package allocations

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
	"math/rand"
	"os"
	"strings"
	"time"

	"github.com/eastore-project/fildeal/src/buffer"
	dealutils "github.com/eastore-project/fildeal/src/deal/utils"
	eabi "github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	ethtypes "github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ipfs/go-cid"
	"github.com/oklog/ulid/v2"
	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/ddo"
	"github.com/Eastore-project/ddo-client/pkg/contract/payments"
	"github.com/Eastore-project/ddo-client/pkg/curio"
	"github.com/Eastore-project/ddo-client/pkg/curio/cidconv"
	"github.com/Eastore-project/ddo-client/pkg/types"
	"github.com/Eastore-project/ddo-client/pkg/utils"
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
				Name:    "buffer-api-key",
				Usage:   "Buffer service API key",
				EnvVars: []string{"BUFFER_API_KEY"},
			},
			&cli.StringFlag{
				Name:    "buffer-url",
				Usage:   "Buffer service base URL",
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
			// Curio MK20 flags
			&cli.StringFlag{
				Name:    "curio-api",
				Usage:   "Curio MK20 API base URL (e.g., http://127.0.0.1:12310)",
				EnvVars: []string{"CURIO_API"},
			},
			&cli.BoolFlag{
				Name:    "curio-upload",
				Usage:   "Enable MK20 deal submission to Curio after on-chain allocation",
				EnvVars: []string{"CURIO_UPLOAD"},
			},
			&cli.BoolFlag{
				Name:  "skip-contract-verify",
				Usage: "Skip contract verification by using 0xtest address (for devnet testing)",
			},
			&cli.StringFlag{
				Name:  "provider-fil-addr",
				Usage: "Filecoin address of the provider (e.g., t03123279). If not provided, derives f0<provider_id>",
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
	curioAPI := c.String("curio-api")
	curioUpload := c.Bool("curio-upload")

	// Auto-discover Curio API URL from on-chain miner info if not provided
	if curioUpload && curioAPI == "" && c.IsSet("provider") {
		fmt.Printf("No --curio-api provided, discovering SP URL from chain...\n")
		discovered, err := curio.DiscoverSPURL(config.RPCEndpoint, c.Uint64("provider"))
		if err != nil {
			fmt.Printf("Warning: could not auto-discover SP URL: %v\n", err)
			fmt.Printf("Use --curio-api to provide manually\n")
		} else {
			curioAPI = discovered
			fmt.Printf("Discovered Curio API: %s\n", discovered)
		}
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

	// Determine if we need to keep CAR files for Curio upload
	curioEnabled := curioUpload && curioAPI != ""

	// Handle temporary directory
	useTempDir := outDir == ""
	var err error

	if useTempDir {
		outDir, err = os.MkdirTemp("", "ddo-client-*")
		if err != nil {
			return fmt.Errorf("failed to create temporary directory: %w", err)
		}
		// Only clean up temp dir after Curio upload is done (deferred at end)
		if !curioEnabled {
			defer os.RemoveAll(outDir)
		}
		fmt.Printf("Using temporary directory: %s\n", outDir)
	} else {
		if err := os.MkdirAll(outDir, 0755); err != nil {
			return fmt.Errorf("failed to create output directory: %w", err)
		}
	}

	fmt.Printf("Preparing data from: %s\n", inputPath)

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

	fmt.Printf("Data prepared successfully!\n")
	fmt.Printf("   Piece CID: %s\n", prepResult.PieceCid)
	fmt.Printf("   Piece Size: %d bytes\n", prepResult.PieceSize)
	fmt.Printf("   Payload CID: %s\n", prepResult.PayloadCid)
	fmt.Printf("   CAR Size: %d bytes\n", prepResult.CarSize)
	fmt.Printf("   CAR Path: %s\n", prepResult.LocalPath)
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
		PieceCid:            cidObj.Bytes(),
		Size:                prepResult.PieceSize,
		Provider:            c.Uint64("provider"),
		TermMin:             c.Int64("term-min"),
		TermMax:             c.Int64("term-max"),
		ExpirationOffset:    c.Int64("expiration-offset"),
		DownloadURL:         downloadURL,
		PaymentTokenAddress: common.HexToAddress(paymentToken),
	}

	// Get user address from private key
	privateKey, err := crypto.HexToECDSA(strings.TrimPrefix(config.PrivateKey, "0x"))
	if err != nil {
		return fmt.Errorf("failed to parse private key: %v", err)
	}
	userAddress := crypto.PubkeyToAddress(privateKey.PublicKey)

	// Display allocation information
	fmt.Printf("\nAllocation Creation Summary:\n")
	fmt.Printf("   Client Address: %s\n", userAddress.Hex())
	fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("   Payments Contract: %s\n", config.PaymentsContractAddress)
	fmt.Printf("   RPC: %s\n", config.RPCEndpoint)
	if curioEnabled {
		fmt.Printf("   Curio API: %s\n", curioAPI)
	}
	fmt.Println()

	// Display piece information
	fmt.Printf("Prepared Piece:\n")
	fmt.Printf("   Provider: %d\n", pieceInfo.Provider)
	fmt.Printf("   Size: %d bytes\n", pieceInfo.Size)
	fmt.Printf("   Payment Token: %s\n", pieceInfo.PaymentTokenAddress.Hex())
	if pieceInfo.DownloadURL != "" {
		fmt.Printf("   Download URL: %s\n", pieceInfo.DownloadURL)
	}
	fmt.Println()

	if c.Bool("dry-run") {
		fmt.Printf("Dry run completed - no transactions sent\n")
		return nil
	}

	// Create eth client for monitoring
	ethClient, err := ethclient.Dial(config.RPCEndpoint)
	if err != nil {
		return fmt.Errorf("failed to create eth client: %v", err)
	}
	defer ethClient.Close()

	// Create DDO contract client
	ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	pieceInfos := []types.PieceInfo{pieceInfo}

	// Calculate storage costs
	fmt.Printf("Calculating storage costs...\n")
	costResult, err := utils.CalculateStorageCosts(ddoClient, pieceInfos)
	if err != nil {
		return fmt.Errorf("failed to calculate storage costs: %v", err)
	}

	fmt.Printf("Cost Analysis:\n")
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

		fmt.Printf("Dry Run Results:\n\n")

		fmt.Printf("DataCap Requirements:\n")
		fmt.Printf("   Total DataCap Needed: %s (%s)\n", totalDataCap.String(), utils.FormatBytes(totalDataCap))
		fmt.Printf("   Number of Pieces: %d\n", len(pieceInfos))
		fmt.Println()

		fmt.Printf("Payment Requirements:\n")
		fmt.Printf("   Token: %s\n", pieceInfo.PaymentTokenAddress.Hex())
		fmt.Printf("   Total Storage Cost: %s\n", costResult.TotalCost.String())
		fmt.Printf("   Price: %s\n", utils.FormatPriceBothFormats(costResult.PricePerBytePerEpoch))
		fmt.Printf("   Required Operator Allowance: %s\n", oneMonthCost.String())
		fmt.Printf("   Total Term Length: %d epochs\n", costResult.TotalEpochs)
		fmt.Println()

		fmt.Printf("Account Information:\n")
		fmt.Printf("   User Address: %s\n", userAddress.Hex())
		fmt.Printf("   DDO Contract: %s\n", config.ContractAddress)
		fmt.Printf("   Payments Contract: %s\n", config.PaymentsContractAddress)
		fmt.Println()

		fmt.Printf("Next Steps:\n")
		fmt.Printf("1. Ensure you have enough tokens in your wallet\n")
		fmt.Printf("2. Approve the payments contract to spend your tokens (if ERC20)\n")
		fmt.Printf("3. Run without --dry-run to execute\n")
		return nil
	}

	// Create payments client
	paymentsClient, err := payments.NewClientWithParams(config.RPCEndpoint, config.PaymentsContractAddress, config.PrivateKey)
	if err != nil {
		return fmt.Errorf("failed to create payments contract client: %v", err)
	}

	// Setup payments if not skipped
	if !c.Bool("skip-payment-setup") {
		fmt.Printf("Setting up payments...\n")

		contractAddress := common.HexToAddress(config.ContractAddress)
		err := utils.CheckAndSetupPayments(
			ethClient,
			ddoClient,
			paymentsClient,
			pieceInfos,
			userAddress,
			contractAddress,
			config.RPCEndpoint,
			config.PrivateKey,
		)
		if err != nil {
			return fmt.Errorf("failed to setup payments: %v", err)
		}

		fmt.Printf("Payment setup completed!\n\n")
	} else {
		fmt.Printf("Skipping payment setup - ensure payments are configured manually\n")
	}

	// Execute the transaction
	fmt.Printf("Creating allocation request...\n")
	fmt.Printf("DDO Contract: %s\n", config.ContractAddress)
	fmt.Printf("Payments Contract: %s\n", config.PaymentsContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)

	txHash, err := ddoClient.CreateAllocationRequests(pieceInfos)
	if err != nil {
		return fmt.Errorf("failed to create allocation requests: %v", err)
	}

	fmt.Printf("Transaction successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)

	// Wait for transaction to be mined and get receipt
	fmt.Printf("Waiting for allocation creation transaction to be mined...\n")
	receipt, err := utils.WaitForTransactionWithReceipt(ethClient, txHash)
	if err != nil {
		fmt.Printf("Warning: could not get transaction receipt: %v\n", err)
	} else {
		fmt.Printf("Allocation creation transaction mined successfully!\n")
	}

	// Submit deal to Curio MK20 if enabled
	if curioEnabled && receipt != nil {
		fmt.Printf("\nSubmitting deal to Curio MK20...\n")
		if err := submitToCurio(c, privateKey, userAddress, cidObj, prepResult.CarSize, prepResult.LocalPath, receipt, curioAPI); err != nil {
			return fmt.Errorf("failed to submit deal to Curio: %v", err)
		}
	} else if curioEnabled && receipt == nil {
		fmt.Printf("Warning: skipping Curio submission - no transaction receipt available\n")
	}

	// Clean up temp dir after Curio upload if needed
	if useTempDir && curioEnabled {
		os.RemoveAll(outDir)
	}

	return nil
}

// submitToCurio handles the Curio MK20 deal submission and CAR file upload.
func submitToCurio(
	c *cli.Context,
	privateKey *ecdsa.PrivateKey,
	userAddress common.Address,
	pieceCidV1 cid.Cid,
	carSize uint64,
	carFilePath string,
	receipt *ethtypes.Receipt,
	curioAPI string,
) error {
	ctx := context.Background()

	// Parse AllocationCreated events from receipt
	allocationIDs, err := ddo.ParseAllocationCreatedEvents(receipt)
	if err != nil {
		return fmt.Errorf("failed to parse allocation events: %w", err)
	}
	fmt.Printf("   Found %d allocation(s): %v\n", len(allocationIDs), allocationIDs)

	// Convert piece CID V1 -> V2
	pieceCidV2, err := cidconv.PieceCidV2FromV1(pieceCidV1, carSize)
	if err != nil {
		return fmt.Errorf("failed to convert piece CID to V2: %w", err)
	}
	fmt.Printf("   Piece CID V2: %s\n", pieceCidV2.String())

	// Derive Filecoin addresses
	userFilAddr, err := curio.EthToFilecoinDelegated(userAddress)
	if err != nil {
		return fmt.Errorf("failed to derive user Filecoin address: %w", err)
	}
	fmt.Printf("   User Filecoin Address: %s\n", userFilAddr.String())

	ddoContractAddr := common.HexToAddress(config.ContractAddress)
	ddoFilAddr, err := curio.EthToFilecoinDelegated(ddoContractAddr)
	if err != nil {
		return fmt.Errorf("failed to derive DDO contract Filecoin address: %w", err)
	}
	fmt.Printf("   DDO Contract Filecoin Address: %s\n", ddoFilAddr.String())

	// Determine provider Filecoin address
	providerFilAddr := c.String("provider-fil-addr")
	if providerFilAddr == "" {
		providerID := c.Uint64("provider")
		addr, err := curio.ProviderIDToFilecoinAddr(providerID)
		if err != nil {
			return fmt.Errorf("failed to derive provider Filecoin address: %w", err)
		}
		providerFilAddr = addr.String()
	}
	fmt.Printf("   Provider Filecoin Address: %s\n", providerFilAddr)

	// Determine contract address for verification
	contractVerifyAddr := config.ContractAddress
	if c.Bool("skip-contract-verify") {
		contractVerifyAddr = "0xtest"
	}

	// Create Curio client
	curioClient := curio.NewClient(curioAPI, privateKey)

	fmt.Printf("   CAR file: %s\n", carFilePath)

	// ABI-encode the verify method params type for reuse
	uint64Ty, _ := eabi.NewType("uint64", "", nil)
	verifyArgs := eabi.Arguments{{Type: uint64Ty}}

	// Submit a deal for each allocation
	for _, allocID := range allocationIDs {
		fmt.Printf("\n   Submitting deal for allocation %d...\n", allocID)

		// Generate ULID
		entropy := rand.New(rand.NewSource(time.Now().UnixNano()))
		dealID := ulid.MustNew(ulid.Timestamp(time.Now()), entropy)

		// Build notification payload (CBOR-encoded allocation ID)
		notifPayload := curio.CborEncodeUint64(allocID)

		// ABI-encode allocation ID as (uint64) for contract verification
		verifyParams, err := verifyArgs.Pack(allocID)
		if err != nil {
			return fmt.Errorf("failed to ABI-encode verify params for allocation %d: %w", allocID, err)
		}

		// Build deal — client is the DDO Diamond contract (on-chain allocation owner)
		deal := &curio.Deal{
			Identifier: dealID,
			Client:     ddoFilAddr.String(),
			Data: &curio.DataSource{
				PieceCID: pieceCidV2,
				Format: curio.PieceDataFormat{
					Car: &curio.FormatCar{},
				},
				SourceHttpPut: &curio.DataSourcePut{},
			},
			Products: curio.Products{
				DDOV1: &curio.DDOV1{
					Provider:                   providerFilAddr,
					PieceManager:               userFilAddr.String(),
					Duration:                   518400,
					AllocationId:               &allocID,
					ContractAddress:            contractVerifyAddr,
					ContractVerifyMethod:       "getDealId",
					ContractVerifyMethodParams: verifyParams,
					NotificationAddress:        ddoFilAddr.String(),
					NotificationPayload:        notifPayload,
				},
				RetrievalV1: &curio.RetrievalV1{
					Indexing: true,
				},
			},
		}

		// POST /store
		fmt.Printf("   Storing deal %s...\n", dealID.String())
		if err := curioClient.Store(ctx, deal); err != nil {
			return fmt.Errorf("failed to store deal %s: %w", dealID.String(), err)
		}
		fmt.Printf("   Deal stored successfully!\n")

		// Upload CAR file
		fmt.Printf("   Uploading CAR file...\n")
		carFile, err := os.Open(carFilePath)
		if err != nil {
			return fmt.Errorf("failed to open CAR file: %w", err)
		}

		if err := curioClient.UploadSerial(ctx, dealID, carFile); err != nil {
			carFile.Close()
			return fmt.Errorf("failed to upload CAR file: %w", err)
		}
		carFile.Close()
		fmt.Printf("   CAR file uploaded successfully!\n")

		// Finalize upload
		fmt.Printf("   Finalizing upload...\n")
		if err := curioClient.UploadSerialFinalize(ctx, dealID); err != nil {
			return fmt.Errorf("failed to finalize upload: %w", err)
		}
		fmt.Printf("   Upload finalized! Deal ID: %s\n", dealID.String())
	}

	fmt.Printf("\nCurio MK20 deal submission completed!\n")
	return nil
}
