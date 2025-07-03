package sp

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/contract/payments"
	"ddo-client/internal/utils"
)

func SettleCommand() *cli.Command {
	return &cli.Command{
		Name:    "settle",
		Aliases: []string{"settlement"},
		Usage:   "Settle storage provider payments for allocations",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "Contract address (overrides DDO_CONTRACT_ADDRESS env var)",
			},
			&cli.StringFlag{
				Name:    "payments-contract",
				Aliases: []string{"pc"},
				Usage:   "Payments contract address (optional - will fetch from DDO contract if not provided)",
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
			&cli.Uint64Flag{
				Name:     "provider",
				Aliases:  []string{"p"},
				Usage:    "Storage provider ID (required if allocation-id is not specified)",
			},
			&cli.Uint64Flag{
				Name:    "allocation-id",
				Aliases: []string{"a"},
				Usage:   "Specific allocation ID to settle (optional - if not provided, settles all allocations for the provider)",
			},
			&cli.Uint64Flag{
				Name:    "until-epoch",
				Aliases: []string{"e"},
				Usage:   "Epoch until which to settle (optional - defaults to current block number)",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Show what would be settled without executing transactions",
			},
		},
		Action: executeSettle,
	}
}

func executeSettle(c *cli.Context) error {
	// Override global config with command line flags if provided
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
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

	providerId := c.Uint64("provider")
	allocationId := c.Uint64("allocation-id")
	untilEpoch := c.Uint64("until-epoch")

	// Validate input parameters
	if allocationId == 0 && providerId == 0 {
		return fmt.Errorf("either --provider or --allocation-id must be specified")
	}

	// Create contract client
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Get current block number if until-epoch not specified
	if untilEpoch == 0 {
		ethClient, err := ethclient.Dial(config.RPCEndpoint)
		if err != nil {
			return fmt.Errorf("failed to create eth client: %v", err)
		}
		defer ethClient.Close()

		currentBlock, err := ethClient.BlockNumber(context.TODO())
		if err != nil {
			return fmt.Errorf("failed to get current block number: %v", err)
		}
		untilEpoch = currentBlock
		fmt.Printf("Using current block number as until-epoch: %d\n", untilEpoch)
	}

	// Get user address from private key for display
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Determine the provider ID to use for getting SP info
	targetProviderId := providerId
	if allocationId > 0 {
		// Get provider ID from allocation
		_, providerIdFromAllocation, _, err := ddoClient.GetAllocationRailInfo(allocationId)
		if err != nil {
			return fmt.Errorf("failed to get allocation rail info: %v", err)
		}
		targetProviderId = providerIdFromAllocation
	}

	// Get SP configuration to find payment address and supported tokens
	fmt.Printf("🔍 Getting SP information for provider %d...\n", targetProviderId)
	spConfig, err := ddoClient.GetSPConfig(targetProviderId)
	if err != nil {
		return fmt.Errorf("failed to get SP config for provider %d: %v", targetProviderId, err)
	}
	if spConfig == nil {
		return fmt.Errorf("SP %d is not registered", targetProviderId)
	}

	// Get payments contract address
	var paymentsContractAddr common.Address
	paymentsContractStr := c.String("payments-contract"); 
	fmt.Println("payments contract string is" , paymentsContractStr)
	if paymentsContractStr != "" {
		paymentsContractAddr = common.HexToAddress(paymentsContractStr)
		fmt.Printf("Using provided payments contract address: %s\n", paymentsContractAddr.Hex())
	} else {
		// Get payments contract address from DDO contract
		paymentsContractAddr, err = ddoClient.GetPaymentsContract()
		if err != nil {
			return fmt.Errorf("failed to get payments contract address from DDO contract: %v", err)
		}
		fmt.Printf("Fetched payments contract address from DDO: %s\n", paymentsContractAddr.Hex())
	}

	// Override payments contract address in config temporarily
	originalPaymentsContract := config.PaymentsContractAddress
	config.PaymentsContractAddress = paymentsContractAddr.Hex()
	defer func() {
		config.PaymentsContractAddress = originalPaymentsContract
	}()

	// Create payments client after configuring the address
	paymentsClient, err := payments.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create payments client: %v", err)
	}
	defer paymentsClient.Close()

	fmt.Printf("🏦 Settlement Parameters:\n")
	fmt.Printf("   User Address: %s\n", userAddress.Hex())
	fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("   Payments Contract: %s\n", paymentsContractAddr.Hex())
	fmt.Printf("   Until Epoch: %d\n", untilEpoch)
	fmt.Printf("   SP Payment Address: %s\n", spConfig.PaymentAddress.Hex())
	fmt.Printf("   SP Active Tokens: %d\n", len(spConfig.SupportedTokens))
	fmt.Println()

	// Log SP supported tokens
	fmt.Printf("📋 SP Supported Tokens:\n")
	for i, tokenConfig := range spConfig.SupportedTokens {
		status := "inactive"
		if tokenConfig.IsActive {
			status = "active"
		}
		if tokenConfig.Token.Hex() == "0x0000000000000000000000000000000000000000" {
			fmt.Printf("   %d. Native Token (FIL) - %s (price: %s)\n", 
				i+1, status, utils.FormatPriceBothFormats(tokenConfig.PricePerBytePerEpoch))
		} else {
			fmt.Printf("   %d. %s - %s (price: %s)\n", 
				i+1, tokenConfig.Token.Hex(), status, utils.FormatPriceBothFormats(tokenConfig.PricePerBytePerEpoch))
		}
	}
	fmt.Println()

	if c.Bool("dry-run") {
		if allocationId > 0 {
			fmt.Printf("   Mode: Single Allocation Settlement\n")
			fmt.Printf("   Allocation ID: %d\n", allocationId)
			
			// Get allocation details for dry run
			railId, providerIdFromAllocation, railView, err := ddoClient.GetAllocationRailInfo(allocationId)
			if err != nil {
				return fmt.Errorf("failed to get allocation rail info: %v", err)
			}
			
			fmt.Printf("\n📊 Allocation Details:\n")
			fmt.Printf("   Provider ID: %d\n", providerIdFromAllocation)
			fmt.Printf("   Rail ID: %d\n", railId)
			fmt.Printf("   Current Payment Rate: %s\n", railView.PaymentRate.String())
			fmt.Printf("   Settled Up To: %d\n", railView.SettledUpTo.Uint64())
			fmt.Printf("   Token: %s\n", railView.Token.Hex())
		} else {
			fmt.Printf("   Mode: Total Provider Settlement\n")
			fmt.Printf("   Provider ID: %d\n", providerId)
			
			// Get all allocations for provider for dry run
			allocationIds, err := ddoClient.GetAllocationIdsForProvider(providerId)
			if err != nil {
				return fmt.Errorf("failed to get allocation IDs for provider: %v", err)
			}
			
			fmt.Printf("\n📋 Provider Allocation Summary:\n")
			fmt.Printf("   Total Allocations: %d\n", len(allocationIds))
			fmt.Printf("   Allocation IDs: %v\n", allocationIds)
		}
		
		fmt.Printf("\n📝 Next Steps:\n")
		fmt.Printf("1. Run without --dry-run to execute settlement\n")
		fmt.Printf("2. Ensure you have sufficient gas for the transaction(s)\n")
		return nil
	}

	// Get SP account information from payments contract before settlement
	fmt.Printf("💰 Checking SP account information before settlement...\n")
	for i, tokenConfig := range spConfig.SupportedTokens {
		if !tokenConfig.IsActive {
			continue
		}
		
		account, err := paymentsClient.GetAccount(tokenConfig.Token, spConfig.PaymentAddress)
		if err != nil {
			fmt.Printf("⚠️  Warning: failed to get account info for token %d (%s): %v\n", i+1, tokenConfig.Token.Hex(), err)
			continue
		}
		
		tokenName := tokenConfig.Token.Hex()
		if tokenConfig.Token.Hex() == "0x0000000000000000000000000000000000000000" {
			tokenName = "Native Token (ETH)"
		}
		
		fmt.Printf("🔍 SP Account Info (Before) - %s:\n", tokenName)
		fmt.Printf("   Funds: %s\n", account.Funds.String())
		fmt.Printf("   Lockup Current: %s\n", account.LockupCurrent.String())
		fmt.Printf("   Lockup Rate: %s\n", account.LockupRate.String())
		fmt.Printf("   Lockup Last Settled At: %s\n", account.LockupLastSettledAt.String())
		fmt.Println()
	}

	// Execute settlement based on parameters
	var txHash string
	if allocationId > 0 {
		// Settle specific allocation
		fmt.Printf("💰 Settling payment for allocation %d until epoch %d...\n", allocationId, untilEpoch)
		
		txHash, err = ddoClient.SettleSpPayment(allocationId, new(big.Int).SetUint64(untilEpoch))
		if err != nil {
			return fmt.Errorf("failed to settle SP payment for allocation %d: %v", allocationId, err)
		}
		
		fmt.Printf("✅ Settlement transaction successful!\n")
		fmt.Printf("Transaction Hash: %s\n", txHash)
	} else {
		// Settle all allocations for provider
		fmt.Printf("💰 Settling payments for all allocations of provider %d until epoch %d...\n", providerId, untilEpoch)
		
		txHash, err = ddoClient.SettleSpTotalPayment(providerId, new(big.Int).SetUint64(untilEpoch))
		if err != nil {
			return fmt.Errorf("failed to settle total SP payments for provider %d: %v", providerId, err)
		}
		
		fmt.Printf("✅ Total settlement transaction successful!\n")
		fmt.Printf("Transaction Hash: %s\n", txHash)
	}

	// Wait for transaction to be mined
	fmt.Printf("⏳ Waiting for settlement transaction to be mined...\n")
	ethClient, err := ethclient.Dial(config.RPCEndpoint)
	if err != nil {
		fmt.Printf("⚠️  Warning: failed to create eth client for transaction wait: %v\n", err)
	} else {
		defer ethClient.Close()
		if err := utils.WaitForTransaction(ethClient, txHash); err != nil {
			fmt.Printf("⚠️  Warning: settlement transaction may not have been mined: %v\n", err)
		} else {
			fmt.Printf("✅ Settlement transaction mined successfully\n")
		}
	}
	fmt.Println()

	// Get SP account information from payments contract after settlement
	fmt.Printf("💰 Checking SP account information after settlement...\n")
	for i, tokenConfig := range spConfig.SupportedTokens {
		if !tokenConfig.IsActive {
			continue
		}
		
		account, err := paymentsClient.GetAccount(tokenConfig.Token, spConfig.PaymentAddress)
		if err != nil {
			fmt.Printf("⚠️  Warning: failed to get account info for token %d (%s): %v\n", i+1, tokenConfig.Token.Hex(), err)
			continue
		}
		
		tokenName := tokenConfig.Token.Hex()
		if tokenConfig.Token.Hex() == "0x0000000000000000000000000000000000000000" {
			tokenName = "Native Token (ETH)"
		}
		
		fmt.Printf("🔍 SP Account Info (After) - %s:\n", tokenName)
		fmt.Printf("   Funds: %s\n", account.Funds.String())
		fmt.Printf("   Lockup Current: %s\n", account.LockupCurrent.String())
		fmt.Printf("   Lockup Rate: %s\n", account.LockupRate.String())
		fmt.Printf("   Lockup Last Settled At: %s\n", account.LockupLastSettledAt.String())
		fmt.Println()
	}

	return nil
} 