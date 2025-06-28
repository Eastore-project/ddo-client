package main

import (
	"fmt"
	"log"
	"os"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/commands"
	"ddo-client/internal/commands/allocations"
	"ddo-client/internal/commands/payments"
	"ddo-client/internal/commands/sp"
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
			allocations.AllocationsCommand(),
			payments.PaymentsCommand(),
			sp.SPCommand(),
			commands.ApproveTokenCommand(),
			// Future commands will be added here
		},
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
} 