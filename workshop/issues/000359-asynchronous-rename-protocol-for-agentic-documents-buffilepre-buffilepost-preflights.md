---
id: 000359
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
severity: low
card_mirror: '79500d940f4625450ce5167c0a3b94a65af54dda' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T12:52:47-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b6b87e44", done: "edfeb538"}
---

# Asynchronous rename protocol for agentic documents (BufFilePre/BufFilePost preflights)

## Problem

The rename preflights for agentic documents block the editor on a Couch round trip. They run inside `BufFilePre` and `BufFilePost` autocmds, for a `:file` or `:saveas`-style rename of a document, in `lua/parley/agentic_document.lua`:
- `bounded_request`: `register` or `lookup` in `vim.wait`;
- the destination `lookup`.

These autocmds must decide synchronously, before Neovim renames the buffer, so on a busy machine the editor freezes for the length of the wait. #357 makes the waits configurable and reports "not confirmed" instead of failing, and makes the Parley mover's own `move_path` asynchronous. It deliberately leaves this protocol alone (TL decision, 2026-10-16).

## Spec

Let the rename proceed without waiting, and reconcile the registry afterwards. The registry move is recorded as pending, and confirmed or reported once Couch answers. This is a change to the move protocol: the window between the editor's rename and the registry's must be safe. No agent write goes to the old path, and no lock is lost.

## Done when

- A `:saveas` or `:file` rename of an agentic document never blocks in `vim.wait`.
- The registry ends up renamed, or the operator sees one recovery action.
- Tests use a slow fake Couch registry.

## Plan

The durable plan, with the state projection table: [000359 plan](../plans/000359-asynchronous-rename-protocol-for-agentic-documents-buffilepre-buffilepost-preflights-plan.md). It is waiting for the TL's review, and its code waits for #357 to land.

- [ ] Task 1: `move_preflight` and `move_outcome` (pure)
- [ ] Task 2: the movers stop waiting
- [ ] Task 3: `BufFilePre` and `BufFilePost` stop waiting, except for an overwrite
- [ ] Task 4: `document_move.begin` and `project` accept a destination left to Couch
- [ ] Task 5: atlas, README, close

## Log

### 2026-10-16

### 2026-10-16 (build notes, before code)
- The code is now unblocked: #357 landed (PR #277) and main is merged in. `change-code` inferred the quick flow. If the diff leaves the shell, the close review upgrades itself.
- Mechanics found while reading the code:
  - **The registry reply drops the Couch code.** `document_session.classify_reply` maps a non-ok reply, `target-conflict` included, to `{kind = "unavailable", error = Error}`. Row 6 needs the code, so `classify_reply` must carry `code = decoded.Code` on unavailable results.
  - **The rename reply path.** The model's `moved` event issues `rename`. An invalid rename reply becomes `pending(operation, error)`, which emits a `reconcile` effect and never calls `moving.metadata_done`, so the journal stays pending and `s.move` stays set. Rows 5 to 7 render from there.
  - **Where W3 lives.** `M.move_path` blocks on `vim.wait(agentic_move_timeout_ms, s.move == nil)` after `advance_move`. Done means returning once `journal.steps.document_moved` holds.
  - **Where W2 lives.** `M.move_path` asks `bounded_request("lookup", {new_path})`, and so does `BufFilePost` today.
  - **The identity cache.** It is synchronous: `cache(s)` reads `known.json` under a lease. `M.identity(buf)` is the loaded model's registration.
  - **`begin`'s guard.** `document_move.begin` refuses `destination_registered ~= false` at line 342 and passes `false` to `project`.
- Task 2 is built: the movers no longer wait on Couch.
  - `move_membership` decides by `move_preflight`. For identity it checks, in order: the loaded model's registration, the namespace cache, the loaded model's positive absence, then an in-memory answer from an earlier background lookup.
  - An unknown identity or a legacy document refuses at once and asks in the background: a lookup, or a register that caches its registration.
  - `move_path` has no destination lookup (`destination_registered = "authority"`) and no completion wait. It returns once `steps.document_moved` holds and `advance` reported no pending handoff on the spot.
- Found while building, fixed and tested:
  - **Saves during the rename.** Row 5 lets the operator save while the rename is out, but the journal proved the move by the original inode and bytes, so a save then made rows 6 and 7 unrecoverable. Added `document_move.record_write`, called from BufWritePost while the operation runs. It sets `steps.saved_after_move`, and validation and recovery then prove the move against the recorded save. Tested both ways in `document_move_spec`; removing the call fails the owned-move "Couch unavailable" case.
  - **The rename's request timeout.** The band warns at the submit deadline; the rename request itself gets 3x, because the registry starts its timer at enqueue.
  - **Where the outcome shows.** session_sync holds its winbar still while it is moving, so the outcome renders through the agentic band, styled by `feedback_view`.
  - **Row 6's wording.** The label is capped at 160 characters, so NEW is named once ("the destination is registered to another document. Run: couch --session-sync forget NEW, then reopen"), and the notification carries the whole command uncut.
- Changed tests, all behaviour changes the design intends:
  - #357's three move cases became rows 1, 5, 3, 4 and 6.
  - The destination-race test became "never looks up the destination".
  - Owned-move: the receipt and unloaded-door cases now wait for Couch's confirmation after the move returns. "Refuses unavailable membership" became row 7: a held identity moves while Couch is down, and the journal recovers on reopen. The legacy case now refuses first (row 4).
- Task 3 is built: the rename hooks stop waiting.
  - `BufFilePre` decides by `move_preflight` over `known_identity`. It refuses rows 3 and 4 at once, with the name unchanged, and asks in the background. A background register for a loaded buffer adopts its result, so the rerun sees the identity.
  - `BufFilePost` asks Couch only when NEW already exists, which is the `:saveas!` overwrite (rows 8 and 9, #357's bounded wait kept). Otherwise it begins with `destination_registered = "authority"` and the shared `moving_metadata` hook: confirming, then background.
- Rewritten agentic_document_spec cases, all intended:
  - #357's `:saveas` timeout became row 9: a `:saveas!` onto an existing file says to rename back.
  - New: a registered `:saveas` to an absent file returns in under 500 ms (row 1).
  - The unregistered `:saveas` timeout became row 2: a plain rename asks Couch nothing.
  - "Confirmed-absent plain native rename" became row 3: it refuses while the open lookup is held, then renames plainly.
  - "Submit pumped during the OLD lookup" became "asks Couch nothing inside a plain native rename".
  - Owned-move: the legacy alias `:saveas` now refuses first (row 4), and the register still gets the canonical caller path.
- Seen once: "moves an unloaded registered ordinary file through the public tree door" failed once with no output kept, then passed 9 runs in a row. Watching for it in the suite.

