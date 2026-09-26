---
id: 000279
status: codecomplete
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T23:48:38-07:00
flow: {kind: quick, provenance: inferred, spec: "67a68b10", done: "4b6cf4f0"}
actual_hours: 0.22
---

# Reuse running proxy without a local executable during onboarding

## Problem

The demo retains its selected agent but reopens the picker on every submission
because onboarding requires a local executable before probing the running proxy.

## Spec

Delegate readiness to cliproxy.ensure_running, which probes before discovering
a binary (ARCH-DRY). Keep credential/model validation and failure onboarding.

## Done when

- Repeated readiness checks reuse a running proxy without any local executable or picker.
- Missing models and unavailable proxies still offer setup.

## Plan

- [x] Reproduce with the process-level proxy fake, remove premature discovery, and verify readiness/failure paths.

## Log

### 2026-09-25
- 2026-09-25: closed — 54 process-level proxy lifecycle cases pass, including repeated readiness without a discoverable executable, missing-model fallback and removed-account fallback; regression failed before fix. 183 starter cases pass in clean snapshot (live tutorial edits preserved/excluded). Lua lint and scoped whitespace pass.; review verdict: SHIP

- Red: process-level regression reopened picker despite reachable proxy; green: 54 lifecycle cases pass, including repeated readiness, missing model and removed credential.
- 183 starter cases pass in clean snapshot /tmp/parley-279-clean.log; live-tree suite hit operator tutorial edits, which were excluded and preserved. Changed Lua lint and scoped whitespace pass.
- Fix removes duplicate executable precondition; ensure_running remains the owner of probe/spawn ordering (ARCH-DRY).
