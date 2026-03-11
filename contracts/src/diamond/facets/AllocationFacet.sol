// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDDOStorage} from "../libraries/LibDDOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VerifRegSerializationDiamond} from "../libraries/VerifRegSerializationDiamond.sol";
import {VerifRegTypes} from "lib/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {DataCapAPI} from "lib/filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {DataCapTypes} from "lib/filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {CBORDecoder} from "lib/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {PowerAPI} from "lib/filecoin-solidity/contracts/v0.8/PowerAPI.sol";
import {FilAddressIdConverter} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddressIdConverter.sol";
import {Misc} from "lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

contract AllocationFacet {
    using CBORDecoder for bytes;
    using CBOR for CBOR.CBORBuffer;

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createAllocationRequests(LibDDOStorage.PieceInfo[] memory pieceInfos)
        public
        returns (bytes memory recipientData)
    {
        LibDDOStorage.enforceNotPaused();
        LibDDOStorage.enforceNonReentrant();

        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();

        _validatePiecesForSP(s, pieceInfos);

        if (pieceInfos.length == 0) revert LibDDOStorage.DDOTypes__NoPieceInfosProvided();
        if (address(s.paymentsContract) == address(0)) revert LibDDOStorage.DDOTypes__PaymentsContractNotSet();

        LibDDOStorage.AllocationRequest[] memory allocationRequests =
            new LibDDOStorage.AllocationRequest[](pieceInfos.length);
        uint256 totalDataCap;
        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            LibDDOStorage.PieceInfo memory info = pieceInfos[i];
            if (info.size == 0) revert LibDDOStorage.DDOTypes__InvalidPieceSize();
            if (info.provider == 0) revert LibDDOStorage.DDOTypes__InvalidProviderId();

            allocationRequests[i] = LibDDOStorage.AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: currentEpoch + info.expirationOffset
            });
            totalDataCap += info.size;
        }

        bytes memory receiverParams = VerifRegSerializationDiamond.serializeVerifregOperatorData(allocationRequests);
        recipientData = _transferDataCap(s, totalDataCap, receiverParams);

        if (recipientData.length > 0) {
            LibDDOStorage.VerifregResponse memory verifregResponse =
                VerifRegSerializationDiamond.deserializeVerifregResponse(recipientData);
            if (verifregResponse.newAllocations.length > 0) {
                if (verifregResponse.newAllocations.length != pieceInfos.length) {
                    revert LibDDOStorage.DDOTypes__AllocationCountMismatch();
                }

                for (uint256 i; i < verifregResponse.newAllocations.length; i++) {
                    uint64 allocationId = verifregResponse.newAllocations[i];
                    LibDDOStorage.PieceInfo memory info = pieceInfos[i];

                    if (s.allocationInfos[allocationId].client != address(0)) {
                        revert LibDDOStorage.DDOTypes__AllocationAlreadyExists();
                    }

                    s.allocationIdsByClient[msg.sender].push(allocationId);
                    s.allocationIdsByProvider[info.provider].push(allocationId);
                    _initiatePaymentRail(s, info, allocationId);

                    int64 expiration = int64(int256(block.number)) + info.expirationOffset;
                    emit LibDDOStorage.AllocationCreated(
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

        LibDDOStorage.clearReentrancy();
    }

    function settleSpPayment(uint64 allocationId, uint256 untilEpoch)
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
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        LibDDOStorage.AllocationInfo memory info = s.allocationInfos[allocationId];
        if (!info.activated) revert LibDDOStorage.DDOTypes__AllocationNotActivated();
        if (info.railId == 0) revert LibDDOStorage.DDOTypes__NoRailFoundForAllocation();

        return s.paymentsContract.settleRail(info.railId, untilEpoch);
    }

    function settleSpTotalPayment(uint64 providerId, uint256 untilEpoch, uint256 startIndex, uint256 batchSize)
        external
        returns (uint256 settledCount)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        uint64[] memory allocationIds = s.allocationIdsByProvider[providerId];
        if (allocationIds.length == 0) revert LibDDOStorage.DDOTypes__NoAllocationsFoundForProvider();

        uint256 end = (batchSize == 0) ? allocationIds.length : _min(startIndex + batchSize, allocationIds.length);
        for (uint256 i = startIndex; i < end; i++) {
            LibDDOStorage.AllocationInfo memory info = s.allocationInfos[allocationIds[i]];
            if (info.activated && info.railId > 0) {
                s.paymentsContract.settleRail(info.railId, untilEpoch);
                settledCount++;
            }
        }
    }

    function handle_filecoin_method(uint64 method, uint64 _codec, bytes memory params)
        public
        returns (uint32, uint64, bytes memory)
    {
        LibDDOStorage.enforceNotPaused();

        if (method == LibDDOStorage.DATACAP_RECEIVER_HOOK_METHOD_NUM) {
            _receiveDataCap(params);
            return (0, 0, new bytes(0));
        } else if (method == LibDDOStorage.SECTOR_CONTENT_CHANGED_METHOD_NUM) {
            bytes memory ret = _processSectorContentChanged(params);
            return (0, Misc.CBOR_CODEC, ret);
        } else {
            revert LibDDOStorage.DDOTypes__UnauthorizedMethod();
        }
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initiatePaymentRail(
        LibDDOStorage.DDOState storage s,
        LibDDOStorage.PieceInfo memory pieceInfo,
        uint64 allocationId
    ) internal returns (uint256 railId) {
        if (address(s.paymentsContract) == address(0)) revert LibDDOStorage.DDOTypes__PaymentsContractNotSet();

        LibDDOStorage.SPConfig memory spConfig = s.spConfigs[pieceInfo.provider];
        if (spConfig.paymentAddress == address(0)) revert LibDDOStorage.DDOSp__SPNotRegistered();

        railId = s.paymentsContract.createRail(
            IERC20(pieceInfo.paymentTokenAddress),
            msg.sender,
            spConfig.paymentAddress,
            address(this),
            s.commissionRateBps,
            LibDiamond.contractOwner()
        );

        s.paymentsContract.modifyRailLockup(railId, 0, s.allocationLockupAmount);

        uint256 agreedPrice = _getAndValidateSPPrice(s, pieceInfo.provider, pieceInfo.paymentTokenAddress);

        s.allocationInfos[allocationId] = LibDDOStorage.AllocationInfo({
            client: msg.sender,
            provider: pieceInfo.provider,
            activated: false,
            pieceCidHash: keccak256(pieceInfo.pieceCid),
            paymentToken: pieceInfo.paymentTokenAddress,
            pieceSize: pieceInfo.size,
            railId: railId,
            pricePerBytePerEpoch: agreedPrice,
            sectorNumber: 0
        });

        s.railIdToAllocationId[railId] = allocationId;

        emit LibDDOStorage.RailCreated(
            msg.sender, spConfig.paymentAddress, pieceInfo.paymentTokenAddress, railId, pieceInfo.provider, allocationId
        );
    }

    function _activatePaymentRail(LibDDOStorage.DDOState storage s, uint64 allocationId) internal {
        LibDDOStorage.AllocationInfo storage info = s.allocationInfos[allocationId];
        uint256 pricePerEpoch = info.pricePerBytePerEpoch * info.pieceSize;
        info.activated = true;
        s.paymentsContract.modifyRailPayment(info.railId, pricePerEpoch, 0);
        s.paymentsContract.modifyRailLockup(info.railId, LibDDOStorage.EPOCHS_PER_MONTH, 0);
        emit LibDDOStorage.AllocationActivated(allocationId, info.provider, 0, info.railId, pricePerEpoch);
    }

    function _isMinerActor(address caller) internal virtual returns (bool isMiner) {
        (bool isID, uint64 id) = FilAddressIdConverter.isIDAddress(caller);
        if (!isID) return false;
        (int256 exit,) = PowerAPI.minerRawPower(id);
        return exit == 0;
    }

    function _processSectorContentChanged(bytes memory params) internal virtual returns (bytes memory) {
        if (!_isMinerActor(msg.sender)) revert LibDDOStorage.DDOTypes__NotMinerActor();
        (, uint64 minerActorId) = FilAddressIdConverter.isIDAddress(msg.sender);

        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();

        uint256 byteIdx;
        uint256 sectorCount;
        (sectorCount, byteIdx) = params.readFixedArray(byteIdx);

        CBOR.CBORBuffer memory retBuf = CBOR.create(256);
        retBuf.startFixedArray(uint64(sectorCount));

        for (uint256 sc; sc < sectorCount; sc++) {
            uint256 sectorTupleLen;
            (sectorTupleLen, byteIdx) = params.readFixedArray(byteIdx);

            uint64 sectorNumber;
            (sectorNumber, byteIdx) = params.readUInt64(byteIdx);

            int64 minCommitEpoch;
            (minCommitEpoch, byteIdx) = params.readInt64(byteIdx);

            uint256 pieceCount;
            (pieceCount, byteIdx) = params.readFixedArray(byteIdx);

            retBuf.startFixedArray(uint64(pieceCount));

            for (uint256 p; p < pieceCount; p++) {
                uint256 pieceTupleLen;
                (pieceTupleLen, byteIdx) = params.readFixedArray(byteIdx);

                bytes memory dataCid;
                (dataCid, byteIdx) = params.readBytes(byteIdx);

                // Strip CBOR tag 42 0x00 prefix from CID bytes
                if (dataCid.length > 0 && dataCid[0] == 0x00) {
                    bytes memory stripped = new bytes(dataCid.length - 1);
                    for (uint256 i; i < stripped.length; i++) {
                        stripped[i] = dataCid[i + 1];
                    }
                    dataCid = stripped;
                }

                uint64 pieceSize;
                (pieceSize, byteIdx) = params.readUInt64(byteIdx);

                bytes memory payload;
                (payload, byteIdx) = params.readBytes(byteIdx);

                uint64 allocationId;
                (allocationId,) = payload.readUInt64(0);

                LibDDOStorage.AllocationInfo storage allocInfo = s.allocationInfos[allocationId];
                bool accepted;

                if (
                    allocInfo.client != address(0) && !allocInfo.activated && allocInfo.provider == minerActorId
                        && allocInfo.pieceCidHash == keccak256(dataCid) && allocInfo.pieceSize == pieceSize
                ) {
                    allocInfo.sectorNumber = sectorNumber;
                    _activatePaymentRail(s, allocationId);
                    accepted = true;
                }

                retBuf.writeBool(accepted);
            }
        }

        return retBuf.data();
    }

    function _transferDataCap(LibDDOStorage.DDOState storage, uint256 amount, bytes memory operatorData)
        internal
        returns (bytes memory recipientData)
    {
        CommonTypes.FilAddress memory dataCapActorAddress =
            FilAddresses.fromActorID(CommonTypes.FilActorId.unwrap(VerifRegTypes.ActorID));

        CommonTypes.BigInt memory transferAmount =
            CommonTypes.BigInt({val: abi.encodePacked(amount * 10 ** 18), neg: false});

        DataCapTypes.TransferParams memory transferParams =
            DataCapTypes.TransferParams({operator_data: operatorData, to: dataCapActorAddress, amount: transferAmount});

        (int256 exitCode, DataCapTypes.TransferReturn memory transferResult) = DataCapAPI.transfer(transferParams);

        if (exitCode != 0) revert LibDDOStorage.DDOTypes__DataCapTransferError(exitCode);

        emit LibDDOStorage.DataCapTransferSuccess(amount, transferResult.recipient_data);
        return transferResult.recipient_data;
    }

    function _receiveDataCap(bytes memory) internal {
        if (msg.sender != LibDDOStorage.DATACAP_ACTOR_ETH_ADDRESS) {
            revert LibDDOStorage.DDOTypes__UnauthorizedMethod();
        }
        emit LibDDOStorage.ReceivedDataCap("DataCap Received!");
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _getAndValidateSPPrice(LibDDOStorage.DDOState storage s, uint64 actorId, address token)
        internal
        view
        returns (uint256)
    {
        if (s.spConfigs[actorId].paymentAddress == address(0)) {
            revert LibDDOStorage.DDOSp__SPNotRegistered();
        }
        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }
        revert LibDDOStorage.DDOSp__TokenNotSupportedBySP();
    }

    function _validatePiecesForSP(LibDDOStorage.DDOState storage s, LibDDOStorage.PieceInfo[] memory pieceInfos)
        internal
        view
    {
        for (uint256 i; i < pieceInfos.length; i++) {
            uint64 actorId = pieceInfos[i].provider;

            if (s.spConfigs[actorId].paymentAddress == address(0)) {
                revert LibDDOStorage.DDOSp__SPNotRegistered();
            }
            if (!s.spConfigs[actorId].isActive) {
                revert LibDDOStorage.DDOSp__SPNotActive();
            }

            LibDDOStorage.SPConfig memory config = s.spConfigs[actorId];

            if (pieceInfos[i].size < config.minPieceSize || pieceInfos[i].size > config.maxPieceSize) {
                revert LibDDOStorage.DDOSp__PieceSizeOutOfRange();
            }

            if (pieceInfos[i].termMin < config.minTermLength || pieceInfos[i].termMax > config.maxTermLength) {
                revert LibDDOStorage.DDOSp__TermLengthOutOfRange();
            }

            // Validate token is supported
            _getAndValidateSPPrice(s, actorId, pieceInfos[i].paymentTokenAddress);
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
