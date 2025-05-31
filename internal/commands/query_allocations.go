package commands

import (
	"fmt"
	"strings"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract"
)

func QueryAllocationsCommand() *cli.Command {
	return &cli.Command{
		Name:    "query-allocations",
		Aliases: []string{"qa"},
		Usage:   "Query allocation IDs for a client address",
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
				Name:     "client-address",
				Aliases:  []string{"a"},
				Usage:    "Client address to query allocation IDs for",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "count-only",
				Usage: "Only show the count of allocations, not the full list",
			},
		},
		Action: executeQueryAllocations,
	}
}

func executeQueryAllocations(c *cli.Context) error {
	// Override global config with command line flags if provided
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}

	// Validate required configuration (only contract and RPC needed for read operations)
	missing := []string{}
	if config.ContractAddress == "" {
		missing = append(missing, "DDO_CONTRACT_ADDRESS")
	}
	if config.RPCEndpoint == "" {
		missing = append(missing, "RPC_ENDPOINT")
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}

	clientAddress := c.String("client-address")
	countOnly := c.Bool("count-only")

	fmt.Printf("🔍 Querying allocations for client: %s\n", clientAddress)
	fmt.Printf("Contract: %s\n", config.ContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)
	fmt.Println()

	// Create contract client (read-only, no private key needed)
	client, err := contract.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create contract client: %v", err)
	}

	if countOnly {
		// Get only the count
		count, err := client.GetAllocationCountForClient(clientAddress)
		if err != nil {
			return fmt.Errorf("failed to get allocation count: %v", err)
		}

		fmt.Printf("📊 Results:\n")
		fmt.Printf("Total allocations: %s\n", count.String())
	} else {
		// Get all allocation IDs
		allocationIds, err := client.GetAllocationIdsForClient(clientAddress)
		if err != nil {
			return fmt.Errorf("failed to get allocation IDs: %v", err)
		}

		fmt.Printf("📊 Results:\n")
		fmt.Printf("Total allocations: %d\n", len(allocationIds))

		if len(allocationIds) == 0 {
			fmt.Printf("No allocations found for this client.\n")
		} else {
			fmt.Printf("\nAllocation IDs:\n")
			for i, id := range allocationIds {
				fmt.Printf("  %d: %d\n", i+1, id)
			}
		}
	}

	return nil
} 