package ddo

import (
	"context"
	"crypto/ecdsa"
	"fmt"
	"math/big"
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

	return &Client{
		ethClient:    client,
		contract:     contract,
		contractAddr: addr,
		auth:         auth,
		abi:          parsedABI,
		privateKey:   privateKeyECDSA,
	}, nil
}

// NewReadOnlyClientWithParams creates a new read-only contract client with specific parameters
func NewReadOnlyClientWithParams(rpcEndpoint, contractAddress string) (*Client, error) {
	if contractAddress == "" {
		return nil, fmt.Errorf("contract address not set")
	}
	if rpcEndpoint == "" {
		return nil, fmt.Errorf("RPC endpoint not set")
	}

	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum client: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(DDOClientABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ABI: %w", err)
	}

	addr := common.HexToAddress(contractAddress)
	boundContract := bind.NewBoundContract(addr, parsedABI, client, nil, nil)

	return &Client{
		ethClient:    client,
		contract:     boundContract,
		contractAddr: addr,
		abi:          parsedABI,
	}, nil
}

// GetPaymentsContract returns the payments contract address from the DDO contract
func (c *Client) GetPaymentsContract() (common.Address, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "paymentsContract")
	if err != nil {
		return common.Address{}, fmt.Errorf("failed to get payments contract address: %w", err)
	}
	
	if len(result) == 0 {
		return common.Address{}, fmt.Errorf("no result returned from paymentsContract call")
	}
	
	paymentsAddress, ok := result[0].(common.Address)
	if !ok {
		return common.Address{}, fmt.Errorf("failed to parse payments contract address: %T", result[0])
	}
	
	return paymentsAddress, nil
}

// Close closes the Ethereum client connection
func (c *Client) Close() {
	if c.ethClient != nil {
		c.ethClient.Close()
	}
}

// GetEthClient returns the underlying Ethereum client
func (c *Client) GetEthClient() *ethclient.Client {
	return c.ethClient
}

// GetAllSPIds returns all registered SP actor IDs from the ViewFacet
func (c *Client) GetAllSPIds() ([]uint64, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "getAllSPIds")
	if err != nil {
		return nil, fmt.Errorf("failed to get all SP IDs: %w", err)
	}

	if len(result) == 0 {
		return nil, nil
	}

	ids, ok := result[0].([]uint64)
	if !ok {
		return nil, fmt.Errorf("unexpected result type for getAllSPIds: %T", result[0])
	}

	return ids, nil
}

// DeactivateSP deactivates a storage provider (owner-only)
func (c *Client) DeactivateSP(actorId uint64) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "deactivateSP", actorId)
	if err != nil {
		return "", fmt.Errorf("failed to deactivate SP: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// RemoveSPToken removes a token from a storage provider's supported tokens (owner-only)
func (c *Client) RemoveSPToken(actorId uint64, token common.Address) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "removeSPToken", actorId, token)
	if err != nil {
		return "", fmt.Errorf("failed to remove SP token: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SetPaymentsContract sets the payments contract address (owner-only)
func (c *Client) SetPaymentsContract(addr common.Address) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "setPaymentsContract", addr)
	if err != nil {
		return "", fmt.Errorf("failed to set payments contract: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SetCommissionRate sets the commission rate in basis points (owner-only)
func (c *Client) SetCommissionRate(bps *big.Int) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "setCommissionRate", bps)
	if err != nil {
		return "", fmt.Errorf("failed to set commission rate: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SetAllocationLockupAmount sets the allocation lockup amount (owner-only)
func (c *Client) SetAllocationLockupAmount(amount *big.Int) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "setAllocationLockupAmount", amount)
	if err != nil {
		return "", fmt.Errorf("failed to set allocation lockup amount: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// Pause pauses the contract (owner-only)
func (c *Client) Pause() (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "pause")
	if err != nil {
		return "", fmt.Errorf("failed to pause contract: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// Unpause unpauses the contract (owner-only)
func (c *Client) Unpause() (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "unpause")
	if err != nil {
		return "", fmt.Errorf("failed to unpause contract: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// Paused returns whether the contract is paused
func (c *Client) Paused() (bool, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "paused")
	if err != nil {
		return false, fmt.Errorf("failed to get paused status: %w", err)
	}

	if len(result) == 0 {
		return false, fmt.Errorf("no result returned from paused call")
	}

	paused, ok := result[0].(bool)
	if !ok {
		return false, fmt.Errorf("unexpected result type for paused: %T", result[0])
	}

	return paused, nil
}

// BlacklistSector blacklists or unblacklists a sector for a provider (owner-only)
func (c *Client) BlacklistSector(providerId uint64, sectorNumber uint64, blacklisted bool) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "blacklistSector", providerId, sectorNumber, blacklisted)
	if err != nil {
		return "", fmt.Errorf("failed to blacklist sector: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// IsSectorBlacklisted returns whether a sector is blacklisted for a provider
func (c *Client) IsSectorBlacklisted(providerId uint64, sectorNumber uint64) (bool, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "isSectorBlacklisted", providerId, sectorNumber)
	if err != nil {
		return false, fmt.Errorf("failed to check sector blacklist: %w", err)
	}

	if len(result) == 0 {
		return false, fmt.Errorf("no result returned from isSectorBlacklisted call")
	}

	blacklisted, ok := result[0].(bool)
	if !ok {
		return false, fmt.Errorf("unexpected result type for isSectorBlacklisted: %T", result[0])
	}

	return blacklisted, nil
}

// GetAllocationLockupAmount returns the allocation lockup amount from the contract
func (c *Client) GetAllocationLockupAmount() (*big.Int, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "allocationLockupAmount")
	if err != nil {
		return nil, fmt.Errorf("failed to get allocation lockup amount: %w", err)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no result returned from allocationLockupAmount call")
	}

	amount, ok := result[0].(*big.Int)
	if !ok {
		return nil, fmt.Errorf("unexpected result type for allocationLockupAmount: %T", result[0])
	}

	return amount, nil
}