# DDO Client

A command-line interface for interacting with DDO (Distributed Data Objects) smart contracts on Filecoin. This tool enables direct data onboarding through smart contracts with customizable allocation requests and comprehensive query capabilities.

## Project Structure

```
.
├── cmd/cli/              # Go CLI application entry point
├── internal/
│   ├── config/          # Configuration management
│   ├── contract/        # Contract interaction logic
│   │   ├── client.go    # Contract client setup
│   │   ├── abi.go       # Contract ABI definitions
│   │   ├── allocation_requests.go  # Create allocation functions
│   │   └── allocation_queries.go   # Query allocation functions
│   ├── commands/        # CLI command implementations
│   │   ├── create_allocation.go           # Manual allocation creation
│   │   ├── create_allocation_from_files.go # File-based allocation creation
│   │   └── query_allocations.go           # Allocation queries
│   └── types/           # Go structs matching Solidity types
├── contracts/
│   ├── lib/             # Smart contract dependencies
│   ├── src/             # Smart contract source files
│   │   ├── DDOClient.sol    # Main contract
│   │   └── DDOTypes.sol     # Contract types and events
│   └── foundry.toml     # Foundry configuration
├── examples/            # Example input files
├── scripts/             # Build and deployment scripts
├── CLI.md              # Detailed CLI documentation
└── go.mod              # Go module configuration
```

## Features

- ✅ **Create allocation requests** with single or bulk operations
- ✅ **Create allocations from files/folders** with automatic data preparation
- ✅ **Query allocation IDs** for any client address (read-only)
- ✅ **Environment-based configuration** with command-line overrides
- ✅ **Dry-run mode** for DataCap calculation without transactions
- ✅ **JSON input support** for bulk operations
- ✅ **Buffer service integration** (lighthouse, local)
- ✅ **Read-only operations** (no private key needed for queries)
- ✅ **Comprehensive error handling** and validation
- ✅ **Extensible architecture** for future commands

## Quick Start

### 1. Build the CLI
```bash
# Download dependencies
go mod tidy

# Build the CLI
chmod +x scripts/build.sh
./scripts/build.sh
```

### 2. Configure Environment
```bash
# Required for transaction operations
export DDO_CONTRACT_ADDRESS="0x1234567890abcdef1234567890abcdef12345678"
export PRIVATE_KEY="your_private_key_without_0x_prefix"

# Optional (defaults to localhost:8545)
export RPC_ENDPOINT="https://api.calibration.node.glif.io/rpc/v1"
```

### 3. Available Commands

**View all commands:**
```bash
./ddo --help
```

**Query allocations (read-only, no private key needed):**
```bash
./ddo query-allocations --client-address 0x1234567890abcdef1234567890abcdef12345678
```

**Create allocations from pre-calculated data:**
```bash
./ddo create-allocations --input-file examples/piece_infos.json
```

**Create allocations from files/folders:**
```bash
./ddo create-from-files --input ./my-data.txt --provider 17840
```

### 4. Example Workflows

**Check existing allocations:**
```bash
./ddo query-allocations --client-address 0x9299eac94952235Ae86b94122D2f7c77F7F6Ad30
```

**Create allocation from file:**
```bash
# Dry run first
./ddo create-from-files --input ./data.txt --provider 17840 --dry-run

# Execute for real
./ddo create-from-files --input ./data.txt --provider 17840
```

**Create allocation from existing piece data:**
```bash
./ddo create-allocations \
  --piece-cid "baga6ea4seaqhpxa6yyafiw4irpaikk3o256l2smmiavkffkvykztotukpqheqfq" \
  --size 8388608 \
  --provider 17840 \
  --term-min 518400 \
  --term-max 5256000
```

## Commands Overview

| Command | Purpose | Private Key Required | Input |
|---------|---------|---------------------|-------|
| `create-allocations` | Create from known piece data | ✅ | JSON file or CLI flags |
| `create-from-files` | Create from raw files/folders | ✅ | File/folder path |
| `query-allocations` | Query allocation IDs | ❌ | Client address |

## Documentation

All CLI usage, examples, and troubleshooting information is contained in this README. No separate documentation files are needed.

## Environment Variables

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `DDO_CONTRACT_ADDRESS` | - | ✅ | Contract address |
| `PRIVATE_KEY` | - | For transactions | Private key (without 0x prefix) |
| `RPC_ENDPOINT` | `http://localhost:8545` | ❌ | RPC endpoint URL |

**Note:** Query operations only require `DDO_CONTRACT_ADDRESS` and `RPC_ENDPOINT`.

## Development

### Adding New Commands

The architecture is designed for easy extension:

1. **Create command file** in `internal/commands/`
2. **Add contract method** in `internal/contract/` (choose appropriate file)
3. **Update ABI** in `internal/contract/abi.go` if needed
4. **Register command** in `cmd/cli/main.go`

Example:
```go
// internal/commands/new_command.go
func NewCommand() *cli.Command {
    return &cli.Command{
        Name:    "new-command",
        Usage:   "Description of command",
        Action:  executeNewCommand,
    }
}
```

### Contract Integration Files

- **`client.go`** - Client setup, connection management
- **`abi.go`** - Contract ABI definitions
- **`allocation_requests.go`** - Functions for creating allocations
- **`allocation_queries.go`** - Functions for querying allocations

### Prerequisites

- Go 1.22+
- Access to Filecoin RPC endpoint
- Smart contract deployed on target network
- Private key for transaction operations (not needed for queries)

## Contract Functions Supported

### Write Operations (require private key)
- ✅ `createAllocationRequests(PieceInfo[] memory pieceInfos)`
- ✅ `createSingleAllocationRequest(...)`
- ✅ `calculateTotalDataCap(PieceInfo[] memory pieceInfos)` (view function)

### Read Operations (no private key needed)
- ✅ `getAllocationIdsForClient(address clientAddress)`
- ✅ `getAllocationCountForClient(address clientAddress)`

### Future Additions
- 🔄 `getClaimInfo`, `transfer`, claim management, etc.

## Data Preparation Integration

The CLI integrates with the `fildeal` data preparation utilities for automatic:
- **CAR file generation** from raw files/folders
- **Piece CID calculation** 
- **Buffer service upload** (lighthouse, local)
- **Metadata extraction** (piece size, payload CID)

## Troubleshooting

Common issues and solutions are documented in [CLI.md](CLI.md#troubleshooting).

**Quick debug commands:**
```bash
# Verbose mode with dry run
./ddo --verbose create-allocations --dry-run --input-file examples/piece_infos.json

# Test connectivity with read-only query
./ddo query-allocations --client-address 0x1234... --count-only

# Validate file preparation
./ddo create-from-files --input ./test.txt --provider 17840 --dry-run
```
