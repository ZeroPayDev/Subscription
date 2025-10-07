#!/bin/bash

# abi.sh - Generate ABI files for contracts
# Usage: ./abi.sh

set -e

echo "🔨 Building contracts..."
forge build --extra-output-files abi

echo "📁 Creating abi directory..."
mkdir -p abi

echo "🧹 Cleaning existing ABIs..."
rm -f abi/*.abi.json

echo "📄 Copying contract ABIs..."

# Core protocol contracts
contracts=(
    "ZeroPaySubscription:Subscription.sol"
)

for contract_info in "${contracts[@]}"; do
    IFS=':' read -r contract_name source_path <<< "$contract_info"

    source_file="out/${source_path}/${contract_name}.abi.json"
    dest_file="abi/${contract_name}.abi.json"

    if [[ -f "$source_file" ]]; then
        cp "$source_file" "$dest_file"
        echo "✅ $contract_name -> $dest_file"
    else
        echo "❌ $source_file not found"
    fi
done

echo ""
echo "📊 Generated ABI files:"
ls -la abi/*.abi.json

echo ""
echo "🎉 ABI generation complete!"
echo "📂 ABIs available in: abi/"
