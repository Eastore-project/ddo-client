package types

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

// TokenBalance represents a token balance for an address
type TokenBalance struct {
	TokenAddress common.Address `json:"tokenAddress"`
	Balance      *big.Int       `json:"balance"`
}

// TokenBalanceResult contains the result of token balance queries
type TokenBalanceResult struct {
	Address  common.Address `json:"address"`
	Balances []TokenBalance `json:"balances"`
}

// TokenBalanceComparison contains before/after balance comparison
type TokenBalanceComparison struct {
	TokenAddress   common.Address `json:"tokenAddress"`
	BeforeBalance  *big.Int       `json:"beforeBalance"`
	AfterBalance   *big.Int       `json:"afterBalance"`
	Difference     *big.Int       `json:"difference"`
	HasChange      bool           `json:"hasChange"`
} 