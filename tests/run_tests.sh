#!/usr/bin/env bash
# Run lsp_signature tests headlessly
# Usage: bash tests/run_tests.sh

set -e
cd "$(dirname "$0")/.."

echo "Running lsp_signature tests..."

nvim --headless \
  -u tests/minimal_init.lua \
  -c "PlenaryBustedFile tests/lsp_sig_spec.lua" \
  2>&1

echo "Done."
