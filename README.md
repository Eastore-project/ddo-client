# DDO Client

Client software for **direct data onboarding on Filecoin** using smart contracts. This tool enables efficient data storage deals through blockchain-based automation, bypassing traditional market mechanisms for enhanced efficiency and cost savings.

## Overview

DDO (Decentralized Data Orchestration) Client provides a streamlined approach to Filecoin data onboarding through smart contract automation. It eliminates the complexity of traditional F05 market deals while providing customizable SLAs and automated payment processing.

## Key Features

- 🔧 **Customizable SLAs and logic** through smart contract configuration
- 💰 **Stablecoin and native payments** support for flexible payment options
- 🚀 **Monthly payment rails** directly between clients and storage providers
- ⛽ **Reduced gas costs** compared to traditional F05 market deals
- 🖥️ **Comprehensive CLI** for seamless interaction with the protocol
- 📋 **Automated deal management** with configurable terms and conditions
- 🔄 **Direct provider-client settlements** without intermediary market overhead

## Project Structure

This repository contains two main components:

### 1. Smart Contracts (`contracts/`)

Smart contracts implementing the DDO protocol with customizable deal logic, payment processing, and SLA enforcement. **Built with Foundry framework.**

### 2. CLI Tool (`internal/`)

Command-line interface for interacting with DDO contracts. **Full documentation available in [CLI_USAGE.md](CLI_USAGE.md)**.

```
.
├── contracts/           # Smart contract implementations
│   ├── src/            # Contract source files
│   ├── lib/            # Dependencies
│   └── foundry.toml    # Foundry configuration
├── internal/
│   ├── commands/       # CLI command implementations
│   ├── contract/       # Contract interaction logic
│   ├── config/         # Configuration management
│   ├── types/          # Type definitions
│   ├── token/          # Token handling utilities
│   └── utils/          # Helper utilities
├── cmd/cli/            # CLI application entry point
├── examples/           # Example input files
└── CLI_USAGE.md       # Complete CLI documentation
```

## Officially Deployed Contracts

### Filecoin Calibration Testnet

| Contract              | Address                                      | Description                       |
| --------------------- | -------------------------------------------- | --------------------------------- |
| **DDO Contract**      | `0x5638917113653Ebe0B8dC0A874037088e9e297FA` | Main data onboarding contract     |
| **Payments Contract** | `0x549a0cE5c649fF9c284f03F479e41E1Ed881F637` | Payment processing and settlement |

### Supported Tokens

| Token                      | Symbol  | Address                                      | Description                    |
| -------------------------- | ------- | -------------------------------------------- | ------------------------------ |
| **USD Coin (Calibration)** | `USDFC` | `0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0` | Calibration testnet stablecoin |

## Quick Start

### 1. Build the CLI

```bash
# Download dependencies
go mod tidy

# Build the CLI
go build -o ddo cmd/cli/main.go
```

### 2. Configure Environment

```bash
# Required configuration
export DDO_CONTRACT_ADDRESS="0x1234567890abcdef1234567890abcdef12345678"
export PAYMENTS_CONTRACT_ADDRESS="0xabcdef1234567890abcdef1234567890abcdef12"
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"

# Required for transactions
export PRIVATE_KEY="your_private_key_without_0x_prefix"
```

### 3. Basic Usage Examples

**Query storage providers:**

```bash
./ddo sp query --actor-id 17840
```

**Create data allocation:**

```bash
./ddo allocations create-from-file \
  --input ./my-data.txt \
  --provider 17840 \
  --payment-token 0x1234567890abcdef1234567890abcdef12345678 \
  --term-min 518400 \
  --term-max 1036800
```

**Check allocation status:**

```bash
./ddo allocations query --client-address 0xYourAddress
```

For complete CLI documentation, see **[CLI_USAGE.md](CLI_USAGE.md)**.

## Smart Contract Development

The smart contracts are built using the **Foundry framework** for robust development, testing, and deployment.

### Prerequisites for Contract Development

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Git for dependency management
- Access to Filecoin Calibration testnet RPC

### Initialize Contracts

```bash
# Navigate to contracts directory
cd contracts/

# Install Foundry dependencies
forge install

# Update dependencies (if needed)
forge update
```

### Build Contracts

```bash
# Compile all contracts
forge build

# Build with specific Solidity version
forge build --use 0.8.19
```

### Run Tests

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -v

# Run specific test file
forge test --match-path test/DDOClient.t.sol

# Run tests with gas reporting
forge test --gas-report

# Run tests with coverage
forge coverage
```

### Deploy to Calibration Testnet

```bash
# Set environment variables
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"
export PRIVATE_KEY="your_private_key_without_0x_prefix"

# Deploy contracts
forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast src/DDOClient.sol:DDOClient
```

### Contract Interaction

```bash
# Call read-only functions
cast call <CONTRACT_ADDRESS> "getAllocationIdsForClient(address)" <CLIENT_ADDRESS> --rpc-url $RPC_URL

# Send transactions
cast send <CONTRACT_ADDRESS> "createAllocationRequest(...)" <PARAMS> --private-key $PRIVATE_KEY --rpc-url $RPC_URL

```

### Development Workflow

1. **Write contracts** in `contracts/src/`
2. **Add tests** in `contracts/test/`
3. **Run tests** with `forge test`
4. **Deploy locally** for testing
5. **Deploy to testnet** when ready
6. **Update CLI** with new contract addresses

## Complete Deal Flow Process

This section provides a comprehensive guide for the end-to-end data onboarding process using DDO Client, from initial setup to deal completion and payment settlement.

### Prerequisites and Setup

#### 1. Environment Setup

First, set up your environment variables for the Filecoin Calibration testnet:

```bash
# Required configuration
export DDO_CONTRACT_ADDRESS="0x5638917113653Ebe0B8dC0A874037088e9e297FA"
export PAYMENTS_CONTRACT_ADDRESS="0x549a0cE5c649fF9c284f03F479e41E1Ed881F637"
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"

# Your private key (required for transactions)
export PRIVATE_KEY="your_private_key_without_0x_prefix"

# Buffer service configuration (for data preparation)
export LIGHTHOUSE_API_KEY="your_lighthouse_api_key"
export BUFFER_URL="https://gateway.lighthouse.storage/ipfs/"
```

#### 2. Build the CLI

```bash
# Clone and build the DDO client
git clone <repository-url>
cd ddo-client
go mod tidy
go build -o ddo cmd/cli/main.go
chmod +x ddo
```

#### 3. Get Testnet Tokens

You'll need both testnet FIL for gas fees and USDFC for storage payments:

**Get Testnet FIL:**

- Visit the [Filecoin Calibration Faucet](https://faucet.calibnet.chainsafe-fil.io/)
- Request testnet FIL tokens for your wallet address
- These tokens are used for transaction gas fees

**Get USDFC Tokens:**

- Visit the [USDFC Faucet](https://forest-explorer.chainsafe.dev/faucet/calibnet_usdfc)
- Request USDFC tokens for storage payments
- USDFC is the supported stablecoin for storage deals

### Storage Provider Information

For this tutorial, we'll use Storage Provider **17840** which offers the following specifications:

```
📋 Storage Provider Information
=====================================

🆔 Basic Information:
   Actor ID: 17840
   Payment Address: 0xFe643b54727d53C49835f9f6c1a2B9861E741d98
   Status: ✅ Active

📏 Capacity Limits:
   Min Piece Size: 1024.00 KB (1048576 bytes)
   Max Piece Size: 524288.00 KB (536870912 bytes)

⏰ Term Limits:
   Min Term: 86400 epochs (~30.0 days)
   Max Term: 5256000 epochs (~1825.0 days)

🪙 Supported Tokens (1 tokens):
   1. ✅ Active
      Token Address: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0
      Price: $2.94 USD per TB per month (31 token units per byte per epoch)
      Example Costs:
        1024.00 KB for 30 days: 0.00 USDC
        1024.00 KB for 180 days: 0.00 USDC
        1024.00 KB for 360 days: 0.00 USDC
```

### Step-by-Step Deal Creation Process

#### Step 1: Verify Storage Provider Information

First, query the storage provider to confirm their configuration:

```bash
./ddo sp query --actor-id 17840 -r $RPC_URL -c $DDO_CONTRACT_ADDRESS
```

This will display the storage provider's current configuration, pricing, and availability.

#### Step 2: Approve Payment Token (Optional)

Before creating deals, approve the USDFC token for the payments contract:

```bash
./ddo approve-token \
  --token 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 \
  --payments-contract $PAYMENTS_CONTRACT_ADDRESS \
  --rpc $RPC_URL \
  --private-key $PRIVATE_KEY \
  --unlimited
```

This one-time approval allows the payments contract to handle USDFC transfers for your deals.

#### Step 3: Create Data Allocation

Now create your data allocation using the `create-from-file` command. This command will:

- Prepare your data (create CAR files, calculate piece CIDs)
- Upload data to the buffer service (Lighthouse)
- Create the allocation request on-chain
- Initialize payment rails

```bash
./ddo allocations create-from-file \
  --rpc $RPC_URL \
  --contract $DDO_CONTRACT_ADDRESS \
  --payments-contract $PAYMENTS_CONTRACT_ADDRESS \
  --buffer-type lighthouse \
  --buffer-api-key $LIGHTHOUSE_API_KEY \
  --buffer-url $BUFFER_URL \
  --provider 17840 \
  --payment-token 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 \
  --input /path/to/your/file \
  --term-min 86400 \
  --term-max 518400 \
  --private-key $PRIVATE_KEY
```

**Alternative short form command:**

```bash
./ddo allocations cff \
  -r $RPC_URL \
  --buffer-type lighthouse \
  --buffer-api-key $LIGHTHOUSE_API_KEY \
  --buffer-url https://gateway.lighthouse.storage/ipfs/ \
  --provider 17840 \
  -c $DDO_CONTRACT_ADDRESS \
  --pc $PAYMENTS_CONTRACT_ADDRESS \
  --payment-token 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 \
  --input /path/to/file
```

**Expected Output:**

```
🔍 Data Preparation Starting...
📁 Processing file: /path/to/your/file
📦 Creating CAR file...
🔗 Calculating piece CID: baga6ea4seaq...
📊 Piece size: 8388608 bytes
☁️  Uploading to Lighthouse...
✅ Upload complete: https://gateway.lighthouse.storage/ipfs/QmXXX...

💰 Payment Setup:
   Token: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 (USDFC)
   Estimated cost: 0.00 USDC for 180 days
   Payment rail initialized
   .....

🚀 Creating allocation request...
✅ Allocation created successfully!
   Allocation ID: 65869
   Transaction: 0xabc123...
```

#### Step 4: Query Your Allocations

Verify your allocation was created successfully:

```bash
./ddo allocations query \
  --rpc $RPC_URL \
  --contract $DDO_CONTRACT_ADDRESS \
  --client-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
```

**Expected Output:**

```
Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
RPC: https://api.calibration.node.glif.io/rpc/v1

🔍 Querying allocations for client: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
📊 Results:
Total allocations: 1

Allocation IDs:
  1: 65869
```

### Storage Provider Data Onboarding

Once your allocation is created, the storage provider will:

1. **Listen for Events**: The storage provider runs [ddo-sp](https://github.com/eastore-project/ddo-sp) to monitor for new allocation events
2. **Download Data**: Retrieve your data from the buffer service (Lighthouse)
3. **Onboard Data**: Complete the data onboarding process using boost

This process can take few hours depending on data size and network conditions.

### Step 5: Monitor Deal Progress

Check if the storage provider has successfully onboarded your data:

```bash
./ddo allocations query-claim-info \
  --rpc $RPC_URL \
  --contract $DDO_CONTRACT_ADDRESS \
  --client-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30 \
  --claim-id 65869
```

### Payment Settlement Process

#### Step 6: Settle Payments

Anyone can trigger payment settlement for active deals. This transfers earned payments from the client to the storage provider:

```bash
./ddo sp settle \
  --rpc $RPC_URL \
  --contract $DDO_CONTRACT_ADDRESS \
  --payments-contract $PAYMENTS_CONTRACT_ADDRESS \
  --provider 17840 \
  --allocation-id 65869 \
  --until-epoch 2550000 \
  --private-key $PRIVATE_KEY
```

**Example Output:**

```
🔄 Settlement Process Starting...
📊 Calculating payments for allocation 65869
⏰ Settlement period: epochs 2500000 to 2550000
💰 SP balance before settlement: 0.00 USDC
✅ Settlement completed!
   Transaction: 0xdef456...
   SP earned: 0.15 USDC
```

#### Step 7: Storage Provider Withdrawal

The storage provider can withdraw their earned payments using their registered payment address:

```bash
./ddo payments withdraw \
  --rpc $RPC_URL \
  --payments-contract $PAYMENTS_CONTRACT_ADDRESS \
  --token 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 \
  --amount 150000 \
  --private-key $SP_PRIVATE_KEY
```

**Expected Output:**

```
💸 Withdrawal Process:
   Token: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 (USDFC)
   Amount: 0.15 USDC
   To Address: 0xFe643b54727d53C49835f9f6c1a2B9861E741d98

✅ Withdrawal successful!
   Transaction: 0x789abc...
```

### Deal Lifecycle Summary

1. **Setup** (5 mins): Configure environment, get testnet tokens, build CLI
2. **Approval** (1 transaction): Approve USDFC for payments contract
3. **Data Preparation** (2-5 mins): Create CAR files, upload to buffer service
4. **Allocation Creation** (1 transaction): Create on-chain allocation request
5. **SP Onboarding** (15-30 mins): Storage provider downloads and onboards data
6. **Monitoring** (ongoing): Query deal status and claim information
7. **Settlement** (periodic): Settle payments based on storage duration
8. **Withdrawal** (as needed): Storage provider withdraws earned payments

### Key Benefits of DDO vs Traditional F05

- **🔄 Automated Payments**: Monthly payment rails eliminate manual deal renewals
- **⛽ Lower Gas Costs**: Batch operations and optimized smart contracts reduce fees
- **🎯 Customizable SLAs**: Configure terms, pricing, and conditions per storage provider
- **💰 Stablecoin Support**: Use USDFC for predictable pricing instead of volatile FIL
- **🚀 Direct Settlement**: No intermediary market overhead or complex deal negotiations

This completes the full end-to-end process for direct data onboarding using DDO Client!

## Development

### Prerequisites

- Go 1.22+
- Foundry (for smart contract development)
- Access to Filecoin Calibration testnet
- Private key for transaction operations

### Architecture

The CLI is designed with a modular architecture for easy extension:

- **Commands** - Individual CLI command implementations
- **Contract** - Smart contract interaction logic
- **Config** - Environment and configuration management
- **Types** - Shared data structures
- **Utils** - Common utilities and helpers

### Adding New Features

1. **Add CLI commands** in `internal/commands/`
2. **Extend contract functions** in `internal/contract/`
3. **Update types** in `internal/types/` if needed
4. **Register commands** in `cmd/cli/main.go`

## Documentation

- **[CLI_USAGE.md](CLI_USAGE.md)** - Complete CLI command reference
- **Contract Documentation** - Available in `contracts/` directory
- **Examples** - Sample configurations in `examples/` directory

## Support

For issues, questions, or contributions, please refer to the project's issue tracker or documentation.
