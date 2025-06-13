// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {VerifRegTypes} from "lib/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";
import {DataCapAPI} from "lib/filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {DataCapTypes} from "lib/filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {PrecompilesAPI} from "lib/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol";
import {VerifRegAPI} from "lib/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";

contract DDOClient is DDOTypes {
    /**
     * @notice Creates allocation requests and transfers DataCap to the DataCap actor
     * @param pieceInfos Array of piece information to create allocations for
     * @return recipientData Data returned from the DataCap transfer
     */
    function createAllocationRequests(
        PieceInfo[] memory pieceInfos
    ) public returns (bytes memory recipientData) {
        require(pieceInfos.length > 0, "No piece infos provided");

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );
        uint256 totalDataCap = 0;

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

            // Store allocation request info for later event emission with allocation ID
        }

        // Serialize allocation requests to CBOR bytes (receiver params)
        bytes memory receiverParams = VerifRegSerialization
            .serializeVerifregOperatorData(allocationRequests);

        // ReceiverParamsGenerated event removed as requested

        // Transfer DataCap to the DataCap actor (not the miner)
        recipientData = _transferDataCap(totalDataCap, receiverParams);

        // Deserialize recipientData and store allocation IDs
        if (recipientData.length > 0) {
            DDOTypes.VerifregResponse
                memory verifregResponse = VerifRegSerialization
                    .deserializeVerifregResponse(recipientData);
            if (verifregResponse.newAllocations.length > 0) {
                require(
                    verifregResponse.newAllocations.length == pieceInfos.length,
                    "Allocation count mismatch"
                );

                for (
                    uint256 i = 0;
                    i < verifregResponse.newAllocations.length;
                    i++
                ) {
                    uint64 allocationId = verifregResponse.newAllocations[i];
                    PieceInfo memory info = pieceInfos[i];

                    // Store allocation ID for client
                    allocationIdsByClient[msg.sender].push(allocationId);

                    // Store provider mapping for this allocation
                    allocationIdToProvider[allocationId] = info.provider;

                    // Emit combined event with allocation info and ID
                    int64 expiration = int64(int256(block.number)) +
                        info.expirationOffset;

                    emit AllocationCreated(
                        msg.sender,
                        allocationId,
                        info.provider,
                        info.pieceCid,
                        info.size,
                        info.termMin,
                        info.termMax,
                        expiration,
                        info.downloadURL
                    );
                }
            }
        }

        return recipientData;
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
    ) external returns (bytes memory recipientData) {
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

        recipientData = createAllocationRequests(pieceInfos);
        return recipientData;
    }

    /**
     * @notice Internal function to transfer DataCap to the DataCap actor
     * @param amount Amount of DataCap to transfer
     * @param operatorData Serialized allocation request data containing provider info
     * @return recipientData Data returned from the transfer
     */
    function _transferDataCap(
        uint256 amount,
        bytes memory operatorData
    ) internal returns (bytes memory recipientData) {
        // Get DataCap actor address using the actor ID (7) from DataCapTypes
        CommonTypes.FilAddress memory dataCapActorAddress = FilAddresses
            .fromActorID(CommonTypes.FilActorId.unwrap(VerifRegTypes.ActorID));

        // Convert amount to BigInt
        CommonTypes.BigInt memory transferAmount = CommonTypes.BigInt({
            val: abi.encodePacked(amount * 10 ** 18),
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

    /**
     * @notice Public wrapper for testing deserializeVerifregResponse
     * @param cborData The CBOR encoded verification registry response
     */
    function deserializeVerifregResponse(
        bytes memory cborData
    ) external pure returns (VerifregResponse memory) {
        return VerifRegSerialization.deserializeVerifregResponse(cborData);
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

    /**
     * @notice Get all allocation IDs for a specific client
     * @param clientAddress The address of the client
     * @return allocationIds Array of all allocation IDs for the client
     */
    function getAllocationIdsForClient(
        address clientAddress
    ) external view returns (uint64[] memory allocationIds) {
        return allocationIdsByClient[clientAddress];
    }

    /**
     * @notice Get the number of allocations for a specific client
     * @param clientAddress The address of the client
     * @return count The number of allocations for the client
     */
    function getAllocationCountForClient(
        address clientAddress
    ) external view returns (uint256 count) {
        return allocationIdsByClient[clientAddress].length;
    }

    /**
     * @notice Get claim information for a specific client and claim ID
     * @param clientAddress The address of the client
     * @param claimId The ID of the claim to retrieve
     * @return claims An array of Claim structs, empty if not found or an error occurred
     */
    function getClaimInfoForClient(
        address clientAddress,
        uint64 claimId
    )
        external
        view
        onlyValidClaimForClient(clientAddress, claimId)
        returns (VerifRegTypes.Claim[] memory claims)
    {
        // Get the provider ID for this allocation from our mapping
        uint64 providerActorId = allocationIdToProvider[claimId];
        require(providerActorId != 0, "Provider not found for allocation");

        // Prepare params for VerifRegAPI.getClaims
        CommonTypes.FilActorId[]
            memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory params = VerifRegTypes
            .GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(providerActorId),
                claim_ids: claimIdsToFetch
            });

        // Call VerifRegAPI.getClaims
        (
            int256 exitCode,
            VerifRegTypes.GetClaimsReturn memory getClaimsReturn
        ) = VerifRegAPI.getClaims(params);

        if (exitCode != 0) {
            revert GetClaimsFailed(exitCode);
        }

        // If the call was successful but no claims were returned for this ID (e.g., success_count is 0)
        // or if the claims array is unexpectedly empty, return an empty array.
        // VerifRegAPI.getClaims should ideally return at least one claim if success_count > 0 for a single ID query.
        if (
            getClaimsReturn.batch_info.success_count == 0 ||
            getClaimsReturn.claims.length == 0
        ) {
            revert NoClaimsFound();
        }

        return getClaimsReturn.claims;
    }

    /**
     * @notice Get claim information for a specific provider and claim ID
     * @param providerActorId The actor ID of the provider
     * @param claimId The ID of the claim to retrieve
     * @return getClaimsReturn The GetClaimsReturn struct containing batch info and claims
     */
    function getClaimInfo(
        uint64 providerActorId,
        uint64 claimId
    ) external view returns (VerifRegTypes.GetClaimsReturn memory) {
        // Prepare params for VerifRegAPI.getClaims
        CommonTypes.FilActorId[]
            memory claimIdsToFetch = new CommonTypes.FilActorId[](1);
        claimIdsToFetch[0] = CommonTypes.FilActorId.wrap(claimId);

        VerifRegTypes.GetClaimsParams memory params = VerifRegTypes
            .GetClaimsParams({
                provider: CommonTypes.FilActorId.wrap(providerActorId),
                claim_ids: claimIdsToFetch
            });

        // Call VerifRegAPI.getClaims
        (
            int256 exitCode,
            VerifRegTypes.GetClaimsReturn memory getClaimsReturnData
        ) = VerifRegAPI.getClaims(params);

        if (exitCode != 0) {
            revert GetClaimsFailed(exitCode);
        }

        return getClaimsReturnData;
    }
}
