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
├── Makefile            # Make targets (bootstrap, sandbox, sandbox-build, etc.)
├── sandbox.sh          # Lifecycle script (build, connect, stop)
├── policy.yaml         # OpenShell network/filesystem policy
├── overlay/
│   └── setup.sh        # One-shot user-local setup (neovim, git config, aliases)
└── dotfiles/           # Legacy — kept for reference, not used in sandbox
```

## Key Design Decisions

1. **Community `base` image** — no custom Dockerfile. Base includes Python, Node 22, gh, git, claude, codex, copilot. Sandbox is agent runtime only.

2. **Minimal overlay** — `setup.sh` installs only neovim binary to `~/.local/bin` + git config + bash aliases. No IDE plugins, no zsh, no dotfiles. Agents run headless; humans use host.

3. **Mutagen for file sync** (not docker bind mounts, not `--upload`):
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

## Known Limitations
- `openshell sandbox create --no-tty` still opens an interactive shell (~30s supervisor startup)
- Git clone inside sandbox is slow (all traffic goes through L7 proxy) — prefer syncing deps from host
- `--upload` has ~30s handshake overhead — setup piped over SSH instead
- No persistent state across sandbox recreations — all setup re-runs on fresh create

## History
- 2026-03-30: Migrated to real OpenShell runtime with policy enforcement (issue 000031)
  - Community base image, mutagen sync, GitHub token auth, minimal agent-runtime setup
  - Dropped custom Dockerfile, SSH agent forwarding, docker bind mounts
- 2026-03-29: Agent auto-approve: Claude settings, Codex alias, Gemini env var (issue 000016)
- 2026-03-29: Mount as /{repo-name}, add /worktree mount, portable worktree paths (issue 000014)
- 2026-03-28: Initial creation (issue 000010)
