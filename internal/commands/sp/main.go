package sp

import (
	"github.com/urfave/cli/v2"
)

func SPCommand() *cli.Command {
	return &cli.Command{
		Name:    "sp",
		Aliases: []string{"storage-provider"},
		Usage:   "Storage provider management commands",
		Subcommands: []*cli.Command{
			ListCommand(),
			RegisterCommand(),
			UpdateCommand(),
			QueryCommand(),
			DeactivateCommand(),
			RemoveTokenCommand(),
			SettleCommand(),
		},
	}
} 