// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {DDOTypes} from "./DDOTypes.sol";
import {DDOSp} from "./DDOSp.sol";
import {IPayments} from "./IPayments.sol";
import {DDOValidator} from "./DDOValidator.sol";
import {MockDDO} from "./MockDDO.sol";
import {VerifRegTypes} from "lib/filecoin-solidity/contracts/v0.8/types/VerifRegTypes.sol";
import {VerifRegSerialization} from "./VerifRegSerialization.sol";
import {DataCapAPI} from "lib/filecoin-solidity/contracts/v0.8/DataCapAPI.sol";
import {DataCapTypes} from "lib/filecoin-solidity/contracts/v0.8/types/DataCapTypes.sol";
import {CommonTypes} from "lib/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol";
import {FilAddresses} from "lib/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol";
import {PrecompilesAPI} from "lib/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol";
import {VerifRegAPI} from "lib/filecoin-solidity/contracts/v0.8/VerifRegAPI.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract DDOClientTest is
    DDOTypes,
    DDOSp,
    DDOValidator,
    ReentrancyGuard,
    MockDDO
{
    /**
     * @notice Set the payments contract address
     * @param _paymentsContract Address of the payments contract
     */
    function setPaymentsContract(address _paymentsContract) external onlyOwner {
        if (_paymentsContract == address(0)) {
            revert InvalidPaymentsContract();
        }
        paymentsContract = IPayments(_paymentsContract);
    }

    /**
     * @notice Set the commission rate for storage provider payments
     * @param _commissionRateBps Commission rate in basis points (max 100 = 1%)
     */
    function setCommissionRate(uint256 _commissionRateBps) external onlyOwner {
        if (_commissionRateBps > MAX_COMMISSION_RATE_BPS) {
            revert CommissionRateExceedsMaximum();
        }
        commissionRateBps = _commissionRateBps;
    }

    // remove override when not testing
    /**
     * @notice Internal function to create a payment rail for one allocation
     * @param pieceInfo Single piece information
     * @param allocationId The allocation ID to associate with this rail
     * @return railId The created rail ID
     */
    function _initiatePaymentRail(
        PieceInfo memory pieceInfo,
        uint64 allocationId
    ) internal override returns (uint256 railId) {
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        // Get storage provider configuration
        SPConfig memory spConfig = spConfigs[pieceInfo.provider];
        if (spConfig.paymentAddress == address(0)) {
            revert SPNotRegistered();
        }

        // Create payment rail between client and storage provider for this allocation
        railId = paymentsContract.createRail(
            pieceInfo.paymentTokenAddress, // token
            msg.sender, // from (client)
            spConfig.paymentAddress, // to (storage provider)
            address(this), // validator (DDOClient contract as validator)
            commissionRateBps, // commission rate
            owner() // service fee recipient
        );

        // Get and validate the price per byte per epoch for the payment token
        uint256 pricePerBytePerEpoch = this.getAndValidateSPPrice(
            pieceInfo.provider,
            pieceInfo.paymentTokenAddress
        );

        // Calculate fixed lockup amount (piece size * price per byte per epoch * epochs per month)
        uint256 fixedLockupAmount = pieceInfo.size *
            pricePerBytePerEpoch *
            EPOCHS_PER_MONTH;

        // Do fixed lockup from client to do one time payment when SP claims
        // payment for first time. Fixed lockup would then be made 0.
        paymentsContract.modifyRailLockup(
            railId,
            0, // lockup period (0 epochs)
            fixedLockupAmount // fixed lockup amount
        );

        // Store the mapping from allocation ID to rail ID
        allocationIdToRailId[allocationId] = railId;

        // Emit event for rail creation with allocation ID
        emit RailCreated(
            msg.sender,
            spConfig.paymentAddress,
            pieceInfo.paymentTokenAddress,
            railId,
            pieceInfo.provider,
            allocationId
        );

        return railId;
    }

    /**
     * @notice Creates allocation requests and transfers DataCap to the DataCap actor
     * @param pieceInfos Array of piece information to create allocations for
     * @return recipientData Data returned from the DataCap transfer
     */
    function createAllocationRequests(
        PieceInfo[] memory pieceInfos
    )
        public
        onlyValidPieceForSP(pieceInfos)
        returns (bytes memory recipientData)
    {
        if (pieceInfos.length == 0) {
            revert NoPieceInfosProvided();
        }
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        AllocationRequest[] memory allocationRequests = new AllocationRequest[](
            pieceInfos.length
        );
        uint256 totalDataCap = 0;

        int64 currentEpoch = int64(int256(block.number));

        // Create allocation requests from piece infos
        for (uint256 i = 0; i < pieceInfos.length; i++) {
            PieceInfo memory info = pieceInfos[i];

            // Validate piece size is reasonable (basic validation)
            if (info.size == 0) {
                revert InvalidPieceSize();
            }
            if (info.provider == 0) {
                revert InvalidProviderId();
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
                if (
                    verifregResponse.newAllocations.length != pieceInfos.length
                ) {
                    revert AllocationCountMismatch();
                }

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

                    // Store allocation ID for provider
                    allocationIdsByProvider[info.provider].push(allocationId);

                    // Create payment rail for this allocation
                    _initiatePaymentRail(info, allocationId);

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

    // /**
    //  * @notice Helper function to create a single allocation request
    //  * @param pieceCid Piece CID as bytes
    //  * @param size Piece size
    //  * @param provider Provider/Miner ID
    //  * @param termMin Minimum term
    //  * @param termMax Maximum term
    //  * @param expirationOffset Expiration offset from current block
    //  * @param downloadURL Download URL for the piece
    //  * @param paymentTokenAddress Token address client is willing to pay with
    //  * @return recipientData Data returned from the DataCap transfer
    //  */
    // function createSingleAllocationRequest(
    //     bytes memory pieceCid,
    //     uint64 size,
    //     uint64 provider,
    //     int64 termMin,
    //     int64 termMax,
    //     int64 expirationOffset,
    //     string memory downloadURL,
    //     address paymentTokenAddress
    // ) external returns (bytes memory recipientData) {
    //     PieceInfo[] memory pieceInfos = new PieceInfo[](1);
    //     pieceInfos[0] = PieceInfo({
    //         pieceCid: pieceCid,
    //         size: size,
    //         provider: provider,
    //         termMin: termMin,
    //         termMax: termMax,
    //         expirationOffset: expirationOffset,
    //         downloadURL: downloadURL,
    //         paymentTokenAddress: paymentTokenAddress
    //     });

    //     recipientData = createAllocationRequests(pieceInfos);
    //     return recipientData;
    // }

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

    // /**
    //  * @notice Get the rail ID for a specific allocation
    //  * @param allocationId The allocation ID
    //  * @return railId The corresponding rail ID (0 if not found)
    //  */
    // function getRailIdForAllocation(
    //     uint64 allocationId
    // ) external view returns (uint256 railId) {
    //     return allocationIdToRailId[allocationId];
    // }

    /**
     * @notice Get allocation and rail information together
     * @param allocationId The allocation ID
     * @return railId The corresponding rail ID
     * @return providerId The storage provider ID
     * @return railView Detailed rail information (if rail exists)
     */
    function getAllocationRailInfo(
        uint64 allocationId
    )
        external
        view
        returns (
            uint256 railId,
            uint64 providerId,
            IPayments.RailView memory railView
        )
    {
        railId = allocationIdToRailId[allocationId];
        providerId = allocationIdToProvider[allocationId];

        if (railId > 0 && address(paymentsContract) != address(0)) {
            railView = paymentsContract.getRail(railId);
        }

        return (railId, providerId, railView);
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

    // /**
    //  * @notice Public wrapper for testing deserializeVerifregResponse
    //  * @param cborData The CBOR encoded verification registry response
    //  */
    function deserializeVerifregResponse(
        bytes memory cborData
    ) external pure returns (VerifregResponse memory) {
        return VerifRegSerialization.deserializeVerifregResponse(cborData);
    }

    /**
     * @notice Handles the receipt of DataCap.
     * @param _params The parameters associated with the DataCap.
     */
    function receiveDataCap(bytes memory _params) internal {
        if (msg.sender != DATACAP_ACTOR_ETH_ADDRESS) {
            revert UnauthorizedMethod();
        }
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

    // /**
    //  * @notice Get the number of allocations for a specific client
    //  * @param clientAddress The address of the client
    //  * @return count The number of allocations for the client
    //  */
    // function getAllocationCountForClient(
    //     address clientAddress
    // ) external view returns (uint256 count) {
    //     return allocationIdsByClient[clientAddress].length;
    // }

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
        if (providerActorId == 0) {
            revert InvalidProvider();
        }

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
    ) public view returns (VerifRegTypes.GetClaimsReturn memory) {
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

    // /**
    //  * @notice Get payment rails for a client and token
    //  * @param client The client address
    //  * @param token The token address
    //  * @return railInfos Array of rail information
    //  */
    // function getClientRailsForToken(
    //     address client,
    //     address token
    // ) external view returns (IPayments.RailInfo[] memory railInfos) {
    //     require(
    //         address(paymentsContract) != address(0),
    //         "Payments contract not set"
    //     );
    //     return paymentsContract.getRailsForPayerAndToken(client, token);
    // }

    // /**
    //  * @notice Get detailed rail information by rail ID
    //  * @param railId The rail ID to query
    //  * @return railView Detailed rail information
    //  */
    // function getRailDetails(
    //     uint256 railId
    // ) external view returns (IPayments.RailView memory railView) {
    //     require(
    //         address(paymentsContract) != address(0),
    //         "Payments contract not set"
    //     );
    //     return paymentsContract.getRail(railId);
    // }

    /**
     * @notice Settle storage provider payment for an allocation
     * @param allocationId The allocation ID to settle payment for
     */
    function settleSpFirstPayment(uint64 allocationId) external nonReentrant {
        // Check if allocation exists and get provider ID
        uint64 providerId = allocationIdToProvider[allocationId];
        if (providerId == 0) {
            revert AllocationNotFound();
        }

        // Check if provider is registered
        SPConfig memory spConfig = spConfigs[providerId];
        if (spConfig.paymentAddress == address(0)) {
            revert InvalidProvider();
        }

        // Get claim information for this allocation
        VerifRegTypes.GetClaimsReturn memory claimsReturn = getClaimInfo(
            providerId,
            allocationId
        );

        // Verify that claim was successfully retrieved
        if (claimsReturn.batch_info.success_count == 0) {
            revert FailedToGetClaimInfo();
        }
        if (claimsReturn.claims.length == 0) {
            revert NoClaimsFoundForAllocation();
        }

        // Get the rail ID corresponding to this allocation
        uint256 railId = allocationIdToRailId[allocationId];
        if (railId == 0) {
            revert NoRailFoundForAllocation();
        }

        // Check if payments contract is set
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        // Get rail details
        IPayments.RailView memory rail = paymentsContract.getRail(railId);

        // Corrected type conversion from uint64 to uint256
        uint256 pricePerEpoch = this.getSPActivePricePerBytePerEpoch(
            providerId,
            rail.token
        ) * claimsReturn.claims[0].size;

        // Check payment rate and handle accordingly
        if (rail.paymentRate == 0) {
            // Handle case when payment rate is 0 (settled or special state)
            _handleZeroPaymentRate(
                railId,
                uint256(
                    uint64(
                        CommonTypes.ChainEpoch.unwrap(
                            claimsReturn.claims[0].term_start
                        )
                    )
                ),
                pricePerEpoch
            );
        }
    }

    /**
     * @notice Settle storage provider payment for an allocation (complete settlement)
     * @param allocationId The allocation ID to settle payment for
     * @param untilEpoch The epoch until which to settle the rail
     * @return totalSettledAmount Total amount settled
     * @return totalNetPayeeAmount Net amount paid to payee
     * @return totalPaymentFee Payment fees deducted
     * @return totalOperatorCommission Commission paid to operator
     * @return finalSettledEpoch Final epoch settled up to
     * @return note Settlement note
     */
    function settleSpPayment(
        uint64 allocationId,
        uint256 untilEpoch
    )
        external
        nonReentrant
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
        this.settleSpFirstPayment(allocationId);

        // Get the rail ID for this allocation
        uint256 railId = allocationIdToRailId[allocationId];
        if (railId == 0) {
            revert NoRailFoundForAllocation();
        }

        // Check if payments contract is set
        if (address(paymentsContract) == address(0)) {
            revert PaymentsContractNotSet();
        }

        // Settle the rail up to the specified epoch
        return paymentsContract.settleRail(railId, untilEpoch);
    }

    /**
     * @notice Settle storage provider payment for all allocations until specified epoch
     * @param providerId The storage provider ID to settle payments for
     * @param untilEpoch The epoch until which to settle all rails
     */
    function settleSpTotalPayment(
        uint64 providerId,
        uint256 untilEpoch
    ) external nonReentrant {
        // Get all allocation IDs for this provider
        uint64[] memory allocationIds = allocationIdsByProvider[providerId];
        if (allocationIds.length == 0) {
            revert NoAllocationsFoundForProvider();
        }

        // Settle payment for each allocation
        for (uint256 i = 0; i < allocationIds.length; i++) {
            uint64 allocationId = allocationIds[i];

            this.settleSpPayment(allocationId, untilEpoch);
        }
    }

    /**
     * @notice Get all allocation IDs for a specific storage provider
     * @param providerId The storage provider ID
     * @return allocationIds Array of all allocation IDs for the provider
     */
    function getAllocationIdsForProvider(
        uint64 providerId
    ) external view returns (uint64[] memory allocationIds) {
        return allocationIdsByProvider[providerId];
    }

    // /**
    //  * @notice Get the number of allocations for a specific storage provider
    //  * @param providerId The storage provider ID
    //  * @return count The number of allocations for the provider
    //  */
    // function getAllocationCountForProvider(
    //     uint64 providerId
    // ) external view returns (uint256 count) {
    //     return allocationIdsByProvider[providerId].length;
    // }

    // remove override when not testing
    /**
     * @notice Handle settlement when rail payment rate is 0
     * @param railId The rail ID
     * @param termStart The term start epoch from claim
     * @param pricePerEpoch The SP's price per epoch
     */
    function _handleZeroPaymentRate(
        uint256 railId,
        uint256 termStart,
        uint256 pricePerEpoch
    ) internal override {
        // Validate term start
        if (termStart < 0) {
            revert InvalidTermStart();
        }
        if (block.number < termStart) {
            revert CurrentBlockBeforeTermStart();
        }

        // Calculate one-time payment for elapsed time
        uint256 elapsedEpochs = block.number - termStart;
        uint256 elapsedTimePayment = pricePerEpoch * elapsedEpochs;

        // Calculate monthly payment cap
        uint256 monthlyPayment = pricePerEpoch * EPOCHS_PER_MONTH;

        // Use minimum of elapsed time payment or monthly payment
        uint256 oneTimePayment = elapsedTimePayment < monthlyPayment
            ? elapsedTimePayment
            : monthlyPayment;

        paymentsContract.modifyRailPayment(railId, 0, oneTimePayment);

        // Set up ongoing payments with monthly lockup period and no fixed lockup
        paymentsContract.modifyRailLockup(
            railId,
            EPOCHS_PER_MONTH, // lockup period (one month)
            0 // fixed lockup amount (0)
        );

        // Modify rail payment with calculated rate and one-time payment
        paymentsContract.modifyRailPayment(railId, pricePerEpoch, 0);
    }
}
