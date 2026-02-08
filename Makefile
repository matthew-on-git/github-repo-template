.PHONY: help init lint format format-fix check clean security security-scan test pre-commit setup ci all
.PHONY: lint-shell lint-python lint-terraform format-shell format-python format-terraform
.PHONY: format-fix-shell format-fix-python format-fix-terraform

# Default target
.DEFAULT_GOAL := help

# Variables
# SCRIPT can be overridden: make lint-shell SCRIPT=my-script.sh
# If not set, will auto-detect shell scripts in the repo root
SCRIPT ?= $(shell find . -maxdepth 1 -type f -name "*.sh" ! -path "./.git/*" | head -1)
PYTHON_FILES := $(shell find . -type f -name "*.py" ! -path "./.git/*" ! -path "./.venv/*" ! -path "./venv/*" ! -path "*/__pycache__/*")
TERRAFORM_FILES := $(shell find . -type f -name "*.tf" ! -path "./.git/*" ! -path "./.terraform/*")
TERRAFORM_DIRS := $(shell find . -type f -name "*.tf" ! -path "./.git/*" ! -path "./.terraform/*" -exec dirname {} \; | sort -u)

SHELLCHECK_OPTS := -e SC1090,SC1091
DOCKER_RUN := docker run --rm -v "$(PWD):/work" -w /work
SHELLCHECK_IMAGE := koalaman/shellcheck:stable
SHFMT_IMAGE := mvdan/shfmt:v3.7.0
GITLEAKS_IMAGE := zricethezav/gitleaks:latest
DETECT_SECRETS_IMAGE := python:3.11-slim
PYLINT_IMAGE := python:3.11-slim
BLACK_IMAGE := python:3.11-slim
TERRAFORM_IMAGE := hashicorp/terraform:latest
TFLINT_IMAGE := ghcr.io/terraform-linters/tflint:latest

help: ## Show this help message
	@echo "Available targets:"
	@echo "  make init          - Install pre-commit hooks"
	@echo "  make security      - Run security scans (Gitleaks + detect-secrets)"
	@echo "  make lint          - Run linting for all detected languages"
	@echo "  make format        - Check formatting for all detected languages"
	@echo "  make format-fix    - Auto-fix formatting for all detected languages"
	@echo "  make check         - Run all checks (security + lint + format)"
	@echo "  make clean         - Remove temporary files"
	@echo ""
	@echo "Language-specific targets:"
	@echo "  make lint-shell    - Lint shell scripts (ShellCheck)"
	@echo "  make lint-python   - Lint Python files (pylint, flake8)"
	@echo "  make lint-terraform - Lint Terraform files (tflint, terraform validate)"
	@echo "  make format-shell  - Format shell scripts (shfmt)"
	@echo "  make format-python - Format Python files (black)"
	@echo "  make format-terraform - Format Terraform files (terraform fmt)"

init: ## Install pre-commit hooks
	@echo "Installing pre-commit hooks..."
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Error: pre-commit not found. Install it with: pip install pre-commit"; \
		exit 1; \
	fi
	pre-commit install
	pre-commit install --hook-type commit-msg
	@echo "✓ Pre-commit hooks installed"

lint: lint-shell lint-python lint-terraform ## Run linting for all detected languages

lint-shell: ## Run ShellCheck on shell scripts
	@if [ -z "$(SCRIPT)" ]; then \
		echo "No shell scripts found. Skipping shell linting."; \
		exit 0; \
	fi
	@echo "Running ShellCheck..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run linting checks."; \
		exit 1; \
	fi
	@echo "Linting: $(SCRIPT)"
	$(DOCKER_RUN) $(SHELLCHECK_IMAGE) $(SHELLCHECK_OPTS) $(SCRIPT)
	@echo "✓ Shell linting passed"

lint-python: ## Run Python linting (pylint, flake8)
	@if [ -z "$(PYTHON_FILES)" ]; then \
		echo "No Python files found. Skipping Python linting."; \
		exit 0; \
	fi
	@echo "Running Python linting..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run linting checks."; \
		exit 1; \
	fi
	@echo "Running pylint..."
	@$(DOCKER_RUN) $(PYLINT_IMAGE) sh -c "pip install -q pylint && pylint --disable=C0111,C0103 --exit-zero --output-format=text $$(find /work -name '*.py' ! -path '/work/.git/*' ! -path '/work/.venv/*' ! -path '/work/venv/*' ! -path '*/__pycache__/*')" || echo "⚠ Pylint found issues (non-fatal)"
	@echo "Running flake8..."
	@$(DOCKER_RUN) $(PYLINT_IMAGE) sh -c "pip install -q flake8 && flake8 --max-line-length=100 --extend-ignore=E203,W503 $$(find /work -name '*.py' ! -path '/work/.git/*' ! -path '/work/.venv/*' ! -path '/work/venv/*' ! -path '*/__pycache__/*')" || (echo "⚠ Flake8 found issues" && exit 1)
	@echo "✓ Python linting passed"

lint-terraform: ## Run Terraform linting (tflint, terraform validate)
	@if [ -z "$(TERRAFORM_FILES)" ]; then \
		echo "No Terraform files found. Skipping Terraform linting."; \
		exit 0; \
	fi
	@echo "Running Terraform linting..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run linting checks."; \
		exit 1; \
	fi
	@echo "Running tflint..."
	@for dir in $(TERRAFORM_DIRS); do \
		echo "Linting Terraform in $$dir..."; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TFLINT_IMAGE) --init || true; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TFLINT_IMAGE) || (echo "⚠ tflint found issues in $$dir" && exit 1); \
	done
	@echo "Running terraform validate..."
	@for dir in $(TERRAFORM_DIRS); do \
		echo "Validating Terraform in $$dir..."; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TERRAFORM_IMAGE) init -backend=false > /dev/null 2>&1 || true; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TERRAFORM_IMAGE) validate || (echo "✗ Terraform validation failed in $$dir" && exit 1); \
	done
	@echo "✓ Terraform linting passed"

format: format-shell format-python format-terraform ## Check formatting for all detected languages

format-shell: ## Check shell script formatting
	@if [ -z "$(SCRIPT)" ]; then \
		echo "No shell scripts found. Skipping shell format check."; \
		exit 0; \
	fi
	@echo "Checking shell script formatting..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting checks."; \
		exit 1; \
	fi
	@echo "Checking format: $(SCRIPT)"
	@$(DOCKER_RUN) $(SHFMT_IMAGE) -i 2 -bn -ci -sr -d $(SCRIPT) || (echo "✗ Formatting issues found. Run 'make format-fix' to fix." && exit 1)
	@echo "✓ Shell formatting check passed"

format-python: ## Check Python formatting (black)
	@if [ -z "$(PYTHON_FILES)" ]; then \
		echo "No Python files found. Skipping Python format check."; \
		exit 0; \
	fi
	@echo "Checking Python formatting..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting checks."; \
		exit 1; \
	fi
	@$(DOCKER_RUN) $(BLACK_IMAGE) sh -c "pip install -q black && black --check --line-length=100 $$(find /work -name '*.py' ! -path '/work/.git/*' ! -path '/work/.venv/*' ! -path '/work/venv/*' ! -path '*/__pycache__/*')" || (echo "✗ Python formatting issues found. Run 'make format-fix' to fix." && exit 1)
	@echo "✓ Python formatting check passed"

format-terraform: ## Check Terraform formatting
	@if [ -z "$(TERRAFORM_FILES)" ]; then \
		echo "No Terraform files found. Skipping Terraform format check."; \
		exit 0; \
	fi
	@echo "Checking Terraform formatting..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting checks."; \
		exit 1; \
	fi
	@for dir in $(TERRAFORM_DIRS); do \
		echo "Checking format in $$dir..."; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TERRAFORM_IMAGE) fmt -check -diff || (echo "✗ Terraform formatting issues found in $$dir. Run 'make format-fix' to fix." && exit 1); \
	done
	@echo "✓ Terraform formatting check passed"

format-fix: format-fix-shell format-fix-python format-fix-terraform ## Auto-fix formatting for all detected languages

format-fix-shell: ## Auto-fix shell script formatting
	@if [ -z "$(SCRIPT)" ]; then \
		echo "No shell scripts found. Nothing to format."; \
		exit 0; \
	fi
	@echo "Formatting shell scripts..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting."; \
		exit 1; \
	fi
	@echo "Formatting: $(SCRIPT)"
	$(DOCKER_RUN) $(SHFMT_IMAGE) -i 2 -bn -ci -sr -w $(SCRIPT)
	@echo "✓ Shell formatting complete"

format-fix-python: ## Auto-fix Python formatting (black)
	@if [ -z "$(PYTHON_FILES)" ]; then \
		echo "No Python files found. Nothing to format."; \
		exit 0; \
	fi
	@echo "Formatting Python files..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting."; \
		exit 1; \
	fi
	@$(DOCKER_RUN) $(BLACK_IMAGE) sh -c "pip install -q black && black --line-length=100 $$(find /work -name '*.py' ! -path '/work/.git/*' ! -path '/work/.venv/*' ! -path '/work/venv/*' ! -path '*/__pycache__/*')"
	@echo "✓ Python formatting complete"

format-fix-terraform: ## Auto-fix Terraform formatting
	@if [ -z "$(TERRAFORM_FILES)" ]; then \
		echo "No Terraform files found. Nothing to format."; \
		exit 0; \
	fi
	@echo "Formatting Terraform files..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run formatting."; \
		exit 1; \
	fi
	@for dir in $(TERRAFORM_DIRS); do \
		echo "Formatting Terraform in $$dir..."; \
		$(DOCKER_RUN) -v "$(PWD)/$$dir:/work" -w /work $(TERRAFORM_IMAGE) fmt -recursive; \
	done
	@echo "✓ Terraform formatting complete"

check: security lint format ## Run all checks (security + lint + format)

# Additional targets (not shown in help, but available)
setup: init ## Set up development environment (install hooks)
	@echo "✓ Development environment set up"

clean: ## Clean temporary files
	@echo "Cleaning temporary files..."
	@find . -type f -name "*.bak" -delete
	@find . -type f -name "*.tmp" -delete
	@find . -type f -name "*.swp" -delete
	@find . -type f -name "*~" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✓ Clean complete"

security: security-scan ## Run security scans (Gitleaks + detect-secrets)

security-scan: ## Run security scanning (Gitleaks, detect-secrets)
	@echo "Running security scans..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "Error: docker not found. Install Docker to run security scans."; \
		exit 1; \
	fi
	@echo "Running Gitleaks..."
	@$(DOCKER_RUN) $(GITLEAKS_IMAGE) detect --verbose --no-banner --source /work || (echo "⚠ Gitleaks found potential secrets. Review the output above." && exit 1)
	@echo "✓ Gitleaks scan passed"
	@echo "Running detect-secrets..."
	@if [ ! -f .secrets.baseline ]; then \
		echo "Creating .secrets.baseline..."; \
		$(DOCKER_RUN) $(DETECT_SECRETS_IMAGE) sh -c "pip install -q detect-secrets && detect-secrets scan --baseline .secrets.baseline" || true; \
	fi
	@$(DOCKER_RUN) $(DETECT_SECRETS_IMAGE) sh -c "pip install -q detect-secrets && detect-secrets audit .secrets.baseline --report --json" || (echo "⚠ detect-secrets found potential secrets. Review with: detect-secrets audit .secrets.baseline" && exit 1)
	@echo "✓ detect-secrets scan passed"
	@echo "✓ Security scanning complete"

# Additional targets (not shown in help, but available)
test: ## Run syntax and basic tests (if shell scripts exist)
	@if [ -z "$(SCRIPT)" ]; then \
		echo "No shell scripts found. Skipping tests."; \
		exit 0; \
	fi
	@echo "Running syntax check..."
	@bash -n $(SCRIPT) || (echo "✗ Syntax check failed" && exit 1)
	@echo "✓ Syntax check passed"
	@if [ -x "$(SCRIPT)" ] && ./$(SCRIPT) --help > /dev/null 2>&1; then \
		echo "Testing help output..."; \
		./$(SCRIPT) --help | head -5 > /dev/null 2>&1 || (echo "✗ Help test failed" && exit 1); \
		echo "✓ Help test passed"; \
	fi

pre-commit: ## Run pre-commit hooks on all files
	@echo "Running pre-commit hooks..."
	@if ! command -v pre-commit >/dev/null 2>&1; then \
		echo "Error: pre-commit not found. Install it with: pip install pre-commit"; \
		exit 1; \
	fi
	pre-commit run --all-files

ci: lint test ## Run CI checks (for GitHub Actions)

all: check test ## Run all checks, validations, and security scans
