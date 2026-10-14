---
id: 000325
status: open
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '314d76a1f05c0abae38576672f58ef35dc397152' # card fields mirrored from issue-cards; edit via sdlc
---

# Image paste (Alt+v) in any markdown file, not only timestamp-named chats: sidecar assets per file, for the TL session file and QA files

## Problem

The operator wants to paste screenshots into the TL session file's `## Operator instructions` (ops `teams/<team>/tl-status-<operator>.md`) and into QA answer files (`teams/<team>/qa/<operator>/*.md`), 2026-10-14. Alt+v (`paste_image`) is bound in markdown buffers (lua/parley/init.lua, the markdown dispatch table), but `paste_image.paste` asks `assets.folder_for(path)`, which only accepts timestamp-named chats, so it refuses with "image paste needs a timestamp-named chat".

## Spec

`assets.folder_for` accepts any markdown file: the sidecar is `<dir>/assets/<file-stem>/<asset-timestamp>.<ext>`, still written only through `assets` (THE writer), with the same no-bytes-without-a-line guarantees. Chats keep their timestamp folders unchanged. Lifecycle stays the file owner's: parley never deletes an asset because a line was deleted. A separate sweep (the TL, for the session and QA files) removes assets no longer referenced. Document the sidecar in the README.

## Done when

- Alt+v in a non-chat markdown file (e.g. `tl-status-xian-xu.md`) saves `assets/tl-status-xian-xu/<ts>.png` and inserts `![](assets/tl-status-xian-xu/<ts>.png)` (test); chats unchanged (regression test).

## Plan

- [ ]

## Log

### 2026-10-14

## Revisions

- 2026-10-14 — add (operator): images must not be stored at full fidelity. The new sidecar path reuses the existing `assets` shrink step (sips/magick/…, JPEG within the max edge; `assets.shrink`/`shrink_cmd` honoured); add a test that a large paste into a non-chat markdown file lands shrunk.
