package ddo

import (
	"context"
	"fmt"
	"math/big"
	"reflect"

	"github.com/Eastore-project/ddo-client/pkg/types"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
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

// GetAllocationInfo queries the allocationInfos mapping for a specific allocation ID
func (c *Client) GetAllocationInfo(allocationId uint64) (*types.AllocationInfo, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "allocationInfos", allocationId)
	if err != nil {
		return nil, fmt.Errorf("failed to call allocationInfos: %w", err)
	}

	// allocationInfos returns 9 individual values (not a struct tuple)
	if len(result) < 9 {
		return nil, fmt.Errorf("unexpected number of results from allocationInfos: %d", len(result))
	}

	info := &types.AllocationInfo{
		Client:               result[0].(common.Address),
		Provider:             result[1].(uint64),
		Activated:            result[2].(bool),
		PieceCidHash:         result[3].([32]byte),
		PaymentToken:         result[4].(common.Address),
		PieceSize:            result[5].(uint64),
		RailId:               result[6].(*big.Int),
		PricePerBytePerEpoch: result[7].(*big.Int),
		SectorNumber:         result[8].(uint64),
	}

	return info, nil
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
