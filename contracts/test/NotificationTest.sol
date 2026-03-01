// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {BaseTest, DDOTypes, FilecoinPayV1, IERC20} from "./BaseTest.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";

/**
 * @title NotificationTest
 * @notice Tests for SectorContentChanged notification flow and allocation activation
 */
contract NotificationTest is BaseTest {
    using CBOR for CBOR.CBORBuffer;

    uint256 constant SETTLEMENT_EPOCHS = 1000;

    // Helper: build CBOR SectorContentChangedParams for a single sector with a single piece
    function _buildSinglePieceCBOR(
        uint64 sectorNumber,
        int64 minCommitEpoch,
        bytes memory dataCid,
        uint64 pieceSize,
        uint64 allocationId
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(512);

        // Outer array: 1 sector
        buf.startFixedArray(1);

        // Sector tuple: [sectorNumber, minCommitEpoch, pieces[]]
        buf.startFixedArray(3);
        buf.writeUInt64(sectorNumber);
        buf.writeInt64(minCommitEpoch);

        // Pieces array: 1 piece
        buf.startFixedArray(1);

        // Piece tuple: [dataCid, pieceSize, payload]
        buf.startFixedArray(3);
        buf.writeBytes(dataCid);
        buf.writeUInt64(pieceSize);

        // Payload: allocationId encoded as CBOR uint64
        CBOR.CBORBuffer memory payloadBuf = CBOR.create(16);
        payloadBuf.writeUInt64(allocationId);
        buf.writeBytes(payloadBuf.data());

        return buf.data();
    }

    function testNotificationActivatesRail() public {
        console.log("=== Testing Notification Activates Rail ===");

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];
        (,,,,,,uint256 railId) = ddoClient.allocationInfos(allocationId);

        // Verify rail is inactive (rate = 0)
        FilecoinPayV1.RailView memory railBefore = paymentsContract.getRail(railId);
        assertEq(railBefore.paymentRate, 0, "Rail should start with 0 rate");
        assertTrue(railBefore.lockupFixed > 0, "Should have fixed lockup");

        // Activate via mockActivateAllocation
        ddoClient.mockActivateAllocation(allocationId);

        // Verify rail is now active
        FilecoinPayV1.RailView memory railAfter = paymentsContract.getRail(railId);
        assertEq(
            railAfter.paymentRate,
            PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE,
            "Rail rate should be set after activation"
        );
        assertEq(railAfter.lockupFixed, 0, "Fixed lockup should be cleared");
        assertEq(
            railAfter.lockupPeriod,
            ddoClient.EPOCHS_PER_MONTH(),
            "Should have monthly lockup period"
        );

        // Verify AllocationInfo.activated is true
        (,,bool activated,,,,) = ddoClient.allocationInfos(allocationId);
        assertTrue(activated, "Allocation should be activated");
    }

    function testSettleAfterNotification() public {
        console.log("=== Testing Settle After Notification ===");

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];

        // Get initial balances
        (uint256 initialSpFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );

        // Activate
        ddoClient.mockActivateAllocation(allocationId);

        // Advance time and settle
        uint256 settlementEpoch = block.number + SETTLEMENT_EPOCHS;
        vm.roll(settlementEpoch);

        vm.prank(client1);
        (
            uint256 totalSettled,
            uint256 netPayee,
            ,
            ,
            uint256 finalEpoch,

        ) = ddoClient.mockSettleSpPayment(allocationId, settlementEpoch);

        // Verify settlement
        assertTrue(totalSettled > 0, "Should have settled some amount");
        assertTrue(netPayee > 0, "SP should receive payment");
        assertEq(finalEpoch, settlementEpoch, "Should settle to requested epoch");

        // Verify SP balance increased
        (uint256 finalSpFunds, , , ) = paymentsContract.accounts(
            IERC20(address(testToken)),
            sp1PaymentAddress
        );
        assertEq(
            finalSpFunds,
            initialSpFunds + netPayee,
            "SP should receive net payment"
        );
    }

    function testSettleWithoutActivationReverts() public {
        console.log("=== Testing Settle Without Activation Reverts ===");

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];

        // Try to settle without activation - should revert
        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("DDOTypes__AllocationNotActivated()"));
        ddoClient.settleSpPayment(allocationId, block.number + 100);
    }

    function testDoubleActivationFails() public {
        console.log("=== Testing Double Activation Fails ===");

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];

        // First activation succeeds
        ddoClient.mockActivateAllocation(allocationId);

        // Second activation should fail
        vm.expectRevert(abi.encodeWithSignature("DDOTypes__AllocationAlreadyActivated()"));
        ddoClient.mockActivateAllocation(allocationId);
    }

    function testMultipleAllocationsActivation() public {
        console.log("=== Testing Multiple Allocations Activation ===");

        // Create 3 allocations
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](3);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(SP2_ACTOR_ID, uint64(PIECE_SIZE / 2));
        pieceInfos[2] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE / 4));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = ddoClient.getAllocationIdsForClient(client1);
        assertEq(allocationIds.length, 3, "Should have 3 allocations");

        // Activate all
        for (uint256 i = 0; i < allocationIds.length; i++) {
            ddoClient.mockActivateAllocation(allocationIds[i]);
        }

        // Verify all rails are active
        for (uint256 i = 0; i < allocationIds.length; i++) {
            (,,bool activated,,,,uint256 railId) = ddoClient.allocationInfos(allocationIds[i]);
            assertTrue(activated, "Allocation should be activated");

            FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
            assertTrue(rail.paymentRate > 0, "Rail should have active payment rate");
            assertEq(rail.lockupFixed, 0, "Fixed lockup should be cleared");
        }
    }

    function testFullCBORNotificationFlow() public {
        console.log("=== Testing Full CBOR Notification Flow ===");

        // Cache method number before prank (prank only applies to next external call)
        uint64 sectorChangedMethod = ddoClient.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];
        (,,,,,,uint256 railId) = ddoClient.allocationInfos(allocationId);

        // Build CBOR notification params
        bytes memory cborParams = _buildSinglePieceCBOR(
            1, // sectorNumber
            int64(int256(block.number)), // minCommitEpoch
            pieceInfos[0].pieceCid, // dataCid
            uint64(PIECE_SIZE), // pieceSize
            allocationId // allocationId in payload
        );

        // Call handle_filecoin_method as miner actor
        vm.prank(sp1MinerAddress);
        (uint32 exitCode, uint64 retCodec, bytes memory retData) = ddoClient.handle_filecoin_method(
            sectorChangedMethod,
            0x51,
            cborParams
        );

        assertEq(exitCode, 0, "Should succeed");
        assertEq(retCodec, 0x51, "Should return CBOR codec");
        assertTrue(retData.length > 0, "Should have return data");

        // Verify allocation is now activated
        (,,bool activated,,,,) = ddoClient.allocationInfos(allocationId);
        assertTrue(activated, "Allocation should be activated via CBOR notification");

        // Verify rail is active
        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(
            rail.paymentRate,
            PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE,
            "Rail rate should be set"
        );
    }

    function testNotificationRejectsNonMiner() public {
        console.log("=== Testing Notification Rejects Non-Miner ===");

        // Cache method number before prank
        uint64 sectorChangedMethod = ddoClient.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];

        // Build CBOR notification params
        bytes memory cborParams = _buildSinglePieceCBOR(
            1,
            int64(int256(block.number)),
            pieceInfos[0].pieceCid,
            uint64(PIECE_SIZE),
            allocationId
        );

        // Call from non-miner address - should revert
        address randomAddress = makeAddr("randomCaller");
        vm.prank(randomAddress);
        vm.expectRevert(abi.encodeWithSignature("DDOTypes__NotMinerActor()"));
        ddoClient.handle_filecoin_method(
            sectorChangedMethod,
            0x51,
            cborParams
        );
    }

    function testNotificationRejectsPieceSizeMismatch() public {
        console.log("=== Testing Notification Rejects Piece Size Mismatch ===");

        // Cache method number before prank
        uint64 sectorChangedMethod = ddoClient.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        // Create allocation
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = ddoClient.getAllocationIdsForClient(client1)[0];
        (,,,,,,uint256 railId) = ddoClient.allocationInfos(allocationId);

        // Build CBOR with WRONG piece size
        bytes memory cborParams = _buildSinglePieceCBOR(
            1,
            int64(int256(block.number)),
            pieceInfos[0].pieceCid,
            uint64(PIECE_SIZE / 2), // WRONG size
            allocationId
        );

        // Call from miner - should succeed but piece rejected (accepted=false)
        vm.prank(sp1MinerAddress);
        (uint32 exitCode, , ) = ddoClient.handle_filecoin_method(
            sectorChangedMethod,
            0x51,
            cborParams
        );

        assertEq(exitCode, 0, "Call should succeed (piece just rejected)");

        // Verify allocation is NOT activated
        (,,bool activated,,,,) = ddoClient.allocationInfos(allocationId);
        assertFalse(activated, "Allocation should NOT be activated with wrong piece size");

        // Verify rail is still inactive
        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(rail.paymentRate, 0, "Rail rate should still be 0");
    }
}
