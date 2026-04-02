# OpenShell Sandbox Environment

## Purpose
Secure, policy-enforced sandbox for AI agent workflows using NVIDIA OpenShell. The sandbox is an **agent runtime**, not a dev environment — humans use their host IDE, agents run inside the sandbox.

## Architecture

```
Host (macOS)                          Sandbox (OpenShell / K3s pod)
┌─────────────────────┐              ┌──────────────────────────┐
│ IDE, terminal       │              │ Community base image     │
│ make sandbox-build  │──creates──→  │ + project-specific tools │
│ make sandbox        │──connects──→ │ + git config, aliases    │
│                     │              │                          │
│ mutagen (host-side) │◄──sync──►   │ /sandbox/repo            │
│                     │──one-way──→  │ /sandbox/worktree        │
└─────────────────────┘              └──────────────────────────┘
         │                                      │
         │  OpenShell proxy (L7)                │
         │  ← policy.yaml enforces egress →     │
         └──────────────────────────────────────┘
```

## Key Design Decisions

1. **Community `base` image, no custom image** — base includes Python, Node, gh, git, claude, codex, copilot. We add project-specific tools (neovim, lua, luacheck, zellij) via bootstrap scripts at sandbox creation time. Tool versions track whatever the base image ships; project-specific tools are pinned in bootstrap.sh.

2. **Host-side download, sandbox-side install** — all `curl`/`git clone` runs on the host (fast, no proxy overhead, parallel). Sandbox only does cheap work (copy binaries, compile Lua). Bootstrap cache (`.bootstrap/`) persists across sandbox rebuilds.

3. **Mutagen for file sync** — two-way for repo and worktree, one-way for `.git/` and plenary.nvim. Chosen over `--upload` (30s handshake overhead) and git clone inside sandbox (slow through L7 proxy).

4. **GitHub auth forwarded from host** — `gh auth token` copied to sandbox via SSH. Git uses HTTPS via `url.insteadOf` rewrite. `http.sslVerify false` required because OpenShell proxy terminates TLS.

5. **Agents get full auto-approve** — sandbox is the security boundary, so agents inside run unrestricted. See `setup.sh` for the aliases.

## Gotchas

- **Policy `binaries` field** — every `network_policies` entry must have `binaries: [{path: "/**"}]` or OPA silently denies all traffic (shows "Active" but returns 403).
- **`HOME=/sandbox`** in the community base image, not `/home/sandbox`.
- **DNS-1035 sandbox names** — dots replaced with hyphens (`parley.nvim` → `parley-nvim`).
- **Luacheck without LuaRocks** — LuaRocks needs `unzip` (not in base image, no root). We clone source + build luafilesystem with `gcc` directly.
- **No persistent state** across sandbox recreations — all setup re-runs on fresh create.

## Usage
```bash
make bootstrap          # One-time: install openshell, gh, mutagen + gh auth
make sandbox-build      # Create sandbox, run setup, start sync (idempotent)
make sandbox            # Connect to sandbox (builds if needed)
make sandbox-clean      # Reset repo sync + re-apply config, keep sandbox + tools
make sandbox-stop       # Stop sync, delete sandbox, clean up
make sandbox-nuke       # Same as stop
```

## Structure
```
.openshell/
├── Makefile            # Make targets
├── sandbox.sh          # Lifecycle script (build, connect, clean, stop)
├── policy.yaml         # Network/filesystem policy
├── overlay/
│   ├── bootstrap.sh    # Host-side: parallel download into .bootstrap/
│   ├── post-install.sh # Sandbox-side: install from bootstrap cache
│   └── setup.sh        # Sandbox-side: git config, shell aliases, workspace dirs
└── dotfiles/
    └── zellij/         # Zellij config
```
