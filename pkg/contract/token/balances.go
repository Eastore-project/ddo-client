package token

import (
	"math/big"

	logging "github.com/ipfs/go-log/v2"

	"github.com/ethereum/go-ethereum/common"

	"github.com/Eastore-project/ddo-client/pkg/types"
)

var log = logging.Logger("ddo/token")

// GetTokenBalances gets the token balances for an address from the supported tokens
func GetTokenBalances(rpcEndpoint string, supportedTokens []types.TokenConfig, address common.Address) ([]types.TokenBalance, error) {
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
		erc20Client, err := NewERC20ReadOnlyClient(rpcEndpoint, tokenConfig.Token.Hex())
		if err != nil {
			log.Warnw("failed to create ERC20 client",
				"token", tokenConfig.Token.Hex(), "error", err)
			continue
		}

		balance, err := erc20Client.GetBalance(address)
		if err != nil {
			log.Warnw("failed to get balance",
				"token", tokenConfig.Token.Hex(), "error", err)
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
func GetTokenBalanceResult(rpcEndpoint string, supportedTokens []types.TokenConfig, address common.Address) (*types.TokenBalanceResult, error) {
	balances, err := GetTokenBalances(rpcEndpoint, supportedTokens, address)
	if err != nil {
		return nil, err
	}

	return &types.TokenBalanceResult{
		Address:  address,
		Balances: balances,
	}, nil
}
