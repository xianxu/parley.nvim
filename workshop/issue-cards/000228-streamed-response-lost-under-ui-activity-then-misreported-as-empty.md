---
id: '000228'
status: done
started: 2026-09-09T21:19:38-07:00
created: 2026-09-09
updated: 2026-09-10
actual_hours: 2.61
---

# streamed response lost under UI activity, then misreported as empty

## Problem

Operator report, with a screenshot of the failure:

```
Parley.nvim: cliproxyapi response is empty: body_bytes=18152
```

**The body was 18 KB and parley called it empty.** The message is wrong on its
face, and it is not a token limit or a provider-side truncation — the bytes
arrived.

Two symptoms, and the operator's own observation ties them together:

- some chats **always** fail this way on retry;
- others come back **truncated** mid-answer;
- and critically: *"this seems to happen more often when I'm interacting with
  the page, scrolling and such. if I left it alone during generation, it seemed
  fine."*

That last sentence is the strongest evidence in the report and points at a
**main-loop contention** bug rather than anything about the model or the
transport.

### What the error actually means

`dispatcher.lua:312-313`:

```lua
local content = qt.response
if content == "" and qt.raw_response:match("choices") and qt.raw_response:match("content") then
```

`qt.response` is the content **accumulated by the SSE stream handler**. The block
that follows is a *salvage* path that only runs when streaming produced
**nothing at all**. So the reported condition is not "the response was empty" —
it is:

> the SSE stream accumulated zero content, **and** the salvage parse also failed.

The primary failure is the lost stream. The message names the secondary one.

### Why the salvage cannot rescue it

`dispatcher.lua:319`:

```lua
local json_str = qt.raw_response:match("{.-choices.-}")
```

The pattern is **non-greedy**, so on a large body it matches the first, shortest
`{…choices…}` fragment — in an SSE body that is a partial chunk. It then requires
the **non-streaming** OpenAI shape:

```lua
response.choices[1].message.content
```

but a streamed body carries `choices[1].delta.content`. So for any SSE response
the salvage is structurally incapable of extracting anything, whatever its size.
An 18 KB body and a 200-byte one fail identically.

### Why UI activity makes it worse — the likely mechanism

The stream handler is `vim.schedule_wrap`'d (`dispatcher.lua:635`), so every
chunk is deferred to the main loop, which is exactly what scrolling and redrawing
contend for. Inside it, several guards **return without recording the chunk**:

```lua
local qt = tasker.get_query(qid);      if not qt then return end
if not vim.api.nvim_buf_is_valid(buf) then return end
if type(chunk) ~= "string" then return end
if opts.before_write and not opts.before_write(qid, chunk) then return end
```

Each is a silent drop: the chunk is discarded and nothing counts it. That gives
one mechanism for **both** symptoms — a few dropped chunks read as a truncated
answer, and enough of them read as "empty". It also explains why leaving the
window alone during generation appears to work.

**This is a hypothesis, not a measured finding.** The guards and the
`schedule_wrap` are read from the code; that one of them fires under scrolling
has not been observed. The first plan step is to make a drop *visible* rather
than to fix anything.

### Prior art in this file

`dispatcher.lua:336-339` already records that this message has misled before:

> Record, don't report (#197). finish_stdout runs BEFORE the terminal closure and
> cannot know whether the request actually succeeded, so logging here made every
> credential failure announce the misleading "response is empty: body_bytes=215"
> ahead of the real diagnosis

So the message has now misreported at least twice, for two different underlying
causes. That is a signal the message itself is the defect, not only its callers.
