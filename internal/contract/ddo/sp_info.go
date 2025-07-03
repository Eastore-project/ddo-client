package ddo

import (
	"ddo-client/internal/types"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

// CalculateStorageCost calculates the storage cost for a specific piece
func (c *Client) CalculateStorageCost(providerId uint64, token common.Address, pieceSize uint64, termLength int64) (*big.Int, error) {
	var result []interface{}
	
	err := c.contract.Call(nil, &result, "calculateStorageCost", providerId, token, pieceSize, termLength)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate storage cost: %w", err)
	}

	if len(result) == 0 {
		return big.NewInt(0), nil
	}

	if cost, ok := result[0].(*big.Int); ok {
		return cost, nil
	}

	return big.NewInt(0), fmt.Errorf("unexpected result type: %T", result[0])
}

// GetAndValidateSPPrice gets and validates the storage provider's price per byte per epoch
func (c *Client) GetAndValidateSPPrice(providerId uint64, token common.Address) (*big.Int, error) {
	var result []interface{}
	
	err := c.contract.Call(nil, &result, "getAndValidateSPPrice", providerId, token)
	if err != nil {
		return nil, fmt.Errorf("failed to get SP price: %w", err)
	}

	if len(result) == 0 {
		return big.NewInt(0), nil
	}

	if price, ok := result[0].(*big.Int); ok {
		return price, nil
	}

	return big.NewInt(0), fmt.Errorf("unexpected result type: %T", result[0])
} 


// GetSPSupportedTokensFromContract calls the contract's getSPSupportedTokens function directly
func (c *Client) GetSPSupportedTokensFromContract(actorId uint64) ([]types.TokenConfig, error) {
	// Call the contract using interface parsing
	var supportedTokensRaw []interface{}
	err := c.contract.Call(nil, &supportedTokensRaw, "getSPSupportedTokens", actorId)
	if err != nil {
		return nil, fmt.Errorf("failed to call getSPSupportedTokens: %w", err)
	}

	// Parse supported tokens - the result is an array containing one element which is the TokenConfig array
	var supportedTokens []types.TokenConfig
	if len(supportedTokensRaw) > 0 {
		// The first element should be the array of TokenConfig structs
		if tokenArray, ok := supportedTokensRaw[0].([]struct {
			Token               common.Address `json:"token"`
			PricePerBytePerEpoch *big.Int       `json:"pricePerBytePerEpoch"`
			IsActive            bool           `json:"isActive"`
		}); ok {
			supportedTokens = make([]types.TokenConfig, len(tokenArray))
			for i, token := range tokenArray {
				supportedTokens[i] = types.TokenConfig{
					Token:               token.Token,
					PricePerBytePerEpoch: token.PricePerBytePerEpoch,
					IsActive:            token.IsActive,
				}
			}
		} else {
			fmt.Printf("DEBUG: Could not parse token array, type: %T\n", supportedTokensRaw[0])
		}
	}

	return supportedTokens, nil
}

// GetSPConfig retrieves the storage provider configuration using the public spConfigs mapping
func (c *Client) GetSPConfig(actorId uint64) (*types.SPConfig, error) {
	// Call the contract and see what we get
	var result []interface{}
	
	err := c.contract.Call(nil, &result, "spConfigs", actorId)
	if err != nil {
		return nil, fmt.Errorf("failed to call spConfigs: %w", err)
	}

	// Based on debug output, we expect 6 fields:
	// [0] paymentAddress, [1] minPieceSize, [2] maxPieceSize, [3] minTermLength, [4] maxTermLength, [5] isActive
	if len(result) < 6 {
		return nil, fmt.Errorf("unexpected result length: expected at least 6, got %d", len(result))
	}

	// Extract payment address
	paymentAddress, ok := result[0].(common.Address)
	if !ok {
		return nil, fmt.Errorf("invalid payment address type: %T", result[0])
	}

	// If payment address is zero, SP is not registered
	if paymentAddress == (common.Address{}) {
		return nil, nil
	}

	// Extract other fields
	minPieceSize, ok := result[1].(uint64)
	if !ok {
		return nil, fmt.Errorf("invalid min piece size type: %T", result[1])
	}

	maxPieceSize, ok := result[2].(uint64)
	if !ok {
		return nil, fmt.Errorf("invalid max piece size type: %T", result[2])
	}

	minTermLength, ok := result[3].(int64)
	if !ok {
		return nil, fmt.Errorf("invalid min term length type: %T", result[3])
	}

	maxTermLength, ok := result[4].(int64)
	if !ok {
		return nil, fmt.Errorf("invalid max term length type: %T", result[4])
	}

	isActive, ok := result[5].(bool)
	if !ok {
		return nil, fmt.Errorf("invalid is active type: %T", result[5])
	}

	// Get supported tokens using the dedicated function
	supportedTokens, err := c.GetSPSupportedTokensFromContract(actorId)
	if err != nil {
		fmt.Printf("DEBUG: Failed to get supported tokens: %v\n", err)
		supportedTokens = []types.TokenConfig{}
	}

	config := &types.SPConfig{
		PaymentAddress:  paymentAddress,
		MinPieceSize:    minPieceSize,
		MaxPieceSize:    maxPieceSize,
		MinTermLength:   minTermLength,
		MaxTermLength:   maxTermLength,
		SupportedTokens: supportedTokens,
		IsActive:        isActive,
	}

	return config, nil
}

// GetSPSupportedTokens retrieves all supported tokens for a storage provider
// This function gets the tokens from the spConfigs mapping since supportedTokens is part of the SP config
func (c *Client) GetSPSupportedTokens(actorId uint64) ([]types.TokenConfig, error) {
	return c.GetSPSupportedTokensFromContract(actorId)
}

// IsSPRegistered checks if a storage provider is registered
func (c *Client) IsSPRegistered(actorId uint64) (bool, error) {
	config, err := c.GetSPConfig(actorId)
	if err != nil {
		return false, err
	}
	return config != nil, nil
}

// GetSPPaymentAddress gets the payment address for a storage provider
func (c *Client) GetSPPaymentAddress(actorId uint64) (common.Address, error) {
	config, err := c.GetSPConfig(actorId)
	if err != nil {
		return common.Address{}, err
	}
	if config == nil {
		return common.Address{}, fmt.Errorf("SP %d not registered", actorId)
	}
	return config.PaymentAddress, nil
} 