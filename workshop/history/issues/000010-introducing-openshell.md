---
id: 000010
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# introducing openshell

see discussion in ../design/2026-03-28.18-37-34.270.md, and design bootstrap with openshell integrated. 

1. there should be a single command to set up everything
2. I should be able to log into the machine with similar working environment. check my files to see what you need to install by default
   1. check my nvim setting in ~/.config/nvim
   2. check my ~/.zshrc (there's oh-my-zsh)
   3. check my homebrew file in ~/settings/brewfile

## Done when

- `.openshell/` directory with Dockerfile, policy.yaml, dotfiles checked in
- `bootstrap.sh` at repo root creates sandbox with one command
- Dockerfile builds successfully

## Plan

- [x] Create `.openshell/Dockerfile` with core tools, shell, languages
- [x] Create `.openshell/policy.yaml` with network/filesystem policy
- [x] Create `.openshell/dotfiles/zshrc` (portable version of ~/.zshrc)
- [x] Copy nvim config into `.openshell/dotfiles/nvim/`
- [x] Create `bootstrap.sh` at repo root
- [x] Verify Dockerfile builds
- [x] User verifies end-to-end

## Verification Steps (for you to run)

### 1. Build the image
```bash
cd ~/workspace/parley.nvim
docker build -t parley-sandbox -f .openshell/Dockerfile .openshell/
```
Takes ~2 min on first build, cached after.

### 2. Smoke-test tools
```bash
docker run --rm parley-sandbox zsh -c '
  source ~/.zshrc 2>/dev/null
  nvim --version | head -1
  node --version
  lua5.4 -v
  python3 --version
  go version
  rg --version | head -1
  gh --version | head -1
  echo "ZSH theme: $(grep ZSH_THEME ~/.zshrc | head -1)"
  echo "Plugins: $(ls ~/.oh-my-zsh/custom/plugins/)"
'
```
Expected: neovim 0.9+, node 24+, lua 5.4, python 3.12, go 1.22, ripgrep, gh, af-magic theme, fzf-tab/zsh-autosuggestions/fast-syntax-highlighting.

### 3. Interactive shell test
```bash
docker run --rm -it parley-sandbox zsh
```
You should get af-magic prompt, vi-mode, autosuggestions, syntax highlighting. Try:
- `v` (alias for nvim) — should open neovim with your full config
- `s` (alias for git status)
- `rg`, `fzf`, `gh`, `node`, `python3`, `go version`
- `Ctrl-R` for history search

### 4. Full workflow with OpenShell (when available)
```bash
./bootstrap.sh
openshell sandbox connect parley.nvim
```

## Dev Workflow (new)

### Without OpenShell (Docker only — available now)
```bash
# Build once
docker build -t parley-sandbox -f .openshell/Dockerfile .openshell/

# Run with your repo mounted
docker run --rm -it -v $(pwd):/sandbox parley-sandbox zsh

# Inside: edit code, run tests, use nvim — all tools available
# Changes to /sandbox are live-synced to your host via the mount
```

### With OpenShell (when it goes public)
```bash
# One command — creates sandbox, syncs repo, drops you into zsh
./bootstrap.sh

# Reconnect later
openshell sandbox connect parley.nvim

# Sync changes back
openshell sandbox download parley.nvim /sandbox ./
```

### Updating the sandbox environment
1. Edit `.openshell/Dockerfile` or `.openshell/dotfiles/*`
2. Rebuild: `docker build -t parley-sandbox -f .openshell/Dockerfile .openshell/`
3. If you change your local nvim config, re-sync:
   ```bash
   rsync -av --exclude='~/Library*' ~/.config/nvim/ .openshell/dotfiles/nvim/
   ```

### For agentic coding (the end goal)
```bash
# Docker version (now)
docker run --rm -it -v $(pwd):/sandbox parley-sandbox zsh -c 'claude'

# OpenShell version (later) — with network policy enforcement
./bootstrap.sh
openshell sandbox connect parley.nvim
# Inside: run claude code, codex, etc — sandboxed by policy.yaml
```

## Log

### 2026-03-28
- Reviewed user's ~/.zshrc, ~/.config/nvim/, ~/settings/brewfile
- Decided: copy nvim config into repo (hermetic), languages: Node+Lua+Python+Go
- Fixed: oh-my-zsh overwrites .zshrc, so dotfiles COPY must come after omz install
- Fixed: nvm/omz must install as sandbox user, not root
- Verified: docker build succeeds, all tools present and working

