---
id: 000357
status: codecomplete
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'c829f7519d17945cc7eaa63157c90a6c2c90b0f6' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T11:11:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: 1.45
---

# Alt+Return times out under load: asynchronous submit, generous deadline, unconfirmed instead of failed

## Problem

Alt+Return times out under load. Operator request, relayed by the TL (ops:0) on 2026-10-16; part of universal-agent-input-interface.
- `document_registry` requests default to `timeout_ms` 2500, and `agentic_document`'s `bounded_request` blocks the editor in `vim.wait(2600)`.
- On a busy machine the couch CLI alone can take longer than that. The submit then fails as "Couch deadline exceeded", although it may still land.

## Spec

1. The submit is asynchronous. The editor never blocks in `vim.wait` for a Couch round trip, and the winbar shows "submitting…" meanwhile.
2. A generous deadline, about 15 s, configurable.
3. On the deadline the result is "unconfirmed", not "failed". Parley checks the receipt or the ledger for that submit before offering a resend, so the operator never double-submits. #332's dedup receipt helps here.
4. The other blocking waits get the same treatment, such as the 3000 ms move wait.

## Done when

- Tests with a slow fake Couch cover:
  - a submit that is slower than the old 2.6 s and still succeeds, with the editor not blocked meanwhile;
  - a deadline that ends unconfirmed and then resolves from the receipt, with no double submit;
  - the move wait under the same slow fake.
- After that, the operator's live check.

## Plan

**What the code does today** (read 2026-10-16; it corrects the issue's premise):
- **Alt+Return's submit is already asynchronous.** `agentic_document.M.submit` dispatches into the pure model, `document_session`. Its effects then run on callbacks:
  - `register` or `lookup`, through `document_registry.request` (`vim.system`, with a 2500 ms timer);
  - `save`, a local write;
  - `send`, which is `couch --send-to …` through `couch.run`, with **no deadline**.
- **What times out on Alt+Return** is the registry request, at 2500 ms, with the message "Couch registry deadline exceeded; mutation outcome may be unknown". The model then goes `pending`. The next Alt+Return is a `retry` with `resume_only`, which confirms the registration but **never sends**: "Registration confirmation must never automatically resend a message". So after a timeout the agent gets nothing until a *third* press. That is the bug the operator feels.
- **The editor-blocking waits** are `bounded_request`'s `vim.wait(2600)` ("Couch deadline exceeded") and the 3000 ms move wait. They are only on the move and rename paths: the Parley mover, `move_path`, and the `BufFilePre`/`BufFilePost` handlers. They are not on submit.

**Core concepts**

| Name | Lives in | Status |
|------|----------|--------|
| `begin_submit` | `lua/parley/agentic_document.lua` | new |
| `end_submit` | `lua/parley/agentic_document.lua` | new |
| `bounded_request` | `lua/parley/agentic_document.lua` | modified |
| `agentic_submit_timeout_ms` | `lua/parley/config.lua` | new |
| `agentic_move_timeout_ms` | `lua/parley/config.lua` | new |

There is no new pure entity. The pure model (`document_session`) already refuses a second send while one is in flight, and keeps the receipt. The changes are in the shell, the integration point that owns the timers and the band. Their tests use the slow fake Couch: `FAKE_COUCH_SLEEP` for sends, and the new `FAKE_COUCH_REGISTRY_DELAY` for the registry.

**The change**

1. **One submit deadline.** It is configurable as `agentic_submit_timeout_ms`, default 15000, and it covers the registry stage and the send stage together. `document_registry.request` takes it as `timeout_ms`. The registry child may still be killed at the deadline, since `register` and `lookup` are idempotent (same path, same owner). **A send is never killed**, because a kill can't tell delivered from not.
2. **The visible states**, through the existing band and feedback:
   - while the submit is in flight, a winbar "submitting…";
   - on the deadline, the red operator state "not confirmed: submit again", with the lock back to the operator (the session-sync turn is re-acquired if the send had already released it). That is one state with one action, Alt+Return;
   - on a late success, the usual "submitted to <owner> · HH:MM".
3. **An idempotent resubmit, using #332's receipt** (the hash of the saved bytes plus the registration ID and owner):
   - **A resubmit while the first send is still in flight** joins it: no second `couch --send-to`, and the band says "submitting…".
   - **A late success** of the first send still records the receipt, so an identical resubmit afterwards gets "nothing to submit: no changes since HH:MM", today's unchanged path. There is no double delivery.
   - **A first send that failed** (non-zero exit) records no receipt, so the resubmit really sends.
   - **A registry stage that timed out:** the resubmit from "not confirmed" completes the submit. It confirms the registration *and* sends, because the operator pressed again. The `resume_only` no-send rule stays for automatic retries only.
4. **The blocking waits on move and rename.** These run inside `BufFilePre`/`BufFilePost` autocmds, which must decide synchronously before Neovim renames the buffer. They can't become async without changing what a rename means. See the question for the TL.

**Tests** use a slow fake Couch. `tests/helpers/fake_couch.lua` already has `FAKE_COUCH_SLEEP` for sends, and `fake_couch_registry.py` gets a configurable registry delay in place of its fixed 1 s.
- `document_session_spec`, pure: the deadline goes to "not confirmed" with the lock back. A resubmit while the send is in flight issues no second send. A late `sent ok` records the receipt, and a resubmit then gets "unchanged". A registry timeout followed by a resubmit sends exactly once.
- Integration, through the real path with a slow fake:
  - A send slower than the old 2.6 s but under the deadline succeeds, and the editor is not blocked meanwhile: a scheduled tick runs during the wait.
  - A send that lands after the deadline: the operator resubmits the identical content, and the fake's send log holds exactly one delivery.
  - A registry stage slower than 2.5 s succeeds.

**Question for the TL** (spec point 4). Making the `BufFilePre`/`BufFilePost` rename preflights asynchronous means letting the rename proceed and reconciling afterwards, which is a design change to the move protocol. My proposal for #357:
- Make the waits configurable (`agentic_move_timeout_ms`), and on the deadline report "not confirmed", never "failed".
- Make `move_path`, the Parley mover's own path that doesn't sit inside an autocmd, asynchronous.
- File the autocmd-rename protocol change separately.

## Log

### 2026-10-16
- 2026-10-16: closed — Round 2 FIX-THEN-SHIP answered in 71341518, applying the rule that every timed call site needs a slow-fake test past the old default. The rename-stage test now delays 3 s against the old 2.5 s, and reverting its timeout_ms fails it (mutation run). New agentic_document_spec cases: an unregistered :saveas (BufFilePre membership lookup) times out with "move not confirmed ... Run the move again", nothing renamed, rerun succeeds; a legacy session file move with a slow admission register (DELAY_OPS=register) returns the run-it-again error, nothing moved, rerun moves it. Every bounded_request and registry.request call site is now covered by a slow-fake test past 2.5 s: open/register (3 s registry submit), lookup-submit, rename, move_path preflight and legacy register, BufFilePre and BufFilePost. agentic_document_spec has 8 slow-Couch cases, all green; round 1 evidence stands (pure resubmit with 3 model cases, the TL-approved send-stage lock Revision, README, DRY defaults). (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
- 2026-10-16: flow upgraded quick → full — 112 added lines in code files (limit 100); an earlier round of this close already ran the full review

- Built:
  - `begin_submit` and `end_submit`: one submit at a time, with "submitting…", the configured deadline, and "not confirmed: submit again · <reason>". A press during a send joins it. A pending press now confirms and then submits the current bytes; the replay is skipped while still pending, so it can't loop.
  - The registry stage takes the submit deadline.
  - `bounded_request` uses `agentic_move_timeout_ms`, and the registry's own timer sits past it. On the deadline: "move not confirmed: Couch did not answer within N s; nothing moved. Run the move again". `move_path` returns that error for its destination lookup.
- Existing tests changed on purpose:
  - The "edited in-flight registration … without automatic resend" case now expects the next press to submit the current text. Its old assertion was the operator's bug.
  - Two band cases expect "not confirmed: submit again" in place of "operation failed:" for submit failures.
- New tests in `agentic_document_spec`, "under a slow Couch (#357)", 4 cases:
  - a registry at 3 s submits, and the press returns in under 500 ms;
  - a send past a 1 s deadline: not confirmed, a press joins, the late success arrives, and the identical resubmit gives "nothing to submit". Exactly one delivery;
  - a lookup past the deadline keeps the lock, and the next press sends once;
  - a move preflight past 500 ms returns the run-it-again error with nothing moved, and the rerun moves it.
- Mutation checks:
  - Without the pending-press replay, the edited-registration case fails.
  - With the registry left at its 2500 ms default, the 3 s registry case fails.

## Revisions

- 2026-10-16 Operator amendment, relayed by the TL (delivery 53e28eff), replacing Spec point 3:
  - On the deadline, parley returns the lock to the operator and shows the red "not confirmed: submit again" state. That is one state with one action, Alt+Return.
  - There is no ledger check before a resend. Instead the resubmit is idempotent: an identical resubmit (same file, same content) must not deliver twice.
  - To verify: that #332's dedup receipt covers this.
  - To test: a slow fake Couch where the first submit lands after the deadline, and the resubmit is not delivered twice.
- 2026-10-16 TL decisions on the plan:
  - Approved: one deadline, never killing a send, and the join rule.
  - Spec point 4: do (a). Filed (c) as #359, unclaimed. No full asynchronous rename here.
  - Re-plan: `move_path`'s callers in init.lua (moving one chat, moving a chat tree) are synchronous chains, so (b) folds into #359. #357 does (a) only.
  - The actions split at "before anything moved", where the action is "Run the move again", and "after", where the existing journal recovery applies.
- 2026-10-16 Send-stage lock, approved by the TL as option (A), replacing the amendment's "return the lock to the operator" for the SEND stage only:
  - The registry stage keeps the operator's lock, because the send never started.
  - At a send-stage deadline the lock is NOT re-taken. The send already released it, as today, and it may still land. A re-taken lock would refuse the agent's answer (exit 3), and the operator's identical resubmit gives "nothing to submit", which never releases the lock. The answer would stay stuck until the text changed: the stuck-answer case.
  - The red "not confirmed: submit again" band still makes the resubmit obvious, which was the operator's intent. Their next edit takes the turn as usual.
- 2026-10-16 Close review round 1 was REWORK. Its fixes:
  - Critical: the shell's queued submit could outlive a pending rename or reconcile. "Confirm then submit" is now the pure model's `retry{submit=true}` → `resubmit` effect, only for a pending register. It has 3 `document_session_spec` cases.
  - The rename stage takes the async deadline.
  - At BufFilePost, which runs after Neovim renamed, a timeout says "rename not confirmed … rename back to OLD, then run it again", the cancel path that exists. It has a `:saveas` test.
  - A test for the post-begin wait, using a rename-only registry delay: the move finishes through the journal.
  - README documents the two keys and the states.
  - The defaults live only in config.lua.
  - Seconds round up.
  - The Plan's pure cases for the deadline, the join and the late receipt live in the shell's integration tests, because the deadline timer and the band are shell state. The model already refused a concurrent send.
- 2026-10-16 Close review round 2, FIX-THEN-SHIP. Its rule: every timed call site needs a slow-fake test whose delay is past the old default.
  - The rename-stage test now uses 3 s against the old 2.5 s. Reverting its deadline fails the test.
  - New: an unregistered document's `:saveas` (BufFilePre's membership lookup) times out with "move not confirmed … Run the move again", nothing renamed, and the rerun works.
  - New: a legacy session file's move, with a slow admission `register` (`DELAY_OPS=register`), says to run it again, and the rerun moves it.
  - Every `bounded_request` and `registry.request` call site now has its slow-fake test: open, register, lookup, rename, the move preflights, and BufFilePre and BufFilePost.
