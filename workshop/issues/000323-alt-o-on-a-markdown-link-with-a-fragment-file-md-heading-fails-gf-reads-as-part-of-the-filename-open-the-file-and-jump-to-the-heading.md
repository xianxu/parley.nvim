---
id: 000323
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'd6cbb172d8d2df0dd471bea584182c5b01cf290d' # card fields mirrored from issue-cards; edit via sdlc
---

# Alt+o on a markdown link with a #fragment (file.md#heading) fails: gf reads # as part of the filename; open the file and jump to the heading

## Problem

2026-10-14: in ops' QA answer files, the backlink `[Operator instructions](../../tl-status-xian-xu.md#operator-instructions)` didn't open with Alt+o. `OpenFileUnderCursor` (lua/parley/init.lua ~5027) finds no parley reference, falls back to `ResolveRefOrGotoFile`, then native `gf`, and `#` is in Vim's default `isfname`, so gf looks for a file literally named `tl-status-xian-xu.md#operator-instructions`. The path itself is correct; the TL dropped the fragment as a workaround.

## Spec

Alt+o on a markdown link `[text](path)` opens `path` relative to the current file; a `#fragment` is stripped from the path and then used to jump to the matching heading (GitHub-style slug: lowercase, spaces to `-`, punctuation dropped). Unknown fragments open the file at the top with a notice. Plain `gf` behaviour elsewhere is unchanged.

## Done when

- Alt+o on `[x](../a.md#some-heading)` opens `a.md` at `## Some heading` (test), and on `[x](../a.md)` as before.

## Plan

- [ ]

## Log

### 2026-10-14
