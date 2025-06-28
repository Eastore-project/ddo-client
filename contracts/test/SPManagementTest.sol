// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./BaseTest.sol";

/**
 * @title SPManagementTest
 * @notice Tests for storage provider registration and management
 */
contract SPManagementTest is BaseTest {
    function testStorageProviderRegistration() public view {
        console.log("=== Testing Storage Provider Registration ===");

        // Check SP1 configuration
        (
            address sp1PaymentAddr,
            uint64 sp1MinPiece,
            uint64 sp1MaxPiece,
            int64 sp1MinTerm,
            int64 sp1MaxTerm,
            bool sp1Active
        ) = ddoClient.spConfigs(SP1_ACTOR_ID);

        console.log("SP1 Configuration:");
        console.log("  Payment Address:", sp1PaymentAddr);
        console.log("  Min Piece Size:", sp1MinPiece);
        console.log("  Max Piece Size:", sp1MaxPiece);
        console.log("  Min Term Length:", uint256(uint64(sp1MinTerm)));
        console.log("  Max Term Length:", uint256(uint64(sp1MaxTerm)));
        console.log("  Is Active:", sp1Active);

        // Verify SP1 configuration
        assertEq(
            sp1PaymentAddr,
            sp1PaymentAddress,
            "SP1 payment address should match"
        );
        assertEq(sp1MinPiece, 1024, "SP1 min piece size should be 1024");
        assertEq(
            sp1MaxPiece,
            uint64(PIECE_SIZE * 2),
            "SP1 max piece size should be 64GB"
        );
        assertEq(sp1MinTerm, 86400, "SP1 min term should be 30 days");
        assertEq(sp1MaxTerm, 5256000, "SP1 max term should be ~1820 days");
        assertTrue(sp1Active, "SP1 should be active");

        // Check SP2 configuration
        (
            address sp2PaymentAddr,
            uint64 sp2MinPiece,
            uint64 sp2MaxPiece,
            int64 sp2MinTerm,
            int64 sp2MaxTerm,
            bool sp2Active
        ) = ddoClient.spConfigs(SP2_ACTOR_ID);

        console.log("SP2 Configuration:");
        console.log("  Payment Address:", sp2PaymentAddr);
        console.log("  Min Piece Size:", sp2MinPiece);
        console.log("  Max Piece Size:", sp2MaxPiece);
        console.log("  Min Term Length:", uint256(uint64(sp2MinTerm)));
        console.log("  Max Term Length:", uint256(uint64(sp2MaxTerm)));
        console.log("  Is Active:", sp2Active);

        // Verify SP2 configuration
        assertEq(
            sp2PaymentAddr,
            sp2PaymentAddress,
            "SP2 payment address should match"
        );
        assertTrue(sp2Active, "SP2 should be active");
    }

    function testSPTokenSupport() public view {
        console.log("=== Testing SP Token Support ===");

        // Test SP1 token support
        uint256 sp1Price = ddoClient.getSPActivePricePerBytePerEpoch(
            SP1_ACTOR_ID,
            address(testToken)
        );
        console.log("SP1 price per byte per epoch for test token:", sp1Price);
        assertEq(
            sp1Price,
            PRICE_PER_BYTE_PER_EPOCH,
            "SP1 should support test token at correct price"
        );

        // Test SP2 token support
        uint256 sp2Price = ddoClient.getSPActivePricePerBytePerEpoch(
            SP2_ACTOR_ID,
            address(testToken)
        );
        console.log("SP2 price per byte per epoch for test token:", sp2Price);
        assertEq(
            sp2Price,
            PRICE_PER_BYTE_PER_EPOCH,
            "SP2 should support test token at correct price"
        );
    }

    function testSPConfigRetrieval() public view {
        console.log("=== Testing SP Configuration Retrieval ===");

        // Get supported tokens for SP1
        DDOSp.TokenConfig[] memory sp1Tokens = ddoClient.getSPSupportedTokens(
            SP1_ACTOR_ID
        );
        console.log("SP1 supported tokens count:", sp1Tokens.length);
        assertEq(sp1Tokens.length, 1, "SP1 should support 1 token");

        if (sp1Tokens.length > 0) {
            console.log("SP1 Token 1:");
            console.log("  Address:", sp1Tokens[0].token);
            console.log(
                "  Price per byte per epoch:",
                sp1Tokens[0].pricePerBytePerEpoch
            );
            console.log("  Is active:", sp1Tokens[0].isActive);

            assertEq(
                sp1Tokens[0].token,
                address(testToken),
                "Token address should match"
            );
            assertEq(
                sp1Tokens[0].pricePerBytePerEpoch,
                PRICE_PER_BYTE_PER_EPOCH,
                "Price should match"
            );
            assertTrue(sp1Tokens[0].isActive, "Token should be active");
        }
    }

    function testRegisterNewSP() public {
        console.log("=== Testing New SP Registration ===");

        uint64 newSPId = 55555;
        address newSPPaymentAddress = makeAddr("newSPPayment");

        // Prepare token configuration
        DDOSp.TokenConfig[] memory tokenConfigs = new DDOSp.TokenConfig[](1);
        tokenConfigs[0] = DDOSp.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH * 2, // Different price
            isActive: true
        });

        // Register new SP
        ddoClient.registerSP(
            newSPId,
            newSPPaymentAddress,
            2048, // minPieceSize: 2KB
            uint64(PIECE_SIZE), // maxPieceSize: 32GB
            172800, // minTermLength: 60 days
            2628000, // maxTermLength: ~910 days
            tokenConfigs
        );

        console.log("New SP registered with ID:", newSPId);

        // Verify new SP configuration
        (
            address paymentAddr,
            uint64 minPiece,
            uint64 maxPiece,
            int64 minTerm,
            int64 maxTerm,
            bool isActive
        ) = ddoClient.spConfigs(newSPId);

        assertEq(
            paymentAddr,
            newSPPaymentAddress,
            "Payment address should match"
        );
        assertEq(minPiece, 2048, "Min piece size should match");
        assertEq(maxPiece, uint64(PIECE_SIZE), "Max piece size should match");
        assertEq(minTerm, 172800, "Min term should match");
        assertEq(maxTerm, 2628000, "Max term should match");
        assertTrue(isActive, "New SP should be active");

        // Verify token support
        uint256 newSPPrice = ddoClient.getSPActivePricePerBytePerEpoch(
            newSPId,
            address(testToken)
        );
        assertEq(
            newSPPrice,
            PRICE_PER_BYTE_PER_EPOCH * 2,
            "New SP should have different price"
        );
    }

    function testUpdateSPTokenConfig() public {
        console.log("=== Testing SP Token Configuration Update ===");

        uint256 newPrice = PRICE_PER_BYTE_PER_EPOCH * 3; // 3x the original price

        // Update SP1 token configuration
        ddoClient.updateSPToken(
            SP1_ACTOR_ID,
            address(testToken),
            newPrice,
            true
        );

        console.log("Updated SP1 token config with new price:", newPrice);

        // Verify the price was updated
        uint256 updatedPrice = ddoClient.getSPActivePricePerBytePerEpoch(
            SP1_ACTOR_ID,
            address(testToken)
        );
        assertEq(updatedPrice, newPrice, "SP1 price should be updated");

        // Test deactivating the token
        ddoClient.updateSPToken(
            SP1_ACTOR_ID,
            address(testToken),
            newPrice,
            false // deactivate
        );

        console.log("Deactivated token for SP1");

        // Should now revert when trying to get price for inactive token
        vm.expectRevert(abi.encodeWithSignature("TokenNotSupportedBySP()"));
        ddoClient.getSPActivePricePerBytePerEpoch(
            SP1_ACTOR_ID,
            address(testToken)
        );

        // Reactivate for other tests
        ddoClient.updateSPToken(
            SP1_ACTOR_ID,
            address(testToken),
            PRICE_PER_BYTE_PER_EPOCH, // Reset to original price
            true
        );
    }

    function testAddNewTokenToSP() public {
        console.log("=== Testing Adding New Token to SP ===");

        // Deploy a new token
        SimpleERC20 newToken = new SimpleERC20();
        uint256 newTokenPrice = PRICE_PER_BYTE_PER_EPOCH / 2; // Half the price

        console.log("Adding new token to SP1:", address(newToken));

        // Add new token to SP1
        ddoClient.addSPToken(SP1_ACTOR_ID, address(newToken), newTokenPrice);

        // Verify new token is supported
        uint256 price = ddoClient.getSPActivePricePerBytePerEpoch(
            SP1_ACTOR_ID,
            address(newToken)
        );
        assertEq(price, newTokenPrice, "New token should have correct price");

        // Verify SP now supports 2 tokens
        DDOSp.TokenConfig[] memory tokens = ddoClient.getSPSupportedTokens(
            SP1_ACTOR_ID
        );
        assertEq(tokens.length, 2, "SP1 should now support 2 tokens");

        console.log("SP1 now supports", tokens.length, "tokens");
    }

    function testSPDeactivation() public {
        console.log("=== Testing SP Deactivation ===");

        // Deactivate SP2
        ddoClient.deactivateSP(SP2_ACTOR_ID);
        console.log("Deactivated SP2");

        // Verify SP2 is now inactive
        (, , , , , bool isActive) = ddoClient.spConfigs(SP2_ACTOR_ID);
        assertFalse(isActive, "SP2 should be inactive");

        // Try to create allocation with inactive SP (should fail)
        DDOTypes.PieceInfo memory pieceInfo = createBasicPieceInfo(
            SP2_ACTOR_ID,
            uint64(PIECE_SIZE)
        );
        DDOTypes.PieceInfo[] memory pieceInfos = new DDOTypes.PieceInfo[](1);
        pieceInfos[0] = pieceInfo;

        vm.prank(client1);
        vm.expectRevert(abi.encodeWithSignature("SPNotActive()"));
        ddoClient.mockCreateAllocationRequests(pieceInfos);

        console.log(
            "SP2 successfully deactivated - allocation creation properly blocked"
        );
    }

    function test_RevertWhen_RegisterDuplicateSP() public {
        console.log("=== Testing Duplicate SP Registration (Should Fail) ===");

        // Try to register SP1 again (should fail)
        DDOSp.TokenConfig[] memory tokenConfigs = new DDOSp.TokenConfig[](1);
        tokenConfigs[0] = DDOSp.TokenConfig({
            token: address(testToken),
            pricePerBytePerEpoch: PRICE_PER_BYTE_PER_EPOCH,
            isActive: true
        });

        vm.expectRevert(abi.encodeWithSignature("SPAlreadyRegistered()"));
        ddoClient.registerSP(
            SP1_ACTOR_ID, // Same ID as existing SP
            sp1PaymentAddress,
            1024,
            uint64(PIECE_SIZE),
            86400,
            5256000,
            tokenConfigs
        );
    }

    function test_RevertWhen_UpdateNonExistentSP() public {
        console.log("=== Testing Update Non-Existent SP (Should Fail) ===");

        uint64 nonExistentSPId = 99999;

        // Try to update token config for non-existent SP
        vm.expectRevert(abi.encodeWithSignature("SPNotRegistered()"));
        ddoClient.updateSPToken(
            nonExistentSPId,
            address(testToken),
            PRICE_PER_BYTE_PER_EPOCH,
            true
        );
    }
}
