---
id: 000438
status: open
deps: []
github_issue:
created: 2026-10-24
updated: 2026-10-24
estimate_hours:
card_mirror: '2c41021929aac53f1ce7130ebe36dca47a9d57c5' # card fields mirrored from issue-cards; edit via sdlc
---

# Couch bridge timeout test reads a probe marker before startup is established

## Problem

Main's diagnostic baseline suite failed the Couch bridge subprocess timeout test while landing #425. This is separate from that branch's agentic-document lifetime failure; no shared root cause is established.

## Spec

Find the cause of tests.packaging.test_couch_bridge.SessionTests.test_probe_timeout_joins_before_eof failing after its subprocess timeout with no producer/probe marker. The fixture starts Python with a0.1s timeout, then unconditionally reads the child's PID marker. Determine whether this assumes the child reached its first instruction before the timeout, or a real BridgeSession ownership/cleanup defect. Preserve the join-before-EOF and killed-child assertions; do not simply raise the timeout.

Exact recorded baseline: b31fd0390b69c6b4d8030f670ab2903922dd8ec1, diagnostic attempt85e09dd14d1b11e6a6ed11100b6bcd80,7m39s. tests/integration/couch_bridge_spec.lua wraps19 Python tests; this was its only error. FileNotFoundError at test_couch_bridge.py:127 reading /Volumes/TestScratch/bridge-consumer-x48oc727/producer/probe. Python3.14.5. Clean owned-process census. Main's agentic_document_lifetime_spec passed.

Raw log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/85e09dd14d1b11e6a6ed11100b6bcd80.log, SHA256cddbab19727c3dc5979f93186d880b2a113bde12a00ec772c8ee91101a70fbdf; lines1718–1765. This is a diagnostic main-baseline run, not a posted ordinary suite pass/fail record. #425's integrated candidate failed a different test; this evidence does not identify a branch regression or an established intermittent failure yet. No flake registration is fabricated from this single occurrence.

## Done when

- Identify the startup/timeout/cleanup ordering that permits the absent probe marker.
- Add deterministic startup/timeout controls and fix the owning fixture or bridge implementation while preserving process join and EOF ordering assertions.
- Verify the Python regression and normal wrapper/suite; retain failure and control evidence.

## Plan

- [ ]

## Log

Filed unclaimed at hub direction b6b69042-a85a-47bf-b5b9-8c7c4601b9fe. One bounded replay of this single Python timeout test on the pinned main revision is planned during #425 diagnosis, separately from the matched lifetime repetitions; no blind full-suite retry.
