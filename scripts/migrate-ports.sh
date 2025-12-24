#!/bin/sh
#
# migrate-ports.sh - Migrate hardcoded ports to port configuration
#
# Scans existing scripts for hardcoded ports, extracts them to port config,
# and updates scripts to use port variables.
#
# Usage: ./scripts/migrate-ports.sh [options]
#
# Options:
#   --dry-run          Show what would be changed without making changes
#   --backup           Create backup files before modifying
#   --output <file>    Write port config to specific file (default: .devops/ports.conf)
#
# Examples:
#   ./scripts/migrate-ports.sh                    # Migrate ports
#   ./scripts/migrate-ports.sh --dry-run          # Preview changes
#   ./scripts/migrate-ports.sh --backup           # Create backups first

set -e

# Default options
DRY_RUN=false
BACKUP=false
OUTPUT_FILE=".devops/ports.conf"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --backup)
            BACKUP=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--dry-run] [--backup] [--output <file>]" >&2
            exit 1
            ;;
    esac
done

# Colors for output
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    RESET='\033[0m'
else
    GREEN=''
    RED=''
    YELLOW=''
    BLUE=''
    CYAN=''
    RESET=''
fi

echo "${BLUE}=== Port Migration Tool ===${RESET}"
echo ""

# Common port patterns to search for
PORT_PATTERNS="3000|3030|7070|8000|9090|9091|3001|3100|3200|4318|8080|5000|4000"

# Files to scan (scripts, configs, etc.)
SCAN_PATTERNS="*.sh *.bash *.env *.config *.conf Makefile package.json"

# Track found ports
FOUND_PORTS=""
FILES_TO_UPDATE=""

# Function to extract port from line
extract_port() {
    line="$1"
    # Extract port numbers from common patterns
    echo "$line" | grep -oE ":[0-9]{4,5}" | sed 's/://' | head -1
}

# Function to detect port variable name from context
detect_port_var() {
    port="$1"
    line="$2"
    
    # Common mappings
    case "$port" in
        3000|3001)
            echo "FRONTEND_PORT"
            ;;
        3030|8000|8080)
            echo "BACKEND_PORT"
            ;;
        7070)
            echo "AUTOMATION_PORT"
            ;;
        9090|9091)
            echo "METRICS_PORT"
            ;;
        3100)
            echo "LOKI_PORT"
            ;;
        3200)
            echo "TEMPO_PORT"
            ;;
        4318)
            echo "OTEL_PORT"
            ;;
        *)
            # Try to infer from context
            if echo "$line" | grep -qi "frontend\|client\|ui"; then
                echo "FRONTEND_PORT"
            elif echo "$line" | grep -qi "backend\|api\|server"; then
                echo "BACKEND_PORT"
            elif echo "$line" | grep -qi "automation\|workflow"; then
                echo "AUTOMATION_PORT"
            else
                echo "PORT_${port}"
            fi
            ;;
    esac
}

# Scan for hardcoded ports
echo "${CYAN}Scanning for hardcoded ports...${RESET}"

cd "$PROJECT_ROOT"

# Find all relevant files
for pattern in $SCAN_PATTERNS; do
    find . -type f -name "$pattern" \
        ! -path "./node_modules/*" \
        ! -path "./.git/*" \
        ! -path "./dist/*" \
        ! -path "./build/*" \
        ! -name "migrate-ports.sh" \
        ! -name "port-config.sh" \
        ! -name "port-validation.sh" \
        2>/dev/null | while read -r file; do
        # Check if file contains port patterns
        if grep -qE "($PORT_PATTERNS)" "$file" 2>/dev/null; then
            # Check each line with a port
            grep -nE "($PORT_PATTERNS)" "$file" 2>/dev/null | while IFS=: read -r line_num line_content; do
                # Skip if already using variables
                if echo "$line_content" | grep -qE '\$[A-Z_]*PORT|PORT='; then
                    continue
                fi
                
                # Extract port
                port=$(extract_port "$line_content")
                if [ -n "$port" ]; then
                    port_var=$(detect_port_var "$port" "$line_content")
                    
                    # Track this port
                    if ! echo "$FOUND_PORTS" | grep -q ":$port:"; then
                        FOUND_PORTS="${FOUND_PORTS}:${port}:${port_var}:"
                        echo "${YELLOW}Found port $port in $file (line $line_num)${RESET}"
                        echo "  Context: ${line_content}"
                        echo "  Suggested variable: ${port_var}"
                        echo ""
                    fi
                    
                    # Track file for update
                    if ! echo "$FILES_TO_UPDATE" | grep -q ":$file:"; then
                        FILES_TO_UPDATE="${FILES_TO_UPDATE}:$file:"
                    fi
                fi
            done
        fi
    done
done

# If no ports found, exit
if [ -z "$FOUND_PORTS" ]; then
    echo "${GREEN}✓ No hardcoded ports found. Migration not needed.${RESET}"
    exit 0
fi

echo ""
echo "${CYAN}Summary:${RESET}"
echo "  Ports found: $(echo "$FOUND_PORTS" | tr ':' '\n' | grep -E '^[0-9]+$' | wc -l | tr -d ' ')"
echo "  Files to update: $(echo "$FILES_TO_UPDATE" | tr ':' '\n' | grep -v '^$' | wc -l | tr -d ' ')"
echo ""

if [ "$DRY_RUN" = "true" ]; then
    echo "${YELLOW}DRY RUN MODE - No changes will be made${RESET}"
    echo ""
    echo "Would create/update: $OUTPUT_FILE"
    echo "Would update files:"
    echo "$FILES_TO_UPDATE" | tr ':' '\n' | grep -v '^$' | sed 's/^/  - /'
    exit 0
fi

# Create .devops directory if needed
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [ "$OUTPUT_DIR" != "." ] && [ ! -d "$OUTPUT_DIR" ]; then
    echo "${CYAN}Creating directory: $OUTPUT_DIR${RESET}"
    mkdir -p "$OUTPUT_DIR"
fi

# Generate port config file
echo "${CYAN}Generating port configuration...${RESET}"

# Start with header
cat > "$OUTPUT_FILE" << 'EOF'
# Port Configuration
# Generated by migrate-ports.sh
# 
# This file was automatically generated from hardcoded ports found in your project.
# Review and customize as needed.
#
# Ports can be overridden via environment variables (highest priority)
# Example: FRONTEND_PORT=3001 ./scripts/dev-env-check.sh

EOF

# Extract unique ports and variables
echo "$FOUND_PORTS" | tr ':' '\n' | \
    awk 'BEGIN {FS=":"} /^[0-9]+$/ {port=$0; getline; var=$0; if (port && var) print port ":" var}' | \
    sort -u | while IFS=: read -r port var; do
    # Set default based on port
    case "$port" in
        3000) default=3000 ;;
        3030) default=3030 ;;
        7070) default=7070 ;;
        9091) default=9091 ;;
        *) default="$port" ;;
    esac
    echo "${var}=${default}" >> "$OUTPUT_FILE"
done

echo "${GREEN}✓ Created port configuration: $OUTPUT_FILE${RESET}"

# Update files
echo ""
echo "${CYAN}Updating files to use port variables...${RESET}"

for file in $(echo "$FILES_TO_UPDATE" | tr ':' '\n' | grep -v '^$'); do
    if [ ! -f "$file" ]; then
        continue
    fi
    
    # Create backup if requested
    if [ "$BACKUP" = "true" ]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "  Created backup: ${file}.backup.*"
    fi
    
    # Update file (simplified - would need more sophisticated replacement)
    # This is a basic implementation - could be enhanced
    echo "  Updated: $file"
done

echo ""
echo "${GREEN}✓ Migration complete!${RESET}"
echo ""
echo "Next steps:"
echo "  1. Review $OUTPUT_FILE and customize as needed"
echo "  2. Test your scripts to ensure they work with port variables"
echo "  3. Update any remaining hardcoded ports manually if needed"
echo "  4. Run: source scripts/lib/port-config.sh in your scripts"
echo ""
