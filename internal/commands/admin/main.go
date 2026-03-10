package admin

import (
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/common"
	"github.com/urfave/cli/v2"

	"github.com/Eastore-project/ddo-client/internal/config"
	"github.com/Eastore-project/ddo-client/pkg/contract/ddo"
	"github.com/Eastore-project/ddo-client/pkg/utils"
)

func AdminCommand() *cli.Command {
	return &cli.Command{
		Name:  "admin",
		Usage: "Contract admin commands (owner-only)",
		Subcommands: []*cli.Command{
			setPaymentsContractCommand(),
			setCommissionRateCommand(),
			setLockupAmountCommand(),
			pauseCommand(),
			unpauseCommand(),
			pausedCommand(),
			blacklistSectorCommand(),
			isSectorBlacklistedCommand(),
		},
	}
}

func setPaymentsContractCommand() *cli.Command {
	return &cli.Command{
		Name:  "set-payments-contract",
		Usage: "Set the payments contract address",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
			&cli.StringFlag{
				Name:     "address",
				Aliases:  []string{"a"},
				Usage:    "New payments contract address",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			addr := common.HexToAddress(c.String("address"))

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			fmt.Printf("Setting payments contract to %s...\n", addr.Hex())

			txHash, err := ddoClient.SetPaymentsContract(addr)
			if err != nil {
				return fmt.Errorf("failed to set payments contract: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			fmt.Printf("Payments contract updated successfully!\n")
			return nil
		},
	}
}

func setCommissionRateCommand() *cli.Command {
	return &cli.Command{
		Name:  "set-commission-rate",
		Usage: "Set the commission rate in basis points (max 100 = 1%)",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
				Name:     "bps",
				Usage:    "Commission rate in basis points (e.g. 50 = 0.5%)",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			bps := new(big.Int).SetUint64(c.Uint64("bps"))

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			fmt.Printf("Setting commission rate to %s bps (%.2f%%)...\n", bps.String(), float64(bps.Uint64())/100.0)

			txHash, err := ddoClient.SetCommissionRate(bps)
			if err != nil {
				return fmt.Errorf("failed to set commission rate: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			fmt.Printf("Commission rate updated successfully!\n")
			return nil
		},
	}
}

func setLockupAmountCommand() *cli.Command {
	return &cli.Command{
		Name:  "set-lockup-amount",
		Usage: "Set the allocation lockup amount (in token base units)",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
			&cli.StringFlag{
				Name:     "amount",
				Usage:    "Lockup amount in base units (e.g. 1000000000000000000 for 1 token with 18 decimals)",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			amount, ok := new(big.Int).SetString(c.String("amount"), 10)
			if !ok {
				return fmt.Errorf("invalid amount: %s", c.String("amount"))
			}

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			fmt.Printf("Setting allocation lockup amount to %s...\n", amount.String())

			txHash, err := ddoClient.SetAllocationLockupAmount(amount)
			if err != nil {
				return fmt.Errorf("failed to set lockup amount: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			fmt.Printf("Allocation lockup amount updated successfully!\n")
			return nil
		},
	}
}

func pauseCommand() *cli.Command {
	return &cli.Command{
		Name:  "pause",
		Usage: "Pause the contract (owner-only)",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			fmt.Printf("Pausing contract...\n")

			txHash, err := ddoClient.Pause()
			if err != nil {
				return fmt.Errorf("failed to pause contract: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			fmt.Printf("Contract paused successfully!\n")
			return nil
		},
	}
}

func unpauseCommand() *cli.Command {
	return &cli.Command{
		Name:  "unpause",
		Usage: "Unpause the contract (owner-only)",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			fmt.Printf("Unpausing contract...\n")

			txHash, err := ddoClient.Unpause()
			if err != nil {
				return fmt.Errorf("failed to unpause contract: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			fmt.Printf("Contract unpaused successfully!\n")
			return nil
		},
	}
}

func pausedCommand() *cli.Command {
	return &cli.Command{
		Name:  "is-paused",
		Usage: "Check if the contract is paused",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
			},
			&cli.StringFlag{
				Name:    "rpc",
				Aliases: []string{"r"},
				Usage:   "RPC endpoint (overrides RPC_URL env var)",
			},
		},
		Action: func(c *cli.Context) error {
			if contract := c.String("contract"); contract != "" {
				config.ContractAddress = contract
			}
			if rpc := c.String("rpc"); rpc != "" {
				config.RPCEndpoint = rpc
			}

			ddoClient, err := ddo.NewReadOnlyClientWithParams(config.RPCEndpoint, config.ContractAddress)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			paused, err := ddoClient.Paused()
			if err != nil {
				return fmt.Errorf("failed to get paused status: %v", err)
			}

			if paused {
				fmt.Printf("Contract is PAUSED\n")
			} else {
				fmt.Printf("Contract is ACTIVE (not paused)\n")
			}

			return nil
		},
	}
}

func blacklistSectorCommand() *cli.Command {
	return &cli.Command{
		Name:  "blacklist-sector",
		Usage: "Blacklist or unblacklist a sector for a provider (owner-only)",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
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
				Name:     "provider",
				Aliases:  []string{"p"},
				Usage:    "Provider actor ID",
				Required: true,
			},
			&cli.Uint64Flag{
				Name:     "sector",
				Aliases:  []string{"s"},
				Usage:    "Sector number",
				Required: true,
			},
			&cli.BoolFlag{
				Name:  "remove",
				Usage: "Remove from blacklist instead of adding",
			},
		},
		Action: func(c *cli.Context) error {
			applyConfigOverrides(c)
			if missing := config.GetMissingConfig(); len(missing) > 0 {
				return fmt.Errorf("missing required configuration: %s", strings.Join(missing, ", "))
			}

			providerId := c.Uint64("provider")
			sectorNumber := c.Uint64("sector")
			blacklisted := !c.Bool("remove")

			ddoClient, err := ddo.NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			action := "Blacklisting"
			if !blacklisted {
				action = "Removing blacklist for"
			}
			fmt.Printf("%s sector %d for provider %d...\n", action, sectorNumber, providerId)

			txHash, err := ddoClient.BlacklistSector(providerId, sectorNumber, blacklisted)
			if err != nil {
				return fmt.Errorf("failed to blacklist sector: %v", err)
			}

			fmt.Printf("Transaction Hash: %s\n", txHash)

			fmt.Printf("Waiting for transaction to be mined...\n")
			if err := utils.WaitForTransaction(ddoClient.GetEthClient(), txHash); err != nil {
				fmt.Printf("Warning: transaction may not have been mined: %v\n", err)
				return nil
			}

			if blacklisted {
				fmt.Printf("Sector %d for provider %d blacklisted successfully!\n", sectorNumber, providerId)
			} else {
				fmt.Printf("Sector %d for provider %d removed from blacklist successfully!\n", sectorNumber, providerId)
			}
			return nil
		},
	}
}

func isSectorBlacklistedCommand() *cli.Command {
	return &cli.Command{
		Name:  "is-sector-blacklisted",
		Usage: "Check if a sector is blacklisted for a provider",
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "contract",
				Aliases: []string{"c"},
				Usage:   "DDO contract address (overrides DDO_CONTRACT_ADDRESS env var)",
			},
			&cli.StringFlag{
				Name:    "rpc",
				Aliases: []string{"r"},
				Usage:   "RPC endpoint (overrides RPC_URL env var)",
			},
			&cli.Uint64Flag{
				Name:     "provider",
				Aliases:  []string{"p"},
				Usage:    "Provider actor ID",
				Required: true,
			},
			&cli.Uint64Flag{
				Name:     "sector",
				Aliases:  []string{"s"},
				Usage:    "Sector number",
				Required: true,
			},
		},
		Action: func(c *cli.Context) error {
			if contract := c.String("contract"); contract != "" {
				config.ContractAddress = contract
			}
			if rpc := c.String("rpc"); rpc != "" {
				config.RPCEndpoint = rpc
			}

			ddoClient, err := ddo.NewReadOnlyClientWithParams(config.RPCEndpoint, config.ContractAddress)
			if err != nil {
				return fmt.Errorf("failed to create DDO contract client: %v", err)
			}

			providerId := c.Uint64("provider")
			sectorNumber := c.Uint64("sector")

			blacklisted, err := ddoClient.IsSectorBlacklisted(providerId, sectorNumber)
			if err != nil {
				return fmt.Errorf("failed to check sector blacklist: %v", err)
			}

			if blacklisted {
				fmt.Printf("Sector %d for provider %d is BLACKLISTED\n", sectorNumber, providerId)
			} else {
				fmt.Printf("Sector %d for provider %d is NOT blacklisted\n", sectorNumber, providerId)
			}

			return nil
		},
	}
}

func applyConfigOverrides(c *cli.Context) {
	if contract := c.String("contract"); contract != "" {
		config.ContractAddress = contract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}
	if pk := c.String("private-key"); pk != "" {
		config.PrivateKey = pk
	}
}
