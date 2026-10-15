---
id: 000336
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'ef7cc75200ca34930bb9e6ebae3eb6f613ecb4f4' # card fields mirrored from issue-cards; edit via sdlc
---

# Flake: packaging VM guest chat confinement follows transient focus

## Problem

Flake first seen 2026-10-15 during #332 verification: tests/integration/packaging_vm_spec.lua, case exercises guest fake first use, login prompt and real chat dispatch in an isolated profile, failed its guest current-buffer confinement assertion. An unchanged focused rerun passed all17cases. Per test-economy rule, retain this as a tracked flake rather than treating rerun success as disposal.

## Spec

Investigate and eliminate the guest probe timing/focus dependence without weakening profile confinement, first-use login or real chat dispatch assertions. Reproduce under parallel integration load and distinguish the created chat document from transient UI focus.

## Done when

A deterministic regression or controlled scheduling reproduces the failure, the root cause is fixed, and focused plus full parallel integration checks prove isolation without assuming the current buffer is the completed chat.

## Plan

- [ ]

## Log

First-seen head: b6c67239f20e820d85bf4144671f5c7cb8f98152. Command: make -k test-integration, after the required suite stopped at unit failures. Log: /tmp/parley332-full-remainder.log, packaging_vm_spec section, test line167, generated fake-chat.lua line10: guest chat file escaped isolated profile. Observed16pass/1fail, exit1. Unchanged command make -k test-spec SPEC=scratch MAP_FILE=/tmp/parley332-vm-map.yaml passed17/0; log /tmp/parley332-packaging-vm-repro.log. The failed combined remainder has four other named #332 failure classes, independently fixed; this flake had no packaging source changes.
