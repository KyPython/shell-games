# Shell Games Toolkit

A collection of reusable shell scripts that automate common development tasks. These scripts demonstrate the "Shell Games" principle from *The Pragmatic Programmer* - using shell scripts to automate repetitive tasks and make your development workflow more efficient.

## Overview

This toolkit provides essential scripts for development automation:

- **`new-node-project.sh`** - Scaffold a new Node.js/TypeScript project with sensible defaults
- **`dev-env-check.sh`** - Verify that required development tools are installed
- **`simple-deploy.sh`** - Simulate a deployment workflow (build + copy to deploy folder)
- **`test-all.sh`** - Run tests across all services in a monorepo
- **`lint-and-test.sh`** - Run linting and tests across all services

All scripts support:
- ✅ NPM script integration (via `package.json`)
- ✅ Multi-service/monorepo projects
- ✅ CI/CD environments (GitHub Actions, etc.)

## The "Shell Games" Concept

From *The Pragmatic Programmer* by Andy Hunt and Dave Thomas:

> "Don't Repeat Yourself" (DRY) applies to more than just code. Use shell scripts to automate repetitive tasks, making your workflow more efficient and less error-prone. Treat your command line as a powerful tool for automation.

These scripts embody this principle by:

1. **Eliminating repetitive typing** - No more manually creating project structures
2. **Ensuring consistency** - Every project starts with the same foundation
3. **Catching issues early** - Environment checks prevent "it works on my machine" problems
4. **Standardizing workflows** - Deployment steps are consistent and repeatable

## Scripts

### `new-node-project.sh`

Scaffolds a complete Node.js/TypeScript project with:

- `package.json` with TypeScript dependencies and build scripts
- `tsconfig.json` with sensible compiler options
- `src/index.ts` starter file
- `.gitignore` with common ignore patterns
- Basic `README.md`

**Usage:**

```bash
./scripts/new-node-project.sh my-app
cd my-app
npm install
npm run build
```

**What it creates:**

```
my-app/
├── package.json
├── tsconfig.json
├── .gitignore
├── README.md
└── src/
    └── index.ts
```

### `dev-env-check.sh`

Checks for installed development tools and reports their versions. Useful for:

- Onboarding new developers
- Verifying CI/CD environment setup
- Troubleshooting "works on my machine" issues

**Usage:**

```bash
./scripts/dev-env-check.sh
```

**Output example:**

```
=== Development Environment Check ===

Core Tools:
✓ Node.js:        v20.10.0
✓ npm:            10.2.3
✓ Git:            git version 2.42.0

Optional Tools:
✓ Docker:         Docker version 24.0.6
✗ Python 3:       not installed

TypeScript Tools:
○ TypeScript:     not installed globally (can install per-project)

=== Summary ===
Installed: 4
Missing: 1
```

**Exit Codes:**
- `0` - All checks passed
- `1` - Core tools missing/failed (required)
- `2` - Optional tools missing/failed (non-critical)
- `3` - Custom checks failed (project-specific)

**Custom Checks:**
You can extend the environment check with project-specific validations (e.g., Supabase connection, Kafka topics, service health endpoints). See `scripts/custom-env-checks.sh.example` for examples.

```bash
# Copy the example and customize
cp scripts/custom-env-checks.sh.example scripts/custom-env-checks.sh
# Edit custom-env-checks.sh to add your checks
# Run: ./scripts/dev-env-check.sh
```

### `simple-deploy.sh`

Simulates a deployment workflow by:

1. Running the project's build script (if present)
2. Copying build output to a `deploy/` directory
3. Creating deployment artifacts with standardized naming

This is a simplified deployment simulation - in production, you'd integrate with actual deployment tools (Docker, Kubernetes, cloud services, etc.).

**Usage:**

```bash
# Deploy current directory
./scripts/simple-deploy.sh

# Deploy a specific project
./scripts/simple-deploy.sh ../my-other-project
```

**What it does:**

1. Checks for `package.json` and runs build command (configurable)
2. Looks for build output in configurable directories (default: `dist/`, `build/`, `out/`)
3. Creates deployment artifacts with standardized naming: `{name}-{version}-{timestamp}.tar.gz`
4. Supports service-specific configurations (frontend, backend, automation)

**Configuration:**

Create `deploy.config.sh` in your project root to customize deployment behavior:

```bash
# Copy the example
cp scripts/deploy.config.sh.example deploy.config.sh

# Customize for your project
# Example: Next.js frontend
DEPLOY_BUILD_CMD_FRONTEND="npm run build && npm run export"
DEPLOY_BUILD_DIRS_FRONTEND="out"
```

**Service Type Detection:**
- Automatically detects service type from directory name (frontend, backend, automation)
- Applies service-specific build commands and output directories
- Supports custom configurations per service type

**Example workflow:**

```bash
cd my-app
npm run build                    # Build the project
../shell-games/scripts/simple-deploy.sh .    # Deploy simulation
ls deploy/                       # Review deployment artifacts
```

## Requirements

- POSIX-compliant shell (bash, dash, zsh)
- Common Unix utilities: `grep`, `sed`, `mkdir`, `cp`, `find`
- Node.js and npm (for projects created with `new-node-project.sh`)
- Git (optional, for version control)

## Portability

These scripts use POSIX shell (`#!/bin/sh`) for maximum portability across:

- macOS
- Linux
- BSD systems
- Windows (via WSL, Git Bash, or Cygwin)

The scripts avoid bash-specific features and use standard Unix commands where possible.

## Best Practices Demonstrated

### Error Handling

All scripts use `set -e` to exit immediately if any command fails:

```bash
set -e
```

### Input Validation

Scripts validate user input before proceeding:

```bash
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name is required" >&2
    exit 1
fi
```

### Clear Output

Scripts provide colored output (when supported) and clear status messages:

```bash
echo "✓ Project created successfully!"
```

### Idempotency

Where possible, scripts check for existing files/directories before creating them to avoid overwriting work.

## Extending the Toolkit

These scripts serve as templates. You can extend them for:

- **Different project types**: Python, Go, Rust, etc.
- **Advanced deployment**: Docker builds, cloud uploads, rollback mechanisms
- **Environment setup**: Database initialization, secret management
- **Testing**: Run test suites before deployment
- **Notifications**: Email/Slack alerts on deployment

### Custom Environment Checks

Add project-specific environment validations:

1. Copy the example: `cp scripts/custom-env-checks.sh.example scripts/custom-env-checks.sh`
2. Implement your custom check functions (e.g., `check_supabase_connection`, `check_kafka_topics`)
3. Add function names to `CUSTOM_CHECKS` variable
4. The checks will run automatically with `dev-env-check.sh`

**Example custom checks:**
- Database connectivity
- External service health endpoints
- Required environment variables
- Infrastructure dependencies (Kafka, Redis, etc.)

### Deployment Configuration

Customize deployment behavior per service type:

1. Copy the example: `cp scripts/deploy.config.sh.example deploy.config.sh`
2. Configure build commands and output directories per service type
3. Customize artifact naming format
4. Deploy with: `./scripts/simple-deploy.sh`

**Configuration options:**
- Service-specific build commands (frontend, backend, automation)
- Custom build output directories
- Standardized artifact naming with placeholders
- Per-service test commands

## Integration Patterns

### 1. NPM Script Integration

All scripts are available as npm commands for easy access:

```json
{
  "scripts": {
    "check-env": "./scripts/dev-env-check.sh",
    "gen:project": "./scripts/new-node-project.sh",
    "deploy": "./scripts/simple-deploy.sh",
    "test:all": "./scripts/test-all.sh",
    "lint:test": "./scripts/lint-and-test.sh"
  }
}
```

**Usage:**
```bash
npm run check-env      # Check development environment
npm run gen:project    # Generate new project (requires argument)
npm run deploy         # Deploy current project
npm run test:all       # Test all services in monorepo
npm run lint:test      # Lint and test all services
```

### 2. Multi-Service Project Support

All scripts support monorepo structures with multiple services:

**Example project structure:**
```
my-project/
├── frontend/
│   ├── package.json
│   └── src/
├── backend/
│   ├── package.json
│   └── src/
├── automation/
│   ├── package.json
│   └── scripts/
└── package.json (root)
```

**Scripts automatically detect and handle:**
- Multiple `package.json` files in subdirectories
- Services at different nesting levels (up to 3 levels deep)
- Root-level projects vs. monorepo structures

**Example usage:**
```bash
# Test all services in a monorepo
./scripts/test-all.sh .

# Deploy all services
./scripts/simple-deploy.sh .

# Lint and test all services
./scripts/lint-and-test.sh .
```

### 3. CI/CD Integration

All scripts support CI/CD environments with the `CI=true` environment variable:

**Features:**
- **Graceful failures**: Optional checks don't fail the build in CI mode
- **Non-interactive**: No prompts or user input required
- **Fail fast**: Core tool checks still fail the build if required tools are missing
- **Clear output**: Works with or without color support

**GitHub Actions Example:**
```yaml
- name: Check development environment
  run: |
    chmod +x scripts/dev-env-check.sh
    CI=true ./scripts/dev-env-check.sh || echo "⚠️ Some optional tools missing (continuing)"

- name: Run tests
  run: |
    chmod +x scripts/test-all.sh
    CI=true ./scripts/test-all.sh

- name: Deploy
  run: |
    chmod +x scripts/simple-deploy.sh
    CI=true ./scripts/simple-deploy.sh .
```

**Key CI/CD Features:**
- Scripts work without interactive prompts
- `chmod +x` ensures scripts are executable in CI
- `CI=true` enables CI mode for all scripts
- Optional tools (like Docker, Python) don't fail the build
- Core tools (Node.js, npm, Git) still fail if missing

## Examples

### Quick Start Workflow

```bash
# 1. Check your environment
./scripts/dev-env-check.sh
# or: npm run check-env

# 2. Create a new project
./scripts/new-node-project.sh my-api
# or: npm run gen:project my-api

# 3. Set up the project
cd my-api
npm install
npm run build

# 4. Simulate deployment
../shell-games/scripts/simple-deploy.sh .
# or: npm run deploy
```

### Multi-Service Workflow

```bash
# 1. Check environment
npm run check-env

# 2. Test all services
npm run test:all

# 3. Lint and test
npm run lint:test

# 4. Deploy all services
npm run deploy
```

## License

This toolkit is provided as-is for educational and practical use.

## References

- *The Pragmatic Programmer* by Andy Hunt and Dave Thomas
- [Shell Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)

