#!/bin/sh
#
# dev-env-check.sh - Check for development tools and versions
#
# Usage: ./scripts/dev-env-check.sh
#
# Checks for common development tools and reports their installation status and version.
# It can validate against required versions defined in the script.
#
# CI/CD Support:
#   Set CI=true to enable CI mode (optional checks fail gracefully)
#   Example: CI=true ./scripts/dev-env-check.sh

# Detect CI environment
CI_MODE="${CI:-false}"

set -e
set -u

# --- Configuration ---
# Define required tools and their versions.
# Format: "Tool Name|command|required_version"
# required_version is optional. Examples: "20", ">=18", "<=10.5"
CORE_TOOLS="Node.js|node|>=20 npm|npm|>=9 Git|git"
OPTIONAL_TOOLS="Docker|docker Python 3|python3"
# --- End Configuration ---

# --- Port Configuration Check ---
# Check port configuration if available
check_port_config() {
    if [ -f "scripts/lib/port-validation.sh" ]; then
        # shellcheck source=/dev/null
        . scripts/lib/port-validation.sh
        if ! validate_port_config; then
            return 1
        fi
        # Note: Port conflict checking is optional (may have false positives)
        # Uncomment to enable:
        # check_port_conflicts || true
    fi
    return 0
}
# --- End Port Configuration Check ---

# --- Extensibility Hook ---
# Allow projects to extend with custom checks (e.g., Supabase, Kafka, service health)
# Create scripts/custom-env-checks.sh in your project to add custom checks
# Example custom-env-checks.sh:
#   check_supabase_connection() {
#     # Your custom check logic
#   }
#   CUSTOM_CHECKS="check_supabase_connection|check_kafka_topics|check_service_health"
CUSTOM_CHECKS=""
if [ -f "scripts/custom-env-checks.sh" ]; then
    # shellcheck source=/dev/null
    . scripts/custom-env-checks.sh
fi
# --- End Extensibility Hook ---

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
CORE_MISSING=0
CORE_FAILED=0
CUSTOM_FAILED=0

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
    is_core="$4"

    printf "%-15s" "$tool_name:"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf "${RED}✗ not installed${RESET}\n"
        MISSING=$((MISSING + 1))
        if [ "$is_core" = "true" ]; then
            CORE_MISSING=$((CORE_MISSING + 1))
        fi
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
        if [ "$is_core" = "true" ]; then
            CORE_FAILED=$((CORE_FAILED + 1))
        fi
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

        check_tool "$tool_name" "$command_name" "$required_version" "$is_core" || true
    done
}

# Core development tools
echo "Core Tools:"
process_tools "$CORE_TOOLS" "true"

echo ""
echo "Optional Tools:"
process_tools "$OPTIONAL_TOOLS" "false"

# Port configuration check
if [ -f ".devops/ports.conf" ] || [ -f "scripts/lib/port-config.sh" ]; then
    echo ""
    echo "Port Configuration:"
    printf "%-15s" "port-config:"
    if check_port_config; then
        printf "${GREEN}✓ valid${RESET}\n"
    else
        printf "${YELLOW}⚠ issues found${RESET}\n"
    fi
fi

# Run custom checks if defined
if [ -n "$CUSTOM_CHECKS" ]; then
    echo ""
    echo "Custom Checks:"
    set -f
    for custom_check in $CUSTOM_CHECKS; do
        set +f
        printf "%-15s" "$custom_check:"
        if command -v "$custom_check" >/dev/null 2>&1; then
            if "$custom_check"; then
                printf "${GREEN}✓ passed${RESET}\n"
            else
                printf "${RED}✗ failed${RESET}\n"
                CUSTOM_FAILED=$((CUSTOM_FAILED + 1))
            fi
        else
            printf "${YELLOW}⚠ function not found${RESET}\n"
            CUSTOM_FAILED=$((CUSTOM_FAILED + 1))
        fi
    done
fi

echo ""
echo "${BLUE}=== Summary ===${RESET}"

# Exit codes:
# 0 = All checks passed
# 1 = Core tools missing/failed (required)
# 2 = Optional tools missing/failed (non-critical)
# 3 = Custom checks failed (project-specific)

if [ "$CI_MODE" = "true" ]; then
    # In CI mode, only fail on core tool issues
    if [ "$CORE_FAILED" -gt 0 ] || [ "$CORE_MISSING" -gt 0 ]; then
        echo "${RED}✗ Core tool check failed.${RESET} Please fix the issues marked with ✗."
        exit 1
    else
        if [ "$FAILED_CHECKS" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
            echo "${YELLOW}⚠️  Some optional tools missing (continuing in CI mode)${RESET}"
        fi
        if [ "$CUSTOM_FAILED" -gt 0 ]; then
            echo "${YELLOW}⚠️  Some custom checks failed (continuing in CI mode)${RESET}"
        fi
        echo "${GREEN}✓ Core tools check passed!${RESET}"
        exit 0
    fi
else
    # In non-CI mode, use different exit codes
    if [ "$CORE_FAILED" -gt 0 ] || [ "$CORE_MISSING" -gt 0 ]; then
        echo "${RED}✗ Core tool check failed.${RESET} Please fix the issues marked with ✗."
        exit 1  # Required tools missing
    elif [ "$CUSTOM_FAILED" -gt 0 ]; then
        echo "${RED}✗ Custom checks failed.${RESET} Please fix the issues marked with ✗."
        exit 3  # Custom checks failed
    elif [ "$FAILED_CHECKS" -gt 0 ] || [ "$MISSING" -gt 0 ]; then
        echo "${YELLOW}⚠️  Some optional tools missing (non-critical)${RESET}"
        exit 2  # Optional tools missing
    else
        echo "${GREEN}✓ Environment check passed!${RESET}"
        exit 0  # All checks passed
    fi
fi
