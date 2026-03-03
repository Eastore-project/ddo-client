package ddo

import (
	"context"
	"fmt"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/core/types"

	ddotypes "ddo-client/internal/types"
)

// CreateAllocationRequests creates allocation requests on the contract
func (c *Client) CreateAllocationRequests(pieceInfos []ddotypes.PieceInfo) (string, error) {
	c.auth.Context = context.Background()

	tx, err := c.contract.Transact(c.auth, "createAllocationRequests", pieceInfos)
	if err != nil {
		return "", fmt.Errorf("failed to send transaction: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// allocationCreatedEventID holds the parsed AllocationCreated event from the ABI.
var allocationCreatedEventID abi.Event

func init() {
	parsedABI, err := abi.JSON(strings.NewReader(DDOClientABI))
	if err != nil {
		panic(fmt.Sprintf("failed to parse ABI for events: %v", err))
	}
	event, ok := parsedABI.Events["AllocationCreated"]
	if !ok {
		panic("AllocationCreated event not found in ABI")
	}
	allocationCreatedEventID = event
}

// ParseAllocationCreatedEvents extracts allocation IDs from AllocationCreated event logs
// in a transaction receipt. The allocationId is the second indexed parameter (topic[2]).
func ParseAllocationCreatedEvents(receipt *types.Receipt) ([]uint64, error) {
	var allocationIDs []uint64

	eventSigHash := allocationCreatedEventID.ID

	for _, log := range receipt.Logs {
		if len(log.Topics) < 3 {
			continue
		}
		if log.Topics[0] != eventSigHash {
			continue
		}

		// topic[1] = client (address, indexed)
		// topic[2] = allocationId (uint64, indexed)
		allocationIdBig := new(big.Int).SetBytes(log.Topics[2].Bytes())
		allocationIDs = append(allocationIDs, allocationIdBig.Uint64())
	}

	if len(allocationIDs) == 0 {
		return nil, fmt.Errorf("no AllocationCreated events found in transaction receipt")
	}

	return allocationIDs, nil
}
