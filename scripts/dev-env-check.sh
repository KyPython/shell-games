#!/bin/sh
#
# dev-env-check.sh - Check for development tools installation
#
# Usage: ./scripts/dev-env-check.sh
#
# Checks for common development tools and reports their installation status

set -e

# Colors for output (if terminal supports it)
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

# Function to check if a command exists
check_tool() {
    tool_name="$1"
    command_name="${2:-$1}"
    
    if command -v "$command_name" >/dev/null 2>&1; then
        version_output=""
        case "$command_name" in
            node)
                version_output="$(node --version 2>/dev/null || echo 'unknown')"
                ;;
            npm)
                version_output="$(npm --version 2>/dev/null || echo 'unknown')"
                ;;
            git)
                version_output="$(git --version 2>/dev/null | head -n1 || echo 'unknown')"
                ;;
            docker)
                version_output="$(docker --version 2>/dev/null || echo 'unknown')"
                ;;
            python|python3)
                version_output="$(python3 --version 2>/dev/null || echo 'unknown')"
                ;;
            *)
                version_output="$(command -v "$command_name")"
                ;;
        esac
        
        printf "${GREEN}✓${RESET} %-15s %s\n" "$tool_name:" "$version_output"
        return 0
    else
        printf "${RED}✗${RESET} %-15s ${YELLOW}not installed${RESET}\n" "$tool_name:"
        return 1
    fi
}

echo "${BLUE}=== Development Environment Check ===${RESET}"
echo ""

INSTALLED=0
MISSING=0

# Core development tools
echo "Core Tools:"
if check_tool "Node.js" "node"; then INSTALLED=$((INSTALLED + 1)); else MISSING=$((MISSING + 1)); fi
if check_tool "npm" "npm"; then INSTALLED=$((INSTALLED + 1)); else MISSING=$((MISSING + 1)); fi
if check_tool "Git" "git"; then INSTALLED=$((INSTALLED + 1)); else MISSING=$((MISSING + 1)); fi

echo ""
echo "Optional Tools:"
if check_tool "Docker" "docker"; then INSTALLED=$((INSTALLED + 1)); else MISSING=$((MISSING + 1)); fi
if check_tool "Python 3" "python3"; then INSTALLED=$((INSTALLED + 1)); else MISSING=$((MISSING + 1)); fi

# Check for TypeScript compiler (global)
echo ""
echo "TypeScript Tools:"
if command -v tsc >/dev/null 2>&1; then
    TS_VERSION="$(tsc --version 2>/dev/null || echo 'unknown')"
    printf "${GREEN}✓${RESET} %-15s %s\n" "TypeScript:" "$TS_VERSION"
    INSTALLED=$((INSTALLED + 1))
else
    printf "${YELLOW}○${RESET} %-15s ${YELLOW}not installed globally${RESET} (can install per-project)\n" "TypeScript:"
fi

# Check npm version (for newer features)
echo ""
if command -v npm >/dev/null 2>&1; then
    NPM_MAJOR="$(npm --version 2>/dev/null | cut -d. -f1)"
    if [ "$NPM_MAJOR" -lt 7 ] 2>/dev/null; then
        printf "${YELLOW}⚠${RESET} npm version is older than 7.0.0 (consider upgrading)\n"
    fi
fi

echo ""
echo "${BLUE}=== Summary ===${RESET}"
echo "Installed: ${GREEN}$INSTALLED${RESET}"
if [ "$MISSING" -gt 0 ]; then
    echo "Missing: ${RED}$MISSING${RESET}"
    exit 1
else
    echo "All core tools are installed! ${GREEN}✓${RESET}"
    exit 0
fi

