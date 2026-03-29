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
make sandbox-build          # build/rebuild image (destroys state)
make sandbox                # start, restart, or attach
make sandbox-shell          # open another shell
make sandbox-stop           # stop (state preserved)
make sandbox-nuke           # destroy all state
```

## Mount Layout
- Repo mounted at `/{repo-name}` (e.g., `/parley.nvim`), set as working directory
- `../worktree` mounted at `/worktree` — enables `make issue`/`make worktree` inside container
- `../worktree` from `/{repo-name}` resolves to `/worktree`, so relative paths are portable

## Policy
- Filesystem: writable `/{repo-name}`, `/worktree`, `/tmp`, `/home/sandbox`
- Network: allows GitHub, npm, PyPI, Go proxy, Anthropic API, OpenAI API; denies all else

## History
- 2026-03-29: Mount as /{repo-name}, add /worktree mount, portable worktree paths (issue 000014)
- 2026-03-28: Initial creation (issue 000010)
