# DDO Client CLI Usage Guide

A comprehensive command-line interface for interacting with DDO (Decentralized Data Orchestration) smart contracts on the Filecoin network.

## Table of Contents

- [Installation](#installation)
- [Environment Variables](#environment-variables)
- [Global Flags](#global-flags)
- [Commands Overview](#commands-overview)
- [Allocation Commands](#allocation-commands)
- [Storage Provider Commands](#storage-provider-commands)
- [Payments Commands](#payments-commands)
- [Token Approval Commands](#token-approval-commands)
- [Usage Examples](#usage-examples)
- [Error Handling](#error-handling)

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd ddo-client

# Build the CLI
go mod tidy
go build -o ddo cmd/cli/main.go

# Make executable (Linux/macOS)
chmod +x ddo
```

## Environment Variables

The CLI uses environment variables for configuration, which can be overridden with command-line flags.

### Required Variables

| Variable | Description | Required For | Example |
|----------|-------------|--------------|---------|
| `DDO_CONTRACT_ADDRESS` | DDO smart contract address | All commands | `0x1234567890abcdef...` |
| `PRIVATE_KEY` | Private key for transactions | Transaction commands only | `abcdef123456...` (without 0x prefix) |

### Optional Variables

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `RPC_URL` | `http://localhost:8545` | RPC endpoint URL | `https://api.calibration.node.glif.io/rpc/v1` |
| `PAYMENTS_CONTRACT_ADDRESS` | - | Payments contract address | `0xabcdef1234567890...` |

### Setting Environment Variables

```bash
# Required for all operations
export DDO_CONTRACT_ADDRESS="0x1234567890abcdef1234567890abcdef12345678"

# Required for transactions (not needed for read-only queries)
export PRIVATE_KEY="your_private_key_without_0x_prefix"

# Optional - specify RPC endpoint
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"

# Optional - specify payments contract (if different from default)
export PAYMENTS_CONTRACT_ADDRESS="0xabcdef1234567890abcdef1234567890abcdef12"
```

## Global Flags

Available for all commands:

| Flag | Short | Description | Example |
|------|-------|-------------|---------|
| `--verbose` | `-v` | Show verbose output including configuration | `ddo -v <command>` |
| `--help` | `-h` | Show help information | `ddo --help` |

## Commands Overview

| Command | Purpose | Private Key Required | Description |
|---------|---------|---------------------|-------------|
| `allocations` | Allocation management | ✅ (for create) | Create and query data allocations |
| `sp` | Storage provider management | ✅ (for register/update) | Manage storage provider configurations |
| `payments` | Payment management | ✅ (for transactions) | Handle payment operations and queries |
| `approve-token` | Token approval | ✅ | Approve ERC20 tokens for payments contract |

## Allocation Commands

### `allocations` (alias: `alloc`)

Manage data allocations on the DDO network.

#### Subcommands

##### `allocations query` (alias: `q`)
Query existing allocations for a client address.

```bash
ddo allocations query --client-address <ADDRESS> [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--client-address, -a`: Client address to query (required)
- `--json`: Output in JSON format

**Example:**
```bash
ddo alloc query --client-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30 --json
```

##### `allocations create` (alias: `c`)
Create new allocations from piece information.

```bash
ddo allocations create [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--payments-contract, -pc`: Override payments contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--input-file, -f`: JSON file with piece information
- `--piece-cid`: Piece CID (if not using file)
- `--piece-size`: Piece size in bytes (if not using file)
- `--provider`: Storage provider actor ID (if not using file)
- `--term-min`: Minimum term in epochs (if not using file)
- `--term-max`: Maximum term in epochs (if not using file)
- `--download-url`: Download URL for the piece
- `--payment-token`: Payment token address (required)
- `--dry-run`: Calculate costs without sending transaction
- `--skip-payment-setup`: Skip payment setup (use with caution)

**Example:**
```bash
ddo alloc create \
  --piece-cid "baga6ea4seaqhpxa6yyafiw4irpaikk3o256l2smmiavkffkvykztotukpqheqfq" \
  --piece-size 8388608 \
  --provider 17840 \
  --term-min 518400 \
  --term-max 5256000 \
  --payment-token 0x1234567890abcdef1234567890abcdef12345678 \
  --dry-run
```

##### `allocations create-from-file` (alias: `cf`)
Create allocations from files or directories.

```bash
ddo allocations create-from-file --input <PATH> [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--payments-contract, -pc`: Override payments contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--input, -i`: Input file or directory path (required)
- `--provider, -p`: Storage provider actor ID (required)
- `--term-min`: Minimum term in epochs (required)
- `--term-max`: Maximum term in epochs (required)
- `--payment-token`: Payment token address (required)
- `--buffer-service`: Buffer service type (lighthouse, local)
- `--buffer-api-key`: Buffer API key (required for lighthouse)
    can be set as env variable `BUFFER_API_KEY`
- `--buffer-url`: Buffer url prefix (like for lighthouse it is https://gateway.lighthouse.storage/ipfs/)
    can be set as env variable `BUFFER_URL`
- `--dry-run`: Calculate costs without sending transaction
- `--skip-payment-setup`: Skip payment setup

**Example:**
```bash
ddo alloc create-from-file \
  --input ./my-data.txt \
  --provider 17840 \
  --term-min 518400 \
  --term-max 5256000 \
  --payment-token 0x1234567890abcdef1234567890abcdef12345678 \
  --buffer-service lighthouse
```

##### `allocations query-claim-info` (alias: `qci`)
Query claim information for specific client and claim ID.

```bash
ddo allocations query-claim-info --client-address <ADDRESS> --claim-id <ID> [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--client-address, -a`: Client address (required)
- `--claim-id, -id`: Claim ID (required)
- `--json`: Output in JSON format

## Storage Provider Commands

### `sp` (alias: `storage-provider`)

Manage storage provider configurations and operations.

#### Subcommands

##### `sp register` (alias: `reg`)
Register a new storage provider.

```bash
ddo sp register [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--actor-id, -id`: Filecoin actor ID (required)
- `--payment-address, -pa`: Payment address (required)
- `--min-piece-size, -min-size`: Minimum piece size (default: 128 bytes)
- `--max-piece-size, -max-size`: Maximum piece size (default: 32GB)
- `--min-term, -mt`: Minimum term in epochs (default: 86400)
- `--max-term, -Mt`: Maximum term in epochs (default: 5256000)
- `--tokens, -t`: Token configurations (required, repeatable)
- `--tokens-file`: JSON file with token configurations
- `--dry-run`: Show configuration without transaction

**Token Configuration Format:**
```
--tokens "TOKEN_ADDRESS:PRICE_USD_PER_TB_PER_MONTH"
```

**Example:**
```bash
ddo sp register \
  --actor-id 17840 \
  --payment-address 0x1234567890abcdef1234567890abcdef12345678 \
  --min-piece-size 1024 \
  --max-piece-size 34359738368 \
  --tokens "0xTokenAddress:10.50" \
  --tokens "0xAnotherToken:15.25" \
  --dry-run
```

##### `sp update`
Update storage provider configuration.

###### `sp update config` (alias: `cfg`)
Update basic storage provider configuration.

```bash
ddo sp update config [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--actor-id, -id`: Storage provider actor ID (required)
- `--payment-address, -pa`: Payment address (required)
- `--min-piece-size, -min-size`: Minimum piece size
- `--max-piece-size, -max-size`: Maximum piece size
- `--min-term, -mt`: Minimum term in epochs
- `--max-term, -Mt`: Maximum term in epochs
- `--dry-run`: Show what would be updated

###### `sp update token` (alias: `tok`)
Update existing token configuration.

```bash
ddo sp update token [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--actor-id, -id`: Storage provider actor ID (required)
- `--token, -t`: Token address (required)
- `--price, -p`: Price in USD per TB per month (required)
- `--active`: Set token as active (default: true)
- `--inactive`: Set token as inactive
- `--dry-run`: Show what would be updated

###### `sp update add-token` (alias: `add`)
Add new token configuration.

```bash
ddo sp update add-token [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--actor-id, -id`: Storage provider actor ID (required)
- `--token, -t`: Token address (required)
- `--price, -p`: Price in USD per TB per month (required)
- `--dry-run`: Show what would be added

##### `sp query` (alias: `q`)
Query storage provider information.

```bash
ddo sp query --actor-id <ID> [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--rpc, -r`: Override RPC endpoint
- `--actor-id, -id`: Storage provider actor ID (required)
- `--json`: Output in JSON format

##### `sp settle` (alias: `settlement`)
Settle storage provider payments.

```bash
ddo sp settle [flags]
```

**Flags:**
- `--contract, -c`: Override DDO contract address
- `--payments-contract, -pc`: Override payments contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--provider, -p`: Storage provider ID (required if allocation-id not specified)
- `--allocation-id, -a`: Specific allocation ID to settle
- `--until-epoch, -e`: Epoch until which to settle
- `--dry-run`: Show what would be settled

## Payments Commands

### `payments` (alias: `pay`)

Manage payment operations and queries.

#### Query Subcommands

##### `payments contract-info` (alias: `info`)
Show contract basic information.

```bash
ddo payments contract-info [flags]
```

##### `payments account` (alias: `acc`)
Query account information.

```bash
ddo payments account --token <ADDRESS> --address <ADDRESS> [flags]
```

**Flags:**
- `--token, -t`: Token address (required)
- `--address, -a`: Account address (required)

##### `payments operator-approval` (alias: `op`, `approval`)
Query operator approval information.

```bash
ddo payments operator-approval --token <ADDRESS> --account <ADDRESS> --operator <ADDRESS> [flags]
```

**Flags:**
- `--token, -t`: Token address (required)
- `--account, -a`: Account address (required)
- `--operator, -o`: Operator address (required)

##### `payments rail` (alias: `r`)
Query rail information by rail ID.

```bash
ddo payments rail --rail-id <ID> [flags]
```

**Flags:**
- `--rail-id, -id`: Rail ID (required)

##### `payments accumulated-fees` (alias: `fees`)
Query accumulated fees for a token.

```bash
ddo payments accumulated-fees --token <ADDRESS> [flags]
```

**Flags:**
- `--token, -t`: Token address (required)

##### `payments all-accounts` (alias: `all`)
Query all accounts with accumulated fees.

```bash
ddo payments all-accounts [flags]
```

#### Transaction Subcommands

##### `payments set-operator-allowance` (alias: `soa`, `set-allowance`)
Set or update operator approval and allowances.

```bash
ddo payments set-operator-allowance --token <ADDRESS> --operator <ADDRESS> [flags]
```

**Flags:**
- `--token, -t`: Token address (required)
- `--operator, -o`: Operator address (required)
- `--approved`: Whether operator is approved (default: true)
- `--rate-allowance, -ra`: Maximum payment rate operator can set
- `--lockup-allowance, -la`: Maximum lockup amount
- `--max-lockup-period, -mlp`: Maximum lockup period in epochs
- `--unlimited`: Set unlimited allowances
- `--check-only`: Only check current approval

##### `payments withdraw`
Withdraw funds from payment account.

```bash
ddo payments withdraw [flags]
```

**Common Payment Flags:**
- `--payments-contract, -pc`: Override payments contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key

## Token Approval Commands

### `approve-token` (alias: `at`)

Check and approve ERC20 token allowance for the payments contract.

```bash
ddo approve-token --token <ADDRESS> [flags]
```

**Flags:**
- `--payments-contract, -pc`: Override payments contract address
- `--rpc, -r`: Override RPC endpoint
- `--private-key, -pk`: Override private key
- `--token, -t`: ERC20 token contract address (required)
- `--amount, -a`: Amount to approve
- `--check-only`: Only check current allowance
- `--unlimited`: Approve unlimited amount

**Example:**
```bash
# Check current allowance
ddo approve-token --token 0x1234567890abcdef1234567890abcdef12345678 --check-only

# Approve unlimited amount
ddo approve-token --token 0x1234567890abcdef1234567890abcdef12345678 --unlimited

# Approve specific amount
ddo approve-token --token 0x1234567890abcdef1234567890abcdef12345678 --amount 1000000000000000000
```

## Usage Examples

### Complete Workflow Examples

#### 1. Storage Provider Registration

```bash
# Set environment variables
export DDO_CONTRACT_ADDRESS="0x1234567890abcdef1234567890abcdef12345678"
export PRIVATE_KEY="your_private_key_without_0x_prefix"
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"

# Register storage provider
ddo sp register \
  --actor-id 17840 \
  --payment-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30 \
  --min-piece-size 1024 \
  --max-piece-size 34359738368 \
  --min-term 518400 \
  --max-term 5256000 \
  --tokens "0xTokenAddress1:10.50" \
  --tokens "0xTokenAddress2:15.25"

# Query registered storage provider
ddo sp query --actor-id 17840 --json
```

#### 2. Client Data Allocation

```bash
# Set environment variables
export DDO_CONTRACT_ADDRESS="0x1234567890abcdef1234567890abcdef12345678"
export PRIVATE_KEY="client_private_key_without_0x_prefix"
export PAYMENTS_CONTRACT_ADDRESS="0xabcdef1234567890abcdef1234567890abcdef12"

# Approve token for payments (one-time setup)
ddo approve-token \
  --token 0xTokenAddress1 \
  --unlimited

# Create allocation from file (dry run first)
ddo alloc create-from-file \
  --input ./my-dataset.tar \
  --provider 17840 \
  --term-min 518400 \
  --term-max 1036800 \
  --payment-token 0xTokenAddress1 \
  --dry-run

# Execute actual allocation creation
ddo alloc create-from-file \
  --input ./my-dataset.tar \
  --provider 17840 \
  --term-min 518400 \
  --term-max 1036800 \
  --payment-token 0xTokenAddress1

# Query created allocations
ddo alloc query --client-address 0xClientAddress --json
```

#### 3. Payment Management

```bash
# Query account balance
ddo payments account \
  --token 0xTokenAddress1 \
  --address 0xClientAddress

# Set operator allowance
ddo payments set-operator-allowance \
  --token 0xTokenAddress1 \
  --operator 0xOperatorAddress \
  --rate-allowance 1000000000000000000 \
  --lockup-allowance 5000000000000000000

# Query operator approval
ddo payments operator-approval \
  --token 0xTokenAddress1 \
  --account 0xClientAddress \
  --operator 0xOperatorAddress
```

#### 4. Settlement Operations

```bash
# Settle payments for specific provider
ddo sp settle \
  --provider 17840 \
  --until-epoch 2500000 \
  --dry-run

# Settle specific allocation
ddo sp settle \
  --allocation-id 123 \
  --dry-run
```

### JSON Input File Examples

#### Piece Information File (`pieces.json`):
```json
{
  "pieces": [
    {
      "piece_cid": "baga6ea4seaqhpxa6yyafiw4irpaikk3o256l2smmiavkffkvykztotukpqheqfq",
      "piece_size": 8388608,
      "provider": 17840,
      "term_min": 518400,
      "term_max": 5256000,
      "download_url": "https://example.com/data.tar"
    }
  ]
}
```

#### Token Configuration File (`tokens.json`):
```json
{
  "tokens": [
    {
      "token": "0x1234567890abcdef1234567890abcdef12345678",
      "priceUSDPerTBPerMonth": "10.50",
      "isActive": true
    },
    {
      "token": "0xabcdef1234567890abcdef1234567890abcdef12",
      "priceUSDPerTBPerMonth": "15.25",
      "isActive": true
    }
  ]
}
```

## Error Handling

### Common Error Messages

1. **Missing Configuration**:
   ```
   Error: missing required configuration: DDO_CONTRACT_ADDRESS or --contract flag
   ```
   **Solution**: Set the `DDO_CONTRACT_ADDRESS` environment variable or use `--contract` flag.

2. **Invalid Address**:
   ```
   Error: invalid payment address: 0xinvalid
   ```
   **Solution**: Ensure addresses are valid Ethereum addresses starting with `0x`.

3. **Insufficient Allowance**:
   ```
   Error: insufficient token allowance
   ```
   **Solution**: Use `approve-token` command to approve tokens for the payments contract.

4. **Private Key Required**:
   ```
   Error: private key required for transaction commands
   ```
   **Solution**: Set `PRIVATE_KEY` environment variable or use `--private-key` flag.

### Debug Tips

1. **Use Verbose Mode**: Add `-v` flag to see detailed configuration information.
2. **Use Dry Run**: Add `--dry-run` flag to preview operations without executing them.
3. **Check Only Mode**: Use `--check-only` for read-only verification of current state.
4. **JSON Output**: Use `--json` flag for machine-readable output in query commands.

### Network Configuration

Different networks require different RPC endpoints:

```bash
# Filecoin Mainnet
export RPC_URL="https://api.node.glif.io/rpc/v1"

# Filecoin Calibration Testnet
export RPC_URL="https://api.calibration.node.glif.io/rpc/v1"

# Local node
export RPC_URL="http://localhost:8545"
```

## Command Reference Summary

| Command | Read-Only | Transaction | Key Required |
|---------|-----------|-------------|--------------|
| `alloc query` | ✅ | ❌ | ❌ |
| `alloc create` | ❌ | ✅ | ✅ |
| `alloc create-from-file` | ❌ | ✅ | ✅ |
| `alloc query-claim-info` | ✅ | ❌ | ❌ |
| `sp query` | ✅ | ❌ | ❌ |
| `sp register` | ❌ | ✅ | ✅ |
| `sp update` | ❌ | ✅ | ✅ |
| `sp settle` | ❌ | ✅ | ✅ |
| `payments query *` | ✅ | ❌ | ❌ |
| `payments set-operator-allowance` | ❌ | ✅ | ✅ |
| `payments withdraw` | ❌ | ✅ | ✅ |
| `approve-token` | ❌ | ✅ | ✅ |

---

For additional help with any command, use:
```bash
ddo <command> --help
ddo <command> <subcommand> --help
```
