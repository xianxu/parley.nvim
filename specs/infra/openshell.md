# OpenShell Sandbox Environment

## Purpose
Secure, policy-enforced sandbox for AI agent workflows using NVIDIA OpenShell. The sandbox is an **agent runtime**, not a dev environment — humans use their host IDE, agents run inside the sandbox.

## Architecture

```
Host (macOS)                          Sandbox (OpenShell / K3s pod)
+---------------------+              +--------------------------+
| IDE, terminal       |              | Community base image     |
| make sandbox-build  |--creates-->  | + project-specific tools |
| make sandbox        |--connects--> | + git config, aliases    |
|                     |              |                          |
| mutagen (host-side) |<---sync--->  | /sandbox/repo            |
|                     |--one-way-->  | /sandbox/worktree        |
+---------------------+              +--------------------------+
         |                                      |
         |  OpenShell proxy (L7)                |
         |  <- policy.yaml enforces egress ->    |
         +--------------------------------------+
```

## Key Design Decisions

1. **Community `base` image, no custom image** — project-specific tools added via bootstrap scripts at creation time.
2. **Host-side download, sandbox-side install** — fast parallel downloads on host, cheap install in sandbox. Bootstrap cache persists across rebuilds.
3. **Mutagen for file sync** — two-way for repo/worktree, one-way for `.git/`/plenary. Chosen over `--upload` (slow handshake) and git clone (slow through L7 proxy).
4. **GitHub auth forwarded from host** — `gh auth token` copied via SSH. `http.sslVerify false` needed because OpenShell proxy terminates TLS.
5. **Agents get full auto-approve** — sandbox is the security boundary.

## Base Image Update Check

On every `make sandbox`, compares the GHCR registry digest of `base:latest` against a locally saved digest (`.openshell/.base-image-digest`). Prompts user to rebuild if a newer image is available. Fails open — never blocks on network errors.

## Gotchas

- **Policy `binaries` field** — every `network_policies` entry must have `binaries` or OPA silently denies all traffic.
- **`HOME=/sandbox`** in the community base image, not `/home/sandbox`.
- **DNS-1035 sandbox names** — dots replaced with hyphens.
- **Luacheck without LuaRocks** — built from source with `gcc` directly (no `unzip` in base image).

## Usage
```bash
make bootstrap          # One-time: install openshell, gh, mutagen + gh auth
make sandbox-build      # Create sandbox, run setup, start sync (idempotent)
make sandbox            # Connect to sandbox (builds if needed)
make sandbox-clean      # Reset repo sync + re-apply config
make sandbox-stop       # Delete sandbox, clean up
```
