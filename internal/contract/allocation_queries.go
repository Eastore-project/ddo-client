package contract

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

// GetAllocationIdsForClient gets all allocation IDs for a specific client address
func (c *Client) GetAllocationIdsForClient(clientAddress string) ([]uint64, error) {
	var result []interface{}
	
	// Convert string address to common.Address
	addr := common.HexToAddress(clientAddress)
	
	err := c.contract.Call(nil, &result, "getAllocationIdsForClient", addr)
	if err != nil {
		return nil, fmt.Errorf("failed to call contract: %w", err)
	}

	if len(result) == 0 {
		return []uint64{}, nil
	}

	// Check if the result is already []uint64
	if allocationIds, ok := result[0].([]uint64); ok {
		return allocationIds, nil
	}

	// If it's []interface{}, convert each element
	if resultSlice, ok := result[0].([]interface{}); ok {
		allocationIds := make([]uint64, len(resultSlice))
		for i, val := range resultSlice {
			if bigIntVal, ok := val.(*big.Int); ok {
				allocationIds[i] = bigIntVal.Uint64()
			} else {
				return nil, fmt.Errorf("unexpected type in result slice at index %d: %T", i, val)
			}
		}
		return allocationIds, nil
	}

	return []uint64{}, fmt.Errorf("unexpected result type: %T", result[0])
}

// GetAllocationCountForClient gets the number of allocations for a specific client address
func (c *Client) GetAllocationCountForClient(clientAddress string) (*big.Int, error) {
	var result []interface{}
	
	// Convert string address to common.Address
	addr := common.HexToAddress(clientAddress)
	
	err := c.contract.Call(nil, &result, "getAllocationCountForClient", addr)
	if err != nil {
		return nil, fmt.Errorf("failed to call contract: %w", err)
	}

	if len(result) == 0 {
		return big.NewInt(0), nil
	}

	// Convert result to big.Int
	if count, ok := result[0].(*big.Int); ok {
		return count, nil
	}

	// Handle case where it might be returned as uint64
	if count, ok := result[0].(uint64); ok {
		return big.NewInt(int64(count)), nil
	}

	return big.NewInt(0), fmt.Errorf("unexpected result type: %T", result[0])
} 