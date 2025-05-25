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
        uint256 operatorDataLength;
        uint256 allocationRequestsLength;
        uint256 claimExtensionRequestsLength;
        uint64 provider;
        uint64 claimId;
        uint64 size;
        bytes memory data;
        int64 termMin;
        int64 termMax;
        int64 expiration;
        uint256 byteIdx = 0;

        (operatorDataLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        if (operatorDataLength != 2) revert DDOTypes.InvalidOperatorData();

        (allocationRequestsLength, byteIdx) = CBORDecoder.readFixedArray(
            cborData,
            byteIdx
        );
        allocationRequests = new DDOTypes.AllocationRequest[](
            allocationRequestsLength
        );

        for (uint256 i = 0; i < allocationRequestsLength; i++) {
            uint256 allocationRequestLength;
            (allocationRequestLength, byteIdx) = CBORDecoder.readFixedArray(
                cborData,
                byteIdx
            );

            if (allocationRequestLength != 6) {
                revert DDOTypes.InvalidAllocationRequest();
            }

            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            CommonTypes.Cid memory cidStruct;
            (cidStruct, byteIdx) = FilecoinCBOR.readCid(cborData, byteIdx); // Use FilecoinCBOR.readCid
            data = cidStruct.data;
            (size, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            (termMin, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMin
            (termMax, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMax
            (expiration, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // expiration

            allocationRequests[i] = DDOTypes.AllocationRequest({
                provider: provider,
                data: data,
                size: size,
                termMin: termMin,
                termMax: termMax,
                expiration: expiration
            });
        }

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

            (provider, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            (claimId, byteIdx) = CBORDecoder.readUInt64(cborData, byteIdx);
            // slither-disable-start unused-return
            (, byteIdx) = CBORDecoder.readInt64(cborData, byteIdx); // termMax
            // slither-disable-end unused-return

            claimExtensions[i].provider = CommonTypes.FilActorId.wrap(provider);
            claimExtensions[i].claim = CommonTypes.FilActorId.wrap(claimId);
        }
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
}
