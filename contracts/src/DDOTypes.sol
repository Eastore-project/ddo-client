// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {IPayments} from "./IPayments.sol";

/**
 * @title DDOTypes
 * @notice Contains all type definitions, events, errors, and constants for the DDO system
 */
abstract contract DDOTypes {
    // Constants
    uint64 public constant DATACAP_RECEIVER_HOOK_METHOD_NUM = 3726118371;
    address public constant DATACAP_ACTOR_ETH_ADDRESS =
        0xfF00000000000000000000000000000000000007;
    // Payment system constants and variables
    uint256 public constant MAX_COMMISSION_RATE_BPS = 100; // 1% maximum commission
    uint256 public commissionRateBps = 50; // Default 0.5% commission rate

    // Payments contract interface
    IPayments public paymentsContract;

    // Mapping
    mapping(address => uint64[]) public allocationIdsByClient;
    mapping(uint64 => uint64) public allocationIdToProvider;
    mapping(uint64 => uint256) public allocationIdToRailId;
    mapping(uint64 => uint64[]) public allocationIdsByProvider;

    // Structs
    struct PieceInfo {
        bytes pieceCid; // Piece CID as bytes
        uint64 size; // Piece size
        uint64 provider; // Provider/Miner ID
        int64 termMin; // Minimum term
        int64 termMax;
        int64 expirationOffset; // Expiration offset from current block
        string downloadURL; // Download URL for the piece
        address paymentTokenAddress; // Token address client is willing to pay with
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

    event RailCreated(
        address indexed client,
        address indexed storageProvider,
        address indexed token,
        uint256 railId,
        uint64 providerId,
        uint64 allocationId
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
    error PaymentsContractNotSet();
    error RailCreationFailed();
    error InvalidPaymentsContract();
    error CommissionRateExceedsMaximum();
    error NoPieceInfosProvided();
    error InvalidPieceSize();
    error InvalidProviderId();
    error AllocationCountMismatch();
    error AllocationNotFound();
    error FailedToGetClaimInfo();
    error NoClaimsFoundForAllocation();
    error NoRailFoundForAllocation();
    error InvalidTermStart();
    error CurrentBlockBeforeTermStart();
    error NoAllocationsFoundForProvider();
}
