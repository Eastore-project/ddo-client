# DDO Contracts

Solidity smart contracts implementing the DDO protocol using the **Diamond proxy pattern (EIP-2535)**. Built with [Foundry](https://book.getfoundry.sh/).

## Architecture

The DDO contract is a Diamond proxy where each function selector maps independently to a facet address. This allows atomic upgrades of individual facets without redeploying the contract or losing state.

### Facets

```
src/diamond/facets/
├── AdminFacet.sol           # Owner-only: payments contract, commission, lockup config
├── AllocationFacet.sol      # Create allocations, settle payments, Filecoin actor callbacks
├── SPFacet.sol              # SP registration, pricing, token management, queries
├── ViewFacet.sol            # Read-only: allocation queries, claim info, deal verification
├── ValidatorFacet.sol       # Payment validation logic
├── DiamondCutFacet.sol      # diamondCut() — add/replace/remove selectors
├── DiamondLoupeFacet.sol    # Diamond introspection (facets, selectors, addresses)
├── OwnershipFacet.sol       # transferOwnership, owner
└── mock/
    └── MockAllocationFacet.sol  # Test variant with mock miner behavior
```

### Libraries

| Library | Purpose |
|---|---|
| `LibDDOStorage.sol` | Diamond storage slot, all shared state, types, events, errors, constants |
| `LibDiamond.sol` | Diamond storage struct, internal cut logic, ownership |
| `VerifRegSerializationDiamond.sol` | CBOR serialization for Filecoin VerifReg actor calls |

### Scripts

| Script | Purpose |
|---|---|
| `DeployDiamond.s.sol` | Full Diamond deployment: cut facet, proxy, all facets, initialization |
| `DeployPayments.s.sol` | Deploy Payments contract (UUPS proxy) |

## Build

```bash
forge build
```

## Test

```bash
# All tests
forge test

# Verbose
forge test -vvv

# Specific file
forge test --match-path test/diamond/DiamondAllocationTest.sol

# Specific function
forge test --match-test testCreateAllocation
```

## Deploy

Deployment uses Foundry keystore for secure key management. Auth is handled via CLI flags (`--account`, `--private-key`, or `--keystore`).

```bash
# Set env vars
export DEPLOYER_ADDRESS="0x..."
export PAYMENTS_CONTRACT_ADDRESS="0x..."

# Deploy Diamond (using keystore)
forge script script/DeployDiamond.s.sol \
  --rpc-url $RPC_URL --account <keystore-name> --broadcast --slow --gas-estimate-multiplier 100000

# Verify on Blockscout (after deployment)
forge verify-contract <ADDRESS> src/diamond/Diamond.sol:Diamond \
  --verifier blockscout --verifier-url https://filecoin.blockscout.com/api/
```

> **Note:** Filecoin requires much higher gas estimates than Ethereum due to on-chain message storage costs. The `--gas-estimate-multiplier 100000` (1000x) accounts for this.


