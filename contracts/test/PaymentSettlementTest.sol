// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {BaseTest, DDOTypes, FilecoinPayV1, IERC20} from "./BaseTest.sol";

/**
 * @title PaymentSettlementTest
 * @notice Tests for end-to-end payment settlement flow from allocation creation to SP payments
 */
contract PaymentSettlementTest is BaseTest {
    // Test constants for settlement
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

        ) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        (uint256 initialSpFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );
        (uint256 initialOperatorFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            owner
        );

        console.log("Initial client lockup:", initialLockup);
        console.log("Initial SP funds:", initialSpFunds);

        // Create allocation
        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        // Get allocation and rail IDs
        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];
        (,,,,,,uint256 railId) = ddoClient.allocationInfos(allocationId);

        console.log("Allocation ID:", allocationId);
        console.log("Rail ID:", railId);

        // Verify lockup increased by anti-spam amount
        uint256 allocationLockup = ddoClient.allocationLockupAmount();
        (, uint256 afterAllocLockup, , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            client1
        );
        assertEq(
            afterAllocLockup,
            initialLockup + allocationLockup,
            "Lockup should increase"
        );

        // Step 2A: Activate allocation (replaces first payment setup)
        console.log("=== Step 2A: Activate Allocation ===");
        ddoClient.mockActivateAllocation(allocationId);

        // Log rail state after activation
        FilecoinPayV1.RailView memory railAfterActivation = paymentsContract
            .getRail(railId);
        console.log("=== Rail State After Activation ===");
        console.log("Payment rate:", railAfterActivation.paymentRate);
        console.log("Settled up to:", railAfterActivation.settledUpTo);
        console.log("Lockup fixed:", railAfterActivation.lockupFixed);
        console.log("Lockup period:", railAfterActivation.lockupPeriod);

        // Verify activation setup
        assertEq(
            railAfterActivation.paymentRate,
            PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE,
            "Payment rate should be set"
        );
        assertEq(
            railAfterActivation.lockupFixed,
            0,
            "Fixed lockup should be cleared after activation"
        );
        assertEq(
            railAfterActivation.lockupPeriod,
            ddoClient.EPOCHS_PER_MONTH(),
            "Should have monthly lockup period"
        );
        // After activation, lockup switches to streaming (rate * EPOCHS_PER_MONTH)
        uint256 expectedStreamingLockup = PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE * ddoClient.EPOCHS_PER_MONTH();
        (, uint256 currentClientLockup, , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            client1
        );
        assertEq(
            currentClientLockup,
            expectedStreamingLockup,
            "Client lockup should reflect streaming lockup after activation"
        );
        console.log("epoch after activation:", block.number);

        // Step 2B: Actual settlement after time passes
        console.log("=== Step 2B: Settlement After Time Passage ===");

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);
        console.log("Current block (settlement):", block.number);
        console.log("Settlement epoch:", settlementEpoch);

        // Perform settlement
        vm.prank(client1);
        (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalOperatorCommission,
            uint256 totalNetworkFee,
            uint256 finalSettledEpoch,
            string memory note
        ) = ddoClient.mockSettleSpPayment(
                allocationId,
                settlementEpoch
            );

        console.log("=== Settlement Results ===");
        console.log("Total settled amount:", totalSettledAmount);
        console.log("Net payee amount:", totalNetPayeeAmount);
        console.log("Network fee:", totalNetworkFee);
        console.log("Operator commission:", totalOperatorCommission);
        console.log("Final settled epoch:", finalSettledEpoch);
        console.log("Settlement note:", note);

        // Verify settlement amounts
        assertTrue(totalSettledAmount > 0, "Should have settled some amount");
        assertTrue(totalNetPayeeAmount > 0, "SP should receive payment");
        assertEq(
            totalSettledAmount,
            totalNetPayeeAmount + totalNetworkFee + totalOperatorCommission,
            "Total should equal sum of components"
        );
        // check total settled amount value
        assertEq(
            totalSettledAmount,
            railAfterActivation.paymentRate * SETTLEMENT_EPOCHS,
            "Total should equal payment rate * settlement epochs"
        );

        // Step 3: Check final balances
        (
            uint256 finalClientFunds,
            uint256 finalClientLockup,
            ,

        ) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        (uint256 finalSpFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );
        (uint256 finalOperatorFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
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
        FilecoinPayV1.RailView memory railAfterSettlement = paymentsContract
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

        // Step 2A: Activate both allocations
        console.log("=== Step 2A: Activate Allocations ===");

        // Get initial SP balances
        (uint256 initialSp1Funds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );
        (uint256 initialSp2Funds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp2PaymentAddress
        );

        ddoClient.mockActivateAllocation(allocationIds[0]);
        ddoClient.mockActivateAllocation(allocationIds[1]);

        // Step 2B: Settlement after time passes
        console.log("=== Step 2B: Settlement After Time Passage ===");
        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.startPrank(client1);

        // Settle first allocation (SP1, full piece size)
        (uint256 settled1, uint256 netPayee1, , , , ) = ddoClient
            .mockSettleSpPayment(
                allocationIds[0],
                settlementEpoch
            );

        // Settle second allocation (SP2, half piece size)
        (uint256 settled2, uint256 netPayee2, , , , ) = ddoClient
            .mockSettleSpPayment(
                allocationIds[1],
                settlementEpoch
            );

        vm.stopPrank();

        // Check final SP balances
        (uint256 finalSp1Funds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );
        (uint256 finalSp2Funds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
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

        // Activate allocation
        console.log("=== Activate Allocation ===");
        ddoClient.mockActivateAllocation(allocationId);

        // Check account state after activation
        (
            uint256 afterSetupFunds,
            uint256 afterSetupLockup,
            ,

        ) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        console.log("After activation - Funds:", afterSetupFunds);
        console.log("After activation - Lockup:", afterSetupLockup);

        // Get unlocked funds
        (, , uint256 unlockedFunds, ) = paymentsContract
            .getAccountInfoIfSettled(IERC20(address(testToken)), client1);
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
            IERC20(address(testToken)),
            unlockedFunds -
                PRICE_PER_BYTE_PER_EPOCH *
                PIECE_SIZE *
                leaveFundsForBlocks
        );

        // Settlement after time passes with insufficient funds
        console.log(
            "=== Settlement After Time Passage (Insufficient Funds) ==="
        );
        uint256 settlementEpoch = block.number +
            10000 +
            ddoClient.EPOCHS_PER_MONTH();
        vm.roll(settlementEpoch);

        vm.prank(client1);

        try
            ddoClient.mockSettleSpPayment(
                allocationId,
                settlementEpoch
            )
        returns (
            uint256 settled,
            uint256 netPayee,
            uint256 operatorCommission,
            uint256 networkFee,
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

            // check if the settlement epoch is close to what we left funds for
            assertEq(
                finalEpoch,
                1 + leaveFundsForBlocks,
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
        (,,,,,,uint256 railId) = ddoClient.allocationInfos(allocationId);

        // Check initial rail state
        FilecoinPayV1.RailView memory initialRail = paymentsContract.getRail(
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

        // Activate allocation
        console.log("=== Activate Allocation ===");
        ddoClient.mockActivateAllocation(allocationId);

        // Settlement after time passes
        console.log("=== Settlement After Time Passage ===");
        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        ddoClient.mockSettleSpPayment(
            allocationId,
            settlementEpoch
        );

        // Check rail state after settlement
        FilecoinPayV1.RailView memory finalRail = paymentsContract.getRail(railId);
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
            "Fixed lockup should be cleared after activation"
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
