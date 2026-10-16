---
id: 000238
status: codecomplete
created: 2026-09-12
updated: 2026-10-16
estimate_hours:
github_issue:
started: 2026-10-16T06:07:45-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.12
tracker:
    version: 1
    completion:
        token: close-ea21339661ad
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 2be663329e6f2984be613a815bf7b860a705022e
        evidence_commit: aa2628badb07cc8578d46b687771eea15a9553c4
---

# Catalog conformance cases cannot pass with the fabricated credential

## Problem

`tests/integration/cliproxy_conformance_spec.lua` has two #205 cases that boot the
real cliproxyapi and read its model catalog:

- "serves /v1beta/models with the naming fields parse() joins on"
- "joins its two model routes onto each other for real"

Both fail on every build tried (7.1.71, 7.2.158, and the latest release the spec
downloads under `PARLEY_LIVE_GITHUB=1`): `/v1beta/models` comes back empty. The
spec boots the proxy with a fabricated, expired Claude credential, by design, so
that its startup refresh is a harmless 401, and the proxy registers no models
for a credential it cannot refresh. Until #237 no real binary was ever on the
harness's `PATH`, so these cases always ran `pending` and nobody saw that they
cannot pass. With a real login the catalog works: the operator's proxy on
7.2.159 lists 17 claude models.
