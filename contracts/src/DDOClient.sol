// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {DDOSp} from "./DDOSp.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DDOValidator} from "./DDOValidator.sol";
import {MockDDO} from "./MockDDO.sol";
import {VerifRegTypes} from "lib/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";
import {DataCapAPI} from "lib/filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {DataCapTypes} from "lib/filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {PrecompilesAPI} from "lib/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol";
import {VerifRegAPI} from "lib/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {CBORDecoder} from "lib/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {PowerAPI} from "lib/filecoin-solidity/contracts/v0.8/PowerAPI.sol";
import {FilAddressIdConverter} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddressIdConverter.sol";
import {Misc} from "lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

contract DDOClient is DDOTypes, DDOSp, DDOValidator, ReentrancyGuard {
    using CBORDecoder for bytes;
    using CBOR for CBOR.CBORBuffer;

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Set the payments contract address
     * @param _paymentsContract Address of the payments contract
     */
    function setPaymentsContract(address _paymentsContract) external onlyOwner {
        if (_paymentsContract == address(0)) {
            revert DDOTypes__InvalidPaymentsContract();
        }
        paymentsContract = FilecoinPayV1(_paymentsContract);
    }

    /**
     * @notice Set the commission rate for storage provider payments
     * @param _commissionRateBps Commission rate in basis points (max 100 = 1%)
     */
    function setCommissionRate(uint256 _commissionRateBps) external onlyOwner {
        if (_commissionRateBps > MAX_COMMISSION_RATE_BPS) {
            revert DDOTypes__CommissionRateExceedsMaximum();
        }
        commissionRateBps = _commissionRateBps;
    }

    /**
     * @notice Set the anti-spam lockup amount applied per allocation until activation
     * @param _amount Lockup amount in token units
     */
    function setAllocationLockupAmount(uint256 _amount) external onlyOwner {
        allocationLockupAmount = _amount;
    }

    /**
     * @notice Creates allocation requests and transfers DataCap to the DataCap actor
     * @param pieceInfos Array of piece information to create allocations for
     * @return recipientData Data returned from the DataCap transfer
     */
    function createAllocationRequests(
        PieceInfo[] memory pieceInfos
    )
        public
        onlyValidPieceForSP(pieceInfos)
        returns (bytes memory recipientData)
    {
        if (pieceInfos.length == 0) {
            revert DDOTypes__NoPieceInfosProvided();
        }
        if (address(paymentsContract) == address(0)) {
            revert DDOTypes__PaymentsContractNotSet();
        }

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );
        uint256 totalDataCap;

        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            if (info.size == 0) {
                revert DDOTypes__InvalidPieceSize();
            }
            if (info.provider == 0) {
                revert DDOTypes__InvalidProviderId();
            }

            int64 expiration = currentEpoch + info.expirationOffset;

            allocationRequests[i] = AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: expiration
            });

            totalDataCap += info.size;
        }

        bytes memory receiverParams = VerifRegSerialization
            .serializeVerifregOperatorData(allocationRequests);

        recipientData = _transferDataCap(totalDataCap, receiverParams);

        if (recipientData.length > 0) {
            DDOTypes.VerifregResponse
                memory verifregResponse = VerifRegSerialization
                    .deserializeVerifregResponse(recipientData);
            if (verifregResponse.newAllocations.length > 0) {
                if (
                    verifregResponse.newAllocations.length != pieceInfos.length
                ) {
                    revert DDOTypes__AllocationCountMismatch();
                }

                for (
                    uint256 i;
                    i < verifregResponse.newAllocations.length;
                    i++
                ) {
                    uint64 allocationId = verifregResponse.newAllocations[i];
                    PieceInfo memory info = pieceInfos[i];

                    allocationIdsByClient[msg.sender].push(allocationId);
                    allocationIdsByProvider[info.provider].push(allocationId);
                    _initiatePaymentRail(info, allocationId);

                    int64 expiration = int64(int256(block.number)) +
                        info.expirationOffset;

                    emit AllocationCreated(
                        msg.sender,
                        allocationId,
                        info.provider,
                        info.pieceCid,
                        info.size,
                        info.termMin,
                        info.termMax,
                        expiration,
                        info.downloadURL
                    );
                }
            }
        }

        return recipientData;
    }

    /**
     * @notice Settle storage provider payment for an allocation (requires activation)
     * @param allocationId The allocation ID to settle payment for
     * @param untilEpoch The epoch until which to settle the rail
     */
    function settleSpPayment(
        uint64 allocationId,
        uint256 untilEpoch
    )
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalNetworkFee,
            uint256 totalOperatorCommission,
            uint256 finalSettledEpoch,
            string memory note
        )
    {
        AllocationInfo memory info = allocationInfos[allocationId];
        if (!info.activated) {
            revert DDOTypes__AllocationNotActivated();
        }
        if (info.railId == 0) {
            revert DDOTypes__NoRailFoundForAllocation();
        }

        return paymentsContract.settleRail(info.railId, untilEpoch);
    }

    /**
     * @notice Settle storage provider payment for all allocations until specified epoch
     * @param providerId The storage provider ID to settle payments for
     * @param untilEpoch The epoch until which to settle all rails
     */
    function settleSpTotalPayment(
        uint64 providerId,
        uint256 untilEpoch
    ) external {
        uint64[] memory allocationIds = allocationIdsByProvider[providerId];
        if (allocationIds.length == 0) {
            revert DDOTypes__NoAllocationsFoundForProvider();
        }

        for (uint256 i; i < allocationIds.length; i++) {
            this.settleSpPayment(allocationIds[i], untilEpoch);
        }
    }

    /**
     * @notice Universal entry point for any EVM-based actor method calls.
     * @param method FRC42 method number for the specific method hook.
     * @param _codec An unused codec param defining input format.
     * @param params The CBOR encoded byte array parameters associated with the method call.
     * @return A tuple containing exit code, codec and bytes return data.
     */
    function handle_filecoin_method(
        uint64 method,
        uint64 _codec,
        bytes memory params
    ) public returns (uint32, uint64, bytes memory) {
        if (method == DATACAP_RECEIVER_HOOK_METHOD_NUM) {
            receiveDataCap(params);
            return (0, 0, new bytes(0));
        } else if (method == SECTOR_CONTENT_CHANGED_METHOD_NUM) {
            bytes memory ret = _processSectorContentChanged(params);
            return (0, Misc.CBOR_CODEC, ret);
        } else {
            revert DDOTypes__UnauthorizedMethod();
        }
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get all allocation IDs for a specific client
     * @param clientAddress The address of the client
     * @return allocationIds Array of all allocation IDs for the client
     */
    function getAllocationIdsForClient(
        address clientAddress
    ) external view returns (uint64[] memory allocationIds) {
        return allocationIdsByClient[clientAddress];
    }

    /**
     * @notice Get allocation and rail information together
     * @param allocationId The allocation ID
     * @return railId The corresponding rail ID
     * @return providerId The storage provider ID
     * @return railView Detailed rail information (if rail exists)
     */
    function getAllocationRailInfo(
        uint64 allocationId
    )
        external
        view
        returns (
            uint256 railId,
            uint64 providerId,
            FilecoinPayV1.RailView memory railView
        )
    {
        AllocationInfo memory info = allocationInfos[allocationId];
        railId = info.railId;
        providerId = info.provider;

        if (railId > 0 && address(paymentsContract) != address(0)) {
            railView = paymentsContract.getRail(railId);
        }

        return (railId, providerId, railView);
    }

    /**
     * @notice Get claim information for a specific client and claim ID
     * @param clientAddress The address of the client
     * @param claimId The ID of the claim to retrieve
     * @return claims An array of Claim structs, empty if not found or an error occurred
     */
    function getClaimInfoForClient(
        address clientAddress,
        uint64 claimId
    )
        external
        view
        onlyValidClaimForClient(clientAddress, claimId)
        returns (VerifRegTypes.Claim[] memory claims)
    {
        uint64 providerActorId = allocationInfos[claimId].provider;
        if (providerActorId == 0) {
            revert DDOTypes__InvalidProvider();
        }

        CommonTypes.FilActorId[]
            memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory claimParams = VerifRegTypes
            .GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(providerActorId),
                claim_ids: claimIdsToFetch
            });

        (
            int256 exitCode,
            VerifRegTypes.GetClaimsReturn memory getClaimsReturn
        ) = VerifRegAPI.getClaims(claimParams);

        if (exitCode != 0) {
            revert DDOTypes__GetClaimsFailed(exitCode);
        }

        if (
            getClaimsReturn.batch_info.success_count == 0 ||
            getClaimsReturn.claims.length == 0
        ) {
            revert DDOTypes__NoClaimsFound();
        }

        return getClaimsReturn.claims;
    }

    /**
     * @notice Get claim information for a specific provider and claim ID
     * @param providerActorId The actor ID of the provider
     * @param claimId The ID of the claim to retrieve
     * @return getClaimsReturn The GetClaimsReturn struct containing batch info and claims
     */
    function getClaimInfo(
        uint64 providerActorId,
        uint64 claimId
    ) public view returns (VerifRegTypes.GetClaimsReturn memory) {
        CommonTypes.FilActorId[]
            memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory claimParams = VerifRegTypes
            .GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(providerActorId),
                claim_ids: claimIdsToFetch
            });

        (
            int256 exitCode,
            VerifRegTypes.GetClaimsReturn memory getClaimsReturnData
        ) = VerifRegAPI.getClaims(claimParams);

        if (exitCode != 0) {
            revert DDOTypes__GetClaimsFailed(exitCode);
        }

        return getClaimsReturnData;
    }

    /**
     * @notice Get all allocation IDs for a specific storage provider
     * @param providerId The storage provider ID
     * @return allocationIds Array of all allocation IDs for the provider
     */
    function getAllocationIdsForProvider(
        uint64 providerId
    ) external view returns (uint64[] memory allocationIds) {
        return allocationIdsByProvider[providerId];
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to create a payment rail for one allocation
     * @param pieceInfo Single piece information
     * @param allocationId The allocation ID to associate with this rail
     * @return railId The created rail ID
     */
    function _initiatePaymentRail(
        PieceInfo memory pieceInfo,
        uint64 allocationId
    ) internal returns (uint256 railId) {
        if (address(paymentsContract) == address(0)) {
            revert DDOTypes__PaymentsContractNotSet();
        }

        SPConfig memory spConfig = spConfigs[pieceInfo.provider];
        if (spConfig.paymentAddress == address(0)) {
            revert DDOSp__SPNotRegistered();
        }

        railId = paymentsContract.createRail(
            IERC20(pieceInfo.paymentTokenAddress),
            msg.sender,
            spConfig.paymentAddress,
            address(this),
            commissionRateBps,
            owner()
        );

        paymentsContract.modifyRailLockup(
            railId,
            0,
            allocationLockupAmount
        );

        allocationInfos[allocationId] = AllocationInfo({
            client: msg.sender,
            provider: pieceInfo.provider,
            activated: false,
            pieceCidHash: keccak256(pieceInfo.pieceCid),
            paymentToken: pieceInfo.paymentTokenAddress,
            pieceSize: pieceInfo.size,
            railId: 0
        });
        allocationInfos[allocationId].railId = railId;

        emit RailCreated(
            msg.sender,
            spConfig.paymentAddress,
            pieceInfo.paymentTokenAddress,
            railId,
            pieceInfo.provider,
            allocationId
        );

        return railId;
    }

    /**
     * @notice Activate a payment rail after SectorContentChanged notification
     * @param allocationId The allocation ID to activate
     */
    function _activatePaymentRail(uint64 allocationId) internal virtual {
        AllocationInfo storage info = allocationInfos[allocationId];
        uint256 pricePerEpoch = this.getAndValidateSPPrice(info.provider, info.paymentToken) * info.pieceSize;
        paymentsContract.modifyRailPayment(info.railId, pricePerEpoch, 0);
        paymentsContract.modifyRailLockup(info.railId, EPOCHS_PER_MONTH, 0);
        info.activated = true;
        emit AllocationActivated(allocationId, info.provider, 0, info.railId, pricePerEpoch);
    }

    /**
     * @notice Check if the caller is a miner actor using PowerAPI
     * @param caller The address to check
     * @return isMiner True if the caller is a miner actor
     */
    function _isMinerActor(address caller) internal virtual returns (bool isMiner) {
        (bool isID, uint64 id) = FilAddressIdConverter.isIDAddress(caller);
        if (!isID) return false;

        (int256 exit, ) = PowerAPI.minerRawPower(id);
        return exit == 0;
    }

    /**
     * @notice Process SectorContentChanged notification from miner actor
     * @param params CBOR encoded SectorContentChangedParams
     * @return CBOR encoded response with accepted booleans per piece
     */
    function _processSectorContentChanged(bytes memory params) internal returns (bytes memory) {
        if (!_isMinerActor(msg.sender)) {
            revert DDOTypes__NotMinerActor();
        }
        (, uint64 minerActorId) = FilAddressIdConverter.isIDAddress(msg.sender);

        uint byteIdx;
        uint sectorCount;
        (sectorCount, byteIdx) = params.readFixedArray(byteIdx);

        CBOR.CBORBuffer memory retBuf = CBOR.create(256);
        retBuf.startFixedArray(uint64(sectorCount));

        for (uint s; s < sectorCount; s++) {
            uint sectorTupleLen;
            (sectorTupleLen, byteIdx) = params.readFixedArray(byteIdx);

            uint64 sectorNumber;
            (sectorNumber, byteIdx) = params.readUInt64(byteIdx);

            int64 minCommitEpoch;
            (minCommitEpoch, byteIdx) = params.readInt64(byteIdx);

            uint pieceCount;
            (pieceCount, byteIdx) = params.readFixedArray(byteIdx);

            retBuf.startFixedArray(uint64(pieceCount));

            for (uint p; p < pieceCount; p++) {
                uint pieceTupleLen;
                (pieceTupleLen, byteIdx) = params.readFixedArray(byteIdx);

                bytes memory dataCid;
                (dataCid, byteIdx) = params.readBytes(byteIdx);

                // Strip CBOR tag 42 0x00 prefix from CID bytes
                if (dataCid.length > 0 && dataCid[0] == 0x00) {
                    bytes memory stripped = new bytes(dataCid.length - 1);
                    for (uint i; i < stripped.length; i++) {
                        stripped[i] = dataCid[i + 1];
                    }
                    dataCid = stripped;
                }

                uint64 pieceSize;
                (pieceSize, byteIdx) = params.readUInt64(byteIdx);

                bytes memory payload;
                (payload, byteIdx) = params.readBytes(byteIdx);

                uint64 allocationId;
                (allocationId, ) = payload.readUInt64(0);

                AllocationInfo storage allocInfo = allocationInfos[allocationId];
                bool accepted;

                if (
                    allocInfo.client != address(0) &&
                    !allocInfo.activated &&
                    allocInfo.provider == minerActorId &&
                    allocInfo.pieceCidHash == keccak256(dataCid) &&
                    allocInfo.pieceSize == pieceSize
                ) {
                    _activatePaymentRail(allocationId);
                    accepted = true;
                }

                retBuf.writeBool(accepted);
            }
        }

        return retBuf.data();
    }

    /**
     * @notice Internal function to transfer DataCap to the DataCap actor
     * @param amount Amount of DataCap to transfer
     * @param operatorData Serialized allocation request data containing provider info
     * @return recipientData Data returned from the transfer
     */
    function _transferDataCap(
        uint256 amount,
        bytes memory operatorData
    ) internal returns (bytes memory recipientData) {
        CommonTypes.FilAddress memory dataCapActorAddress = FilAddresses
            .fromActorID(CommonTypes.FilActorId.unwrap(VerifRegTypes.ActorID));

        CommonTypes.BigInt memory transferAmount = CommonTypes.BigInt({
            val: abi.encodePacked(amount * 10 ** 18),
            neg: false
        });

        DataCapTypes.TransferParams memory transferParams = DataCapTypes
            .TransferParams({
                operator_data: operatorData,
                to: dataCapActorAddress,
                amount: transferAmount
            });

        (
            int256 exitCode,
            DataCapTypes.TransferReturn memory transferResult
        ) = DataCapAPI.transfer(transferParams);

        if (exitCode != 0) {
            revert DDOTypes__DataCapTransferError(exitCode);
        }

        emit DataCapTransferSuccess(amount, transferResult.recipient_data);
        return transferResult.recipient_data;
    }

    /**
     * @notice Handles the receipt of DataCap.
     * @param _params The parameters associated with the DataCap.
     */
    function receiveDataCap(bytes memory _params) internal {
        if (msg.sender != DATACAP_ACTOR_ETH_ADDRESS) {
            revert DDOTypes__UnauthorizedMethod();
        }
        emit ReceivedDataCap("DataCap Received!");
    }
}
