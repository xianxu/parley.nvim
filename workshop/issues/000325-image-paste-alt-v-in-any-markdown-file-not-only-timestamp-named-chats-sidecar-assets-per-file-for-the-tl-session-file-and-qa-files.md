---
id: 000325
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'bc6774d0c9347ce07e6c86bbbb7ed0eafd95f22d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T09:55:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Image paste (Alt+v) in any markdown file, not only timestamp-named chats: sidecar assets per file, for the TL session file and QA files

## Problem

The operator wants to paste screenshots into the TL session file's `## Operator instructions` (ops `teams/<team>/tl-status-<operator>.md`) and into QA answer files (`teams/<team>/qa/<operator>/*.md`), 2026-10-14. Alt+v (`paste_image`) is bound in markdown buffers (lua/parley/init.lua, the markdown dispatch table), but `paste_image.paste` asks `assets.folder_for(path)`, which only accepts timestamp-named chats, so it refuses with "image paste needs a timestamp-named chat".

## Spec

`assets.folder_for` accepts any markdown file: the sidecar is `<dir>/assets/<file-stem>/<asset-timestamp>.<ext>`, still written only through `assets` (THE writer), with the same no-bytes-without-a-line guarantees. Chats keep their timestamp folders unchanged. Lifecycle stays the file owner's: parley never deletes an asset because a line was deleted. A separate sweep (the TL, for the session and QA files) removes assets no longer referenced. Document the sidecar in the README.

## Done when

- Alt+v in a non-chat markdown file (e.g. `tl-status-xian-xu.md`) saves `assets/tl-status-xian-xu/<ts>.png` and inserts `![](assets/tl-status-xian-xu/<ts>.png)` (test); chats unchanged (regression test).

## Plan

- [ ] Add failing asset layout/round-trip and paste regressions for session and QA markdown, large-image shrinking, and rejection of non-markdown/unanchored paths.
- [ ] Widen the pure asset key to file stems while retaining chat timestamp keys (ARCH-PURE/DRY); percent-encode link segments and validate/decode them in the existing attachment reader (ARCH-SECURE). Keep save, cap, shrink config, and paste rollback shared.
- [ ] Document sidecar layout and file-owner sweep in README/atlas (ARCH-FUNERAL); run targeted make -k checks and the pushed-head suite through sdlc local-check, then close review.

## Log

### 2026-10-14

- Claimed by parley.nvim:2 and entered planning. Refreshed Parley to 62a35b2aeb4a849cee910062a35ea02f0b5dba29 and private Ariadne to 407e48a39057503fab7cdecaf6c69ce338ce7631. Generated vocabulary drift belongs to concurrent #326; restored only that generated file per hub instruction and will integrate its landed main.
- Design uses the existing async clipboard → save/shrink → anchored insert path, its 10 MiB source cap, one in-flight paste per buffer, and rollback on failed insertion (ARCH-CONSTRAINTS/ORDER). No new external dependency: existing fake_clipboard/fake_sips exercise the same command seam (ARCH-MOCK). Markdown owners sweep unreferenced sidecars; deleting a line does not remove an image.
- Plan sent to ops:0 for approval; publication waits for SHIP.

## Revisions

- 2026-10-14 — add (operator): images must not be stored at full fidelity. The new sidecar path reuses the existing `assets` shrink step (sips/magick/…, JPEG within the max edge; `assets.shrink`/`shrink_cmd` honoured); add a test that a large paste into a non-chat markdown file lands shrunk.
