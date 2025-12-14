#!/bin/sh
#
# dev-env-check.sh - Check for development tools and versions
#
# Usage: ./scripts/dev-env-check.sh
#
# Checks for common development tools and reports their installation status and version.
# It can validate against required versions defined in the script.

set -e
set -u

# --- Configuration ---
# Define required tools and their versions.
# Format: "Tool Name|command|required_version"
# required_version is optional. Examples: "20", ">=18", "<=10.5"
CORE_TOOLS="Node.js|node|>=20 npm|npm|>=9 Git|git"
OPTIONAL_TOOLS="Docker|docker Python 3|python3"
# --- End Configuration ---

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

echo "${BLUE}=== Development Environment Check ===${RESET}"
echo ""

INSTALLED=0
MISSING=0
FAILED_CHECKS=0

# POSIX-compliant version comparison function
# Usage: version_compare "18.1.0" ">=18"
version_compare() {
    # shellcheck disable=SC2046
    set -- $(echo "$1" | tr . ' ') "$2"
    v1_major="${1:-0}"
    v1_minor="${2:-0}"
    v1_patch="${3:-0}"
    req="$4"

    op="$(echo "$req" | sed 's/[0-9.].*//')"
    req_v="$(echo "$req" | sed 's/^[^0-9]*//')"
    # shellcheck disable=SC2046
    set -- $(echo "$req_v" | tr . ' ')
    v2_major="${1:-0}"
    v2_minor="${2:-0}"

    if [ "$v1_major" -gt "$v2_major" ]; then
        [ "$op" = ">=" ] || [ "$op" = ">" ] && return 0
    elif [ "$v1_major" -lt "$v2_major" ]; then
        [ "$op" = "<=" ] || [ "$op" = "<" ] && return 0
    elif [ "$v1_minor" -ge "$v2_minor" ]; then
        [ "$op" = ">=" ] || [ "$op" = "=" ] && return 0
    elif [ "$v1_minor" -lt "$v2_minor" ]; then
        [ "$op" = "<=" ] || [ "$op" = "<" ] && return 0
    fi
    return 1
}

# Function to check a tool, its version, and validate against a requirement
check_tool() {
    tool_name="$1"
    command_name="$2"
    required_version="$3"

    printf "%-15s" "$tool_name:"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf "${RED}✗ not installed${RESET}\n"
        MISSING=$((MISSING + 1))
        return 1
    fi

    INSTALLED=$((INSTALLED + 1))
    version_output="$(eval "$command_name --version" 2>/dev/null | head -n1 | sed 's/.* //; s/v//')"

    if [ -z "$required_version" ]; then
        printf "${GREEN}✓ installed${RESET} ($version_output)\n"
        return 0
    fi

    if version_compare "$version_output" "$required_version"; then
        printf "${GREEN}✓ installed${RESET} ($version_output, required: $required_version)\n"
        return 0
    else
        printf "${RED}✗ wrong version${RESET} (found: $version_output, required: $required_version)\n"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Wrapper to loop through tool definitions
process_tools() {
    tool_definitions="$1"
    is_core="$2"
    
    # Use IFS to split on space, and disable globbing
    set -f
    for tool_def in $tool_definitions; do
        set +f
        # Restore IFS and re-enable globbing
        tool_name=$(echo "$tool_def" | cut -d'|' -f1)
        command_name=$(echo "$tool_def" | cut -d'|' -f2)
        required_version=$(echo "$tool_def" | cut -d'|' -f3)
        # If there's no version, cut returns the command name. Clear it.
        if [ "$required_version" = "$command_name" ]; then required_version=""; fi

        if ! check_tool "$tool_name" "$command_name" "$required_version" && [ "$is_core" = "true" ]; then
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done
}

# Core development tools
echo "Core Tools:"
process_tools "$CORE_TOOLS" "true"

echo ""
echo "Optional Tools:"
process_tools "$OPTIONAL_TOOLS" "false"

echo ""
echo "${BLUE}=== Summary ===${RESET}"
if [ "$FAILED_CHECKS" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
    echo "${RED}✗ Environment check failed.${RESET} Please fix the issues marked with ✗."
    exit 1
else
    echo "${GREEN}✓ Environment check passed!${RESET}"
    exit 0
fi
