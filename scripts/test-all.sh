#!/bin/sh
#
# test-all.sh - Run tests across all services in a monorepo
#
# Usage: ./scripts/test-all.sh [project-dir]
#
# Finds all package.json files in subdirectories and runs tests for each service.
# Supports multi-service projects (frontend, backend, automation, etc.)
#
# CI/CD Support:
#   Set CI=true to enable CI mode (fail fast, non-interactive)
#   Example: CI=true ./scripts/test-all.sh

# Detect CI environment
CI_MODE="${CI:-false}"

set -e

PROJECT_DIR="${1:-.}"

# Colors for output
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    YELLOW=''
    BLUE=''
    RESET=''
fi

# Validate project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory '$PROJECT_DIR' does not exist" >&2
    exit 1
fi

# Function to find all package.json files (for monorepo support)
find_services() {
    find "$1" -maxdepth 3 -name "package.json" -type f | grep -v node_modules | sort
}

echo "${BLUE}=== Running Tests Across All Services ===${RESET}"
echo ""

# Find all services
SERVICES=$(find_services "$PROJECT_DIR")
SERVICE_COUNT=$(echo "$SERVICES" | grep -c . || echo "0")

if [ "$SERVICE_COUNT" -eq 0 ]; then
    echo "${YELLOW}Warning:${RESET} No package.json files found in $PROJECT_DIR"
    exit 1
fi

echo "Found $SERVICE_COUNT service(s) to test"
echo ""

FAILED=0
PASSED=0
SKIPPED=0

# Test each service
for SERVICE_PKG in $SERVICES; do
    SERVICE_ROOT=$(dirname "$SERVICE_PKG")
    SERVICE_NAME=$(basename "$SERVICE_ROOT")
    
    # Skip root package.json if it's not a service
    if [ "$SERVICE_ROOT" = "$PROJECT_DIR" ] && [ "$SERVICE_COUNT" -gt 1 ]; then
        continue
    fi
    
    echo "${BLUE}--- Testing: $SERVICE_NAME ---${RESET}"
    
    # Check if test script exists
    if ! grep -q '"test"' "$SERVICE_PKG"; then
        echo "${YELLOW}⚠${RESET}  No 'test' script found. Skipping."
        SKIPPED=$((SKIPPED + 1))
        echo ""
        continue
    fi
    
    # Check if node_modules exists
    if [ ! -d "$SERVICE_ROOT/node_modules" ]; then
        echo "${YELLOW}Warning:${RESET} node_modules not found. Running 'npm install' first..."
        (cd "$SERVICE_ROOT" && npm install) || {
            echo "${RED}✗${RESET} Failed to install dependencies"
            FAILED=$((FAILED + 1))
            echo ""
            continue
        }
    fi
    
    # Run tests
    if (cd "$SERVICE_ROOT" && npm test); then
        echo "${GREEN}✓${RESET} Tests passed for $SERVICE_NAME"
        PASSED=$((PASSED + 1))
    else
        echo "${RED}✗${RESET} Tests failed for $SERVICE_NAME"
        FAILED=$((FAILED + 1))
        if [ "$CI_MODE" = "true" ]; then
            echo "${RED}Aborting (CI mode: fail fast)${RESET}"
            exit 1
        fi
    fi
    echo ""
done

# Summary
echo "${BLUE}=== Test Summary ===${RESET}"
echo "${GREEN}Passed:${RESET} $PASSED"
if [ "$FAILED" -gt 0 ]; then
    echo "${RED}Failed:${RESET} $FAILED"
fi
if [ "$SKIPPED" -gt 0 ]; then
    echo "${YELLOW}Skipped:${RESET} $SKIPPED"
fi

if [ "$FAILED" -gt 0 ]; then
    exit 1
else
    echo ""
    echo "${GREEN}✓ All tests passed!${RESET}"
    exit 0
fi
