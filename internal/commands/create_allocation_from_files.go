package commands

import (
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/eastore-project/fildeal/src/buffer"
	dealutils "github.com/eastore-project/fildeal/src/deal/utils"
	"github.com/ipfs/go-cid"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract"
	"ddo-client/internal/types"
)

func CreateAllocationFromFilesCommand() *cli.Command {
    return &cli.Command{
        Name:    "create-from-files",
        Aliases: []string{"cff"},
        Usage:   "Create allocation requests from files/folders using data preparation",
        Flags: []cli.Flag{
            &cli.StringFlag{
                Name:    "contract",
                Aliases: []string{"c"},
                Usage:   "Contract address (overrides DDO_CONTRACT_ADDRESS env var)",
            },
            &cli.StringFlag{
                Name:    "rpc",
                Aliases: []string{"r"},
                Usage:   "RPC endpoint (overrides RPC_ENDPOINT env var)",
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
            },
            &cli.StringFlag{
                Name:  "buffer-url",
                Usage: "Buffer service base URL",
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
            &cli.BoolFlag{
                Name:  "dry-run",
                Usage: "Prepare data and calculate DataCap without sending transaction",
            },
        },
        Action: executeCreateAllocationFromFiles,
    }
}

func executeCreateAllocationFromFiles(c *cli.Context) error {
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

    inputPath := c.String("input")
    outDir := c.String("outdir")

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
        PieceCid:         cidObj.Bytes(),
        Size:             prepResult.PieceSize,
        Provider:         c.Uint64("provider"),
        TermMin:          c.Int64("term-min"),
        TermMax:          c.Int64("term-max"),
        ExpirationOffset: c.Int64("expiration-offset"),
        DownloadURL:      downloadURL,
    }

    pieceInfos := []types.PieceInfo{pieceInfo}

    fmt.Println()
    fmt.Printf("📋 Allocation Request Details:\n")
    fmt.Printf("   Provider: %d\n", pieceInfo.Provider)
    fmt.Printf("   Size: %d bytes\n", pieceInfo.Size)
    fmt.Printf("   Term: %d - %d\n", pieceInfo.TermMin, pieceInfo.TermMax)
    if pieceInfo.DownloadURL != "" {
        fmt.Printf("   Download URL: %s\n", pieceInfo.DownloadURL)
    }
    fmt.Println()

    // Create contract client
    client, err := contract.NewClient()
    if err != nil {
        return fmt.Errorf("failed to create contract client: %v", err)
    }

    // If dry run, just calculate total DataCap
    if c.Bool("dry-run") {
        totalDataCap, err := client.CalculateTotalDataCap(pieceInfos)
        if err != nil {
            return fmt.Errorf("failed to calculate total DataCap: %v", err)
        }
        
        fmt.Printf("📊 Dry Run Results:\n")
        fmt.Printf("Total DataCap required: %s bytes\n", totalDataCap.String())
        
        // Convert to more readable units
        if totalDataCap.Cmp(big.NewInt(1024*1024*1024)) >= 0 {
            gb := new(big.Int).Div(totalDataCap, big.NewInt(1024*1024*1024))
            fmt.Printf("                      : %s GB\n", gb.String())
        }
        
        fmt.Printf("\nTo execute for real, remove the --dry-run flag\n")
        return nil
    }

    // Execute the transaction
    fmt.Printf("🚀 Sending transaction...\n")
    fmt.Printf("Contract: %s\n", config.ContractAddress)
    fmt.Printf("RPC: %s\n", config.RPCEndpoint)

    txHash, err := client.CreateAllocationRequests(pieceInfos)
    if err != nil {
        return fmt.Errorf("failed to create allocation requests: %v", err)
    }

    fmt.Printf("✅ Transaction successful!\n")
    fmt.Printf("Transaction Hash: %s\n", txHash)
    
    return nil
} 