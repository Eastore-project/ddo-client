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

func SetOperatorAllowanceCommand() *cli.Command {
	return &cli.Command{
		Name:    "set-operator-allowance",
		Aliases: []string{"soa", "set-allowance"},
		Usage:   "Set or update operator approval and allowances",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "ERC20 token contract address",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "operator",
				Aliases:  []string{"o"},
				Usage:    "Operator address to grant approval to",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "approved",
				Usage: "Whether the operator is approved (true) or not (false)",
				Value: true,
			},
			&cli.StringFlag{
				Name:    "rate-allowance",
				Aliases: []string{"ra"},
				Usage:   "Maximum payment rate the operator can set (defaults to current value)",
			},
			&cli.StringFlag{
				Name:    "lockup-allowance",
				Aliases: []string{"la"},
				Usage:   "Maximum amount of funds the operator can lock up (defaults to current value)",
			},
			&cli.StringFlag{
				Name:    "max-lockup-period",
				Aliases: []string{"mlp"},
				Usage:   "Maximum number of epochs the operator can lock funds for (defaults to current value)",
			},
			&cli.BoolFlag{
				Name:  "unlimited",
				Usage: "Set unlimited allowances for rate and lockup",
			},
			&cli.BoolFlag{
				Name:  "check-only",
				Usage: "Only check current operator approval without setting",
			},
		}...),
		Action: executeSetOperatorAllowance,
	}
}

func executeSetOperatorAllowance(c *cli.Context) error {
	// Validate private key configuration
	if err := validatePrivateKeyConfig(c); err != nil {
		return err
	}

	tokenAddress := common.HexToAddress(c.String("token"))
	operatorAddress := common.HexToAddress(c.String("operator"))
	approved := c.Bool("approved")
	checkOnly := c.Bool("check-only")
	unlimited := c.Bool("unlimited")

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Create payments client
	paymentsClient, err := payments.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create payments client: %v", err)
	}
	defer paymentsClient.Close()

	fmt.Printf("🔍 Operator Allowance Management:\n")
	fmt.Printf("   Account: %s\n", userAddress.Hex())
	fmt.Printf("   Token: %s\n", tokenAddress.Hex())
	fmt.Printf("   Operator: %s\n", operatorAddress.Hex())
	fmt.Println()

	// Check current operator approval
	currentApproval, err := paymentsClient.GetOperatorApproval(tokenAddress, userAddress, operatorAddress)
	if err != nil {
		return fmt.Errorf("failed to get current operator approval: %v", err)
	}

	rateAvailable := new(big.Int).Sub(currentApproval.RateAllowance, currentApproval.RateUsage)
	lockupAvailable := new(big.Int).Sub(currentApproval.LockupAllowance, currentApproval.LockupUsage)

	fmt.Printf("📊 Current Status:\n")
	fmt.Printf("   Is Approved: %t\n", currentApproval.IsApproved)
	fmt.Printf("   Rate Allowance: %s\n", currentApproval.RateAllowance.String())
	fmt.Printf("   Rate Usage: %s\n", currentApproval.RateUsage.String())
	fmt.Printf("   Rate Available: %s\n", rateAvailable.String())
	fmt.Printf("   Lockup Allowance: %s\n", currentApproval.LockupAllowance.String())
	fmt.Printf("   Lockup Usage: %s\n", currentApproval.LockupUsage.String())
	fmt.Printf("   Lockup Available: %s\n", lockupAvailable.String())
	fmt.Printf("   Max Lockup Period: %s epochs\n", currentApproval.MaxLockupPeriod.String())
	fmt.Println()

	// If check-only, just display the information
	if checkOnly {
		fmt.Printf("✅ Operator approval check completed\n")
		return nil
	}

	// Determine the allowances to set
	var rateAllowance, lockupAllowance, maxLockupPeriod *big.Int

	if unlimited {
		// Use max uint256 for unlimited allowances
		maxUint256 := new(big.Int)
		maxUint256.SetString("115792089237316195423570985008687907853269984665640564039457584007913129639935", 10)
		rateAllowance = maxUint256
		lockupAllowance = maxUint256
		maxLockupPeriod = big.NewInt(525600) // 1 year in epochs (assuming ~1 minute per epoch)
		fmt.Printf("🔓 Setting unlimited allowances...\n")
	} else {
		// Parse provided values or use current values as defaults
		rateAllowanceStr := c.String("rate-allowance")
		if rateAllowanceStr != "" {
			rateAllowance = new(big.Int)
			var ok bool
			rateAllowance, ok = rateAllowance.SetString(rateAllowanceStr, 10)
			if !ok {
				return fmt.Errorf("invalid rate-allowance format: %s", rateAllowanceStr)
			}
		} else {
			// Default to current value if not specified
			rateAllowance = new(big.Int).Set(currentApproval.RateAllowance)
		}

		lockupAllowanceStr := c.String("lockup-allowance")
		if lockupAllowanceStr != "" {
			lockupAllowance = new(big.Int)
			var ok bool
			lockupAllowance, ok = lockupAllowance.SetString(lockupAllowanceStr, 10)
			if !ok {
				return fmt.Errorf("invalid lockup-allowance format: %s", lockupAllowanceStr)
			}
		} else {
			// Default to current value if not specified
			lockupAllowance = new(big.Int).Set(currentApproval.LockupAllowance)
		}

		maxLockupPeriodStr := c.String("max-lockup-period")
		if maxLockupPeriodStr != "" {
			maxLockupPeriod = new(big.Int)
			var ok bool
			maxLockupPeriod, ok = maxLockupPeriod.SetString(maxLockupPeriodStr, 10)
			if !ok {
				return fmt.Errorf("invalid max-lockup-period format: %s", maxLockupPeriodStr)
			}
		} else {
			// Default to current value if not specified
			maxLockupPeriod = new(big.Int).Set(currentApproval.MaxLockupPeriod)
		}

		fmt.Printf("💰 Setting allowances:\n")
		if c.String("rate-allowance") != "" {
			fmt.Printf("   Rate Allowance: %s (new value)\n", rateAllowance.String())
		} else {
			fmt.Printf("   Rate Allowance: %s (keeping current)\n", rateAllowance.String())
		}
		if c.String("lockup-allowance") != "" {
			fmt.Printf("   Lockup Allowance: %s (new value)\n", lockupAllowance.String())
		} else {
			fmt.Printf("   Lockup Allowance: %s (keeping current)\n", lockupAllowance.String())
		}
		if c.String("max-lockup-period") != "" {
			fmt.Printf("   Max Lockup Period: %s epochs (new value)\n", maxLockupPeriod.String())
		} else {
			fmt.Printf("   Max Lockup Period: %s epochs (keeping current)\n", maxLockupPeriod.String())
		}
	}

	// Create payments client for transactions
	paymentsTransactClient, err := payments.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create payments transaction client: %v", err)
	}
	defer paymentsTransactClient.Close()

	// Send the set operator approval transaction
	fmt.Printf("📝 Sending operator approval transaction...\n")
	txHash, err := paymentsTransactClient.SetOperatorApproval(
		tokenAddress,
		operatorAddress,
		approved,
		rateAllowance,
		lockupAllowance,
		maxLockupPeriod,
	)
	if err != nil {
		return fmt.Errorf("failed to set operator approval: %v", err)
	}

	fmt.Printf("✅ Operator approval transaction sent: %s\n", txHash)

	// Wait for transaction to be mined using the payments client's ethclient
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(paymentsTransactClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	// Verify the new operator approval
	newApproval, err := paymentsClient.GetOperatorApproval(tokenAddress, userAddress, operatorAddress)
	if err != nil {
		fmt.Printf("⚠️  Warning: could not verify new operator approval: %v\n", err)
		return nil
	}

	newRateAvailable := new(big.Int).Sub(newApproval.RateAllowance, newApproval.RateUsage)
	newLockupAvailable := new(big.Int).Sub(newApproval.LockupAllowance, newApproval.LockupUsage)

	fmt.Printf("✅ Transaction mined successfully!\n")
	fmt.Printf("📊 New Operator Approval Status:\n")
	fmt.Printf("   Is Approved: %t\n", newApproval.IsApproved)
	fmt.Printf("   Rate Allowance: %s\n", newApproval.RateAllowance.String())
	fmt.Printf("   Rate Available: %s\n", newRateAvailable.String())
	fmt.Printf("   Lockup Allowance: %s\n", newApproval.LockupAllowance.String())
	fmt.Printf("   Lockup Available: %s\n", newLockupAvailable.String())
	fmt.Printf("   Max Lockup Period: %s epochs\n", newApproval.MaxLockupPeriod.String())

	return nil
} 