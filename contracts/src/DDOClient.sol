// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";
import {DataCapAPI} from "lib/filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {DataCapTypes} from "lib/filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";

contract DDOClient is DDOTypes {
    /**
     * @notice Creates allocation requests and transfers DataCap to the DataCap actor
     * @param pieceInfos Array of piece information to create allocations for
     * @return totalDataCap Total datacap required for all allocations
     * @return receiverParams Serialized receiver params as bytes
     * @return recipientData Data returned from the DataCap transfer
     */
    function createAllocationRequests(
        PieceInfo[] memory pieceInfos
    )
        public
        returns (
            uint256 totalDataCap,
            bytes memory receiverParams,
            bytes memory recipientData
        )
    {
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

            emit AllocationRequestCreated(
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

        emit ReceiverParamsGenerated(receiverParams);

        // Transfer DataCap to the DataCap actor (not the miner)
        recipientData = _transferDataCapToActor(totalDataCap, receiverParams);

        return (totalDataCap, receiverParams, recipientData);
    }

    /**
     * @notice Helper function to create a single allocation request
     * @param pieceCid Piece CID as bytes
     * @param size Piece size
     * @param provider Provider/Miner ID
     * @param termMin Minimum term
     * @param termMax Maximum term
     * @param expirationOffset Expiration offset from current block
     * @param downloadURL Download URL for the piece
     * @return receiverParams Serialized receiver params as bytes
     * @return recipientData Data returned from the DataCap transfer
     */
    function createSingleAllocationRequest(
        bytes memory pieceCid,
        uint64 size,
        uint64 provider,
        int64 termMin,
        int64 termMax,
        int64 expirationOffset,
        string memory downloadURL
    )
        external
        returns (bytes memory receiverParams, bytes memory recipientData)
    {
        PieceInfo[] memory pieceInfos = new PieceInfo[](1);
        pieceInfos[0] = PieceInfo({
            pieceCid: pieceCid,
            size: size,
            provider: provider,
            termMin: termMin,
            termMax: termMax,
            expirationOffset: expirationOffset,
            downloadURL: downloadURL
        });

        (, receiverParams, recipientData) = createAllocationRequests(
            pieceInfos
        );
        return (receiverParams, recipientData);
    }

    /**
     * @notice Internal function to transfer DataCap to the DataCap actor
     * @param amount Amount of DataCap to transfer
     * @param operatorData Serialized allocation request data containing provider info
     * @return recipientData Data returned from the transfer
     */
    function _transferDataCapToActor(
        uint256 amount,
        bytes memory operatorData
    ) internal returns (bytes memory recipientData) {
        // Get DataCap actor address using the actor ID (7) from DataCapTypes
        CommonTypes.FilAddress memory dataCapActorAddress = FilAddresses
            .fromActorID(CommonTypes.FilActorId.unwrap(DataCapTypes.ActorID));

        // Convert amount to BigInt
        CommonTypes.BigInt memory transferAmount = CommonTypes.BigInt({
            val: abi.encodePacked(amount),
            neg: false
        });

        // Prepare transfer parameters
        DataCapTypes.TransferParams memory transferParams = DataCapTypes
            .TransferParams({
                operator_data: operatorData,
                to: dataCapActorAddress,
                amount: transferAmount
            });

        // Call DataCap transfer
        (
            int256 exitCode,
            DataCapTypes.TransferReturn memory transferResult
        ) = DataCapAPI.transfer(transferParams);

        if (exitCode != 0) {
            emit DataCapTransferFailed(exitCode, amount);
            revert DataCapTransferError(exitCode);
        }

        emit DataCapTransferSuccess(amount, transferResult.recipient_data);
        return transferResult.recipient_data;
    }

    /**
     * @notice Get the total datacap required for piece infos without creating the request
     * @param pieceInfos Array of piece information
     * @return totalDataCap Total datacap required
     */
    function calculateTotalDataCap(
        PieceInfo[] memory pieceInfos
    ) external pure returns (uint256 totalDataCap) {
        for (uint256 i = 0; i < pieceInfos.length; i++) {
            totalDataCap += pieceInfos[i].size;
        }
        return totalDataCap;
    }

    /**
     * @notice Create allocation requests without transferring DataCap (for testing)
     * @param pieceInfos Array of piece information to create allocations for
     * @return totalDataCap Total datacap required for all allocations
     * @return receiverParams Serialized receiver params as bytes
     */
    function createAllocationRequestsOnly(
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

            emit AllocationRequestCreated(
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

        emit ReceiverParamsGenerated(receiverParams);

        return (totalDataCap, receiverParams);
    }

    /**
     * @notice Public wrapper for testing deserializeVerifregOperatorData
     * @param cborData The cbor encoded operator data
     */
    function deserializeVerifregOperatorData(
        bytes memory cborData
    )
        external
        pure
        returns (
            ProviderClaim[] memory claimExtensions,
            AllocationRequest[] memory allocationRequests
        )
    {
        return VerifRegSerialization.deserializeVerifregOperatorData(cborData);
    }

    /**
     * @notice Public wrapper for testing serializeVerifregOperatorData
     * @param allocationRequests Array of allocation requests to serialize
     */
    function serializeVerifregOperatorData(
        AllocationRequest[] memory allocationRequests
    ) external pure returns (bytes memory) {
        return
            VerifRegSerialization.serializeVerifregOperatorData(
                allocationRequests
            );
    }

    function transfer(DataCapTypes.TransferParams calldata params) public {
        int256 exitCode;
        /// @custom:oz-upgrades-unsafe-allow-reachable delegatecall
        (exitCode, ) = DataCapAPI.transfer(params);
        if (exitCode != 0) {
            revert DataCapTransferError(exitCode);
        }
    }

    /**
     * @notice Handles the receipt of DataCap.
     * @param _params The parameters associated with the DataCap.
     */
    function receiveDataCap(bytes memory _params) internal {
        require(
            msg.sender == DATACAP_ACTOR_ETH_ADDRESS,
            "msg.sender needs to be datacap actor f07"
        );
        emit ReceivedDataCap("DataCap Received!");
        // Add get datacap balance API and store DataCap amount
    }

    /**
     * @notice Universal entry point for any EVM-based actor method calls.
     * @param method FRC42 method number for the specific method hook.
     * @param _codec An unused codec param defining input format.
     * @param params The CBOR encoded byte array parameters associated with the method call.
     * @return A tuple containing exit code, codec and bytes return data.
     */
    function handle_filecoin_method(
        uint64 method,
        uint64 _codec,
        bytes memory params
    ) public returns (uint32, uint64, bytes memory) {
        bytes memory ret;
        uint64 codec;

        // Dispatch methods
        if (method == DATACAP_RECEIVER_HOOK_METHOD_NUM) {
            receiveDataCap(params);
        } else {
            revert UnauthorizedMethod();
        }

        return (0, codec, ret);
    }
}
