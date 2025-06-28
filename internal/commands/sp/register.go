package sp

import (
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/types"
	"ddo-client/internal/utils"
)

func RegisterCommand() *cli.Command {
	return &cli.Command{
		Name:    "register",
		Aliases: []string{"reg"},
		Usage:   "Register a new storage provider with the DDO contract",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "Contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
			// SP Configuration
			&cli.Uint64Flag{
				Name:     "actor-id",
				Aliases:  []string{"id"},
				Usage:    "Filecoin actor ID of the storage provider",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "payment-address",
				Aliases:  []string{"pa"},
				Usage:    "Address where payments will be sent",
				Required: true,
			},
			&cli.Uint64Flag{
				Name:    "min-piece-size",
				Aliases: []string{"min-size"},
				Usage:   "Minimum piece size in bytes",
				Value:   128, // 128 bytes default
			},
			&cli.Uint64Flag{
				Name:    "max-piece-size",
				Aliases: []string{"max-size"},
				Usage:   "Maximum piece size in bytes",
				Value:   34359738368, // 32GB default
			},
			&cli.Int64Flag{
				Name:    "min-term",
				Aliases: []string{"mt"},
				Usage:   "Minimum term length in epochs",
				Value:   86400, // 30 days default
			},
			&cli.Int64Flag{
				Name:    "max-term",
				Aliases: []string{"Mt"},
				Usage:   "Maximum term length in epochs",
				Value:   5256000, // ~1820 days default
			},
			// Token Configuration
			&cli.StringSliceFlag{
				Name:     "tokens",
				Aliases:  []string{"t"},
				Usage:    "Token configurations in format 'address:priceUSDPerTBPerMonth' where price is in USD per TB per month (e.g., '10.50')",
				Required: true,
			},
			&cli.StringFlag{
				Name:  "tokens-file",
				Usage: "JSON file containing token configurations",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Show configuration without sending transaction",
			},
		},
		Action: executeRegisterSP,
	}
}

// TokenConfigInput represents token configuration from CLI input
type TokenConfigInput struct {
	Token               string `json:"token"`
	PriceUSDPerTBPerMonth string `json:"priceUSDPerTBPerMonth"`
	IsActive            bool   `json:"isActive"`
}

// TokenConfigFile represents the structure of the tokens JSON file
type TokenConfigFile struct {
	Tokens []TokenConfigInput `json:"tokens"`
}

func executeRegisterSP(c *cli.Context) error {
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

	// Parse SP parameters
	actorId := c.Uint64("actor-id")
	paymentAddress := c.String("payment-address")
	minPieceSize := c.Uint64("min-piece-size")
	maxPieceSize := c.Uint64("max-piece-size")
	minTerm := c.Int64("min-term")
	maxTerm := c.Int64("max-term")

	// Validate payment address
	if !common.IsHexAddress(paymentAddress) {
		return fmt.Errorf("invalid payment address: %s", paymentAddress)
	}

	// Validate size and term ranges
	if minPieceSize == 0 || maxPieceSize < minPieceSize {
		return fmt.Errorf("invalid piece size range: min=%d, max=%d", minPieceSize, maxPieceSize)
	}
	if minTerm <= 0 || maxTerm < minTerm {
		return fmt.Errorf("invalid term range: min=%d, max=%d", minTerm, maxTerm)
	}

	// Parse token configurations
	var tokenInputs []TokenConfigInput
	
	// First check if tokens file is provided
	if tokensFile := c.String("tokens-file"); tokensFile != "" {
		data, err := os.ReadFile(tokensFile)
		if err != nil {
			return fmt.Errorf("failed to read tokens file: %w", err)
		}

		var configFile TokenConfigFile
		if err := json.Unmarshal(data, &configFile); err != nil {
			return fmt.Errorf("failed to parse tokens file: %w", err)
		}

		tokenInputs = configFile.Tokens
	} else {
		// Parse from command line flags
		tokenStrings := c.StringSlice("tokens")
		if len(tokenStrings) == 0 {
			return fmt.Errorf("at least one token configuration is required")
		}

		for _, tokenStr := range tokenStrings {
			parts := strings.Split(tokenStr, ":")
			if len(parts) != 2 {
				return fmt.Errorf("invalid token format '%s', expected 'address:priceUSDPerTBPerMonth'", tokenStr)
			}

			tokenInputs = append(tokenInputs, TokenConfigInput{
				Token:               parts[0],
				PriceUSDPerTBPerMonth: parts[1],
				IsActive:           true,
			})
		}
	}

	// Convert token inputs to contract format
	tokenConfigs := make([]types.TokenConfig, len(tokenInputs))
	for i, tokenInput := range tokenInputs {
		if !common.IsHexAddress(tokenInput.Token) {
			return fmt.Errorf("invalid token address: %s", tokenInput.Token)
		}

		// Parse price as USD per TB per month and convert to bytes per epoch in token units
		pricePerBytePerEpoch, err := utils.ConvertUSDPerTBPerMonthToBytesPerEpoch(tokenInput.PriceUSDPerTBPerMonth)
		if err != nil {
			return fmt.Errorf("invalid USD price format for token %s: %v", tokenInput.Token, err)
		}

		tokenConfigs[i] = types.TokenConfig{
			Token:               common.HexToAddress(tokenInput.Token),
			PricePerBytePerEpoch: pricePerBytePerEpoch,
			IsActive:            tokenInput.IsActive,
		}

		// Show both formats for clarity
		fmt.Printf("   Token %s: %s\n", 
			tokenInput.Token, 
			utils.FormatPriceBothFormats(pricePerBytePerEpoch))
	}

	// Create registration parameters
	regParams := types.SPRegistrationParams{
		ActorId:        actorId,
		PaymentAddress: common.HexToAddress(paymentAddress),
		MinPieceSize:   minPieceSize,
		MaxPieceSize:   maxPieceSize,
		MinTermLength:  minTerm,
		MaxTermLength:  maxTerm,
		TokenConfigs:   tokenConfigs,
	}

	fmt.Printf("📋 Storage Provider Registration Details:\n")
	fmt.Printf("   Actor ID: %d\n", regParams.ActorId)
	fmt.Printf("   Payment Address: %s\n", regParams.PaymentAddress.Hex())
	fmt.Printf("   Piece Size Range: %s - %s\n", 
		utils.FormatBytes(new(big.Int).SetUint64(regParams.MinPieceSize)),
		utils.FormatBytes(new(big.Int).SetUint64(regParams.MaxPieceSize)))
	fmt.Printf("   Term Range: %d - %d epochs\n", regParams.MinTermLength, regParams.MaxTermLength)
	fmt.Printf("   Term Range (days): ~%.1f - ~%.1f days\n", 
		float64(regParams.MinTermLength)/2880.0, 
		float64(regParams.MaxTermLength)/2880.0)
	fmt.Println()

	fmt.Printf("🪙 Supported Token Configurations (%d tokens):\n", len(tokenConfigs))
	for i, tc := range tokenConfigs {
		fmt.Printf("   %d. Token: %s\n", i+1, tc.Token.Hex())
		fmt.Printf("      Actual price after Rounding off (bytes per epoch): %s\n", utils.FormatPriceBothFormats(tc.PricePerBytePerEpoch))
		fmt.Printf("      Active: %t\n", tc.IsActive)
		if i < len(tokenConfigs)-1 {
			fmt.Println()
		}
	}
	fmt.Println()

	// If dry run, just show configuration
	if c.Bool("dry-run") {
		fmt.Printf("🎯 Dry Run Results:\n\n")

		// Check if SP is already registered
		ddoClient, err := ddo.NewClient()
		if err != nil {
			return fmt.Errorf("failed to create DDO contract client: %v", err)
		}

		isRegistered, err := ddoClient.IsSPRegistered(actorId)
		if err != nil {
			fmt.Printf("⚠️  Could not check SP registration status: %v\n", err)
		} else if isRegistered {
			fmt.Printf("⚠️  Storage Provider %d is already registered\n", actorId)
			
			// Get existing config
			existingConfig, err := ddoClient.GetSPConfig(actorId)
			if err != nil {
				fmt.Printf("⚠️  Could not retrieve existing config: %v\n", err)
			} else {
				fmt.Printf("📋 Current Configuration:\n")
				fmt.Printf("   Payment Address: %s\n", existingConfig.PaymentAddress.Hex())
				fmt.Printf("   Piece Size Range: %s - %s\n", 
					utils.FormatBytes(new(big.Int).SetUint64(existingConfig.MinPieceSize)),
					utils.FormatBytes(new(big.Int).SetUint64(existingConfig.MaxPieceSize)))
				fmt.Printf("   Term Range: %d - %d epochs\n", existingConfig.MinTermLength, existingConfig.MaxTermLength)
				fmt.Printf("   Active: %t\n", existingConfig.IsActive)
				fmt.Printf("   Supported Tokens: %d\n", len(existingConfig.SupportedTokens))
			}
		} else {
			fmt.Printf("✅ Storage Provider %d is not registered yet\n", actorId)
		}
		
		fmt.Printf("Configuration validated successfully!\n")
		fmt.Printf("Contract: %s\n", config.ContractAddress)
		fmt.Printf("RPC: %s\n", config.RPCEndpoint)
		fmt.Println()
		fmt.Printf("📝 Next Steps:\n")
		fmt.Printf("1. Ensure you are the contract owner\n")
		fmt.Printf("2. Run without --dry-run to execute registration\n")
		return nil
	}

	// Create contract client
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Execute the transaction
	fmt.Printf("🚀 Registering storage provider...\n")
	fmt.Printf("DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)

	txHash, err := ddoClient.RegisterSP(regParams)
	if err != nil {
		return fmt.Errorf("failed to register SP: %v", err)
	}

	fmt.Printf("✅ Registration successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Wait for transaction to be mined using the existing client
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("✅ Registration transaction mined successfully!\n")
	
	return nil
} 