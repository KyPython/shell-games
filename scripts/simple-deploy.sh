#!/bin/sh
#
# simple-deploy.sh - Simulate a deployment step
#
# Usage: ./scripts/simple-deploy.sh [project-dir]
#
# Builds the project (if build script exists) and copies output to deploy/
# This simulates a deployment workflow for demonstration purposes.
#
# Multi-Service Support:
#   If project-dir contains subdirectories with package.json, each will be deployed
#   Example: ./scripts/simple-deploy.sh .  (deploys all services in monorepo)
#
# Configuration:
#   Create deploy.config.sh in project root to customize deployment behavior
#   See deploy.config.sh.example for configuration options
#
# CI/CD Support:
#   Set CI=true to enable CI mode (non-interactive, fail fast)
#   Example: CI=true ./scripts/simple-deploy.sh

# Detect CI environment
CI_MODE="${CI:-false}"

set -e

PROJECT_DIR="${1:-.}"

# Load configuration if available
DEPLOY_CONFIG_FILE="$PROJECT_DIR/deploy.config.sh"
if [ -f "$DEPLOY_CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$DEPLOY_CONFIG_FILE"
fi

# Default configuration values (can be overridden by deploy.config.sh)
# Build commands per service type (detected by directory name or package.json keywords)
DEFAULT_BUILD_CMD="${DEPLOY_BUILD_CMD:-npm run build}"
DEFAULT_TEST_CMD="${DEPLOY_TEST_CMD:-npm test}"
DEFAULT_BUILD_DIRS="${DEPLOY_BUILD_DIRS:-dist build out .next}"

# Artifact naming format: {name}-{version}-{timestamp}.tar.gz
ARTIFACT_NAME_FORMAT="${DEPLOY_ARTIFACT_FORMAT:-{name}-{version}-{timestamp}.tar.gz}"

# Colors for output (must be defined before use)
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

# Check if this is a monorepo (multiple package.json files)
SERVICES=$(find_services "$PROJECT_DIR")
SERVICE_COUNT=$(echo "$SERVICES" | grep -c . || echo "0")

if [ "$SERVICE_COUNT" -gt 1 ]; then
    echo "${BLUE}Detected multi-service project ($SERVICE_COUNT services)${RESET}"
    echo ""
    DEPLOY_MULTI=true
else
    DEPLOY_MULTI=false
fi

echo "${BLUE}=== Simple Deploy Simulation ===${RESET}"
if [ "$DEPLOY_MULTI" = "true" ]; then
    echo "Multi-service deployment mode"
else
    echo "Project directory: $PROJECT_DIR"
fi
echo ""

# Function to detect service type and get service-specific config
get_service_config() {
    SERVICE_ROOT="$1"
    SERVICE_DIR="$2"
    SERVICE_NAME=$(basename "$SERVICE_ROOT")
    
    # Detect service type from directory name or package.json
    SERVICE_TYPE="default"
    if echo "$SERVICE_NAME" | grep -qiE "(frontend|web|client|ui)"; then
        SERVICE_TYPE="frontend"
    elif echo "$SERVICE_NAME" | grep -qiE "(backend|api|server)"; then
        SERVICE_TYPE="backend"
    elif echo "$SERVICE_NAME" | grep -qiE "(automation|script|tool)"; then
        SERVICE_TYPE="automation"
    fi
    
    # Check package.json for type hints
    if grep -qi '"type".*"module"' "$SERVICE_DIR" 2>/dev/null; then
        SERVICE_TYPE="esm"
    fi
    
    # Get service-specific build command
    BUILD_CMD_VAR="DEPLOY_BUILD_CMD_$(echo "$SERVICE_TYPE" | tr '[:lower:]' '[:upper:]')"
    BUILD_CMD=$(eval "echo \${$BUILD_CMD_VAR:-$DEFAULT_BUILD_CMD}")
    
    # Get service-specific build directories
    BUILD_DIRS_VAR="DEPLOY_BUILD_DIRS_$(echo "$SERVICE_TYPE" | tr '[:lower:]' '[:upper:]')"
    BUILD_DIRS=$(eval "echo \${$BUILD_DIRS_VAR:-$DEFAULT_BUILD_DIRS}")
    
    # Export for use in deploy_service
    export SERVICE_TYPE
    export BUILD_CMD
    export BUILD_DIRS
}

# Function to generate artifact name
generate_artifact_name() {
    SERVICE_DIR="$1"
    SERVICE_NAME=$(grep '"name"' "$SERVICE_DIR" | cut -d '"' -f 4 | tr -d ' ')
    VERSION=$(grep '"version"' "$SERVICE_DIR" | cut -d '"' -f 4 | tr -d ' ')
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    # Replace placeholders in format string
    ARTIFACT_NAME=$(echo "$ARTIFACT_NAME_FORMAT" | \
        sed "s/{name}/$SERVICE_NAME/g" | \
        sed "s/{version}/$VERSION/g" | \
        sed "s/{timestamp}/$TIMESTAMP/g")
    
    echo "$ARTIFACT_NAME"
}

# Function to deploy a single service
deploy_service() {
    SERVICE_DIR="$1"
    SERVICE_ROOT=$(dirname "$SERVICE_DIR")
    SERVICE_NAME=$(basename "$SERVICE_ROOT")
    
    if [ "$DEPLOY_MULTI" = "true" ]; then
        echo "${BLUE}--- Deploying service: $SERVICE_NAME ---${RESET}"
    fi
    
    # Check if package.json exists
    if [ ! -f "$SERVICE_DIR" ]; then
        echo "${YELLOW}Warning:${RESET} No package.json found at $SERVICE_DIR. Skipping."
        return 0
    fi
    
    # Get service-specific configuration
    get_service_config "$SERVICE_ROOT" "$SERVICE_DIR"
    
    if [ "$DEPLOY_MULTI" = "true" ]; then
        echo "  Service type: $SERVICE_TYPE"
    fi
    # Check if node_modules exists, suggest npm install if not
    if [ ! -d "$SERVICE_ROOT/node_modules" ]; then
        echo "${YELLOW}Warning:${RESET} node_modules not found. Running 'npm install' first..."
        (cd "$SERVICE_ROOT" && npm install)
    fi

    # 1. Run tests
    TEST_CMD_VAR="DEPLOY_TEST_CMD_$(echo "$SERVICE_TYPE" | tr '[:lower:]' '[:upper:]')"
    TEST_CMD=$(eval "echo \${$TEST_CMD_VAR:-$DEFAULT_TEST_CMD}")
    
    if grep -q '"test"' "$SERVICE_DIR"; then
        echo "${BLUE}[1/4]${RESET} Running test step..."
        if (cd "$SERVICE_ROOT" && eval "$TEST_CMD"); then
            echo "${GREEN}✓${RESET} Tests passed"
        else
            echo "${RED}✗${RESET} Tests failed. Aborting deployment."
            return 1
        fi
    else
        echo "${YELLOW}[1/4]${RESET} No 'test' script found in package.json. Skipping test step."
    fi

    # 2. Run build
    echo ""
    if grep -q '"build"' "$SERVICE_DIR" || [ -n "$BUILD_CMD" ]; then
        echo "${BLUE}[2/4]${RESET} Running build step..."
        if (cd "$SERVICE_ROOT" && eval "$BUILD_CMD"); then
            echo "${GREEN}✓${RESET} Build completed successfully"
        else
            echo "${RED}✗${RESET} Build failed. Aborting deployment."
            return 1
        fi
    else
        echo "${YELLOW}[2/4]${RESET} No build command configured. Skipping build step."
    fi

    # Determine build output directory
    BUILD_DIR=""
    for build_dir in $BUILD_DIRS; do
        if [ "$build_dir" = "." ]; then
            # Special case: deploy entire directory
            BUILD_DIR=""
            break
        elif [ -d "$SERVICE_ROOT/$build_dir" ]; then
            BUILD_DIR="$SERVICE_ROOT/$build_dir"
            break
        fi
    done
    
    if [ -z "$BUILD_DIR" ] && [ "$BUILD_DIRS" != "." ]; then
        echo "${YELLOW}Warning:${RESET} No build directory found (checked: $BUILD_DIRS)."
        echo "  Deploying entire service directory (excluding node_modules, etc.)"
    fi

    # Prepare for packaging with standardized naming
    PACKAGE_NAME=$(generate_artifact_name "$SERVICE_DIR")
    DEPLOY_ARTIFACT_DIR="$SERVICE_ROOT/deploy"
    DEPLOY_ARTIFACT_PATH="$DEPLOY_ARTIFACT_DIR/$PACKAGE_NAME"

    echo ""
    echo "${BLUE}[3/4]${RESET} Creating deployment package..."

    mkdir -p "$DEPLOY_ARTIFACT_DIR"

    # Create the tarball
    if [ -n "$BUILD_DIR" ]; then
        echo "  Archiving build artifacts from '$BUILD_DIR'..."
        # Create a temporary directory to stage files for consistent archive structure
        STAGE_DIR=$(mktemp -d)
        cp -r "$BUILD_DIR"/* "$STAGE_DIR/" 2>/dev/null || true
        if [ -f "$SERVICE_DIR" ]; then
            cp "$SERVICE_DIR" "$STAGE_DIR/"
        fi
        (cd "$STAGE_DIR" && tar -czf "$DEPLOY_ARTIFACT_PATH" .)
        rm -rf "$STAGE_DIR"
    else
        echo "  Archiving entire service (excluding dev files)..."
        tar -czf "$DEPLOY_ARTIFACT_PATH" \
            --exclude="node_modules" \
            --exclude=".git" \
            --exclude="deploy" \
            --exclude="*.log" \
            --exclude=".DS_Store" \
            -C "$SERVICE_ROOT" .
    fi

    echo "${GREEN}✓${RESET} Created package: $DEPLOY_ARTIFACT_PATH"

    echo ""
    echo "${BLUE}[4/4]${RESET} Validating deployment package..."
    if [ -s "$DEPLOY_ARTIFACT_PATH" ]; then
        echo "${GREEN}✓${RESET} Package is not empty."
    else
        echo "${RED}✗${RESET} Package is empty or could not be created."
        return 1
    fi
    
    if [ "$DEPLOY_MULTI" = "true" ]; then
        echo ""
    fi
}

# Deploy all services
if [ "$DEPLOY_MULTI" = "true" ]; then
    FAILED=0
    for SERVICE_PKG in $SERVICES; do
        if ! deploy_service "$SERVICE_PKG"; then
            FAILED=$((FAILED + 1))
        fi
    done
    
    echo ""
    echo "${BLUE}=== Multi-Service Deployment Summary ===${RESET}"
    if [ "$FAILED" -eq 0 ]; then
        echo "${GREEN}✓${RESET} All services deployed successfully!"
    else
        echo "${RED}✗${RESET} $FAILED service(s) failed to deploy."
        exit 1
    fi
else
    # Single service deployment
    if [ -f "$PROJECT_DIR/package.json" ]; then
        deploy_service "$PROJECT_DIR/package.json"
        echo ""
        echo "${GREEN}✓${RESET} Deployment simulation complete!"
        echo ""
        PACKAGE_NAME=$(generate_artifact_name "$PROJECT_DIR/package.json")
        echo "Deployment artifact created at: $PROJECT_DIR/deploy/$PACKAGE_NAME"
        echo ""
        echo "${BLUE}Next steps (simulated):${RESET}"
        echo "  - Upload '$PACKAGE_NAME' to a server or artifact repository"
        echo "  - On the server: unpack, run 'npm install --production', and start"
    else
        echo "${YELLOW}Warning:${RESET} No package.json found. Skipping deployment."
    fi
fi
