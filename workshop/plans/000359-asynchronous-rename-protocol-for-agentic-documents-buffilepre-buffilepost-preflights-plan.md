# Asynchronous rename protocol for agentic documents: implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** No move or rename of an agentic document blocks the editor on a Couch round trip, except a `:saveas!` onto an existing file. That is an explicit overwrite, and it keeps a bounded wait.

**Architecture:**
- Today three kinds of synchronous wait guard a move:
  - **W1, identity:** is OLD a registered document?
  - **W2, destination:** is no other document registered at NEW?
  - **W3, completion:** `move_path` waits for the whole move.
- All three can go, because each one either is already known locally or is enforced again later by an asynchronous authority:
  - **W1:** answered from the identity parley already holds. When it holds none, the move refuses at once, nothing moved, and starts the lookup so the rerun has the answer.
  - **W2:** dropped. Couch's own `rename` refuses an occupied destination (`target-conflict`), and the filesystem's no-replace rename guards NEW's bytes.
  - **W3:** dropped. `document_move.advance` moves the file on disk synchronously, and only its metadata step is asynchronous.
- The journal's existing forward recovery carries everything after "moved".

**Tech stack:** Lua (Neovim), the existing `document_move` journal, `document_registry`, and the fake Couch registry.

**Depends on #357 landing.** #357 introduced `bounded_request`'s configurable deadline, its "not confirmed" messages and the slow-fake tests (`FAKE_COUCH_REGISTRY_DELAY`, `_OPS`). This plan replaces most of those waits, so it builds on #357's code and starts after #357 merges (#272: no stacking). The design is independent.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `move_preflight` | `lua/parley/document_move_plan.lua` | new |
| `move_outcome` | `lua/parley/document_move_plan.lua` | new |

- **`move_preflight(known)`** is a pure decision from what parley already knows. Its input `known` holds:
  - `identity`: a registration, `"plain"` (positively absent), or `"unknown"`;
  - `legacy`: an owner from `type: session-sync`, or nil;
  - `new_exists`, `overwrite`: whether NEW is on disk, and whether this is `:saveas!`.

  It returns one of:
  - `{ proceed = true }`;
  - `{ plain = true }`, a plain rename that never registers;
  - `{ refuse = "identity", lookup = true }`;
  - `{ refuse = "legacy", register = true }`;
  - `{ wait_destination = true }`, only for an overwrite onto an existing NEW.

  Its tests are colocated in `tests/unit/document_move_plan_spec.lua`, which already exists for this module. It needs no IO.
  - **Relationships:** it is called once per move by each of the three entry points: `move_membership`/`move_path`, `BufFilePre` and `BufFilePost`. That is N:1.
  - **DRY rationale:** today each entry point re-derives "do I need Couch?" with its own `bounded_request`. One decision table replaces three call-site variants, so they can't drift (#357 round 2 found exactly such drift).
- **`move_outcome(journal_steps, registry_result)`** is a pure projection from the journal's progress and the metadata step's registry reply to `{ state, band, action }`. It is the state projection table below, as code, with unit tests per row.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.move_membership` | `lua/parley/agentic_document.lua` | modified | registry lookup |
| `M.move_path` | `lua/parley/agentic_document.lua` | modified | `document_move.begin`/`advance` |
| `BufFilePre` / `BufFilePost` handlers | `lua/parley/agentic_document.lua` | modified | Neovim rename events |
| `bounded_request` | `lua/parley/agentic_document.lua` | modified | used only by the `:saveas!` overwrite |
| `fake_couch_registry.py` | `tests/fixtures/` | reused | `target-conflict`, delay knobs (#357) |

The integration tests use the stateful fake registry with #357's delay knobs, plus its existing `target-conflict` for an occupied NEW.

### ARCH-FUNERAL

This creates nothing durable. The journals are `document_move`'s existing family, with their existing removal: success unlinks, and recovery replays. The async identity lookup a refused move starts is an in-memory registry request, cancelled on detach.

## The state projection table

What the operator sees at every point of a move, and the one recovery action. "Nothing moved" means neither the disk nor the registry changed, so rerunning is idempotent.

| # | Internal state | What the operator sees | The one action |
|---|---|---|---|
| 1 | Identity known (registered), destination not an existing file | The move happens at once; the band reads `moving: confirming with Couch`, then clears | none |
| 2 | Identity `plain` (positively absent) | A plain rename at once; a background recheck follows | none |
| 3 | Identity `unknown` (the open-time lookup is still pending or failed) | `move not confirmed: Couch hasn't confirmed this document yet; nothing moved. Run the move again`; the lookup is started | rerun the move |
| 4 | Legacy `type: session-sync` file, not yet registered | `move not confirmed: registering this document first; nothing moved. Run the move again`; the register is started asynchronously | rerun the move |
| 5 | Moved on disk; the metadata rename still in flight past `agentic_submit_timeout_ms` | `move not confirmed: finishing in the background` (warning colour); saving works | none; it clears on success, or becomes row 6 or 7 |
| 6 | Moved on disk; Couch refused the rename with `target-conflict` (a stale registration at NEW) | `move not confirmed: NEW is registered to another document. Run: couch --session-sync forget NEW, then reopen` (NEW is the literal path, so the operator can paste the command) | forget NEW, then reopen; the journal replays the rename |
| 7 | Moved on disk; the metadata reply was lost or uncertain | `move pending: reopen to recover` (today's journal recovery) | reopen |
| 8 | `:saveas!` onto an existing file, destination check answered absent within `agentic_move_timeout_ms` | as row 1 | none |
| 9 | `:saveas!` onto an existing file, destination registered, or the check timed out | `rename not confirmed: …; rename back to OLD, then run it again` (today's text, from #357) | rename back, rerun |

The rows that stay synchronous are 8 and 9, an explicit overwrite of an existing file. Every other row never waits on Couch.

## Why each wait can go, and the risk it trades

- **W1, identity.** Parley caches registrations per namespace (`cache`, 256 entries) and seeds the model from that cache at attach, so a document the operator has submitted or opened before is known synchronously.
  - "Unknown" means Couch hasn't answered the open-time lookup. Refusing at once, row 3, is safe and costs one rerun.
  - "Plain" means positively absent at open. The residual risk is that another actor registered the file since then. The rename then leaves that registration at OLD. Row 2's background recheck (`M.recheck`, which already runs on a plain rename) finds it, and Couch's `lookup` of OLD reports it absent-with-file-gone, which is today's behaviour for an external `mv`.
- **W2, destination.** Couch's `rename` is the authority and refuses an occupied NEW. That's documented in `couch --skill` ("An occupied destination refuses without replacing its identity"), and the fake returns `target-conflict`. Dropping the pre-check moves the refusal from before the move to after the file moved: row 6. NEW can only be registered while its file is absent if the registration is stale, since an existing file at NEW is row 8 or 9. So row 6 is the rare stale-registration case, and its action names the fix.
- **W3, completion.** `advance` performs the rename, the `.side/` move and the backlink rewrites synchronously, and only `metadata` is asynchronous. So `move_path` returns `new_path` once `journal.steps.document_moved` holds. The chat movers in `init.lua` stay synchronous and keep their sequence: file, assets, references. They no longer wait on Couch.

## Tasks

### Task 1: `move_preflight` and `move_outcome` (pure)

**Files:** Modify `lua/parley/document_move_plan.lua` and `tests/unit/document_move_plan_spec.lua`.

- [ ] Write failing tests, one per row of the table: rows 1–4 and 8–9 for `move_preflight`, rows 5–7 for `move_outcome`. Include a test that `move_outcome`'s band texts and actions match the table verbatim.
- [ ] Run `make test-spec SPEC=tests/unit/document_move_plan_spec.lua`. Expected: FAIL (functions missing).
- [ ] Implement both functions as table-driven code with no IO.
- [ ] Run the spec. Expected: PASS.
- [ ] Commit.

### Task 2: the movers stop waiting (W1, W2, W3 in `move_membership` and `move_path`)

**Files:** Modify `lua/parley/agentic_document.lua` and `tests/integration/agentic_document_spec.lua`.

- [ ] Write failing tests, all with a slow registry (`FAKE_COUCH_REGISTRY_DELAY=3`, past both deadlines):
  - A registered document's `move_path` returns `new_path` in under 500 ms, the file at NEW. The band clears once the 3 s rename lands. (Rows 1 and 5.)
  - A document whose identity is unknown, because the open-time lookup is held: `move_path` returns row 3's error in under 500 ms, and nothing moved. The rerun after the lookup lands moves it.
  - A legacy session file: row 4, then the rerun moves it.
  - A stale registration at NEW (register NEW, then delete its file): the move lands on disk, and the band shows row 6, its text naming the literal NEW path in the runnable `couch --session-sync forget NEW` command. After `forget NEW` and a reopen, the journal finishes.
- [ ] Run them. Expected: FAIL (today's code blocks, or returns #357's run-it-again text after the wait).
- [ ] Implement:
  - `move_membership` decides by `move_preflight` with no wait. A refusal starts the async lookup or register and returns at once.
  - `move_path` drops its destination lookup. After `advance_move` it returns when `document_moved` holds, and renders `move_outcome` into the band on the async result.
- [ ] Run them. Expected: PASS. Run the whole of `agentic_document_spec`: #357's move cases change from "waits, then run it again" to "refuses at once". Update them, and record each change in the Log.
- [ ] Commit.

### Task 3: `BufFilePre` and `BufFilePost` stop waiting, except for an overwrite

**Files:** Modify `lua/parley/agentic_document.lua` and `tests/integration/agentic_document_spec.lua`.

- [ ] Write failing tests, all under a slow registry:
  - `:saveas NEW` (NEW absent) of a registered document completes in under 500 ms and lands as row 1.
  - `:file NEW` of an unknown-identity document refuses at once with row 3, and the buffer keeps its name.
  - `:saveas! EXISTING`, where EXISTING is registered to another document, is still refused before anything is written. The other file is unchanged (row 9, today's test kept).
  - `:saveas! EXISTING`, where EXISTING is plain, succeeds within the move deadline (row 8).
- [ ] Run them. Expected: FAIL.
- [ ] Implement:
  - `BufFilePre` decides by `move_preflight`. It refuses at once for rows 3 and 4, and has no `bounded_request` except where NEW exists. Neovim gives `BufFilePre` no NEW name, so it reads NEW in `BufFilePost` and decides the overwrite there.
  - `BufFilePost` calls `bounded_request` only for `new_exists`, which is `:saveas!` onto an existing file. Otherwise it begins the journal with the destination left to Couch.
- [ ] Run them. Expected: PASS. Then run the agentic, owned_move, lifetime, band and session_sync specs.
- [ ] Commit.

### Task 4: `document_move.begin` accepts a destination left to Couch

**Files:** Modify `lua/parley/document_move.lua`, `lua/parley/document_move_plan.lua` (`project`'s `destination_registered` observation, line 208), `tests/integration/document_move_spec.lua`, `tests/unit/document_move_plan_spec.lua`.

- [ ] Write failing tests:
  - `begin` with `destination_registered = "authority"` (new) journals the move, and a `target-conflict` metadata reply leaves the journal pending with the conflict as its error. Today `begin` refuses unless the destination is confirmed absent.
  - `project` with `"authority"` treats the registry as undecided rather than occupied. The side-directory check stays as it is.
- [ ] Implement: `destination_registered` accepts `false` (confirmed absent, as today) or `"authority"` (Couch's rename decides), in both `begin` and `project`. Recovery is unchanged: replaying the rename after a `forget` succeeds.
- [ ] Run the journal and move specs, then commit.

### Task 5: atlas, README, close

- [ ] Rewrite the move paragraph of `atlas/modes/session_sync.md`: the state projection table in short, and that only an overwrite waits. Rewrite the README's move sentence to match.
- [ ] Run the full suite: `sdlc local-check run --name suite`.
- [ ] Close the issue with `sdlc close`.

## Open questions for the TL

1. **Row 2's residual risk** (a plain document registered by another actor between open and rename). I'd accept it, with the background recheck as the backstop. It is today's external-`mv` behaviour, and the alternative re-adds W1's wait for every plain rename.
2. **Row 6's action names a Couch command** for the operator to ask the agent for. The alternative is an automatic `forget` of a stale NEW registration, a mutation of another document's identity that I'd rather not automate.

## Revisions

- **2026-10-16, TL review (ops:0).** The design is approved. Building waits for #357 to land (#272).
  - (1) Row 2's residual risk is accepted: it equals today's external `mv`, and the background recheck catches it.
  - (2) There is no automatic forget. The change is that row 6's message shows the exact, pasteable command with the literal NEW path (`Run: couch --session-sync forget <NEW>, then reopen`), so the operator needs no agent. The row 6 test asserts that text.
  - The operator's actions reduce to five: nothing, run again, reopen, forget and reopen, rename back.
