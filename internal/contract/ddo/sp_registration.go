package ddo

import (
	"fmt"
	"math/big"

	"ddo-client/internal/types"

	"github.com/ethereum/go-ethereum/common"
)

// RegisterSP registers a new storage provider with the DDO contract
func (c *Client) RegisterSP(params types.SPRegistrationParams) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (read-only mode)")
	}

	// Convert TokenConfig slice to the format expected by the contract
	contractTokenConfigs := make([]struct {
		Token               common.Address
		PricePerBytePerEpoch *big.Int
		IsActive            bool
	}, len(params.TokenConfigs))

	for i, tc := range params.TokenConfigs {
		contractTokenConfigs[i] = struct {
			Token               common.Address
			PricePerBytePerEpoch *big.Int
			IsActive            bool
		}{
			Token:               tc.Token,
			PricePerBytePerEpoch: tc.PricePerBytePerEpoch,
			IsActive:            tc.IsActive,
		}
	}

	tx, err := c.contract.Transact(c.auth, "registerSP",
		params.ActorId,
		params.PaymentAddress,
		params.MinPieceSize,
		params.MaxPieceSize,
		params.MinTermLength,
		params.MaxTermLength,
		contractTokenConfigs,
	)
	if err != nil {
		return "", fmt.Errorf("failed to register SP: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// UpdateSPConfig updates an existing storage provider's basic configuration
func (c *Client) UpdateSPConfig(actorId uint64, paymentAddress common.Address, minPieceSize, maxPieceSize uint64, minTermLength, maxTermLength int64) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (read-only mode)")
	}

	tx, err := c.contract.Transact(c.auth, "updateSPConfig",
		actorId,
		paymentAddress,
		minPieceSize,
		maxPieceSize,
		minTermLength,
		maxTermLength,
	)
	if err != nil {
		return "", fmt.Errorf("failed to update SP config: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// AddSPToken adds a new token configuration to an existing storage provider
func (c *Client) AddSPToken(actorId uint64, token common.Address, pricePerBytePerEpoch *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (read-only mode)")
	}

	tx, err := c.contract.Transact(c.auth, "addSPToken",
		actorId,
		token,
		pricePerBytePerEpoch,
	)
	if err != nil {
		return "", fmt.Errorf("failed to add SP token: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// UpdateSPToken updates an existing token configuration for a storage provider
func (c *Client) UpdateSPToken(actorId uint64, token common.Address, pricePerBytePerEpoch *big.Int, isActive bool) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (read-only mode)")
	}

	tx, err := c.contract.Transact(c.auth, "updateSPToken",
		actorId,
		token,
		pricePerBytePerEpoch,
		isActive,
	)
	if err != nil {
		return "", fmt.Errorf("failed to update SP token: %w", err)
	}

	return tx.Hash().Hex(), nil
}
