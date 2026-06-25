---
id: 000138
status: working
deps: []
github_issue:
created: 2026-06-25
updated: 2026-06-25
estimate_hours:
started: 2026-06-25T15:33:57-07:00
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

- [ ] Make the response spinner / pre-first-token render `commit()` the lease after
      each Parley-owned write (mirror the topic-spinner guard from `cc15556`).
- [ ] Add a regression test for spinner-tick-during-pending-request (no cancel) and
      a real-edit-during-pending-request (still cancels).
- [ ] Re-enable the drift check in `chat_lease.validate` (revert the temp workaround).

## Log

### 2026-06-25

- Found while debugging a cascade of cliproxyapi errors. Confirmed root cause by
  replaying the exact failing request through raw `curl` (no lease/spinner) — it
  streamed fine every time — and by disabling the drift check in
  `chat_lease.validate`, after which a plain "hello" returned output normally.
- **Temporary workaround currently in the working tree** (uncommitted): the
  `baseline_changedtick ~= current_changedtick` block in `chat_lease.validate` is
  commented out. Revert it (`git checkout lua/parley/chat_lease.lua`) once the
  spinner/render path commits the lease.
- #137 landed 2026-06-25 (HEAD is 204 commits past v2.1.0, which predates the
  lease), matching when the breakage started.
