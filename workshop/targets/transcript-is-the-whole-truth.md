---
type: target
slug: transcript-is-the-whole-truth
status: active
created: 2026-09-17
updated: 2026-09-19
sources:
  - "parley#261 — the audit that enumerated every state outside the transcript and found the one authoritative violation"
  - "parley#254 — hardened chat ownership/concurrency; introduced the disjoint-generation model this target deliberately reverses"
  - "operator session 2026-09-17 — 'there shouldn't be external store to begin with, and is the purpose of this audit'"
---

# Target: The transcript is the whole truth — nothing outside the file may be authoritative over it, and its history stays linear

A Parley chat is one Markdown file. That file is the complete state of the
conversation: what was asked, what was answered, what the tools did, and what may
legally happen next. A user can open it in Parley, in plain vim, or in another
editor entirely; hand-edit it; restore it from git; copy it to another machine —
and then submit it. **In no situation may metadata kept outside that file prevent
someone from working on it.** That is the shape we defend.

The failure this target exists to prevent is specific and was real: a sidecar
store became a *precondition*. Regenerating an answer required a successful write
to a private directory under the profile, with no fallback branch — so a wrong
file mode, a restored backup, a full quota, or a stray file in a directory the
user had never heard of could refuse to let them work on their own transcript,
across every chat, permanently, with no in-editor remedy and no error message
naming the path. The bug was not the store's implementation. It was the
*direction of authority*: the file had become downstream of its own metadata.

The second half of the commitment is what makes the first half liveable.
Authority is only half of "the truth is in the file" — the other half is that its
**history is comprehensible**. Concurrent writers mutating one transcript produce
an edit history interleaved across unrelated exchanges, so undo rewinds someone
else's answer and the user cannot predict what a keystroke will restore. A
history the user cannot reason about is not a usable source of truth, and it is
what drives the temptation to build a bespoke restore mechanism beside the file —
which is how the sidecar was born in the first place. So: **mutation of the
transcript is serialized and document-ordered.** Concurrency belongs in
scheduling and execution, never in mutation. Requests may run in parallel; tool
calls may execute in parallel; the *writes* land one at a time, in the order the
reader sees them.

Together these give a system with one place to look and one history to reason
about. When something genuinely cannot live in the file — bytes the Markdown no
longer holds — the preference order is: keep it in memory for the session and let
it die with the process; else use a base editor mechanism that already exists
(`undofile`, native undo) rather than inventing our own; and in every case it is
advisory, never a gate. Losing it degrades an affordance. It never blocks a user.

## Why now

The #261 audit was commissioned on a hunch and found exactly one subsystem
authoritative over the chat file, plus a second class of process- and
buffer-scoped state that outlived the buffer and survived the reopen the user
reached for. The architecture underneath was sound — no registry keyed by file
path, reload revoking every grant, structure rebuilt from the bytes — which is
what makes this the right moment to state the invariant rather than patch the
instance. The violations were at the edges of a correct design, and edges drift
back unless something names them.

The serialization half is newly decided and reverses a documented choice:
`atlas/chat/ownership.md` currently promises that "disjoint generations may write
separate answers while the human edits the next question." That was a reasonable
throughput decision and it is being traded, knowingly, for a history a person can
hold in their head.

## What this is NOT

- **Not a ban on all state outside the file.** Caches, indexes, logs and
  transport files are fine. The test is authority and blocking: may its absence,
  staleness, corruption or exhaustion change or refuse what the user can do to
  the transcript? If yes, it violates this target. If no, it is an accelerator.
- **Not a ban on concurrency.** Provider requests and tool executions run in
  parallel. Only *mutation* serializes. This is a write-ordering commitment, not
  a throughput ceiling.
- **Not a promise of crash durability.** Quitting mid-generation may leave a
  partial answer in the transcript, and that is an accepted outcome, not a defect
  to engineer around. The file is whatever it says it is.
- **Not a rewrite of the document core.** The #254 index, grants, epochs and
  repair machinery stay. This constrains who may write and in what order, not how
  structure is derived.
- **Not a statement about presentation.** Extmarks, spinners, folds and
  diagnostics are display projections and may be as concurrent and as ephemeral
  as they like, precisely because they never become Markdown.

## Open questions

- **How far does "provenance" belong in the file?** Under stock config the
  transcript records no model, provider or system prompt, so the same file
  answers differently for two people. That is a different sense of the same
  commitment and may deserve its own target rather than living under this one.
- **Where is the boundary for sidecars the user already accepts?** Asset folders
  hold image bytes the Markdown genuinely cannot carry, and they degrade visibly
  without blocking — the model this target points at. Does the same latitude
  extend to future binary payloads, or is `assets/` the last one?
- **What bounds the in-session memory that replaces durable recovery?** It dies
  with the process, but within a long session it still grows. Size, eviction and
  what the user is told when an old answer is no longer held are undecided.
- **Does serialization extend across chats, or only within one transcript?** Two
  different files have independent histories; nothing yet requires their writes
  to order against each other, but batch and branch flows touch more than one.

## Revisions

### 2026-09-17 — "in the order the reader sees them", made precise (parley#266 M1)

**Reason.** Implementing the serialization showed the phrase promises more than
serialization can deliver *across* generations: two generations write different
answers, and the one admitted first need not be the one earlier in the file —
regenerating Q3 and then Q1 writes Q3's region first. Holding the target to the
literal wording would demand reordering writes by document position, which no
one asked for and which would re-introduce interleaving.

**Delta — what the target now defends:**

- **Across generations:** one writer at a time, and each generation's writes form
  ~~**one contiguous run** — so each undo step removes exactly one generation's
  coherent contribution~~ *(overstated; corrected in the next revisions)*, never a
  mix ~~and never a partial 4 KiB slice~~. A holder keeps the write turn for its
  lifetime, including through a transient grant suspension ~~precisely so its
  run is never split around another's~~.
- **Within one generation's tool round:** document order does hold — insertion is
  monotonic at the answer's tail (parley#266 M2).
- **Human edits** are never serialized behind a generation; they may land between
  runs, and undo reflects that honestly.

`atlas/chat/ownership.md` no longer promises disjoint concurrent answer writes;
it describes the write turn. The "Why now" paragraph above records the promise
as it stood when this target was written.

### 2026-09-17 — the contiguity claim, with its exceptions (parley#266 M1 review round 2)

**Reason.** The previous revision said each generation's writes form one run
that is never split. Two exceptions make that false as stated: a **pause**
(unknown tool outcome, revoked tool output, stale input at a continuation)
yields the turn — deliberately, or a paused generation would block every other
answer until the operator acts — so its resumed writes start a new run with
another generation's between them; and native undo groups per **(generation,
grant)** run, so one answer written through its main grant and then its
completion grant is already several undo steps.

**Delta — the invariant, stated the way the code behaves:**

- **No undo step ever mixes two generations**~~, and none is a partial slice of a
  larger write. This holds unconditionally~~ *(the slice clause is conditional —
  see the next revision)*.
- A generation's writes are **contiguous for as long as it holds the turn
  uninterrupted** — a transient grant suspension does not interrupt it. A pause
  does: the resumed writes start a new run.
- ~~Undo entries are per **(generation, grant)** run.~~ *(only while nothing
  intervenes — see the next revision)*

`atlas/chat/ownership.md` says the same; `tests/integration/generation_turn_spec.lua`
pins both the uninterrupted case and the pause-then-resume case.

### 2026-09-17 — undo grouping has one statement, in the atlas (parley#266 M1 review round 3)

**Reason.** Both earlier revisions restated undo grouping here, and each
restatement dropped an exception — the second said "no partial slice …
unconditionally", which a human edit between two 4 KiB slices falsifies.
Restating a code-derived rule in prose is how it drifts, so this target stops
doing it.

**Delta.** The target defends one undo property, and it is unconditional:
**no undo step ever mixes two generations.** How writes group into undo steps —
one step per (generation, grant) run with no partial slice, *while nothing
intervenes*, and exactly which events intervene — is stated once, in
[`atlas/chat/ownership.md`](../../atlas/chat/ownership.md) ("Undo grouping"),
derived from `Editor:can_join_undo`. parley#261, which leans on these guarantees,
should cite that section, not this target's revisions.


### 2026-09-18 — tool rounds land in order; a failed call no longer pauses (parley#266 M2)

**Reason.** M2 shipped ordered `(call, result)` insertion, and the operator
decided a failed tool call should not pause: it is written as an error result so
the model can try another way.

**Delta.**

- **Delivered:** within one generation's tool round, document order holds —
  every block is appended at the answer's tail, each call immediately before its
  own result. `tests/integration/response_tools_spec.lua` pins it on real text,
  including a sweep of every interleaving of two outcomes, a stop and cleanup.
- **The pause causes listed in the round-2 revision shrink to one:** stale input
  at a continuation. An unknown tool outcome is written as an error result and
  the round goes on; "revoked tool output" no longer exists apart from the
  answer, since a round's blocks have no grants of their own — an edit inside
  them revokes the answer.
- **A gap this target now tolerates, stated so it is not mistaken for a
  guarantee:** execution precedes the record. A tool whose pair is held — behind
  an earlier call still running, or behind another generation's turn — has
  already run but is not yet in the file, and Stop drops pairs not yet written,
  like any held output. Before M2 a call block was always written before its tool
  started. The transcript still never *claims* an effect that did not happen; it
  can omit one that did, if the generation is stopped first.

### 2026-09-18 — the gap closed: Stop writes the round out (parley#266 M3)

**Reason.** Operator decision after the M2 close: the tolerated gap recorded in
the previous revision — Stop dropping `(call, result)` pairs whose tools had
already run — is not acceptable.

**Delta.** The gap is closed. A Stop during a tool round cancels every running
tool and then writes the whole round out, in declared order: a tool finished by
the time its pair is reached gets its real result, any other an error result
saying the user cancelled it (while running — it may have partly taken effect —
or before it ran). Only then does the answer end. A stopped answer behind another
keeps its place and writes when the turn arrives. So the file records every tool
call the model made in that round, and what is known of each one's outcome. The
remaining ways to lose a pair are the hard stops: a second Stop, reload, or an
edit that revokes the answer.

### 2026-09-18 — the flush's guarantees have one statement (parley#266 M3 review)

**Reason.** The previous revision restated what a Stop writes, from the machine
alone: "a tool finished by the time its pair is reached gets its real result",
and "the remaining ways to lose a pair are a second Stop, reload, or an edit".
Both were incomplete for the composed system — the producer's cancel settles a
running tool as cancelled, and several more `stop()` calls are reachable
mid-flush (an overflow, a failed write of the held text, the gap or a block).

**Delta.** Those two sentences are withdrawn. What a Stop writes for each tool,
and the complete list of what ends a flush early, are stated once, in
[`atlas/providers/tool_use.md`](../../atlas/providers/tool_use.md) "Stop during
a tool round", derived from every `stop()` reachable from `flushing`. This
target defends only the property: a Stop during a tool round leaves every call
of that round in the file with what is known of its outcome, unless one of the
listed hard stops intervenes.

### 2026-09-18 — the on-disk store is gone; no replaced answer is kept (parley#261 M1)

**Reason.** #261 M1 deleted the answer-recovery store. The operator decided
that nothing replaces it as a user-facing affordance.

**Delta.**

- The open question "What bounds the in-session memory that replaces durable
  recovery?" is answered: none is kept. Native undo is the way back to a
  replaced answer.
- The only held copy is `prev_answer`. It lives on the document coordinator for
  as long as one generation runs, and feeds request context only (parley#255,
  folded into #261 M2).
- Every remaining sidecar under the state directory now degrades instead of
  throwing, whether the file is invalid JSON or has wrongly typed fields.
  - `tests/helpers/sidecars.lua` lists them.
  - `tests/integration/sidecar_degrade_spec.lua` corrupts each one and then
    submits.
  - `tests/arch/sidecar_authority_spec.lua` fails any new reader that is not
    listed.

### 2026-09-19 — the inventory is kept up to date in the atlas; no blocker goes unexplained (parley#261 M5)

**Reason.** #261's first Done-when asks for an inventory of every state that
can block submission or hold a generation. An audit's list goes stale once
written, so the inventory now lives on a maintained atlas page. M5's tests also
found a permanent blocker: a paused batch that could never resume refused
every later batch until `:e!`.

**Delta.**

- [`atlas/chat/transcript_truth.md`](../../atlas/chat/transcript_truth.md)
  states the restart invariant: a reopen rebuilds every fact a submission
  depends on from the file. It lists each state with its bucket, what releases
  it, and the spec that pins that. Adding a state that can refuse a submission
  means adding its row there.
- The file carries no pending or error marker. An interrupted answer is partial
  text with no next `💬:` prompt. Why it stopped is said once, when it stops, in
  the words of `lua/parley/refusal.lua`, and is never stored.
  The guarantee is in the code: `refusal.describe` gates its `failure` by
  value, so a reason with no words becomes the detail beside the words of that
  refusal's kind, and every refusal still names an action. The runner gates the
  same way where it stores a failure. Two nets then find the gaps for a
  developer — `tests/arch/refusal_vocabulary_spec.lua` at authoring time, for
  the call shapes it knows, and the harness watch over what `describe` resolves
  across the suite — and neither is what makes the invariant true.
- `:e!` reaches the document as a detach followed by a fresh attach, not an
  epoch change. Everything a detach releases, a reload releases too. The host
  tells the two apart only to choose its words.
- A paused batch whose response has settled gives way to a new
  `:ParleyChatRespondAll`. Only a running batch refuses.
