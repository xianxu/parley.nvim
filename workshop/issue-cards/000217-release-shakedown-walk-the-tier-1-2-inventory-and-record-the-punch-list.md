---
id: 000217
status: open
created: 2026-09-05
updated: 2026-09-05
estimate_hours:
github_issue:
---

# Release shakedown: walk the Tier 1/2 inventory and record the punch list

## Problem

`workshop/projects/parley-v1-release.md` has no shakedown item. The audit
(`workshop/plans/000206-shipping-surface-inventory.md`) is **static** — three
agents reading code plus a clean-clone repro. Nothing in the breakdown covers
sitting in the editor and using each feature, which is where usability defects
and "works but feels wrong" live.

This issue is the running punch list for that pass. Each row is **verified**,
**talking point** (announcement-worthy, works), or **gap** (fix before release).
Gaps large enough to plan get their own issue; this stays the index.

Note the audit's Tier 1 is a *triage* list, not a status surface — it says what
to lead with, not what currently works. This issue is the status surface.
