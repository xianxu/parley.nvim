---
id: 000300
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: 'cb25334fd9074f69b3eebeab466cbd1b199c059d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T10:35:00-07:00
flow: {kind: quick, provenance: inferred, spec: "8ca1e017", done: "d6e804a8"}
---

# Conversation label icons and app buffer completion

## Problem

App usage exposed missing conversation prefixes on tagged outline entries and disabled buffer-word typeahead.

## Spec

Reuse the configured question prefix for attached tag labels in flat and tree outlines; retain indentation, anchors, anonymous hiding and standalone annotations. Enable the existing app Blink buffer source for the current buffer only at two characters. Use Ctrl-n/p to select, Ctrl-y to accept and Ctrl-e to dismiss, with no preselection or Enter binding. Preserve command-line completion. ARCH-DRY: share label formatting and use Blink’s existing provider. This is a bounded app change; broader spelling/path work remains in #259/#288.

## Done when

- Tagged questions show the configured conversation prefix in both outline paths, including custom prefixes.
- App typing offers words from the current buffer after two characters; Ctrl-n and Ctrl-p move forward/backward among candidates, Ctrl-y accepts, Ctrl-e dismisses, and Enter is unchanged.
- Focused outline tests and real pinned-Blink typing checks pass; app documentation describes the keys.

## Plan

- [x] Update label projections and app options with regression coverage, run focused suites and real Blink smoke, document behavior.

## Log

### 2026-09-29

Scoped from the two explicit app requests. No new dependency, persistent state or background owner; existing Blink manages completion lifecycle.

Verified: make test-spec SPEC=ui/outline and SPEC=infra/starter passed; real pinned Blink keyboard smoke passed (two-character trigger, current buffer only, selection/accept/dismiss/newline, command-line matching); changed Lua files passed luacheck. Regressions failed before implementation. The smoke must feed remappable keys to test the actual configured bindings.

## Revisions

### 2026-09-29 — complete acceptance coverage (BR-1)

Reason: boundary review found that custom prefixes and Ctrl-p were only partially exercised.
Delta: parameterize the actual flat/tree builder fixture for default and custom prefixes; drive Ctrl-n twice and Ctrl-p back through distinguishable real-Blink candidates.

### Verification

Both updated suites pass (228 outline checks; real Blink 14-step typing smoke). Three independent mutations fail as intended: force the default prefix in the flat caller; force it in the tree caller; replace Ctrl-p’s select_prev with select_next. Each production file was restored byte-for-byte after its probe. Changed test files pass luacheck. This addresses BR-1’s entire acceptance-matrix-coverage family.
