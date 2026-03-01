// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";

/**
 * @title DDOTypes
 * @notice Contains all type definitions, events, errors, and constants for the DDO system
 */
abstract contract DDOTypes {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint64 public constant DATACAP_RECEIVER_HOOK_METHOD_NUM = 3726118371;
    address public constant DATACAP_ACTOR_ETH_ADDRESS =
        0xfF00000000000000000000000000000000000007;
    uint256 public constant MAX_COMMISSION_RATE_BPS = 100; // 1% maximum commission
    uint64 public constant SECTOR_CONTENT_CHANGED_METHOD_NUM = 2034386435;

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public commissionRateBps = 50; // Default 0.5% commission rate

    // Anti-spam fixed lockup applied per allocation until activation (owner-configurable)
    uint256 public allocationLockupAmount = 1 * 10 ** 18; // Default 1 token

    // Payments contract interface
    FilecoinPayV1 public paymentsContract;

    /*//////////////////////////////////////////////////////////////
                             TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    // Allocation info struct - tracks all data needed for notification-based activation
    // Packed for storage efficiency: 4 slots instead of 5
    struct AllocationInfo {
        address client;          // 20 bytes ─┐ slot 0 (29 bytes)
        uint64 provider;         //  8 bytes  │
        bool activated;          //  1 byte  ─┘
        bytes32 pieceCidHash;    // 32 bytes ── slot 1
        address paymentToken;    // 20 bytes ─┐ slot 2 (28 bytes)
        uint64 pieceSize;        //  8 bytes ─┘
        uint256 railId;          // 32 bytes ── slot 3
    }

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

    struct VerifregResponse {
        CommonTypes.BatchReturn allocationResults;
        CommonTypes.BatchReturn extensionResults;
        uint64[] newAllocations;
    }

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(uint64 => AllocationInfo) public allocationInfos;
    mapping(address => uint64[]) public allocationIdsByClient;
    mapping(uint64 => uint64[]) public allocationIdsByProvider;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

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

    event AllocationActivated(
        uint64 indexed allocationId,
        uint64 indexed provider,
        uint64 sector,
        uint256 railId,
        uint256 paymentRate
    );

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyValidClaimForClient(address clientAddress, uint64 claimId) {
        bool claimFoundLocally;
        uint64[] memory clientAllocations = allocationIdsByClient[
            clientAddress
        ];
        for (uint256 i; i < clientAllocations.length; i++) {
            if (clientAllocations[i] == claimId) {
                claimFoundLocally = true;
                break;
            }
        }
        if (!claimFoundLocally) {
            revert DDOTypes__InvalidClaimIdForClient();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error DDOTypes__InvalidOperatorData();
    error DDOTypes__InvalidAllocationRequest();
    error DDOTypes__InvalidClaimExtensionRequest();
    error DDOTypes__UnauthorizedMethod();
    error DDOTypes__DataCapTransferError(int256 exitCode);
    error DDOTypes__InvalidProvider();
    error DDOTypes__GetClaimsFailed(int256 exitCode);
    error DDOTypes__InvalidClaimIdForClient();
    error DDOTypes__NoClaimsFound();
    error DDOTypes__PaymentsContractNotSet();
    error DDOTypes__RailCreationFailed();
    error DDOTypes__InvalidPaymentsContract();
    error DDOTypes__CommissionRateExceedsMaximum();
    error DDOTypes__NoPieceInfosProvided();
    error DDOTypes__InvalidPieceSize();
    error DDOTypes__InvalidProviderId();
    error DDOTypes__AllocationCountMismatch();
    error DDOTypes__AllocationNotFound();
    error DDOTypes__NoRailFoundForAllocation();
    error DDOTypes__NoAllocationsFoundForProvider();
    error DDOTypes__NotMinerActor();
    error DDOTypes__AllocationAlreadyActivated();
    error DDOTypes__AllocationNotActivated();
    error DDOTypes__PieceSizeMismatch();
    error DDOTypes__ProviderMismatch();
    error DDOTypes__PieceCidMismatch();
    error DDOTypes__InvalidCBORCodec();
    error DDOTypes__InvalidVerifregResponse();
    error DDOTypes__InvalidBatchReturnFormat();
    error DDOTypes__InvalidFailCodeFormat();
}
