# Sandbox management — include from your project Makefile:
#   include .openshell/Makefile

.PHONY: help-sandbox bootstrap sandbox sandbox-build sandbox-clean sandbox-stop sandbox-shell sandbox-nuke

# K8s names must be DNS-1035: lowercase alphanumeric + hyphens only
SANDBOX_NAME = $(shell echo "$(REPO_NAME)-sandbox" | tr '.' '-' | tr '[:upper:]' '[:lower:]')

help-sandbox:
	@printf '%s\n' \
	"Sandbox (OpenShell + mutagen):" \
	"  make bootstrap        Install dependencies (openshell, gh, mutagen) and auth" \
	"  make sandbox-build    Create sandbox, run setup, start sync (one-time)" \
	"  make sandbox          Connect to sandbox (builds if needed)" \
	"  make sandbox-shell    Alias for sandbox" \
	"  make sandbox-clean    Reset repo sync (keeps sandbox + tools)" \
	"  make sandbox-stop     Stop sync, delete sandbox, clean up" \
	"  make sandbox-nuke     sandbox-stop + wipe bootstrap cache (full re-download)" \
	""

# Install sandbox dependencies and configure auth.
bootstrap:
	@echo "==> Checking homebrew dependencies..."
	@for pkg in gh mutagen-io/mutagen/mutagen; do \
		name=$$(echo "$$pkg" | sed 's|.*/||'); \
		if brew list "$$pkg" >/dev/null 2>&1; then \
			echo "  [ok] $$name already installed"; \
		else \
			echo "  [..] Installing $$name..."; \
			brew install "$$pkg"; \
		fi; \
	done
	@echo ""
	@echo "==> Checking openshell CLI..."
	@if command -v openshell >/dev/null 2>&1; then \
		echo "  [ok] openshell already installed: $$(openshell --version 2>/dev/null || echo 'unknown version')"; \
	else \
		echo "  [..] Installing openshell..."; \
		curl -LsSf https://raw.githubusercontent.com/NVIDIA/OpenShell/main/install.sh | sh; \
		echo "  Ensure ~/.local/bin is in your PATH:"; \
		echo '    export PATH="$$HOME/.local/bin:$$PATH"'; \
	fi
	@echo ""
	@echo "==> Checking GitHub CLI auth..."
	@if gh auth status >/dev/null 2>&1; then \
		echo "  [ok] gh is authenticated"; \
	else \
		echo "  [..] gh is not authenticated. Starting login..."; \
		echo "  (Select HTTPS as preferred protocol for git operations)"; \
		gh auth login; \
	fi

# Create sandbox, run setup, start sync. Idempotent.
sandbox-build:
	@.openshell/sandbox.sh build $(SANDBOX_NAME)

# Connect to sandbox (builds first if needed)
sandbox: sandbox-build
	@.openshell/sandbox.sh connect $(SANDBOX_NAME)

# Alias
sandbox-shell: sandbox

# Light reset: re-sync repo files, keep sandbox and tools
sandbox-clean:
	@.openshell/sandbox.sh clean $(SANDBOX_NAME)

# Stop sandbox: terminate sync, delete sandbox, clean up
sandbox-stop:
	@.openshell/sandbox.sh stop $(SANDBOX_NAME)

# Nuclear reset: stop + wipe bootstrap cache so everything re-downloads on next build
sandbox-nuke:
	@.openshell/sandbox.sh nuke $(SANDBOX_NAME)
