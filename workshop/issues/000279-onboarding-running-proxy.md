---
id: 000279
status: working
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T23:48:38-07:00
flow: {kind: quick, provenance: inferred, spec: "67a68b10", done: "4b6cf4f0"}
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

- [ ] Reproduce with the process-level proxy fake, remove premature discovery, and verify readiness/failure paths.

## Log

### 2026-09-25
