---
id: 000254
status: open
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours:
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
