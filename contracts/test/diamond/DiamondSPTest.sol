// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {console} from "forge-std/Test.sol";
import {DiamondBaseTest} from "./DiamondBaseTest.sol";
import {LibDDOStorage} from "src/diamond/libraries/LibDDOStorage.sol";
import {SimpleERC20} from "src/SimpleERC20.sol";

contract DiamondSPTest is DiamondBaseTest {
    function testStorageProviderRegistration() public view {
        (
            address sp1PaymentAddr,
            uint64 sp1MinPiece,
            uint64 sp1MaxPiece,
            int64 sp1MinTerm,
            int64 sp1MaxTerm,
            bool sp1Active
        ) = spDiamond.spConfigs(SP1_ACTOR_ID);

        assertEq(sp1PaymentAddr, sp1PaymentAddress, "SP1 payment address should match");
        assertEq(sp1MinPiece, 1024, "SP1 min piece size should be 1024");
        assertEq(sp1MaxPiece, uint64(PIECE_SIZE * 2), "SP1 max piece size should be 64GB");
        assertEq(sp1MinTerm, 86400, "SP1 min term should be 30 days");
        assertEq(sp1MaxTerm, 5256000, "SP1 max term should be ~1820 days");
        assertTrue(sp1Active, "SP1 should be active");

        (
            address sp2PaymentAddr,
            ,,,, bool sp2Active
        ) = spDiamond.spConfigs(SP2_ACTOR_ID);

        assertEq(sp2PaymentAddr, sp2PaymentAddress, "SP2 payment address should match");
        assertTrue(sp2Active, "SP2 should be active");
    }

    function testSPTokenSupport() public view {
        uint256 sp1Price = spDiamond.getSPActivePricePerBytePerEpoch(SP1_ACTOR_ID, address(testToken));
        assertEq(sp1Price, PRICE_PER_BYTE_PER_EPOCH, "SP1 should support test token at correct price");

        uint256 sp2Price = spDiamond.getSPActivePricePerBytePerEpoch(SP2_ACTOR_ID, address(testToken));
        assertEq(sp2Price, PRICE_PER_BYTE_PER_EPOCH, "SP2 should support test token at correct price");
    }

    function testSPConfigRetrieval() public view {
        LibDDOStorage.TokenConfig[] memory sp1Tokens = spDiamond.getSPSupportedTokens(SP1_ACTOR_ID);
        assertEq(sp1Tokens.length, 1, "SP1 should support 1 token");

        if (sp1Tokens.length > 0) {
            assertEq(sp1Tokens[0].token, address(testToken), "Token address should match");
            assertEq(sp1Tokens[0].pricePerBytePerEpoch, PRICE_PER_BYTE_PER_EPOCH, "Price should match");
            assertTrue(sp1Tokens[0].isActive, "Token should be active");
        }
    }

    function testRegisterNewSP() public {
        uint64 newSPId = 55555;
        address newSPPaymentAddress = makeAddr("newSPPayment");

        LibDDOStorage.TokenConfig[] memory tokenConfigs = new LibDDOStorage.TokenConfig[](1);
        tokenConfigs[0] = LibDDOStorage.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH * 2,
            isActive: true
        });

        spDiamond.registerSP(
            newSPId,
            newSPPaymentAddress,
            2048,
            uint64(PIECE_SIZE),
            172800,
            2628000,
            tokenConfigs
        );

        (address paymentAddr, uint64 minPiece, uint64 maxPiece, int64 minTerm, int64 maxTerm, bool isActive) =
            spDiamond.spConfigs(newSPId);

        assertEq(paymentAddr, newSPPaymentAddress, "Payment address should match");
        assertEq(minPiece, 2048, "Min piece size should match");
        assertEq(maxPiece, uint64(PIECE_SIZE), "Max piece size should match");
        assertEq(minTerm, 172800, "Min term should match");
        assertEq(maxTerm, 2628000, "Max term should match");
        assertTrue(isActive, "New SP should be active");

        uint256 newSPPrice = spDiamond.getSPActivePricePerBytePerEpoch(newSPId, address(testToken));
        assertEq(newSPPrice, PRICE_PER_BYTE_PER_EPOCH * 2, "New SP should have different price");
    }

    function testUpdateSPTokenConfig() public {
        uint256 newPrice = PRICE_PER_BYTE_PER_EPOCH * 3;

        spDiamond.updateSPToken(SP1_ACTOR_ID, address(testToken), newPrice, true);

        uint256 updatedPrice = spDiamond.getSPActivePricePerBytePerEpoch(SP1_ACTOR_ID, address(testToken));
        assertEq(updatedPrice, newPrice, "SP1 price should be updated");

        spDiamond.updateSPToken(SP1_ACTOR_ID, address(testToken), newPrice, false);

        vm.expectRevert(abi.encodeWithSignature("DDOSp__TokenNotSupportedBySP()"));
        spDiamond.getSPActivePricePerBytePerEpoch(SP1_ACTOR_ID, address(testToken));

        // Reactivate
        spDiamond.updateSPToken(SP1_ACTOR_ID, address(testToken), PRICE_PER_BYTE_PER_EPOCH, true);
    }

    function testAddNewTokenToSP() public {
        SimpleERC20 newToken = new SimpleERC20();
        uint256 newTokenPrice = PRICE_PER_BYTE_PER_EPOCH / 2;

        spDiamond.addSPToken(SP1_ACTOR_ID, address(newToken), newTokenPrice);

        uint256 price = spDiamond.getSPActivePricePerBytePerEpoch(SP1_ACTOR_ID, address(newToken));
        assertEq(price, newTokenPrice, "New token should have correct price");

        LibDDOStorage.TokenConfig[] memory tokens = spDiamond.getSPSupportedTokens(SP1_ACTOR_ID);
        assertEq(tokens.length, 2, "SP1 should now support 2 tokens");
    }

    function testSPDeactivation() public {
        spDiamond.deactivateSP(SP2_ACTOR_ID);

        (,,,,, bool isActive) = spDiamond.spConfigs(SP2_ACTOR_ID);
        assertFalse(isActive, "SP2 should be inactive");

        LibDDOStorage.PieceInfo memory pieceInfo = createBasicPieceInfo(SP2_ACTOR_ID, uint64(PIECE_SIZE));
        LibDDOStorage.PieceInfo[] memory pieceInfos = new LibDDOStorage.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("DDOSp__SPNotActive()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);
    }

    function test_RevertWhen_RegisterDuplicateSP() public {
        LibDDOStorage.TokenConfig[] memory tokenConfigs = new LibDDOStorage.TokenConfig[](1);
        tokenConfigs[0] = LibDDOStorage.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH,
            isActive: true
        });

        vm.expectRevert(abi.encodeWithSignature("DDOSp__SPAlreadyRegistered()"));
        spDiamond.registerSP(
            SP1_ACTOR_ID,
            sp1PaymentAddress,
            1024,
            uint64(PIECE_SIZE),
            86400,
            5256000,
            tokenConfigs
        );
    }

    function test_RevertWhen_UpdateNonExistentSP() public {
        uint64 nonExistentSPId = 99999;

        vm.expectRevert(abi.encodeWithSignature("DDOSp__SPNotRegistered()"));
        spDiamond.updateSPToken(nonExistentSPId, address(testToken), PRICE_PER_BYTE_PER_EPOCH, true);
    }
}
