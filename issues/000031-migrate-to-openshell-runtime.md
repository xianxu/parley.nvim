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

## Open questions
- Does OpenShell's custom image support (`--from ./dir`) work with our full Dockerfile (neovim, oh-my-zsh, language runtimes, etc.)?
- How does `openshell sandbox create` handle volume mounts for repo and worktree?
- Does the alpha have rough edges that block our workflow (e.g., GPU not needed, but K3s overhead)?
- Can we keep `make sandbox` / `make sandbox-shell` UX or does OpenShell's CLI replace it entirely?

## Done when

- `make sandbox` launches a real OpenShell sandbox with policy enforcement
- `policy.yaml` is actively enforced (network egress deny-by-default works)
- Agent workflows (claude, codex, gemini) function inside the sandbox
- SSH/git access works through OpenShell's credential injection, not raw socket passthrough

## Plan

- [ ] Install openshell CLI and verify basic `sandbox create -- claude` works
- [ ] Compare our policy.yaml schema with OpenShell's expected format
- [ ] Adapt Dockerfile as custom image, test with `--from`
- [ ] Rewrite Makefile targets to use openshell CLI
- [ ] Remove SSH agent socket mounting, configure credential injection
- [ ] Verify all agent auto-approve workflows
- [ ] Update specs/infra/openshell.md

## Log

### 2026-03-29
- Created issue after discovering OpenShell runtime is publicly available
- Context: issue 000030 finding 1 identified that policy.yaml was never enforced
