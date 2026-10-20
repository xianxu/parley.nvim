---
id: 000401
status: working
deps: []
github_issue:
created: 2026-10-19
updated: 2026-10-19
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'c4ee7f49a1664586f53e874f229aee7b6089b369' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-19T17:57:41-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "134144a6", done: "1ebb975b"}
---

# document_fold_retirement_spec: silent 43 s case stalls under suite load

## Problem

`tests/integration/document_fold_retirement_spec.lua` stalled in #394's recorded suite on 59b6cd14 (attempt 2e99c5ad6d069ce4b1cac89edd5bf005). It hung in the compat pass (installed nvim 0.11.7) with 0 cases completed, and the suite killed it after 180 s idle. The same file passed in that run's preferred pass in 19 s. The unchanged rerun on the same head passed every file, but sdlc judged the first failure unattributable and won't record the pass over it.

The one case builds a 50,010-line document in an embedded child nvim (`jobstart --embed`) and prints nothing until it finishes. Run alone, it takes 43 s on the preferred runtime, the slowest file in `chat/document`. Under the suite's parallel load it can plausibly pass the 180 s idle deadline. Its `vim.rpcrequest` calls to the child have no timeout, so a wedged child would also hang until the harness kills it, with no diagnosis.

## Spec

Make the case's cost and its failure bounded and diagnosable:
- Size the document to the smallest that still suspends folds, or report progress so the idle deadline sees life.
- Bound every request to the child, so a wedged child fails with a message instead of a silent stall.

## Done when

- The case runs well inside the idle deadline under suite load (a measured margin).
- A wedged embedded child fails the case with a named cause, not a harness kill.

## Plan

Measured (2026-10-19), with the case's code run directly in a headless nvim:
- Nearly all of the cost is `D.drain` of the 50,010-line fixture: 14–17 s on the preferred runtime and 25 s on the installed 0.11.7. The fold steps themselves take about 0 s. Drain time is linear (6,250 / 12,500 / 25,000 / 50,010 lines: 1.5 / 3.6 / 7.4 / 16.9 s); that's the parser's cost, which `perf_document_spec` tracks.
- The fixture has 50,010 lines only to cross `tool_folds`' `INTERACTIVE_ROWS` (50,000), the scope above which folds are suspended.
- `document_fold_uncertainty_retirement_spec` has the same shape: one silent case of about 30 s, with a 50,010-line drain.
- Nine specs drive an embedded nvim through `vim.rpcrequest`, 21 call sites, none of them bounded. This is the class to fix (ARCH-PURPOSE).

Steps:
- [x] `tests/helpers/embedded_nvim.lua`, the one way a spec drives a child nvim (ARCH-DRY):
  - `start({ ui = { w, h } })` spawns `--clean --embed --headless -i NONE`, optionally attaches a UI, and appends the repo to the child's runtimepath.
  - `request(method, ...)`, `exec(code, ...)`, `input(keys)`, `stop()`.
  - Every request is bounded by `REQUEST_MS`. On expiry a libuv timer kills the child by pid; the timer runs in a fast callback, where `jobstop` isn't allowed. The pending `rpcrequest` then errors on the closed channel, and the helper raises `embedded nvim did not answer <method> within N ms; killed pid P`.
  - `REQUEST_MS` is 4 × `arrival.MS` (60 s): a request stretched up to the harness's load factor (at most 4) still fits, and a wedged child is named well before the 180 s idle kill.
- [x] Sweep all nine specs onto the helper. No `vim.rpcrequest` left in `tests/integration`; an arch spec refuses a new one outside the helper (the mistake-class rule).
- [x] `tool_folds.INTERACTIVE_ROWS` becomes a module field, read at each use (the repo's `POLL_MS` pattern). The two retirement specs set it to 500 in the child and build a fixture just past it, so each case drains a few hundred lines, not 50k. The real 50,000 threshold stays covered by `document_fold_batches_spec` and the perf spec, which keep the constant.
- [x] Tests:
  - The helper's timeout: a child blocked in `exec` (a busy loop) fails, naming the method, after a short bound; checked against an injected `REQUEST_MS`.
  - Both retirement cases now take seconds; measured before and after on both runtimes, and the numbers logged.

## Log

### 2026-10-19

### 2026-10-19 (implementation)

- Prototype: a libuv timer that kills the child by pid unblocks a pending `vim.rpcrequest` ("ch N was closed by the peer") on both runtimes. `jobstop` isn't allowed in that fast callback; `uv.kill` is.
- Sweep: all nine specs now drive their child through `tests/helpers/embedded_nvim.lua`; no `vim.rpcrequest` or `--embed` spawn is left outside it.
- Scope addition (same class): both retirement specs came off `spec_runner`'s 180 s run-alone list; they now run in 1–2 s under the default 50 s budget. The fold batches and semantic corpora keep the long budget and the real 50k threshold.
- Measured, each retirement spec alone: 30–43 s before, 1–2 s after, on both the preferred runtime and 0.11.7.
- Red checks:
  - A raw `vim.rpcrequest` added to `stream_view_spec` fails the arch guard.
  - Removing `F.INTERACTIVE_ROWS=500` fails both retirement cases ('did not suspend'), so the small fixture still exercises suspension.
- Helper spec: a busy child fails its request, naming `nvim_exec_lua`, the 500 ms bound and its pid, and the child is reaped.
- Targeted runs green: `infra/test_harness`, `chat/document`, `chat/exchange_model`, `context/file_references`, `modes/session_sync`.

