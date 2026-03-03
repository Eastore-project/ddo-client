# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DDO Client is a CLI + smart contract system for Decentralized Data Orchestration on Filecoin. It enables clients to create data allocations with storage providers, with an integrated payment rail system for automated streaming payments. The contracts use the Diamond proxy pattern (EIP-2535) for upgradeable, modular architecture.

## Build & Development Commands

### Go CLI
```bash
# Build the CLI binary
go build -ldflags="-s -w" -o ddo ./cmd/cli

# Run directly without building
go run ./cmd/cli <command>

# Tidy dependencies
go mod tidy
```

### Solidity Contracts (Foundry)
All Foundry commands must be run from the `contracts/` directory:
```bash
cd contracts

# Build contracts
forge build

# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run a specific test file
forge test --match-path test/diamond/DiamondAllocationTest.sol

# Run a specific test function
forge test --match-test testCreateAllocation

# Deploy Diamond (requires RPC_URL, PRIVATE_KEY, PAYMENTS_CONTRACT_ADDRESS env vars)
forge script script/DeployDiamond.s.sol \
  --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --skip-simulation --slow

```

## Architecture

### Two-Layer System
1. **Go CLI** (`cmd/cli/`, `internal/`) — User-facing CLI built with `urfave/cli/v2` that interacts with on-chain contracts via `go-ethereum`
2. **Solidity Contracts** (`contracts/src/`) — Diamond proxy (EIP-2535) deployed on Filecoin, built with Foundry

### Go CLI Structure
- **`cmd/cli/main.go`** — Entry point, registers top-level commands: `allocations`, `sp`, `payments`, `admin`, `approve-token`
- **`internal/commands/`** — CLI command implementations organized by domain (`allocations/`, `sp/`, `payments/`, `admin/`)
- **`internal/contract/ddo/`** — Go bindings for DDO Diamond contract (ABI string in `abi.go`, client wrapper in `client.go`)
- **`internal/contract/payments/`** — Go bindings for Payments contract (same pattern)
- **`internal/contract/token/`** — ERC20 token interactions
- **`internal/config/`** — Global config loaded from env vars (`RPC_URL`, `DDO_CONTRACT_ADDRESS`, `PAYMENTS_CONTRACT_ADDRESS`, `PRIVATE_KEY`)
- **`internal/curio/`** — Curio MK20 integration: deal submission (`client.go`), SP auto-discovery from on-chain multiaddrs (`discover.go`), address conversion (`address.go`), auth signing (`auth.go`)
- **`internal/types/`** — Shared Go types mirroring Solidity structs
- **`internal/utils/`** — Payment setup, cost calculation, formatting

### Contract Client Pattern
Both `ddo.Client` and `payments.Client` follow the same pattern:
- `NewClient()` — Full client with transaction auth (requires private key)
- `NewReadOnlyClient()` — Read-only, no private key needed
- `NewClientWithParams()` — Explicit parameters instead of global config
- Contract interaction uses `go-ethereum`'s `bind.BoundContract` with ABI strings hardcoded in `abi.go`

### Smart Contract Architecture (Diamond Pattern)
The DDO contract is a Diamond proxy where each function selector maps to a facet address:

- **`Diamond.sol`** — Proxy contract, delegates all calls to registered facets
- **`InitDiamond.sol`** — Initialization logic (payments contract, commission rate, lockup amount)
- **Facets** (`src/diamond/facets/`):
  - `AdminFacet.sol` — Owner-only config: set payments contract, commission, lockup, read constants
  - `AllocationFacet.sol` — Create allocations, settle payments, handle Filecoin actor callbacks (`handle_filecoin_method`)
  - `SPFacet.sol` — SP registration, pricing, token management, 17 selectors
  - `ViewFacet.sol` — Read-only queries: allocations, claims, deal verification (`getDealId`)
  - `ValidatorFacet.sol` — Payment validation logic
  - `DiamondCutFacet.sol` — `diamondCut()` for upgrade operations
  - `DiamondLoupeFacet.sol` — Diamond introspection
  - `OwnershipFacet.sol` — Ownership management
  - `MockAllocationFacet.sol` — Test variant with mock miner behavior
- **Libraries** (`src/diamond/libraries/`):
  - `LibDDOStorage.sol` — Diamond storage slot, all shared state, types, events, errors, constants
  - `LibDiamond.sol` — Diamond storage struct, internal cut logic, ownership
  - `VerifRegSerializationDiamond.sol` — CBOR serialization for VerifReg actor
- **Scripts** (`script/`):
  - `DeployDiamond.s.sol` — Full Diamond deployment with all facets
  - `DeployPayments.s.sol` — Payments contract deployment (UUPS proxy)

### Curio Integration
- `internal/curio/client.go` — MK20 API client: store deals, upload CAR files, finalize uploads
- `internal/curio/discover.go` — Auto-discovers SP's Curio API URL from on-chain multiaddrs (queries `Filecoin.StateMinerInfo`, parses multiaddr bytes). Falls back to extracting host:port from libp2p multiaddrs without explicit `/http` suffix.
- `internal/curio/address.go` — Ethereum-to-Filecoin delegated address conversion
- `internal/curio/auth.go` — Request signing for authenticated Curio endpoints
- `internal/curio/cidconv/` — Piece CID V1-to-V2 conversion for MK20

### Key Domain Concepts
- **Allocation**: A DataCap allocation linking a client's data piece to a storage provider, created via Filecoin's VerifReg actor
- **Rail**: A streaming payment channel between a client (payer) and SP (payee), operated by the DDO contract. Has a payment rate, lockup period, and optional validator.
- **Settlement**: Process of transferring accrued payments from client to SP based on elapsed epochs. The DDO contract acts as both operator and validator of rails.
- **Diamond Cut**: Atomic operation to add/replace/remove function selectors in the Diamond proxy. All changes happen in a single transaction.
- **Epochs**: Filecoin block time (~30 seconds). Constants: `EPOCHS_PER_DAY = 2880`, `EPOCHS_PER_MONTH = 86400`

### Contract Dependencies (git submodules)
- `filecoin-solidity` — Filecoin actor APIs (DataCap, VerifReg, Power)
- `filecoin-pay` — Payment rail system (FilecoinPayV1)
- `openzeppelin-contracts` / `openzeppelin-contracts-upgradeable` — Access control, proxy, reentrancy guard
- `forge-std` — Foundry test framework
- `buffer` — ENS buffer library

## Environment Variables
| Variable | Required | Description |
|---|---|---|
| `DDO_CONTRACT_ADDRESS` | Yes | DDO Diamond proxy address |
| `PRIVATE_KEY` | For transactions | Wallet private key (with or without 0x prefix) |
| `RPC_URL` | No (default: localhost:8545) | Filecoin RPC endpoint |
| `PAYMENTS_CONTRACT_ADDRESS` | For payment ops | Payments proxy contract address |

## Testing Notes
- Contract tests are in `contracts/test/diamond/` and use `MockAllocationFacet.sol` (test variant with mock miner behavior)
- `DiamondBaseTest.sol` provides shared test setup: deploys Diamond, registers facets, registers SPs, mints tokens
- Tests: `DiamondAllocationTest`, `DiamondSettlementTest`, `DiamondSPTest`
