// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DDOSp
 * @notice Storage Provider management contract with multi-token support
 */
contract DDOSp is DDOTypes, Ownable {
    // SP Configuration Structs (Simplified & Gas Optimized)
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

    // Simplified SP Storage (owner-only approach)
    mapping(uint64 => SPConfig) public spConfigs; // actorId => config

    // SP Events
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

    // SP Errors
    error SPAlreadyRegistered();
    error SPNotRegistered();
    error InvalidSPConfig();
    error TokenNotSupportedBySP();
    error PieceSizeOutOfRange();
    error TermLengthOutOfRange();
    error TokenAlreadyExists();
    error TokenNotFound();
    error TokenInactive();
    error SPNotActive();

    // Modifiers
    modifier onlyValidSPConfig(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength
    ) {
        if (actorId == 0) {
            revert InvalidSPConfig();
        }
        if (paymentAddress == address(0)) {
            revert InvalidSPConfig();
        }
        if (minPieceSize == 0 || maxPieceSize < minPieceSize) {
            revert InvalidSPConfig();
        }
        if (minTermLength <= 0 || maxTermLength < minTermLength) {
            revert InvalidSPConfig();
        }
        _;
    }

    modifier onlyValidTokenConfigs(TokenConfig[] memory tokenConfigs) {
        if (tokenConfigs.length == 0) {
            revert InvalidSPConfig();
        }

        // Validate token configs
        for (uint256 i = 0; i < tokenConfigs.length; i++) {
            if (!tokenConfigs[i].isActive) {
                revert TokenInactive();
            }

            // Check for duplicate tokens
            for (uint256 j = i + 1; j < tokenConfigs.length; j++) {
                if (tokenConfigs[i].token == tokenConfigs[j].token) {
                    revert TokenAlreadyExists();
                }
            }
        }
        _;
    }

    modifier onlyRegisteredSP(uint64 actorId) {
        if (spConfigs[actorId].paymentAddress == address(0)) {
            revert SPNotRegistered();
        }
        _;
    }

    modifier onlyValidPieceForSP(PieceInfo[] memory pieceInfos) {
        for (uint256 i = 0; i < pieceInfos.length; i++) {
            uint64 actorId = pieceInfos[i].provider;

            // Check if SP is registered and active
            if (spConfigs[actorId].paymentAddress == address(0)) {
                revert SPNotRegistered();
            }
            if (!spConfigs[actorId].isActive) {
                revert SPNotActive();
            }

            SPConfig memory config = spConfigs[actorId];

            // Validate piece size
            if (
                pieceInfos[i].size < config.minPieceSize ||
                pieceInfos[i].size > config.maxPieceSize
            ) {
                revert PieceSizeOutOfRange();
            }

            // Validate term length
            if (
                pieceInfos[i].termMin < config.minTermLength ||
                pieceInfos[i].termMax > config.maxTermLength
            ) {
                revert TermLengthOutOfRange();
            }

            // Validate token support (will revert if token not supported or inactive)
            this.getSPActivePricePerBytePerEpoch(
                actorId,
                pieceInfos[i].paymentTokenAddress
            );
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    // Constants for time conversion
    uint256 public constant EPOCHS_PER_DAY = 2880; // ~30 second epochs
    uint256 public constant EPOCHS_PER_MONTH = 86400; // ~30 days

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
        // Check if SP already registered
        if (spConfigs[actorId].paymentAddress != address(0)) {
            revert SPAlreadyRegistered();
        }

        // Store SP configuration
        SPConfig storage newConfig = spConfigs[actorId];
        newConfig.paymentAddress = paymentAddress;
        newConfig.minPieceSize = minPieceSize;
        newConfig.maxPieceSize = maxPieceSize;
        newConfig.minTermLength = minTermLength;
        newConfig.maxTermLength = maxTermLength;
        newConfig.isActive = true;

        // Manually copy token configs from memory to storage
        for (uint256 i = 0; i < tokenConfigs.length; i++) {
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

        // Check if token already exists
        for (uint256 i = 0; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                revert TokenAlreadyExists();
            }
        }

        // Add new token
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

        // Find and update token
        for (uint256 i = 0; i < config.supportedTokens.length; i++) {
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

        revert TokenNotFound();
    }

    /**
     * @notice Remove token support from SP (Owner only)
     */
    function removeSPToken(
        uint64 actorId,
        address token
    ) external onlyOwner onlyRegisteredSP(actorId) {
        SPConfig storage config = spConfigs[actorId];

        // Find and remove token
        for (uint256 i = 0; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                // Move last element to current position and pop
                config.supportedTokens[i] = config.supportedTokens[
                    config.supportedTokens.length - 1
                ];
                config.supportedTokens.pop();

                emit SPTokenConfigUpdated(actorId, token, 0, false);
                return;
            }
        }

        revert TokenNotFound();
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

    // ======================== GETTER FUNCTIONS ========================

    /**
     * @notice Get complete SP configuration
     */
    function getSPConfig(
        uint64 actorId
    ) external view onlyRegisteredSP(actorId) returns (SPConfig memory) {
        return spConfigs[actorId];
    }

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
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                return (tokens[i].pricePerBytePerEpoch, tokens[i].isActive);
            }
        }

        return (0, false); // Token not found
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
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }

        revert TokenNotSupportedBySP();
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
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                if (tokens[i].isActive) {
                    // Convert: price per byte per epoch -> price per TB per month
                    // 1 TB = 10^12 bytes, 1 month = ~86400 epochs
                    pricePerTBPerMonth =
                        tokens[i].pricePerBytePerEpoch *
                        1e12 *
                        EPOCHS_PER_MONTH;
                    return (pricePerTBPerMonth, true);
                }
                return (0, false);
            }
        }

        return (0, false); // Token not found
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

        for (uint256 i = 0; i < length; i++) {
            tokens[i] = tokenConfigs[i].token;
            activeStatus[i] = tokenConfigs[i].isActive;

            if (tokenConfigs[i].isActive) {
                // Convert to price per GB per month
                pricesPerTBPerMonth[i] =
                    tokenConfigs[i].pricePerBytePerEpoch *
                    1e12 *
                    EPOCHS_PER_MONTH;
            } else {
                pricesPerTBPerMonth[i] = 0;
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
            revert SPNotActive();
        }
        if (
            pieceSize < config.minPieceSize || pieceSize > config.maxPieceSize
        ) {
            revert PieceSizeOutOfRange();
        }
        if (
            termLength < config.minTermLength ||
            termLength > config.maxTermLength
        ) {
            revert TermLengthOutOfRange();
        }

        // Find token pricing
        for (uint256 i = 0; i < config.supportedTokens.length; i++) {
            TokenConfig memory tokenConfig = config.supportedTokens[i];
            if (tokenConfig.token == token && tokenConfig.isActive) {
                totalCost =
                    tokenConfig.pricePerBytePerEpoch *
                    pieceSize *
                    uint64(termLength);
                return totalCost;
            }
        }

        revert TokenNotSupportedBySP();
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
        for (uint256 i = 0; i < tokens.length; i++) {
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
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }

        revert TokenNotSupportedBySP();
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
