# Shell Games Toolkit

A collection of reusable shell scripts that automate common development tasks. These scripts demonstrate the "Shell Games" principle from *The Pragmatic Programmer* - using shell scripts to automate repetitive tasks and make your development workflow more efficient.

## Overview

This toolkit provides three essential scripts:

- **`new-node-project.sh`** - Scaffold a new Node.js/TypeScript project with sensible defaults
- **`dev-env-check.sh`** - Verify that required development tools are installed
- **`simple-deploy.sh`** - Simulate a deployment workflow (build + copy to deploy folder)

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

The script exits with code 0 if all core tools are installed, or 1 if any are missing.

### `simple-deploy.sh`

Simulates a deployment workflow by:

1. Running the project's build script (if present)
2. Copying build output to a `deploy/` directory
3. Creating deployment metadata

This is a simplified deployment simulation - in production, you'd integrate with actual deployment tools (Docker, Kubernetes, cloud services, etc.).

**Usage:**

```bash
# Deploy current directory
./scripts/simple-deploy.sh

# Deploy a specific project
./scripts/simple-deploy.sh ../my-other-project
```

**What it does:**

1. Checks for `package.json` and runs `npm run build` if available
2. Looks for build output in `dist/`, `build/`, or `out/` directories
3. Copies build artifacts to `deploy/`
4. Creates a `.deploy-info` file with deployment metadata

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

## Examples

### Quick Start Workflow

```bash
# 1. Check your environment
./scripts/dev-env-check.sh

# 2. Create a new project
./scripts/new-node-project.sh my-api

# 3. Set up the project
cd my-api
npm install
npm run build

# 4. Simulate deployment
../shell-games/scripts/simple-deploy.sh .
```

### CI/CD Integration

You can integrate these scripts into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Check environment
  run: ./scripts/dev-env-check.sh

- name: Build project
  run: npm run build

- name: Deploy
  run: ./scripts/simple-deploy.sh .
```

## License

This toolkit is provided as-is for educational and practical use.

## References

- *The Pragmatic Programmer* by Andy Hunt and Dave Thomas
- [Shell Script Best Practices](https://google.github.io/styleguide/shellguide.html)
- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)

