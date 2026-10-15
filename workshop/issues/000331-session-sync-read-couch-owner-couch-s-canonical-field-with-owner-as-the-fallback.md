---
id: 000331
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'cb8dd061a439dcfcf3e58263897ebec3d595d937' # card fields mirrored from issue-cards; edit via sdlc
---

# session-sync: read couch-owner: (Couch's canonical field) with owner: as the fallback

## Problem

Couch's session-sync contract calls `couch-owner:` the canonical frontmatter field naming a session-sync file's agent
(`owner:` is the older spelling, still read), and ariadne's tl-lead now writes `couch-owner:`. parley reads only
`owner:` (`lua/parley/session_sync.lua:60`), so a file using the canonical name loses its owner in parley: Alt+Return
has no recipient, the band can't name the agent, and owed-response pings stop. The operator (2026-10-14): "make it
consistent to be couch-owner".

## Spec

- parley reads `couch-owner:` first and falls back to `owner:` (the same precedence as Couch).
- Everything that uses the owner (submit recipient, band label, owed pings, quiet detection) goes through that one
  accessor.
- Docs and README name `couch-owner:` as canonical.

## Done when

- A file with only `couch-owner:` submits to that slot and shows it in the band; a file with only `owner:` still works;
  with both, `couch-owner:` wins. Headless tests cover all three.
- The operator's TL status file is switched to `couch-owner:` after this lands (TL does it).

## Plan

- [ ]

## Log

### 2026-10-14
