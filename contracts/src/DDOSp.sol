// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DDOSp
 * @notice Storage Provider management contract with multi-token support
 */
contract DDOSp is DDOTypes, Ownable {
    /*//////////////////////////////////////////////////////////////
                             TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    struct TokenConfig {
        address token; // Token address (address(0) for ETH)
        uint256 pricePerBytePerEpoch; // Price in token's smallest unit
        bool isActive; // Whether SP accepts this token
    }

    struct SPConfig {
        address paymentAddress; // Where payments should be sent
        uint64 minPieceSize; // Minimum piece size in bytes
        uint64 maxPieceSize; // Maximum piece size in bytes
        int64 minTermLength; // Minimum term in epochs
        int64 maxTermLength; // Maximum term in epochs
        TokenConfig[] supportedTokens; // All supported tokens with pricing
        bool isActive; // Whether SP is accepting new deals
    }

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(uint64 => SPConfig) public spConfigs; // actorId => config

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant EPOCHS_PER_DAY = 2880; // ~30 second epochs
    uint256 public constant EPOCHS_PER_MONTH = 86400; // ~30 days

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyValidSPConfig(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength
    ) {
        if (actorId == 0) {
            revert DDOSp__InvalidSPConfig();
        }
        if (paymentAddress == address(0)) {
            revert DDOSp__InvalidSPConfig();
        }
        if (minPieceSize == 0 || maxPieceSize < minPieceSize) {
            revert DDOSp__InvalidSPConfig();
        }
        if (minTermLength <= 0 || maxTermLength < minTermLength) {
            revert DDOSp__InvalidSPConfig();
        }
        _;
    }

    modifier onlyValidTokenConfigs(TokenConfig[] memory tokenConfigs) {
        if (tokenConfigs.length == 0) {
            revert DDOSp__InvalidSPConfig();
        }

        for (uint256 i; i < tokenConfigs.length; i++) {
            if (!tokenConfigs[i].isActive) {
                revert DDOSp__TokenInactive();
            }

            for (uint256 j = i + 1; j < tokenConfigs.length; j++) {
                if (tokenConfigs[i].token == tokenConfigs[j].token) {
                    revert DDOSp__TokenAlreadyExists();
                }
            }
        }
        _;
    }

    modifier onlyRegisteredSP(uint64 actorId) {
        if (spConfigs[actorId].paymentAddress == address(0)) {
            revert DDOSp__SPNotRegistered();
        }
        _;
    }

    modifier onlyValidPieceForSP(PieceInfo[] memory pieceInfos) {
        for (uint256 i; i < pieceInfos.length; i++) {
            uint64 actorId = pieceInfos[i].provider;

            if (spConfigs[actorId].paymentAddress == address(0)) {
                revert DDOSp__SPNotRegistered();
            }
            if (!spConfigs[actorId].isActive) {
                revert DDOSp__SPNotActive();
            }

            SPConfig memory config = spConfigs[actorId];

            if (
                pieceInfos[i].size < config.minPieceSize ||
                pieceInfos[i].size > config.maxPieceSize
            ) {
                revert DDOSp__PieceSizeOutOfRange();
            }

            if (
                pieceInfos[i].termMin < config.minTermLength ||
                pieceInfos[i].termMax > config.maxTermLength
            ) {
                revert DDOSp__TermLengthOutOfRange();
            }

            this.getSPActivePricePerBytePerEpoch(
                actorId,
                pieceInfos[i].paymentTokenAddress
            );
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register as a Storage Provider (Owner only)
     * @param actorId The Filecoin actor ID of the storage provider
     * @param paymentAddress Address to receive payments
     * @param minPieceSize Minimum piece size in bytes
     * @param maxPieceSize Maximum piece size in bytes
     * @param minTermLength Minimum term in epochs
     * @param maxTermLength Maximum term in epochs
     * @param tokenConfigs Array of supported tokens with pricing
     */
    function registerSP(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength,
        TokenConfig[] memory tokenConfigs
    )
        external
        onlyOwner
        onlyValidSPConfig(
            actorId,
            paymentAddress,
            minPieceSize,
            maxPieceSize,
            minTermLength,
            maxTermLength
        )
        onlyValidTokenConfigs(tokenConfigs)
    {
        if (spConfigs[actorId].paymentAddress != address(0)) {
            revert DDOSp__SPAlreadyRegistered();
        }

        SPConfig storage newConfig = spConfigs[actorId];
        newConfig.paymentAddress = paymentAddress;
        newConfig.minPieceSize = minPieceSize;
        newConfig.maxPieceSize = maxPieceSize;
        newConfig.minTermLength = minTermLength;
        newConfig.maxTermLength = maxTermLength;
        newConfig.isActive = true;

        for (uint256 i; i < tokenConfigs.length; i++) {
            newConfig.supportedTokens.push(tokenConfigs[i]);
        }

        emit SPRegistered(
            actorId,
            paymentAddress,
            minPieceSize,
            maxPieceSize,
            minTermLength,
            maxTermLength,
            tokenConfigs.length
        );
    }

    /**
     * @notice Update SP basic configuration (Owner only)
     */
    function updateSPConfig(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength
    )
        external
        onlyOwner
        onlyRegisteredSP(actorId)
        onlyValidSPConfig(
            actorId,
            paymentAddress,
            minPieceSize,
            maxPieceSize,
            minTermLength,
            maxTermLength
        )
    {
        SPConfig storage config = spConfigs[actorId];
        config.paymentAddress = paymentAddress;
        config.minPieceSize = minPieceSize;
        config.maxPieceSize = maxPieceSize;
        config.minTermLength = minTermLength;
        config.maxTermLength = maxTermLength;

        emit SPConfigUpdated(actorId);
    }

    /**
     * @notice Add new token support to SP (Owner only)
     */
    function addSPToken(
        uint64 actorId,
        address token,
        uint256 pricePerBytePerEpoch
    ) external onlyOwner onlyRegisteredSP(actorId) {
        SPConfig storage config = spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                revert DDOSp__TokenAlreadyExists();
            }
        }

        config.supportedTokens.push(
            TokenConfig({
                token: token,
                pricePerBytePerEpoch: pricePerBytePerEpoch,
                isActive: true
            })
        );

        emit SPTokenConfigUpdated(actorId, token, pricePerBytePerEpoch, true);
    }

    /**
     * @notice Update existing token configuration (Owner only)
     */
    function updateSPToken(
        uint64 actorId,
        address token,
        uint256 pricePerBytePerEpoch,
        bool isActive
    ) external onlyOwner onlyRegisteredSP(actorId) {
        SPConfig storage config = spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                config
                    .supportedTokens[i]
                    .pricePerBytePerEpoch = pricePerBytePerEpoch;
                config.supportedTokens[i].isActive = isActive;

                emit SPTokenConfigUpdated(
                    actorId,
                    token,
                    pricePerBytePerEpoch,
                    isActive
                );
                return;
            }
        }

        revert DDOSp__TokenNotFound();
    }

    /**
     * @notice Remove token support from SP (Owner only)
     */
    function removeSPToken(
        uint64 actorId,
        address token
    ) external onlyOwner onlyRegisteredSP(actorId) {
        SPConfig storage config = spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                config.supportedTokens[i] = config.supportedTokens[
                    config.supportedTokens.length - 1
                ];
                config.supportedTokens.pop();

                emit SPTokenConfigUpdated(actorId, token, 0, false);
                return;
            }
        }

        revert DDOSp__TokenNotFound();
    }

    /**
     * @notice Deactivate SP (Owner only)
     */
    function deactivateSP(
        uint64 actorId
    ) external onlyOwner onlyRegisteredSP(actorId) {
        spConfigs[actorId].isActive = false;
        emit SPDeactivated(actorId);
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get token price for specific SP and token (per epoch)
     */
    function getSPTokenPrice(
        uint64 actorId,
        address token
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (uint256 price, bool isActive)
    {
        TokenConfig[] memory tokens = spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                return (tokens[i].pricePerBytePerEpoch, tokens[i].isActive);
            }
        }

        return (0, false);
    }

    /**
     * @notice Get SP's price per byte per epoch for a specific active token
     * @param actorId The SP actor ID
     * @param token The token address
     * @return pricePerBytePerEpoch The price per byte per epoch
     * @dev Reverts if token is not found or not active
     */
    function getSPActivePricePerBytePerEpoch(
        uint64 actorId,
        address token
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (uint256 pricePerBytePerEpoch)
    {
        TokenConfig[] memory tokens = spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }

        revert DDOSp__TokenNotSupportedBySP();
    }

    /**
     * @notice Get token price per TB per month (user-friendly)
     */
    function getSPTokenPricePerTBPerMonth(
        uint64 actorId,
        address token
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (uint256 pricePerTBPerMonth, bool isActive)
    {
        TokenConfig[] memory tokens = spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                if (tokens[i].isActive) {
                    pricePerTBPerMonth =
                        tokens[i].pricePerBytePerEpoch *
                        1e12 *
                        EPOCHS_PER_MONTH;
                    return (pricePerTBPerMonth, true);
                }
                return (0, false);
            }
        }

        return (0, false);
    }

    /**
     * @notice Get all supported tokens with their monthly prices for SP
     */
    function getSPAllTokenPricesPerMonth(
        uint64 actorId
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (
            address[] memory tokens,
            uint256[] memory pricesPerTBPerMonth,
            bool[] memory activeStatus
        )
    {
        TokenConfig[] memory tokenConfigs = spConfigs[actorId].supportedTokens;
        uint256 length = tokenConfigs.length;

        tokens = new address[](length);
        pricesPerTBPerMonth = new uint256[](length);
        activeStatus = new bool[](length);

        for (uint256 i; i < length; i++) {
            tokens[i] = tokenConfigs[i].token;
            activeStatus[i] = tokenConfigs[i].isActive;

            if (tokenConfigs[i].isActive) {
                pricesPerTBPerMonth[i] =
                    tokenConfigs[i].pricePerBytePerEpoch *
                    1e12 *
                    EPOCHS_PER_MONTH;
            }
        }

        return (tokens, pricesPerTBPerMonth, activeStatus);
    }

    /**
     * @notice Calculate total cost for storage deal
     */
    function calculateStorageCost(
        uint64 actorId,
        address token,
        uint64 pieceSize,
        int64 termLength
    ) external view onlyRegisteredSP(actorId) returns (uint256 totalCost) {
        SPConfig memory config = spConfigs[actorId];
        if (!config.isActive) {
            revert DDOSp__SPNotActive();
        }
        if (
            pieceSize < config.minPieceSize || pieceSize > config.maxPieceSize
        ) {
            revert DDOSp__PieceSizeOutOfRange();
        }
        if (
            termLength < config.minTermLength ||
            termLength > config.maxTermLength
        ) {
            revert DDOSp__TermLengthOutOfRange();
        }

        for (uint256 i; i < config.supportedTokens.length; i++) {
            TokenConfig memory tokenConfig = config.supportedTokens[i];
            if (tokenConfig.token == token && tokenConfig.isActive) {
                totalCost =
                    tokenConfig.pricePerBytePerEpoch *
                    pieceSize *
                    uint64(termLength);
                return totalCost;
            }
        }

        revert DDOSp__TokenNotSupportedBySP();
    }

    /**
     * @notice Check if SP supports specific token
     */
    function isSPTokenSupported(
        uint64 actorId,
        address token
    ) external view returns (bool) {
        if (spConfigs[actorId].paymentAddress == address(0)) return false;

        TokenConfig[] memory tokens = spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Check if SP is registered and active
     */
    function isSPActive(uint64 actorId) external view returns (bool) {
        return
            spConfigs[actorId].paymentAddress != address(0) &&
            spConfigs[actorId].isActive;
    }

    /**
     * @notice Get SP basic info
     */
    function getSPBasicInfo(
        uint64 actorId
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (
            address paymentAddress,
            bool isActive,
            uint256 supportedTokenCount,
            uint64 minPieceSize,
            uint64 maxPieceSize
        )
    {
        SPConfig memory config = spConfigs[actorId];
        return (
            config.paymentAddress,
            config.isActive,
            config.supportedTokens.length,
            config.minPieceSize,
            config.maxPieceSize
        );
    }

    /**
     * @notice Get and validate SP's price per byte per epoch for a specific token
     * @param actorId The SP actor ID
     * @param token The token address
     * @return pricePerBytePerEpoch The price per byte per epoch
     * @dev Reverts if token is not supported or inactive
     */
    function getAndValidateSPPrice(
        uint64 actorId,
        address token
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (uint256 pricePerBytePerEpoch)
    {
        TokenConfig[] memory tokens = spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }

        revert DDOSp__TokenNotSupportedBySP();
    }

    /**
     * @notice Get all supported tokens for a storage provider
     * @param actorId The SP actor ID
     * @return tokenConfigs Array of all token configurations for the SP
     */
    function getSPSupportedTokens(
        uint64 actorId
    )
        external
        view
        onlyRegisteredSP(actorId)
        returns (TokenConfig[] memory tokenConfigs)
    {
        return spConfigs[actorId].supportedTokens;
    }
}
