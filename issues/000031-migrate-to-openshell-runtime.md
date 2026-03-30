---
id: 000031
status: open
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# Migrate sandbox to real OpenShell runtime

## Context
The current `.openshell/` setup is a hand-rolled Docker container that mimics OpenShell's intent but doesn't use the actual runtime. `policy.yaml` exists but nothing reads it — there's no policy engine, no network interception, no filesystem enforcement. NVIDIA OpenShell is now publicly available (alpha, single-player mode) with a CLI that manages sandbox lifecycle and enforces declarative YAML policies at L7.

Repo: https://github.com/NVIDIA/OpenShell
Docs: https://docs.nvidia.com/openshell/latest/index.html

## What OpenShell provides that we don't have today
- **Policy engine**: intercepts every outbound connection, enforces allow/deny/route at L7
- **Filesystem locking**: policy-defined writable/readable paths enforced at sandbox creation
- **Process isolation**: prevents privilege escalation and dangerous syscalls
- **Inference routing**: can reroute model API calls to controlled backends, strip/inject credentials
- **Credential injection**: auto-discovers API keys from host env, injects at runtime without persisting to disk

## What needs to change
1. Install `openshell` CLI (via `curl` installer or `uv tool install -U openshell`)
2. Adapt current Dockerfile as a custom image for `--from ./path`
3. Migrate Makefile targets from `docker run`/`docker exec` to `openshell sandbox create/connect`
4. Apply `policy.yaml` via `openshell policy set` — our existing policy.yaml schema may need adjustments to match OpenShell's actual format
5. Remove SSH agent passthrough hack — OpenShell handles credential injection natively
6. Verify agent auto-approve still works (Claude, Codex, Gemini) inside OpenShell sandbox
7. Update spec and docs

## Open questions (answered)
- **Custom image**: `--from ./dir` works with any Dockerfile — our image should work
- **No volume mounts**: OpenShell uses `--upload`/`download` not `docker -v`. Repo synced at create time, changes downloaded back. This is a workflow change.
- **No sandbox stop**: Only create or delete. `--no-keep` auto-deletes on exit.
- **UX**: We keep `make sandbox` / `make sandbox-shell` as thin wrappers around `openshell` CLI

## Key design decisions
1. **Use community `base` image** — no custom Dockerfile. `base` already includes Python, Node 22, gh, git, claude, codex, copilot agents. Sandbox is an agent runtime, not a dev environment — humans use host IDE.
2. **Minimal setup via SSH** — `setup.sh` piped over SSH installs only neovim binary + git config + bash aliases. No IDE plugins, no zsh, no dotfiles. Agents run headless tests; humans use host.
3. **`--policy .openshell/policy.yaml`** applied at creation (static parts locked). Every `network_policies` entry MUST have `binaries: [{path: "/**"}]` or OPA silently denies all traffic.
4. **`--auto-providers`** for credential injection (API keys + GitHub token)
5. **GitHub token for git auth** — OpenShell's GitHub provider auto-discovers `GH_TOKEN` from host and injects it into sandbox. Git inside sandbox uses HTTPS via `git config url.insteadOf` to rewrite SSH remotes. Plus `http.sslVerify false` since proxy terminates TLS.
6. **Mutagen for all file sync** (replaces docker -v bind mounts, replaces `--upload`)
   - Repo: two-way-resolved to `/sandbox/repo`
   - Worktree: two-way-resolved to `/sandbox/worktree`
   - Plenary.nvim: one-way-replica from host (avoids slow git clone through proxy)
   - Near-instant on macOS (FSEvents), ~10s for sandbox-originated changes
   - Respects `~/.ssh/config` including OpenShell's ProxyCommand
7. **`make bootstrap`** installs all dependencies: openshell CLI, `gh` + auth, `mutagen` (all via homebrew except openshell)
8. **`HOME=/sandbox`** in base image — all paths use `/sandbox/` not `/home/sandbox/`
9. **DNS-1035 sandbox names** — dots replaced with hyphens (`parley.nvim` → `parley-nvim`)
10. **macOS Docker Desktop** needs `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`

## Done when

- `make sandbox` launches a real OpenShell sandbox with policy enforcement + live file sync
- `make test` passes inside sandbox
- `policy.yaml` is actively enforced (network egress deny-by-default works)
- Host repo + worktree + plenary synced in sandbox via mutagen
- Agent workflows (claude, codex, gemini) function inside the sandbox
- Credentials injected via OpenShell providers (API keys + GitHub token)

## Plan

### Step 1: Rewrite policy.yaml to OpenShell schema ✅
- [x] Convert filesystem and network sections to OpenShell format
- [x] Add `binaries: [{path: "/**"}]` to every network policy entry
- [x] Add `*.blob.core.windows.net` for GitHub release redirects

### Step 2: Minimal agent-runtime setup ✅
- [x] Use `--from base` community image (no custom Dockerfile)
- [x] `setup.sh` — installs neovim binary to `~/.local/bin`, configures git, bash aliases
- [x] No IDE plugins, no zsh/oh-my-zsh, no dotfiles — agent runtime only
- [x] Setup piped over SSH (not `--upload`, which has ~30s handshake overhead)

### Step 3: Rewrite Makefile targets ✅
- [x] `make bootstrap` — install openshell CLI + gh + mutagen + gh auth
- [x] `sandbox` → create sandbox, SSH config, run setup, start mutagen (repo + worktree + plenary), connect
- [x] `sandbox-shell` → `openshell sandbox connect`
- [x] `sandbox-stop` → terminate mutagen + delete sandbox + clean ssh config
- [x] `sandbox-nuke` → same as stop

### Step 4: Verification
- [x] `make sandbox` creates sandbox, runs setup, starts sync, enters shell
- [x] `make test` passes inside sandbox
- [x] Neovim 0.11+ available inside sandbox
- [x] Repo files synced via mutagen
- [x] Plenary synced one-way from host
- [ ] Network deny-by-default works (curl to random site fails)
- [ ] Git push/pull works using GH token
- [ ] Claude/Codex/Gemini can start and authenticate inside sandbox

### Step 5: UX polish
- [ ] Fix `--no-tty` still opening a shell on `sandbox create` (requires extra `exit` before setup runs)
- [ ] Investigate if `-- true` or `-- sleep 0` avoids the interactive shell issue

### Step 6: Update specs and docs
- [ ] Update specs/infra/openshell.md with new architecture
- [ ] Update TOOLING.md if sandbox commands changed

### Step 5: Update specs and docs
- [ ] Update specs/infra/openshell.md with new architecture
- [ ] Update TOOLING.md if sandbox commands changed

## Log

### 2026-03-29
- Created issue after discovering OpenShell runtime is publicly available
- Context: issue 000030 finding 1 identified that policy.yaml was never enforced
- Researched OpenShell CLI thoroughly: no volume mounts (upload/download instead), policy schema is completely different (named network_policies with per-endpoint config), credential injection via providers (auto-discovers from host env), no sandbox stop (only delete)
- Added `make bootstrap` target for installing openshell CLI
- Wrote detailed migration plan with 5 steps
- Decided on reverse SSH tunnel + sshfs for live filesystem sharing (replaces docker -v)
- SSH agent forwarding preserved through reverse tunnel for git access
- Identified FUSE risk (/dev/fuse in K3s pod); mutagen as fallback
- Rejected reverse SSH tunnel approach — gives sandbox full shell access to host, defeats sandboxing purpose
- Switched to mutagen: runs host-side, connects into sandbox (not reverse), no host exposure, no FUSE, `brew install mutagen`
- SSH agent forwarding via standard `ssh -A` on `sandbox connect` (forward direction, secure)
- Confirmed SSH agent forwarding won't work: OpenShell's embedded SSH daemon (russh) doesn't implement agent_request_forwarding
- Git auth in sandbox: GitHub provider injects GH_TOKEN + `git config url.insteadOf` rewrites SSH→HTTPS
- Keep `sandbox-build` as explicit `docker build` step; use `--from <image>` not `--from ./dir` to avoid rebuilding every time
- `make bootstrap` installs: openshell CLI (curl), gh + mutagen (homebrew), gh auth login

### 2026-03-30
- `--from <image-name>` doesn't work — K3s has separate containerd, can't see Docker Desktop images. `--from ./dir` is the only local path but rebuilds+pushes every time (slow)
- Realized sandbox is an agent runtime, not a dev environment. Humans use host IDE. Agents just need language runtimes + git + tools.
- Community `base` image already has Python, Node, gh, git, claude, codex, copilot
- New approach: use `base` image directly, overlay neovim + zsh/dotfiles via `--upload` + setup script
- Dropped custom Dockerfile and `sandbox-build` target
- `--upload` is slow (~30s handshake overhead). Switched to piping setup.sh over SSH instead
- Policy `network_policies` entries MUST have `binaries` field — without it OPA denies all traffic (silent failure, policy shows "Active" but all 403)
- `binaries: [{path: "/**"}]` allows any binary (security at network level, not per-binary)
- Base image `HOME=/sandbox` not `/home/sandbox` — mutagen targets must use `/sandbox/`
- Removed `protocol: rest` and `access:` from non-API endpoints — proxy MITM causes issues with binary downloads
- OpenShell proxy terminates TLS — need `git config --global http.sslVerify false` inside sandbox
- `*.blob.core.windows.net` needed for GitHub release asset downloads (redirect chain)
- Plenary.nvim synced one-way from host via mutagen (avoids slow git clone through proxy)
- Sandbox name must be DNS-1035 compliant (no dots) — `parley.nvim` → `parley-nvim`
- Docker Desktop macOS needs `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`
- `--no-tty` on `sandbox create` still seems to open a shell — need to exit one level before setup runs. End result works but UX needs polish.
- **End-to-end working**: `make sandbox` → creates sandbox, runs setup via SSH, syncs repo + plenary via mutagen, `make test` passes inside sandbox
- Policy needs `*.claude.com`, `*.claude.ai`, `*.chatgpt.com` for agent CLIs (not just API endpoints)
- DO NOT sync `~/.claude` or `~/.codex` from host — overwrites sandbox auth state set by OpenShell's `--auto-providers`. Let agents authenticate via provider injection or manual login inside sandbox.
- Codex OAuth device flow broken through MITM proxy (chatgpt.com returns 403 on GET after CONNECT succeeds). API key auth works. Filed as OpenShell limitation.
- Refactored sandbox.sh: `build` (idempotent setup), `connect` (builds if needed + connects), `stop` (cleanup)
- `make sandbox-build` = one-time setup, `make sandbox` = connect (runs build first)
