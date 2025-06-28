package payments

import (
	"fmt"

	"github.com/urfave/cli/v2"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/payments"
)

// createPaymentsClient creates a read-only payments client with command-line flag overrides
func createPaymentsClient(c *cli.Context) (*payments.Client, error) {
	// Override global config with command line flags if provided
	if paymentsContract := c.String("payments-contract"); paymentsContract != "" {
		config.PaymentsContractAddress = paymentsContract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}

	// Validate required configuration
	if config.PaymentsContractAddress == "" {
		return nil, fmt.Errorf("payments contract address required (use --payments-contract flag or PAYMENTS_CONTRACT_ADDRESS env var)")
	}
	if config.RPCEndpoint == "" {
		return nil, fmt.Errorf("RPC endpoint required (use --rpc flag or RPC_URL env var)")
	}

	// Create read-only payments client
	client, err := payments.NewReadOnlyClient()
	if err != nil {
		return nil, fmt.Errorf("failed to create payments client: %v", err)
	}

	return client, nil
}

// validatePrivateKeyConfig validates and sets private key configuration for transaction commands
func validatePrivateKeyConfig(c *cli.Context) error {
	// Override global config with command line flags if provided
	if paymentsContract := c.String("payments-contract"); paymentsContract != "" {
		config.PaymentsContractAddress = paymentsContract
	}
	if rpc := c.String("rpc"); rpc != "" {
		config.RPCEndpoint = rpc
	}
	if pk := c.String("private-key"); pk != "" {
		config.PrivateKey = pk
	}

	// Validate required configuration
	if config.PrivateKey == "" {
		return fmt.Errorf("private key required (use --private-key flag or PRIVATE_KEY env var)")
	}
	if config.PaymentsContractAddress == "" {
		return fmt.Errorf("payments contract address required (use --payments-contract flag or PAYMENTS_CONTRACT_ADDRESS env var)")
	}

	return nil
} 