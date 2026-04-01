#!/bin/bash
# One-shot setup for OpenShell sandbox — agent runtime, not dev environment.
# Installs minimal tooling needed to run tests and agent workflows.
# Everything installs to $HOME — no root needed.
set -euo pipefail

mkdir -p "$HOME/.local/bin"

echo "==> Configuring git..."
git config --global url."https://github.com/".insteadOf "git@github.com:"
git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
# OpenShell proxy terminates TLS — sandbox doesn't have its CA cert
git config --global http.sslVerify false

echo "==> Installing Neovim 0.11..."
curl -fsSL https://github.com/neovim/neovim/releases/download/v0.11.6/nvim-linux-arm64.tar.gz \
    | tar xz -C "$HOME/.local"
ln -sf "$HOME/.local/nvim-linux-arm64/bin/nvim" "$HOME/.local/bin/nvim"

echo "==> Installing Zellij..."
curl -fsSL https://github.com/zellij-org/zellij/releases/latest/download/zellij-aarch64-unknown-linux-musl.tar.gz \
    | tar xz -C "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/zellij"

echo "==> Installing Oh My Bash..."
OSH="$HOME/.oh-my-bash" bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended

echo "==> Configuring shell..."
cat >> "$HOME/.bashrc" << 'BASHEOF'

# Added by openshell overlay setup
export PATH="$HOME/.local/bin:$PATH"
export LANG=en_US.UTF-8
export EDITOR="nvim"
export VISUAL="nvim"

# Vi mode
set -o vi
bind '"\C-r": reverse-search-history'
bind '"\C-s": forward-search-history'

# Git aliases
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

echo "==> Creating workspace dirs..."
mkdir -p "$HOME/repo" "$HOME/worktree"
mkdir -p "$HOME/.local/share/nvim/lazy"

echo "==> Done."
