// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./BaseTest.sol";

/**
 * @title PaymentsSetupTest
 * @notice Tests for payments system deployment, initialization, and basic setup
 */
contract PaymentsSetupTest is BaseTest {
    function testPaymentsContractDeployment() public view {
        console.log("=== Testing Payments Contract Deployment ===");

        // Verify payments contract is deployed
        assertTrue(
            address(paymentsContract) != address(0),
            "Payments contract should be deployed"
        );

        // Verify DDOClient is connected to payments contract
        assertEq(
            address(ddoClient.paymentsContract()),
            address(paymentsContract),
            "DDOClient should be connected to payments contract"
        );

        // Verify payments contract constants
        assertEq(
            paymentsContract.COMMISSION_MAX_BPS(),
            10000,
            "Commission max should be 10000 BPS"
        );
        assertEq(
            paymentsContract.PAYMENT_FEE_BPS(),
            10,
            "Payment fee should be 10 BPS"
        );

        console.log(
            "Payments contract deployed at:",
            address(paymentsContract)
        );
        console.log(
            "Commission max BPS:",
            paymentsContract.COMMISSION_MAX_BPS()
        );
        console.log("Payment fee BPS:", paymentsContract.PAYMENT_FEE_BPS());
    }

    function testTokenDeploymentAndMinting() public {
        console.log("=== Testing Token Deployment and Minting ===");

        // Verify token deployment
        assertTrue(
            address(testToken) != address(0),
            "Test token should be deployed"
        );
        assertEq(
            testToken.name(),
            "SimpleERC20",
            "Token name should be SimpleERC20"
        );
        assertEq(testToken.symbol(), "SIM", "Token symbol should be SIM");

        // Test initial balances (clients have 500 tokens left after 500 deposited)
        uint256 client1Balance = testToken.balanceOf(client1);
        uint256 client2Balance = testToken.balanceOf(client2);

        console.log("Client1 balance:", client1Balance);
        console.log("Client2 balance:", client2Balance);

        // Each client should have 500 tokens left (1000 minted - 500 deposited)
        assertEq(
            client1Balance,
            500 * 10 ** 18,
            "Client1 should have 500 tokens (1000 minted - 500 deposited)"
        );
        assertEq(
            client2Balance,
            500 * 10 ** 18,
            "Client2 should have 500 tokens (1000 minted - 500 deposited)"
        );

        // Test additional minting
        vm.prank(client1);
        testToken.mint();

        uint256 newBalance = testToken.balanceOf(client1);
        assertEq(
            newBalance,
            client1Balance + (100 * 10 ** 18),
            "Client1 should have 100 more tokens after minting"
        );

        console.log("Client1 balance after additional mint:", newBalance);
    }

    function testClientTokenDeposits() public view {
        console.log("=== Testing Client Token Deposits ===");

        // Check account balances in payments contract
        (uint256 client1Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        (uint256 client2Funds, , , ) = paymentsContract.accounts(
            address(testToken),
            client2
        );

        console.log("Client1 deposited funds:", client1Funds);
        console.log("Client2 deposited funds:", client2Funds);

        // Each client should have deposited 500 tokens
        assertEq(
            client1Funds,
            500 * 10 ** 18,
            "Client1 should have 500 tokens deposited"
        );
        assertEq(
            client2Funds,
            500 * 10 ** 18,
            "Client2 should have 500 tokens deposited"
        );
    }

    function testOperatorApprovals() public view {
        console.log("=== Testing Operator Approvals ===");

        // Check operator approvals for DDOClient
        (
            bool isApproved1,
            uint256 rateAllowance1,
            uint256 lockupAllowance1,
            ,
            ,
            uint256 maxLockupPeriod1
        ) = paymentsContract.operatorApprovals(
                address(testToken),
                client1,
                address(ddoClient)
            );

        (
            bool isApproved2,
            uint256 rateAllowance2,
            uint256 lockupAllowance2,
            ,
            ,
            uint256 maxLockupPeriod2
        ) = paymentsContract.operatorApprovals(
                address(testToken),
                client2,
                address(ddoClient)
            );

        console.log("Client1 DDOClient approval:", isApproved1);
        console.log("Client1 rate allowance:", rateAllowance1);
        console.log("Client1 lockup allowance:", lockupAllowance1);
        console.log("Client1 max lockup period:", maxLockupPeriod1);

        console.log("Client2 DDOClient approval:", isApproved2);
        console.log("Client2 rate allowance:", rateAllowance2);
        console.log("Client2 lockup allowance:", lockupAllowance2);
        console.log("Client2 max lockup period:", maxLockupPeriod2);

        // Verify approvals are set correctly
        assertTrue(
            isApproved1,
            "Client1 should have approved DDOClient as operator"
        );
        assertTrue(
            isApproved2,
            "Client2 should have approved DDOClient as operator"
        );
        assertEq(
            rateAllowance1,
            type(uint256).max,
            "Client1 should have max rate allowance"
        );
        assertEq(
            rateAllowance2,
            type(uint256).max,
            "Client2 should have max rate allowance"
        );
        assertEq(
            lockupAllowance1,
            type(uint256).max,
            "Client1 should have max lockup allowance"
        );
        assertEq(
            lockupAllowance2,
            type(uint256).max,
            "Client2 should have max lockup allowance"
        );
    }

    function testPaymentsContractTokenApprovals() public view {
        console.log("=== Testing Token Approvals for Payments Contract ===");

        // Check that clients have approved payments contract to spend their tokens
        uint256 client1Allowance = testToken.allowance(
            client1,
            address(paymentsContract)
        );
        uint256 client2Allowance = testToken.allowance(
            client2,
            address(paymentsContract)
        );

        console.log(
            "Client1 allowance to payments contract:",
            client1Allowance
        );
        console.log(
            "Client2 allowance to payments contract:",
            client2Allowance
        );

        assertEq(
            client1Allowance,
            type(uint256).max,
            "Client1 should have max allowance to payments contract"
        );
        assertEq(
            client2Allowance,
            type(uint256).max,
            "Client2 should have max allowance to payments contract"
        );
    }

    function testAdditionalDepositAndWithdraw() public {
        console.log("=== Testing Additional Deposit and Withdraw ===");

        uint256 additionalDeposit = 100 * 10 ** 18; // 100 tokens

        // Get initial balance
        (uint256 initialFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        console.log("Client1 initial deposited funds:", initialFunds);

        // Make additional deposit
        vm.prank(client1);
        paymentsContract.deposit(
            address(testToken),
            client1,
            additionalDeposit
        );

        // Check new balance
        (uint256 newFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        console.log("Client1 funds after additional deposit:", newFunds);

        assertEq(
            newFunds,
            initialFunds + additionalDeposit,
            "Funds should increase by deposit amount"
        );

        // Test withdrawal
        uint256 withdrawAmount = 50 * 10 ** 18; // 50 tokens

        vm.prank(client1);
        paymentsContract.withdraw(address(testToken), withdrawAmount);

        // Check balance after withdrawal
        (uint256 finalFunds, , , ) = paymentsContract.accounts(
            address(testToken),
            client1
        );
        console.log("Client1 funds after withdrawal:", finalFunds);

        assertEq(
            finalFunds,
            newFunds - withdrawAmount,
            "Funds should decrease by withdrawal amount"
        );
    }

    function test_RevertWhen_DepositWithoutApproval() public {
        console.log(
            "=== Testing Deposit Without Token Approval (Should Fail) ==="
        );

        // Create a new address without token approval
        address newClient = makeAddr("newClient");

        // Mint tokens for new client
        vm.prank(newClient);
        testToken.mint();

        uint256 balance = testToken.balanceOf(newClient);
        console.log("New client token balance:", balance);

        // Try to deposit without approving payments contract (should fail)
        vm.prank(newClient);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC20InsufficientAllowance(address,uint256,uint256)",
                address(paymentsContract),
                0,
                50 * 10 ** 18
            )
        );
        paymentsContract.deposit(address(testToken), newClient, 50 * 10 ** 18);
    }

    function testCommissionRateSettings() public {
        console.log("=== Testing Commission Rate Settings ===");

        // Test initial commission rate
        uint256 initialRate = ddoClient.commissionRateBps();
        console.log("Initial commission rate (BPS):", initialRate);
        assertEq(
            initialRate,
            50,
            "Initial commission rate should be 50 BPS (0.5%)"
        );

        // Test setting new commission rate
        uint256 newRate = 75; // 0.75%
        ddoClient.setCommissionRate(newRate);

        uint256 updatedRate = ddoClient.commissionRateBps();
        console.log("Updated commission rate (BPS):", updatedRate);
        assertEq(updatedRate, newRate, "Commission rate should be updated");

        // Test maximum commission rate
        uint256 maxRate = ddoClient.MAX_COMMISSION_RATE_BPS();
        console.log("Maximum commission rate (BPS):", maxRate);
        assertEq(
            maxRate,
            100,
            "Maximum commission rate should be 100 BPS (1%)"
        );

        // Test setting commission rate at maximum
        ddoClient.setCommissionRate(maxRate);
        assertEq(
            ddoClient.commissionRateBps(),
            maxRate,
            "Should be able to set commission rate to maximum"
        );

        // Test setting commission rate above maximum (should fail)
        vm.expectRevert(
            abi.encodeWithSignature("CommissionRateExceedsMaximum()")
        );
        ddoClient.setCommissionRate(maxRate + 1);
    }
}
