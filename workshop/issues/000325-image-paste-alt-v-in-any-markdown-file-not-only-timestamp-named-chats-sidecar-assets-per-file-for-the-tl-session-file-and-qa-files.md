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
flow: {kind: quick, provenance: inferred, spec: "d37ce80b", done: "fd08213e"}
---

# Image paste (Alt+v) in any markdown file, not only timestamp-named chats: sidecar assets per file, for the TL session file and QA files

## Problem

The operator wants to paste screenshots into the TL session file's `## Operator instructions` (ops `teams/<team>/tl-status-<operator>.md`) and into QA answer files (`teams/<team>/qa/<operator>/*.md`), 2026-10-14. Alt+v (`paste_image`) is bound in markdown buffers (lua/parley/init.lua, the markdown dispatch table), but `paste_image.paste` asks `assets.folder_for(path)`, which only accepts timestamp-named chats, so it refuses with "image paste needs a timestamp-named chat".

## Spec

`assets.folder_for` accepts any markdown file: the sidecar is `<dir>/assets/<file-stem>/<asset-timestamp>.<ext>`, still written only through `assets` (THE writer), with the same no-bytes-without-a-line guarantees. Chats keep their timestamp folders unchanged. Lifecycle stays the file owner's: parley never deletes an asset because a line was deleted. A separate sweep (the TL, for the session and QA files) removes assets no longer referenced. Document the sidecar in the README.

## Done when

- Alt+v in ordinary Markdown (session and QA files) saves a small PNG under `assets/<file-stem>/<ts>.png` and inserts its image link; deleting that link leaves owner-managed bytes. Chats retain timestamp folders (regression tests).
- An eligible large paste uses the existing shrink step and lands a smaller JPEG within the configured maximum edge; `assets.shrink`/`shrink_cmd` remain honored. Escaped stems resolve to the same bytes through reads and both message-builder budget checks (tests).

## Plan

- [x] Add failing asset layout/round-trip and paste regressions for session and QA markdown, large-image shrinking, and rejection of non-markdown/unanchored paths.
- [x] Widen the pure asset key to file stems while retaining chat timestamp keys (ARCH-PURE/DRY); percent-encode link segments and validate/decode them in the existing attachment reader (ARCH-SECURE). Keep save, cap, shrink config, and paste rollback shared.
- [x] Document sidecar layout and file-owner sweep in README/atlas (ARCH-FUNERAL); run targeted make -k checks and the pushed-head suite through sdlc local-check.

After verification: close review, then publish/merge on SHIP.

## Log

### 2026-10-14
- 2026-10-14: closed — BR-1: shared assets.resolve_path used by budget stat and bounded read; both message-builder regressions observed red (0 images), then green for space/punctuation/Unicode/percent/dotted stems. BR-2: Done-when explicitly covers small PNG, eligible large JPEG within max edge, shrink configuration, and unchanged chat folders. 17 mapped specs plus lint pass via make -k. Full suite passes on f721457ecbefcefa8c61b8a2a77b383c1bb14db7 (1m56s, log 2012be564fda); PR 234 merge-check 38610361921 green. Live sips non-chat save independently verified 6481758 bytes at 1800x1200 to 27563 bytes at 1600x1066.; review verdict: SHIP

- Claimed by parley.nvim:2 and entered planning. Refreshed Parley to 62a35b2aeb4a849cee910062a35ea02f0b5dba29 and private Ariadne to 407e48a39057503fab7cdecaf6c69ce338ce7631. Generated vocabulary drift belongs to concurrent #326; restored only that generated file per hub instruction and will integrate its landed main.
- Design uses the existing async clipboard → save/shrink → anchored insert path, its 10 MiB source cap, one in-flight paste per buffer, and rollback on failed insertion (ARCH-CONSTRAINTS/ORDER). No new external dependency: existing fake_clipboard/fake_sips exercise the same command seam (ARCH-MOCK). Markdown owners sweep unreferenced sidecars; deleting a line does not remove an image.
- Plan sent to ops:0 for approval; publication waits for SHIP.

- Hub approved the plan. Paused #325 to land #326 first as directed: PR #233 merge 813ef78f6eef65146fcf65a8b69b498208a21532; archived main 2a048860b52c104a51b66e35adc9c62f26a3f7b6 passed merge-check 38607834375. Integrated that main before change-code.
- Tests first failed for ordinary Markdown paste/layout/shrink and rollback; existing chat paths passed. Implemented pure key widening and canonical percent-escaped segments; read_bounded now validates the attachment grammar before decoding to an on-disk segment. A literal percent-escape in a stem remains literal after one decode. The test fixtures remain behind existing clipboard/shrink config seams (ARCH-DRY/SECURE/MOCK).

- make -k test-spec SPEC=chat/attachments lint passed: every mapped attachment spec, 0 lint warnings/errors across 723 files, clean orphan census. A real assets.save of a non-chat file named QA screenshots.md using default sips shrank 6,481,758 source bytes (1800×1200) to a 27,563-byte JPEG (1600×1066), independently probed with sips and read back through the escaped link. Temporary smoke assets removed.

- Full suite passed through sdlc local-check run --name suite on 422923118c212f5910e8dd3d8215f19c700722d0: exit 0, 2m27s, log sha256 prefix 7ea1e5bd15ae, no surviving test processes. PR #234 merge-check 38608792185 and local-gates guard both pass. Final targeted checks covered 17 mapped specs; git diff --check passed.

- Close round 1 returned REWORK: BR-1 identified the budget stat in chat_respond.asset_size using encoded URL text as a disk path; both build_messages and build_messages_from_model share it. BR-2 identified stale PNG-only Done-when. Added regressions for both builders over space/punctuation/Unicode/percent/dotted stems; will use one pure assets.resolve_path for budget stat and bounded read. Swept all att.path consumers: parser/content keep URL text, export uses image src URLs; only budget stat and bounded read touch the image disk path.

- BR-1 fix: assets.resolve_path is the shared pure resolver for read_bounded and chat_respond.asset_size (both builders). New parsed/live builder tests were red (0 images instead of 1), then green over every escaped-stem class; they assert both stat calls use the same absolute path and the image bytes reach the payload. The resolver round-trip and unsafe-path cases also pass. BR-2 fix: Done-when now covers small PNG, eligible large JPEG within max edge, configured shrink policy, and unchanged chats. make -k test-spec SPEC=chat/attachments lint passes, 0 warnings/errors; full suite will be rerun on the fix head.

- Fix-head full suite passed via sdlc local-check on f721457ecbefcefa8c61b8a2a77b383c1bb14db7: exit 0, 1m56s, log sha256 prefix 2012be564fda, no surviving test processes. PR #234 merge-check 38610361921 is green. Both review families now have their full consumer/contract correction and red→green evidence; ready for round 2.

## Revisions

- 2026-10-14 — add (operator): images must not be stored at full fidelity. The new sidecar path reuses the existing `assets` shrink step (sips/magick/…, JPEG within the max edge; `assets.shrink`/`shrink_cmd` honoured); add a test that a large paste into a non-chat markdown file lands shrunk.

- 2026-10-14 — plan clarification after #326 review: separate close-time verification from subsequent close/landing steps; the final checkbox now covers docs and completed checks only.

- 2026-10-14 — close BR-1/BR-2: expand verification to both send builders, centralize validated URL-to-disk resolution, and replace PNG-only Done-when with explicit small PNG/large JPEG and chat-preservation criteria. The writer/shrink contract is unchanged.
