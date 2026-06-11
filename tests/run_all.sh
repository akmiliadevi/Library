#!/usr/bin/env bash
# Run all test suites and report results.
set -e

cd "$(dirname "$0")/.."

echo "=== Running utility tests ==="
lua5.3 tests/test_utils.lua -v

echo ""
echo "=== Running config system tests ==="
lua5.3 tests/test_config.lua -v
