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
    echo "${YELLOW}Warning:${RESET} No package.json found. Skipping build step."
else
    # Check if build script exists in package.json
    if grep -q '"build"' "$PROJECT_DIR/package.json"; then
        echo "${BLUE}[1/3]${RESET} Running build step..."
        
        # Check if node_modules exists, suggest npm install if not
        if [ ! -d "$PROJECT_DIR/node_modules" ]; then
            echo "${YELLOW}Warning:${RESET} node_modules not found. Running 'npm install' first..."
            (cd "$PROJECT_DIR" && npm install)
        fi
        
        # Run the build
        (cd "$PROJECT_DIR" && npm run build)
        
        if [ $? -eq 0 ]; then
            echo "${GREEN}✓${RESET} Build completed successfully"
        else
            echo "${RED}✗${RESET} Build failed"
            exit 1
        fi
    else
        echo "${YELLOW}[1/3]${RESET} No 'build' script found in package.json. Skipping build step."
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

# Create deploy directory
DEPLOY_DIR="$PROJECT_DIR/deploy"
echo ""
echo "${BLUE}[2/3]${RESET} Preparing deploy directory..."

# Remove existing deploy directory if it exists
if [ -d "$DEPLOY_DIR" ]; then
    echo "  Removing existing deploy directory..."
    rm -rf "$DEPLOY_DIR"
fi

mkdir -p "$DEPLOY_DIR"

# Copy files to deploy directory
echo "${BLUE}[3/3]${RESET} Copying files to deploy/..."

if [ -n "$BUILD_DIR" ]; then
    echo "  Copying from: $BUILD_DIR"
    cp -r "$BUILD_DIR"/* "$DEPLOY_DIR/" 2>/dev/null || cp -r "$BUILD_DIR"/. "$DEPLOY_DIR/"
    
    # Also copy package.json if it exists (for production dependencies)
    if [ -f "$PROJECT_DIR/package.json" ]; then
        cp "$PROJECT_DIR/package.json" "$DEPLOY_DIR/"
        # Create a minimal package.json for production
        if command -v node >/dev/null 2>&1; then
            node -e "
                const pkg = require('./${PROJECT_DIR}/package.json');
                const prodPkg = {
                    name: pkg.name,
                    version: pkg.version,
                    main: pkg.main || 'index.js',
                    dependencies: pkg.dependencies || {}
                };
                require('fs').writeFileSync(
                    './${DEPLOY_DIR}/package.json',
                    JSON.stringify(prodPkg, null, 2) + '\n'
                );
            " 2>/dev/null || cp "$PROJECT_DIR/package.json" "$DEPLOY_DIR/"
        fi
    fi
else
    # Copy entire project, excluding common ignore patterns
    echo "  Copying project files (excluding node_modules, .git, etc.)..."
    (cd "$PROJECT_DIR" && find . -type f \
        ! -path "./node_modules/*" \
        ! -path "./.git/*" \
        ! -path "./deploy/*" \
        ! -path "./.DS_Store" \
        ! -path "./*.log" \
        -exec cp --parents {} "$DEPLOY_DIR/" \; 2>/dev/null || \
    rsync -av --exclude 'node_modules' --exclude '.git' --exclude 'deploy' \
        --exclude '*.log' --exclude '.DS_Store' \
        . "$DEPLOY_DIR/" 2>/dev/null || \
    echo "${YELLOW}Note:${RESET} Using basic copy method. Some files may be included that shouldn't be.")
fi

# Create deployment info file
cat > "$DEPLOY_DIR/.deploy-info" << EOF
Deployed: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Source: $PROJECT_DIR
Build directory: ${BUILD_DIR:-"N/A (full project copy)"}
EOF

echo ""
echo "${GREEN}✓${RESET} Deployment simulation complete!"
echo ""
echo "Deployed files are in: $DEPLOY_DIR"
echo ""
echo "${BLUE}Next steps (simulated):${RESET}"
echo "  - Review files in $DEPLOY_DIR"
echo "  - Upload to server"
echo "  - Run production setup (e.g., npm install --production)"
echo "  - Start application"

