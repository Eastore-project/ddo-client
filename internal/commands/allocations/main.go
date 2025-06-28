package allocations

import (
	"github.com/urfave/cli/v2"
)

func AllocationsCommand() *cli.Command {
	return &cli.Command{
		Name:    "allocations",
		Aliases: []string{"alloc"},
		Usage:   "Allocation management commands",
		Subcommands: []*cli.Command{
			QueryCommand(),
			CreateCommand(),
			CreateFromFileCommand(),
			QueryClaimInfoCommand(),
		},
	}
} 