---
id: 000266
status: working
deps: []
github_issue:
target: transcript-is-the-whole-truth
created: 2026-09-17
updated: 2026-09-17
estimate_hours:
started: 2026-09-17T11:06:53-07:00
---

# Serialize transcript mutation: queue generations, insert tool call/result pairs in order

## Problem

Transcript mutation is concurrent today, and the resulting edit history is not
something a user can reason about. Up to four generations may write one document
(`document/state.lua:190`, `if count(s.generations)>=4 then return reject('generation limit')`),
and within a single tool round every call block plus every `(Tool result pending)`
placeholder is appended in one write, after which results fill their reserved
slots **in completion order** (`response_tools.lua:137-170`):

```lua
for i in ipairs(calls)do
    append('

')
    local first=length
    append('(Tool result pending)')
    slots[i]={first=first,last=length}
end
```

So the buffer's undo chain carries entries from unrelated exchanges interleaved,
and holes that fill out of document order. Undo rewinds someone else's answer;
the user cannot predict what a keystroke restores. That unreasonable history is
the reason a bespoke restore sidecar existed beside the file at all — see
[[transcript-is-the-whole-truth]] and parley#261. Fixing the history is what lets
the sidecar be deleted rather than replaced.

This issue knowingly **reverses a #254 decision**. `atlas/chat/ownership.md:8`
currently promises "Disjoint generations may write separate answers while the
human edits the next question." That was a reasonable throughput choice; it is
being traded for a history a person can hold in their head. The atlas must be
rewritten, not merely appended to.

## Spec

**The invariant: concurrency belongs in scheduling and execution, never in
mutation.** Requests run in parallel; tool calls execute in parallel; writes land
one at a time, in the order the reader sees them.

### 1. Generations — concurrent execution, serialized writes

Operator decision: option (b), not full queuing. A second generation's provider
request *starts* while the first is still streaming; its output is **held** until
the first generation's writes are complete, then applied in full. One writer per
document at any instant.

Consequences to design:

- `document/state.lua:190`'s limit of 4 concurrent generations becomes a limit on
  concurrently *admitted* generations, with exactly one holding write authority.
  The write turn is a queue, ordered by admission.
- Held output needs an explicit byte bound and a defined behavior at the bound
  (ARCH-CONSTRAINTS). A held generation can be waiting behind a long tool chain,
  so this is not a small buffer. Name the budget, its basis, and what happens
  when it is exceeded — the existing staging limits (`generation_runner.lua:75`,
  1 MiB per generation / 16 MiB process-wide) are the precedent to reuse or
  supersede, not to duplicate (ARCH-DRY).
- Cancellation, revocation and staleness must be expressible for a generation
  that is *complete but not yet written*. That is a new lifecycle state; enumerate
  it explicitly rather than encoding it as a boolean pair (ARCH-ORDER).

### 2. Tool rounds — concurrent execution, serialized `(call, result)` insertion

Replace the bulk upfront reservation with monotonic ordered append: insert tool
call 1's block and its result, then call 2's block and its result, and so on in
call order — even when call 2's result returns first. The transcript grows
forward and never fills a hole.

Consequences to design:

- The reserved-slot mechanism and the child-grant machinery that exists to police
  those slots both become unnecessary. Removing them is part of the deliverable,
  not a follow-up (ARCH-PURPOSE); a serialized append that still carries the slot
  bookkeeping is the easy subset.
- Progress visibility must not regress. Today the user sees all calls in a round
  immediately. After this change the transcript shows only what has landed, so
  concurrent progress belongs in the **presentation** layer — `chat_pending`
  extmarks, which by contract never become Markdown, undo entries, saved text or
  request context (`atlas/chat/response_progress.md`). Presentation may stay as
  concurrent as it likes precisely because it is not the transcript.
- A tool whose result never arrives must not stall the ones behind it forever.
  Define the ordering guarantee against an unresolved call (skip-with-marker,
  bounded wait, or explicit failure), and cover it — an unknown outcome is
  already the hardest case in the batch model.

### 3. Atlas

`atlas/chat/ownership.md` and `atlas/providers/tool_use.md` state the current
disjoint/ordered-slot model as fact. Both are consumers of this decision and must
derive from the new one, not restate the old (ARCH-PURPOSE shadow-sweep).

## Done when

- One writer mutates a transcript at any instant; a second generation's output is
  held and applied whole, in admission order.
- A tool round appends `(call, result)` pairs in call order regardless of result
  arrival order; no placeholder text is written and later overwritten.
- The reserved-slot and child-grant machinery that only existed to police
  out-of-order fills is deleted.
- Undo over a session with two concurrent generations and a multi-call tool round
  walks backwards in document order, and a test asserts that ordering rather than
  only asserting final content.
- Held-output byte budget is declared with its basis and its behavior at the
  bound, and a test drives the overflow path.
- An unresolved tool call has a defined, tested effect on the calls behind it.
- `atlas/chat/ownership.md` and `atlas/providers/tool_use.md` describe the
  serialized model; no page still promises disjoint concurrent answer writes.
- No regression in batch sequencing, cancellation, or reload/detach retirement.

## Plan

- [ ] Design pending — `sdlc start-plan` then author the durable plan via
      `superpowers-writing-plans`.

## Log

### 2026-09-17

Split out of parley#261 during its planning. #261 (delete the external answer
recovery store, rely on in-session memory) depends on this: removing a targeted
restore is only safe once the undo history it falls back to is linear and
document-ordered. Sequencing is this issue first or alongside, never after.

Operator framing: "this presents a linear history user understands, while
allowing concurrent scheduling of things to happen."
