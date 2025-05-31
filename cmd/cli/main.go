package main

import (
	"fmt"
	"os"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/commands"
	"ddo-client/internal/config"
)

func main() {
	// Load configuration from environment variables
	config.LoadFromEnv()

	app := &cli.App{
		Name:  "ddo-client",
		Usage: "A CLI application for interacting with DDO smart contracts",
		Before: func(c *cli.Context) error {
			// Print configuration info
			if c.Bool("verbose") {
				fmt.Printf("RPC Endpoint: %s\n", config.RPCEndpoint)
				if config.ContractAddress != "" {
					fmt.Printf("Contract Address: %s\n", config.ContractAddress)
				}
			}
			return nil
		},
		Flags: []cli.Flag{
			&cli.BoolFlag{
				Name:    "verbose",
				Aliases: []string{"v"},
				Usage:   "Show verbose output",
			},
		},
		Commands: []*cli.Command{
			commands.CreateAllocationRequestsCommand(),
			commands.CreateAllocationFromFilesCommand(),
			commands.QueryAllocationsCommand(),
			// Future commands will be added here
		},
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
} 