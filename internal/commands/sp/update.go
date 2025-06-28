package sp

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/utils"
)

func UpdateCommand() *cli.Command {
	return &cli.Command{
		Name:    "update",
		Aliases: []string{"upd"},
		Usage:   "Update storage provider configuration",
		Subcommands: []*cli.Command{
			UpdateConfigCommand(),
			UpdateTokenCommand(),
			AddTokenCommand(),
		},
	}
}

func UpdateConfigCommand() *cli.Command {
	return &cli.Command{
		Name:    "config",
		Aliases: []string{"cfg"},
		Usage:   "Update storage provider basic configuration",
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
			},
			&cli.Uint64Flag{
				Name:    "max-piece-size",
				Aliases: []string{"max-size"},
				Usage:   "Maximum piece size in bytes",
			},
			&cli.Int64Flag{
				Name:    "min-term",
				Aliases: []string{"mt"},
				Usage:   "Minimum term length in epochs",
			},
			&cli.Int64Flag{
				Name:    "max-term",
				Aliases: []string{"Mt"},
				Usage:   "Maximum term length in epochs",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Show what would be updated without sending transaction",
			},
		},
		Action: executeUpdateSPConfig,
	}
}

func UpdateTokenCommand() *cli.Command {
	return &cli.Command{
		Name:    "token",
		Aliases: []string{"tok"},
		Usage:   "Update existing token configuration",
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
			&cli.Uint64Flag{
				Name:     "actor-id",
				Aliases:  []string{"id"},
				Usage:    "Filecoin actor ID of the storage provider",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address to update",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "price",
				Aliases:  []string{"p"},
				Usage:    "Price in USD per TB per month (e.g., '10.50')",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "active",
				Usage: "Set token as active",
				Value: true,
			},
			&cli.BoolFlag{
				Name:  "inactive",
				Usage: "Set token as inactive",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Show what would be updated without sending transaction",
			},
		},
		Action: executeUpdateSPToken,
	}
}

func AddTokenCommand() *cli.Command {
	return &cli.Command{
		Name:    "add-token",
		Aliases: []string{"add"},
		Usage:   "Add new token configuration",
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
			&cli.Uint64Flag{
				Name:     "actor-id",
				Aliases:  []string{"id"},
				Usage:    "Filecoin actor ID of the storage provider",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address to add",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "price",
				Aliases:  []string{"p"},
				Usage:    "Price in USD per TB per month (e.g., '10.50')",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Show what would be added without sending transaction",
			},
		},
		Action: executeAddSPToken,
	}
}

func executeUpdateSPConfig(c *cli.Context) error {
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

	actorId := c.Uint64("actor-id")
	paymentAddress := c.String("payment-address")

	if !common.IsHexAddress(paymentAddress) {
		return fmt.Errorf("invalid payment address: %s", paymentAddress)
	}

	// Create contract client to get current config
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Get current SP configuration
	currentConfig, err := ddoClient.GetSPConfig(actorId)
	if err != nil {
		return fmt.Errorf("failed to get current SP config: %v", err)
	}
	if currentConfig == nil {
		return fmt.Errorf("storage provider %d is not registered", actorId)
	}

	// Use current values as defaults if not provided
	minPieceSize := c.Uint64("min-piece-size")
	if minPieceSize == 0 {
		minPieceSize = currentConfig.MinPieceSize
	}

	maxPieceSize := c.Uint64("max-piece-size")
	if maxPieceSize == 0 {
		maxPieceSize = currentConfig.MaxPieceSize
	}

	minTerm := c.Int64("min-term")
	if minTerm == 0 {
		minTerm = currentConfig.MinTermLength
	}

	maxTerm := c.Int64("max-term")
	if maxTerm == 0 {
		maxTerm = currentConfig.MaxTermLength
	}

	// Validate ranges
	if minPieceSize == 0 || maxPieceSize < minPieceSize {
		return fmt.Errorf("invalid piece size range: min=%d, max=%d", minPieceSize, maxPieceSize)
	}
	if minTerm <= 0 || maxTerm < minTerm {
		return fmt.Errorf("invalid term range: min=%d, max=%d", minTerm, maxTerm)
	}

	fmt.Printf("📋 Storage Provider Config Update:\n")
	fmt.Printf("   Actor ID: %d\n", actorId)
	fmt.Printf("   Payment Address: %s → %s\n", currentConfig.PaymentAddress.Hex(), paymentAddress)
	fmt.Printf("   Min Piece Size: %s → %s\n", 
		utils.FormatBytes(new(big.Int).SetUint64(currentConfig.MinPieceSize)),
		utils.FormatBytes(new(big.Int).SetUint64(minPieceSize)))
	fmt.Printf("   Max Piece Size: %s → %s\n", 
		utils.FormatBytes(new(big.Int).SetUint64(currentConfig.MaxPieceSize)),
		utils.FormatBytes(new(big.Int).SetUint64(maxPieceSize)))
	fmt.Printf("   Min Term: %d → %d epochs\n", currentConfig.MinTermLength, minTerm)
	fmt.Printf("   Max Term: %d → %d epochs\n", currentConfig.MaxTermLength, maxTerm)
	fmt.Println()

	if c.Bool("dry-run") {
		fmt.Printf("🎯 Dry Run - Configuration validated successfully!\n")
		return nil
	}

	// Execute the transaction
	fmt.Printf("🚀 Updating storage provider configuration...\n")

	txHash, err := ddoClient.UpdateSPConfig(
		actorId,
		common.HexToAddress(paymentAddress),
		minPieceSize,
		maxPieceSize,
		minTerm,
		maxTerm,
	)
	if err != nil {
		return fmt.Errorf("failed to update SP config: %v", err)
	}

	fmt.Printf("✅ Update successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Wait for transaction to be mined using the existing client
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("✅ Update transaction mined successfully!\n")
	
	return nil
}

func executeUpdateSPToken(c *cli.Context) error {
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

	actorId := c.Uint64("actor-id")
	tokenAddress := c.String("token")
	priceUSD := c.String("price")

	if !common.IsHexAddress(tokenAddress) {
		return fmt.Errorf("invalid token address: %s", tokenAddress)
	}

	// Parse active flag (inactive overrides active)
	isActive := c.Bool("active")
	if c.Bool("inactive") {
		isActive = false
	}

	// Convert USD price to bytes per epoch
	pricePerBytePerEpoch, err := utils.ConvertUSDPerTBPerMonthToBytesPerEpoch(priceUSD)
	if err != nil {
		return fmt.Errorf("invalid USD price format: %v", err)
	}

	fmt.Printf("📋 Storage Provider Token Update:\n")
	fmt.Printf("   Actor ID: %d\n", actorId)
	fmt.Printf("   Token: %s\n", tokenAddress)
	fmt.Printf("   Price: %s\n", utils.FormatPriceBothFormats(pricePerBytePerEpoch))
	fmt.Printf("   Active: %t\n", isActive)
	fmt.Println()

	if c.Bool("dry-run") {
		fmt.Printf("🎯 Dry Run - Token configuration validated successfully!\n")
		return nil
	}

	// Create contract client
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Execute the transaction
	fmt.Printf("🚀 Updating token configuration...\n")

	txHash, err := ddoClient.UpdateSPToken(
		actorId,
		common.HexToAddress(tokenAddress),
		pricePerBytePerEpoch,
		isActive,
	)
	if err != nil {
		return fmt.Errorf("failed to update SP token: %v", err)
	}

	fmt.Printf("✅ Token update successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Wait for transaction to be mined using the existing client
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("✅ Token update transaction mined successfully!\n")
	
	return nil
}

func executeAddSPToken(c *cli.Context) error {
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

	actorId := c.Uint64("actor-id")
	tokenAddress := c.String("token")
	priceUSD := c.String("price")

	if !common.IsHexAddress(tokenAddress) {
		return fmt.Errorf("invalid token address: %s", tokenAddress)
	}

	// Convert USD price to bytes per epoch
	pricePerBytePerEpoch, err := utils.ConvertUSDPerTBPerMonthToBytesPerEpoch(priceUSD)
	if err != nil {
		return fmt.Errorf("invalid USD price format: %v", err)
	}

	fmt.Printf("📋 Storage Provider Token Addition:\n")
	fmt.Printf("   Actor ID: %d\n", actorId)
	fmt.Printf("   Token: %s\n", tokenAddress)
	fmt.Printf("   Price: %s\n", utils.FormatPriceBothFormats(pricePerBytePerEpoch))
	fmt.Printf("   Active: true\n")
	fmt.Println()

	if c.Bool("dry-run") {
		fmt.Printf("🎯 Dry Run - Token configuration validated successfully!\n")
		return nil
	}

	// Create contract client
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Execute the transaction
	fmt.Printf("🚀 Adding token configuration...\n")

	txHash, err := ddoClient.AddSPToken(
		actorId,
		common.HexToAddress(tokenAddress),
		pricePerBytePerEpoch,
	)
	if err != nil {
		return fmt.Errorf("failed to add SP token: %v", err)
	}

	fmt.Printf("✅ Token addition successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Wait for transaction to be mined using the existing client
	fmt.Printf("⏳ Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("⚠️  Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("✅ Token addition transaction mined successfully!\n")
	
	return nil
} 