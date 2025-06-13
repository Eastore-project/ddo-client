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
    mapping(uint64 => uint64) public allocationIdToProvider;

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
    event AllocationCreated(
        address indexed client,
        uint64 indexed allocationId,
        uint64 indexed provider,
        bytes data,
        uint64 size,
        int64 termMin,
        int64 termMax,
        int64 expiration,
        string downloadURL
    );

    event DataCapTransferSuccess(uint256 totalDataCap, bytes recipientData);

    event ReceivedDataCap(string message);

    // Modifiers
    modifier onlyValidClaimForClient(address clientAddress, uint64 claimId) {
        bool claimFoundLocally = false;
        uint64[] memory clientAllocations = allocationIdsByClient[
            clientAddress
        ];
        for (uint256 i = 0; i < clientAllocations.length; i++) {
            if (clientAllocations[i] == claimId) {
                claimFoundLocally = true;
                break;
            }
        }
        if (!claimFoundLocally) {
            revert InvalidClaimIdForClient();
        }
        _;
    }

    // Errors
    error InvalidOperatorData();
    error InvalidAllocationRequest();
    error InvalidClaimExtensionRequest();
    error UnauthorizedMethod();
    error DataCapTransferError(int256 exitCode);
    error InvalidProvider();
    error GetClaimsFailed(int256 exitCode);
    error InvalidClaimIdForClient();
    error NoClaimsFound();
}
