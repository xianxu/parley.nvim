---
type: target
slug: transcript-is-the-whole-truth
status: active
created: 2026-09-17
updated: 2026-09-17
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

