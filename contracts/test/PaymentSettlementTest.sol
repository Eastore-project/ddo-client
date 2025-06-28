// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./BaseTest.sol";

/**
 * @title PaymentSettlementTest
 * @notice Tests for end-to-end payment settlement flow from allocation creation to SP payments
 */
contract PaymentSettlementTest is BaseTest {
    // Test constants for settlement
    uint64 constant MOCK_CLAIM_SIZE = uint64(PIECE_SIZE);
    int64 constant MOCK_TERM_START = 100; // Mock epoch when SP started storing
    uint256 constant SETTLEMENT_EPOCHS = 1000; // Settle for 1000 epochs

    function testE2EAllocationToPaymentSettlement() public {
        console.log(
            "=== Testing E2E: Allocation Creation to Payment Settlement ==="
        );

        // Step 1: Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        // Get initial state
        (
            uint256 initialClientFunds,
            uint256 initialLockup,
            ,

        ) = paymentsContract.accounts(address(testToken), client1);
        (uint256 initialSpFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp1PaymentAddress
        );
        (uint256 initialOperatorFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            owner
        );

        console.log("Initial client lockup:", initialLockup);
        console.log("Initial SP funds:", initialSpFunds);

        // Create allocation
        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        // Get allocation and rail IDs
        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];
        uint256 railId = ddoClient.allocationIdToRailId(allocationId);

        console.log("Allocation ID:", allocationId);
        console.log("Rail ID:", railId);

        // Verify lockup increased
        uint256 expectedLockup = PIECE_SIZE *
            PRICE_PER_BYTE_PER_EPOCH *
            ddoClient.EPOCHS_PER_MONTH();
        (, uint256 afterAllocLockup, , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        assertEq(
            afterAllocLockup,
            initialLockup + expectedLockup,
            "Lockup should increase"
        );

        // Step 2A: First Payment Setup
        console.log("=== Step 2A: First Payment Setup ===");
        vm.roll(uint256(int256(MOCK_TERM_START)));

        vm.prank(client1);
        ddoClient.mockSettleSpFirstPayment(
            allocationId,
            MOCK_CLAIM_SIZE,
            MOCK_TERM_START
        );

        // Log rail state after first payment setup
        IPayments.RailView memory railAfterFirstPayment = paymentsContract
            .getRail(railId);
        console.log("=== Rail State After First Payment Setup ===");
        console.log("Payment rate:", railAfterFirstPayment.paymentRate);
        console.log("Settled up to:", railAfterFirstPayment.settledUpTo);
        console.log("Lockup fixed:", railAfterFirstPayment.lockupFixed);
        console.log("Lockup period:", railAfterFirstPayment.lockupPeriod);

        // Verify first payment setup
        assertEq(
            railAfterFirstPayment.paymentRate,
            PRICE_PER_BYTE_PER_EPOCH * MOCK_CLAIM_SIZE,
            "Payment rate should be set"
        );
        assertEq(
            railAfterFirstPayment.lockupFixed,
            0,
            "Fixed lockup should be cleared after first payment setup"
        );
        assertEq(
            railAfterFirstPayment.lockupPeriod,
            ddoClient.EPOCHS_PER_MONTH(),
            "Should have monthly lockup period"
        );
        // client lockup should be increased by expected lockup for one month
        //get current lockup from payments contract
        (, uint256 currentClientLockup, , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        assertEq(
            currentClientLockup,
            expectedLockup,
            "Client lockup should be increased by expected lockup for one month"
        );
        console.log("epoch after first payment setup:", block.number);

        // Step 2B: Actual settlement after time passes
        console.log("=== Step 2B: Settlement After Time Passage ===");

        // Step 2B: Settlement after time passes
        console.log("=== Settlement ===");
        uint256 settlementEpoch = uint256(int256(MOCK_TERM_START)) +
            SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);
        console.log("Current block (settlement):", block.number);
        console.log("Settlement epoch:", settlementEpoch);

        // Perform settlement
        vm.prank(client1);
        (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalPaymentFee,
            uint256 totalOperatorCommission,
            uint256 finalSettledEpoch,
            string memory note
        ) = ddoClient.mockSettleSpPayment(
                allocationId,
                MOCK_CLAIM_SIZE,
                MOCK_TERM_START,
                settlementEpoch
            );

        console.log("=== Settlement Results ===");
        console.log("Total settled amount:", totalSettledAmount);
        console.log("Net payee amount:", totalNetPayeeAmount);
        console.log("Payment fee:", totalPaymentFee);
        console.log("Operator commission:", totalOperatorCommission);
        console.log("Final settled epoch:", finalSettledEpoch);
        console.log("Settlement note:", note);

        // Verify settlement amounts
        assertTrue(totalSettledAmount > 0, "Should have settled some amount");
        assertTrue(totalNetPayeeAmount > 0, "SP should receive payment");
        assertEq(
            totalSettledAmount,
            totalNetPayeeAmount + totalPaymentFee + totalOperatorCommission,
            "Total should equal sum of components"
        );
        // check total settled amount value
        assertEq(
            totalSettledAmount,
            railAfterFirstPayment.paymentRate * SETTLEMENT_EPOCHS,
            "Total should equal payment rate * settlement epochs"
        );

        // Step 3: Check final balances
        (
            uint256 finalClientFunds,
            uint256 finalClientLockup,
            ,

        ) = paymentsContract.accounts(address(testToken), client1);
        (uint256 finalSpFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp1PaymentAddress
        );
        (uint256 finalOperatorFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            owner
        );

        console.log("=== Final Balances ===");
        console.log("Client1 funds:", finalClientFunds);
        console.log("Client1 lockup:", finalClientLockup);
        console.log("SP1 funds:", finalSpFunds);
        console.log("DDOClient (operator) funds:", finalOperatorFunds);

        // Verify payment flows
        assertEq(
            finalClientFunds,
            initialClientFunds - totalSettledAmount,
            "Client should pay the settled amount"
        );
        assertEq(
            finalSpFunds,
            initialSpFunds + totalNetPayeeAmount,
            "SP should receive net payment amount"
        );
        assertEq(
            finalOperatorFunds,
            initialOperatorFunds + totalOperatorCommission,
            "Operator should receive commission"
        );

        // Verify rail state after final settlement
        IPayments.RailView memory railAfterSettlement = paymentsContract
            .getRail(railId);
        assertEq(
            railAfterSettlement.settledUpTo,
            finalSettledEpoch,
            "Rail should be settled up to final epoch"
        );
        assertTrue(
            railAfterSettlement.paymentRate > 0,
            "Rail should have ongoing payment rate after settlement"
        );

        console.log("Test completed successfully!");
    }

    function testSettlementWithMultipleAllocations() public {
        console.log("=== Testing Settlement with Multiple Allocations ===");

        // Create multiple allocations with different SPs
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](2);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(
            SP2_ACTOR_ID,
            uint64(PIECE_SIZE / 2)
        );

        // Create allocations
        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        // Get allocation IDs
        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(
            client1
        );
        assertEq(allocationIds.length, 2, "Should have 2 allocations");

        // Step 2A: First Payment Setup for both allocations
        console.log("=== Step 2A: First Payment Setup ===");
        vm.roll(uint256(int256(MOCK_TERM_START)));

        // Get initial SP balances
        (uint256 initialSp1Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp1PaymentAddress
        );
        (uint256 initialSp2Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp2PaymentAddress
        );

        vm.startPrank(client1);

        // Setup first payment for both allocations
        ddoClient.mockSettleSpFirstPayment(
            allocationIds[0],
            MOCK_CLAIM_SIZE,
            MOCK_TERM_START
        );

        ddoClient.mockSettleSpFirstPayment(
            allocationIds[1],
            uint64(PIECE_SIZE / 2),
            MOCK_TERM_START
        );

        vm.stopPrank();

        // Step 2B: Settlement after time passes
        console.log("=== Step 2B: Settlement After Time Passage ===");
        uint256 settlementEpoch = uint256(int256(MOCK_TERM_START)) +
            SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.startPrank(client1);

        // Settle first allocation (SP1, full piece size)
        (uint256 settled1, uint256 netPayee1, , , , ) = ddoClient
            .mockSettleSpPayment(
                allocationIds[0],
                MOCK_CLAIM_SIZE,
                MOCK_TERM_START,
                settlementEpoch
            );

        // Settle second allocation (SP2, half piece size)
        (uint256 settled2, uint256 netPayee2, , , , ) = ddoClient
            .mockSettleSpPayment(
                allocationIds[1],
                uint64(PIECE_SIZE / 2),
                MOCK_TERM_START,
                settlementEpoch
            );

        vm.stopPrank();

        // Check final SP balances
        (uint256 finalSp1Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp1PaymentAddress
        );
        (uint256 finalSp2Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            sp2PaymentAddress
        );

        console.log("=== Multiple Settlement Results ===");
        console.log("SP1 settled amount:", settled1);
        console.log("SP1 net amount:", netPayee1);
        console.log("SP2 settled amount:", settled2);
        console.log("SP2 net amount:", netPayee2);
        console.log("SP1 balance increase:", finalSp1Funds - initialSp1Funds);
        console.log("SP2 balance increase:", finalSp2Funds - initialSp2Funds);

        // Verify SP1 received more than SP2 (since it stored a larger piece)
        assertTrue(
            settled1 > settled2,
            "SP1 should receive more payment (larger piece)"
        );
        assertTrue(
            netPayee1 > netPayee2,
            "SP1 should receive more net payment"
        );

        // Verify payments were received
        assertEq(
            finalSp1Funds,
            initialSp1Funds + netPayee1,
            "SP1 should receive correct net payment"
        );
        assertEq(
            finalSp2Funds,
            initialSp2Funds + netPayee2,
            "SP2 should receive correct net payment"
        );
    }

    function testDebtRailSettlementInsufficientFunds() public {
        console.log("=== Testing Settlement with Insufficient Funds ===");

        // Create allocation
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(
            client1
        );
        uint64 allocationId = allocationIds[0];

        // Step 2A: First Payment Setup
        console.log("=== Step 2A: First Payment Setup ===");
        vm.roll(uint256(int256(MOCK_TERM_START)));

        vm.prank(client1);
        ddoClient.mockSettleSpFirstPayment(
            allocationId,
            MOCK_CLAIM_SIZE,
            MOCK_TERM_START
        );

        // Check account state after first payment setup
        (
            uint256 afterSetupFunds,
            uint256 afterSetupLockup,
            ,

        ) = paymentsContract.accounts(address(testToken), client1);
        console.log("After setup - Funds:", afterSetupFunds);
        console.log("After setup - Lockup:", afterSetupLockup);

        // Get unlocked funds
        (, , uint256 unlockedFunds, ) = paymentsContract
            .getAccountInfoIfSettled(address(testToken), client1);
        console.log("Unlocked funds:", unlockedFunds);
        uint256 leaveFundsForBlocks = 10;
        console.log(
            "funds to withdraw:",
            unlockedFunds -
                PRICE_PER_BYTE_PER_EPOCH *
                PIECE_SIZE *
                leaveFundsForBlocks
        );
        // withdraw the unlocked funds
        vm.prank(client1);
        paymentsContract.withdraw(
            address(testToken),
            unlockedFunds -
                PRICE_PER_BYTE_PER_EPOCH *
                PIECE_SIZE *
                leaveFundsForBlocks
        );
        // get the balance again

        // Step 2B: Settlement after time passes with insufficient funds
        console.log(
            "=== Step 2B: Settlement After Time Passage (Insufficient Funds) ==="
        );
        uint256 settlementEpoch = uint256(int256(MOCK_TERM_START)) +
            10000 +
            ddoClient.EPOCHS_PER_MONTH();
        vm.roll(settlementEpoch);

        vm.prank(client1);

        try
            ddoClient.mockSettleSpPayment(
                allocationId,
                MOCK_CLAIM_SIZE,
                MOCK_TERM_START,
                settlementEpoch
            )
        returns (
            uint256 settled,
            uint256 netPayee,
            uint256 fee,
            uint256 commission,
            uint256 finalEpoch,
            string memory note
        ) {
            console.log("Partial settlement succeeded:");
            console.log("Settled amount:", settled);
            console.log("Final epoch:", finalEpoch);
            console.log("Note:", note);

            // Should settle less than requested due to insufficient funds
            assertTrue(
                finalEpoch < settlementEpoch,
                "Should settle less due to insufficient funds"
            );

            // check if the settlement epoch is what we left funds for
            assertEq(
                finalEpoch,
                uint256(int256(MOCK_TERM_START)) + leaveFundsForBlocks,
                "Settlement epoch should be what we left funds for"
            );
        } catch Error(string memory reason) {
            console.log("Settlement failed as expected:", reason);
            // This is acceptable - insufficient funds should cause failure
        }
    }

    function testRailStateAfterSettlement() public {
        console.log("=== Testing Rail State Changes During Settlement ===");

        // Create allocation
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP1_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(
            client1
        );
        uint64 allocationId = allocationIds[0];
        uint256 railId = ddoClient.allocationIdToRailId(allocationId);

        // Check initial rail state
        IPayments.RailView memory initialRail = paymentsContract.getRail(
            railId
        );
        console.log("=== Initial Rail State ===");
        console.log("Payment rate:", initialRail.paymentRate);
        console.log("Settled up to:", initialRail.settledUpTo);
        console.log("Lockup fixed:", initialRail.lockupFixed);
        console.log("Lockup period:", initialRail.lockupPeriod);

        assertEq(
            initialRail.paymentRate,
            0,
            "Initial payment rate should be 0"
        );
        assertEq(
            initialRail.settledUpTo,
            block.number,
            "Initial settled epoch should be current block"
        );
        assertTrue(initialRail.lockupFixed > 0, "Should have fixed lockup");

        // Step 2A: First Payment Setup
        console.log("=== Step 2A: First Payment Setup ===");
        vm.roll(uint256(int256(MOCK_TERM_START)));

        vm.prank(client1);
        ddoClient.mockSettleSpFirstPayment(
            allocationId,
            MOCK_CLAIM_SIZE,
            MOCK_TERM_START
        );

        // Step 2B: Settlement after time passes
        console.log("=== Step 2B: Settlement After Time Passage ===");
        uint256 settlementEpoch = uint256(int256(MOCK_TERM_START)) +
            SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        ddoClient.mockSettleSpPayment(
            allocationId,
            MOCK_CLAIM_SIZE,
            MOCK_TERM_START,
            settlementEpoch
        );

        // Check rail state after settlement
        IPayments.RailView memory finalRail = paymentsContract.getRail(railId);
        console.log("=== Final Rail State ===");
        console.log("Payment rate:", finalRail.paymentRate);
        console.log("Settled up to:", finalRail.settledUpTo);
        console.log("Lockup fixed:", finalRail.lockupFixed);
        console.log("Lockup period:", finalRail.lockupPeriod);

        // Verify rail state changes
        assertTrue(
            finalRail.paymentRate > 0,
            "Payment rate should be set after settlement"
        );
        assertEq(
            finalRail.settledUpTo,
            settlementEpoch,
            "Should be settled up to target epoch"
        );
        assertEq(
            finalRail.lockupFixed,
            0,
            "Fixed lockup should be cleared after first settlement"
        );
        assertEq(
            finalRail.lockupPeriod,
            ddoClient.EPOCHS_PER_MONTH(),
            "Should have monthly lockup period"
        );

        // Verify commission rate
        assertEq(
            finalRail.commissionRateBps,
            ddoClient.commissionRateBps(),
            "Commission rate should match DDOClient setting"
        );
    }
}
