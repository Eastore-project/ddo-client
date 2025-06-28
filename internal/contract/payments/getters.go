package payments

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"ddo-client/internal/types"
)

// GetCommissionMaxBPS returns the maximum commission rate in basis points
func (c *Client) GetCommissionMaxBPS() (*big.Int, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "COMMISSION_MAX_BPS")
	if err != nil {
		return nil, fmt.Errorf("failed to get COMMISSION_MAX_BPS: %w", err)
	}
	return result[0].(*big.Int), nil
}

// GetPaymentFeeBPS returns the payment fee in basis points
func (c *Client) GetPaymentFeeBPS() (*big.Int, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "PAYMENT_FEE_BPS")
	if err != nil {
		return nil, fmt.Errorf("failed to get PAYMENT_FEE_BPS: %w", err)
	}
	return result[0].(*big.Int), nil
}

// GetAccount returns the account information for a specific token and account address
func (c *Client) GetAccount(token, account common.Address) (*types.Account, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "accounts", token, account)
	if err != nil {
		return nil, fmt.Errorf("failed to get account: %w", err)
	}

	if len(result) < 4 {
		return nil, fmt.Errorf("unexpected number of results from accounts: got %d, expected 4", len(result))
	}

	// Parse individual values from the result array
	// Order: [funds, lockupCurrent, lockupRate, lockupLastSettledAt]
	return &types.Account{
		Funds:               result[0].(*big.Int),
		LockupCurrent:       result[1].(*big.Int),
		LockupRate:          result[2].(*big.Int),
		LockupLastSettledAt: result[3].(*big.Int),
	}, nil
}

// GetOperatorApproval returns the operator approval information
func (c *Client) GetOperatorApproval(token, client, operator common.Address) (*types.OperatorApproval, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "operatorApprovals", token, client, operator)
	if err != nil {
		return nil, fmt.Errorf("failed to get operator approval: %w", err)
	}

	if len(result) < 6 {
		return nil, fmt.Errorf("unexpected number of results from operatorApprovals: got %d, expected 6", len(result))
	}

	// Parse individual values from the result array
	// Order: [isApproved, rateAllowance, lockupAllowance, rateUsage, lockupUsage, maxLockupPeriod]
	return &types.OperatorApproval{
		IsApproved:      result[0].(bool),
		RateAllowance:   result[1].(*big.Int),
		LockupAllowance: result[2].(*big.Int),
		RateUsage:       result[3].(*big.Int),
		LockupUsage:     result[4].(*big.Int),
		MaxLockupPeriod: result[5].(*big.Int),
	}, nil
}

// GetAccumulatedFees returns the accumulated fees for a specific token
func (c *Client) GetAccumulatedFees(token common.Address) (*big.Int, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "accumulatedFees", token)
	if err != nil {
		return nil, fmt.Errorf("failed to get accumulated fees: %w", err)
	}
	return result[0].(*big.Int), nil
}

// GetHasCollectedFees returns whether fees have been collected for a token
func (c *Client) GetHasCollectedFees(token common.Address) (bool, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "hasCollectedFees", token)
	if err != nil {
		return false, fmt.Errorf("failed to get hasCollectedFees: %w", err)
	}
	return result[0].(bool), nil
}

// GetRail returns the rail information for a specific rail ID
func (c *Client) GetRail(railId *big.Int) (*types.RailView, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "getRail", railId)
	if err != nil {
		return nil, fmt.Errorf("failed to get rail: %w", err)
	}

	railStruct := result[0].(struct {
		Token               common.Address `json:"token"`
		From                common.Address `json:"from"`
		To                  common.Address `json:"to"`
		Operator            common.Address `json:"operator"`
		Validator           common.Address `json:"validator"`
		PaymentRate         *big.Int       `json:"paymentRate"`
		LockupPeriod        *big.Int       `json:"lockupPeriod"`
		LockupFixed         *big.Int       `json:"lockupFixed"`
		SettledUpTo         *big.Int       `json:"settledUpTo"`
		EndEpoch            *big.Int       `json:"endEpoch"`
		CommissionRateBps   *big.Int       `json:"commissionRateBps"`
		ServiceFeeRecipient common.Address `json:"serviceFeeRecipient"`
	})

	return &types.RailView{
		Token:               railStruct.Token,
		From:                railStruct.From,
		To:                  railStruct.To,
		Operator:            railStruct.Operator,
		Validator:           railStruct.Validator,
		PaymentRate:         railStruct.PaymentRate,
		LockupPeriod:        railStruct.LockupPeriod,
		LockupFixed:         railStruct.LockupFixed,
		SettledUpTo:         railStruct.SettledUpTo,
		EndEpoch:            railStruct.EndEpoch,
		CommissionRateBps:   railStruct.CommissionRateBps,
		ServiceFeeRecipient: railStruct.ServiceFeeRecipient,
	}, nil
}

// GetAllAccumulatedFees returns all accumulated fees across all tokens
func (c *Client) GetAllAccumulatedFees() (*types.AccumulatedFeesResult, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "getAllAccumulatedFees")
	if err != nil {
		return nil, fmt.Errorf("failed to get all accumulated fees: %w", err)
	}

	return &types.AccumulatedFeesResult{
		Tokens:  result[0].([]common.Address),
		Amounts: result[1].([]*big.Int),
		Count:   result[2].(*big.Int),
	}, nil
}

// GetRailsForPayerAndToken returns all rails for a payer and specific token
func (c *Client) GetRailsForPayerAndToken(payer, token common.Address) ([]*types.RailInfo, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "getRailsForPayerAndToken", payer, token)
	if err != nil {
		return nil, fmt.Errorf("failed to get rails for payer and token: %w", err)
	}

	if len(result) == 0 {
		return []*types.RailInfo{}, nil
	}

	// Parse the array of RailInfo structs
	railInfoStructs := result[0].([]struct {
		RailId       *big.Int `json:"railId"`
		IsTerminated bool     `json:"isTerminated"`
		EndEpoch     *big.Int `json:"endEpoch"`
	})

	railInfos := make([]*types.RailInfo, len(railInfoStructs))
	for i, r := range railInfoStructs {
		railInfos[i] = &types.RailInfo{
			RailId:       r.RailId,
			IsTerminated: r.IsTerminated,
			EndEpoch:     r.EndEpoch,
		}
	}

	return railInfos, nil
}

// GetRailsForPayeeAndToken returns all rails for a payee and specific token
func (c *Client) GetRailsForPayeeAndToken(payee, token common.Address) ([]*types.RailInfo, error) {
	var result []interface{}
	err := c.contract.Call(&bind.CallOpts{Context: context.Background()}, &result, "getRailsForPayeeAndToken", payee, token)
	if err != nil {
		return nil, fmt.Errorf("failed to get rails for payee and token: %w", err)
	}

	if len(result) == 0 {
		return []*types.RailInfo{}, nil
	}

	// Parse the array of RailInfo structs
	railInfoStructs := result[0].([]struct {
		RailId       *big.Int `json:"railId"`
		IsTerminated bool     `json:"isTerminated"`
		EndEpoch     *big.Int `json:"endEpoch"`
	})

	railInfos := make([]*types.RailInfo, len(railInfoStructs))
	for i, r := range railInfoStructs {
		railInfos[i] = &types.RailInfo{
			RailId:       r.RailId,
			IsTerminated: r.IsTerminated,
			EndEpoch:     r.EndEpoch,
		}
	}

	return railInfos, nil
} 