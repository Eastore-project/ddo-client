// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {DDOSp} from "./DDOSp.sol";
import {IPayments} from "./IPayments.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";

/// @title MockDDO
/// @notice Mock functions for DDO Client for testing purposes
/// @dev This contract contains all mock functions that can be easily removed by removing inheritance
abstract contract MockDDO is DDOTypes, DDOSp {
    // TODO: Remove this function after testing
    /**
     * @notice Create allocation requests without transferring DataCap (for testing)
     * @param pieceInfos Array of piece information to create allocations for
     * @return totalDataCap Total datacap required for all allocations
     * @return receiverParams Serialized receiver params as bytes
     */
    function mockCreateAllocationRequests(
        PieceInfo[] memory pieceInfos
    )
        external
        onlyValidPieceForSP(pieceInfos)
        returns (uint256 totalDataCap, bytes memory receiverParams)
    {
        require(pieceInfos.length > 0, "No piece infos provided");
        require(
            address(paymentsContract) != address(0),
            "Payments contract not set"
        );

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );
        totalDataCap = 0;

        int64 currentEpoch = int64(int256(block.number));

        // Create allocation requests from piece infos
        for (uint256 i = 0; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            // Validate piece size is reasonable (basic validation)
            require(info.size > 0, "Invalid piece size");
            require(info.provider > 0, "Invalid provider ID");

            int64 expiration = currentEpoch + info.expirationOffset;

            allocationRequests[i] = AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: expiration
            });

            totalDataCap += info.size;

            // Create mock allocation ID for testing (block.timestamp + index)
            uint64 mockAllocationId = uint64(block.timestamp + i + 1);

            // Store allocation ID for client
            allocationIdsByClient[msg.sender].push(mockAllocationId);

            // Store provider mapping for this allocation
            allocationIdToProvider[mockAllocationId] = info.provider;

            // Create payment rail for this mock allocation
            _initiatePaymentRail(info, mockAllocationId);

            emit AllocationCreated(
                msg.sender,
                mockAllocationId,
                info.provider,
                info.pieceCid,
                info.size,
                info.termMin,
                info.termMax,
                expiration,
                info.downloadURL
            );
        }

        // Serialize allocation requests to CBOR bytes (receiver params)
        receiverParams = VerifRegSerialization.serializeVerifregOperatorData(
            allocationRequests
        );

        return (totalDataCap, receiverParams);
    }

    // TODO: Remove this function after testing
    /**
     * @notice Create allocation requests without transferring DataCap (for testing)
     * @param pieceInfos Array of piece information to create allocations for
     * @return totalDataCap Total datacap required for all allocations
     * @return receiverParams Serialized receiver params as bytes
     */
    function mockCreateRawAllocationRequests(
        PieceInfo[] memory pieceInfos
    ) external returns (uint256 totalDataCap, bytes memory receiverParams) {
        require(pieceInfos.length > 0, "No piece infos provided");

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );
        totalDataCap = 0;

        int64 currentEpoch = int64(int256(block.number));

        // Create allocation requests from piece infos
        for (uint256 i = 0; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            // Validate piece size is reasonable (basic validation)
            require(info.size > 0, "Invalid piece size");
            require(info.provider > 0, "Invalid provider ID");

            int64 expiration = currentEpoch + info.expirationOffset;

            allocationRequests[i] = AllocationRequest({
                provider: info.provider,
                data: info.pieceCid,
                size: info.size,
                termMin: info.termMin,
                termMax: info.termMax,
                expiration: expiration
            });

            totalDataCap += info.size;
            emit AllocationCreated(
                msg.sender,
                10,
                info.provider,
                info.pieceCid,
                info.size,
                info.termMin,
                info.termMax,
                expiration,
                info.downloadURL
            );
        }

        // Serialize allocation requests to CBOR bytes (receiver params)
        receiverParams = VerifRegSerialization.serializeVerifregOperatorData(
            allocationRequests
        );

        return (totalDataCap, receiverParams);
    }

    /**
     * @notice Mock function to authenticate proposal by decoding bytes to string to test curio mk20
     * @param data The bytes data to decode
     * @return The decoded string
     */
    function mockAuthenticateCurioProposal(
        bytes memory data
    ) external view virtual returns (string memory) {
        return abi.decode(data, (string));
    }

    // TODO: Remove this function after testing
    /**
     * @notice Mock settle storage provider first payment for an allocation (for testing)
     * @param allocationId The allocation ID to settle payment for
     * @param claimSize The size of the claim (bypassing getClaimInfo)
     * @param termStart The term start epoch from claim (bypassing getClaimInfo)
     */
    function mockSettleSpFirstPayment(
        uint64 allocationId,
        uint64 claimSize,
        int64 termStart
    ) external {
        // Check if allocation exists and get provider ID
        uint64 providerId = allocationIdToProvider[allocationId];
        require(providerId > 0, "Allocation not found");

        // Check if provider is registered
        SPConfig memory spConfig = spConfigs[providerId];
        if (spConfig.paymentAddress == address(0)) {
            revert InvalidProvider();
        }

        // Get the rail ID corresponding to this allocation
        uint256 railId = allocationIdToRailId[allocationId];
        require(railId > 0, "No rail found for allocation");

        // Check if payments contract is set
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        // Get rail details
        IPayments.RailView memory rail = paymentsContract.getRail(railId);

        // Calculate price per epoch using mock claim size
        uint256 pricePerEpoch = this.getSPActivePricePerBytePerEpoch(
            providerId,
            rail.token
        ) * claimSize;

        // Check payment rate and handle accordingly
        if (rail.paymentRate == 0) {
            // Handle case when payment rate is 0 (settled or special state)
            _handleZeroPaymentRate(
                railId,
                uint256(uint64(termStart)),
                pricePerEpoch
            );
        }
    }

    // TODO: Remove this function after testing
    /**
     * @notice Mock settle storage provider payment for an allocation (for testing)
     * @param allocationId The allocation ID to settle payment for
     * @param claimSize The size of the claim (bypassing getClaimInfo)
     * @param termStart The term start epoch from claim (bypassing getClaimInfo)
     */
    function mockSettleSpPayment(
        uint64 allocationId,
        uint64 claimSize,
        int64 termStart,
        uint256 untilEpoch
    )
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalPaymentFee,
            uint256 totalOperatorCommission,
            uint256 finalSettledEpoch,
            string memory note
        )
    {
        // First, handle the initial payment setup if needed
        this.mockSettleSpFirstPayment(allocationId, claimSize, termStart);

        // Get the rail ID for this allocation
        uint256 railId = allocationIdToRailId[allocationId];
        require(railId > 0, "No rail found for allocation");

        // Check if payments contract is set
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        // Settle the rail up to the specified epoch
        return paymentsContract.settleRail(railId, untilEpoch);
    }

    // Abstract function to be implemented by inheriting contracts
    function _initiatePaymentRail(
        PieceInfo memory pieceInfo,
        uint64 allocationId
    ) internal virtual returns (uint256 railId);

    function _handleZeroPaymentRate(
        uint256 railId,
        uint256 termStart,
        uint256 pricePerEpoch
    ) internal virtual;
}
