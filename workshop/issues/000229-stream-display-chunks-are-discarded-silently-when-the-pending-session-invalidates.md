---
id: 000229
status: open
deps: []
github_issue:
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
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

## Plan

- [ ] Instrument the four early returns: count + log with reason
- [ ] Build a test that invalidates the pending extmark mid-stream and compares
      the buffer against `qt.response`
- [ ] Read the measurement; record what actually fires and how often
- [ ] Choose the remedy from what step 3 shows, or close with the evidence that
      no content is lost

## Log

### 2026-09-10

Split from #228 rather than folded in: #228's cause is settled (a token cap)
and its fix shipped, while this path is real code but unobserved. Keeping them
together would have meant either holding a fixed issue open for a speculative
one, or closing a Done-when row that was never met.
