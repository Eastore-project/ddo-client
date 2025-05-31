// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {CBORDecoder} from "lib/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol";
import {CBOR} from "lib/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {FilecoinCBOR} from "lib/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol";
import {DDOTypes} from "./DDOTypes.sol";

/**
 * @title VerifRegSerialization
 * @notice Library for serializing and deserializing DDO data structures to/from CBOR
 */
library VerifRegSerialization {
    using CBOR for CBOR.CBORBuffer;

    /**
     * @notice Serialize allocation requests to CBOR bytes
     * @param allocationRequests Array of allocation requests to serialize
     * @return Serialized CBOR bytes
     */
    function serializeVerifregOperatorData(
        DDOTypes.AllocationRequest[] memory allocationRequests
    ) internal pure returns (bytes memory) {
        // Calculate capacity needed for CBOR buffer
        uint256 capacity = 0;

        // Top level array [allocation_requests, claim_extensions] - 2 elements
        capacity += _getPrefixSize(2);

        // Allocation requests array
        capacity += _getPrefixSize(allocationRequests.length);
        for (uint256 i = 0; i < allocationRequests.length; i++) {
            // Each allocation request has 6 fields
            capacity += _getPrefixSize(6);
            capacity += _getPrefixSize(allocationRequests[i].provider); // uint64
            capacity += _getBytesSize(allocationRequests[i].data); // bytes
            capacity += _getPrefixSize(allocationRequests[i].size); // uint64
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].termMin >= 0
                        ? allocationRequests[i].termMin
                        : -allocationRequests[i].termMin
                )
            ); // int64
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].termMax >= 0
                        ? allocationRequests[i].termMax
                        : -allocationRequests[i].termMax
                )
            ); // int64
            capacity += _getPrefixSize(
                uint64(
                    allocationRequests[i].expiration >= 0
                        ? allocationRequests[i].expiration
                        : -allocationRequests[i].expiration
                )
            ); // int64
        }

        // Empty claim extensions array
        capacity += _getPrefixSize(0);

        CBOR.CBORBuffer memory buf = CBOR.create(capacity);

        // Start top level array with 2 elements [allocation_requests, claim_extensions]
        buf.startFixedArray(2);

        // Write allocation requests array
        buf.startFixedArray(uint64(allocationRequests.length));
        for (uint256 i = 0; i < allocationRequests.length; i++) {
            DDOTypes.AllocationRequest memory req = allocationRequests[i];

            // Each allocation request is an array of 6 elements
            buf.startFixedArray(6);
            buf.writeUInt64(req.provider); // provider
            FilecoinCBOR.writeCid(buf, req.data); // data (CID with proper CBOR tag 42)
            buf.writeUInt64(req.size); // size
            buf.writeInt64(req.termMin); // termMin
            buf.writeInt64(req.termMax); // termMax
            buf.writeInt64(req.expiration); // expiration
        }

        // Write empty claim extensions array
        buf.startFixedArray(0);

        return buf.data();
    }

    /**
     * @notice Deserialize Verifreg Operator Data
     * @param cborData The cbor encoded operator data
     */
    function deserializeVerifregOperatorData(
        bytes memory cborData
    )
        internal
        pure
        returns (
            DDOTypes.ProviderClaim[] memory claimExtensions,
            DDOTypes.AllocationRequest[] memory allocationRequests
        )
    {
        uint256 byteIdx = 0;

        // Read top-level array (should have 2 elements)
        uint256 operatorDataLength;
        (operatorDataLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        if (operatorDataLength != 2) revert DDOTypes.InvalidOperatorData();

        // Deserialize allocation requests
        (allocationRequests, byteIdx) = _deserializeAllocationRequests(
            cborData,
            byteIdx
        );

        // Deserialize claim extensions
        (claimExtensions, byteIdx) = _deserializeClaimExtensions(
            cborData,
            byteIdx
        );
    }

    /**
     * @notice Helper function to deserialize allocation requests
     * @param cborData The CBOR data
     * @param startIdx Starting byte index
     * @return allocationRequests Array of allocation requests
     * @return nextIdx Next byte index after parsing
     */
    function _deserializeAllocationRequests(
        bytes memory cborData,
        uint256 startIdx
    )
        internal
        pure
        returns (
            DDOTypes.AllocationRequest[] memory allocationRequests,
            uint256 nextIdx
        )
    {
        uint256 byteIdx = startIdx;

        uint256 allocationRequestsLength;
        (allocationRequestsLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        allocationRequests = new DDOTypes.AllocationRequest[](
            allocationRequestsLength
        );

        for (uint256 i = 0; i < allocationRequestsLength; i++) {
            (
                allocationRequests[i],
                byteIdx
            ) = _deserializeSingleAllocationRequest(cborData, byteIdx);
        }

        return (allocationRequests, byteIdx);
    }

    /**
     * @notice Helper function to deserialize a single allocation request
     * @param cborData The CBOR data
     * @param startIdx Starting byte index
     * @return request Single allocation request
     * @return nextIdx Next byte index after parsing
     */
    function _deserializeSingleAllocationRequest(
        bytes memory cborData,
        uint256 startIdx
    )
        internal
        pure
        returns (DDOTypes.AllocationRequest memory request, uint256 nextIdx)
    {
        uint256 byteIdx = startIdx;

        uint256 allocationRequestLength;
        (allocationRequestLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );

        if (allocationRequestLength != 6) {
            revert DDOTypes.InvalidAllocationRequest();
        }

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

        request = DDOTypes.AllocationRequest({
            provider: provider,
            data: cidStruct.data,
            size: size,
            termMin: termMin,
            termMax: termMax,
            expiration: expiration
        });

        return (request, byteIdx);
    }

    /**
     * @notice Helper function to deserialize claim extensions
     * @param cborData The CBOR data
     * @param startIdx Starting byte index
     * @return claimExtensions Array of claim extensions
     * @return nextIdx Next byte index after parsing
     */
    function _deserializeClaimExtensions(
        bytes memory cborData,
        uint256 startIdx
    )
        internal
        pure
        returns (
            DDOTypes.ProviderClaim[] memory claimExtensions,
            uint256 nextIdx
        )
    {
        uint256 byteIdx = startIdx;

        uint256 claimExtensionRequestsLength;
        (claimExtensionRequestsLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        claimExtensions = new DDOTypes.ProviderClaim[](
            claimExtensionRequestsLength
        );

        for (uint256 i = 0; i < claimExtensionRequestsLength; i++) {
            uint256 claimExtensionRequestLength;
            (claimExtensionRequestLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );

            if (claimExtensionRequestLength != 3) {
                revert DDOTypes.InvalidClaimExtensionRequest();
            }

            uint64 provider;
            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            uint64 claimId;
            (claimId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);

            // slither-disable-start unused-return
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMax
            // slither-disable-end unused-return

            claimExtensions[i].provider = CommonTypes.FilActorId.wrap(provider);
            claimExtensions[i].claim = CommonTypes.FilActorId.wrap(claimId);
        }

        return (claimExtensions, byteIdx);
    }

    /**
     * @notice Helper function to calculate CBOR prefix size
     */
    function _getPrefixSize(uint256 dataSize) internal pure returns (uint256) {
        if (dataSize <= 23) {
            return 1;
        } else if (dataSize <= 0xFF) {
            return 2;
        } else if (dataSize <= 0xFFFF) {
            return 3;
        } else if (dataSize <= 0xFFFFFFFF) {
            return 5;
        }
        return 9;
    }

    /**
     * @notice Helper function to calculate bytes size with prefix
     */
    function _getBytesSize(bytes memory value) internal pure returns (uint256) {
        return _getPrefixSize(value.length) + value.length;
    }

    /**
     * @notice Deserialize Verification Registry Response from CBOR
     * @param cborData The CBOR encoded verification registry response
     * @return response Parsed VerifregResponse struct
     */
    function deserializeVerifregResponse(
        bytes memory cborData
    ) internal pure returns (DDOTypes.VerifregResponse memory response) {
        uint256 byteIdx = 0;
        uint256 len;

        // Read top-level array (should be 3 elements: AllocationResults, ExtensionResults, NewAllocations)
        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        require(len == 3, "Invalid response format: expected 3 elements");

        // Parse AllocationResults (CommonTypes.BatchReturn)
        (response.allocationResults, byteIdx) = _deserializeBatchReturn(
            cborData,
            byteIdx
        );

        // Parse ExtensionResults (CommonTypes.BatchReturn)
        (response.extensionResults, byteIdx) = _deserializeBatchReturn(
            cborData,
            byteIdx
        );

        // Parse NewAllocations
        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        response.newAllocations = new uint64[](len);
        for (uint256 i = 0; i < len; i++) {
            (response.newAllocations[i], byteIdx) = CBORDecoder.readUInt64(
                cborData,
                byteIdx
            );
        }

        return response;
    }

    /**
     * @notice Helper function to deserialize CommonTypes.BatchReturn from CBOR
     * @param cborData The CBOR encoded data
     * @param initialByteIdx The starting byte index for deserialization
     * @return batchReturn The deserialized BatchReturn struct
     * @return nextByteIdx The byte index after deserialization
     */
    function _deserializeBatchReturn(
        bytes memory cborData,
        uint256 initialByteIdx
    )
        internal
        pure
        returns (
            CommonTypes.BatchReturn memory batchReturn,
            uint256 nextByteIdx
        )
    {
        uint256 byteIdx = initialByteIdx;
        uint256 len;

        // BatchReturn is an array of 2 elements: success_count, fail_codes
        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        require(len == 2, "Invalid BatchReturn format: expected 2 elements");

        // Read success_count (uint32)
        uint64 successCount64;
        (successCount64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx); // Read as uint64 first
        batchReturn.success_count = uint32(successCount64); // Convert to uint32

        // Read fail_codes array
        (len, byteIdx) = CBORDecoder.readFixedArray(cborData, byteIdx);
        batchReturn.fail_codes = new CommonTypes.FailCode[](len);
        for (uint256 i = 0; i < len; i++) {
            // Each FailCode is an array of 2 elements: idx, code
            uint256 failCodeLen;
            (failCodeLen, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );
            require(
                failCodeLen == 2,
                "Invalid FailCode format: expected 2 elements"
            );

            // Read idx (uint32)
            uint64 idx64;
            (idx64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx); // Read as uint64
            batchReturn.fail_codes[i].idx = uint32(idx64); // Convert to uint32

            // Read code (uint32)
            uint64 code64;
            (code64, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx); // Read as uint64
            batchReturn.fail_codes[i].code = uint32(code64); // Convert to uint32
        }
        nextByteIdx = byteIdx;
        return (batchReturn, nextByteIdx);
    }
}
