# OpenShell Sandbox Environment

## Purpose
Secure, policy-enforced sandbox for AI agent workflows using NVIDIA OpenShell. The sandbox is an **agent runtime**, not a dev environment — humans use their host IDE, agents run headless tests and code changes inside the sandbox.

## Architecture

```
Host (macOS)                          Sandbox (OpenShell / K3s pod)
┌─────────────────────┐              ┌──────────────────────────┐
│ IDE, terminal       │              │ Community base image     │
│ make sandbox-build  │──creates──→  │ + neovim (user-local)    │
│ make sandbox        │──connects──→ │ + git config (HTTPS)     │
│                     │              │ + bash aliases (agents)   │
│ mutagen (host-side) │◄──sync──►   │ /sandbox/repo            │
│                     │──one-way──→  │ /sandbox/worktree        │
│                     │──one-way──→  │ ~/.local/share/nvim/lazy │
└─────────────────────┘              └──────────────────────────┘
         │                                      │
         │  OpenShell proxy (L7)                │
         │  ← policy.yaml enforces egress →     │
         └──────────────────────────────────────┘
```

## Structure
```
.openshell/
├── Makefile            # Make targets (bootstrap, sandbox-build, sandbox-clean, etc.)
├── sandbox.sh          # Lifecycle script (build, connect, clean, stop)
├── policy.yaml         # OpenShell network/filesystem policy
├── .bootstrap/         # Host-side dep cache (gitignored, persists across rebuilds)
├── overlay/
│   ├── bootstrap.sh    # Host-side: parallel download of all deps into .bootstrap/
│   ├── setup.sh        # Sandbox-side: git config, shell config, workspace dirs
│   ├── post-install.sh # Sandbox-side: install tools from bootstrap cache
│   └── deps/           # Legacy individual dep scripts (no longer sourced)
└── dotfiles/
    └── zellij/         # Zellij terminal multiplexer config
```

## Key Design Decisions

1. **Community `base` image** — no custom Dockerfile. Base includes Python, Node 22, gh, git, claude, codex, copilot. Sandbox is agent runtime only.

2. **Host-side bootstrap + sandbox post-install** (split download from install for speed):
   - `bootstrap.sh` runs on the **host** — downloads neovim, zellij, oh-my-bash, lua source, luacheck+deps in parallel to `.bootstrap/` cache. Skips if `.bootstrap/.done` exists.
   - `post-install.sh` runs on the **sandbox** — copies pre-built binaries, compiles Lua/luafilesystem from source, installs luacheck via wrapper script.
   - `setup.sh` runs on the **sandbox** — git config, shell config, workspace dirs only. Idempotent via `BEGIN/END` markers so it can be re-run by `sandbox-clean`.
   - **Why split?** Host downloads are fast (no proxy overhead, parallel). Sandbox only does the cheap parts (copy, compile). Bootstrap cache persists across sandbox rebuilds.

3. **Mutagen for file sync** (not docker bind mounts, not `--upload`):
   - **Bootstrap**: one-way-replica of `.bootstrap/` to `/tmp/bootstrap/` (deps cache)
   - **Repo**: two-way-resolved to `/sandbox/repo`
   - **Git history**: one-way-replica of `.git/` to sandbox (enables `git diff/log/branch` inside sandbox without full clone; ignores `index.lock` to avoid conflicts)
   - **Worktree**: two-way-resolved to `/sandbox/worktree`
   - **Plenary.nvim**: one-way from host (avoids slow git clone through OpenShell proxy)
   - Near-instant on macOS (FSEvents), ~10s for sandbox-originated changes

4. **GitHub token for git auth** — OpenShell's GitHub provider auto-discovers `GH_TOKEN` and injects it. Git uses HTTPS via `url.insteadOf` rewrite. No SSH agent forwarding (OpenShell's embedded SSH daemon doesn't support it). Requires `http.sslVerify false` since proxy terminates TLS.

5. **Policy requires `binaries` field** — every `network_policies` entry must have `binaries: [{path: "/**"}]` or OPA silently denies all traffic (policy shows "Active" but returns 403).

6. **`HOME=/sandbox`** in the community base image, not `/home/sandbox`.

7. **DNS-1035 sandbox names** — dots replaced with hyphens (`parley.nvim` → `parley-nvim`).

8. **macOS Docker Desktop** requires `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`.

## Usage
```bash
make bootstrap          # Install openshell, gh, mutagen + gh auth (one-time)
make sandbox-build      # Create sandbox, run setup, start sync (idempotent)
make sandbox            # Connect to sandbox (builds if needed)
make sandbox-shell      # Alias for sandbox
make sandbox-clean      # Reset repo sync + re-apply config, keep sandbox + tools
make sandbox-stop       # Stop sync, delete sandbox, clean up SSH config
make sandbox-nuke       # Same as stop (no persistent state)
```

## File Sync Layout
- Host repo → `/sandbox/repo` (two-way via mutagen)
- Host `.git/` → `/sandbox/repo/.git` (one-way-replica via mutagen, ignores `index.lock`)
- Host `../worktree` → `/sandbox/worktree` (two-way via mutagen)
- Host `~/.local/share/nvim/lazy/plenary.nvim` → sandbox (one-way via mutagen)
- SSH config managed via `BEGIN/END` markers in `~/.ssh/config` (includes `ServerAliveInterval 15` keepalive)

## Agent Permissions
Sandbox is the security boundary — agents inside get full auto-approve:
- **Claude Code**: `--permission-mode bypassPermissions` via bash alias
- **Codex**: `--full-auto` via bash alias
- **Gemini CLI**: `GEMINI_CLI_AUTO_APPROVE=true` env var

## Network Policy
- Deny-by-default: anything not listed is blocked
- Allowed: GitHub (+ Azure blob for release assets), npm, Cargo, RubyGems, PyPI, Go proxy, LuaRocks, Hex, Anthropic API, OpenAI API, Google AI API, Amazon AWS, Ubuntu apt
- L4 passthrough (no HTTP inspection) for most endpoints
- All entries require `binaries: [{path: "/**"}]`

## Performance Optimizations

1. **Parallel sandbox create + host download** — `openshell sandbox create` (~34s) runs in background while `bootstrap.sh` downloads deps on host. Both must finish before post-install.

2. **Host-side download, sandbox-side install** — All `curl`/`git clone` happens on the host (no proxy overhead, parallel downloads). Only compilation (Lua, luafilesystem) and file copies run on the sandbox.

3. **Bootstrap cache** — `.bootstrap/` persists across `sandbox-stop`/`sandbox-build` cycles. Only cleared manually (`rm -rf .openshell/.bootstrap`). The `.done` marker skips re-downloading.

4. **`sandbox-clean` for iterating on trampoline setup** — Terminates mutagen syncs, wipes `/sandbox/repo` + `/sandbox/worktree`, re-syncs files, then re-runs `setup.sh` + dotfile copies + credential forwarding. This is the fast path for evolving the sandbox configuration (shell aliases, env vars, dotfiles) without recreating the sandbox — edit files on the host, `make sandbox-clean`, `make sandbox` to test. `setup.sh` is idempotent (uses `BEGIN/END openshell-overlay` markers in `.bashrc`).

5. **Luacheck without LuaRocks** — LuaRocks requires `unzip` (not in base image, no root). Instead: clone luacheck + argparse source, build luafilesystem C module with one `gcc` call, wrapper script sets `LUA_PATH`/`LUA_CPATH`.

6. **Lua without readline** — Build with `make linux` instead of `make linux-readline` to avoid `libreadline-dev` dependency (not in base image). Interactive shell features not needed for linting.

## Known Limitations
- `openshell sandbox create --no-tty` still opens an interactive shell (~30s supervisor startup)
- Git clone inside sandbox is slow (all traffic goes through L7 proxy) — prefer syncing deps from host
- `--upload` has ~30s handshake overhead — setup piped over SSH instead
- No persistent state across sandbox recreations — all setup re-runs on fresh create

## History
- 2026-04-01: `sandbox-clean` now re-applies config (setup.sh + dotfiles + creds) after re-sync
  - `setup.sh` made idempotent with `BEGIN/END openshell-overlay` markers
  - Enables iterating on trampoline setup without full sandbox rebuild
- 2026-04-01: Split deps into host-side bootstrap + sandbox post-install for speed
  - Parallel sandbox create + dep download, bootstrap cache, luacheck without LuaRocks
  - Added `make sandbox-clean` for fast repo reset without recreating sandbox
- 2026-03-30: Migrated to real OpenShell runtime with policy enforcement (issue 000031)
  - Community base image, mutagen sync, GitHub token auth, minimal agent-runtime setup
  - Dropped custom Dockerfile, SSH agent forwarding, docker bind mounts
- 2026-03-29: Agent auto-approve: Claude settings, Codex alias, Gemini env var (issue 000016)
- 2026-03-29: Mount as /{repo-name}, add /worktree mount, portable worktree paths (issue 000014)
- 2026-03-28: Initial creation (issue 000010)
