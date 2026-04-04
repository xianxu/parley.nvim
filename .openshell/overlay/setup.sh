#!/bin/bash
# One-shot setup for OpenShell sandbox — git config, shell config, workspace dirs.
# Dependency installation is handled by post-install.sh (from bootstrap cache).
# Idempotent: safe to re-run (e.g. via `make sandbox-clean`).
set -euo pipefail

mkdir -p "$HOME/.local/bin"

# ── Git config ───────────────────────────────────────────────────────────────
echo "==> Configuring git..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
# OpenShell proxy terminates TLS — sandbox doesn't have its CA cert
git config --global http.sslVerify false

# ── Shell config ─────────────────────────────────────────────────────────────
echo "==> Configuring shell..."
# Remove old block if present (idempotent)
sed -i '/^# BEGIN openshell-overlay/,/^# END openshell-overlay/d' "$HOME/.bashrc"
cat >> "$HOME/.bashrc" << 'BASHEOF'
# BEGIN openshell-overlay
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
alias zl="zellij list-sessions"
alias ze="zellij"
alias za="zellij a"
alias tl="tmux list-sessions"
alias ta="tmux attach -t"
alias tn="tmux new -s"

# AI agent sandbox permissions — agents get full auto-approve
alias claude="claude --permission-mode bypassPermissions"
alias codex="codex --full-auto"
export GEMINI_CLI_AUTO_APPROVE=true
# END openshell-overlay
BASHEOF

# ── Workspace dirs ───────────────────────────────────────────────────────────
echo "==> Creating workspace dirs..."
mkdir -p "$HOME/repo" "$HOME/worktree"
mkdir -p "$HOME/.local/share/nvim/lazy"

# ── Credentials (from bootstrap cache) ──────────────────────────────────────
CREDS="/tmp/bootstrap/credentials"
if [ -d "$CREDS" ]; then
    echo "==> Distributing credentials..."
    if [ -f "$CREDS/codex-auth.json" ]; then
        mkdir -p "$HOME/.codex"
        cp "$CREDS/codex-auth.json" "$HOME/.codex/auth.json"
        echo "  [ok] codex auth"
    fi
fi

echo "==> Done."
