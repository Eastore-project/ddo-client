package token

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"

	"ddo-client/internal/config"
	"ddo-client/internal/types"
)

// GetTokenBalances gets the token balances for an address from the supported tokens
func GetTokenBalances(supportedTokens []types.TokenConfig, address common.Address) ([]types.TokenBalance, error) {
	var balances []types.TokenBalance
	
	for _, tokenConfig := range supportedTokens {
		if !tokenConfig.IsActive {
			continue
		}
		
		// Skip native token (address 0x0) as it's handled differently
		if tokenConfig.Token == common.HexToAddress("0x0") {
			balances = append(balances, types.TokenBalance{
				TokenAddress: tokenConfig.Token,
				Balance:      big.NewInt(0), // We could get ETH balance but it's more complex
			})
			continue
		}
		
		// Create read-only ERC20 client
		erc20Client, err := NewERC20ReadOnlyClient(config.RPCEndpoint, tokenConfig.Token.Hex())
		if err != nil {
			fmt.Printf("⚠️  Warning: failed to create ERC20 client for token %s: %v\n", 
				tokenConfig.Token.Hex(), err)
			continue
		}
		
		balance, err := erc20Client.GetBalance(address)
		if err != nil {
			fmt.Printf("⚠️  Warning: failed to get balance for token %s: %v\n", 
				tokenConfig.Token.Hex(), err)
			erc20Client.Close()
			continue
		}
		
		balances = append(balances, types.TokenBalance{
			TokenAddress: tokenConfig.Token,
			Balance:      balance,
		})
		
		erc20Client.Close()
	}
	
	return balances, nil
}
// GetTokenBalanceResult gets token balances and returns a structured result
func GetTokenBalanceResult(supportedTokens []types.TokenConfig, address common.Address) (*types.TokenBalanceResult, error) {
	balances, err := GetTokenBalances(supportedTokens, address)
	if err != nil {
		return nil, err
	}
	
	return &types.TokenBalanceResult{
		Address:  address,
		Balances: balances,
	}, nil
} 