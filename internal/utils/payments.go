package utils

import (
	"context"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"ddo-client/internal/config"
	"ddo-client/internal/contract/ddo"
	"ddo-client/internal/contract/payments"
	"ddo-client/internal/contract/token"
	"ddo-client/internal/types"
)

const (
	// EPOCHS_PER_MONTH represents the number of epochs in a month (from DDOSp.sol)
	EPOCHS_PER_MONTH = 86400
	// BYTES_PER_TB represents the number of bytes in a terabyte
	BYTES_PER_TB = 1024 * 1024 * 1024 * 1024
	// USD_DECIMALS represents the number of decimals for USD calculations (6 for USDC)
	USD_DECIMALS = 18
)

// StorageCostResult contains the result of storage cost calculation
type StorageCostResult struct {
	TotalCost           *big.Int `json:"totalCost"`
	PricePerBytePerEpoch *big.Int `json:"pricePerBytePerEpoch"`
	TotalBytes          uint64   `json:"totalBytes"`
	TotalEpochs         int64    `json:"totalEpochs"`
}

// PaymentSetupResult contains the result of payment setup operations
type PaymentSetupResult struct {
	TotalStorageCost    *big.Int `json:"totalStorageCost"`
	OneMonthAllowance   *big.Int `json:"oneMonthAllowance"`
	RequiredDeposit     *big.Int `json:"requiredDeposit"`
	TokenAddress        string   `json:"tokenAddress"`
	TokenAllowanceTx    string   `json:"tokenAllowanceTx,omitempty"`
	DepositTxHash       string   `json:"depositTxHash,omitempty"`
	OperatorApprovalTx  string   `json:"operatorApprovalTx,omitempty"`
}

// CalculateStorageCosts calculates the total storage costs for multiple pieces
func CalculateStorageCosts(ddoClient *ddo.Client, pieceInfos []types.PieceInfo) (*StorageCostResult, error) {
	if len(pieceInfos) == 0 {
		return nil, fmt.Errorf("no piece infos provided")
	}

	totalCost := big.NewInt(0)
	var totalBytes uint64 = 0
	var totalEpochs int64 = 0
	var pricePerBytePerEpoch *big.Int

	// Group pieces by provider and token for cost calculation
	providerTokenCosts := make(map[string]*big.Int)

	for _, piece := range pieceInfos {
		if piece.TermMin <= 0 {
			return nil, fmt.Errorf("invalid term length for piece provider %d: %d", piece.Provider, piece.TermMin)
		}

		        // Calculate cost for this specific piece
        cost, err := ddoClient.CalculateStorageCost(
            piece.Provider,
            piece.PaymentTokenAddress,
            piece.Size,
            piece.TermMin,
        )
		if err != nil {
			return nil, fmt.Errorf("failed to calculate storage cost for provider %d: %w", piece.Provider, err)
		}

		        // Get price per byte per epoch for the first piece (assuming all use same rate)
        if pricePerBytePerEpoch == nil {
            pricePerBytePerEpoch, err = ddoClient.GetAndValidateSPPrice(piece.Provider, piece.PaymentTokenAddress)
            if err != nil {
                return nil, fmt.Errorf("failed to get SP price for provider %d: %w", piece.Provider, err)
            }
        }

        key := fmt.Sprintf("%d-%s", piece.Provider, piece.PaymentTokenAddress.Hex())
		if providerTokenCosts[key] == nil {
			providerTokenCosts[key] = big.NewInt(0)
		}
		providerTokenCosts[key].Add(providerTokenCosts[key], cost)

		totalCost.Add(totalCost, cost)
		totalBytes += piece.Size
		totalEpochs += piece.TermMin
	}

	return &StorageCostResult{
		TotalCost:           totalCost,
		PricePerBytePerEpoch: pricePerBytePerEpoch,
		TotalBytes:          totalBytes,
		TotalEpochs:         totalEpochs,
	}, nil
}

// CheckAndSetupPayments handles the complete payment setup process
func CheckAndSetupPayments(
	ethClient *ethclient.Client,
	ddoClient *ddo.Client,
	paymentsClient *payments.Client,
	pieceInfos []types.PieceInfo,
	userAddress common.Address,
	contractAddress common.Address,
) (*PaymentSetupResult, error) {
	
	// Calculate total storage costs
	costResult, err := CalculateStorageCosts(ddoClient, pieceInfos)
	if err != nil {
		return nil, fmt.Errorf("failed to calculate storage costs: %w", err)
	}

	    // Assume all pieces use the same token (we could enhance this later for multi-token support)
    if len(pieceInfos) == 0 {
        return nil, fmt.Errorf("no pieces provided")
    }
    tokenAddress := pieceInfos[0].PaymentTokenAddress

	// Calculate one month allowance (for operator approval lockup allowance)
	// This is: total_bytes * price_per_byte_per_epoch * epochs_per_month
	oneMonthCost := new(big.Int).Mul(
		new(big.Int).SetUint64(costResult.TotalBytes),
		costResult.PricePerBytePerEpoch,
	)
	oneMonthCost.Mul(oneMonthCost, big.NewInt(EPOCHS_PER_MONTH))

	// Required deposit is the total storage cost
	requiredDeposit := new(big.Int).Mul(costResult.TotalCost, big.NewInt(2))

	fmt.Printf("💰 Payment Setup Summary:\n")
	fmt.Printf("   Token: %s\n", tokenAddress.Hex())
	fmt.Printf("   Total Storage Cost: %s\n", costResult.TotalCost.String())
	fmt.Printf("   One Month Allowance: %s\n", oneMonthCost.String())
	fmt.Printf("   Required Deposit: %s\n", requiredDeposit.String())
	fmt.Println()

	result := &PaymentSetupResult{
		TotalStorageCost:  costResult.TotalCost,
		OneMonthAllowance: oneMonthCost,
		RequiredDeposit:   requiredDeposit,
		TokenAddress:      tokenAddress.Hex(),
	}

	// Check current account balance in payments contract
	fmt.Println(tokenAddress.Hex())
	account, err := paymentsClient.GetAccount(tokenAddress, userAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to get account info: %w", err)
	}

	fmt.Printf("📊 Current Account Status:\n")
	fmt.Printf("   Funds: %s\n", account.Funds.String())
	fmt.Printf("   Lockup Current: %s\n", account.LockupCurrent.String())
	fmt.Printf("   Available: %s\n", new(big.Int).Sub(account.Funds, account.LockupCurrent).String())
	fmt.Println()

	// Check if user needs to deposit more funds
	available := new(big.Int).Sub(account.Funds, account.LockupCurrent)
	if available.Cmp(requiredDeposit) < 0 {
		deficit := new(big.Int).Sub(requiredDeposit, available)
		fmt.Printf("⚠️  Insufficient funds. Need to deposit: %s\n", deficit.String())
		
		// For ERC20 tokens, check and approve allowance before depositing
		if tokenAddress != common.HexToAddress("0x0") {
			fmt.Printf("🔍 Checking ERC20 token allowance...\n")
			
			// Create ERC20 client
			erc20Client, err := token.NewERC20Client(tokenAddress.Hex())
			if err != nil {
				return nil, fmt.Errorf("failed to create ERC20 client: %w", err)
			}
			defer erc20Client.Close()

			// Check user's token balance
			tokenBalance, err := erc20Client.GetBalance(userAddress)
			if err != nil {
				return nil, fmt.Errorf("failed to get token balance: %w", err)
			}

			if tokenBalance.Cmp(deficit) < 0 {
				return nil, fmt.Errorf("insufficient token balance: have %s, need %s", tokenBalance.String(), deficit.String())
			}

			// Check and approve allowance if needed
			allowanceTx, approved, err := erc20Client.CheckAndApprove(userAddress, paymentsClient.GetContractAddress(), deficit)
			if err != nil {
				return nil, fmt.Errorf("failed to check/approve token allowance: %w", err)
			}

			if approved {
				fmt.Printf("✅ Token allowance approved: %s\n", allowanceTx)
				result.TokenAllowanceTx = allowanceTx
				
				// Wait for approval transaction to be mined before depositing
				fmt.Printf("⏳ Waiting for allowance transaction to be mined...\n")
				if err := WaitForTransaction(ethClient, allowanceTx); err != nil {
					fmt.Printf("⚠️  Warning: allowance transaction may not have been mined: %v\n", err)
				}
			} else {
				fmt.Printf("✅ Token allowance already sufficient\n")
			}
		}

		// Deposit the required amount
		fmt.Printf("💸 Depositing %s tokens...\n", deficit.String())
		txHash, err := paymentsClient.Deposit(tokenAddress, userAddress, deficit)
		if err != nil {
			return nil, fmt.Errorf("failed to deposit tokens: %w", err)
		}
		result.DepositTxHash = txHash
		fmt.Printf("✅ Deposit transaction sent: %s\n", txHash)
	}

	// Check operator approval for DDO contract
	operatorApproval, err := paymentsClient.GetOperatorApproval(tokenAddress, userAddress, contractAddress)
	if err != nil {
		return nil, fmt.Errorf("failed to get operator approval: %w", err)
	}

	fmt.Printf("🔐 Operator Approval Status:\n")
	fmt.Printf("   Is Approved: %t\n", operatorApproval.IsApproved)
	fmt.Printf("   Rate Allowance: %s\n", operatorApproval.RateAllowance.String())
	fmt.Printf("   Lockup Allowance: %s\n", operatorApproval.LockupAllowance.String())
	fmt.Printf("   Rate Usage: %s\n", operatorApproval.RateUsage.String())
	fmt.Printf("   Lockup Usage: %s\n", operatorApproval.LockupUsage.String())
	fmt.Println()
		
	// Set rate allowance to a large number for flexibility
	rateAllowance := new(big.Int).Mul(costResult.PricePerBytePerEpoch, new(big.Int).SetUint64(costResult.TotalBytes))
	// actual cost is 2x one month cost even though we lock just for one month as we unlock fund after one time payment which require 2x allowance to go through
	// as funds are not unlocked before that operation
	lockupAllowance := new(big.Int).Mul(oneMonthCost, big.NewInt(2))
		var txHash string
		if !operatorApproval.IsApproved || (new(big.Int).Sub(operatorApproval.RateAllowance, operatorApproval.RateUsage).Cmp(rateAllowance) < 0 && new(big.Int).Sub(operatorApproval.LockupAllowance, operatorApproval.LockupUsage).Cmp(lockupAllowance) < 0) {
			fmt.Printf("🔧 Setting operator approval...\n")
			txHash, err = paymentsClient.SetOperatorApproval(
				tokenAddress,
				contractAddress, // operator (DDO contract)
				true,           // approved
				new(big.Int).Add(operatorApproval.RateAllowance, rateAllowance),  // rate allowance
				new(big.Int).Add(operatorApproval.LockupAllowance, lockupAllowance),   // lockup allowance (one month of payments)
				big.NewInt(EPOCHS_PER_MONTH), // max lockup period (1 month)
			) 
			} else if new(big.Int).Sub(operatorApproval.RateAllowance, operatorApproval.RateUsage).Cmp(rateAllowance) < 0 {
				fmt.Printf("🔧 Updating operator approval...\n")
				txHash, err = paymentsClient.SetOperatorApproval(
					tokenAddress,
					contractAddress, // operator (DDO contract)
					true,           // approved
					new(big.Int).Add(operatorApproval.RateAllowance, rateAllowance),  // rate allowance
					operatorApproval.LockupAllowance,   // lockup allowance same
					big.NewInt(EPOCHS_PER_MONTH), // max lockup period (1 month)
				)
			} else if new(big.Int).Sub(operatorApproval.LockupAllowance, operatorApproval.LockupUsage).Cmp(lockupAllowance) < 0 {
				fmt.Printf("🔧 Updating operator approval...\n")
				txHash, err = paymentsClient.SetOperatorApproval(
					tokenAddress,
					contractAddress, // operator (DDO contract)
					true,           // approved
					new(big.Int).Add(operatorApproval.RateAllowance, rateAllowance),  // rate allowance
					new(big.Int).Add(operatorApproval.LockupAllowance, lockupAllowance),   // lockup allowance (one month of payments)
					big.NewInt(EPOCHS_PER_MONTH), // max lockup period (1 month)
				)
			} else {
				fmt.Printf("✅ Operator approval already sufficient\n")
			}

		if err != nil {
			return nil, fmt.Errorf("failed to set operator approval: %w", err)
		}
		result.OperatorApprovalTx = txHash
		fmt.Printf("✅ Operator approval transaction sent: %s\n", txHash)
	

	return result, nil
}

// PromptUserConfirmation prompts the user to confirm payment setup
func PromptUserConfirmation(result *PaymentSetupResult) error {
	fmt.Printf("\n🎯 Payment Setup Required:\n")
	fmt.Printf("   Token: %s\n", result.TokenAddress)
	fmt.Printf("   Total Storage Cost: %s\n", result.TotalStorageCost.String())
	fmt.Printf("   Required Deposit: %s\n", result.RequiredDeposit.String())
	fmt.Printf("   Operator Allowance: %s\n", result.OneMonthAllowance.String())
	fmt.Println()
	
	fmt.Printf("⚠️  Before proceeding:\n")
	fmt.Printf("1. Ensure you have enough tokens in your wallet\n")
	fmt.Printf("2. Approve the payments contract to spend your tokens (if using ERC20)\n")
	fmt.Printf("3. The system will deposit tokens and set operator approvals\n")
	fmt.Println()
	
	// In a real CLI, you might want to add actual user confirmation prompt
	// For now, we'll assume confirmation
	return nil
}

// WaitForTransaction waits for a transaction to be mined
func WaitForTransaction(client *ethclient.Client, txHash string) error {
	if txHash == "" {
		return nil
	}
	
	hash := common.HexToHash(txHash)
	fmt.Printf("⏳ Waiting for transaction %s to be mined...\n", txHash)
	
	// Get the transaction first
	tx, _, err := client.TransactionByHash(context.Background(), hash)
	if err != nil {
		return fmt.Errorf("failed to get transaction: %w", err)
	}
	
	_, err = bind.WaitMined(context.Background(), client, tx)
	if err != nil {
		return fmt.Errorf("transaction failed or timed out: %w", err)
	}
	
	fmt.Printf("✅ Transaction mined successfully\n")
	return nil
}

// CalculateTotalDataCap calculates the total DataCap needed (sum of all piece sizes)
func CalculateTotalDataCap(pieceInfos []types.PieceInfo) *big.Int {
	totalDataCap := big.NewInt(0)
	
	for _, piece := range pieceInfos {
		totalDataCap.Add(totalDataCap, big.NewInt(int64(piece.Size)))
	}
	
	return totalDataCap
}

// CheckTokenAllowanceAndBalance checks token balance and allowance for a user
func CheckTokenAllowanceAndBalance(
	tokenAddress string, 
	userAddress, spenderAddress common.Address, 
	requiredAmount *big.Int,
) (balance, allowance *big.Int, err error) {
	// Skip check for native tokens (ETH)
	if tokenAddress == "0x0" || tokenAddress == "" {
		return big.NewInt(0), big.NewInt(0), nil
	}

	// Create ERC20 client for read-only operations
	erc20Client, err := token.NewERC20ReadOnlyClient(config.RPCEndpoint, tokenAddress)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to create ERC20 client: %w", err)
	}
	defer erc20Client.Close()

	// Get user's token balance
	balance, err = erc20Client.GetBalance(userAddress)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get token balance: %w", err)
	}

	// Get current allowance
	allowance, err = erc20Client.GetAllowance(userAddress, spenderAddress)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to get token allowance: %w", err)
	}

	return balance, allowance, nil
}

// ApproveTokenIfNeeded approves tokens for spending if the current allowance is insufficient
func ApproveTokenIfNeeded(
	tokenAddress string,
	userAddress, spenderAddress common.Address,
	requiredAmount *big.Int,
) (txHash string, wasApproved bool, err error) {
	// Skip approval for native tokens (ETH)
	if tokenAddress == "0x0" || tokenAddress == "" {
		return "", false, nil
	}

	// Create ERC20 client
	erc20Client, err := token.NewERC20Client(tokenAddress)
	if err != nil {
		return "", false, fmt.Errorf("failed to create ERC20 client: %w", err)
	}
	defer erc20Client.Close()

	// Check and approve if needed
	txHash, wasApproved, err = erc20Client.CheckAndApprove(userAddress, spenderAddress, requiredAmount)
	if err != nil {
		return "", false, fmt.Errorf("failed to check/approve allowance: %w", err)
	}

	return txHash, wasApproved, nil
}

// FormatBytes formats a byte count into a human-readable string
func FormatBytes(bytes *big.Int) string {
	const unit = 1024
	
	// Convert to float64 for calculation
	b := new(big.Float).SetInt(bytes)
	
	if bytes.Cmp(big.NewInt(unit)) < 0 {
		return fmt.Sprintf("%s B", bytes.String())
	}
	
	div := big.NewFloat(unit)
	exp := 0
	units := []string{"B", "KB", "MB", "GB", "TB", "PB"}
	
	for {
		next := new(big.Float).Quo(b, div)
		if next.Cmp(big.NewFloat(unit)) < 0 || exp >= len(units)-1 {
			break
		}
		b = next
		exp++
	}
	
	// Format with 2 decimal places
	f, _ := b.Float64()
	return fmt.Sprintf("%.2f %s", f, units[exp])
}

// Price Conversion Functions

// ConvertTBPerMonthToBytesPerEpoch converts price per TB per month to price per byte per epoch
func ConvertTBPerMonthToBytesPerEpoch(pricePerTBPerMonth *big.Int) *big.Int {
	// price per byte per epoch = price per TB per month / (BYTES_PER_TB * EPOCHS_PER_MONTH)
	denominator := new(big.Int).Mul(
		big.NewInt(BYTES_PER_TB),
		big.NewInt(EPOCHS_PER_MONTH),
	)
	
	result := new(big.Int).Div(pricePerTBPerMonth, denominator)
	return result
}

// ConvertBytesPerEpochToTBPerMonth converts price per byte per epoch to price per TB per month
func ConvertBytesPerEpochToTBPerMonth(pricePerBytePerEpoch *big.Int) *big.Int {
	// price per TB per month = price per byte per epoch * BYTES_PER_TB * EPOCHS_PER_MONTH
	result := new(big.Int).Mul(pricePerBytePerEpoch, big.NewInt(BYTES_PER_TB))
	result.Mul(result, big.NewInt(EPOCHS_PER_MONTH))
	return result
}

// ConvertUSDPerTBPerMonthToTokenUnits converts USD per TB per month to token units (USDC with 6 decimals)
func ConvertUSDPerTBPerMonthToTokenUnits(usdPriceStr string) (*big.Int, error) {
	// Parse the USD price as a float
	usdPrice := new(big.Float)
	_, ok := usdPrice.SetString(usdPriceStr)
	if !ok {
		return nil, fmt.Errorf("invalid USD price format: %s", usdPriceStr)
	}

	// Convert to token units (multiply by 10^USD_DECIMALS for USDC)
	decimalsMultiplier := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(USD_DECIMALS), nil))
	tokenUnits := new(big.Float).Mul(usdPrice, decimalsMultiplier)

	// Convert to big.Int
	result, _ := tokenUnits.Int(nil)
	return result, nil
}

// ConvertUSDPerTBPerMonthToBytesPerEpoch converts USD per TB per month to bytes per epoch in token units
func ConvertUSDPerTBPerMonthToBytesPerEpoch(usdPriceStr string) (*big.Int, error) {
	// First convert USD to token units (TB per month)
	pricePerTBPerMonth, err := ConvertUSDPerTBPerMonthToTokenUnits(usdPriceStr)
	if err != nil {
		return nil, err
	}

	// Then convert TB per month to bytes per epoch
	return ConvertTBPerMonthToBytesPerEpoch(pricePerTBPerMonth), nil
}

// ConvertTokenUnitsToUSD converts token units to USD (assuming USDC with 6 decimals)
func ConvertTokenUnitsToUSD(tokenUnits *big.Int) string {
	// Convert token units to float
	tokenFloat := new(big.Float).SetInt(tokenUnits)
	
	// Divide by 10^USD_DECIMALS
	decimalsMultiplier := new(big.Float).SetInt(new(big.Int).Exp(big.NewInt(10), big.NewInt(USD_DECIMALS), nil))
	usdFloat := new(big.Float).Quo(tokenFloat, decimalsMultiplier)
	
	// Format to 2 decimal places
	return fmt.Sprintf("%.2f", usdFloat)
}

// FormatPriceBothFormats formats a price in both TB per month and bytes per epoch formats
func FormatPriceBothFormats(pricePerBytePerEpoch *big.Int) string {
	pricePerTBPerMonth := ConvertBytesPerEpochToTBPerMonth(pricePerBytePerEpoch)
	usdPricePerTB := ConvertTokenUnitsToUSD(pricePerTBPerMonth)
	return fmt.Sprintf("$%s USD per TB per month (%s token units per byte per epoch)", 
		usdPricePerTB, 
		pricePerBytePerEpoch.String())
}

// FormatPriceWithUnit formats price with appropriate unit for display
func FormatPriceWithUnit(pricePerBytePerEpoch *big.Int, showBothFormats bool) string {
	if showBothFormats {
		return FormatPriceBothFormats(pricePerBytePerEpoch)
	}
	
	pricePerTBPerMonth := ConvertBytesPerEpochToTBPerMonth(pricePerBytePerEpoch)
	usdPricePerTB := ConvertTokenUnitsToUSD(pricePerTBPerMonth)
	return fmt.Sprintf("$%s USD per TB per month", usdPricePerTB)
} 