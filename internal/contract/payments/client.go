package payments

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"

	"ddo-client/internal/config"
)

type Client struct {
	ethClient    *ethclient.Client
	contract     *bind.BoundContract
	contractAddr common.Address
	auth         *bind.TransactOpts
	abi          abi.ABI
	privateKey   *ecdsa.PrivateKey
}

// getContractABI returns the parsed ABI
func getContractABI() abi.ABI {
	parsedABI, err := abi.JSON(strings.NewReader(PaymentsABI))
	if err != nil {
		panic(fmt.Sprintf("failed to parse Payments ABI: %v", err))
	}
	return parsedABI
}

// NewClient creates a new payments contract client using global config
func NewClient() (*Client, error) {
	if config.PaymentsContractAddress == "" {
		return nil, fmt.Errorf("payments contract address not configured")
	}
	return NewClientWithParams(config.RPCEndpoint, config.PaymentsContractAddress, config.PrivateKey)
}

// NewClientWithAddress creates a new payments contract client with specific address
func NewClientWithAddress(contractAddress string) (*Client, error) {
	return NewClientWithParams(config.RPCEndpoint, contractAddress, config.PrivateKey)
}

// NewClientWithParams creates a new payments contract client with specific parameters
func NewClientWithParams(rpcEndpoint, contractAddress, privateKey string) (*Client, error) {
	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RPC endpoint: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(PaymentsABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse Payments ABI: %w", err)
	}

	addr := common.HexToAddress(contractAddress)
	contract := bind.NewBoundContract(addr, parsedABI, client, client, client)

	privateKeyECDSA, err := crypto.HexToECDSA(strings.TrimPrefix(privateKey, "0x"))
	if err != nil {
		return nil, fmt.Errorf("failed to parse private key: %w", err)
	}

	chainID, err := client.ChainID(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get chain ID: %w", err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKeyECDSA, chainID)
	if err != nil {
		return nil, fmt.Errorf("failed to create transactor: %w", err)
	}

	return &Client{
		ethClient:    client,
		contract:     contract,
		contractAddr: addr,
		auth:         auth,
		abi:          parsedABI,
		privateKey:   privateKeyECDSA,
	}, nil
}

// NewReadOnlyClient creates a new payments contract client for read-only operations using global config
func NewReadOnlyClient() (*Client, error) {
	if config.PaymentsContractAddress == "" {
		return nil, fmt.Errorf("payments contract address not configured")
	}
	return NewReadOnlyClientWithAddress(config.PaymentsContractAddress)
}

// NewReadOnlyClientWithAddress creates a new payments contract client for read-only operations with specific address
func NewReadOnlyClientWithAddress(contractAddress string) (*Client, error) {
	if contractAddress == "" {
		return nil, fmt.Errorf("payments contract address not provided")
	}
	if config.RPCEndpoint == "" {
		return nil, fmt.Errorf("RPC endpoint not set")
	}

	// Connect to Ethereum client
	client, err := ethclient.Dial(config.RPCEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum client: %w", err)
	}

	// Parse contract address
	contractAddr := common.HexToAddress(contractAddress)

	// Create bound contract (read-only)
	contractABI := getContractABI()
	boundContract := bind.NewBoundContract(contractAddr, contractABI, client, nil, nil)

	return &Client{
		ethClient:    client,
		contract:     boundContract,
		contractAddr: contractAddr,
		auth:         nil, // No auth for read-only operations
		abi:          contractABI,
		privateKey:   nil, // No private key for read-only operations
	}, nil
}

// GetContractAddress returns the contract address
func (c *Client) GetContractAddress() common.Address {
	return c.contractAddr
}

// GetEthClient returns the underlying Ethereum client
func (c *Client) GetEthClient() *ethclient.Client {
	return c.ethClient
}

// Close closes the Ethereum client connection
func (c *Client) Close() {
	if c.ethClient != nil {
		c.ethClient.Close()
	}
} 