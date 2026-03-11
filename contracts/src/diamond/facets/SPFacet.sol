// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDDOStorage} from "../libraries/LibDDOStorage.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";

contract SPFacet {
    /*//////////////////////////////////////////////////////////////
                    EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function registerSP(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength,
        LibDDOStorage.TokenConfig[] memory tokenConfigs
    ) external {
        LibDiamond.enforceIsContractOwner();
        _validateSPConfig(actorId, paymentAddress, minPieceSize, maxPieceSize, minTermLength, maxTermLength);
        _validateTokenConfigs(tokenConfigs);

        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();

        if (s.spConfigs[actorId].paymentAddress != address(0)) {
            revert LibDDOStorage.DDOSp__SPAlreadyRegistered();
        }

        LibDDOStorage.SPConfig storage newConfig = s.spConfigs[actorId];
        newConfig.paymentAddress = paymentAddress;
        newConfig.minPieceSize = minPieceSize;
        newConfig.maxPieceSize = maxPieceSize;
        newConfig.minTermLength = minTermLength;
        newConfig.maxTermLength = maxTermLength;
        newConfig.isActive = true;

        for (uint256 i; i < tokenConfigs.length; i++) {
            newConfig.supportedTokens.push(tokenConfigs[i]);
        }

        s.registeredSPIds.push(actorId);

        emit LibDDOStorage.SPRegistered(
            actorId, paymentAddress, minPieceSize, maxPieceSize, minTermLength, maxTermLength, tokenConfigs.length
        );
    }

    function updateSPConfig(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);
        _validateSPConfig(actorId, paymentAddress, minPieceSize, maxPieceSize, minTermLength, maxTermLength);

        LibDDOStorage.SPConfig storage config = s.spConfigs[actorId];
        config.paymentAddress = paymentAddress;
        config.minPieceSize = minPieceSize;
        config.maxPieceSize = maxPieceSize;
        config.minTermLength = minTermLength;
        config.maxTermLength = maxTermLength;

        emit LibDDOStorage.SPConfigUpdated(actorId);
    }

    function addSPToken(uint64 actorId, address token, uint256 pricePerBytePerEpoch) external {
        LibDiamond.enforceIsContractOwner();
        if (token == address(0)) revert LibDDOStorage.DDOSp__InvalidSPConfig();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.SPConfig storage config = s.spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                revert LibDDOStorage.DDOSp__TokenAlreadyExists();
            }
        }

        config.supportedTokens.push(
            LibDDOStorage.TokenConfig({token: token, pricePerBytePerEpoch: pricePerBytePerEpoch, isActive: true})
        );

        emit LibDDOStorage.SPTokenConfigUpdated(actorId, token, pricePerBytePerEpoch, true);
    }

    function updateSPToken(uint64 actorId, address token, uint256 pricePerBytePerEpoch, bool isActive) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.SPConfig storage config = s.spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                config.supportedTokens[i].pricePerBytePerEpoch = pricePerBytePerEpoch;
                config.supportedTokens[i].isActive = isActive;
                emit LibDDOStorage.SPTokenConfigUpdated(actorId, token, pricePerBytePerEpoch, isActive);
                return;
            }
        }

        revert LibDDOStorage.DDOSp__TokenNotFound();
    }

    function removeSPToken(uint64 actorId, address token) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.SPConfig storage config = s.spConfigs[actorId];

        for (uint256 i; i < config.supportedTokens.length; i++) {
            if (config.supportedTokens[i].token == token) {
                config.supportedTokens[i] = config.supportedTokens[config.supportedTokens.length - 1];
                config.supportedTokens.pop();
                emit LibDDOStorage.SPTokenConfigUpdated(actorId, token, 0, false);
                return;
            }
        }

        revert LibDDOStorage.DDOSp__TokenNotFound();
    }

    function deactivateSP(uint64 actorId) external {
        LibDiamond.enforceIsContractOwner();
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);
        s.spConfigs[actorId].isActive = false;
        emit LibDDOStorage.SPDeactivated(actorId);
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function spConfigs(uint64 actorId)
        external
        view
        returns (
            address paymentAddress,
            uint64 minPieceSize,
            uint64 maxPieceSize,
            int64 minTermLength,
            int64 maxTermLength,
            bool isActive
        )
    {
        LibDDOStorage.SPConfig storage config = LibDDOStorage.getStorage().spConfigs[actorId];
        return (
            config.paymentAddress,
            config.minPieceSize,
            config.maxPieceSize,
            config.minTermLength,
            config.maxTermLength,
            config.isActive
        );
    }

    function getSPTokenPrice(uint64 actorId, address token) external view returns (uint256 price, bool isActive) {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                return (tokens[i].pricePerBytePerEpoch, tokens[i].isActive);
            }
        }
        return (0, false);
    }

    function getSPActivePricePerBytePerEpoch(uint64 actorId, address token)
        external
        view
        returns (uint256 pricePerBytePerEpoch)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }
        revert LibDDOStorage.DDOSp__TokenNotSupportedBySP();
    }

    function getSPTokenPricePerTBPerMonth(uint64 actorId, address token)
        external
        view
        returns (uint256 pricePerTBPerMonth, bool isActive)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token) {
                if (tokens[i].isActive) {
                    pricePerTBPerMonth = tokens[i].pricePerBytePerEpoch * 1e12 * LibDDOStorage.EPOCHS_PER_MONTH;
                    return (pricePerTBPerMonth, true);
                }
                return (0, false);
            }
        }
        return (0, false);
    }

    function getSPAllTokenPricesPerMonth(uint64 actorId)
        external
        view
        returns (address[] memory tokens, uint256[] memory pricesPerTBPerMonth, bool[] memory activeStatus)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.TokenConfig[] memory tokenConfigs = s.spConfigs[actorId].supportedTokens;
        uint256 length = tokenConfigs.length;

        tokens = new address[](length);
        pricesPerTBPerMonth = new uint256[](length);
        activeStatus = new bool[](length);

        for (uint256 i; i < length; i++) {
            tokens[i] = tokenConfigs[i].token;
            activeStatus[i] = tokenConfigs[i].isActive;
            if (tokenConfigs[i].isActive) {
                pricesPerTBPerMonth[i] = tokenConfigs[i].pricePerBytePerEpoch * 1e12 * LibDDOStorage.EPOCHS_PER_MONTH;
            }
        }
    }

    function calculateStorageCost(uint64 actorId, address token, uint64 pieceSize, int64 termLength)
        external
        view
        returns (uint256 totalCost)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.SPConfig memory config = s.spConfigs[actorId];
        if (!config.isActive) revert LibDDOStorage.DDOSp__SPNotActive();
        if (pieceSize < config.minPieceSize || pieceSize > config.maxPieceSize) {
            revert LibDDOStorage.DDOSp__PieceSizeOutOfRange();
        }
        if (termLength < config.minTermLength || termLength > config.maxTermLength) {
            revert LibDDOStorage.DDOSp__TermLengthOutOfRange();
        }

        for (uint256 i; i < config.supportedTokens.length; i++) {
            LibDDOStorage.TokenConfig memory tokenConfig = config.supportedTokens[i];
            if (tokenConfig.token == token && tokenConfig.isActive) {
                return tokenConfig.pricePerBytePerEpoch * pieceSize * uint64(termLength);
            }
        }
        revert LibDDOStorage.DDOSp__TokenNotSupportedBySP();
    }

    function isSPTokenSupported(uint64 actorId, address token) external view returns (bool) {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        if (s.spConfigs[actorId].paymentAddress == address(0)) return false;

        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) return true;
        }
        return false;
    }

    function isSPActive(uint64 actorId) external view returns (bool) {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        return s.spConfigs[actorId].paymentAddress != address(0) && s.spConfigs[actorId].isActive;
    }

    function getSPBasicInfo(uint64 actorId)
        external
        view
        returns (
            address paymentAddress,
            bool isActive,
            uint256 supportedTokenCount,
            uint64 minPieceSize,
            uint64 maxPieceSize
        )
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.SPConfig memory config = s.spConfigs[actorId];
        return (
            config.paymentAddress,
            config.isActive,
            config.supportedTokens.length,
            config.minPieceSize,
            config.maxPieceSize
        );
    }

    function getAndValidateSPPrice(uint64 actorId, address token)
        external
        view
        returns (uint256 pricePerBytePerEpoch)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);

        LibDDOStorage.TokenConfig[] memory tokens = s.spConfigs[actorId].supportedTokens;
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i].token == token && tokens[i].isActive) {
                return tokens[i].pricePerBytePerEpoch;
            }
        }
        revert LibDDOStorage.DDOSp__TokenNotSupportedBySP();
    }

    function getSPSupportedTokens(uint64 actorId)
        external
        view
        returns (LibDDOStorage.TokenConfig[] memory tokenConfigs)
    {
        LibDDOStorage.DDOState storage s = LibDDOStorage.getStorage();
        _enforceRegisteredSP(s, actorId);
        return s.spConfigs[actorId].supportedTokens;
    }

    /*//////////////////////////////////////////////////////////////
                      INTERNAL VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateSPConfig(
        uint64 actorId,
        address paymentAddress,
        uint64 minPieceSize,
        uint64 maxPieceSize,
        int64 minTermLength,
        int64 maxTermLength
    ) internal pure {
        if (actorId == 0) revert LibDDOStorage.DDOSp__InvalidSPConfig();
        if (paymentAddress == address(0)) revert LibDDOStorage.DDOSp__InvalidSPConfig();
        if (minPieceSize == 0 || maxPieceSize < minPieceSize) revert LibDDOStorage.DDOSp__InvalidSPConfig();
        if (minTermLength <= 0 || maxTermLength < minTermLength) revert LibDDOStorage.DDOSp__InvalidSPConfig();
    }

    function _validateTokenConfigs(LibDDOStorage.TokenConfig[] memory tokenConfigs) internal pure {
        if (tokenConfigs.length == 0) revert LibDDOStorage.DDOSp__InvalidSPConfig();

        for (uint256 i; i < tokenConfigs.length; i++) {
            if (tokenConfigs[i].token == address(0)) revert LibDDOStorage.DDOSp__InvalidSPConfig();
            if (!tokenConfigs[i].isActive) revert LibDDOStorage.DDOSp__TokenInactive();
            for (uint256 j = i + 1; j < tokenConfigs.length; j++) {
                if (tokenConfigs[i].token == tokenConfigs[j].token) {
                    revert LibDDOStorage.DDOSp__TokenAlreadyExists();
                }
            }
        }
    }

    function _enforceRegisteredSP(LibDDOStorage.DDOState storage s, uint64 actorId) internal view {
        if (s.spConfigs[actorId].paymentAddress == address(0)) {
            revert LibDDOStorage.DDOSp__SPNotRegistered();
        }
    }
}
