package contract

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
	parsedABI, err := abi.JSON(strings.NewReader(DDOClientABI))
	if err != nil {
		panic(fmt.Sprintf("failed to parse ABI: %v", err))
	}
	return parsedABI
}

// NewClient creates a new contract client using global config
func NewClient() (*Client, error) {
	return NewClientWithParams(config.RPCEndpoint, config.ContractAddress, config.PrivateKey)
}

// NewClientWithParams creates a new contract client with specific parameters
func NewClientWithParams(rpcEndpoint, contractAddress, privateKey string) (*Client, error) {
	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RPC endpoint: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(DDOClientABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ABI: %w", err)
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

	// Gas limit and gas price will be auto-estimated by the client

	return &Client{
		ethClient:    client,
		contract:     contract,
		contractAddr: addr,
		auth:         auth,
		abi:          parsedABI,
		privateKey:   privateKeyECDSA,
	}, nil
}

// NewReadOnlyClient creates a new contract client for read-only operations (no private key required)
func NewReadOnlyClient() (*Client, error) {
	if config.ContractAddress == "" {
		return nil, fmt.Errorf("contract address not set")
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
	contractAddress := common.HexToAddress(config.ContractAddress)

	// Create bound contract (read-only)
	contractABI := getContractABI()
	boundContract := bind.NewBoundContract(contractAddress, contractABI, client, nil, nil)

	return &Client{
		ethClient:    client,
		contract:     boundContract,
		contractAddr: contractAddress,
		auth:         nil, // No auth for read-only operations
		abi:          contractABI,
		privateKey:   nil, // No private key for read-only operations
	}, nil
} 