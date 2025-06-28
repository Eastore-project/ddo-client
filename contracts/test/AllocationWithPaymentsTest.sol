// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./BaseTest.sol";

/**
 * @title AllocationWithPaymentsTest
 * @notice Tests for allocation creation with integrated payments system
 */
contract AllocationWithPaymentsTest is BaseTest {
    function testSingleAllocationCreationWithPayments() public {
        console.log("=== Testing Single Allocation Creation with Payments ===");

        // Create piece info
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        logPieceInfo(pieceInfo, 1);

        // Get initial account balance
        (
            uint256 initialFunds,
            uint256 initialLockupCurrent,
            ,

        ) = paymentsContract.accounts(address(testToken), client1);
        console.log("Client1 initial funds:", initialFunds);
        console.log("Client1 initial lockup:", initialLockupCurrent);

        // Create allocation with payments
        vm.prank(client1);
        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient
            .mockCreateAllocationRequests(pieceInfos);

        console.log("Total DataCap:", totalDataCap);
        console.log("Receiver params length:", receiverParams.length);
        console.log("Receiver params hex:", bytesToHex(receiverParams));

        // Verify allocation was created
        assertEq(
            totalDataCap,
            PIECE_SIZE,
            "Total DataCap should match piece size"
        );
        assertTrue(
            receiverParams.length > 0,
            "Receiver params should not be empty"
        );

        // Check allocation IDs for client
        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(
            client1
        );
        console.log("Number of allocations for client1:", allocationIds.length);
        assertEq(allocationIds.length, 1, "Should have 1 allocation");

        uint64 allocationId = allocationIds[0];
        console.log("Allocation ID:", allocationId);

        // Verify rail was created
        uint256 railId = ddoClient.allocationIdToRailId(allocationId);
        console.log("Rail ID:", railId);
        assertTrue(railId > 0, "Rail should be created");

        // Get rail details
        IPayments.RailView memory rail = paymentsContract.getRail(railId);
        console.log("Rail details:");
        console.log("  Token:", rail.token);
        console.log("  From (client):", rail.from);
        console.log("  To (SP):", rail.to);
        console.log("  Operator (DDOClient):", rail.operator);
        console.log("  Payment rate:", rail.paymentRate);
        console.log("  Lockup period:", rail.lockupPeriod);
        console.log("  Lockup fixed:", rail.lockupFixed);
        console.log("  Commission rate BPS:", rail.commissionRateBps);

        // Verify rail properties
        assertEq(rail.token, address(testToken), "Rail token should match");
        assertEq(rail.from, client1, "Rail from should be client1");
        assertEq(
            rail.to,
            sp1PaymentAddress,
            "Rail to should be SP1 payment address"
        );
        assertEq(
            rail.operator,
            address(ddoClient),
            "Rail operator should be DDOClient"
        );
        assertEq(
            rail.validator,
            address(ddoClient),
            "Rail validator should be DDOClient"
        );
        assertEq(
            rail.commissionRateBps,
            ddoClient.commissionRateBps(),
            "Commission rate should match DDOClient setting"
        );

        // Verify fixed lockup was set correctly
        uint256 expectedLockup = PIECE_SIZE *
            PRICE_PER_BYTE_PER_EPOCH *
            ddoClient.EPOCHS_PER_MONTH();
        assertEq(
            rail.lockupFixed,
            expectedLockup,
            "Fixed lockup should be calculated correctly"
        );

        // Check client's account after rail creation
        (uint256 finalFunds, uint256 finalLockupCurrent, , ) = paymentsContract
            .accounts(address(testToken), client1);
        console.log("Client1 final funds:", finalFunds);
        console.log("Client1 final lockup:", finalLockupCurrent);

        // Funds should be locked up
        assertEq(
            finalLockupCurrent,
            initialLockupCurrent + expectedLockup,
            "Lockup should increase by expected amount"
        );
    }

    function testMultipleAllocationsWithDifferentProviders() public {
        console.log(
            "=== Testing Multiple Allocations with Different Providers ==="
        );

        // Create piece infos for different providers
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](3);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(
            SP2_ACTOR_ID,
            uint64(PIECE_SIZE / 2)
        );
        pieceInfos[2] = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE / 4)
        );

        for (uint256 i = 0; i < pieceInfos.length; i++) {
            logPieceInfo(pieceInfos[i], i + 1);
        }

        // Get initial state
        (
            uint256 initialFunds,
            uint256 initialLockupCurrent,
            ,

        ) = paymentsContract.accounts(address(testToken), client2);
        console.log("Client2 initial funds:", initialFunds);
        console.log("Client2 initial lockup:", initialLockupCurrent);

        // Create allocations
        vm.prank(client2);
        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient
            .mockCreateAllocationRequests(pieceInfos);

        console.log("Total DataCap:", totalDataCap);

        // Verify total datacap
        uint256 expectedTotalDataCap = PIECE_SIZE +
            (PIECE_SIZE / 2) +
            (PIECE_SIZE / 4);
        assertEq(
            totalDataCap,
            expectedTotalDataCap,
            "Total DataCap should be sum of all pieces"
        );

        // Check allocations created
        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(
            client2
        );
        console.log("Number of allocations for client2:", allocationIds.length);
        assertEq(allocationIds.length, 3, "Should have 3 allocations");

        // Verify each allocation has a rail
        uint256 totalExpectedLockup = 0;
        for (uint256 i = 0; i < allocationIds.length; i++) {
            uint64 allocationId = allocationIds[i];
            uint256 railId = ddoClient.allocationIdToRailId(allocationId);

            emit log_named_uint(
                string(
                    abi.encodePacked("Allocation ", vm.toString(i + 1), " ID")
                ),
                allocationId
            );
            emit log_named_uint("Rail ID", railId);
            assertTrue(railId > 0, "Each allocation should have a rail");

            // Get rail details
            IPayments.RailView memory rail = paymentsContract.getRail(railId);
            console.log("  Rail to SP:", rail.to);
            console.log("  Fixed lockup:", rail.lockupFixed);

            totalExpectedLockup += rail.lockupFixed;

            // Verify rail goes to correct SP
            uint64 providerId = ddoClient.allocationIdToProvider(allocationId);
            if (providerId == SP1_ACTOR_ID) {
                assertEq(
                    rail.to,
                    sp1PaymentAddress,
                    "SP1 rails should go to SP1 payment address"
                );
            } else if (providerId == SP2_ACTOR_ID) {
                assertEq(
                    rail.to,
                    sp2PaymentAddress,
                    "SP2 rails should go to SP2 payment address"
                );
            }
        }

        // Check final lockup
        (uint256 finalFunds, uint256 finalLockupCurrent, , ) = paymentsContract
            .accounts(address(testToken), client2);
        console.log("Client2 final funds:", finalFunds);
        console.log("Client2 final lockup:", finalLockupCurrent);
        console.log("Total expected lockup:", totalExpectedLockup);

        assertEq(
            finalLockupCurrent,
            initialLockupCurrent + totalExpectedLockup,
            "Total lockup should match sum of all rail lockups"
        );
    }

    function testAllocationWithInvalidSP() public {
        console.log("=== Testing Allocation with Invalid SP (Should Fail) ===");

        // Create piece info with unregistered SP
        uint64 invalidSPId = 99999;
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            invalidSPId,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        // Should fail because SP is not registered
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("SPNotRegistered()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testAllocationWithUnsupportedToken() public {
        console.log(
            "=== Testing Allocation with Unsupported Token (Should Fail) ==="
        );

        // Deploy a new token that SP doesn't support
        SimpleERC20 unsupportedToken = new SimpleERC20();

        // Create piece info with unsupported token
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        pieceInfo.paymentTokenAddress = address(unsupportedToken);

        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        // Should fail because token is not supported by SP
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("TokenNotSupportedBySP()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testAllocationWithInsufficientFunds() public {
        console.log(
            "=== Testing Allocation with Insufficient Funds (Should Fail) ==="
        );

        // Create a client with minimal funds
        address poorClient = makeAddr("poorClient");

        // Give minimal tokens and setup
        vm.prank(poorClient);
        testToken.mint(); // Only 100 tokens

        vm.startPrank(poorClient);
        testToken.approve(address(paymentsContract), type(uint256).max);
        paymentsContract.deposit(address(testToken), poorClient, 1 * 10 ** 17); // Only 0.1 tokens deposited

        paymentsContract.setOperatorApproval(
            address(testToken),
            address(ddoClient),
            true,
            type(uint256).max,
            type(uint256).max,
            type(uint256).max
        );
        vm.stopPrank();

        // Try to create large allocation that requires more lockup than available
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        uint256 requiredLockup = PIECE_SIZE *
            PRICE_PER_BYTE_PER_EPOCH *
            ddoClient.EPOCHS_PER_MONTH();
        console.log("Required lockup:", requiredLockup);
        emit log_named_uint("Available funds", 1 * 10 ** 17);

        // Should fail due to insufficient funds for lockup
        vm.prank(poorClient);
        vm.expectRevert();
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testSerializationRoundTrip() public view {
        console.log("=== Testing Serialization Round Trip ===");

        // Create test piece info
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        // Note: We can't call mockCreateAllocationRequests in a view function due to state changes
        // So we'll test the serialization components directly

        // Test allocation request creation
        int64 currentEpoch = int64(int256(block.number));
        int64 expiration = currentEpoch + pieceInfo.expirationOffset;

        DDOTypes.AllocationRequest[]
            memory allocationRequests = new DDOTypes.AllocationRequest[](1);
        allocationRequests[0] = DDOTypes.AllocationRequest({
            provider: pieceInfo.provider,
            data: pieceInfo.pieceCid,
            size: pieceInfo.size,
            termMin: pieceInfo.termMin,
            termMax: pieceInfo.termMax,
            expiration: expiration
        });

        // Test serialization
        bytes memory serialized = ddoClient.serializeVerifregOperatorData(
            allocationRequests
        );
        console.log("Serialized data length:", serialized.length);
        console.log("Serialized data hex:", bytesToHex(serialized));

        // Test deserialization
        (
            DDOTypes.ProviderClaim[] memory claimExtensions,
            DDOTypes.AllocationRequest[] memory deserializedRequests
        ) = ddoClient.deserializeVerifregOperatorData(serialized);

        console.log("Claim extensions count:", claimExtensions.length);
        console.log(
            "Deserialized requests count:",
            deserializedRequests.length
        );

        // Verify round trip
        assertEq(claimExtensions.length, 0, "Should have no claim extensions");
        assertEq(
            deserializedRequests.length,
            1,
            "Should have 1 allocation request"
        );

        DDOTypes.AllocationRequest memory original = allocationRequests[0];
        DDOTypes.AllocationRequest memory deserialized = deserializedRequests[
            0
        ];

        assertEq(
            deserialized.provider,
            original.provider,
            "Provider should match"
        );
        assertEq(deserialized.size, original.size, "Size should match");
        assertEq(
            deserialized.termMin,
            original.termMin,
            "Term min should match"
        );
        assertEq(
            deserialized.termMax,
            original.termMax,
            "Term max should match"
        );
        assertEq(
            deserialized.expiration,
            original.expiration,
            "Expiration should match"
        );
        assertEq(
            keccak256(deserialized.data),
            keccak256(original.data),
            "Data should match"
        );

        console.log("Round trip test passed!");
    }
}
