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
)

type Client struct {
	ethClient    *ethclient.Client
	contract     *bind.BoundContract
	contractAddr common.Address
	auth         *bind.TransactOpts
	abi          abi.ABI
	privateKey   *ecdsa.PrivateKey
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

// NewReadOnlyClientWithParams creates a new read-only payments contract client with specific parameters
func NewReadOnlyClientWithParams(rpcEndpoint, contractAddress string) (*Client, error) {
	if contractAddress == "" {
		return nil, fmt.Errorf("payments contract address not provided")
	}
	if rpcEndpoint == "" {
		return nil, fmt.Errorf("RPC endpoint not set")
	}

	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum client: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(PaymentsABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse Payments ABI: %w", err)
	}

	contractAddr := common.HexToAddress(contractAddress)
	boundContract := bind.NewBoundContract(contractAddr, parsedABI, client, nil, nil)

	return &Client{
		ethClient:    client,
		contract:     boundContract,
		contractAddr: contractAddr,
		abi:          parsedABI,
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