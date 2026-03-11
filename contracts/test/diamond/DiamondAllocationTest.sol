// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {DiamondBaseTest} from "./DiamondBaseTest.sol";
import {LibDDOStorage} from "src/diamond/libraries/LibDDOStorage.sol";
import {FilecoinPayV1} from "filecoin-pay/FilecoinPayV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SimpleERC20} from "src/SimpleERC20.sol";
import {CBOR} from "solidity-cborutils/contracts/CBOR.sol";

contract DiamondAllocationTest is DiamondBaseTest {
    using CBOR for CBOR.CBORBuffer;

    function testSingleAllocationCreationWithPayments() public {
        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        (uint256 initialFunds, uint256 initialLockupCurrent,,) =
            paymentsContract.accounts(IERC20(address(testToken)), client1);

        vm.prank(client1);
        (uint256 totalDataCap, bytes memory receiverParams) = ddoClient.mockCreateAllocationRequests(pieceInfos);

        assertEq(totalDataCap, PIECE_SIZE, "Total DataCap should match piece size");
        assertTrue(receiverParams.length > 0, "Receiver params should not be empty");

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        assertEq(allocationIds.length, 1, "Should have 1 allocation");

        uint64 allocationId = allocationIds[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);
        assertTrue(railId > 0, "Rail should be created");

        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(address(rail.token), address(testToken), "Rail token should match");
        assertEq(rail.from, client1, "Rail from should be client1");
        assertEq(rail.to, sp1PaymentAddress, "Rail to should be SP1 payment address");
        assertEq(rail.operator, address(diamond), "Rail operator should be Diamond");
        assertEq(rail.validator, address(diamond), "Rail validator should be Diamond");
        assertEq(rail.commissionRateBps, adminDiamond.commissionRateBps(), "Commission rate should match");

        uint256 expectedLockup = adminDiamond.allocationLockupAmount();
        assertEq(rail.lockupFixed, expectedLockup, "Fixed lockup should match allocationLockupAmount");

        (, uint256 finalLockupCurrent,,) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        assertEq(finalLockupCurrent, initialLockupCurrent + expectedLockup, "Lockup should increase");
    }

    function testMultipleAllocationsWithDifferentProviders() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](3);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(SP2_ACTOR_ID, uint64(PIECE_SIZE / 2));
        pieceInfos[2] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE / 4));

        (, uint256 initialLockupCurrent,,) = paymentsContract.accounts(IERC20(address(testToken)), client2);

        vm.prank(client2);
        (uint256 totalDataCap,) = ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint256 expectedTotalDataCap = PIECE_SIZE + (PIECE_SIZE / 2) + (PIECE_SIZE / 4);
        assertEq(totalDataCap, expectedTotalDataCap, "Total DataCap should be sum of all pieces");

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client2);
        assertEq(allocationIds.length, 3, "Should have 3 allocations");

        uint256 totalExpectedLockup = 0;
        for (uint256 i = 0; i < allocationIds.length; i++) {
            (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationIds[i]);
            assertTrue(railId > 0, "Each allocation should have a rail");

            FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
            totalExpectedLockup += rail.lockupFixed;

            (, uint64 providerId,,,,,,,) = viewDiamond.allocationInfos(allocationIds[i]);
            if (providerId == SP1_ACTOR_ID) {
                assertEq(rail.to, sp1PaymentAddress, "SP1 rails should go to SP1 payment address");
            } else if (providerId == SP2_ACTOR_ID) {
                assertEq(rail.to, sp2PaymentAddress, "SP2 rails should go to SP2 payment address");
            }
        }

        (, uint256 finalLockupCurrent,,) = paymentsContract.accounts(IERC20(address(testToken)), client2);
        assertEq(finalLockupCurrent, initialLockupCurrent + totalExpectedLockup, "Total lockup should match");
    }

    function testAllocationWithInvalidSP() public {
        uint64 invalidSPId = 99999;
        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(invalidSPId, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("DDOSp__SPNotRegistered()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testAllocationWithUnsupportedToken() public {
        SimpleERC20 unsupportedToken = new SimpleERC20();

        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfo.paymentTokenAddress = address(unsupportedToken);

        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("DDOSp__TokenNotSupportedBySP()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testAllocationWithInsufficientFunds() public {
        address poorClient = makeAddr("poorClient");

        vm.prank(poorClient);
        testToken.mint();

        vm.startPrank(poorClient);
        testToken.approve(address(paymentsContract), type(uint256).max);
        paymentsContract.deposit(IERC20(address(testToken)), poorClient, 1 * 10 ** 13);
        paymentsContract.setOperatorApproval(
            IERC20(address(testToken)), address(diamond), true, type(uint256).max, type(uint256).max, type(uint256).max
        );
        vm.stopPrank();

        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(poorClient);
        vm.expectRevert();
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function testSerializationRoundTrip() public view {
        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        int64 currentEpoch = int64(int256(block.number));
        int64 expiration = currentEpoch + pieceInfo.expirationOffset;

        LibDDOStorage.AllocationRequest[] memory allocationRequests = new LibDDOStorage.AllocationRequest[](1);
        allocationRequests[0] = LibDDOStorage.AllocationRequest({
            provider: pieceInfo.provider,
            data: pieceInfo.pieceCid,
            size: pieceInfo.size,
            termMin: pieceInfo.termMin,
            termMax: pieceInfo.termMax,
            expiration: expiration
        });

        bytes memory serialized = ddoClient.serializeVerifregOperatorData(allocationRequests);

        (
            LibDDOStorage.ProviderClaim[] memory claimExtensions,
            LibDDOStorage.AllocationRequest[] memory deserializedRequests
        ) = ddoClient.deserializeVerifregOperatorData(serialized);

        assertEq(claimExtensions.length, 0, "Should have no claim extensions");
        assertEq(deserializedRequests.length, 1, "Should have 1 allocation request");

        assertEq(deserializedRequests[0].provider, allocationRequests[0].provider, "Provider should match");
        assertEq(deserializedRequests[0].size, allocationRequests[0].size, "Size should match");
        assertEq(deserializedRequests[0].termMin, allocationRequests[0].termMin, "Term min should match");
        assertEq(deserializedRequests[0].termMax, allocationRequests[0].termMax, "Term max should match");
        assertEq(deserializedRequests[0].expiration, allocationRequests[0].expiration, "Expiration should match");
        assertEq(keccak256(deserializedRequests[0].data), keccak256(allocationRequests[0].data), "Data should match");
    }

    // === Notification tests ===

    function _buildSinglePieceCBOR(
        uint64 sectorNumber,
        int64 minCommitEpoch,
        bytes memory dataCid,
        uint64 pieceSize,
        uint64 allocationId
    ) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(512);
        buf.startFixedArray(1);
        buf.startFixedArray(3);
        buf.writeUInt64(sectorNumber);
        buf.writeInt64(minCommitEpoch);
        buf.startFixedArray(1);
        buf.startFixedArray(3);
        buf.writeBytes(dataCid);
        buf.writeUInt64(pieceSize);

        CBOR.CBORBuffer memory payloadBuf = CBOR.create(16);
        payloadBuf.writeUInt64(allocationId);
        buf.writeBytes(payloadBuf.data());

        return buf.data();
    }

    function testNotificationActivatesRail() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        FilecoinPayV1.RailView memory railBefore = paymentsContract.getRail(railId);
        assertEq(railBefore.paymentRate, 0, "Rail should start with 0 rate");
        assertTrue(railBefore.lockupFixed > 0, "Should have fixed lockup");

        ddoClient.mockActivateAllocation(allocationId);

        FilecoinPayV1.RailView memory railAfter = paymentsContract.getRail(railId);
        assertEq(railAfter.paymentRate, PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE, "Rail rate should be set");
        assertEq(railAfter.lockupFixed, 0, "Fixed lockup should be cleared");
        assertEq(railAfter.lockupPeriod, adminDiamond.EPOCHS_PER_MONTH(), "Should have monthly lockup period");

        (,, bool activated,,,,,,) = viewDiamond.allocationInfos(allocationId);
        assertTrue(activated, "Allocation should be activated");
    }

    function testSettleWithoutActivationReverts() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("DDOTypes__AllocationNotActivated()"));
        ddoClient.settleSpPayment(allocationId, block.number + 100);
    }

    function testDoubleActivationFails() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];

        ddoClient.mockActivateAllocation(allocationId);

        vm.expectRevert(abi.encodeWithSignature("DDOTypes__AllocationAlreadyActivated()"));
        ddoClient.mockActivateAllocation(allocationId);
    }

    function testMultipleAllocationsActivation() public {
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](3);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));
        pieceInfos[1] = createBasicPieceInfo(SP2_ACTOR_ID, uint64(PIECE_SIZE / 2));
        pieceInfos[2] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE / 4));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64[] memory allocationIds = viewDiamond.getAllocationIdsForClient(client1);
        assertEq(allocationIds.length, 3, "Should have 3 allocations");

        for (uint256 i = 0; i < allocationIds.length; i++) {
            ddoClient.mockActivateAllocation(allocationIds[i]);
        }

        for (uint256 i = 0; i < allocationIds.length; i++) {
            (,, bool activated,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationIds[i]);
            assertTrue(activated, "Allocation should be activated");

            FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
            assertTrue(rail.paymentRate > 0, "Rail should have active payment rate");
            assertEq(rail.lockupFixed, 0, "Fixed lockup should be cleared");
        }
    }

    function testFullCBORNotificationFlow() public {
        uint64 sectorChangedMethod = adminDiamond.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        bytes memory cborParams = _buildSinglePieceCBOR(
            1, int64(int256(block.number)), pieceInfos[0].pieceCid, uint64(PIECE_SIZE), allocationId
        );

        vm.prank(sp1MinerAddress);
        (uint32 exitCode, uint64 retCodec,) = ddoClient.handle_filecoin_method(sectorChangedMethod, 0x51, cborParams);

        assertEq(exitCode, 0, "Should succeed");
        assertEq(retCodec, 0x51, "Should return CBOR codec");

        (,, bool activated,,,,,,) = viewDiamond.allocationInfos(allocationId);
        assertTrue(activated, "Allocation should be activated via CBOR notification");

        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(rail.paymentRate, PRICE_PER_BYTE_PER_EPOCH * PIECE_SIZE, "Rail rate should be set");
    }

    function testNotificationRejectsNonMiner() public {
        uint64 sectorChangedMethod = adminDiamond.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];

        bytes memory cborParams = _buildSinglePieceCBOR(
            1, int64(int256(block.number)), pieceInfos[0].pieceCid, uint64(PIECE_SIZE), allocationId
        );

        address randomAddress = makeAddr("randomCaller");
        vm.prank(randomAddress);
        vm.expectRevert(abi.encodeWithSignature("DDOTypes__NotMinerActor()"));
        ddoClient.handle_filecoin_method(sectorChangedMethod, 0x51, cborParams);
    }

    function testNotificationRejectsPieceSizeMismatch() public {
        uint64 sectorChangedMethod = adminDiamond.SECTOR_CONTENT_CHANGED_METHOD_NUM();

        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = createBasicPieceInfo(SP1_ACTOR_ID, uint64(PIECE_SIZE));

        vm.prank(client1);
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        uint64 allocationId = viewDiamond.getAllocationIdsForClient(client1)[0];
        (,,,,,, uint256 railId,,) = viewDiamond.allocationInfos(allocationId);

        bytes memory cborParams = _buildSinglePieceCBOR(
            1,
            int64(int256(block.number)),
            pieceInfos[0].pieceCid,
            uint64(PIECE_SIZE / 2), // WRONG size
            allocationId
        );

        vm.prank(sp1MinerAddress);
        (uint32 exitCode,,) = ddoClient.handle_filecoin_method(sectorChangedMethod, 0x51, cborParams);
        assertEq(exitCode, 0, "Call should succeed (piece just rejected)");

        (,, bool activated,,,,,,) = viewDiamond.allocationInfos(allocationId);
        assertFalse(activated, "Allocation should NOT be activated with wrong piece size");

        FilecoinPayV1.RailView memory rail = paymentsContract.getRail(railId);
        assertEq(rail.paymentRate, 0, "Rail rate should still be 0");
    }

    // === Payments Setup tests ===

    function testPaymentsContractDeployment() public view {
        assertTrue(address(paymentsContract) != address(0), "Payments contract should be deployed");

        assertEq(
            address(adminDiamond.paymentsContract()),
            address(paymentsContract),
            "Diamond should be connected to payments contract"
        );
    }

    function testCommissionRateSettings() public {
        uint256 initialRate = adminDiamond.commissionRateBps();
        assertEq(initialRate, 50, "Initial commission rate should be 50 BPS");

        adminDiamond.setCommissionRate(75);
        assertEq(adminDiamond.commissionRateBps(), 75, "Commission rate should be updated");

        uint256 maxRate = adminDiamond.MAX_COMMISSION_RATE_BPS();
        assertEq(maxRate, 100, "Maximum commission rate should be 100 BPS");

        adminDiamond.setCommissionRate(maxRate);
        assertEq(adminDiamond.commissionRateBps(), maxRate, "Should be able to set to max");

        vm.expectRevert(abi.encodeWithSignature("DDOTypes__CommissionRateExceedsMaximum()"));
        adminDiamond.setCommissionRate(maxRate + 1);
    }

    function testClientTokenDeposits() public view {
        (uint256 client1Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), client1);
        (uint256 client2Funds,,,) = paymentsContract.accounts(IERC20(address(testToken)), client2);

        assertEq(client1Funds, 500 * 10 ** 18, "Client1 should have 500 tokens deposited");
        assertEq(client2Funds, 500 * 10 ** 18, "Client2 should have 500 tokens deposited");
    }

    function testOperatorApprovals() public view {
        (bool isApproved1, uint256 rateAllowance1, uint256 lockupAllowance1,,, uint256 maxLockupPeriod1) =
            paymentsContract.operatorApprovals(IERC20(address(testToken)), client1, address(diamond));

        assertTrue(isApproved1, "Client1 should have approved Diamond as operator");
        assertEq(rateAllowance1, type(uint256).max, "Client1 should have max rate allowance");
        assertEq(lockupAllowance1, type(uint256).max, "Client1 should have max lockup allowance");
    }
}
