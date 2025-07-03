package ddo

import (
	"fmt"
	"math/big"
	"reflect"

	"ddo-client/internal/types"

	"github.com/ethereum/go-ethereum/common"
)

// getInt64Field tries to get an int64 field by name, trying multiple possible field names
func getInt64Field(v reflect.Value, names ...string) int64 {
	for _, name := range names {
		if field := v.FieldByName(name); field.IsValid() {
			return field.Int()
		}
	}
	return 0
}

// GetAllocationIdsForClient gets all allocation IDs for a specific client address
// Uses the getAllocationIdsForClient getter function
func (c *Client) GetAllocationIdsForClient(clientAddress string) ([]uint64, error) {
	var result []interface{}
	
	// Convert string address to common.Address
	addr := common.HexToAddress(clientAddress)
	
	// Use the dedicated getter function
	err := c.contract.Call(nil, &result, "getAllocationIdsForClient", addr)
	if err != nil {
		return nil, fmt.Errorf("failed to call getAllocationIdsForClient: %w", err)
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
// Uses the length of the public allocationIdsByClient mapping
func (c *Client) GetAllocationCountForClient(clientAddress string) (*big.Int, error) {
	// Get the allocation IDs and return the count
	allocationIds, err := c.GetAllocationIdsForClient(clientAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to get allocation IDs: %w", err)
	}

	return big.NewInt(int64(len(allocationIds))), nil
}

// GetAllocationIdsForProvider gets all allocation IDs for a specific provider
// Uses the getAllocationIdsForProvider getter function
func (c *Client) GetAllocationIdsForProvider(providerId uint64) ([]uint64, error) {
	var result []interface{}
	
	// Use the dedicated getter function
	err := c.contract.Call(nil, &result, "getAllocationIdsForProvider", providerId)
	if err != nil {
		return nil, fmt.Errorf("failed to call getAllocationIdsForProvider: %w", err)
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

// GetProviderForAllocation gets the provider ID for a specific allocation
// Uses the public allocationIdToProvider mapping
func (c *Client) GetProviderForAllocation(allocationId uint64) (uint64, error) {
	var result []interface{}
	
	// Use the public mapping getter directly
	err := c.contract.Call(nil, &result, "allocationIdToProvider", allocationId)
	if err != nil {
		return 0, fmt.Errorf("failed to call allocationIdToProvider: %w", err)
	}

	if len(result) == 0 {
		return 0, nil
	}

	// Convert result to uint64
	if providerId, ok := result[0].(uint64); ok {
		return providerId, nil
	}

	// Handle case where it might be returned as *big.Int
	if providerId, ok := result[0].(*big.Int); ok {
		return providerId.Uint64(), nil
	}

	return 0, fmt.Errorf("unexpected result type: %T", result[0])
}

// GetRailIdForAllocation gets the rail ID for a specific allocation
// Uses the public allocationIdToRailId mapping
func (c *Client) GetRailIdForAllocation(allocationId uint64) (*big.Int, error) {
	var result []interface{}
	
	// Use the public mapping getter directly
	err := c.contract.Call(nil, &result, "allocationIdToRailId", allocationId)
	if err != nil {
		return nil, fmt.Errorf("failed to call allocationIdToRailId: %w", err)
	}

	if len(result) == 0 {
		return big.NewInt(0), nil
	}

	// Convert result to *big.Int
	if railId, ok := result[0].(*big.Int); ok {
		return railId, nil
	}

	// Handle case where it might be returned as uint64
	if railId, ok := result[0].(uint64); ok {
		return big.NewInt(int64(railId)), nil
	}

	return big.NewInt(0), fmt.Errorf("unexpected result type: %T", result[0])
}

// Legacy function kept for backwards compatibility
// GetClaimInfoForClient gets claim information for a specific client address and claim ID
func (c *Client) GetClaimInfoForClient(clientAddress string, claimId uint64) ([]types.Claim, error) {
	var result []interface{}
	
	// Convert string address to common.Address
	addr := common.HexToAddress(clientAddress)
	
	err := c.contract.Call(nil, &result, "getClaimInfoForClient", addr, claimId)
	if err != nil {
		return nil, fmt.Errorf("failed to call contract: %w", err)
	}
	if len(result) == 0 {
		return []types.Claim{}, nil
	}

	// Try different possible struct formats that go-ethereum might use
	
	// First try with camelCase field names (go-ethereum automatic conversion)
	if claimsSlice, ok := result[0].([]struct {
		Provider  uint64 `json:"provider"`
		Client    uint64 `json:"client"`
		Data      []uint8 `json:"data"`
		Size      uint64 `json:"size"`
		TermMin   int64  `json:"term_min"`
		TermMax   int64  `json:"term_max"`
		TermStart int64  `json:"term_start"`
		Sector    uint64 `json:"sector"`
	}); ok {
		// Convert to our types.Claim slice
		claims := make([]types.Claim, len(claimsSlice))
		for i, contractClaim := range claimsSlice {
			claims[i] = types.Claim{
				Provider:  contractClaim.Provider,
				Client:    contractClaim.Client,
				Data:      contractClaim.Data,
				Size:      contractClaim.Size,
				TermMin:   contractClaim.TermMin,
				TermMax:   contractClaim.TermMax,
				TermStart: contractClaim.TermStart,
				Sector:    contractClaim.Sector,
			}
		}
		return claims, nil
	}

	// Try with snake_case field names
	if claimsSlice, ok := result[0].([]struct {
		Provider   uint64 `json:"provider"`
		Client     uint64 `json:"client"`
		Data       []uint8 `json:"data"`
		Size       uint64 `json:"size"`
		Term_min   int64  `json:"term_min"`
		Term_max   int64  `json:"term_max"`
		Term_start int64  `json:"term_start"`
		Sector     uint64 `json:"sector"`
	}); ok {
		// Convert to our types.Claim slice
		claims := make([]types.Claim, len(claimsSlice))
		for i, contractClaim := range claimsSlice {
			claims[i] = types.Claim{
				Provider:  contractClaim.Provider,
				Client:    contractClaim.Client,
				Data:      contractClaim.Data,
				Size:      contractClaim.Size,
				TermMin:   contractClaim.Term_min,
				TermMax:   contractClaim.Term_max,
				TermStart: contractClaim.Term_start,
				Sector:    contractClaim.Sector,
			}
		}
		return claims, nil
	}

	// If neither works, try to parse using reflection
	resultSlice := result[0]
	if reflect.TypeOf(resultSlice).Kind() == reflect.Slice {
		v := reflect.ValueOf(resultSlice)
		claims := make([]types.Claim, v.Len())
		
		for i := 0; i < v.Len(); i++ {
			claimValue := v.Index(i)
			
			claims[i] = types.Claim{
				Provider:  claimValue.FieldByName("Provider").Uint(),
				Client:    claimValue.FieldByName("Client").Uint(),
				Data:      claimValue.FieldByName("Data").Interface().([]byte),
				Size:      claimValue.FieldByName("Size").Uint(),
				TermMin:   getInt64Field(claimValue, "TermMin", "Term_min"),
				TermMax:   getInt64Field(claimValue, "TermMax", "Term_max"),
				TermStart: getInt64Field(claimValue, "TermStart", "Term_start"),
				Sector:    claimValue.FieldByName("Sector").Uint(),
			}
		}
		return claims, nil
	}

	return []types.Claim{}, fmt.Errorf("unexpected result type: %T", result[0])
}
