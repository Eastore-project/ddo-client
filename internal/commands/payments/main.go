package payments

import (
	"github.com/urfave/cli/v2"
)

func PaymentsCommand() *cli.Command {
	return &cli.Command{
		Name:    "payments",
		Aliases: []string{"pay"},
		Usage:   "Manage and query payments contract operations",
		Subcommands: []*cli.Command{
			// Query commands
			QueryContractInfoCommand(),
			QueryAccountCommand(),
			QueryOperatorApprovalCommand(),
			QueryRailCommand(),
			QueryAccumulatedFeesCommand(),
			QueryAllAccountsCommand(),
			// Transaction commands
			SetOperatorAllowanceCommand(),
			WithdrawCommand(),
		},
	}
} 


var paymentsFlags = []cli.Flag{
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
		Usage:   "Private key (overrides PRIVATE_KEY env var) - required for transaction commands",
	},
}
