#!/bin/sh
#
# lint-and-test.sh - Run linting and tests across all services
#
# Usage: ./scripts/lint-and-test.sh [project-dir]
#
# Runs linting (if available) and tests for all services in a monorepo.
# Supports multi-service projects (frontend, backend, automation, etc.)
#
# CI/CD Support:
#   Set CI=true to enable CI mode (fail fast, non-interactive)
#   Example: CI=true ./scripts/lint-and-test.sh

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

echo "${BLUE}=== Linting and Testing All Services ===${RESET}"
echo ""

# Find all services
SERVICES=$(find_services "$PROJECT_DIR")
SERVICE_COUNT=$(echo "$SERVICES" | grep -c . || echo "0")

if [ "$SERVICE_COUNT" -eq 0 ]; then
    echo "${YELLOW}Warning:${RESET} No package.json files found in $PROJECT_DIR"
    exit 1
fi

echo "Found $SERVICE_COUNT service(s)"
echo ""

FAILED=0
PASSED=0

# Process each service
for SERVICE_PKG in $SERVICES; do
    SERVICE_ROOT=$(dirname "$SERVICE_PKG")
    SERVICE_NAME=$(basename "$SERVICE_ROOT")
    
    # Skip root package.json if it's not a service
    if [ "$SERVICE_ROOT" = "$PROJECT_DIR" ] && [ "$SERVICE_COUNT" -gt 1 ]; then
        continue
    fi
    
    echo "${BLUE}--- Processing: $SERVICE_NAME ---${RESET}"
    
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
    
    SERVICE_FAILED=0
    
    # 1. Run linting (if available)
    if grep -q '"lint"' "$SERVICE_PKG"; then
        echo "  [1/2] Running lint..."
        if (cd "$SERVICE_ROOT" && npm run lint); then
            echo "  ${GREEN}✓${RESET} Lint passed"
        else
            echo "  ${RED}✗${RESET} Lint failed"
            SERVICE_FAILED=1
            if [ "$CI_MODE" = "true" ]; then
                echo "${RED}Aborting (CI mode: fail fast)${RESET}"
                exit 1
            fi
        fi
    else
        echo "  [1/2] ${YELLOW}⚠${RESET}  No 'lint' script found. Skipping."
    fi
    
    # 2. Run tests (if available)
    if grep -q '"test"' "$SERVICE_PKG"; then
        echo "  [2/2] Running tests..."
        if (cd "$SERVICE_ROOT" && npm test); then
            echo "  ${GREEN}✓${RESET} Tests passed"
        else
            echo "  ${RED}✗${RESET} Tests failed"
            SERVICE_FAILED=1
            if [ "$CI_MODE" = "true" ]; then
                echo "${RED}Aborting (CI mode: fail fast)${RESET}"
                exit 1
            fi
        fi
    else
        echo "  [2/2] ${YELLOW}⚠${RESET}  No 'test' script found. Skipping."
    fi
    
    if [ "$SERVICE_FAILED" -eq 0 ]; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

# Summary
echo "${BLUE}=== Summary ===${RESET}"
echo "${GREEN}Passed:${RESET} $PASSED"
if [ "$FAILED" -gt 0 ]; then
    echo "${RED}Failed:${RESET} $FAILED"
fi

if [ "$FAILED" -gt 0 ]; then
    exit 1
else
    echo ""
    echo "${GREEN}✓ All checks passed!${RESET}"
    exit 0
fi
