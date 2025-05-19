# DDO Client (WIP)

A demonstration of storing data through Direct Data Onboarding (DDO) in Filecoin using smart contracts. 

## Project Structure

```
.
├── cmd/
│   └── cli/          # Go CLI application for interacting with contracts
├── contracts/
│   ├── lib/          # Smart contract dependencies
│   ├── src/          # Smart contract source files
│   └── foundry.toml  # Foundry configuration
└── go.mod           # Go module configuration
```

## Features

- Smart contract-based storage market
- Customizable payment flow
- CLI interface for contract interaction

## Getting Started

### Prerequisites

- Go 1.22+
- Foundry
- Filecoin node access

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd ddo-client
```

2. Install dependencies:
```bash
# Install Go dependencies
go mod tidy

# Install Foundry dependencies
cd contracts
forge install
```

### Usage

Build and run the CLI:
```bash
go build -o ddo ./cmd/cli
./ddo
```
