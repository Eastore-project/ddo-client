package commands

import (
	"encoding/json"
	"fmt"
	"math/big"
	"os"
	"strings"

	"github.com/ipfs/go-cid"
	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract"
	"ddo-client/internal/types"
)

func CreateAllocationRequestsCommand() *cli.Command {
	return &cli.Command{
		Name:    "create-allocations",
		Aliases: []string{"ca"},
		Usage:   "Create allocation requests on the DDO contract",
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
			&cli.BoolFlag{
				Name:  "dry-run",
				Usage: "Calculate total DataCap without sending transaction",
			},
		},
		Action: executeCreateAllocationRequests,
	}
}

func executeCreateAllocationRequests(c *cli.Context) error {
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

	var pieceInfos []types.PieceInfo

	// Check if input file is provided
	if inputFile := c.String("input-file"); inputFile != "" {
		// For JSON file, we need custom parsing since CID is string in JSON
		data, err := os.ReadFile(inputFile)
		if err != nil {
			return fmt.Errorf("failed to read input file: %v", err)
		}

		// Parse JSON with CID as string first
		var tempPieceInfos []struct {
			PieceCid         string `json:"pieceCid"`
			Size             uint64 `json:"size"`
			Provider         uint64 `json:"provider"`
			TermMin          int64  `json:"termMin"`
			TermMax          int64  `json:"termMax"`
			ExpirationOffset int64  `json:"expirationOffset"`
			DownloadURL      string `json:"downloadURL"`
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

			pieceInfos[i] = types.PieceInfo{
				PieceCid:         cidBytes,
				Size:             temp.Size,
				Provider:         temp.Provider,
				TermMin:          temp.TermMin,
				TermMax:          temp.TermMax,
				ExpirationOffset: temp.ExpirationOffset,
				DownloadURL:      temp.DownloadURL,
			}
		}
	} else {
		// Create single piece info from command line flags
		pieceCidStr := c.String("piece-cid")
		if pieceCidStr == "" {
			return fmt.Errorf("either --input-file or individual piece flags must be provided")
		}

		cidBytes, err := cidStringToBytes(pieceCidStr)
		if err != nil {
			return fmt.Errorf("invalid piece CID: %v", err)
		}

		pieceInfo := types.PieceInfo{
			PieceCid:         cidBytes,
			Size:             c.Uint64("size"),
			Provider:         c.Uint64("provider"),
			TermMin:          c.Int64("term-min"),
			TermMax:          c.Int64("term-max"),
			ExpirationOffset: c.Int64("expiration-offset"),
			DownloadURL:      c.String("download-url"),
		}

		// Basic validation
		if pieceInfo.Size == 0 {
			return fmt.Errorf("size must be greater than 0")
		}
		if pieceInfo.Provider == 0 {
			return fmt.Errorf("provider must be greater than 0")
		}

		pieceInfos = []types.PieceInfo{pieceInfo}
	}

	fmt.Printf("Processing %d piece(s)...\n", len(pieceInfos))
	fmt.Printf("Contract: %s\n", config.ContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)
	fmt.Println()

	// Create contract client using global config
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
	txHash, err := client.CreateAllocationRequests(pieceInfos)
	if err != nil {
		return fmt.Errorf("failed to create allocation requests: %v", err)
	}

	fmt.Printf("✅ Transaction successful!\n")
	fmt.Printf("Transaction Hash: %s\n", txHash)
	
	// Show piece info summary
	fmt.Printf("\n📋 Summary:\n")
	for i, info := range pieceInfos {
		fmt.Printf("  Piece %d:\n", i+1)
		fmt.Printf("    Provider: %d\n", info.Provider)
		fmt.Printf("    Size: %d bytes\n", info.Size)
		fmt.Printf("    Term: %d - %d\n", info.TermMin, info.TermMax)
		if info.DownloadURL != "" {
			fmt.Printf("    URL: %s\n", info.DownloadURL)
		}
	}
	
	return nil
}

func cidStringToBytes(cidStr string) ([]byte, error) {
	c, err := cid.Decode(cidStr)
	if err != nil {
		return nil, fmt.Errorf("invalid CID: %v", err)
	}
	return c.Bytes(), nil
} 