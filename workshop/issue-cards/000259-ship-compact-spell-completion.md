---
id: 000259
status: open
created: 2026-09-15
updated: 2026-09-16
estimate_hours:
github_issue:
---

# Ship compact spell and buffer completion in Parley

## Problem

Parley’s released chat experience does not provide the compact, always-nearby
completion flow that makes misspellings easy to correct. The shipped spell-check
menu is oversized and noisy. The operator’s configured Parley menu is somewhat
better, while Pair’s draft Neovim pane has the preferred behavior: a normal
completion popup appears as the word is typed, with numbered suggestions that
are easy to select. The draft also completes words already present in the
buffer, even when they are not in the spell dictionary.

Parley already has a `spell.lua` typeahead implementation ported from Pair, but
the feature is currently opt-in and its scope is narrower than the draft
completion experience.
