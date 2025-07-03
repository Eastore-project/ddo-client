package allocations

import (
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ipfs/go-cid"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/contract/payments"
	"ddo-client/internal/types"
	"ddo-client/internal/utils"
)

func CreateCommand() *cli.Command {
	return &cli.Command{
		Name:    "create",
		Aliases: []string{"c"},
		Usage:   "Create allocation requests on the DDO contract with payment setup",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "Contract address (overrides DDO_CONTRACT_ADDRESS env var)",
			},
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
				Name:    "input-file",
				Aliases: []string{"f"},
				Usage:   "JSON file containing piece infos",
			},
			// Individual piece info flags for single allocation
			&cli.StringFlag{
				Name:  "piece-cid",
				Usage: "Piece CID (e.g. baga6ea4seaq...)",
			},
			&cli.Uint64Flag{
				Name:  "size",
				Usage: "Piece size in bytes",
			},
			&cli.Uint64Flag{
				Name:  "provider",
				Usage: "Provider/Miner ID",
			},
			&cli.Int64Flag{
				Name:  "term-min",
				Usage: "Minimum term",
			},
			&cli.Int64Flag{
				Name:  "term-max",
				Usage: "Maximum term",
			},
			&cli.Int64Flag{
				Name:  "expiration-offset",
				Usage: "Expiration offset from current block",
				Value: 172800,
			},
			&cli.StringFlag{
				Name:  "download-url",
				Usage: "Download URL for the piece",
			},
			&cli.StringFlag{
				Name:  "payment-token",
				Usage: "Payment token address (required)",
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Calculate costs and requirements without sending transaction",
			},
			&cli.BoolFlag{
				Name:  "skip-payment-setup",
				Usage: "Skip payment setup (deposits and operator approvals) - use with caution",
			},
		},
		Action: executeCreate,
	}
}

func executeCreate(c *cli.Context) error {
	// Override global config with command line flags if provided
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
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

	var pieceInfos []types.PieceInfo
	paymentToken := c.String("payment-token")

	// Check if input file is provided
	if inputFile := c.String("input-file"); inputFile != "" {
		// For JSON file, we need custom parsing since CID is string in JSON
		data, err := os.ReadFile(inputFile)
		if err != nil {
			return fmt.Errorf("failed to read input file: %v", err)
		}

		// Parse JSON with CID as string first
		var tempPieceInfos []struct {
			PieceCid             string `json:"pieceCid"`
			Size                 uint64 `json:"size"`
			Provider             uint64 `json:"provider"`
			TermMin              int64  `json:"termMin"`
			TermMax              int64  `json:"termMax"`
			ExpirationOffset     int64  `json:"expirationOffset"`
			DownloadURL          string `json:"downloadURL"`
			PaymentTokenAddress  string `json:"paymentTokenAddress"`
		}

		if err := json.Unmarshal(data, &tempPieceInfos); err != nil {
			return fmt.Errorf("failed to parse input file: %v", err)
		}

		// Convert to PieceInfo with bytes
		pieceInfos = make([]types.PieceInfo, len(tempPieceInfos))
		for i, temp := range tempPieceInfos {
			cidBytes, err := cidStringToBytes(temp.PieceCid)
			if err != nil {
				return fmt.Errorf("invalid CID for piece %d: %v", i+1, err)
			}

			// Use token from file or command line flag
			tokenAddr := temp.PaymentTokenAddress
			if tokenAddr == "" {
				tokenAddr = paymentToken
			}
			if tokenAddr == "" {
				return fmt.Errorf("payment token address required for piece %d", i+1)
			}

			pieceInfos[i] = types.PieceInfo{
				PieceCid:             cidBytes,
				Size:                 temp.Size,
				Provider:             temp.Provider,
				TermMin:              temp.TermMin,
				TermMax:              temp.TermMax,
				ExpirationOffset:     temp.ExpirationOffset,
				DownloadURL:          temp.DownloadURL,
				PaymentTokenAddress:  common.HexToAddress(tokenAddr),
			}
		}
	} else {
		// Create single piece info from command line flags
		pieceCidStr := c.String("piece-cid")
		if pieceCidStr == "" {
			return fmt.Errorf("either --input-file or individual piece flags must be provided")
		}

		if paymentToken == "" {
			return fmt.Errorf("payment token address required (use --payment-token flag)")
		}

		cidBytes, err := cidStringToBytes(pieceCidStr)
		if err != nil {
			return fmt.Errorf("invalid piece CID: %v", err)
		}

		pieceInfo := types.PieceInfo{
			PieceCid:             cidBytes,
			Size:                 c.Uint64("size"),
			Provider:             c.Uint64("provider"),
			TermMin:              c.Int64("term-min"),
			TermMax:              c.Int64("term-max"),
			ExpirationOffset:     c.Int64("expiration-offset"),
			DownloadURL:          c.String("download-url"),
			PaymentTokenAddress:  common.HexToAddress(paymentToken),
		}

		pieceInfos = []types.PieceInfo{pieceInfo}
	}

	// Validate piece infos
	if len(pieceInfos) == 0 {
		return fmt.Errorf("no piece infos provided")
	}

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Display allocation information
	fmt.Printf("🏗️  Allocation Creation Summary:\n")
	fmt.Printf("   Client Address: %s\n", userAddress.Hex())
	fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("   Payments Contract: %s\n", config.PaymentsContractAddress)
	fmt.Printf("   RPC: %s\n", config.RPCEndpoint)
	fmt.Printf("   Number of Pieces: %d\n", len(pieceInfos))
	fmt.Println()

	// Display piece information
	totalDataCap := uint64(0)
	for i, piece := range pieceInfos {
		fmt.Printf("📦 Piece %d:\n", i+1)
		fmt.Printf("   Provider: %d\n", piece.Provider)
		fmt.Printf("   Size: %d bytes\n", piece.Size)
		fmt.Printf("   Payment Token: %s\n", piece.PaymentTokenAddress.Hex())
		if piece.DownloadURL != "" {
			fmt.Printf("   Download URL: %s\n", piece.DownloadURL)
		}
		totalDataCap += piece.Size
		fmt.Println()
	}

	fmt.Printf("📊 Total DataCap Required: %d bytes\n", totalDataCap)
	fmt.Println()

	if c.Bool("dry-run") {
		fmt.Printf("✅ Dry run completed - no transactions sent\n")
		return nil
	}

	// Create eth client for monitoring
	ethClient, err := ethclient.Dial(config.RPCEndpoint)
	if err != nil {
		return fmt.Errorf("failed to create eth client: %v", err)
	}
	defer ethClient.Close()

	// Create DDO contract client
	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	// Calculate storage costs
	fmt.Printf("💰 Calculating storage costs...\n")
	costResult, err := utils.CalculateStorageCosts(ddoClient, pieceInfos)
	if err != nil {
		return fmt.Errorf("failed to calculate storage costs: %v", err)
	}

	fmt.Printf("📊 Cost Analysis:\n")
	fmt.Printf("   Total Storage Cost: %s\n", costResult.TotalCost.String())
	fmt.Printf("   Price: %s\n", utils.FormatPriceBothFormats(costResult.PricePerBytePerEpoch))
	fmt.Printf("   Total Bytes: %d\n", costResult.TotalBytes)
	fmt.Printf("   Total Epochs: %d\n", costResult.TotalEpochs)
	fmt.Println()

	// If dry run, just show costs and requirements
	if c.Bool("dry-run") {
		// Calculate total DataCap needed
		totalDataCap := utils.CalculateTotalDataCap(pieceInfos)
		
		// Calculate one month allowance for operator approval
		oneMonthCost := new(big.Int).Mul(
			new(big.Int).SetUint64(costResult.TotalBytes),
			costResult.PricePerBytePerEpoch,
		)
		oneMonthCost.Mul(oneMonthCost, big.NewInt(utils.EPOCHS_PER_MONTH))
		
		fmt.Printf("🎯 Dry Run Results:\n\n")
		
		fmt.Printf("📊 DataCap Requirements:\n")
		fmt.Printf("   Total DataCap Needed: %s (%s)\n", totalDataCap.String(), utils.FormatBytes(totalDataCap))
		fmt.Printf("   Number of Pieces: %d\n", len(pieceInfos))
		fmt.Println()
		
		fmt.Printf("💰 Payment Requirements:\n")
		fmt.Printf("   Token: %s\n", pieceInfos[0].PaymentTokenAddress.Hex())
		fmt.Printf("   Total Storage Cost: %s\n", costResult.TotalCost.String())
		fmt.Printf("   Price: %s\n", utils.FormatPriceBothFormats(costResult.PricePerBytePerEpoch))
		fmt.Printf("   Required Operator Allowance: %s\n", oneMonthCost.String())
		fmt.Printf("   Total Term Length: %d epochs\n", costResult.TotalEpochs)
		fmt.Println()
		
		fmt.Printf("👤 Account Information:\n")
		fmt.Printf("   User Address: %s\n", userAddress.Hex())
		fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
		fmt.Printf("   Payments Contract: %s\n", config.PaymentsContractAddress)
		fmt.Println()
		
		fmt.Printf("📝 Next Steps:\n")
		fmt.Printf("1. Ensure you have enough tokens in your wallet\n")
		fmt.Printf("2. Approve the payments contract to spend your tokens (if ERC20)\n")
		fmt.Printf("3. Run without --dry-run to execute\n")
		return nil
	}

	// Create payments client
	paymentsClient, err := payments.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create payments contract client: %v", err)
	}

	// Setup payments if not skipped
	if !c.Bool("skip-payment-setup") {
		fmt.Printf("🔧 Setting up payments...\n")
		
		contractAddress := common.HexToAddress(config.ContractAddress)
		err := utils.CheckAndSetupPayments(
			ethClient,
			ddoClient,
			paymentsClient,
			pieceInfos,
			userAddress,
			contractAddress,
		)
		if err != nil {
			return fmt.Errorf("failed to setup payments: %v", err)
		}
		
		fmt.Printf("✅ Payment setup completed!\n\n")
	} else {
		fmt.Printf("⚠️  Skipping payment setup - ensure payments are configured manually\n")
	}

	// Send allocation creation transaction
	fmt.Printf("📝 Creating allocation requests...\n")
	txHash, err := ddoClient.CreateAllocationRequests(pieceInfos)
	if err != nil {
		return fmt.Errorf("failed to create allocation requests: %v", err)
	}

	fmt.Printf("✅ Transaction successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Wait for transaction to be mined using the existing client
	fmt.Printf("⏳ Waiting for allocation creation transaction to be mined...\n")
	if err := utils.WaitForTransaction(ethClient, txHash); err != nil {
		fmt.Printf("⚠️  Warning: allocation creation transaction may not have been mined: %v\n", err)
	} else {
		fmt.Printf("✅ Allocation creation transaction mined successfully!\n")
	}
	
	// Show piece info summary
	fmt.Printf("\n📋 Summary:\n")
	for i, info := range pieceInfos {
		fmt.Printf("  Piece %d:\n", i+1)
		fmt.Printf("    Provider: %d\n", info.Provider)
		fmt.Printf("    Size: %d bytes\n", info.Size)
		fmt.Printf("    Term: %d - %d\n", info.TermMin, info.TermMax)
		fmt.Printf("    Token: %s\n", info.PaymentTokenAddress.Hex())
		if info.DownloadURL != "" {
			fmt.Printf("    URL: %s\n", info.DownloadURL)
		}
	}

	return nil
}

func cidStringToBytes(cidStr string) ([]byte, error) {
	parsedCid, err := cid.Decode(cidStr)
	if err != nil {
		return nil, fmt.Errorf("failed to parse CID: %v", err)
	}
	return parsedCid.Bytes(), nil
} 