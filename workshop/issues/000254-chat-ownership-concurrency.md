---
id: 000254
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours:
started: 2026-09-14T22:05:59-07:00
---

# Harden chat ownership and concurrency

## Problem

Chat response presentation has a useful pure state machine, but document mutation,
request ownership, transport lifetime, and tool outcomes do not form an enforced
end-to-end lifecycle. The September 14 audit reproduced destructive completion
cleanup, cross-chat cancellation, and retirement of unresolved process ownership.

The operator's experience explains the progression: directly computing buffer
locations was fragile; introducing exchanges improved the abstraction, but did not
make concurrent edits robust. The operator reports disabling buffer editing while
generation runs as the current workaround. Verify the exact deployed restriction
at implementation start; the audit's injected edits establish unsafe interleavings,
not that normal typing currently bypasses that restriction.

The central distinction is **identity versus location**. An exchange keeps its
identity when edits move its lines. An identity alone still does not establish
which revision a response consumed or what text it may overwrite.

## Spec

Harden the existing exchange abstraction incrementally. Keep the editing guard
until scoped ownership is enforced and production-path sequence tests demonstrate
safe typing ahead. This issue captures the agreed direction and proposed policies;
the detailed implementation plan and review boundaries remain to be designed.

### Vocabulary and ownership

| Term | Contract |
| --- | --- |
| Exchange identity | Stable logical question/answer identity, independent of current row coordinates. |
| Location | A current mapping from identity to buffer region; never durable authority for a callback. |
| Content revision | Version of the relevant question, context, or answer region; unrelated typing does not invalidate every region. |
| Generation | One answer-producing run, including preparation, provider/tool rounds, and completion; captures its input snapshot and owns a specific output region. |
| Transport attempt | One external request/process attempt, with its own identity and observed termination evidence. |
| Write grant | Revocable permission for one generation to mutate one answer region. |
| Batch | Fixed ordered exchange selection whose generations execute sequentially. |

ARCH-ORDER / ARCH-PURE: pure components enumerate lifecycle states, events,
transitions, and effects. The IO shell reports human edits, transport events, and
effect outcomes. Authoritative ownership is private and changes only through these
transitions. Reuse the existing presentation reducer, leases, exchange model, and
buffer-edit door where they fit (ARCH-DRY); do not introduce a competing full-buffer
source of truth.

All generated edits pass through one document coordinator using exchange and
generation identity. It validates current regional ownership immediately before
applying a patch. Human edits arrive through Neovim and must be reconciled before
another generated patch; humans cannot be assumed to use our mutation API.
No asynchronous callback retains naked row ranges as write authority.

### Fine-grained editing scope

The operator notes that editing inside an active answer is uncommon. The initial
concurrency policy can therefore keep only the streaming answer region temporarily
read-only while questions and other exchanges remain editable. Fine-grained
ownership makes the restriction match the actual write conflict; enabling typing
ahead does not require merging simultaneous edits inside the answer. If a mutation
does reach that region (including external edits or undo), the revocation rule
below still applies.

Distinguish write conflicts from input dependencies. Typing a subsequent question
does not affect the current generation's inputs or output region. Editing earlier
context does not overlap its output region either, but changes what that answer is
based on. Handle this with immutable input snapshots and an explicit staleness
policy, rather than expanding the write lock to all context.

### Whole-exchange deletion and identity resolution

Deleting a whole exchange is a valid document operation, including while its
answer streams. A regional editing restriction must permit an explicit exchange
deletion to revoke the write grant and remove the exchange coherently. Subsequent
callbacks must resolve to absent/revoked, never old coordinates or a replacement
exchange at the same ordinal:

```text
resolve(exchange_id, generation_id)
  -> current authorized answer region
  -> absent / revoked
```

Resolution and mutation must occur without an intervening unvalidated document
change. Never fall back to remembered rows or recreate the deleted exchange from
late output. Request cancellation only for the deleted exchange's generation;
retain transport ownership until its outcome is resolved. Undo may restore visible
text but must not restore a retired generation's authority.

The current implementation enforces only part of this contract:

- `chat_lease.lua` anchors the answer header with an invalidating extmark and checks
  generation identity. Deleting the header invalidates guarded callbacks. This is
  useful deletion detection, not a complete exchange identity/location resolver.
- `chat_respond.lua` handles invalidation by globally stopping tasker processes;
  the isolated audit reproduced cancellation reaching another chat.
- Response code still uses `target_idx` and model-computed block positions. Batch
  refresh reparses and advances `current_idx + 1`; deletion can change which exchange
  occupies that ordinal. Computing positions through an exchange abstraction does
  not itself establish that the abstraction reflects current human edits.

Capture batch membership by stable identity. If a selected exchange disappears,
pause with an explicit missing-target outcome under the proposed conflict policy;
do not substitute the exchange now occupying its former position. Deleting an
unrelated exchange may move locations without changing selected identities. The
batch ordinal risk is established from code; no additional batch-deletion behavior
was reproduced during this discussion.

### Proposed editing and refresh policies

- Typing the next question and unrelated edits outside the active answer are safe;
  they move locations without revoking the generation's write grant.
- Editing the active answer revokes automatic writing before more output applies;
  preserve the human edit and request cancellation of only that generation.
- Deleting the exchange or ambiguously restructuring its boundaries revokes the
  grant. Undo cannot resurrect a retired generation's write permission.
- Editing context used by an active generation does not silently change its input:
  retain the snapshot and expose that the answer is based on an older revision.
- A single-exchange submission and refresh-through-cursor share the same generation
  operation. Capture a batch's selected exchange identities and question revisions
  once; cursor motion or newly appended exchanges cannot change membership.
- Regenerate sequentially, feeding successful refreshed answers into subsequent
  context. Validate selected question revisions before starting each step; changes
  pause the batch rather than silently mixing versions. Context invalidation must
  also be checked, including edits to previously refreshed answers.
- On failure/cancellation retain completed answers and known partial progress;
  do not launch later steps. A batch is not an atomic transaction, especially when
  tools have already acted. Preserve the previous answer until replacement succeeds,
  or retain an explicitly recoverable previous revision while showing partial output.

### Lifecycle and effect hardening

Acquire response ownership before asynchronous reference preparation. Separate
write-grant revocation from requested cancellation and confirmed transport stop.
Unknown probe/stop outcomes retain unresolved ownership and a bounded reconciliation
policy. Active operation records cannot be evicted by history-retention limits.

Tool execution must enforce the request's selected capabilities, preserve call
identity and honest effect outcomes, check backup/write/close results, and report
post-effect result-processing failures without implying the effect did not happen.
Define retry behavior for possibly completed effects; correlation IDs alone do not
establish at-most-once execution. This does not require a general distributed
transaction system or collaborative-editor framework.

### Audit evidence to promote into durable regression tests

- `chat_respond.lua` completion cleanup used a submission-time exchange list and
  deleted an independently appended question. Production response code with an
  isolated real Neovim buffer reproduced the loss.
- Lease invalidation called global `tasker.stop()`: a late callback from A stopped
  synthetic handles for both A and B. Test used a recording kill fake, no signals.
- `tasker.lua`: injected EPERM became not-busy and dropped ownership; a failed stop
  also dropped ownership; age/count cleanup evicted an unfinished query.
- `tools/builtin/write_file.lua` and equivalent edit paths ignore write/close
  outcomes; injected disk-full failures still reported success. Result processing
  in `tools/dispatcher.lua` can throw after a handler has performed its effect.
- Selected tools are advertised but the execution path uses the global registry;
  an unexpected unadvertised tool response is not rejected by request authority.
  This is a code-established gap, not a live-provider reproduction.

Temporary audit artifacts: `/tmp/parley-chat-audit/audit_spec.lua` and `repro.log`,
and `/tmp/parley-fsm-audit/probe.lua`. These are convenience artifacts, not durable
dependencies: recreate the documented cases as repository tests before changing
implementation. The chat findings predated concurrent #240 changes.

## Done when

- Typing ahead survives streaming, completion, failure, and cancellation without
  losing human text or unnecessarily interrupting the active generation.
- Late/duplicate events cannot mutate another generation or stop another chat;
  edits, deletion, undo, and buffer closure invalidate authority deterministically.
- Production mutation and cancellation paths enforce scoped ownership; architecture
  checks reject bypasses and authoritative state is not externally mutable.
- Single and batch submission share one response lifecycle; selected identities,
  revision conflicts, partial progress, and replacement recovery are tested.
- Whole-exchange deletion during streaming, before completion, and between batch
  steps cannot redirect writes, recreate deleted content, skip to a different
  identity, or cancel unrelated work. Moving an exchange preserves identity;
  deleting then undoing it does not reauthorize stale callbacks.
- Unknown process/effect outcomes remain explicit; active work cannot disappear
  through retention cleanup; tool writes cannot claim unconfirmed success.
- Deterministic sequence tests cover interleaved human edits, chunks, completion,
  retries, tools, batch advancement, stop failures, and stale observations. They
  assert independent preservation/ownership invariants after every transition.
- Atlas documents vocabulary, owner boundaries, transitions, and operating limits;
  tests use stateful editor/transport/filesystem doubles through production seams
  plus isolated Neovim integration tests (ARCH-MOCK). No production sessions needed.

## Plan

- [ ] At implementation start, claim and enter planning; reconcile current code and
  editing restriction, then author a reviewed durable plan with real review boundaries.
- [ ] Promote audit reproductions to durable regression tests and correct lifecycle
  failures without first broadening editing concurrency.
- [ ] Enforce exchange identity, regional revisions, scoped generation writes, and
  ownership from the first asynchronous boundary while the editing guard remains.
- [ ] Enable typing ahead once preservation and event-order tests pass; then cover
  active-answer edits, boundary changes, undo, and document closure explicitly.
- [ ] Replace recursive batch orchestration with explicit selection/progress and
  revision-conflict policy using the same single-generation operation.
- [ ] Complete process/tool uncertainty and capability enforcement, sequence testing,
  atlas updates, and verification through SDLC review gates before closing the issue.

## Log

### 2026-09-14

Captured the read-only chat audit and operator discussion. Core insight: exchange
identity is distinct from current location; safe concurrent editing additionally
requires revision tracking and scoped write authority. Existing response-progress
and provider-architecture suites passed during the audit while the added probes
exposed missing sequence invariants. No implementation changes made. Issue remains
open for future hardening; the proposed steps are not a costed implementation plan.

## Revisions

### 2026-09-14 — Fine-grained ownership and exchange deletion

Follow-up discussion clarified that users seldom edit active answers: restrict the
streaming answer region initially while supporting typing ahead. Added the
write-conflict/input-dependency distinction and the whole-exchange deletion
contract. Recorded the gap between current anchor validation/positional indexing
and authoritative identity resolution, with deletion/undo/batch acceptance cases.
These additions refine the proposed design; no implementation was changed.
