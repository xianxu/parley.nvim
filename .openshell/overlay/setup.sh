#!/bin/bash
# One-shot setup for OpenShell sandbox — agent runtime, not dev environment.
# Installs minimal tooling needed to run tests and agent workflows.
# Everything installs to $HOME — no root needed.
#
# Dependencies live in deps/*.sh — comment out lines below to disable.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$HOME/.local/bin"

# ── Git config ───────────────────────────────────────────────────────────────
echo "==> Configuring git..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
# OpenShell proxy terminates TLS — sandbox doesn't have its CA cert
git config --global http.sslVerify false

# ── Dependencies (comment out to disable) ────────────────────────────────────
source "$SCRIPT_DIR/deps/neovim.sh"
source "$SCRIPT_DIR/deps/zellij.sh"
source "$SCRIPT_DIR/deps/oh-my-bash.sh"
source "$SCRIPT_DIR/deps/lua.sh"

# ── Shell config ─────────────────────────────────────────────────────────────
echo "==> Configuring shell..."
cat >> "$HOME/.bashrc" << 'BASHEOF'

# Added by openshell overlay setup
export PATH="$HOME/.luarocks/bin:$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# Vi mode
set -o vi
bind '"\C-r": reverse-search-history'
bind '"\C-s": forward-search-history'

# Aliases
alias v=nvim
alias s="git status"
alias ss="git diff --stat"
alias a="git add"
alias d="git diff"
alias p="git commit -a; git push"
alias todo="nvim tasks/todo.md"
alias issue="nvim tasks/issue.md"
alias lesson="nvim tasks/lessons.md"

# AI agent sandbox permissions — agents get full auto-approve
alias claude="claude --permission-mode bypassPermissions"
alias codex="codex --full-auto"
export GEMINI_CLI_AUTO_APPROVE=true
BASHEOF

# ── Workspace dirs ───────────────────────────────────────────────────────────
echo "==> Creating workspace dirs..."
mkdir -p "$HOME/repo" "$HOME/worktree"
mkdir -p "$HOME/.local/share/nvim/lazy"

echo "==> Done."
