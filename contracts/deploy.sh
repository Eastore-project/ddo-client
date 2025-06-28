#!/bin/bash

set -e  # Exit on any error

echo "Starting contract deployment..."

# Simple environment variable checks
if [ -z "$RPC_URL_LOCAL" ]; then
    echo "Error: RPC_URL_LOCAL environment variable is not set"
    echo "Please set it with: export RPC_URL_LOCAL=your_rpc_url"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable is not set"
    echo "Please set it with: export PRIVATE_KEY=your_private_key"
    exit 1
fi

echo "Environment variables configured successfully."
echo "Using RPC: $RPC_URL_LOCAL"

# Deploy DDOClient contract
echo "Deploying DDOClient contract..."
DDO_OUTPUT=$(forge create src/DDOClient.sol:DDOClient --rpc-url $RPC_URL_LOCAL --private-key $PRIVATE_KEY --broadcast)
DDO_ADDRESS=$(echo "$DDO_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
if [ -z "$DDO_ADDRESS" ]; then
    echo "Failed to extract DDOClient address"
    echo "Deploy output: $DDO_OUTPUT"
    exit 1
fi
echo "DDOClient deployed to: $DDO_ADDRESS"
echo "Waiting 7 seconds for transaction to be processed..."
sleep 7

# Deploy SimpleERC20 contract
echo "Deploying SimpleERC20 contract..."
ERC20_OUTPUT=$(forge create --rpc-url $RPC_URL_LOCAL --private-key $PRIVATE_KEY --broadcast src/SimpleERC20.sol:SimpleERC20)
ERC20_ADDRESS=$(echo "$ERC20_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
if [ -z "$ERC20_ADDRESS" ]; then
    echo "Failed to extract SimpleERC20 address"
    echo "Deploy output: $ERC20_OUTPUT"
    exit 1
fi
echo "SimpleERC20 deployed to: $ERC20_ADDRESS"
echo "Waiting 7 seconds for transaction to be processed..."
sleep 7

# Deploy Payments contract
echo "Deploying Payments contract..."
PAYMENTS_OUTPUT=$(forge create src/Payments.sol:Payments --rpc-url $RPC_URL_LOCAL --private-key $PRIVATE_KEY --broadcast)
PAYMENTS_ADDRESS=$(echo "$PAYMENTS_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
if [ -z "$PAYMENTS_ADDRESS" ]; then
    echo "Failed to extract Payments address"
    echo "Deploy output: $PAYMENTS_OUTPUT"
    exit 1
fi
echo "Payments deployed to: $PAYMENTS_ADDRESS"
echo "Waiting 7 seconds for transaction to be processed..."
sleep 7

# Deploy PaymentsERC1967Proxy contract
echo "Deploying PaymentsERC1967Proxy contract..."
PROXY_OUTPUT=$(forge create --rpc-url $RPC_URL_LOCAL --private-key $PRIVATE_KEY --broadcast src/ERC1967Proxy.sol:PaymentsERC1967Proxy --constructor-args $PAYMENTS_ADDRESS 0x8129fc1c)
PROXY_ADDRESS=$(echo "$PROXY_OUTPUT" | grep "Deployed to:" | awk '{print $3}')
if [ -z "$PROXY_ADDRESS" ]; then
    echo "Failed to extract PaymentsERC1967Proxy address"
    echo "Deploy output: $PROXY_OUTPUT"
    exit 1
fi
echo "PaymentsERC1967Proxy deployed to: $PROXY_ADDRESS"
echo "Waiting 7 seconds for transaction to be processed..."
sleep 7

# Set payments contract address
echo "Setting payments contract address..."
CAST_OUTPUT=$(cast send $DDO_ADDRESS "setPaymentsContract(address)" $PROXY_ADDRESS --rpc-url $RPC_URL_LOCAL --private-key $PRIVATE_KEY)
echo "Transaction sent: $CAST_OUTPUT"

echo ""
echo "🎉 Deployment completed successfully!"
echo "📋 Contract addresses:"
echo "  DDOClient: $DDO_ADDRESS"
echo "  SimpleERC20: $ERC20_ADDRESS"
echo "  Payments: $PAYMENTS_ADDRESS"
echo "  PaymentsERC1967Proxy: $PROXY_ADDRESS"
echo ""
echo "💡 Save these addresses to your environment:"
echo "export DDO_CONTRACT_ADDRESS=$DDO_ADDRESS"
echo "export PAYMENTS_CONTRACT_ADDRESS=$PROXY_ADDRESS" 