---
id: 000024
status: done
deps: []
created: 2026-03-29
updated: 2026-04-02
---

# claude code installer change to native

got warnning from when claude's installed via npm

    Claude Code has switched from npm to native installer. Run `claude install` or…

We should use that native install method in the openshell container setup

## Resolution

No action needed on our side. The OpenShell community base image already ships Claude Code via native installer (single 220MB ELF binary at `~/.local/share/claude/versions/`). Our old custom Dockerfile that did `npm install -g @anthropic-ai/claude-code` was dead code — removed as part of cleanup.

To keep versions current, added a base image update check: `make sandbox` now compares the GHCR registry digest against a locally saved digest and prompts user to rebuild when a newer image is available.

## Done when

- [x] No npm-based claude install in active code paths
- [x] Old Dockerfile removed
- [x] Base image update probe added to detect when newer claude/codex versions are available

## Log

### 2026-04-02
- Investigated: Claude Code is a single ELF binary (not Node.js app), installed via native installer in base image
- Codex is still npm-based (`@openai/codex`), also ships in base image
- Removed dead code: Dockerfile, dotfiles/nvim/, overlay/deps/ — all from old Docker-based approach
- Cleaned up specs/infra/openshell.md to match current state
- Base image update check added (GHCR digest comparison on `make sandbox`)

### 2026-03-29
- Issue created
