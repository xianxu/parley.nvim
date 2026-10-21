---
id: 000409
status: open
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-21
estimate_hours:
collaboration-mode: collaboration
card_mirror: '89c423affcee81bbaacb3483bbe71a16afa6efcb' # card fields mirrored from issue-cards; edit via sdlc
---

# Test orphan reaper kills an active targeted run in the same checkout

## Problem

## Spec

scripts/reap-test-orphans.py --phase before treats every recognized headless harness under the checkout as left by an earlier run, excluding only its own ancestry. A second targeted make run in the same checkout therefore SIGKILLs a healthy first run. This was observed during #407: /tmp/parley407-heading-inline-red.log reports reap pid69525 ppid47960, while /tmp/parley407-rework-targeted2.log reports that exact active open_reference_spec process as Killed:9. There is no assertion failure or spec deadline in the interrupted test.

Reproduce with one deliberately gated targeted spec running, then start another targeted make test-spec in the same checkout. Active runs must have ownership respected: either serialize same-checkout harness runs under a lifetime resource or distinguish live-owned trees from abandoned processes. Preserve cleanup of genuinely orphaned fixtures and harness children.

## Done when

- A deterministic controlled-process regression starts one active targeted harness then the second run's before/after cleanup and proves the first is not signalled (or the second waits under an explicit lease).
- Cleanup still reaps dead-owner leftovers and its own leaked children, with real process identity checks; an unrelated command containing the path remains untouched.
- Existing reaper tests and targeted/full harness checks pass; document the same-checkout run ownership rule.

## Plan

- [ ]

## Log

Filed unclaimed as an independent harness defect discovered during #407 close rework. The #407 worker serializes its remaining targeted checks; its previous recorded full suite was green and this targeted interruption is infrastructure evidence only.
