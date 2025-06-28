package payments

import (
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
)

// SetOperatorApproval sets or updates operator approval
func (c *Client) SetOperatorApproval(
	token common.Address,
	operator common.Address,
	approved bool,
	rateAllowance *big.Int,
	lockupAllowance *big.Int,
	maxLockupPeriod *big.Int,
) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "setOperatorApproval", 
		token, operator, approved, rateAllowance, lockupAllowance, maxLockupPeriod)
	if err != nil {
		return "", fmt.Errorf("failed to set operator approval: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// Deposit deposits tokens into an account
func (c *Client) Deposit(token common.Address, to common.Address, amount *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	// If depositing native token (ETH), set value in transaction options
	opts := *c.auth
	if token == common.HexToAddress("0x0") {
		opts.Value = amount
	}

	tx, err := c.contract.Transact(&opts, "deposit", token, to, amount)
	if err != nil {
		return "", fmt.Errorf("failed to deposit: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// Withdraw withdraws tokens from the caller's account
func (c *Client) Withdraw(token common.Address, amount *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "withdraw", token, amount)
	if err != nil {
		return "", fmt.Errorf("failed to withdraw: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// WithdrawTo withdraws tokens from the caller's account to a specific address
func (c *Client) WithdrawTo(token common.Address, to common.Address, amount *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "withdrawTo", token, to, amount)
	if err != nil {
		return "", fmt.Errorf("failed to withdraw to address: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// CreateRail creates a new payment rail
func (c *Client) CreateRail(
	token common.Address,
	from common.Address,
	to common.Address,
	validator common.Address,
	commissionRateBps *big.Int,
) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "createRail", token, from, to, validator, commissionRateBps)
	if err != nil {
		return "", fmt.Errorf("failed to create rail: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// ModifyRailLockup modifies the lockup parameters of a rail
func (c *Client) ModifyRailLockup(railId *big.Int, period *big.Int, lockupFixed *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "modifyRailLockup", railId, period, lockupFixed)
	if err != nil {
		return "", fmt.Errorf("failed to modify rail lockup: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// ModifyRailPayment modifies the payment parameters of a rail
func (c *Client) ModifyRailPayment(railId *big.Int, newRate *big.Int, oneTimePayment *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "modifyRailPayment", railId, newRate, oneTimePayment)
	if err != nil {
		return "", fmt.Errorf("failed to modify rail payment: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// TerminateRail terminates a payment rail
func (c *Client) TerminateRail(railId *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "terminateRail", railId)
	if err != nil {
		return "", fmt.Errorf("failed to terminate rail: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SettleRail settles a rail up to a specific epoch
func (c *Client) SettleRail(railId *big.Int, untilEpoch *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "settleRail", railId, untilEpoch)
	if err != nil {
		return "", fmt.Errorf("failed to settle rail: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// SettleTerminatedRailWithoutArbitration settles a terminated rail without arbitration
func (c *Client) SettleTerminatedRailWithoutArbitration(railId *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "settleTerminatedRailWithoutArbitration", railId)
	if err != nil {
		return "", fmt.Errorf("failed to settle terminated rail: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// WithdrawFees allows the contract owner to withdraw accumulated fees
func (c *Client) WithdrawFees(token common.Address, to common.Address, amount *big.Int) (string, error) {
	if c.auth == nil {
		return "", fmt.Errorf("client not configured for transactions")
	}

	tx, err := c.contract.Transact(c.auth, "withdrawFees", token, to, amount)
	if err != nil {
		return "", fmt.Errorf("failed to withdraw fees: %w", err)
	}

	return tx.Hash().Hex(), nil
}

// WaitForTransaction waits for a transaction to be mined and returns the receipt
func (c *Client) WaitForTransaction(txHash string) (*types.Receipt, error) {
	// Note: This is a placeholder implementation
	// In a real implementation, you would need the actual transaction object
	return nil, fmt.Errorf("WaitForTransaction not fully implemented - use specific transaction methods")
} 