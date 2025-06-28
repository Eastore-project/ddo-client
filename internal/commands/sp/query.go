package sp

import (
	"fmt"
	"math/big"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/utils"
)

func QueryCommand() *cli.Command {
	return &cli.Command{
		Name:    "query",
		Aliases: []string{"q"},
		Usage:   "Query storage provider information and configuration",
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
			&cli.Uint64Flag{
				Name:     "actor-id",
				Aliases:  []string{"id"},
				Usage:    "Filecoin actor ID of the storage provider",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "json",
				Usage: "Output in JSON format",
			},
		},
		Action: executeQuerySP,
	}
}

func executeQuerySP(c *cli.Context) error {
	// Override global config with command line flags if provided
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}

	// Validate required configuration (only need contract and RPC for queries)
	if config.ContractAddress == "" {
		return fmt.Errorf("missing DDO contract address (use --contract flag or DDO_CONTRACT_ADDRESS env var)")
	}
	if config.RPCEndpoint == "" {
		return fmt.Errorf("missing RPC endpoint (use --rpc flag or RPC_URL env var)")
	}

	actorId := c.Uint64("actor-id")

	// Create read-only contract client
	ddoClient, err := ddo.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Get SP configuration
	spConfig, err := ddoClient.GetSPConfig(actorId)
	if err != nil {
		return fmt.Errorf("failed to get SP config: %v", err)
	}

	if spConfig == nil {
		fmt.Printf("❌ Storage Provider %d is not registered\n", actorId)
		return nil
	}

	// Output in JSON format if requested
	if c.Bool("json") {
		fmt.Printf("{\n")
		fmt.Printf("  \"actorId\": %d,\n", actorId)
		fmt.Printf("  \"paymentAddress\": \"%s\",\n", spConfig.PaymentAddress.Hex())
		fmt.Printf("  \"minPieceSize\": %d,\n", spConfig.MinPieceSize)
		fmt.Printf("  \"maxPieceSize\": %d,\n", spConfig.MaxPieceSize)
		fmt.Printf("  \"minTermLength\": %d,\n", spConfig.MinTermLength)
		fmt.Printf("  \"maxTermLength\": %d,\n", spConfig.MaxTermLength)
		fmt.Printf("  \"isActive\": %t,\n", spConfig.IsActive)
		fmt.Printf("  \"supportedTokens\": [\n")
		for i, token := range spConfig.SupportedTokens {
			fmt.Printf("    {\n")
			fmt.Printf("      \"token\": \"%s\",\n", token.Token.Hex())
			fmt.Printf("      \"pricePerBytePerEpoch\": \"%s\",\n", token.PricePerBytePerEpoch.String())
			fmt.Printf("      \"pricePerTBPerMonth\": \"%s\",\n", utils.ConvertBytesPerEpochToTBPerMonth(token.PricePerBytePerEpoch).String())
			fmt.Printf("      \"isActive\": %t\n", token.IsActive)
			if i < len(spConfig.SupportedTokens)-1 {
				fmt.Printf("    },\n")
			} else {
				fmt.Printf("    }\n")
			}
		}
		fmt.Printf("  ]\n")
		fmt.Printf("}\n")
		return nil
	}

	// Human-readable format
	fmt.Printf("📋 Storage Provider Information\n")
	fmt.Printf("=====================================\n\n")

	fmt.Printf("🆔 Basic Information:\n")
	fmt.Printf("   Actor ID: %d\n", actorId)
	fmt.Printf("   Payment Address: %s\n", spConfig.PaymentAddress.Hex())
	fmt.Printf("   Status: %s\n", func() string {
		if spConfig.IsActive {
			return "✅ Active"
		}
		return "❌ Inactive"
	}())
	fmt.Println()

	fmt.Printf("📏 Capacity Limits:\n")
	fmt.Printf("   Min Piece Size: %s (%d bytes)\n", 
		utils.FormatBytes(new(big.Int).SetUint64(spConfig.MinPieceSize)), 
		spConfig.MinPieceSize)
	fmt.Printf("   Max Piece Size: %s (%d bytes)\n", 
		utils.FormatBytes(new(big.Int).SetUint64(spConfig.MaxPieceSize)), 
		spConfig.MaxPieceSize)
	fmt.Println()

	fmt.Printf("⏰ Term Limits:\n")
	fmt.Printf("   Min Term: %d epochs (~%.1f days)\n", 
		spConfig.MinTermLength, 
		float64(spConfig.MinTermLength)/2880.0)
	fmt.Printf("   Max Term: %d epochs (~%.1f days)\n", 
		spConfig.MaxTermLength, 
		float64(spConfig.MaxTermLength)/2880.0)
	fmt.Println()

	fmt.Printf("🪙 Supported Tokens (%d tokens):\n", len(spConfig.SupportedTokens))
	if len(spConfig.SupportedTokens) == 0 {
		fmt.Printf("   No tokens configured\n")
	} else {
		for i, token := range spConfig.SupportedTokens {
			status := "✅ Active"
			if !token.IsActive {
				status = "❌ Inactive"
			}

			fmt.Printf("   %d. %s\n", i+1, status)
			fmt.Printf("      Token Address: %s\n", token.Token.Hex())
			fmt.Printf("      Price: %s\n", utils.FormatPriceBothFormats(token.PricePerBytePerEpoch))
			
			// Calculate example costs for common scenarios
			exampleSizes := []uint64{
				1024 * 1024,                    // 1 MB
				1024 * 1024 * 1024,             // 1 GB
				32 * 1024 * 1024 * 1024,        // 32 GB
			}
			
			exampleTerms := []int64{
				86400,   // 30 days
				518400,  // 180 days
				1036800, // 360 days
			}

			fmt.Printf("      Example Costs:\n")
			for _, size := range exampleSizes {
				if size >= spConfig.MinPieceSize && size <= spConfig.MaxPieceSize {
					for _, term := range exampleTerms {
						if term >= spConfig.MinTermLength && term <= spConfig.MaxTermLength {
							cost := new(big.Int).Mul(
								token.PricePerBytePerEpoch,
								new(big.Int).SetUint64(size),
							)
							cost.Mul(cost, big.NewInt(term))
							
							fmt.Printf("        %s for %d days: %s USDC\n",
								utils.FormatBytes(new(big.Int).SetUint64(size)),
								term/2880,
								utils.ConvertTokenUnitsToUSD(cost))
						}
					}
				}
			}
			
			if i < len(spConfig.SupportedTokens)-1 {
				fmt.Println()
			}
		}
	}

	return nil
} 