#!/bin/bash
set -e

echo "🔧 Building DDO Client..."

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo "❌ Go is not installed. Please install Go 1.22 or later."
    exit 1
fi

# Download dependencies
echo "📦 Downloading dependencies..."
go mod tidy
go mod download

# Build the CLI
echo "🏗️  Building binary..."
go build -ldflags="-s -w" -o ddo ./cmd/cli

# Make executable
chmod +x ddo

echo "✅ Build complete!"
echo ""
echo "📋 Setup Instructions:"
echo "1. Set environment variables:"
echo "   export DDO_CONTRACT_ADDRESS=your_contract_address"
echo "   export PRIVATE_KEY=your_private_key"
echo "   export RPC_URL=your_rpc_endpoint"
echo ""
echo "2. Test the CLI:"
echo "   ./ddo --help"
echo "   ./ddo create-allocations --help"
echo ""
echo "3. Example usage:"
echo "   ./ddo create-allocations --dry-run --input-file examples/piece_infos.json" 