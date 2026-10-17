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

