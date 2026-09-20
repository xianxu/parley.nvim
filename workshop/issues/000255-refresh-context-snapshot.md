---
id: 000255
status: working
deps: [254]
github_issue:
created: 2026-09-15
updated: 2026-09-19
estimate_hours:
started: 2026-09-19T17:46:24-07:00
---

# Use previous completed answers in context during refresh

## Problem

Follow-up to #254 (chat ownership and concurrency).

Refreshing Q1 removes its previous answer from the live transcript while the
replacement streams. If the user then refreshes Q2, its current context snapshot
contains an absent or partial Q1 answer even though Q1's previous completed
answer is retained for recovery. Context quality therefore depends on timing.

## Spec

Keep the immutable, per-request context snapshot introduced in #254. While
assembling it, if an earlier exchange is being refreshed and its replacement is
incomplete, use that exchange's previous completed answer when available.

- Select the previous answer as a whole; do not combine it with replacement
  fragments. Preserve the answer's structured tool-call/result content where
  applicable, through the normal context projection and retention rules.
- Resolve the previous answer by the captured exchange identity. Never borrow an
  answer from another exchange after edits, movement, deletion or reload.
- This substitution affects request context only; it does not restore old text
  into the visible buffer or stop concurrent generation.
- Once the replacement completes, subsequently captured requests use the new
  completed answer. Requests already captured remain unchanged.
- If no valid previous completed answer is available, retain existing context
  behavior; this task does not invent an answer or require waiting for refresh.
- Continue excluding the target question's own answer during regeneration.

## Done when

- Refresh Q1, then request Q2 before Q1 emits text: Q2 receives Q1's previous
  completed answer when available.
- Repeat after Q1 has streamed partial replacement text: Q2 still receives the
  complete previous answer, without replacement fragments.
- Request Q2 after Q1 completes: it receives the new completed answer; an already
  captured Q2 request is unaffected by Q1's later completion.
- Multiple simultaneously refreshed preceding exchanges independently use their
  own available previous answers, preserving conversation order.
- Tests cover structured answers, absent/invalid previous-answer availability,
  and identity changes caused by edits/deletion/reload without cross-exchange
  substitution. Existing snapshot and context-retention behavior remains covered.

## Plan

- [x] Design how context capture resolves a valid previous completed answer from
  the exchange/recovery lifecycle without depending on transient line positions.
  → #261 M2: a `prev_answer` slot on the document coordinator, keyed by the
  exchange entity and held only while its generation owns a live grant, so no
  line position is involved.
- [x] Add deterministic concurrent-refresh context tests and implement the
  substitution at the shared request-context boundary.
  → `previous_answer.capture/substitute` (pure), applied where the request
  captures its context. Tests: `chat_respond_spec` "(#255)" cases — before the
  regeneration writes, while it streams, once it completes, when an edit revokes
  it, a request captured mid-stream left unchanged, substitution at capture
  rather than at build, and a typed raw request.
- [x] Verify all request-context consumers, update documentation and traceability,
  and complete review.
  → `document_previous_answer_spec` covers absent/invalid availability and every
  identity change (no grant, stale epoch, revoked, deleted marker, reload,
  detach) and that each exchange keeps its own slot; sub-chat ancestors read the
  parent's live buffer. Mapped in `atlas/chat/transcript_truth.md`, routed in
  `atlas/traceability.yaml`, reviewed across #261 M2's boundary rounds.

## Log

### 2026-09-15

Filed at the user's request after #254 reached codecomplete. Agreed policy:
freeze each request's context, substituting an available previous completed
answer for an earlier exchange whose refresh is still incomplete. Implementation
is follow-up work, not part of #254's current live-testing build.

### 2026-09-18 — folded into parley#261

Operator decision: this work is delivered by parley#261 (see its Revisions,
2026-09-18). #261 deletes the on-disk recovery store this plan meant to read
from. The previous answer instead lives in an in-memory `prev_answer` slot on
the document coordinator's exchange structure, from the moment regeneration
removes it until that generation ends. Ancestor context in sub-chats is
covered too. This issue's Spec and Done-when are carried into #261's Done-when,
and it closes when #261 closes.

### 2026-09-19 — delivered by parley#261 (merged)

#261 shipped this issue's substance in its M2 (PR #197, merged as 38a1d08d):
a request that captures context while an earlier exchange is being regenerated
receives that exchange's previous complete answer — in the same chat and from a
sub-chat whose ancestor chain includes it, read from the parent's live buffer —
never mixed with replacement fragments, and several exchanges regenerating at
once each use their own. Once a generation ends, later requests see what the
transcript says; a request already captured is unaffected.

The answer lives in an in-memory `prev_answer` slot on the document
coordinator, not the on-disk store this issue's original plan assumed (#261 M1
deleted that store). Pinned by `tests/integration/document_previous_answer_spec.lua`
and the `#255` cases in `tests/integration/chat_respond_spec.lua`; mapped in
`atlas/chat/transcript_truth.md`.

Nothing is left to build here. The status flip to `done` needs
`sdlc close --issue 255`, since the binary writes `codecomplete` only through a
close review (#160).
