---
id: 000228
status: done
deps: []
github_issue:
created: 2026-09-09
updated: 2026-09-10
estimate_hours:
started: 2026-09-09T21:19:38-07:00
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

## Revisions

### 2026-09-09 — the central hypothesis is wrong, and the issue is two defects

The Problem section reasons that the four early returns in the `schedule_wrap`'d
handler drop chunks, and that dropped chunks explain both the truncation *and*
the "stream accumulated zero content". **The second half does not hold**, and
the code says so plainly:

```lua
-- dispatcher.lua:291-295, inside process_line — the libuv stdout callback,
-- NOT scheduled, NOT deferred
local content = D._extract_sse_content(line, qt.provider)
if content and type(content) == "string" and content ~= "" then
    qt.response = qt.response .. content   -- accumulation happens HERE
    handler(qid, content)                  -- display is what gets deferred
end
```

`qt.raw_response` (`:369`) and `qt.response` (`:293`) both accumulate
synchronously on the libuv callback. Only `handler` is `vim.schedule_wrap`'d
(`:635`). So the guards at `:637-656` can discard a **display** chunk; they
cannot make `qt.response` empty, because it was already appended one line
earlier and on a different call stack.

That splits #228 into two defects with different causes:

- **A — "empty" with 18 KB of body.** `qt.response == ""` means
  `parse_sse_content` returned nothing for *every* line of the body. That is a
  shape/parsing failure, and the UI-activity correlation does not explain it.
  Cause still unknown; the raw body is the evidence and we do not have it yet.
- **B — truncation, and the UI-activity correlation.** A dropped display chunk
  leaves the *buffer* short of `qt.response`. If nothing reconciles the buffer
  against the accumulated response at end of stream, the transcript is
  permanently missing text the model actually sent — the same characters are in
  `qt.response` and absent from the file. That is the serious half.

**What this changes about the plan.** Step 1 (instrument the guards) still comes
first, but it now measures **B only** — and its value is higher than the Spec
credited, because a dropped display chunk is silent *and* the accumulated
response proves what was lost. **A needs the raw body**, which the Spec already
asks for as a fixture; without it, the salvage rewrite is a guess about a shape
we have not seen.

The Spec flagged its own hypothesis as unmeasured (*"This is a hypothesis, not a
measured finding"*). It was right to, and reading the accumulation path was
enough to falsify half of it before writing any code.

### 2026-09-10 — the raw log settles it: a token cap, not a lost stream

Reproduced with `:ParleyToggleRawLog`. The evidence is one turn in
`workshop/parley/.parley-logs/2026-09-09.12-21-03.569_guide-scope-vs-camera/raw.md`:

| fact | value |
|---|---|
| `max_tokens` (request) | **4096** |
| `stop_reason` | **max_tokens** |
| `output_tokens` | **4096** |
| `content_block_start` types | `thinking` × 1 |
| `text_delta` count | **0** |

The model spent its entire output budget on a single thinking block and never
emitted a text token. **`qt.response == "" ` was correct** — there was no text.
The 18 KB was all reasoning.

`max_tokens` caps OUTPUT for one response, and on Claude it **counts thinking
tokens**. The operator's system prompt mandates a thinking pass — *"Finish the
thinking process first before proceed to answer my question"* — so a 4096
budget exhausts itself before the answer starts. That is deterministic per
prompt, which is exactly the reported *"some chats always fail this way on
retry"*; and the same cap hit **after** some text has streamed is the
truncated-mid-answer symptom. One cause, both symptoms.

**The UI-activity correlation is most likely coincidental.** Long answers take
longer, one scrolls during long generations, and long generations are precisely
the ones that reach the cap. No evidence of a dropped chunk was found, and the
mechanism proposed for it is falsified above.

**Two fixes, both landed:**

1. `max_tokens` default 4096 → **64000** for Claude models (Anthropic's
   documented default for streaming requests, which is what parley makes).
   Keyed on the MODEL, not the provider — the same `claude-sonnet-5` arrives via
   `anthropic` and via `cliproxyapi`, while `cliproxyapi` also proxies `gpt-*`
   and `ollama` serves small local models, so a provider-level default would
   push a cap those cannot honour.
2. `_empty_response_reason` replaces *"response is empty: body_bytes=18152"*.
   Parley extracted `stop_reason` at `dispatcher.lua:309` and then discarded it:
   it had the answer and printed a contradiction. The three cases are now
   distinguished, and a body with bytes is never called empty.

**What remains open, and honestly re-scoped.** The four early returns still
discard a display chunk without counting it, and an `invalid` event finishes the
session and calls `on_discard` rather than repairing. Whether the complete
`qt.response` still reaches the buffer in that case is **unmeasured** — and it
is the only remaining way this issue could involve real data loss. It is a
different defect from the one reported, so it should be measured on its own
terms rather than folded in here.

## Spec

**1. Never drop a chunk silently.** Every early return in the scheduled handler
must count and log the drop with its reason. A stream that loses content should
say so at the moment it happens, not produce a confusing summary at the end.

**2. Make the failure honest.** Distinguish, in the message:

- the transport returned nothing (`body_bytes == 0`);
- the stream accumulated nothing but bytes arrived (**this case**);
- the salvage parse failed, and on what shape.

"response is empty: body_bytes=18152" is self-contradictory and sent the operator
looking for a token limit.

**3. Fix the salvage to understand streaming.** It must handle `delta.content`
across SSE events, not only non-streaming `message.content`, and must not depend
on a non-greedy match against an arbitrarily large body. Reassembling from the
recorded SSE events is preferable to re-parsing raw text at all.

**4. Then address the loss itself**, once step 1 has shown which guard fires.
Buffering chunks outside the scheduled callback, or making the writer resilient
to a transiently invalid window, are candidate directions — deliberately not
chosen here, because the measurement should pick.

## Done when

**Revised 2026-09-10**, after the raw log falsified the hypothesis these rows
were written under. The two rows about dropped chunks moved to #229 rather than
being deleted — they name a real code path, just not this issue's cause. The
salvage row is withdrawn with its reasoning below.

- A prompt that reasons past its output budget produces a **diagnosis**, not a
  contradiction: the message names the cap, says the cap counts thinking, and
  never describes a body with bytes as empty. ✅
- The three cases are distinguished — nothing arrived / stopped at the cap
  before any text / finished normally with no text. ✅
- `max_tokens` is high enough that a thinking-first prompt reaches its answer:
  **64000** for Claude models, keyed on the model so non-Claude models behind
  the same proxy keep their own caps. ✅
- The operator's reproducible case is a fixture. ✅ — synthesized to the same
  shape (one thinking block, no `text_delta`, `stop_reason: max_tokens`) rather
  than committed verbatim, because the captured body is 55 KB of the operator's
  private transcript and the thing under test is a message string.

**Withdrawn: "the salvage path extracts content from a real SSE body."** The
salvage only runs when `qt.response == ""`, and the reported instance of that
was *correct* — there was no text. The salvage's real defects stand (a
non-greedy `{.-choices.-}` against an arbitrarily large body, and requiring the
non-streaming `message.content` shape when a stream carries `delta.content`), so
it cannot rescue an OpenAI SSE body. But no observed failure runs through it:
fixing it would be speculative work on a path we have never seen fire. Recorded
here so the next person finds the analysis instead of redoing it.

**Moved to #229:** the buffer-vs-`qt.response` comparison under a busy main
loop, and counting the four silent discards in the scheduled writer.

## Plan

**Revised 2026-09-10.** Every row below was written before the raw log existed,
and step 1 — "make a drop visible rather than fix anything" — did its job: the
measurement falsified the hypothesis the other rows were built on. Each row is
dispositioned rather than ticked, because "done" and "no longer the right work"
are different outcomes and the difference is the finding.

- [x] **Capture a failing raw body as a fixture.** Done, and it is what settled
      the issue: `stop_reason: max_tokens`, one thinking block, zero
      `text_delta`. Committed as a synthesized equivalent — the captured body is
      55 KB of the operator's private transcript and the thing under test is a
      message string.
- [x] **Fix the message to distinguish the cases.** Done —
      `_empty_response_reason`, with the three cases separated and a body with
      bytes never called empty.
- [x] **Raise `max_tokens`** (row added; the original plan had no cause to
      expect it). 64000 for Claude models, keyed on the model rather than the
      provider.
- [x] **Instrument the four early returns** → **moved to #229.** They discard a
      chunk and count nothing, which is worth fixing, but they cannot produce
      the reported symptom: `qt.response` accumulates on the libuv callback
      before anything is deferred.
- [x] **Fix the loss per what step 1 shows** → **moved to #229.** Step 1 showed
      the loss was a token cap. Whether the display path also loses content is a
      separate, unobserved question with its own measurement.
- [x] **Test: stream + concurrent scroll → complete content** → **moved to
      #229**, where the oracle is stated properly as buffer text vs `qt.response`.
- [x] **Rewrite the salvage for `delta.content`** → **withdrawn**, with the
      analysis kept in Done-when. Its defects are real; no observed failure runs
      through it.

## Log


- 2026-09-10: closed — Round 4. make test exit=0 (366 spec files), make lint 0 warnings / 0 errors in 365 files, verified after the commit. BR-7 residue fixed — the part my whitelist could not reach. A mid-stream error event carries NO stop reason, so it arrives as nil, which _is_normal_finish treats as normal and correctly so (every ordinary non-streaming shape also has none); HTTP said 200 and the terminal closure believes it, so without reading the body the stream simply ends with partial text and nothing logged. D._inband_error reads the body — the only evidence such a failure happened — and surfaces the provider own message. That completes the set: the ending is named by the wire (_extract_stop_reason, three spellings, each with a per-wire test), classified normal or not (_is_normal_finish, a whitelist so unenumerated endings surface), given cap-specific advice when applicable (_is_output_cap), or found in the body when nothing else can see it (_inband_error). New fixture for the in-band shape; mutation-verified lint-clean, disabling the branch reddens J7k by name. BR-8 fixed: atlas/providers/architecture.md now documents the four predicates, why _is_normal_finish is a whitelist rather than the cap question I first asked (a spurious warning is cheap, a silently truncated transcript is not), and that max_tokens is a MODEL property — the same claude-sonnet-5 arrives via anthropic and cliproxyapi while cliproxyapi proxies gpt-* and ollama serves small local models, so the 64000 default is model-keyed. PROCESS NOTE, unchanged: I skipped sdlc change-code on this issue, so no branch was cut and no estimate derived, and the early commits reached origin/main before I noticed; estimate_hours left empty rather than back-fitted. Earlier rounds: root cause diagnosed from the operator raw log which falsified the issue own hypothesis; max_tokens raised to 64000 keyed on the model, goldens regenerated with a structural per-key diff; the misleading empty-response message replaced; truncation after partial text surfaced; per-wire spellings extracted and tested. Done-when and Plan revised with per-row dispositions, two rows moved to #229 and one withdrawn with reasoning.; review verdict: FIX-THEN-SHIP
### 2026-09-09

Filed from an operator report at their request, to avoid losing it. The
screenshot supplied the decisive fact — 18,152 bytes reported as empty — which
rules out the operator's initial "might be some limit exceeded" reading.

The operator's own observation that leaving the window alone during generation
avoids the problem is what points at the scheduled-handler guards; without it,
the non-greedy salvage regex would have looked like the whole story, and it is
only the half that turns a partial loss into a confusing message.
