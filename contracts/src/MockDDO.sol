// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {DDOSp} from "./DDOSp.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";

/// @title MockDDO
/// @notice Mock functions for DDO Client for testing purposes
/// @dev This contract contains all mock functions that can be easily removed by removing inheritance
abstract contract MockDDO is DDOTypes, DDOSp {
    /*//////////////////////////////////////////////////////////////
                    EXTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        if (pieceInfos.length == 0) {
            revert DDOTypes__NoPieceInfosProvided();
        }
        if (address(paymentsContract) == address(0)) {
            revert DDOTypes__PaymentsContractNotSet();
        }

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );

        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            if (info.size == 0) {
                revert DDOTypes__InvalidPieceSize();
            }
            if (info.provider == 0) {
                revert DDOTypes__InvalidProviderId();
            }

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

            uint64 mockAllocationId = uint64(block.timestamp + i + 1);

            allocationIdsByClient[msg.sender].push(mockAllocationId);
            allocationIdsByProvider[info.provider].push(mockAllocationId);
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

        receiverParams = VerifRegSerialization.serializeVerifregOperatorData(
            allocationRequests
        );

        return (totalDataCap, receiverParams);
    }

    /**
     * @notice Create allocation requests without transferring DataCap (for testing)
     * @param pieceInfos Array of piece information to create allocations for
     * @return totalDataCap Total datacap required for all allocations
     * @return receiverParams Serialized receiver params as bytes
     */
    function mockCreateRawAllocationRequests(
        PieceInfo[] memory pieceInfos
    ) external returns (uint256 totalDataCap, bytes memory receiverParams) {
        if (pieceInfos.length == 0) {
            revert DDOTypes__NoPieceInfosProvided();
        }

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );

        int64 currentEpoch = int64(int256(block.number));

        for (uint256 i; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            if (info.size == 0) {
                revert DDOTypes__InvalidPieceSize();
            }
            if (info.provider == 0) {
                revert DDOTypes__InvalidProviderId();
            }

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

        receiverParams = VerifRegSerialization.serializeVerifregOperatorData(
            allocationRequests
        );

        return (totalDataCap, receiverParams);
    }

    /**
     * @notice Mock activate allocation (simulates SectorContentChanged notification)
     * @param allocationId The allocation ID to activate
     */
    function mockActivateAllocation(uint64 allocationId) external {
        AllocationInfo storage info = allocationInfos[allocationId];
        if (info.client == address(0)) {
            revert DDOTypes__AllocationNotFound();
        }
        if (info.activated) {
            revert DDOTypes__AllocationAlreadyActivated();
        }
        _activatePaymentRail(allocationId);
    }

    /**
     * @notice Mock settle storage provider payment for an allocation (for testing)
     * @param allocationId The allocation ID to settle payment for
     * @param untilEpoch The epoch until which to settle the rail
     */
    function mockSettleSpPayment(
        uint64 allocationId,
        uint256 untilEpoch
    )
        external
        returns (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalOperatorCommission,
            uint256 totalNetworkFee,
            uint256 finalSettledEpoch,
            string memory note
        )
    {
        AllocationInfo memory info = allocationInfos[allocationId];
        if (!info.activated) {
            revert DDOTypes__AllocationNotActivated();
        }
        if (info.railId == 0) {
            revert DDOTypes__NoRailFoundForAllocation();
        }

        if (address(paymentsContract) == address(0)) {
            revert DDOTypes__PaymentsContractNotSet();
        }

        return paymentsContract.settleRail(info.railId, untilEpoch);
    }

    /*//////////////////////////////////////////////////////////////
                      EXTERNAL READ-ONLY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                    INTERNAL STATE-CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _initiatePaymentRail(
        PieceInfo memory pieceInfo,
        uint64 allocationId
    ) internal virtual returns (uint256 railId);

    function _activatePaymentRail(
        uint64 allocationId
    ) internal virtual;
}
