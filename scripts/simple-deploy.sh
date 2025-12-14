#!/bin/sh
#
# simple-deploy.sh - Simulate a deployment step
#
# Usage: ./scripts/simple-deploy.sh [project-dir]
#
# Builds the project (if build script exists) and copies output to deploy/
# This simulates a deployment workflow for demonstration purposes.

set -e

PROJECT_DIR="${1:-.}"

# Validate project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Directory '$PROJECT_DIR' does not exist" >&2
    exit 1
fi

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

echo "${BLUE}=== Simple Deploy Simulation ===${RESET}"
echo "Project directory: $PROJECT_DIR"
echo ""

# Check if package.json exists
if [ ! -f "$PROJECT_DIR/package.json" ]; then
    echo "${YELLOW}Warning:${RESET} No package.json found. Skipping test and build steps."
else
    # Check if node_modules exists, suggest npm install if not
    if [ ! -d "$PROJECT_DIR/node_modules" ]; then
        echo "${YELLOW}Warning:${RESET} node_modules not found. Running 'npm install' first..."
        (cd "$PROJECT_DIR" && npm install)
    fi

    # 1. Run tests
    if grep -q '"test"' "$PROJECT_DIR/package.json"; then
        echo "${BLUE}[1/4]${RESET} Running test step..."
        (cd "$PROJECT_DIR" && npm test)
        if [ $? -eq 0 ]; then
            echo "${GREEN}✓${RESET} Tests passed"
        else
            echo "${RED}✗${RESET} Tests failed. Aborting deployment."
            exit 1
        fi
    else
        echo "${YELLOW}[1/4]${RESET} No 'test' script found in package.json. Skipping test step."
    fi

    # 2. Run build
    echo ""
    if grep -q '"build"' "$PROJECT_DIR/package.json"; then
        echo "${BLUE}[2/4]${RESET} Running build step..."
        (cd "$PROJECT_DIR" && npm run build)
        if [ $? -eq 0 ]; then
            echo "${GREEN}✓${RESET} Build completed successfully"
        else
            echo "${RED}✗${RESET} Build failed. Aborting deployment."
            exit 1
        fi
    else
        echo "${YELLOW}[2/4]${RESET} No 'build' script found in package.json. Skipping build step."
    fi
fi

# Determine build output directory
BUILD_DIR=""
if [ -d "$PROJECT_DIR/dist" ]; then
    BUILD_DIR="$PROJECT_DIR/dist"
elif [ -d "$PROJECT_DIR/build" ]; then
    BUILD_DIR="$PROJECT_DIR/build"
elif [ -d "$PROJECT_DIR/out" ]; then
    BUILD_DIR="$PROJECT_DIR/out"
else
    echo "${YELLOW}Warning:${RESET} No standard build directory (dist/build/out) found."
    echo "  Deploying entire project directory (excluding node_modules, etc.)"
fi

# Prepare for packaging
PACKAGE_NAME=$(grep '"name"' "$PROJECT_DIR/package.json" | cut -d '"' -f 4)-$(grep '"version"' "$PROJECT_DIR/package.json" | cut -d '"' -f 4).tar.gz
DEPLOY_ARTIFACT_DIR="$PROJECT_DIR/deploy"
DEPLOY_ARTIFACT_PATH="$DEPLOY_ARTIFACT_DIR/$PACKAGE_NAME"

echo ""
echo "${BLUE}[3/4]${RESET} Creating deployment package..."

mkdir -p "$DEPLOY_ARTIFACT_DIR"

# Create the tarball
if [ -n "$BUILD_DIR" ]; then
    echo "  Archiving build artifacts from '$BUILD_DIR'..."
    # Create a temporary directory to stage files for consistent archive structure
    STAGE_DIR=$(mktemp -d)
    cp -r "$BUILD_DIR"/* "$STAGE_DIR/"
    if [ -f "$PROJECT_DIR/package.json" ]; then
        cp "$PROJECT_DIR/package.json" "$STAGE_DIR/"
    fi
    (cd "$STAGE_DIR" && tar -czf "$DEPLOY_ARTIFACT_PATH" .)
    rm -rf "$STAGE_DIR"
else
    echo "  Archiving entire project (excluding dev files)..."
    tar -czf "$DEPLOY_ARTIFACT_PATH" \
        --exclude="node_modules" \
        --exclude=".git" \
        --exclude="deploy" \
        --exclude="*.log" \
        --exclude=".DS_Store" \
        -C "$PROJECT_DIR" .
fi

echo "${GREEN}✓${RESET} Created package: $DEPLOY_ARTIFACT_PATH"

echo ""
echo "${BLUE}[4/4]${RESET} Validating deployment package..."
if [ -s "$DEPLOY_ARTIFACT_PATH" ]; then
    echo "${GREEN}✓${RESET} Package is not empty."
else
    echo "${RED}✗${RESET} Package is empty or could not be created."
    exit 1
fi

echo ""
echo "${GREEN}✓${RESET} Deployment simulation complete!"
echo ""
echo "Deployment artifact created at: $DEPLOY_ARTIFACT_PATH"
echo ""
echo "${BLUE}Next steps (simulated):${RESET}"
echo "  - Upload '$PACKAGE_NAME' to a server or artifact repository"
echo "  - On the server: unpack, run 'npm install --production', and start"
