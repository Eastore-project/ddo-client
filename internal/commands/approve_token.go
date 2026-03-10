package commands

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/payments"
	"github.com/Eastore-project/ddo-client/pkg/contract/token"
	"github.com/Eastore-project/ddo-client/pkg/utils"
)

func ApproveTokenCommand() *cli.Command {
	return &cli.Command{
		Name:    "approve-token",
		Aliases: []string{"at"},
		Usage:   "Check and approve ERC20 token allowance for the payments contract",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "payments-contract",
				Aliases: []string{"pc"},
				Usage:   "Payments contract address (overrides PAYMENTS_CONTRACT_ADDRESS env var)",
			},
			&cli.StringFlag{
				Name:    "rpc",
				Aliases: []string{"r"},
				Usage:   "RPC endpoint (overrides RPC_URL env var)",
			},
			&cli.StringFlag{
				Name:    "private-key",
				Aliases: []string{"pk"},
				Usage:   "Private key (overrides PRIVATE_KEY env var)",
			},
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "ERC20 token contract address",
				Required: true,
			},
			&cli.StringFlag{
				Name:    "amount",
				Aliases: []string{"a"},
				Usage:   "Amount to approve (if not provided, will approve unlimited)",
			},
			&cli.BoolFlag{
				Name:  "check-only",
				Usage: "Only check current allowance without approving",
			},
			&cli.BoolFlag{
				Name:  "unlimited",
				Usage: "Approve unlimited amount (max uint256)",
			},
		},
		Action: executeApproveToken,
	}
}

func executeApproveToken(c *cli.Context) error {
	// Override global config with command line flags if provided
	if paymentsContract := c.String("payments-contract"); paymentsContract != "" {
		config.PaymentsContractAddress = paymentsContract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}
	if pk := c.String("private-key"); pk != "" {
		config.PrivateKey = pk
	}

	// Validate required configuration
	if missing := config.GetMissingConfig(); len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}

	if config.PaymentsContractAddress == "" {
		return fmt.Errorf("payments contract address required (use --payments-contract flag or PAYMENTS_CONTRACT_ADDRESS env var)")
	}

	tokenAddress := c.String("token")
	checkOnly := c.Bool("check-only")
	unlimited := c.Bool("unlimited")
	amountStr := c.String("amount")

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Create payments client to get contract address
	paymentsClient, err := payments.NewReadOnlyClientWithParams(config.RPCEndpoint, config.PaymentsContractAddress)
	if err != nil {
		return fmt.Errorf("failed to create payments client: %v", err)
	}
	defer paymentsClient.Close()

	spenderAddress := paymentsClient.GetContractAddress()

	fmt.Printf("🔍 Token Allowance Check:\n")
	fmt.Printf("   User Address: %s\n", userAddress.Hex())
	fmt.Printf("   Token Address: %s\n", tokenAddress)
	fmt.Printf("   Spender (Payments Contract): %s\n", spenderAddress.Hex())
	fmt.Println()

	// Create ERC20 client for read-only operations first
	erc20ReadClient, err := token.NewERC20ReadOnlyClient(config.RPCEndpoint, tokenAddress)
	if err != nil {
		return fmt.Errorf("failed to create ERC20 read client: %v", err)
	}
	defer erc20ReadClient.Close()

	// Check current balance and allowance
	balance, err := erc20ReadClient.GetBalance(userAddress)
	if err != nil {
		return fmt.Errorf("failed to get token balance: %v", err)
	}

	allowance, err := erc20ReadClient.GetAllowance(userAddress, spenderAddress)
	if err != nil {
		return fmt.Errorf("failed to get current allowance: %v", err)
	}

	fmt.Printf("📊 Current Status:\n")
	fmt.Printf("   Token Balance: %s\n", balance.String())
	fmt.Printf("   Current Allowance: %s\n", allowance.String())
	fmt.Println()

	// If check-only, just display the information
	if checkOnly {
		fmt.Printf("✅ Allowance check completed\n")
		return nil
	}

	// Determine the amount to approve
	var approveAmount *big.Int

	if unlimited {
		// Use max uint256 for unlimited approval
		approveAmount = new(big.Int)
		approveAmount.SetString("115792089237316195423570985008687907853269984665640564039457584007913129639935", 10)
		fmt.Printf("🔓 Setting unlimited allowance...\n")
	} else if amountStr != "" {
		// Parse the provided amount
		approveAmount = new(big.Int)
		approveAmount, ok := approveAmount.SetString(amountStr, 10)
		if !ok {
			return fmt.Errorf("invalid amount format: %s", amountStr)
		}
		fmt.Printf("💰 Setting allowance to: %s\n", approveAmount.String())
	} else {
		// Default: approve 2x the user's current balance for convenience
		approveAmount = new(big.Int).Mul(balance, big.NewInt(2))
		fmt.Printf("💰 Setting allowance to 2x balance: %s\n", approveAmount.String())
	}

	// Check if approval is needed
	if allowance.Cmp(approveAmount) >= 0 {
		fmt.Printf("✅ Current allowance is already sufficient\n")
		return nil
	}

	// Create ERC20 client for transactions
	erc20Client, err := token.NewERC20ClientWithParams(config.RPCEndpoint, tokenAddress, config.PrivateKey)
	if err != nil {
		return fmt.Errorf("failed to create ERC20 client: %v", err)
	}
	defer erc20Client.Close()

	// Send approval transaction
	fmt.Printf("📝 Sending approval transaction...\n")
	txHash, err := erc20Client.Approve(spenderAddress, approveAmount)
	if err != nil {
		return fmt.Errorf("failed to approve tokens: %v", err)
	}

	fmt.Printf("✅ Approval transaction sent: %s\n", txHash)
	
	// Wait for transaction to be mined using the ERC20 client's ethclient
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(erc20Client.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	// Verify the new allowance
	newAllowance, err := erc20ReadClient.GetAllowance(userAddress, spenderAddress)
	if err != nil {
		fmt.Printf("⚠️  Warning: failed to verify new allowance: %v\n", err)
		return nil
	}

	fmt.Printf("🎉 Approval successful!\n")
	fmt.Printf("   New Allowance: %s\n", newAllowance.String())
	
	return nil
} 