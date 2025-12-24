#!/bin/sh
#
# generate-scripts.sh - Generate scripts from templates
#
# Generates start-dev.sh, stop-dev.sh, and health-check.sh from templates
# using the port configuration system.
#
# Usage: ./scripts/generate-scripts.sh [options]
#
# Options:
#   --template <name>    Generate specific template (start-dev|stop-dev|health-check|all)
#   --output-dir <dir>   Output directory (default: scripts/)
#
# Examples:
#   ./scripts/generate-scripts.sh                    # Generate all scripts
#   ./scripts/generate-scripts.sh --template start-dev  # Generate only start-dev.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/.devops/templates"
OUTPUT_DIR="$PROJECT_ROOT/scripts"
TEMPLATE_NAME="all"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --template)
            TEMPLATE_NAME="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--template <name>] [--output-dir <dir>]" >&2
            exit 1
            ;;
    esac
done

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    YELLOW='\033[1;33m'
    RESET='\033[0m'
else
    GREEN=''
    BLUE=''
    YELLOW=''
    RESET=''
fi

echo "${BLUE}=== Script Generator ===${RESET}"
echo ""

# Check if templates exist
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "${YELLOW}Warning: Template directory not found: $TEMPLATE_DIR${RESET}"
    echo "  Creating template directory..."
    mkdir -p "$TEMPLATE_DIR"
fi

# Create output directory if needed
mkdir -p "$OUTPUT_DIR"

# Function to generate script from template
generate_script() {
    template_name="$1"
    template_file="$TEMPLATE_DIR/${template_name}.sh.template"
    output_file="$OUTPUT_DIR/${template_name}.sh"
    
    if [ ! -f "$template_file" ]; then
        echo "${YELLOW}Warning: Template not found: $template_file${RESET}"
        return 1
    fi
    
    # Copy template to output
    cp "$template_file" "$output_file"
    chmod +x "$output_file"
    
    echo "${GREEN}✓ Generated: $output_file${RESET}"
}

# Generate scripts
case "$TEMPLATE_NAME" in
    all)
        echo "Generating all scripts..."
        echo ""
        generate_script "start-dev"
        generate_script "stop-dev"
        generate_script "health-check"
        ;;
    start-dev|stop-dev|health-check)
        echo "Generating $TEMPLATE_NAME.sh..."
        echo ""
        generate_script "$TEMPLATE_NAME"
        ;;
    *)
        echo "Unknown template: $TEMPLATE_NAME" >&2
        echo "Available templates: start-dev, stop-dev, health-check, all" >&2
        exit 1
        ;;
esac

echo ""
echo "${GREEN}✓ Script generation complete!${RESET}"
echo ""
echo "Generated scripts are in: $OUTPUT_DIR"
echo "  Use them with: ./scripts/start-dev.sh"
echo "  Regenerate with: ./scripts/generate-scripts.sh"
