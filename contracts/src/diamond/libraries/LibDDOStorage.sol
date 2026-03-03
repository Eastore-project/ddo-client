// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {LibDiamond} from "./LibDiamond.sol";

library LibDDOStorage {
    bytes32 constant STORAGE_POSITION = keccak256("ddo.client.diamond.storage");

    /*//////////////////////////////////////////////////////////////
                             TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct AllocationInfo {
        address client;               // 20 bytes ─┐ slot 0 (29 bytes)
        uint64 provider;              //  8 bytes  │
        bool activated;               //  1 byte  ─┘
        bytes32 pieceCidHash;         // 32 bytes ── slot 1
        address paymentToken;         // 20 bytes ─┐ slot 2 (28 bytes)
        uint64 pieceSize;             //  8 bytes ─┘
        uint256 railId;               // 32 bytes ── slot 3
        uint256 pricePerBytePerEpoch; // 32 bytes ── slot 4 (locked at allocation time)
        uint64 sectorNumber;          //  8 bytes ── slot 5 (set during activation)
        // NOTE: sectorNumber defaults to 0, which is also a valid Filecoin sector number.
        // Use the `activated` flag to distinguish unassigned (activated=false, sectorNumber=0)
        // from an allocation genuinely sealed into sector 0 (activated=true, sectorNumber=0).
        // The payment rail rate is 0 for non-activated allocations, so settlement is a no-op.
    }

    struct TokenConfig {
        address token;
        uint256 pricePerBytePerEpoch;
        bool isActive;
    }

    struct SPConfig {
        address paymentAddress;
        uint64 minPieceSize;
        uint64 maxPieceSize;
        int64 minTermLength;
        int64 maxTermLength;
        TokenConfig[] supportedTokens;
        bool isActive;
    }

    struct PieceInfo {
        bytes pieceCid;
        uint64 size;
        uint64 provider;
        int64 termMin;
        int64 termMax;
        int64 expirationOffset;
        string downloadURL;
        address paymentTokenAddress;
    }

    struct AllocationRequest {
        uint64 provider;
        bytes data;
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
                                STATE
    //////////////////////////////////////////////////////////////*/

    struct DDOState {
        FilecoinPayV1 paymentsContract;
        uint256 commissionRateBps;
        uint256 allocationLockupAmount;
        mapping(uint64 => AllocationInfo) allocationInfos;
        mapping(address => uint64[]) allocationIdsByClient;
        mapping(uint64 => uint64[]) allocationIdsByProvider;
        mapping(uint64 => SPConfig) spConfigs;
        uint256 reentrancyStatus; // 1 = not entered, 2 = entered
        // Mock miner mapping (used only in test facet, unused in production)
        mapping(address => uint64) mockMinerActorIds;
        uint64[] registeredSPIds;
        bool paused;
        mapping(uint256 => uint64) railIdToAllocationId;
        mapping(uint64 => mapping(uint64 => bool)) blacklistedSectors; // providerId => sectorNumber => blacklisted
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint64 constant DATACAP_RECEIVER_HOOK_METHOD_NUM = 3726118371;
    address constant DATACAP_ACTOR_ETH_ADDRESS = 0xfF00000000000000000000000000000000000007;
    uint256 constant MAX_COMMISSION_RATE_BPS = 100; // 1% maximum commission
    uint64 constant SECTOR_CONTENT_CHANGED_METHOD_NUM = 2034386435;
    uint256 constant EPOCHS_PER_DAY = 2880;
    uint256 constant EPOCHS_PER_MONTH = 86400;

    // Reentrancy constants
    uint256 constant NOT_ENTERED = 1;
    uint256 constant ENTERED = 2;

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

    event SPRegistered(
        uint64 indexed actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength,
        uint256 tokenCount
    );

    event SPTokenConfigUpdated(
        uint64 indexed actorId,
        address indexed token,
        uint256 pricePerBytePerEpoch,
        bool isActive
    );

    event SPConfigUpdated(uint64 indexed actorId);
    event SPDeactivated(uint64 indexed actorId);
    event SectorBlacklisted(uint64 indexed providerId, uint64 sectorNumber, bool blacklisted);

    // Pause events (matching OZ Pausable)
    event Paused(address account);
    event Unpaused(address account);

    // Admin parameter change events (F-16)
    event AllocationLockupAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event CommissionRateUpdated(uint256 oldRate, uint256 newRate);
    event PaymentsContractUpdated(address oldContract, address newContract);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    // DDOTypes errors
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

    // DDOSp errors
    error DDOSp__SPAlreadyRegistered();
    error DDOSp__SPNotRegistered();
    error DDOSp__InvalidSPConfig();
    error DDOSp__TokenNotSupportedBySP();
    error DDOSp__PieceSizeOutOfRange();
    error DDOSp__TermLengthOutOfRange();
    error DDOSp__TokenAlreadyExists();
    error DDOSp__TokenNotFound();
    error DDOSp__TokenInactive();
    error DDOSp__SPNotActive();

    // Allocation collision error (F-2)
    error DDOTypes__AllocationAlreadyExists();

    // Pause errors (matching OZ Pausable)
    error EnforcedPause();
    error ExpectedPause();

    // Reentrancy error
    error ReentrancyGuardReentrantCall();

    // Blacklist error
    error DDOTypes__SectorBlacklisted();

    /*//////////////////////////////////////////////////////////////
                            STORAGE ACCESS
    //////////////////////////////////////////////////////////////*/

    function getStorage() internal pure returns (DDOState storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS AS FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function enforceNotPaused() internal view {
        if (getStorage().paused) revert EnforcedPause();
    }

    function enforceNonReentrant() internal {
        DDOState storage s = getStorage();
        if (s.reentrancyStatus == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }
        s.reentrancyStatus = ENTERED;
    }

    function clearReentrancy() internal {
        getStorage().reentrancyStatus = NOT_ENTERED;
    }

    function enforceIsContractOwner() internal view {
        LibDiamond.enforceIsContractOwner();
    }
}
