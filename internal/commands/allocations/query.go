package allocations

import (
	"fmt"
	"strings"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
)

func QueryCommand() *cli.Command {
	return &cli.Command{
		Name:    "query",
		Aliases: []string{"q"},
		Usage:   "Query allocation IDs for a client address or provider ID",
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
				Name:    "client-address",
				Aliases: []string{"a"},
				Usage:   "Client address to query allocation IDs for",
			},
			&cli.Uint64Flag{
				Name:    "provider-id",
				Aliases: []string{"p"},
				Usage:   "Provider ID to query allocation IDs for",
			},
			&cli.Uint64Flag{
				Name:    "allocation-id",
				Aliases: []string{"id"},
				Usage:   "Specific allocation ID to get details for",
			},
			&cli.BoolFlag{
				Name:  "count-only",
				Usage: "Only show the count of allocations, not the full list",
			},
		},
		Action: executeQuery,
	}
}

func executeQuery(c *cli.Context) error {
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
		missing = append(missing, "RPC_URL")
	}

	if len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}

	clientAddress := c.String("client-address")
	providerId := c.Uint64("provider-id")
	allocationId := c.Uint64("allocation-id")
	countOnly := c.Bool("count-only")

	// Validate input: need either client address, provider ID, or allocation ID
	if clientAddress == "" && providerId == 0 && allocationId == 0 {
		return fmt.Errorf("must specify either --client-address, --provider-id, or --allocation-id")
	}

	if (clientAddress != "" && providerId != 0) || 
	   (clientAddress != "" && allocationId != 0) || 
	   (providerId != 0 && allocationId != 0) {
		return fmt.Errorf("can only specify one of --client-address, --provider-id, or --allocation-id")
	}

	fmt.Printf("Contract: %s\n", config.ContractAddress)
	fmt.Printf("RPC: %s\n", config.RPCEndpoint)
	fmt.Println()

	// Create contract client (read-only, no private key needed)
	client, err := ddo.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create contract client: %v", err)
	}

	if allocationId != 0 {
		// Query specific allocation details
		fmt.Printf("🔍 Querying allocation details for ID: %d\n", allocationId)
		
		// Get allocation rail info (includes provider ID, rail ID, and rail details)
		railId, providerId, railView, err := client.GetAllocationRailInfo(allocationId)
		if err != nil {
			return fmt.Errorf("failed to get allocation rail info: %v", err)
		}
		
		if providerId == 0 {
			fmt.Printf("❌ Allocation %d not found\n", allocationId)
			return nil
		}

		fmt.Printf("📊 Allocation Details:\n")
		fmt.Printf("   Allocation ID: %d\n", allocationId)
		fmt.Printf("   Provider ID: %d\n", providerId)
		fmt.Printf("   Rail ID: %d\n", railId)
		fmt.Println()

		if railView != nil {
			fmt.Printf("🚄 Rail Information:\n")
			fmt.Printf("   Token: %s\n", railView.Token.Hex())
			fmt.Printf("   From (Payer): %s\n", railView.From.Hex())
			fmt.Printf("   To (Payee): %s\n", railView.To.Hex())
			fmt.Printf("   Operator: %s\n", railView.Operator.Hex())
			fmt.Printf("   Validator: %s\n", railView.Validator.Hex())
			fmt.Printf("   Payment Rate: %s per epoch\n", railView.PaymentRate.String())
			fmt.Printf("   Lockup Period: %s epochs\n", railView.LockupPeriod.String())
			fmt.Printf("   Lockup Fixed: %s\n", railView.LockupFixed.String())
			fmt.Printf("   Settled Up To: epoch %s\n", railView.SettledUpTo.String())
			fmt.Printf("   End Epoch: %s\n", railView.EndEpoch.String())
			fmt.Printf("   Commission Rate BPS: %s\n", railView.CommissionRateBps.String())
			fmt.Printf("   Service Fee Recipient: %s\n", railView.ServiceFeeRecipient.Hex())
		}
		
	} else if clientAddress != "" {
		// Query allocations for client
		fmt.Printf("🔍 Querying allocations for client: %s\n", clientAddress)

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
	} else if providerId != 0 {
		// Query allocations for provider
		fmt.Printf("🔍 Querying allocations for provider: %d\n", providerId)

		allocationIds, err := client.GetAllocationIdsForProvider(providerId)
		if err != nil {
			return fmt.Errorf("failed to get allocation IDs for provider: %v", err)
		}

		fmt.Printf("📊 Results:\n")
		fmt.Printf("Total allocations: %d\n", len(allocationIds))

		if len(allocationIds) == 0 {
			fmt.Printf("No allocations found for this provider.\n")
		} else {
			if countOnly {
				fmt.Printf("Count: %d\n", len(allocationIds))
			} else {
				fmt.Printf("\nAllocation IDs:\n")
				for i, id := range allocationIds {
					fmt.Printf("  %d: %d\n", i+1, id)
				}
			}
		}
	}

	return nil
} 