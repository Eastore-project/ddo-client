package curio

import (
	"fmt"

	"github.com/ethereum/go-ethereum/common"
	"github.com/filecoin-project/go-address"
)

// EthToFilecoinDelegated converts an Ethereum address to a Filecoin f410 delegated address.
func EthToFilecoinDelegated(ethAddr common.Address) (address.Address, error) {
	addr, err := address.NewDelegatedAddress(10, ethAddr.Bytes())
	if err != nil {
		return address.Undef, fmt.Errorf("failed to create delegated address: %w", err)
	}
	return addr, nil
}

// ProviderIDToFilecoinAddr converts a provider ID number to a Filecoin f0 address.
func ProviderIDToFilecoinAddr(providerID uint64) (address.Address, error) {
	addr, err := address.NewIDAddress(providerID)
	if err != nil {
		return address.Undef, fmt.Errorf("failed to create ID address: %w", err)
	}
	return addr, nil
}
