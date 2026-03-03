package sp

import (
	"fmt"
	"math/big"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/utils"
)

func ListCommand() *cli.Command {
	return &cli.Command{
		Name:    "list",
		Aliases: []string{"ls"},
		Usage:   "List all registered storage providers",
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
		},
		Action: executeListSPs,
	}
}

func executeListSPs(c *cli.Context) error {
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}

	if config.ContractAddress == "" {
		return fmt.Errorf("missing DDO contract address (use --contract flag or DDO_CONTRACT_ADDRESS env var)")
	}

	ddoClient, err := ddo.NewReadOnlyClient()
	if err != nil {
		return fmt.Errorf("failed to create DDO contract client: %v", err)
	}
	defer ddoClient.Close()

	spIds, err := ddoClient.GetAllSPIds()
	if err != nil {
		return fmt.Errorf("failed to get SP IDs: %v", err)
	}

	if len(spIds) == 0 {
		fmt.Println("No storage providers registered.")
		return nil
	}

	fmt.Printf("Registered Storage Providers (%d total)\n", len(spIds))
	fmt.Printf("%-12s %-44s %-20s %-8s %-8s\n", "Actor ID", "Payment Address", "Piece Size Range", "Active", "Tokens")
	fmt.Printf("%-12s %-44s %-20s %-8s %-8s\n", "--------", "---------------", "----------------", "------", "------")

	for _, id := range spIds {
		spConfig, err := ddoClient.GetSPConfig(id)
		if err != nil {
			fmt.Printf("%-12d %-44s %-20s %-8s %-8s\n", id, "error", "error", "?", "?")
			continue
		}

		active := "no"
		if spConfig.IsActive {
			active = "yes"
		}

		sizeRange := fmt.Sprintf("%s - %s",
			utils.FormatBytes(new(big.Int).SetUint64(spConfig.MinPieceSize)),
			utils.FormatBytes(new(big.Int).SetUint64(spConfig.MaxPieceSize)))

		fmt.Printf("%-12d %-44s %-20s %-8s %-8d\n",
			id,
			spConfig.PaymentAddress.Hex(),
			sizeRange,
			active,
			len(spConfig.SupportedTokens))
	}

	return nil
}
