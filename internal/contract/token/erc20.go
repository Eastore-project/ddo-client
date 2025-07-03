package token

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

	"ddo-client/internal/config"
)

// ERC20Client handles interactions with ERC20 tokens
type ERC20Client struct {
	ethClient   *ethclient.Client
	contract    *bind.BoundContract
	tokenAddr   common.Address
	auth        *bind.TransactOpts
	abi         abi.ABI
	privateKey  *ecdsa.PrivateKey
}

// Standard ERC20 ABI (minimal interface for allowance and approve)
const ERC20ABI = `[
	{
		"inputs": [
			{"name": "owner", "type": "address"},
			{"name": "spender", "type": "address"}
		],
		"name": "allowance",
		"outputs": [{"name": "", "type": "uint256"}],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"inputs": [
			{"name": "spender", "type": "address"},
			{"name": "amount", "type": "uint256"}
		],
		"name": "approve",
		"outputs": [{"name": "", "type": "bool"}],
		"stateMutability": "nonpayable",
		"type": "function"
	},
	{
		"inputs": [
			{"name": "account", "type": "address"}
		],
		"name": "balanceOf",
		"outputs": [{"name": "", "type": "uint256"}],
		"stateMutability": "view",
		"type": "function"
	},
	{
		"anonymous": false,
		"inputs": [
			{"indexed": true, "name": "owner", "type": "address"},
			{"indexed": true, "name": "spender", "type": "address"},
			{"indexed": false, "name": "value", "type": "uint256"}
		],
		"name": "Approval",
		"type": "event"
	}
]`

// NewERC20Client creates a new ERC20 client for the specified token
func NewERC20Client(tokenAddress string) (*ERC20Client, error) {
	return NewERC20ClientWithParams(config.RPCEndpoint, tokenAddress, config.PrivateKey)
}

// NewERC20ClientWithParams creates a new ERC20 client with specific parameters
func NewERC20ClientWithParams(rpcEndpoint, tokenAddress, privateKey string) (*ERC20Client, error) {
	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RPC endpoint: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(ERC20ABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ERC20 ABI: %w", err)
	}

	tokenAddr := common.HexToAddress(tokenAddress)
	contract := bind.NewBoundContract(tokenAddr, parsedABI, client, client, client)

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

	return &ERC20Client{
		ethClient:  client,
		contract:   contract,
		tokenAddr:  tokenAddr,
		auth:       auth,
		abi:        parsedABI,
		privateKey: privateKeyECDSA,
	}, nil
}

// NewERC20ReadOnlyClient creates a new ERC20 client for read-only operations
func NewERC20ReadOnlyClient(rpcEndpoint, tokenAddress string) (*ERC20Client, error) {
	client, err := ethclient.Dial(rpcEndpoint)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to RPC endpoint: %w", err)
	}

	parsedABI, err := abi.JSON(strings.NewReader(ERC20ABI))
	if err != nil {
		return nil, fmt.Errorf("failed to parse ERC20 ABI: %w", err)
	}

	tokenAddr := common.HexToAddress(tokenAddress)
	contract := bind.NewBoundContract(tokenAddr, parsedABI, client, nil, nil)

	return &ERC20Client{
		ethClient: client,
		contract:  contract,
		tokenAddr: tokenAddr,
		auth:      nil,
		abi:       parsedABI,
		privateKey: nil,
	}, nil
}

// GetAllowance returns the current allowance for a spender
func (e *ERC20Client) GetAllowance(owner, spender common.Address) (*big.Int, error) {
	var result []interface{}
	err := e.contract.Call(&bind.CallOpts{}, &result, "allowance", owner, spender)
	if err != nil {
		return nil, fmt.Errorf("failed to call allowance: %w", err)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no result returned from allowance call")
	}

	allowance, ok := result[0].(*big.Int)
	if !ok {
		return nil, fmt.Errorf("failed to parse allowance result: %T", result[0])
	}

	return allowance, nil
}

// GetBalance returns the token balance for an account
func (e *ERC20Client) GetBalance(account common.Address) (*big.Int, error) {
	var result []interface{}
	err := e.contract.Call(&bind.CallOpts{}, &result, "balanceOf", account)
	if err != nil {
		return nil, fmt.Errorf("failed to call balanceOf: %w", err)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no result returned from balanceOf call")
	}

	balance, ok := result[0].(*big.Int)
	if !ok {
		return nil, fmt.Errorf("failed to parse balance result: %T", result[0])
	}

	return balance, nil
}

// Approve sets the allowance for a spender
func (e *ERC20Client) Approve(spender common.Address, amount *big.Int) (string, error) {
	if e.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (no private key)")
	}

	tx, err := e.contract.Transact(e.auth, "approve", spender, amount)
	if err != nil {
		return "", fmt.Errorf("failed to send approve transaction: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// CheckAndApprove checks the current allowance and approves more if needed
func (e *ERC20Client) CheckAndApprove(owner, spender common.Address, requiredAmount *big.Int) (string, bool, error) {
	// Get current allowance
	currentAllowance, err := e.GetAllowance(owner, spender)
	if err != nil {
		return "", false, fmt.Errorf("failed to get current allowance: %w", err)
	}

	// Check if current allowance is sufficient
	if currentAllowance.Cmp(requiredAmount) >= 0 {
		return "", false, nil // No approval needed
	}

	// Calculate amount to approve (add some buffer for gas fees and future usage)
	// Approve 2x the required amount or type(uint256).max for unlimited approval
	approveAmount := new(big.Int).Mul(requiredAmount, big.NewInt(2))
	
	// For very large amounts, just use max uint256 for unlimited approval
	maxUint256 := new(big.Int)
	maxUint256.SetString("115792089237316195423570985008687907853269984665640564039457584007913129639935", 10)
	
	if approveAmount.Cmp(maxUint256.Div(maxUint256, big.NewInt(2))) > 0 {
		approveAmount = maxUint256
	}
	
	// Send approval transaction
	txHash, err := e.Approve(spender, approveAmount)
	if err != nil {
		return "", false, fmt.Errorf("failed to approve tokens: %w", err)
	}

	return txHash, true, nil
}

// GetTokenAddress returns the token contract address
func (e *ERC20Client) GetTokenAddress() common.Address {
	return e.tokenAddr
}

// GetEthClient returns the underlying Ethereum client
func (e *ERC20Client) GetEthClient() *ethclient.Client {
	return e.ethClient
}

// Close closes the Ethereum client connection
func (e *ERC20Client) Close() {
	if e.ethClient != nil {
		e.ethClient.Close()
	}
} 