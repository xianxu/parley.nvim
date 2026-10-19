---
id: 000396
status: open
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'e96625a2fa7c00a78780f8cd235430938b6ff20d' # card fields mirrored from issue-cards; edit via sdlc
---

# Repair issue vocabulary provenance

## Problem

Every parley PR merge-check fails during Prepare dependencies and compile composition: apply: preserving authored replacement at construct/generated/vocabulary/issue.json. The hub traced the onset to ariadne#394 (8461dcf1), whose issue.cue adds the flake_tests card field. This blocks #391 and later landings; pair main still passes.

## Spec

Determine whether the committed issue vocabulary is hand-authored or stale generated output with incorrect weave ownership. Restore the canonical generated file and provenance through weave, or remove a stale override, preserving the committed runtime artifact required for plugin installs. Do not bypass CI or alter workflows/merge-checks; report if those paths prove necessary.

## Done when

- The authored-replacement refusal is reproduced and its exact cause documented.
- Weave can update the issue vocabulary from current canonical issue.cue, including flake_tests, and a second generation is clean.
- The PR merge-check passes without CI bypass or local-gates configuration changes.

## Plan

- [ ]

## Log

### 2026-10-19

Dispatched as a fleet-blocking quick-flow repair; hub will grant landing priority when ready.
