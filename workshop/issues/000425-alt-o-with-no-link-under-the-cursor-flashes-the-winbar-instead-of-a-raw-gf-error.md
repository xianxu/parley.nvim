---
id: 000425
status: working
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '74d9512693d342a92d3c1ffc38e74d68a3b3b32d' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T12:32:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d464156b", done: "0b48457d"}
---

# Alt+o with no link under the cursor flashes the winbar instead of a raw gf error

## Problem

## Spec

**Alt+o on text with no link shows a raw Lua error (operator, 10-23).** Alt+o's fallback (lua/parley/init.lua:5151,
called from :5196) runs `normal gf` on the word under the cursor; when that word isn't a file (e.g. "error"), Vim
raises E447 "Can't find file in path", and it surfaces as an E5108 stack trace with "Press ENTER". Screenshot:
ops `assets/session/2026-10-23.11-27-34.920.jpg`.

Fix: when there's nothing to open under the cursor (no link, no resolvable path), do nothing except a brief visual
cue: **flash the winbar**. If the buffer has no winbar (not Alt+Returned, so not tracked by Couch), show a transient
winbar just for the flash and remove it. No error, no message prompt. A real failure to open an existing link still
reports clearly.

## Done when

- Alt+o on plain text produces no error or prompt and flashes the winbar, with or without an existing winbar (test).
- Alt+o on a valid link or path still opens it (existing tests pass).

## Plan

- [ ] Catch only native gf no-target E446/E447 at its owning fallback, with an Alt+o callback; keep direct gf and explicit target errors intact.
- [ ] Reuse the shared document_band pulse/layer owner for a quiet same-window cue, temporary bar restoration and Insert-mode restoration (ARCH-DRY, ARCH-ORDER).
- [ ] Add red-first native Normal/Insert no-target cases with/without bars, valid path and missing-link controls; verify shared pulse cleanup and override behavior, then recorded suite and close.

## Log

### 2026-10-23

Root cause: ResolveRefOrGotoFile calls normal! gf without handling native E446/E447. OpenFileUnderCursor catches and rethrows that error, so a normal no-target gesture becomes E5108 and a prompt. Existing document_band owns pulse timers, window layers, restoration proofs and navigation cancellation; reuse that owner instead of an independent notification timer. Alt+o supplies the no-target callback; direct gf retains its native failure behavior. Hub plan posted, proceeding under the quick-flow rule unless objected.

Actions: Alt+o, edit, navigate. | Internal state | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| No resolvable target | Brief No file to open bar cue, then original bar | Edit or navigate to a target and retry Alt+o | None |
| Window navigates/closes or bar overridden during pulse | Current window/bar survives; pulse retires | Continue editing/navigation | None |
| Existing explicit reference fails | Existing clear diagnostic | Correct the reference and retry Alt+o | None |

Creates nothing durable: a pulse owns one finite timer and window layer, removed by completion/navigation/window-close. Navigation remains one existing scan; no added per-byte work. The fixed six pulse frames are independent of document length. No storage, registration, fold, or editing behavior changes. ARCH-PURE: no new business model; this is the existing thin UI/command boundary.
