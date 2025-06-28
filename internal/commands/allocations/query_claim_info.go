package allocations

import (
	"encoding/hex"
	"fmt"
	"strconv"
	"strings"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
)

func QueryClaimInfoCommand() *cli.Command {
	return &cli.Command{
		Name:    "query-claim-info",
		Aliases: []string{"qci"},
		Usage:   "Query claim information for a specific client address and claim ID",
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
				Name:     "client-address",
				Aliases:  []string{"a"},
				Usage:    "Client address to query claim info for",
				Required: true,
			},
			&cli.StringFlag{
				Name:     "claim-id",
				Aliases:  []string{"id"},
				Usage:    "Claim ID to query",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "json",
				Usage: "Output in JSON format",
			},
		},
		Action: executeQueryClaimInfo,
	}
}

func executeQueryClaimInfo(c *cli.Context) error {
	// Override global config with command line flags if provided
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}

	// Validate required configuration
	missing := []string{}
	if config.ContractAddress == "" {
		missing = append(missing, "DDO_CONTRACT_ADDRESS")
	}
	if config.RPCEndpoint == "" {
		missing = append(missing, "RPC_URL")
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}

	clientAddress := c.String("client-address")
	claimIdStr := c.String("claim-id")
	jsonOutput := c.Bool("json")

	// Parse claim ID
	claimId, err := strconv.ParseUint(claimIdStr, 10, 64)
	if err != nil {
		return fmt.Errorf("invalid claim ID '%s': %v", claimIdStr, err)
	}

	if !jsonOutput {
		fmt.Printf("🔍 Querying claim info for:\n")
		fmt.Printf("Client: %s\n", clientAddress)
		fmt.Printf("Claim ID: %d\n", claimId)
		fmt.Printf("Contract: %s\n", config.ContractAddress)
		fmt.Printf("RPC: %s\n", config.RPCEndpoint)
		fmt.Println()
	}

	// Create contract client (read-only, no private key needed)
	client, err := ddo.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create contract client: %v", err)
	}

	// Get claim info
	claims, err := client.GetClaimInfoForClient(clientAddress, claimId)
	if err != nil {
		return fmt.Errorf("failed to get claim info: %v", err)
	}

	if jsonOutput {
		// Output in JSON format
		for i, claim := range claims {
			fmt.Printf("{\n")
			fmt.Printf("  \"index\": %d,\n", i)
			fmt.Printf("  \"provider\": %d,\n", claim.Provider)
			fmt.Printf("  \"client\": %d,\n", claim.Client)
			fmt.Printf("  \"data\": \"%s\",\n", hex.EncodeToString(claim.Data))
			fmt.Printf("  \"size\": %d,\n", claim.Size)
			fmt.Printf("  \"termMin\": %d,\n", claim.TermMin)
			fmt.Printf("  \"termMax\": %d,\n", claim.TermMax)
			fmt.Printf("  \"termStart\": %d,\n", claim.TermStart)
			fmt.Printf("  \"sector\": %d\n", claim.Sector)
			fmt.Printf("}")
			if i < len(claims)-1 {
				fmt.Printf(",")
			}
			fmt.Printf("\n")
		}
	} else {
		// Human-readable output
		fmt.Printf("📊 Results:\n")
		fmt.Printf("Found %d claim(s)\n\n", len(claims))

		if len(claims) == 0 {
			fmt.Printf("No claims found for this client and claim ID.\n")
		} else {
			for i, claim := range claims {
				fmt.Printf("Claim #%d:\n", i+1)
				fmt.Printf("  Provider ID: %d\n", claim.Provider)
				fmt.Printf("  Client ID: %d\n", claim.Client)
				fmt.Printf("  Data (hex): %s\n", hex.EncodeToString(claim.Data))
				fmt.Printf("  Size: %d bytes\n", claim.Size)
				fmt.Printf("  Term Min: %d\n", claim.TermMin)
				fmt.Printf("  Term Max: %d\n", claim.TermMax)
				fmt.Printf("  Term Start: %d\n", claim.TermStart)
				fmt.Printf("  Sector ID: %d\n", claim.Sector)
				if i < len(claims)-1 {
					fmt.Printf("\n")
				}
			}
		}
	}

	return nil
} 