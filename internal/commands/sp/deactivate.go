package sp

import (
	"fmt"
	"strings"

	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/ddo"
	"github.com/Eastore-project/ddo-client/pkg/utils"
)

func DeactivateCommand() *cli.Command {
	return &cli.Command{
		Name:  "deactivate",
		Usage: "Deactivate a storage provider (owner-only)",
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
		},
		Action: executeDeactivateSP,
	}
}

func executeDeactivateSP(c *cli.Context) error {
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}
	if pk := c.String("private-key"); pk != "" {
		config.PrivateKey = pk
	}

	if missing := config.GetMissingConfig(); len(missing) > 0 {
		return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
	}

	actorId := c.Uint64("actor-id")

	ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	fmt.Printf("Deactivating storage provider %d...\n", actorId)

	txHash, err := ddoClient.DeactivateSP(actorId)
	if err != nil {
		return fmt.Errorf("failed to deactivate SP: %v", err)
	}

	fmt.Printf("Transaction Hash: %s\n", txHash)

	fmt.Printf("Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("Storage provider %d deactivated successfully!\n", actorId)
	return nil
}
