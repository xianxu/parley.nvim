---
id: 000357
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: 'c25bb4b786c5ec701b113b8a667d601c5b90e0e4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T11:11:49-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "13367de4", done: "fbefdbd5"}
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

## Revisions

- 2026-10-16 Operator amendment, relayed by the TL (delivery 53e28eff), replacing Spec point 3:
  - On the deadline, parley returns the lock to the operator and shows the red "not confirmed: submit again" state. That is one state with one action, Alt+Return.
  - There is no ledger check before a resend. Instead the resubmit is idempotent: an identical resubmit (same file, same content) must not deliver twice.
  - To verify: that #332's dedup receipt covers this.
  - To test: a slow fake Couch where the first submit lands after the deadline, and the resubmit is not delivered twice.
