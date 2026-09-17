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
