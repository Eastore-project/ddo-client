package sp

import (
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/ddo"
	"github.com/Eastore-project/ddo-client/pkg/utils"
)

func RemoveTokenCommand() *cli.Command {
	return &cli.Command{
		Name:  "remove-token",
		Usage: "Remove a supported token from a storage provider (owner-only)",
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
			&cli.StringFlag{
				Name:     "token",
				Aliases:  []string{"t"},
				Usage:    "Token address to remove",
				Required: true,
			},
		},
		Action: executeRemoveSPToken,
	}
}

func executeRemoveSPToken(c *cli.Context) error {
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
	tokenAddr := common.HexToAddress(c.String("token"))

	ddoClient, err := ddo.NewClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}

	fmt.Printf("Removing token %s from storage provider %d...\n", tokenAddr.Hex(), actorId)

	txHash, err := ddoClient.RemoveSPToken(actorId, tokenAddr)
	if err != nil {
		return fmt.Errorf("failed to remove SP token: %v", err)
	}

	fmt.Printf("Transaction Hash: %s\n", txHash)

	fmt.Printf("Waiting for transaction to be mined...\n")
	if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
		fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
		return nil
	}

	fmt.Printf("Token %s removed from SP %d successfully!\n", tokenAddr.Hex(), actorId)
	return nil
}
