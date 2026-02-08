# GitHub Repository Template

A comprehensive template repository with pre-configured CI/CD pipelines, code quality checks, security scanning, and multi-language support.

## Features

- **Multi-language Support**: Automatic detection and linting/formatting for:
  - Shell scripts (`.sh`)
  - Python (`.py`)
  - Terraform (`.tf`)
- **Security Scanning**: Automated secret detection with Gitleaks and detect-secrets
- **Pre-commit Hooks**: Enforces code quality before commits
- **CI/CD Pipelines**: GitHub Actions workflows for automated testing and releases
- **Conventional Commits**: Enforces commit message standards
- **Docker-based Tools**: Consistent tooling across all environments

## Quick Start

### 1. Use This Template

Click "Use this template" on GitHub or clone this repository:

```bash
git clone <your-repo-url>
cd <your-repo-name>
```

### 2. Initialize Pre-commit Hooks

```bash
make init
```

This installs pre-commit hooks that will run automatically on every commit.

### 3. Run Checks Locally

```bash
# Run all checks (security, lint, format)
make check

# Or run individually:
make security  # Security scans
make lint      # Lint all detected languages
make format    # Check formatting
make test      # Run tests
```

## Available Make Targets

### Setup
- `make init` - Install pre-commit hooks
- `make setup` - Set up development environment

### Code Quality
- `make lint` - Run linting for all detected languages
- `make format` - Check formatting for all detected languages
- `make format-fix` - Auto-fix formatting issues
- `make check` - Run all checks (security + lint + format)

### Security
- `make security` - Run security scans (Gitleaks + detect-secrets)

### Testing
- `make test` - Run syntax and basic tests

### Maintenance
- `make clean` - Remove temporary files and caches
- `make pre-commit` - Run pre-commit hooks manually on all files
- `make ci` - Run CI checks (for GitHub Actions)
- `make all` - Run all checks, validations, and security scans

### Language-Specific Targets

#### Shell Scripts
- `make lint-shell` - Lint shell scripts (ShellCheck)
- `make format-shell` - Check shell script formatting
- `make format-fix-shell` - Auto-fix shell script formatting

#### Python
- `make lint-python` - Lint Python files (pylint, flake8)
- `make format-python` - Check Python formatting (black)
- `make format-fix-python` - Auto-fix Python formatting

#### Terraform
- `make lint-terraform` - Lint Terraform files (tflint, terraform validate)
- `make format-terraform` - Check Terraform formatting
- `make format-fix-terraform` - Auto-fix Terraform formatting

## Pre-commit Hooks

The repository includes pre-commit hooks that automatically:

- **Conventional Commits**: Validates commit message format
- **Secret Detection**: Scans for hardcoded secrets (Gitleaks, detect-secrets)
- **Code Formatting**: Auto-formats shell scripts, Python, and Terraform
- **Linting**: Runs ShellCheck on shell scripts
- **File Checks**: Validates YAML, JSON, TOML, and other common issues

### Manual Pre-commit Run

```bash
# Run on all files
make pre-commit

# Or directly
pre-commit run --all-files
```

## CI/CD Pipelines

### Continuous Integration (CI)

The CI pipeline runs on every push and pull request:

1. **Lint Job**: Runs `make lint` to check code quality
2. **Format Job**: Runs `make format` to verify formatting
3. **Security Job**: Runs `make security` for secret detection
4. **Test Job**: Runs `make test` for basic validation

### Release Pipeline

Automatically creates releases when pushing to `main` or `master`:

- **Versioning**: Automatic semantic versioning based on conventional commits
  - `feat:` → Minor version bump
  - `fix:` → Patch version bump
- **Changelog**: Auto-generated from commit messages
- **Security Check**: Runs security scans before release

### Skipping Releases

Add `[skip release]` to your commit message to skip automatic release creation.

## Requirements

- **Docker**: Required for running linting, formatting, and security tools
- **Python 3**: Required for pre-commit hooks
- **Make**: Required for running make targets (usually pre-installed on Unix systems)

### Installing Dependencies

```bash
# Install pre-commit
pip install pre-commit

# Or via package manager
brew install pre-commit  # macOS
apt-get install pre-commit  # Debian/Ubuntu
```

## Project Structure

```
.
├── .github/
│   └── workflows/
│       ├── ci.yml          # Continuous Integration workflow
│       └── release.yml      # Release automation workflow
├── .pre-commit-config.yaml  # Pre-commit hooks configuration
├── Makefile                 # Main build and check system
├── LICENSE                  # License file
└── README.md               # This file
```

## Customization

### Adding New Languages

The Makefile auto-detects files by extension. To add support for a new language:

1. Add detection variables in the Makefile
2. Create lint/format targets following the existing pattern
3. Add pre-commit hooks if desired

### Overriding Script Detection

For shell scripts, you can override the auto-detected script:

```bash
make lint-shell SCRIPT=my-custom-script.sh
```

### Modifying Security Scans

Security scans are configured in the Makefile. The `.secrets.baseline` file tracks known false positives for detect-secrets.

## Troubleshooting

### Pre-commit Hooks Not Running

```bash
# Reinstall hooks
make init

# Or manually
pre-commit install
pre-commit install --hook-type commit-msg
```

### Docker Not Found

All linting and formatting tools require Docker. Install Docker Desktop or Docker Engine for your platform.

### Baseline File Issues

If detect-secrets fails, the baseline file may need to be regenerated:

```bash
# The Makefile will create it automatically, or manually:
docker run --rm -v "$(PWD):/work" -w /work python:3.11-slim \
  sh -c "pip install -q detect-secrets && detect-secrets scan --all-files . > .secrets.baseline"
```

### No Files Found Errors

The Makefile gracefully skips checks when no files of a given type are found. This is normal for repositories that don't use all supported languages.

## Contributing

1. Make changes
2. Run `make check` to verify everything passes
3. Commit using conventional commit format (e.g., `feat: add new feature`)
4. Push and create a pull request

## License

See [LICENSE](LICENSE) file for details.

## Support

For issues or questions, please open an issue on GitHub.
