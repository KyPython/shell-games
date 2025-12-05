#!/bin/sh
#
# new-node-project.sh - Scaffold a basic Node.js/TypeScript project
#
# Usage: ./scripts/new-node-project.sh <project-name>
#
# Creates a new directory with:
# - package.json with TypeScript dependencies
# - tsconfig.json configuration
# - src/index.ts starter file
# - .gitignore
# - Basic README.md

set -e

PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name is required" >&2
    echo "Usage: $0 <project-name>" >&2
    exit 1
fi

# Validate project name (alphanumeric, dash, underscore only)
if ! echo "$PROJECT_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo "Error: Project name must contain only alphanumeric characters, dashes, or underscores" >&2
    exit 1
fi

if [ -d "$PROJECT_NAME" ]; then
    echo "Error: Directory '$PROJECT_NAME' already exists" >&2
    exit 1
fi

echo "Creating Node.js/TypeScript project: $PROJECT_NAME"
mkdir -p "$PROJECT_NAME/src"

# Create package.json (using non-quoted heredoc for variable expansion)
cat > "$PROJECT_NAME/package.json" << EOF
{
  "name": "$PROJECT_NAME",
  "version": "1.0.0",
  "description": "A TypeScript project",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "tsc --watch",
    "clean": "rm -rf dist"
  },
  "keywords": [],
  "author": "",
  "license": "ISC",
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0"
  }
}
EOF

# Create tsconfig.json
cat > "$PROJECT_NAME/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "moduleResolution": "node"
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
EOF

# Create src/index.ts
cat > "$PROJECT_NAME/src/index.ts" << 'EOF'
/**
 * Main entry point for the application
 */

function main(): void {
  console.log('Hello, TypeScript!');
}

main();
EOF

# Create .gitignore
cat > "$PROJECT_NAME/.gitignore" << 'EOF'
node_modules/
dist/
*.log
.DS_Store
*.swp
*.swo
.env
.env.local
EOF

# Create README.md
cat > "$PROJECT_NAME/README.md" << EOF
# $PROJECT_NAME

A TypeScript Node.js project.

## Setup

\`\`\`bash
npm install
\`\`\`

## Development

\`\`\`bash
npm run dev    # Watch mode
npm run build  # Build once
npm start      # Run built code
\`\`\`

## Project Structure

- \`src/\` - TypeScript source files
- \`dist/\` - Compiled JavaScript (generated)
EOF

echo "✓ Project '$PROJECT_NAME' created successfully!"
echo ""
echo "Next steps:"
echo "  cd $PROJECT_NAME"
echo "  npm install"
echo "  npm run build"

