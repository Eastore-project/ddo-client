package types

import (
	"math/big"

	"github.com/ethereum/go-ethereum/common"
)

// Account represents the Account struct from the Payments contract
type Account struct {
	Funds               *big.Int `json:"funds"`
	LockupCurrent       *big.Int `json:"lockupCurrent"`
	LockupRate          *big.Int `json:"lockupRate"`
	LockupLastSettledAt *big.Int `json:"lockupLastSettledAt"`
}

// OperatorApproval represents the OperatorApproval struct from the Payments contract
type OperatorApproval struct {
	IsApproved       bool     `json:"isApproved"`
	RateAllowance    *big.Int `json:"rateAllowance"`
	LockupAllowance  *big.Int `json:"lockupAllowance"`
	RateUsage        *big.Int `json:"rateUsage"`
	LockupUsage      *big.Int `json:"lockupUsage"`
	MaxLockupPeriod  *big.Int `json:"maxLockupPeriod"`
}

// RailView represents the RailView struct from the Payments contract
type RailView struct {
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
}

// RailInfo represents the RailInfo struct from the Payments contract
type RailInfo struct {
	RailId       *big.Int `json:"railId"`
	IsTerminated bool     `json:"isTerminated"`
	EndEpoch     *big.Int `json:"endEpoch"`
}

// SettlementResult represents the return values from settlement functions
type SettlementResult struct {
	TotalSettledAmount        *big.Int `json:"totalSettledAmount"`
	TotalNetPayeeAmount       *big.Int `json:"totalNetPayeeAmount"`
	TotalPaymentFee           *big.Int `json:"totalPaymentFee"`
	TotalOperatorCommission   *big.Int `json:"totalOperatorCommission"`
	FinalSettledEpoch         *big.Int `json:"finalSettledEpoch"`
	Note                      string   `json:"note"`
}

// AccumulatedFeesResult represents the return from getAllAccumulatedFees
type AccumulatedFeesResult struct {
	Tokens  []common.Address `json:"tokens"`
	Amounts []*big.Int       `json:"amounts"`
	Count   *big.Int         `json:"count"`
} 