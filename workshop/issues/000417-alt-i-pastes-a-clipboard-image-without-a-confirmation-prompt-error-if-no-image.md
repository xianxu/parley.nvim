---
id: 000417
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: '2191b7c1be53cd4179409df50c365fdc90a7e5ab' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T18:01:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6c748c2d", done: "8119f216"}
---

# Alt+i pastes a clipboard image without a confirmation prompt; error if no image

## Problem

## Spec

Operator request (10-22): **Alt+i** (paste the clipboard image as an attachment, #231/#377) currently asks for
confirmation in the Vim command line before inserting. Drop the confirmation: if the clipboard holds an image, insert
it immediately; if it doesn't, show a clear one-line error ("No image in the clipboard") and change nothing.

- Applies in Normal and Insert mode, as today.
- Any naming or placement the confirmation used to let the operator choose falls back to the existing default.
- README and atlas updated.

## Done when

- Alt+i with an image in the clipboard inserts it with no prompt (test with a fake clipboard).
- Alt+i with no image shows the error and leaves the buffer unchanged (test).

## Plan

- [ ] Reproduce the prompt with a native UI and fake clipboard. The async save path currently has no explicit confirmation; guard against builtin notification hit-enter as well as input/confirm dialogs.
- [ ] Keep existing default attachment naming, placement, writer/shrink and rollback (ARCH-DRY). Remove the paste completion's blocking feedback; emit one-line error `No image in the clipboard` for no-image, with buffer/disk unchanged.
- [ ] Cover Normal/Insert mappings, image bytes, no prompt and absent-image no mutation through the existing fake and native UI on both supported Neovim versions. Update README/atlas, run suite and close review.


## Log

### 2026-10-22

### 2026-10-22 — quick-flow design

The existing clipboard-to-assets path does not call a confirmation dialog; its full-path success notice can trigger builtin hit-enter UI. First reproduce this through a real attached native UI instead of deleting an imaginary naming prompt. No new state, dependency or save protocol; existing terminal cleanup and shrink/error diagnostics remain authoritative (ARCH-PURPOSE/DRY). Posted the bounded plan to the hub, proceeding unless it objects.
