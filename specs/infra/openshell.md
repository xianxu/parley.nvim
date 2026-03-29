# OpenShell Sandbox Environment

## Purpose
Hermetic, one-command development sandbox using NVIDIA OpenShell. Replicates the host Mac dev environment in an isolated Linux container for agentic coding workflows.

## Structure
```
.openshell/
├── Dockerfile          # Custom sandbox image (ubuntu:24.04 base, swap to OpenShell base when available)
├── policy.yaml         # Network/filesystem isolation policy
└── dotfiles/
    ├── zshrc           # Portable zsh config (oh-my-zsh, vi-mode, aliases)
    └── nvim/           # Full neovim config snapshot (lazy.nvim, plugins, spell)
bootstrap.sh            # One-command sandbox creation
```

## What's Installed
- **Shell**: zsh + oh-my-zsh (af-magic), fzf-tab, zsh-autosuggestions, fast-syntax-highlighting
- **Editor**: neovim with full plugin suite via lazy.nvim
- **CLI**: ripgrep, fd, fzf, zoxide, bat, tree, ack, gh
- **Languages**: Node.js (nvm), Lua 5.4 + luarocks, Python 3, Go

## Usage
```bash
./bootstrap.sh              # creates sandbox named after current directory
./bootstrap.sh my-sandbox   # custom name
openshell sandbox connect <name>
```

## Policy
- Filesystem: writable `/sandbox`, `/tmp`, `/home/sandbox`
- Network: allows GitHub, npm, PyPI, Go proxy, Anthropic API, OpenAI API; denies all else

## History
- 2026-03-28: Initial creation (issue 000010)
