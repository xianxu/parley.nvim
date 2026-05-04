# OpenShell Sandbox in the Workflow

The OpenShell sandbox is a containerized Linux dev environment that runs alongside the host. It's part of ariadne's base layer — any repo that adopts ariadne gets sandbox support via `.openshell/`.

## Why a Sandbox

- **Consistent environment**: Linux container regardless of host OS
- **Network isolation**: allowlisted egress only (GitHub, package registries, AI APIs)
- **Safe for AI agents**: agents get `--permission-mode bypassPermissions` inside the sandbox
- **Parallel to host**: mutagen keeps repo, git state, worktrees, and nvim state in sync

## Setup (One-Time)

```bash
make bootstrap      # install prerequisites (openshell CLI, gh, mutagen)
make sandbox        # create container, sync repo, install tools, connect
```

First run downloads a small bootstrap cache (~50MB: nvim, zellij, oh-my-bash, lua, luacheck) to `.openshell/.bootstrap/` on the host, syncs it into the container, then installs. Subsequent runs reuse the cache.

## Daily Use

```bash
make sandbox        # connect (builds if needed)
make sandbox-clean  # re-apply config + reconnect with fresh shell
make sandbox-nuke   # destroy everything, re-download bootstrap cache
```

Inside the sandbox, zellij is the terminal multiplexer (leader: `Ctrl+q`, new tab: `Alt+t`, panes: `Alt+arrows`, search scrollback: `Alt+/`). Config lives in `.openshell/dotfiles/zellij/`.

## What's Inside the Container

- **Shell**: bash with vi mode, oh-my-bash
- **Editor**: neovim (synced nvim state from host)
- **Multiplexer**: zellij (gruvbox-dark theme)
- **Languages**: lua 5.4 + luacheck (for neovim plugin development)
- **AI agents**: claude (bypass permissions), codex (full-auto), gemini (auto-approve)
- **Git**: configured from host (name, email, gh auth forwarded)

## How It's Provided by the Base Layer

The `.openshell/` directory is listed in `construct/base.manifest`. In symlink mode, contents point back to ariadne. In vendor mode, files are copied.

**Key convention**: all runtime state is local to each repo. Scripts derive paths from how they're invoked (`$0`), not from where they physically live. See [Base Layer](base-layer.md) for the path resolution rules.

### Files (git-controlled, from base layer)

| Path | Purpose |
|---|---|
| `.openshell/sandbox.sh` | Lifecycle orchestrator (build, connect, clean, stop, nuke) |
| `.openshell/Makefile` | Make targets included by repo Makefile |
| `.openshell/overlay/bootstrap.sh` | Host-side dependency downloader |
| `.openshell/overlay/post-install.sh` | Sandbox-side installer (from bootstrap cache) |
| `.openshell/overlay/setup.sh` | Shell config, aliases, output capture (^Y) |
| `.openshell/policy.yaml` | Network egress allowlist |
| `.openshell/dotfiles/` | Zellij config, layouts |
| `.openshell/ssh_wrapper.sh`, `ssh-bin/` | SSH connectivity (`~/.ssh/config` block managed at runtime by `sandbox.sh:ensure_ssh_config`) |

### Runtime artifacts (local per-repo, gitignored)

| Path | Purpose |
|---|---|
| `.openshell/.bootstrap/` | Cached downloads (created by `make sandbox`) |
| `.openshell/.base-image-digest` | Tracks base container image version |

## Output Capture (^Y)

The sandbox bash shell wraps the session in `script(1)`, providing a real pty. `preexec`/`precmd` hooks record byte offsets in the script log. Ctrl+Y extracts the last command's output and copies to clipboard via OSC 52 (works through SSH, zellij, tmux). No TUI exclusion list needed — programs see a real TTY.

The host zsh has the same mechanism (`~/.zshrc`), using `pbcopy` instead of OSC 52.
