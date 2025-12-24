#!/bin/sh
#
# dependency-detection.sh - Auto-detect and install dependencies
#
# Detects package managers and installs missing dependencies automatically.
# Supports: npm, yarn, pnpm, pip, pip3, poetry, cargo, go mod
#
# Usage:
#   source scripts/lib/dependency-detection.sh
#   check_and_install_deps

# Colors
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    RED='\033[0;31m'
    RESET='\033[0m'
else
    GREEN=''
    YELLOW=''
    BLUE=''
    RED=''
    RESET=''
fi

# Detect package manager
detect_package_manager() {
    # Check for Node.js projects
    if [ -f "package.json" ]; then
        if command -v pnpm >/dev/null 2>&1 && [ -f "pnpm-lock.yaml" ]; then
            echo "pnpm"
        elif command -v yarn >/dev/null 2>&1 && [ -f "yarn.lock" ]; then
            echo "yarn"
        elif command -v npm >/dev/null 2>&1; then
            echo "npm"
        fi
    # Check for Python projects
    elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "Pipfile" ]; then
        if command -v poetry >/dev/null 2>&1 && [ -f "pyproject.toml" ]; then
            echo "poetry"
        elif command -v pip3 >/dev/null 2>&1; then
            echo "pip3"
        elif command -v pip >/dev/null 2>&1; then
            echo "pip"
        fi
    # Check for Rust projects
    elif [ -f "Cargo.toml" ]; then
        if command -v cargo >/dev/null 2>&1; then
            echo "cargo"
        fi
    # Check for Go projects
    elif [ -f "go.mod" ]; then
        if command -v go >/dev/null 2>&1; then
            echo "go"
        fi
    fi
}

# Check if dependencies are installed
check_dependencies_installed() {
    pm="$1"
    
    case "$pm" in
        npm|yarn|pnpm)
            if [ ! -d "node_modules" ]; then
                return 1
            fi
            ;;
        pip|pip3)
            # For pip, we can't easily check, so assume not installed
            return 1
            ;;
        poetry)
            if ! poetry check >/dev/null 2>&1; then
                return 1
            fi
            ;;
        cargo)
            if [ ! -d "target" ]; then
                return 1
            fi
            ;;
        go)
            # Go modules are always "installed" (downloaded on build)
            return 0
            ;;
    esac
    return 0
}

# Install dependencies
install_dependencies() {
    pm="$1"
    service_dir="${2:-.}"
    
    echo "${BLUE}Installing dependencies with $pm...${RESET}"
    
    case "$pm" in
        npm)
            (cd "$service_dir" && npm install)
            ;;
        yarn)
            (cd "$service_dir" && yarn install)
            ;;
        pnpm)
            (cd "$service_dir" && pnpm install)
            ;;
        pip|pip3)
            if [ -f "${service_dir}/requirements.txt" ]; then
                "$pm" install -r "${service_dir}/requirements.txt"
            else
                echo "${YELLOW}  No requirements.txt found${RESET}"
            fi
            ;;
        poetry)
            (cd "$service_dir" && poetry install)
            ;;
        cargo)
            (cd "$service_dir" && cargo fetch)
            ;;
        go)
            (cd "$service_dir" && go mod download)
            ;;
        *)
            echo "${YELLOW}  Unknown package manager: $pm${RESET}"
            return 1
            ;;
    esac
}

# Check and install dependencies for a service
check_and_install_deps() {
    service_dir="${1:-.}"
    
    if [ ! -d "$service_dir" ] && [ "$service_dir" != "." ]; then
        return 0  # Service doesn't exist, skip
    fi
    
    # Detect package manager
    pm=$(cd "$service_dir" && detect_package_manager)
    
    if [ -z "$pm" ]; then
        return 0  # No package manager detected
    fi
    
    echo "${BLUE}Checking dependencies for $service_dir (using $pm)...${RESET}"
    
    # Check if already installed
    if check_dependencies_installed "$pm" "$service_dir"; then
        echo "${GREEN}  ✓ Dependencies already installed${RESET}"
        return 0
    fi
    
    # Ask to install (unless CI mode)
    if [ "${CI:-false}" != "true" ]; then
        echo "${YELLOW}  Dependencies not found. Install? (y/n)${RESET}"
        read -r response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            echo "  Skipping installation"
            return 0
        fi
    fi
    
    # Install
    if install_dependencies "$pm" "$service_dir"; then
        echo "${GREEN}  ✓ Dependencies installed${RESET}"
        return 0
    else
        echo "${RED}  ✗ Failed to install dependencies${RESET}"
        return 1
    fi
}

# Check and install for all services in monorepo
check_all_services() {
    echo "${BLUE}Checking dependencies for all services...${RESET}"
    echo ""
    
    # Check root
    check_and_install_deps "."
    
    # Check common service directories
    for dir in frontend backend api automation services; do
        if [ -d "$dir" ]; then
            check_and_install_deps "$dir"
        fi
    done
    
    # Check for package.json in subdirectories (monorepo)
    find . -name "package.json" -not -path "./node_modules/*" -not -path "./.git/*" \
        -exec dirname {} \; | sort -u | while read -r dir; do
        if [ "$dir" != "." ]; then
            check_and_install_deps "$dir"
        fi
    done
}
