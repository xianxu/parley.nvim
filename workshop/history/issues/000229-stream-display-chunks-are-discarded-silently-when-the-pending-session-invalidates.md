---
id: 000229
status: done
deps: []
github_issue:
created: 2026-09-10
updated: 2026-10-15
estimate_hours:
card_mirror: '4cccf702e2136e137ec9e6c5d1ce55bff7745542' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T18:29:35-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.56
---

# Stream display chunks are discarded silently when the pending session invalidates

## Problem

Split out of #228, which was reported as "streamed response lost under UI
activity". That report's headline turned out to be a token cap (#228 Revisions:
one thinking block, `stop_reason: max_tokens`, zero `text_delta`), and the
mechanism #228 proposed for the loss was falsified — `qt.response` accumulates
synchronously in the libuv stdout callback (`dispatcher.lua:293`), before
anything is deferred, so the scheduled handler's guards cannot empty it.

What that investigation did NOT clear is this: the scheduled display handler has
four early returns that discard a chunk and count nothing.

```lua
-- dispatcher.lua, inside vim.schedule_wrap(function(qid, chunk) ...
local qt = tasker.get_query(qid);      if not qt then return end
if not vim.api.nvim_buf_is_valid(buf) then return end
if type(chunk) ~= "string" then return end
if opts.before_write and not opts.before_write(qid, chunk) then return end
```

The fourth is the interesting one. `chat_pending`'s `before_write` returns false
when the lease is invalid, when the buffer is gone, or when the pending
extmark's position comes back invalid — and in the last two cases it dispatches
`{ type = "invalid" }`, which drives the session to `finished` and calls
`on_discard`. It **discards**; it does not repair.

So the accumulated `qt.response` can hold text that never reached the buffer.
Whether the complete response still lands by some other path (the `on_exit`
leg, `reconcile_stream_span`, a collapse-and-rewrite) is **unmeasured** — and
that measurement is the whole issue. If it does not, a transcript can be
permanently missing text the model actually sent, silently.

**Severity is unknown by construction.** This is a latent path, not a reported
failure: no dropped chunk has been observed. It is filed because a silent
discard on a write path is worth measuring on its own terms rather than assumed
benign.

## Spec

**1. Measure before fixing.** Instrument the four early returns to count and log
a discard with its reason, then drive a stream against a main loop made busy
enough to invalidate — redraw, scroll, an extmark invalidated by a concurrent
edit. Read the log. The instrumentation is worth keeping regardless of what it
shows: a write path that drops content must say so.

**2. The oracle is `qt.response` vs the buffer.** The accumulated response is
ground truth for what the model sent, and it is already complete by
construction. A test here should compare the buffer's answer text against
`qt.response` and assert equality — that comparison is also the fix's oracle,
and it is cheap because both sides already exist.

**3. Only then decide the remedy.** Candidates, deliberately not chosen here
because the measurement should pick: reconcile from `qt.response` at end of
stream; buffer chunks outside the scheduled callback and replay after a
transient invalidation; or make the writer re-anchor on an invalid extmark. The
first is smallest and self-healing, but it rewrites a region the user may have
touched — which is why it needs evidence rather than preference.

## Done when

- The buffer's answer text equals `qt.response` after a stream driven against a
  busy main loop — asserted, not observed.
- No early return in the scheduled writer discards a chunk without counting and
  logging it, with a reason.
- If the measurement shows discards never lose content (some reconcile path
  already covers them), that is a valid outcome: record where the reconciliation
  happens and close, keeping the counters.

## Core concepts

| Entity | Kind | Status | Location | Responsibility |
| --- | --- | --- | --- | --- |
| `create_handler` | INTEGRATION | deleted | `lua/parley/dispatcher.lua` | The scheduled writer with the four silent early returns; no production caller since the generation runner. |
| `stream_replace_at_line` | INTEGRATION | deleted | `lua/parley/buffer_edit.lua` | Only consumer was `create_handler`. |
| `tasker` | INTEGRATION | modified | `lua/parley/tasker.lua` | A throwing stdout reader ends the attempt with a recorded I/O error instead of continuing past the line. |
| `stream_position` | PURE | deleted | `lua/parley/stream_position.lua` | Tip computation for `create_handler`'s cursor follow; no other consumer. |
| `undojoin` | INTEGRATION | deleted | `lua/parley/helper.lua` | `helper.undojoin`, used only by `create_handler`; the document editor joins undo itself. |
| `stream_integrity_spec` | INTEGRATION | new | `tests/integration/stream_integrity_spec.lua` | The Done-when oracle: buffer answer equals `qt.response` under interference. |
| `fake_cliproxy` | INTEGRATION | modified | `tests/fixtures/fake_cliproxy` | A `stream` response mode: many separate content deltas. |

## Plan

Measurement (2026-10-15, :3). The path the issue names is dead code: `D.create_handler` (the scheduled writer with the four early returns) has no production caller, and chat_pending's `before_write` is gone. Chat streaming is now tasker stdout → `dispatcher` `process_line` (`qt.response ..= content`, then handler) → `response_provider` → `generation_runner.cb.output` → the generation machine → `document.append` → `nvim_buf_set_text`. Every refusal on that path STOPS the generation with an outcome the user sees: not alive → revoked/cancelled; overflow; write stale/refused/interrupted; queue discarded with `discarded_bytes`. The one point where a drop can coexist with continued streaming is a Lua error inside the stdout reader. `tasker.call_safely` only logs it; the dispatcher's line loop keeps the unconsumed line, so the next chunk re-processes it, risking a repeated or skipped line, not counted, stream continues. Two silent STALLS (no drop, a possibly hung generation: a machine-rejected output, and a short `applied` receipt) are a different symptom and get their own issue.

- [x] Delete `D.create_handler`, `buffer_edit.stream_replace_at_line` and `create_handler_spec`. The silent early returns go with their only writer (the issue's Done-when 2, by removal).
- [x] tasker: a failed stdout/stderr reader callback ends the attempt with an `io_error` naming the reader, the same terminal path as the retention limit, so the generation fails visibly instead of streaming past the line. Red-first regression: a reader that throws once → the attempt stops with that error; before the fix it keeps running.
- [x] Oracle (Done-when 1): an integration spec drives a real chat response (real dispatcher, tasker, curl, runner, document) against `fake_cliproxy` in a new `stream` response mode (N separate content deltas). A buffer-attach hook makes the main loop busy and inserts a line above the answer on every streamed write. After completion, assert the buffer's answer text equals `qt.response` (less the deliberately stripped leading newlines) and that the inserted lines survived.
- [x] File the two silent-stall paths as a separate issue with the measured file:line evidence.
- [x] Atlas: where streamed bytes can stop and how each is accounted.
- [x] Verify: focused specs, then the full suite.

## Log

### 2026-10-15 (:3)
- 2026-10-15: closed — Prior evidence stands (reader red 29/1 to 30/0; stream_integrity exact equality 3/3, mutation fails; full suite exit 0 on f606daff). Advisory (a): read-error path is one (err,nil) notice then one EOF, not a doubled EOF; comment corrected, tasker_run case pins the sequence (43/0); lint clean.; review verdict: SHIP
- 2026-10-15: closed — Measured: issue path was dead code (create_handler, no production caller); live path stops the generation on every refusal except a throwing reader. Red: tasker_supervision reader case 29/1 before, 30/0 after (data after a throw skipped, attempt stops with stdout reader failed, EOF still delivered per #182, tasker_run 42/0). Oracle stream_integrity_spec: real transport, 300 deltas, >=10 edits above the answer and busy slices; answer equals qt.response exactly 3/3; dropping one delta fails it. Dead writer and orphans removed. Full make -k test exit 0 on f606daff, lint clean. Stalls filed as #341.; review verdict: SHIP

- Measured (an Explore digest, each finding checked at file:line): the issue's path was dead code. See the Plan's measurement paragraph. Remedy chosen from that evidence: no reconcile pass. The live path already ends the generation on every refusal. The two silent-continue risks were the dead writer, removed, and a throwing reader, now terminal.
- Reader failure, red first: `tasker_supervision_spec` "ends the attempt visibly when a stream reader throws" failed 29/1 before the fix (the second piece was delivered after the throw) and passes 30/0 after. All reader calls, including EOF, go through one guard.
- Dead writer removed with its orphans: `create_handler`, `stream_replace_at_line`, `helper.undojoin`, `stream_position` (+ unit spec) and `create_handler_spec`. stream_view_spec's legacy-writer cursor-follow block was replaced by a direct `helper.cursor_to_line` test, since that helper is still used in `init.lua`. stream_view, buffer_edit, dispatcher_query and every arch spec pass; lint is clean.
- Oracle: `stream_integrity_spec` (300 deltas from `fake_cliproxy` `stream` mode, at least 10 interleaved edits above the answer, plus a 3 ms busy slice per write). The answer equals `qt.response` exactly, 3/3 runs. Mutation (temporary file copy): skipping the handler for the 50th delta while `qt.response` still accumulates fails it at the equality assertion.
- Filed #341 (unclaimed) for the two silent-stall paths, with file:line evidence.

### 2026-09-10

Split from #228 rather than folded in: #228's cause is settled (a token cap)
and its fix shipped, while this path is real code but unobserved. Keeping them
together would have meant either holding a fixed issue open for a speculative
one, or closing a Done-when row that was never met.
- Full suite on fe577185: one failure, tasker_run_spec "contains throwing readers and still drains both streams once" (#182). It pins that a reader which threw still receives its EOF. That contract holds: EOF lets a reader release what it holds. The guard now skips only later DATA for a failed reader and still delivers EOF once. tasker_run 42/0, tasker_supervision 30/0, stream_integrity 1/0.
- Full suite on f606daff: exit 0, lint clean (736 files).
- Close advisory (a), folded in at the TL's SHIP. The reported doubled EOF is an error notice, (err, nil), followed by one EOF, (nil, nil); the dispatcher reader logs the first and finishes on the second. The comment now states that contract, and a tasker_run case pins the exact sequence: data, notice, one EOF, with a late EOF after the error ignored. No red step: the behavior was already correct and only the comment was imprecise. tasker_run 43/0, tasker_supervision 30/0, lint clean. Advisory (b) is left as is per the TL: same shape as the retention limit. (c): #341 is on main.
