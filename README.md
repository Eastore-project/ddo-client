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

<details open>
<summary><strong>Storage Provider 17840 Details</strong></summary>

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

</details>

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

<details>
<summary><strong>Expected Output</strong></summary>

```
📁 Preparing data from: /path/to/file
✅ Data prepared successfully!
   Piece CID: baga6ea4seaqbq6kvyhh3ezegcwkt66ew3c3ynudmklpzfiyxhl7e7pi6abpucha
   Piece Size: 33554432 bytes
   Payload CID: <payload_cid>
   CAR Size: 21310472 bytes
   Buffer URL: https://gateway.lighthouse.storage/ipfs/<cid>

🏗️  Allocation Creation Summary:
   Client Address: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
   DDO Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
   Payments Contract: 0x549a0cE5c649fF9c284f03F479e41E1Ed881F637
   RPC: https://api.calibration.node.glif.io/rpc/v1

📦 Prepared Piece:
   Provider: 17840
   Size: 33554432 bytes
   Payment Token: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0
   Download URL: https://gateway.lighthouse.storage/ipfs/<cid>

💰 Calculating storage costs...
📊 Cost Analysis:
   Total Storage Cost: 539233144012800
   Price: $2.94 USD per TB per month (31 token units per byte per epoch)
   Total Bytes: 33554432
   Total Epochs: 518400
   User Address: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30

🔧 Setting up payments...
💰 Payment Setup Summary:
   Token: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0
   Total Storage Cost: 539233144012800
   One Month Allowance: 89872190668800
   Required Deposit: 1078466288025600

📊 Current Account Status:
   Funds: 1336406084169267
   Lockup Current: 359490843049984
   Available: 976915241119283

⚠️  Insufficient funds. Need to deposit: 101551046906317
🔍 Checking ERC20 token allowance...
✅ Token allowance already sufficient
💸 Depositing 101551046906317 tokens...
✅ Deposit transaction sent: 0x7bf2ab7f2336b27a50d721617a0422a523b33d6b9e641ee4eace6bee6b310309
⏳ Waiting for deposit transaction to be mined...
⏳ Waiting for transaction 0x7bf2ab7f2336b27a50d721617a0422a523b33d6b9e641ee4eace6bee6b310309 to be mined...
✅ Transaction mined successfully
🔐 Operator Approval Status:
   Is Approved: true
   Rate Allowance: 3128688640
   Lockup Allowance: 537472106758144
   Rate Usage: 1040187392
   Lockup Usage: 359488762675200

🔧 Updating operator approval...
⏳ Waiting for operator approval transaction to be mined...
⏳ Waiting for transaction 0x51337aa1c9106f7a02a6e406490e0022ce234b8e1d1af5f42b7a8515cefc6ebf to be mined...
✅ Transaction mined successfully
✅ Operator approval transaction sent: 0x51337aa1c9106f7a02a6e406490e0022ce234b8e1d1af5f42b7a8515cefc6ebf
✅ Payment setup completed!

🚀 Creating allocation request...
DDO Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
Payments Contract: 0x549a0cE5c649fF9c284f03F479e41E1Ed881F637
RPC: https://api.calibration.node.glif.io/rpc/v1
✅ Transaction successful!
Transaction Hash: 0x82dcfff2c8e98796b2a1cddbe5fcf240489e68164fea90c65725b48dd81e3f8c
⏳ Waiting for allocation creation transaction to be mined...
⏳ Waiting for transaction 0x82dcfff2c8e98796b2a1cddbe5fcf240489e68164fea90c65725b48dd81e3f8c to be mined...
✅ Transaction mined successfully
✅ Allocation creation transaction mined successfully!
```

</details>

#### Step 4: Query Your Allocations

Verify your allocation was created successfully:

```bash
./ddo allocations query \
  --rpc $RPC_URL \
  --contract $DDO_CONTRACT_ADDRESS \
  --client-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
```

**Expected Output:**

<details open>
<summary><strong>Query Allocations Output</strong></summary>

```
Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
RPC: https://api.calibration.node.glif.io/rpc/v1

🔍 Querying allocations for client: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
📊 Results:
Total allocations: 1

Allocation IDs:
  1: 66655
```

</details>

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
  --claim-id 66655
```

Expected output:

<details open>
<summary><strong>Query Claim Info Output</strong></summary>

```
🔍 Querying claim info for allocation ID: 66655
Client: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
Claim ID: 66655
Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
RPC: https://api.calibration.node.glif.io/rpc/v1

📊 Results:
Found 1 claim(s)

Claim #1:
  Provider ID: 17840
  Client ID: 165718
  Data (hex): 000181e2039220209c8500b9be5a8b063c769eb331c42fd4b92320da30acc640eee35b2ce4dad621
  Piece CID: baga6ea4seaqjzbiaxg7fvcyghr3j5mzryqx5jojdedndblggidxogwzm4tnnmii
  Size: 33554432 bytes
  Term Min: 518400
  Term Max: 5256000
  Term Start: 2807249
  Sector ID: 577
```

</details>

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

<details open>
<summary><strong>Settlement Output</strong></summary>

```
Using current block number as until-epoch: 2818531
🔍 Getting SP information for provider 17840...
payments contract string is 0x549a0cE5c649fF9c284f03F479e41E1Ed881F637
Using provided payments contract address: 0x549a0cE5c649fF9c284f03F479e41E1Ed881F637
🏦 Settlement Parameters:
   User Address: 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
   DDO Contract: 0x5638917113653Ebe0B8dC0A874037088e9e297FA
   Payments Contract: 0x549a0cE5c649fF9c284f03F479e41E1Ed881F637
   Until Epoch: 2818531
   SP Payment Address: 0xFe643b54727d53C49835f9f6c1a2B9861E741d98
   SP Active Tokens: 1

📋 SP Supported Tokens:
   1. 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 - active (price: $2.94 USD per TB per month (31 token units per byte per epoch))

💰 Checking SP account information before settlement...
🔍 SP Account Info (Before) - 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0:
   Funds: 3146314318905
   Lockup Current: 0
   Lockup Rate: 0
   Lockup Last Settled At: 0

💰 Settling payment for allocation 66655 until epoch 2818531...
✅ Settlement transaction successful!
Transaction Hash: 0xa507cf0f02f180fc3e1e939307812cacd8564754b22d087ed72eab0a0ce5f494
⏳ Waiting for settlement transaction to be mined...
⏳ Waiting for transaction 0xa507cf0f02f180fc3e1e939307812cacd8564754b22d087ed72eab0a0ce5f494 to be mined...
✅ Transaction mined successfully
✅ Settlement transaction mined successfully

💰 Checking SP account information after settlement...
🔍 SP Account Info (After) - 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0:
   Funds: 11665040468578
   Lockup Current: 0
   Lockup Rate: 0
   Lockup Last Settled At: 0
```

</details>

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

<details open>
<summary><strong>Withdrawal Output</strong></summary>

```
💸 Withdrawal Process:
   Token: 0xb3042734b608a1B16e9e86B374A3f3e389B4cDf0 (USDFC)
   Amount: 0.15 USDC
   To Address: 0xFe643b54727d53C49835f9f6c1a2B9861E741d98

✅ Withdrawal successful!
   Transaction: 0x789abc...
```

</details>

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
