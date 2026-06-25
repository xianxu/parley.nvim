---
id: 000138
status: done
deps: []
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours: 2
started: 2026-06-25T15:33:57-07:00
actual_hours: 2
---

# Chat-lease false-positives cancel valid chat requests

## Problem

Since #137 (chat lease), **valid chat requests are cancelled** with the warning
`chat transcript changed during pending request` and produce **no output**. It
reproduces on a plain prompt (e.g. "hello") to a cliproxyapi Claude agent with
web search disabled, and is **worse with web_search** (where it was near-100%).

The same root cause also surfaced earlier in the session as:
- `cliproxyapi response is empty: ""`, and
- upstream `cliproxyapi` 500s logged as `{"error":{"message":"context canceled"}}`
  (because cancelling the pending request kills parley's in-flight `curl`, so the
  proxy sees the client disconnect mid-stream).

## Spec

**Root cause.** `chat_lease.validate` (`lua/parley/chat_lease.lua:44`) invalidates
the lease whenever `lease.baseline_changedtick ~= current_changedtick`. The
baseline is captured in `chat_respond.lua:1378` (`chat_lease.begin`) right after
the placeholder lines are inserted, and the **first** stream callback validates at
`chat_respond.lua:1398`. Between those two points the **response spinner /
pre-first-token render writes to the chat buffer without calling
`chat_lease.commit()`**, so `changedtick` drifts and the very first `validate`
fails → the request is cancelled before any content is written.

This is why:
- a slow first token (web_search) makes it deterministic (more spinner ticks
  before content), while a fast first token sometimes slips through;
- raw `curl` replays of the *exact* failing request always succeed (no lease, no
  spinner);
- commenting out the drift check in `validate` restores normal operation.

`cc15556 (#137: guard topic spinner leases)` committed the lease for the **topic**
spinner but not for the **main response spinner / streaming render path**.

**Fix.** Every Parley-owned buffer write between `begin` and the first content
write must call `chat_lease.commit(buf, generation, new_changedtick)` — in
particular the response spinner tick and any pre-first-token progress render. The
contract is already documented in `chat_lease.lua` ("Guarded Parley-owned writes
call commit() with the new tick"); the spinner/streaming render path violates it.
Alternative: have `validate` tolerate Parley-owned writes (compare against the
last committed tick that Parley itself produced) rather than a single baseline.

## Done when

- A plain prompt (no web search) and a web_search prompt to a cliproxyapi Claude
  agent both stream output without the `chat transcript changed during pending
  request` warning.
- A genuine user edit / undo during a pending request still invalidates the lease
  (the #137 behavior is preserved — only the self-inflicted false positive is fixed).
- Test: simulate a spinner tick (a Parley buffer write that does not call
  `commit`) between `begin` and the first `validate`, and assert the request is
  NOT cancelled; plus a test that a non-Parley edit between writes still cancels.

## Plan

- [x] Replace `chat_lease`'s `changedtick` drift check with an `invalidate=true`
      extmark anchored on the response's `🤖:` agent-header line; `validate` =
      anchor still valid (generation check retained); `commit` → no-op.
- [x] Anchor via `chat_respond` `begin` on `model:block_start(target_idx, 2)`
      (agent-header — stable under streaming/spinner/clear, removed by undo).
- [x] Move the lease spec to `tests/integration/` (extmarks need a real buffer);
      cover tolerate-in-place/above-edits, invalidate-on-anchor-delete, stale
      generation, explicit invalidate, clear-by-generation; fix `traceability.yaml`.

## Revisions

### 2026-06-25 — pivot from "commit every writer" to an extmark-anchored lease

The original Spec/Plan (make the response spinner `commit()` the lease, mirroring
`cc15556`) was the wrong fix. The response spinner is web-search-only
(`chat_respond.lua:1291`), yet the false-positive also hit plain prompts — so a
*different* uncommitted writer was at fault, and #137's raw-`changedtick` detector
turns *every* future writer into a fresh regression (whack-a-mole; `cc15556` was
the first mole). **Delta:** anchor the lease structurally via an `invalidate=true`
extmark on the `🤖:` agent-header line — the actual "insertion-point structure"
the lease should protect. Ordinary edits and streaming are tolerated (the editor
moves the mark); only deleting that line (undo/redo of the response, or the user
removing the marker) cancels. This generalizes the guard and removes the need to
`commit()` at all, so the whole commit-treadmill (incl. cc15556) becomes moot.

## Log

### 2026-06-25
- 2026-06-25: closed — Plain + web-search prompts now stream output (no "transcript changed" false-cancel); structural delete/undo/redo still cancels. chat_lease_spec 8/8 + chat_respond_spec 29/29 (incl #137 drift tests) pass; luacheck clean. (actual=2h labeled judgment — active-time found no measurable window.); review verdict: FIX-THEN-SHIP

- Found while debugging a cascade of cliproxyapi errors. Confirmed root cause by
  replaying the exact failing request through raw `curl` (no lease/spinner) — it
  streamed fine every time — and by disabling the drift check in
  `chat_lease.validate`, after which a plain "hello" returned output normally.
- #137 landed 2026-06-25 (HEAD is 204 commits past v2.1.0, which predates the
  lease), matching when the breakage started.
- Implemented the extmark pivot (see Revisions). Empirically verified the extmark
  semantics headlessly first: a point mark with `invalidate=true` tolerates
  in-place edits + edits to lines above (rides gravity) and flips `invalid=true`
  on line-deletion/undo. Anchored on the agent-header (block 2) because
  `stream_replace_at_line` is `set_lines(l,l+1,…)` — it replaces the *stream* line
  every chunk and would trip `invalidate`; the header sits above all streaming.
- **Verified:** `tests/integration/chat_lease_spec` 8/8; `chat_respond_spec`
  29/29 (incl. the #137 undo/redo/recursion drift tests still cancelling
  correctly); `luacheck` 0/0 across 226 files. The single failing spec
  (`parley_harness_golden_spec`, request-payload round-trip) is **pre-existing** —
  fails identically with the two changed source files reverted to HEAD — and
  unrelated to the lease.
- The prior session's temporary `validate` workaround is superseded by the rewrite.
- Boundary review (#69) verdict **FIX-THEN-SHIP**, no Critical. Addressed the one
  Important finding (atlas §8 gate): reworded the stale `changedtick`/commit lease
  description in `atlas/chat/lifecycle.md`, `atlas/chat/exchange_model.md`,
  `atlas/providers/tool_use.md` to the extmark-anchor mechanism, and fixed a
  misleading `agent_blk_idx` comment ref. Deferred minors (non-blocking, noted by
  the review): pcall-swallow diagnostic in `chat_lease.begin`, a two-block
  `validate` DRY fold, a README "requires Neovim ≥0.10" note, and a web_search
  spinner-clear-doesn't-invalidate test.
