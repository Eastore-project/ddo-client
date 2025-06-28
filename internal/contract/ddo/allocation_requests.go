package ddo

import (
	"context"
	"fmt"
	"math/big"

	"ddo-client/internal/types"
)

// CreateAllocationRequests creates allocation requests on the contract
func (c *Client) CreateAllocationRequests(pieceInfos []types.PieceInfo) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "createAllocationRequests", pieceInfos)
	if err != nil {
		return "", fmt.Errorf("failed to send transaction: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// CreateSingleAllocationRequest creates a single allocation request
func (c *Client) CreateSingleAllocationRequest(pieceInfo types.PieceInfo) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "createSingleAllocationRequest",
		pieceInfo.PieceCid,
		pieceInfo.Size,
		pieceInfo.Provider,
		pieceInfo.TermMin,
		pieceInfo.TermMax,
		pieceInfo.ExpirationOffset,
		pieceInfo.DownloadURL,
		pieceInfo.PaymentTokenAddress,
	)
	if err != nil {
		return "", fmt.Errorf("failed to send transaction: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// CalculateTotalDataCap calculates the total DataCap needed without sending transaction
func (c *Client) CalculateTotalDataCap(pieceInfos []types.PieceInfo) (*big.Int, error) {
	var result []interface{}
	
	err := c.contract.Call(nil, &result, "calculateTotalDataCap", pieceInfos)
	if err != nil {
		return nil, fmt.Errorf("failed to call contract: %w", err)
	}

	if len(result) == 0 {
		return big.NewInt(0), nil
	}

	// Convert result to big.Int
	if totalDataCap, ok := result[0].(*big.Int); ok {
		return totalDataCap, nil
	}

	return big.NewInt(0), fmt.Errorf("unexpected result type")
} 