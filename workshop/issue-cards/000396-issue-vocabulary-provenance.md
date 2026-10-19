---
id: 000396
status: open
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
github_issue:
---

# Repair issue vocabulary provenance

## Problem

Every parley PR merge-check fails during Prepare dependencies and compile composition: apply: preserving authored replacement at construct/generated/vocabulary/issue.json. The hub traced the onset to ariadne#394 (8461dcf1), whose issue.cue adds the flake_tests card field. This blocks #391 and later landings; pair main still passes.
