package ddo

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"

	"ddo-client/internal/types"
)

// GetAllocationRailInfo gets allocation and rail information together
func (c *Client) GetAllocationRailInfo(allocationId uint64) (uint64, uint64, *types.RailView, error) {
	var results []interface{}
	err := c.contract.Call(&bind.CallOpts{}, &results, "getAllocationRailInfo", allocationId)
	if err != nil {
		return 0, 0, nil, fmt.Errorf("failed to call getAllocationRailInfo: %w", err)
	}

	if len(results) < 3 {
		return 0, 0, nil, fmt.Errorf("unexpected number of results from getAllocationRailInfo")
	}

	railId := results[0].(*big.Int).Uint64()
	providerId := results[1].(uint64)
	
	// Parse the rail view struct - match the actual struct with JSON tags
	railViewData := results[2].(struct {
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
	
	railView := &types.RailView{
		Token:               railViewData.Token,
		From:                railViewData.From,
		To:                  railViewData.To,
		Operator:            railViewData.Operator,
		Validator:           railViewData.Validator,
		PaymentRate:         railViewData.PaymentRate,
		LockupPeriod:        railViewData.LockupPeriod,
		LockupFixed:         railViewData.LockupFixed,
		SettledUpTo:         railViewData.SettledUpTo,
		EndEpoch:            railViewData.EndEpoch,
		CommissionRateBps:   railViewData.CommissionRateBps,
		ServiceFeeRecipient: railViewData.ServiceFeeRecipient,
	}

	return railId, providerId, railView, nil
}

// SettleSpPayment settles storage provider payment for a specific allocation
func (c *Client) SettleSpPayment(allocationId uint64, untilEpoch *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (no private key)")
	}

	tx, err := c.contract.Transact(c.auth, "settleSpPayment", allocationId, untilEpoch)
	if err != nil {
		return "", fmt.Errorf("failed to call settleSpPayment: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SettleSpTotalPayment settles storage provider payment for all allocations of a provider
func (c *Client) SettleSpTotalPayment(providerId uint64, untilEpoch *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions (no private key)")
	}

	tx, err := c.contract.Transact(c.auth, "settleSpTotalPayment", providerId, untilEpoch)
	if err != nil {
		return "", fmt.Errorf("failed to call settleSpTotalPayment: %w", err)
	}

	return tx.Hash().Hex(), nil
}