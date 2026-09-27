---
id: 000229
status: open
created: 2026-09-10
updated: 2026-09-10
estimate_hours:
github_issue:
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
