# Sandbox management — include from your project Makefile:
#   include .openshell/Makefile

.PHONY: help-sandbox sandbox sandbox-build sandbox-stop sandbox-shell sandbox-nuke

help-sandbox:
	@printf '%s\n' \
	"Sandbox:" \
	"  make sandbox-build    Build/rebuild the sandbox image" \
	"  make sandbox          Start, restart, or attach to sandbox" \
	"  make sandbox-shell    Open another shell into running sandbox" \
	"  make sandbox-stop     Stop sandbox (state preserved)" \
	"  make sandbox-nuke     Destroy sandbox and all state" \
	""

SANDBOX_NAME = $(REPO_NAME)-sandbox
SANDBOX_IMAGE = $(REPO_NAME)-sandbox

# Build the sandbox image and reset state (only needed when .openshell/ changes)
sandbox-build:
	@printf '\033[1;31mWarning: This will rebuild the image and destroy all sandbox state\033[0m\n'
	@printf '\033[1;31m(auth tokens, shell history, Mason LSPs, etc.)\033[0m\n'
	@printf 'Continue? [y/N] '; \
	read answer; \
	if [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi
	docker rm -f $(SANDBOX_NAME) 2>/dev/null || true
	docker volume rm $(SANDBOX_NAME)-home 2>/dev/null || true
	docker build -t $(SANDBOX_IMAGE) -f .openshell/Dockerfile .openshell/
	@echo "Done. Run 'make sandbox' to start fresh."

# Start sandbox in background with repo mounted, or attach if already running.
# Named volumes persist auth tokens, shell history, Mason LSPs, etc. across restarts.
sandbox:
	@if docker ps --format '{{.Names}}' | grep -q '^$(SANDBOX_NAME)$$'; then \
		echo "Attaching to running sandbox..."; \
		docker exec -it $(SANDBOX_NAME) zsh; \
	elif docker ps -a --format '{{.Names}}' | grep -q '^$(SANDBOX_NAME)$$'; then \
		echo "Restarting stopped sandbox..."; \
		docker start $(SANDBOX_NAME); \
		docker exec -it $(SANDBOX_NAME) zsh; \
	else \
		echo "Starting sandbox..."; \
		mkdir -p "$$(pwd)/../worktree"; \
		docker run -d \
			--name $(SANDBOX_NAME) \
			-v "$$(pwd):/$(REPO_NAME)" \
			-v "$$(pwd)/../worktree:/worktree" \
			-w "/$(REPO_NAME)" \
			-v "$$SSH_AUTH_SOCK:/ssh-agent" \
			-e SSH_AUTH_SOCK=/ssh-agent \
			-v $(SANDBOX_NAME)-home:/home/sandbox \
			$(SANDBOX_IMAGE) sleep infinity; \
		docker exec -u root $(SANDBOX_NAME) chmod 777 /ssh-agent 2>/dev/null || true; \
		docker exec -it $(SANDBOX_NAME) zsh; \
	fi

# Open another shell into a running sandbox
sandbox-shell:
	docker exec -it $(SANDBOX_NAME) zsh

# Stop the sandbox (state preserved, `make sandbox` will restart it)
sandbox-stop:
	docker stop $(SANDBOX_NAME) 2>/dev/null || true

# Destroy sandbox and all persisted state (clean slate)
sandbox-nuke:
	docker rm -f $(SANDBOX_NAME) 2>/dev/null || true
	docker volume rm $(SANDBOX_NAME)-home 2>/dev/null || true
	@echo "Sandbox destroyed. Run 'make sandbox' to start fresh."
