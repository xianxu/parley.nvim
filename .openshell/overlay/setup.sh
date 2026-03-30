#!/bin/bash
# One-shot setup for OpenShell sandbox — agent runtime, not dev environment.
# Installs minimal tooling needed to run tests and agent workflows.
# Everything installs to $HOME — no root needed.
set -euo pipefail

mkdir -p "$HOME/.local/bin"

echo "==> Installing Neovim 0.11..."
curl -fsSL https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-arm64.tar.gz \
    | tar xz -C "$HOME/.local"
ln -sf "$HOME/.local/nvim-linux-arm64/bin/nvim" "$HOME/.local/bin/nvim"

echo "==> Configuring shell..."
cat >> "$HOME/.bashrc" << 'BASHEOF'

# Added by openshell overlay setup
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"

# AI agent sandbox permissions — agents get full auto-approve
alias claude="claude --permission-mode bypassPermissions"
alias codex="codex --full-auto"
export GEMINI_CLI_AUTO_APPROVE=true
BASHEOF

echo "==> Configuring git..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
# OpenShell proxy terminates TLS — sandbox doesn't have its CA cert
git config --global http.sslVerify false

echo "==> Creating workspace dirs..."
mkdir -p "$HOME/repo" "$HOME/worktree"
mkdir -p "$HOME/.local/share/nvim/lazy"

echo "==> Done."
