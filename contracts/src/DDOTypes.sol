// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";

/**
 * @title DDOTypes
 * @notice Contains all type definitions, events, errors, and constants for the DDO system
 */
abstract contract DDOTypes {
    // Constants
    uint64 public constant DATACAP_RECEIVER_HOOK_METHOD_NUM = 3726118371;
    address public constant DATACAP_ACTOR_ETH_ADDRESS =
        0xfF00000000000000000000000000000000000007;

    // Mapping
    mapping(address => uint64[]) public allocationIdsByClient;

    // Structs
    struct PieceInfo {
        bytes pieceCid; // Piece CID as bytes
        uint64 size; // Piece size
        uint64 provider; // Provider/Miner ID
        int64 termMin; // Minimum term
        int64 termMax;
        int64 expirationOffset; // Expiration offset from current block
        string downloadURL; // Download URL for the piece
    }

    struct AllocationRequest {
        uint64 provider;
        bytes data; // Piece CID
        uint64 size;
        int64 termMin;
        int64 termMax;
        int64 expiration;
    }

    struct ProviderClaim {
        CommonTypes.FilActorId provider;
        CommonTypes.FilActorId claim;
    }

    // Verification Registry Response Types
    struct VerifregResponse {
        CommonTypes.BatchReturn allocationResults;
        CommonTypes.BatchReturn extensionResults;
        uint64[] newAllocations;
    }

    // Events
    event AllocationRequestCreated(
        uint64 provider,
        bytes data,
        uint64 size,
        int64 termMin,
        int64 termMax,
        int64 expiration,
        string downloadURL
    );

    event ReceiverParamsGenerated(bytes receiverParams);

    event DataCapTransferSuccess(uint256 totalDataCap, bytes recipientData);

    event DataCapTransferFailed(int256 exitCode, uint256 totalDataCap);

    event ReceivedDataCap(string message);

    event AllocationIdsStored(address indexed client, uint64[] allocationIds);

    // Errors
    error InvalidOperatorData();
    error InvalidAllocationRequest();
    error InvalidClaimExtensionRequest();
    error UnauthorizedMethod();
    error DataCapTransferError(int256 exitCode);
    error InvalidProvider();
    error GetClaimsFailed(int256 exitCode);
}
