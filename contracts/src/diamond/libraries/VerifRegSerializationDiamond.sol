// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {CBORDecoder} from "lib/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CBOR} from "lib/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {FilecoinCBOR} from "lib/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {LibDDOStorage} from "./LibDDOStorage.sol";

library VerifRegSerializationDiamond {
    using CBOR for CBOR.CBORBuffer;

    function serializeVerifregOperatorData(LibDDOStorage.AllocationRequest[] memory allocationRequests)
        internal
        pure
        returns (bytes memory)
    {
        uint256 capacity;
        capacity += _getPrefixSize(2);
        capacity += _getPrefixSize(allocationRequests.length);
        for (uint256 i = 0; i < allocationRequests.length; i++) {
            capacity += _getPrefixSize(6);
            capacity += _getPrefixSize(allocationRequests[i].provider);
            capacity += _getBytesSize(allocationRequests[i].data);
            capacity += _getPrefixSize(allocationRequests[i].size);
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].termMin >= 0 ? allocationRequests[i].termMin : -allocationRequests[i].termMin
                )
            );
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].termMax >= 0 ? allocationRequests[i].termMax : -allocationRequests[i].termMax
                )
            );
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].expiration >= 0
                        ? allocationRequests[i].expiration
                        : -allocationRequests[i].expiration
                )
            );
        }
        capacity += _getPrefixSize(0);

        CBOR.CBORBuffer memory buf = CBOR.create(capacity);
        buf.startFixedArray(2);

        buf.startFixedArray(uint64(allocationRequests.length));
        for (uint256 i = 0; i < allocationRequests.length; i++) {
            LibDDOStorage.AllocationRequest memory req = allocationRequests[i];
            buf.startFixedArray(6);
            buf.writeUInt64(req.provider);
            FilecoinCBOR.writeCid(buf, req.data);
            buf.writeUInt64(req.size);
            buf.writeInt64(req.termMin);
            buf.writeInt64(req.termMax);
            buf.writeInt64(req.expiration);
        }

        buf.startFixedArray(0);
        return buf.data();
    }

    function deserializeVerifregOperatorData(bytes memory cborData)
        internal
        pure
        returns (
            LibDDOStorage.ProviderClaim[] memory claimExtensions,
            LibDDOStorage.AllocationRequest[] memory allocationRequests
        )
    {
        uint256 byteIdx = 0;
        uint256 operatorDataLength;
        (operatorDataLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (operatorDataLength != 2) revert LibDDOStorage.DDOTypes__InvalidOperatorData();

        (allocationRequests, byteIdx) = _deserializeAllocationRequests(cborData, byteIdx);
        (claimExtensions, byteIdx) = _deserializeClaimExtensions(cborData, byteIdx);
    }

    function _deserializeAllocationRequests(bytes memory cborData, uint256 startIdx)
        internal
        pure
        returns (LibDDOStorage.AllocationRequest[] memory allocationRequests, uint256 nextIdx)
    {
        uint256 byteIdx = startIdx;
        uint256 allocationRequestsLength;
        (allocationRequestsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        allocationRequests = new LibDDOStorage.AllocationRequest[](allocationRequestsLength);

        for (uint256 i = 0; i < allocationRequestsLength; i++) {
            (allocationRequests[i], byteIdx) = _deserializeSingleAllocationRequest(cborData, byteIdx);
        }
        return (allocationRequests, byteIdx);
    }

    function _deserializeSingleAllocationRequest(bytes memory cborData, uint256 startIdx)
        internal
        pure
        returns (LibDDOStorage.AllocationRequest memory request, uint256 nextIdx)
    {
        uint256 byteIdx = startIdx;
        uint256 allocationRequestLength;
        (allocationRequestLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (allocationRequestLength != 6) revert LibDDOStorage.DDOTypes__InvalidAllocationRequest();

        uint64 provider;
        (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

        CommonTypes.Cid memory cidStruct;
        (cidStruct, byteIdx) = FilecoinCBOR.readCid(cborData, byteIdx);

        uint64 size;
        (size, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

        int64 termMin;
        (termMin, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

        int64 termMax;
        (termMax, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

        int64 expiration;
        (expiration, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

        request = LibDDOStorage.AllocationRequest({
            provider: provider,
            data: cidStruct.data,
            size: size,
            termMin: termMin,
            termMax: termMax,
            expiration: expiration
        });
        return (request, byteIdx);
    }

    function _deserializeClaimExtensions(bytes memory cborData, uint256 startIdx)
        internal
        pure
        returns (LibDDOStorage.ProviderClaim[] memory claimExtensions, uint256 nextIdx)
    {
        uint256 byteIdx = startIdx;
        uint256 claimExtensionRequestsLength;
        (claimExtensionRequestsLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        claimExtensions = new LibDDOStorage.ProviderClaim[](claimExtensionRequestsLength);

        for (uint256 i = 0; i < claimExtensionRequestsLength; i++) {
            uint256 claimExtensionRequestLength;
            (claimExtensionRequestLength, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (claimExtensionRequestLength != 3) revert LibDDOStorage.DDOTypes__InvalidClaimExtensionRequest();

            uint64 provider;
            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            uint64 claimId;
            (claimId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx);

            claimExtensions[i].provider = CommonTypes.FilActorId.wrap(provider);
            claimExtensions[i].claim = CommonTypes.FilActorId.wrap(claimId);
        }
        return (claimExtensions, byteIdx);
    }

    function deserializeVerifregResponse(bytes memory cborData)
        internal
        pure
        returns (LibDDOStorage.VerifregResponse memory response)
    {
        uint256 byteIdx = 0;
        uint256 len;

        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (len != 3) revert LibDDOStorage.DDOTypes__InvalidVerifregResponse();

        (response.allocationResults, byteIdx) = _deserializeBatchReturn(cborData, byteIdx);
        (response.extensionResults, byteIdx) = _deserializeBatchReturn(cborData, byteIdx);

        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        response.newAllocations = new uint64[](len);
        for (uint256 i = 0; i < len; i++) {
            (response.newAllocations[i], byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
        }
    }

    function _deserializeBatchReturn(bytes memory cborData, uint256 initialByteIdx)
        internal
        pure
        returns (CommonTypes.BatchReturn memory batchReturn, uint256 nextByteIdx)
    {
        uint256 byteIdx = initialByteIdx;
        uint256 len;

        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        if (len != 2) revert LibDDOStorage.DDOTypes__InvalidBatchReturnFormat();

        uint64 successCount64;
        (successCount64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
        batchReturn.success_count = uint32(successCount64);

        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        batchReturn.fail_codes = new CommonTypes.FailCode[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 failCodeLen;
            (failCodeLen, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
            if (failCodeLen != 2) revert LibDDOStorage.DDOTypes__InvalidFailCodeFormat();

            uint64 idx64;
            (idx64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            batchReturn.fail_codes[i].idx = uint32(idx64);

            uint64 code64;
            (code64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            batchReturn.fail_codes[i].code = uint32(code64);
        }
        nextByteIdx = byteIdx;
    }

    function _getPrefixSize(uint256 dataSize) internal pure returns (uint256) {
        if (dataSize <= 23) return 1;
        else if (dataSize <= 0xFF) return 2;
        else if (dataSize <= 0xFFFF) return 3;
        else if (dataSize <= 0xFFFFFFFF) return 5;
        return 9;
    }

    function _getBytesSize(bytes memory value) internal pure returns (uint256) {
        return _getPrefixSize(value.length) + value.length;
    }
}
