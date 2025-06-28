package allocations

import (
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/eastore-project/fildeal/src/buffer"
	dealutils "github.com/eastore-project/fildeal/src/deal/utils"
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

func CreateFromFileCommand() *cli.Command {
	return &cli.Command{
		Name:    "create-from-file",
		Aliases: []string{"cff"},
		Usage:   "Create allocation requests from files/folders using data preparation with payment setup",
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
			// File input
			&cli.StringFlag{
				Name:     "input",
				Aliases:  []string{"i"},
				Usage:    "Input file or folder path",
				Required: true,
			},
			&cli.StringFlag{
				Name:  "outdir",
				Usage: "Output directory for CAR files (if not provided, uses temp dir and cleans up after)",
			},
			// Buffer configuration
			&cli.StringFlag{
				Name:  "buffer-type",
				Usage: "Buffer type (lighthouse or local)",
				Value: "local",
			},
			&cli.StringFlag{
				Name:  "buffer-api-key",
				Usage: "Buffer service API key",
				EnvVars: []string{"BUFFER_API_KEY"},
			},
			&cli.StringFlag{
				Name:  "buffer-url",
				Usage: "Buffer service base URL",
				EnvVars: []string{"BUFFER_URL"},
			},
			// Deal parameters
			&cli.Uint64Flag{
				Name:     "provider",
				Usage:    "Provider/Miner ID",
				Required: true,
			},
			&cli.Int64Flag{
				Name:  "term-min",
				Usage: "Minimum term",
				Value: 518400, // Default from eastore
			},
			&cli.Int64Flag{
				Name:  "term-max",
				Usage: "Maximum term",
				Value: 5256000, // 10x default
			},
			&cli.Int64Flag{
				Name:  "expiration-offset",
				Usage: "Expiration offset from current block",
				Value: 172800,
			},
			&cli.StringFlag{
				Name:  "download-url",
				Usage: "Download URL for the piece (optional, will use buffer URL if not provided)",
			},
			&cli.StringFlag{
				Name:     "payment-token",
				Usage:    "Payment token address (required)",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Prepare data and calculate costs without sending transaction",
			},
			&cli.BoolFlag{
				Name:  "skip-payment-setup",
				Usage: "Skip payment setup (deposits and operator approvals) - use with caution",
				Value: false,
			},
		},
		Action: executeCreateFromFile,
	}
}

func executeCreateFromFile(c *cli.Context) error {
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

	inputPath := c.String("input")
	outDir := c.String("outdir")
	paymentToken := c.String("payment-token")

	// Handle temporary directory
	useTempDir := outDir == ""
	var err error

	if useTempDir {
		outDir, err = os.MkdirTemp("", "ddo-client-*")
		if err != nil {
			return fmt.Errorf("failed to create temporary directory: %w", err)
		}
		defer os.RemoveAll(outDir)
		fmt.Printf("Using temporary directory: %s\n", outDir)
	} else {
		if err := os.MkdirAll(outDir, 0755); err != nil {
			return fmt.Errorf("failed to create output directory: %w", err)
		}
	}

	fmt.Printf("📁 Preparing data from: %s\n", inputPath)

	// Create data prep config
	bufferConfig := &buffer.Config{
		Type:    c.String("buffer-type"),
		ApiKey:  c.String("buffer-api-key"),
		BaseURL: c.String("buffer-url"),
	}

	// Prepare data using fildeal's PrepareData utility
	prepResult, err := dealutils.PrepareData(inputPath, outDir, bufferConfig)
	if err != nil {
		return fmt.Errorf("failed to prepare data: %w", err)
	}

	fmt.Printf("✅ Data prepared successfully!\n")
	fmt.Printf("   Piece CID: %s\n", prepResult.PieceCid)
	fmt.Printf("   Piece Size: %d bytes\n", prepResult.PieceSize)
	fmt.Printf("   Payload CID: %s\n", prepResult.PayloadCid)
	fmt.Printf("   CAR Size: %d bytes\n", prepResult.CarSize)
	if prepResult.BufferInfo.URL != "" {
		fmt.Printf("   Buffer URL: %s\n", prepResult.BufferInfo.URL)
	}

	// Convert CID string to bytes
	cidObj, err := cid.Decode(prepResult.PieceCid)
	if err != nil {
		return fmt.Errorf("failed to decode piece CID: %w", err)
	}

	// Determine download URL
	downloadURL := c.String("download-url")
	if downloadURL == "" && prepResult.BufferInfo.URL != "" {
		downloadURL = prepResult.BufferInfo.URL
	}

	// Create PieceInfo from prepared data
	pieceInfo := types.PieceInfo{
		PieceCid:             cidObj.Bytes(),
		Size:                 prepResult.PieceSize,
		Provider:             c.Uint64("provider"),
		TermMin:              c.Int64("term-min"),
		TermMax:              c.Int64("term-max"),
		ExpirationOffset:     c.Int64("expiration-offset"),
		DownloadURL:          downloadURL,
		PaymentTokenAddress:  common.HexToAddress(paymentToken),
	}

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Display allocation information
	fmt.Printf("\n🏗️  Allocation Creation Summary:\n")
	fmt.Printf("   Client Address: %s\n", userAddress.Hex())
	fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("   Payments Contract: %s\n", config.PaymentsContractAddress)
	fmt.Printf("   RPC: %s\n", config.RPCEndpoint)
	fmt.Println()

	// Display piece information
	fmt.Printf("📦 Prepared Piece:\n")
	fmt.Printf("   Provider: %d\n", pieceInfo.Provider)
	fmt.Printf("   Size: %d bytes\n", pieceInfo.Size)
	fmt.Printf("   Payment Token: %s\n", pieceInfo.PaymentTokenAddress.Hex())
	if pieceInfo.DownloadURL != "" {
		fmt.Printf("   Download URL: %s\n", pieceInfo.DownloadURL)
	}
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

	pieceInfos := []types.PieceInfo{pieceInfo}

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
	fmt.Printf("   User Address: %s\n", userAddress.Hex())
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
		fmt.Printf("   Token: %s\n", pieceInfo.PaymentTokenAddress.Hex())
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
		paymentResult, err := utils.CheckAndSetupPayments(
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

		// Wait for transactions to be mined
		if paymentResult.TokenAllowanceTx != "" {
			fmt.Printf("⏳ Waiting for token allowance transaction...\n")
			if err := utils.WaitForTransaction(ethClient, paymentResult.TokenAllowanceTx); err != nil {
				fmt.Printf("⚠️  Warning: token allowance transaction may not have been mined: %v\n", err)
			}
		}

		if paymentResult.DepositTxHash != "" {
			fmt.Printf("⏳ Waiting for deposit transaction...\n")
			if err := utils.WaitForTransaction(ethClient, paymentResult.DepositTxHash); err != nil {
				fmt.Printf("⚠️  Warning: deposit transaction may not have been mined: %v\n", err)
			}
		}

		if paymentResult.OperatorApprovalTx != "" {
			fmt.Printf("⏳ Waiting for operator approval transaction...\n")
			if err := utils.WaitForTransaction(ethClient, paymentResult.OperatorApprovalTx); err != nil {
				fmt.Printf("⚠️  Warning: operator approval transaction may not have been mined: %v\n", err)
			}
		}

		fmt.Printf("✅ Payment setup completed!\n\n")
	} else {
		fmt.Printf("⚠️  Skipping payment setup - ensure payments are configured manually\n")
	}

	// Execute the transaction
	fmt.Printf("🚀 Creating allocation request...\n")
	fmt.Printf("DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("Payments Contract: %s\n", config.PaymentsContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)

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

	return nil
} 