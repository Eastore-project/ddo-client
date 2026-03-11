// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AllocationFacet} from "../AllocationFacet.sol";
import {LibDDOStorage} from "../../libraries/LibDDOStorage.sol";
import {LibDiamond} from "../../libraries/LibDiamond.sol";
import {VerifRegSerializationDiamond} from "../../libraries/VerifRegSerializationDiamond.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CBORDecoder} from "lib/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";
import {Misc} from "lib/filecoin-solidity/contracts/v0.8/utils/Misc.sol";

contract MockAllocationFacet {
    using CBORDecoder for bytes;
    using CBOR for CBOR.CBORBuffer;

    /*//////////////////////////////////////////////////////////////
                           MOCK MINER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function setMockMiner(address miner, uint64 actorId) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.getStorage().mockMinerActorIds[miner] = actorId;
    }

    function mockMinerActorIds(address miner) external view returns (uint64) {
        return LibDDOStorage.getStorage().mockMinerActorIds[miner];
    }

    /*//////////////////////////////////////////////////////////////
                    MOCK ALLOCATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function mockCreateAllocationRequests(LibDDOStorage.PieceInfo[] memory pieceInfos)
        external
        returns (uint256 totalDataCap, bytes memory receiverParams)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();

        _validatePiecesForSP(s, pieceInfos);

        if (pieceInfos.length == 0) revert LibDDOStorage.DDOTypes__NoPieceInfosProvided();
        if (address(s.paymentsContract) == address(0)) revert LibDDOStorage.DDOTypes__PaymentsContractNotSet();

        LibDDOStorage.AllocationRequest[] memory allocationRequests =
            new LibDDOStorage.AllocationRequest[](pieceInfos.length);

        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            LibDDOStorage.PieceInfo memory info = pieceInfos[i];
            if (info.size == 0) revert LibDDOStorage.DDOTypes__InvalidPieceSize();
            if (info.provider == 0) revert LibDDOStorage.DDOTypes__InvalidProviderId();

            int64 expiration = currentEpoch + info.expirationOffset;

            allocationRequests[i] = LibDDOStorage.AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: expiration
            });

            totalDataCap += info.size;

            uint64 mockAllocationId = uint64(block.timestamp + i + 1);

            s.allocationIdsByClient[msg.sender].push(mockAllocationId);
            s.allocationIdsByProvider[info.provider].push(mockAllocationId);
            _initiatePaymentRail(s, info, mockAllocationId);

            emit LibDDOStorage.AllocationCreated(
                msg.sender,
                mockAllocationId,
                info.provider,
                info.pieceCid,
                info.size,
                info.termMin,
                info.termMax,
                expiration,
                info.downloadURL
            );
        }

        receiverParams = VerifRegSerializationDiamond.serializeVerifregOperatorData(allocationRequests);
    }

    function mockCreateRawAllocationRequests(LibDDOStorage.PieceInfo[] memory pieceInfos)
        external
        returns (uint256 totalDataCap, bytes memory receiverParams)
    {
        if (pieceInfos.length == 0) revert LibDDOStorage.DDOTypes__NoPieceInfosProvided();

        LibDDOStorage.AllocationRequest[] memory allocationRequests =
            new LibDDOStorage.AllocationRequest[](pieceInfos.length);

        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            LibDDOStorage.PieceInfo memory info = pieceInfos[i];
            if (info.size == 0) revert LibDDOStorage.DDOTypes__InvalidPieceSize();
            if (info.provider == 0) revert LibDDOStorage.DDOTypes__InvalidProviderId();

            int64 expiration = currentEpoch + info.expirationOffset;

            allocationRequests[i] = LibDDOStorage.AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: expiration
            });

            totalDataCap += info.size;
            emit LibDDOStorage.AllocationCreated(
                msg.sender,
                10,
                info.provider,
                info.pieceCid,
                info.size,
                info.termMin,
                info.termMax,
                expiration,
                info.downloadURL
            );
        }

        receiverParams = VerifRegSerializationDiamond.serializeVerifregOperatorData(allocationRequests);
    }

    function mockActivateAllocation(uint64 allocationId) external {
        mockActivateAllocationWithSector(allocationId, 0);
    }

    function mockActivateAllocationWithSector(uint64 allocationId, uint64 sectorNumber) public {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        LibDDOStorage.AllocationInfo storage info = s.allocationInfos[allocationId];
        if (info.client == address(0)) revert LibDDOStorage.DDOTypes__AllocationNotFound();
        if (info.activated) revert LibDDOStorage.DDOTypes__AllocationAlreadyActivated();
        info.sectorNumber = sectorNumber;
        _activatePaymentRail(s, allocationId);
    }

    function mockSettleSpPayment(uint64 allocationId, uint256 untilEpoch)
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalOperatorCommission,
            uint256 totalNetworkFee,
            uint256 finalSettledEpoch,
            string memory note
        )
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        LibDDOStorage.AllocationInfo memory info = s.allocationInfos[allocationId];
        if (!info.activated) revert LibDDOStorage.DDOTypes__AllocationNotActivated();
        if (info.railId == 0) revert LibDDOStorage.DDOTypes__NoRailFoundForAllocation();
        if (address(s.paymentsContract) == address(0)) revert LibDDOStorage.DDOTypes__PaymentsContractNotSet();

        return s.paymentsContract.settleRail(info.railId, untilEpoch);
    }

    /*//////////////////////////////////////////////////////////////
                    MOCK FILECOIN METHOD HANDLER
    //////////////////////////////////////////////////////////////*/

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
                    SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /*//////////////////////////////////////////////////////////////
                    TEST SERIALIZATION WRAPPERS
    //////////////////////////////////////////////////////////////*/

    function deserializeVerifregOperatorData(bytes memory cborData)
        external
        pure
        returns (
            LibDDOStorage.ProviderClaim[] memory claimExtensions,
            LibDDOStorage.AllocationRequest[] memory allocationRequests
        )
    {
        return VerifRegSerializationDiamond.deserializeVerifregOperatorData(cborData);
    }

    function serializeVerifregOperatorData(LibDDOStorage.AllocationRequest[] memory allocationRequests)
        external
        pure
        returns (bytes memory)
    {
        return VerifRegSerializationDiamond.serializeVerifregOperatorData(allocationRequests);
    }

    function deserializeVerifregResponse(bytes memory cborData)
        external
        pure
        returns (LibDDOStorage.VerifregResponse memory)
    {
        return VerifRegSerializationDiamond.deserializeVerifregResponse(cborData);
    }

    function calculateTotalDataCap(LibDDOStorage.PieceInfo[] memory pieceInfos)
        external
        pure
        returns (uint256 totalDataCap)
    {
        for (uint256 i; i < pieceInfos.length; i++) {
            totalDataCap += pieceInfos[i].size;
        }
    }

    function mockAuthenticateCurioProposal(bytes memory data) external pure returns (string memory) {
        return abi.decode(data, (string));
    }

    /*//////////////////////////////////////////////////////////////
                    INTERNAL FUNCTIONS
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

    function _isMinerActor(address caller) internal view returns (bool) {
        return LibDDOStorage.getStorage().mockMinerActorIds[caller] > 0;
    }

    function _processSectorContentChanged(bytes memory params) internal returns (bytes memory) {
        if (!_isMinerActor(msg.sender)) revert LibDDOStorage.DDOTypes__NotMinerActor();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        uint64 minerActorId = s.mockMinerActorIds[msg.sender];

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

    function _receiveDataCap(bytes memory) internal {
        if (msg.sender != LibDDOStorage.DATACAP_ACTOR_ETH_ADDRESS) {
            revert LibDDOStorage.DDOTypes__UnauthorizedMethod();
        }
        emit LibDDOStorage.ReceivedDataCap("DataCap Received!");
    }

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

            if (s.spConfigs[actorId].paymentAddress == address(0)) revert LibDDOStorage.DDOSp__SPNotRegistered();
            if (!s.spConfigs[actorId].isActive) revert LibDDOStorage.DDOSp__SPNotActive();

            LibDDOStorage.SPConfig memory config = s.spConfigs[actorId];

            if (pieceInfos[i].size < config.minPieceSize || pieceInfos[i].size > config.maxPieceSize) {
                revert LibDDOStorage.DDOSp__PieceSizeOutOfRange();
            }

            if (pieceInfos[i].termMin < config.minTermLength || pieceInfos[i].termMax > config.maxTermLength) {
                revert LibDDOStorage.DDOSp__TermLengthOutOfRange();
            }

            _getAndValidateSPPrice(s, actorId, pieceInfos[i].paymentTokenAddress);
        }
    }
}
