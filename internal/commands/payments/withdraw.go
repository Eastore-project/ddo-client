package payments

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/payments"
	"ddo-client/internal/utils"
)

func WithdrawCommand() *cli.Command {
	return &cli.Command{
		Name:    "withdraw",
		Aliases: []string{"wd"},
		Usage:   "Withdraw tokens from your account",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "ERC20 token contract address",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "amount",
				Aliases:  []string{"a"},
				Usage:    "Amount to withdraw",
				Required: true,
			},
			&cli.StringFlag{
				Name:    "to",
				Aliases: []string{"to-address"},
				Usage:   "Address to withdraw to (defaults to your own address)",
			},
			&cli.BoolFlag{
				Name:  "check-balance",
				Usage: "Check account balance before withdrawing",
			},
		}...),
		Action: executeWithdraw,
	}
}

func executeWithdraw(c *cli.Context) error {
	// Validate private key configuration
	if err := validatePrivateKeyConfig(c); err != nil {
		return err
	}

	tokenAddress := common.HexToAddress(c.String("token"))
	amountStr := c.String("amount")
	toAddressStr := c.String("to")
	checkBalance := c.Bool("check-balance")

	// Parse withdrawal amount
	amount := new(big.Int)
	amount, ok := amount.SetString(amountStr, 10)
	if !ok {
		return fmt.Errorf("invalid amount format: %s", amountStr)
	}

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Determine withdraw destination address
	var toAddress common.Address
	if toAddressStr != "" {
		toAddress = common.HexToAddress(toAddressStr)
	} else {
		toAddress = userAddress // Default to user's own address
	}

	fmt.Printf("💰 Withdraw Information:\n")
	fmt.Printf("   From Account: %s\n", userAddress.Hex())
	fmt.Printf("   Token: %s\n", tokenAddress.Hex())
	fmt.Printf("   Amount: %s\n", amount.String())
	fmt.Printf("   To Address: %s\n", toAddress.Hex())
	if toAddress == userAddress {
		fmt.Printf("   (Withdrawing to your own address)\n")
	}
	fmt.Println()

	// Check balance if requested
	if checkBalance {
		paymentsClient, err := payments.NewReadOnlyClient()
		if err != nil {
			return fmt.Errorf("failed to create payments client: %v", err)
		}
		defer paymentsClient.Close()

		account, err := paymentsClient.GetAccount(tokenAddress, userAddress)
		if err != nil {
			return fmt.Errorf("failed to get account balance: %v", err)
		}

		fmt.Printf("📊 Current Account Status:\n")
		fmt.Printf("   Available Funds: %s\n", account.Funds.String())
		fmt.Printf("   Locked Funds: %s\n", account.LockupCurrent.String())
		fmt.Printf("   Withdrawal Amount: %s\n", amount.String())

		// Check if withdrawal amount exceeds available funds
		if account.Funds.Cmp(amount) < 0 {
			return fmt.Errorf("insufficient funds: available %s, requested %s", account.Funds.String(), amount.String())
		}

		remaining := new(big.Int).Sub(account.Funds, amount)
		fmt.Printf("   Remaining After Withdrawal: %s\n", remaining.String())
		fmt.Println()
	}

	// Create payments client for transactions
	paymentsTransactClient, err := payments.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create payments transaction client: %v", err)
	}
	defer paymentsTransactClient.Close()

	// Send the withdrawal transaction
	fmt.Printf("📝 Sending withdrawal transaction...\n")
	var txHash string
	if toAddressStr == "" {
		// Use regular withdraw function if no destination specified
		txHash, err = paymentsTransactClient.Withdraw(tokenAddress, amount)
	} else {
		// Use withdrawTo function if destination address specified
		txHash, err = paymentsTransactClient.WithdrawTo(tokenAddress, toAddress, amount)
	}

	if err != nil {
		return fmt.Errorf("failed to withdraw: %v", err)
	}

	fmt.Printf("✅ Withdrawal transaction sent: %s\n", txHash)

	// Wait for transaction to be mined using the payments client's ethclient
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(paymentsTransactClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("✅ Withdrawal completed successfully!\n")
	fmt.Printf("   Transaction: %s\n", txHash)
	fmt.Printf("   Amount: %s\n", amount.String())
	fmt.Printf("   From: %s\n", userAddress.Hex())
	fmt.Printf("   To: %s\n", toAddress.Hex())

	return nil
} 