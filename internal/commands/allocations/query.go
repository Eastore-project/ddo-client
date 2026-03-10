package allocations

import (
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/ddo"
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
	client, err := ddo.NewReadOnlyClientWithParams(config.RPCEndpoint, config.ContractAddress)
	if err != nil {
		return fmt.Errorf("failed to create contract client: %v", err)
	}

	if allocationId != 0 {
		// Query specific allocation details
		fmt.Printf("Querying allocation details for ID: %d\n\n", allocationId)

		// Get allocation info (sectorNumber, activated, etc.)
		allocInfo, err := client.GetAllocationInfo(allocationId)
		if err != nil {
			return fmt.Errorf("failed to get allocation info: %v", err)
		}

		if allocInfo.Client == (common.Address{}) {
			fmt.Printf("Allocation %d not found\n", allocationId)
			return nil
		}

		fmt.Printf("Allocation Info:\n")
		fmt.Printf("   Client: %s\n", allocInfo.Client.Hex())
		fmt.Printf("   Provider: %d\n", allocInfo.Provider)
		fmt.Printf("   Activated: %v\n", allocInfo.Activated)
		fmt.Printf("   Payment Token: %s\n", allocInfo.PaymentToken.Hex())
		fmt.Printf("   Piece Size: %d bytes\n", allocInfo.PieceSize)
		fmt.Printf("   Price Per Byte Per Epoch: %s\n", allocInfo.PricePerBytePerEpoch.String())
		if allocInfo.Activated {
			fmt.Printf("   Sector Number: %d\n", allocInfo.SectorNumber)
		} else {
			fmt.Printf("   Sector Number: pending (not yet activated)\n")
		}
		fmt.Printf("   Rail ID: %s\n", allocInfo.RailId.String())
		fmt.Println()

		// Get rail info
		railId, providerId, railView, err := client.GetAllocationRailInfo(allocationId)
		if err != nil {
			return fmt.Errorf("failed to get allocation rail info: %v", err)
		}

		_ = providerId // already shown from allocInfo
		_ = railId     // already shown from allocInfo

		if railView != nil {
			fmt.Printf("Rail Information:\n")
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

		allocationIds, err := client.GetAllocationIdsForClient(clientAddress)
		if err != nil {
			return fmt.Errorf("failed to get allocation IDs: %v", err)
		}

		fmt.Printf("Total allocations: %d\n", len(allocationIds))

		if len(allocationIds) == 0 {
			fmt.Printf("No allocations found for this client.\n")
		} else if !countOnly {
			fmt.Printf("\nAllocation IDs:\n")
			for i, id := range allocationIds {
				fmt.Printf("  %d: %d\n", i+1, id)
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