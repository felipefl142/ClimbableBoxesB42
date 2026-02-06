#!/bin/bash
# Run Climbable Boxes test suite using busted with Lua 5.1
# Usage: ./tests/run_tests.sh [unit|integration|structural|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUSTED="/usr/lib/luarocks/rocks-5.1/busted/2.3.0-1/bin/busted"
LUA="lua5.1"

cd "$PROJECT_DIR"

PROFILE="${1:-all}"

case "$PROFILE" in
    unit)
        echo "=== Running unit tests ==="
        "$LUA" "$BUSTED" --helper=tests/mocks/pz_globals.lua --lpath="tests/?.lua;tests/?/init.lua" --pattern="test_" tests/unit/
        ;;
    integration)
        echo "=== Running integration tests ==="
        "$LUA" "$BUSTED" --helper=tests/mocks/pz_globals.lua --lpath="tests/?.lua;tests/?/init.lua" --pattern="test_" tests/integration/
        ;;
    structural)
        echo "=== Running structural tests ==="
        "$LUA" "$BUSTED" --helper=tests/mocks/pz_globals.lua --lpath="tests/?.lua;tests/?/init.lua" --pattern="test_" tests/structural/
        ;;
    all)
        echo "=== Running ALL tests ==="
        "$LUA" "$BUSTED" --helper=tests/mocks/pz_globals.lua --lpath="tests/?.lua;tests/?/init.lua" --pattern="test_" tests/unit/ tests/integration/ tests/structural/
        ;;
    *)
        echo "Usage: $0 [unit|integration|structural|all]"
        exit 1
        ;;
esac
