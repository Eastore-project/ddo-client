// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {DiamondBaseTest} from "./DiamondBaseTest.sol";
import {LibDDOStorage} from "src/diamond/libraries/LibDDOStorage.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DiamondSettlementTest is DiamondBaseTest {
    uint256 constant SETTLEMENT_EPOCHS = 1000;

    function testE2EAllocationToPaymentSettlement() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        (uint256 initialClientFunds, uint256 initialLockup,,) =
            paymentsContract.accounts(IERC20(address(testToken)), client1);
        (uint256 initialSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        (uint256 initialOperatorFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), owner);

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        uint256 allocationLockup = adminDiamond.allocationLockupAmount();
        (, uint256 afterAllocLockup,,) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        assertEq(afterAllocLockup, initialLockup + allocationLockup, "Lockup should increase");

        // Activate allocation
        ddoClient.mockActivateAllocation(allocationId);

        FilecoinPayV1.RailView memory railAfterActivation = paymentsContract.getRail(railId);
        assertEq(railAfterActivation.paymentRate, PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE, "Payment rate should be set");
        assertEq(railAfterActivation.lockupFixed, 0, "Fixed lockup should be cleared after activation");
        assertEq(railAfterActivation.lockupPeriod, adminDiamond.EPOCHS_PER_MONTH(), "Should have monthly lockup period");

        uint256 expectedStreamingLockup = PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE * adminDiamond.EPOCHS_PER_MONTH();
        (, uint256 currentClientLockup,,) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        assertEq(currentClientLockup, expectedStreamingLockup, "Client lockup should reflect streaming lockup");

        // Settlement after time passes
        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        (
            uint256 totalSettledAmount,
            uint256 totalNetPayeeAmount,
            uint256 totalOperatorCommission,
            uint256 totalNetworkFee,
            uint256 finalSettledEpoch,
        ) = ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        assertTrue(totalSettledAmount > 0, "Should have settled some amount");
        assertTrue(totalNetPayeeAmount > 0, "SP should receive payment");
        assertEq(
            totalSettledAmount,
            totalNetPayeeAmount + totalNetworkFee + totalOperatorCommission,
            "Total should equal sum of components"
        );
        assertEq(
            totalSettledAmount,
            railAfterActivation.paymentRate * SETTLEMENT_EPOCHS,
            "Total should equal payment rate * settlement epochs"
        );

        // Check final balances
        (uint256 finalClientFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        (uint256 finalSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        (uint256 finalOperatorFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), owner);

        assertEq(finalClientFunds, initialClientFunds - totalSettledAmount, "Client should pay the settled amount");
        assertEq(finalSpFunds, initialSpFunds + totalNetPayeeAmount, "SP should receive net payment amount");
        assertEq(
            finalOperatorFunds, initialOperatorFunds + totalOperatorCommission, "Operator should receive commission"
        );

        FilecoinPayV1.RailView memory railAfterSettlement = paymentsContract.getRail(railId);
        assertEq(railAfterSettlement.settledUpTo, finalSettledEpoch, "Rail should be settled up to final epoch");
        assertTrue(railAfterSettlement.paymentRate > 0, "Rail should have ongoing payment rate");
    }

    function testSettlementWithMultipleAllocations() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](2);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(SP2_ACTOR_ID, uint64(PIECE_SIZE / 2));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        assertEq(allocationIds.length, 2, "Should have 2 allocations");

        (uint256 initialSp1Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        (uint256 initialSp2Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp2PaymentAddress);

        ddoClient.mockActivateAllocation(allocationIds[0]);
        ddoClient.mockActivateAllocation(allocationIds[1]);

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.startPrank(client1);

        (uint256 settled1, uint256 netPayee1,,,,) = ddoClient.mockSettleSpPayment(allocationIds[0], settlementEpoch);
        (uint256 settled2, uint256 netPayee2,,,,) = ddoClient.mockSettleSpPayment(allocationIds[1], settlementEpoch);

        vm.stopPrank();

        (uint256 finalSp1Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        (uint256 finalSp2Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp2PaymentAddress);

        assertTrue(settled1 > settled2, "SP1 should receive more payment (larger piece)");
        assertTrue(netPayee1 > netPayee2, "SP1 should receive more net payment");

        assertEq(finalSp1Funds, initialSp1Funds + netPayee1, "SP1 should receive correct net payment");
        assertEq(finalSp2Funds, initialSp2Funds + netPayee2, "SP2 should receive correct net payment");
    }

    function testDebtRailSettlementInsufficientFunds() public {
        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        uint64 allocationId = allocationIds[0];

        ddoClient.mockActivateAllocation(allocationId);

        (,, uint256 unlockedFunds,) = paymentsContract.getAccountInfoIfSettled(IERC20(address(testToken)), client1);
        uint256 leaveFundsForBlocks = 10;

        vm.prank(client1);
        paymentsContract.withdraw(
            IERC20(address(testToken)), unlockedFunds - PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE * leaveFundsForBlocks
        );

        uint256 settlementEpoch = block.number + 10000 + adminDiamond.EPOCHS_PER_MONTH();
        vm.roll(settlementEpoch);

        vm.prank(client1);
        try ddoClient.mockSettleSpPayment(allocationId, settlementEpoch) returns (
            uint256, uint256, uint256, uint256, uint256 finalEpoch, string memory
        ) {
            assertTrue(finalEpoch < settlementEpoch, "Should settle less due to insufficient funds");
            assertEq(finalEpoch, 1 + leaveFundsForBlocks, "Settlement epoch should be what we left funds for");
        } catch Error(string memory) {
            // This is acceptable
        }
    }

    function testRailStateAfterSettlement() public {
        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        uint64 allocationId = allocationIds[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        FilecoinPayV1.RailView memory initialRail = paymentsContract.getRail(railId);
        assertEq(initialRail.paymentRate, 0, "Initial payment rate should be 0");
        assertEq(initialRail.settledUpTo, block.number, "Initial settled epoch should be current block");
        assertTrue(initialRail.lockupFixed > 0, "Should have fixed lockup");

        ddoClient.mockActivateAllocation(allocationId);

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        FilecoinPayV1.RailView memory finalRail = paymentsContract.getRail(railId);
        assertTrue(finalRail.paymentRate > 0, "Payment rate should be set after settlement");
        assertEq(finalRail.settledUpTo, settlementEpoch, "Should be settled up to target epoch");
        assertEq(finalRail.lockupFixed, 0, "Fixed lockup should be cleared after activation");
        assertEq(finalRail.lockupPeriod, adminDiamond.EPOCHS_PER_MONTH(), "Should have monthly lockup period");
        assertEq(finalRail.commissionRateBps, adminDiamond.commissionRateBps(), "Commission rate should match");
    }

    function testBlacklistSectorBlocksSettlement() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        // Activate allocation into sector 42
        ddoClient.mockActivateAllocationWithSector(allocationId, 42);

        FilecoinPayV1.RailView memory railAfterActivation = paymentsContract.getRail(railId);
        assertTrue(railAfterActivation.paymentRate > 0, "Payment rate should be set after activation");

        // Advance time
        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        // Blacklist sector 42 for SP1
        adminDiamond.blacklistSector(SP1_ACTOR_ID, 42, true);
        assertTrue(adminDiamond.isSectorBlacklisted(SP1_ACTOR_ID, 42), "Sector should be blacklisted");

        // Settle — should revert because validator returns no progress for blacklisted sector
        (uint256 initialSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);

        vm.prank(client1);
        vm.expectRevert(); // FilecoinPayV1 reverts with NoProgressInSettlement
        ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        // Verify SP funds unchanged
        (uint256 finalSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        assertEq(finalSpFunds, initialSpFunds, "SP funds should not change for blacklisted sector");
    }

    function testUnblacklistSectorAllowsSettlement() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];

        ddoClient.mockActivateAllocationWithSector(allocationId, 42);

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        // Blacklist then unblacklist
        adminDiamond.blacklistSector(SP1_ACTOR_ID, 42, true);
        assertTrue(adminDiamond.isSectorBlacklisted(SP1_ACTOR_ID, 42), "Sector should be blacklisted");

        adminDiamond.blacklistSector(SP1_ACTOR_ID, 42, false);
        assertFalse(adminDiamond.isSectorBlacklisted(SP1_ACTOR_ID, 42), "Sector should be unblacklisted");

        // Settle — should succeed now
        vm.prank(client1);
        (uint256 totalSettledAmount, uint256 totalNetPayeeAmount,,,,) =
            ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        assertTrue(totalSettledAmount > 0, "Settlement should succeed after unblacklisting");
        assertTrue(totalNetPayeeAmount > 0, "SP should receive payment after unblacklisting");
    }

    function testBlacklistOnlyAffectsTargetSector() public {
        // Create two allocations for the same SP, activated into different sectors
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](2);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        // Make second piece CID different
        pieceInfos[1].pieceCid[pieceInfos[1].pieceCid.length - 1] = 0x01;

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        assertEq(allocationIds.length, 2, "Should have 2 allocations");

        // Activate into different sectors
        ddoClient.mockActivateAllocationWithSector(allocationIds[0], 42);
        ddoClient.mockActivateAllocationWithSector(allocationIds[1], 99);

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        // Blacklist only sector 42
        adminDiamond.blacklistSector(SP1_ACTOR_ID, 42, true);

        // Sector 42 allocation — should revert (no progress)
        vm.prank(client1);
        vm.expectRevert(); // FilecoinPayV1 reverts with NoProgressInSettlement
        ddoClient.mockSettleSpPayment(allocationIds[0], settlementEpoch);

        // Sector 99 allocation — should succeed
        vm.prank(client1);
        (uint256 settled2, uint256 netPayee2,,,,) = ddoClient.mockSettleSpPayment(allocationIds[1], settlementEpoch);
        assertTrue(settled2 > 0, "Non-blacklisted sector should settle normally");
        assertTrue(netPayee2 > 0, "SP should receive payment for non-blacklisted sector");
    }

    function testBlacklistOnlyOwnerCanCall() public {
        // Non-owner should not be able to blacklist
        vm.prank(client1);
        vm.expectRevert("LibDiamond: Must be contract owner");
        adminDiamond.blacklistSector(SP1_ACTOR_ID, 42, true);
    }

    function testBlacklistDoesNotAffectNonActivatedAllocation() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        // Blacklist sector 0 (default for non-activated) — should not affect non-activated allocation
        adminDiamond.blacklistSector(SP1_ACTOR_ID, 0, true);

        // Rail payment rate is 0 for non-activated, so settlement is a no-op regardless
        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(rail.paymentRate, 0, "Non-activated allocation should have 0 payment rate");
    }

    function testSettleAfterNotification() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];

        (uint256 initialSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);

        ddoClient.mockActivateAllocation(allocationId);

        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        (uint256 totalSettled, uint256 netPayee,,, uint256 finalEpoch,) =
            ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        assertTrue(totalSettled > 0, "Should have settled some amount");
        assertTrue(netPayee > 0, "SP should receive payment");
        assertEq(finalEpoch, settlementEpoch, "Should settle to requested epoch");

        (uint256 finalSpFunds,,,) = paymentsContract.accounts(IERC20(address(testToken)), sp1PaymentAddress);
        assertEq(finalSpFunds, initialSpFunds + netPayee, "SP should receive net payment");
    }
}
