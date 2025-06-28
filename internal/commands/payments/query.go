package payments

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
)

// Query subcommands

func QueryContractInfoCommand() *cli.Command {
	return &cli.Command{
		Name:    "contract-info",
		Aliases: []string{"info"},
		Usage:   "Show contract basic information",
		Flags:   paymentsFlags,
		Action:  executeQueryContractInfo,
	}
}

func QueryAccountCommand() *cli.Command {
	return &cli.Command{
		Name:    "account",
		Aliases: []string{"acc"},
		Usage:   "Query account information",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "address",
				Aliases:  []string{"a"},
				Usage:    "Account address",
				Required: true,
			},
		}...),
		Action: executeQueryAccount,
	}
}

func QueryOperatorApprovalCommand() *cli.Command {
	return &cli.Command{
		Name:    "operator-approval",
		Aliases: []string{"op", "approval"},
		Usage:   "Query operator approval information",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "account",
				Aliases:  []string{"a"},
				Usage:    "Account address",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "operator",
				Aliases:  []string{"o"},
				Usage:    "Operator address",
				Required: true,
			},
		}...),
		Action: executeQueryOperatorApproval,
	}
}

func QueryRailCommand() *cli.Command {
	return &cli.Command{
		Name:    "rail",
		Aliases: []string{"r"},
		Usage:   "Query rail information by rail ID",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.Uint64Flag{
				Name:     "rail-id",
				Aliases:  []string{"id"},
				Usage:    "Rail ID",
				Required: true,
			},
		}...),
		Action: executeQueryRail,
	}
}

func QueryAccumulatedFeesCommand() *cli.Command {
	return &cli.Command{
		Name:    "accumulated-fees",
		Aliases: []string{"fees"},
		Usage:   "Query accumulated fees for a token",
		Flags: append(paymentsFlags, []cli.Flag{
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address",
				Required: true,
			},
		}...),
		Action: executeQueryAccumulatedFees,
	}
}

func QueryAllAccountsCommand() *cli.Command {
	return &cli.Command{
		Name:    "all-accounts",
		Aliases: []string{"all"},
		Usage:   "Query all accounts with accumulated fees",
		Flags:   paymentsFlags,
		Action:  executeQueryAllAccounts, 
	}
}

// Query command implementations

func executeQueryContractInfo(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	fmt.Printf("📋 Contract Information:\n")
	fmt.Printf("   Address: %s\n", config.PaymentsContractAddress)
	fmt.Printf("   RPC: %s\n", config.RPCEndpoint)
	fmt.Println()

	commissionMax, err := client.GetCommissionMaxBPS()
	if err != nil {
		return fmt.Errorf("failed to get commission max: %v", err)
	}

	paymentFee, err := client.GetPaymentFeeBPS()
	if err != nil {
		return fmt.Errorf("failed to get payment fee: %v", err)
	}

	fmt.Printf("   Commission Max BPS: %s\n", commissionMax.String())
	fmt.Printf("   Payment Fee BPS: %s\n", paymentFee.String())
	fmt.Println()

	return nil
}

func executeQueryAccount(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	tokenAddr := common.HexToAddress(c.String("token"))
	accountAddr := common.HexToAddress(c.String("address"))

	fmt.Printf("💰 Account Information:\n")
	fmt.Printf("   Token: %s\n", tokenAddr.Hex())
	fmt.Printf("   Account: %s\n", accountAddr.Hex())
	fmt.Println()

	account, err := client.GetAccount(tokenAddr, accountAddr)
	if err != nil {
		return fmt.Errorf("failed to get account: %v", err)
	}

	fmt.Printf("   Funds: %s\n", account.Funds.String())
	fmt.Printf("   Lockup Current: %s\n", account.LockupCurrent.String())
	fmt.Printf("   Lockup Rate: %s\n", account.LockupRate.String())
	fmt.Printf("   Lockup Last Settled At: %s\n", account.LockupLastSettledAt.String())
	fmt.Println()

	return nil
}

func executeQueryOperatorApproval(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	tokenAddr := common.HexToAddress(c.String("token"))
	accountAddr := common.HexToAddress(c.String("account"))
	operatorAddr := common.HexToAddress(c.String("operator"))

	fmt.Printf("🔐 Operator Approval:\n")
	fmt.Printf("   Token: %s\n", tokenAddr.Hex())
	fmt.Printf("   Account: %s\n", accountAddr.Hex())
	fmt.Printf("   Operator: %s\n", operatorAddr.Hex())
	fmt.Println()

	approval, err := client.GetOperatorApproval(tokenAddr, accountAddr, operatorAddr)
	if err != nil {
		return fmt.Errorf("failed to get operator approval: %v", err)
	}

	rateAvailable := new(big.Int).Sub(approval.RateAllowance, approval.RateUsage)
	lockupAvailable := new(big.Int).Sub(approval.LockupAllowance, approval.LockupUsage)

	fmt.Printf("   Is Approved: %t\n", approval.IsApproved)
	fmt.Printf("   Rate Allowance: %s\n", approval.RateAllowance.String())
	fmt.Printf("   Rate Usage: %s\n", approval.RateUsage.String())
	fmt.Printf("   Rate Available: %s\n", rateAvailable.String())
	fmt.Printf("   Lockup Allowance: %s\n", approval.LockupAllowance.String())
	fmt.Printf("   Lockup Usage: %s\n", approval.LockupUsage.String())
	fmt.Printf("   Lockup Available: %s\n", lockupAvailable.String())
	fmt.Printf("   Max Lockup Period: %s epochs\n", approval.MaxLockupPeriod.String())
	fmt.Println()

	return nil
}

func executeQueryRail(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	railId := big.NewInt(int64(c.Uint64("rail-id")))

	fmt.Printf("🚄 Rail Information:\n")
	fmt.Printf("   Rail ID: %s\n", railId.String())
	fmt.Println()

	rail, err := client.GetRail(railId)
	if err != nil {
		return fmt.Errorf("failed to get rail: %v", err)
	}

	fmt.Printf("   Token: %s\n", rail.Token.Hex())
	fmt.Printf("   From: %s\n", rail.From.Hex())
	fmt.Printf("   To: %s\n", rail.To.Hex())
	fmt.Printf("   Operator: %s\n", rail.Operator.Hex())
	fmt.Printf("   Validator: %s\n", rail.Validator.Hex())
	fmt.Printf("   Payment Rate: %s\n", rail.PaymentRate.String())
	fmt.Printf("   Lockup Period: %s epochs\n", rail.LockupPeriod.String())
	fmt.Printf("   Lockup Fixed: %s\n", rail.LockupFixed.String())
	fmt.Printf("   Settled Up To: %s\n", rail.SettledUpTo.String())
	fmt.Printf("   End Epoch: %s\n", rail.EndEpoch.String())
	fmt.Printf("   Commission Rate BPS: %s\n", rail.CommissionRateBps.String())
	fmt.Printf("   Service Fee Recipient: %s\n", rail.ServiceFeeRecipient.Hex())
	fmt.Println()

	return nil
}

func executeQueryAccumulatedFees(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	tokenAddr := common.HexToAddress(c.String("token"))

	fmt.Printf("💸 Accumulated Fees:\n")
	fmt.Printf("   Token: %s\n", tokenAddr.Hex())
	fmt.Println()

	fees, err := client.GetAccumulatedFees(tokenAddr)
	if err != nil {
		return fmt.Errorf("failed to get accumulated fees: %v", err)
	}

	hasCollected, err := client.GetHasCollectedFees(tokenAddr)
	if err != nil {
		return fmt.Errorf("failed to get hasCollectedFees: %v", err)
	}

	fmt.Printf("   Accumulated Fees: %s\n", fees.String())
	fmt.Printf("   Has Collected: %t\n", hasCollected)
	fmt.Println()

	return nil
}

func executeQueryAllAccounts(c *cli.Context) error {
	client, err := createPaymentsClient(c)
	if err != nil {
		return err
	}
	defer client.Close()

	fmt.Printf("📊 All Accumulated Fees:\n")
	fmt.Println()

	result, err := client.GetAllAccumulatedFees()
	if err != nil {
		return fmt.Errorf("failed to get all accumulated fees: %v", err)
	}

	fmt.Printf("   Total Count: %s\n", result.Count.String())
	fmt.Println()

	for i := 0; i < len(result.Tokens) && i < len(result.Amounts); i++ {
		fmt.Printf("   Token %d:\n", i+1)
		fmt.Printf("     Address: %s\n", result.Tokens[i].Hex())
		fmt.Printf("     Amount: %s\n", result.Amounts[i].String())
		fmt.Println()
	}

	return nil
} 