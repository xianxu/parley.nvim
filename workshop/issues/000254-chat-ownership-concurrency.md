---
id: 000254
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 33.107
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

### Confirmed scope and structural requirements — 2026-09-14

The operator confirmed one Neovim instance: human edits to the live buffer while
background operations generate into different parts of its exchange structure.
Reloading the file invalidates current writes. The core must also support
concurrent tool calls and several disjoint background writers, even where the
current product executes them sequentially. The typical flow remains typing the
next question while an answer streams.

The detailed proposal is
`workshop/plans/000254-chat-ownership-concurrency-plan.md`. It refines earlier
exchange-wide ownership into delegated exclusive block/insertion-slot grants;
concurrent tools reserve stable results in declared call order, and each operation
has scoped cancellation. A parent cannot write over a child slot. External tool
resource conflicts are distinct from disjoint transcript writes and require
process-wide admission. Unresolved effects outlive document teardown without
retaining permission to write into a reloaded/reused buffer.

Human edits are interpreted against pre-edit ranges before semantic repair.
Partial/whole exchange deletion can leave unresolved fragments; preserve those
bytes and revoke affected grants rather than infer the user's intent. Identity
reconciliation must not transfer authority by ordinal, matching text, or undo.
Native edits are observed rather than prevented by a supposed region-level lock.

Rendering derives from one incremental index. Ordinary word/newline edits must
avoid document-size arrays, anchor scans, and fold rebuilding; redraw consumes
only bounded visible/context bytes. Repair tracks forward and backward grammar
dependencies and can yield while affected regions remain conservatively styled.
Unrelated concurrent streams must not starve repair. Broad native fold clearing
has an explicitly measured affected-range cost, separate from the ordinary-edit
guarantee. The plan records operating limits, recovery policy, and six proposed
review boundaries for approval before implementation.

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

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.*

Derived after plan-quality accepted PQ-1. The calibration is marked stale by
`sdlc estimate-source`, so these are provisional focused ship-hours, not a promise.
The decomposition below counts independent focused features/integration concerns,
plus six atlas updates and seven actual review boundaries; it does not assign a
single feature primitive to the whole refactor.

The accepted detailed plan applies the v2.1 design discount of 0.2 and design
buffer of 0.15. Each block impl value is the selected v2 value times v3.1's 0.40,
applied once. Familiarity is 1.5: Lua/Neovim is established here, but the combined
incremental dependency/ownership model is novel and bounded by the approved design.

Library check: reuse the existing classifier, fence/reducer, presentation,
LineReader, libuv, parser and fold seams. No new runtime is required. A current
dependency does not supply the provenance-aware incremental sequence/coordinator;
those concerns keep their full primitive base design before the spec discount.
No speculative library design halving or cross-repo overhead is applied.

| Item order / concern | Primitive | v2 design | v2 impl |
|---|---|---:|---:|
| 1. M1 attempt model | lua-neovim | 2 | 1 |
| 2. M1 response containment | lua-neovim | 1 | 1 |
| 3. M1 process supervision | api-integration | 2 | 1.5 |
| 4. M2 indexed sequence | lua-neovim | 3 | 1.5 |
| 5. M2 shared grammar | lua-neovim | 3 | 1.5 |
| 6. M2 incremental repair | lua-neovim | 3 | 1.5 |
| 7. M3 document state | lua-neovim | 2 | 1.5 |
| 8. M3 editor adapter | lua-neovim | 2 | 1.5 |
| 9. M3 highlighting migration | lua-neovim | 2 | 1 |
| 10. M3 fold migration | lua-neovim | 3 | 1.5 |
| 11. M3 structural consumer sweep | cross-cutting-refactor | 1 | 0.5 |
| 12. M4 generation reducer | lua-neovim | 2 | 1 |
| 13. M4 runner integration | api-integration | 2 | 1.5 |
| 14. M4 child-slot projection | lua-neovim | 2 | 1 |
| 15. M4 undo isolation | lua-neovim | 2 | 1 |
| 16. M4 mutation consumer sweep | cross-cutting-refactor | 1 | 0.5 |
| 17. M5 batch reducer | lua-neovim | 2 | 1 |
| 18. M5 recovery store | api-integration | 2 | 1.5 |
| 19. M5 recovery UI | lua-neovim | 1 | 0.5 |
| 20. M6 operation ledger | lua-neovim | 2 | 1 |
| 21. M6 resource admission | lua-neovim | 2 | 1.5 |
| 22. M6 asynchronous scheduler | api-integration | 2 | 1.5 |
| 23. M6 checked filesystem | api-integration | 2 | 1.5 |
| 24. M6 command-tool migration | api-integration | 2 | 1.5 |
| 25. M6 filesystem-tool migration | api-integration | 2 | 1.5 |
| 26. M6 editor-tool migration | lua-neovim | 1 | 0.5 |
| 27. M6 wire projection | cross-cutting-refactor | 0.6 | 0.5 |
| 28. M1 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 29. M2 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 30. M3 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 31. M4 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 32. M5 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 33. M6 atlas/traceability | atlas-docs | 0.1 | 0.1 |
| 34. M1 boundary review | milestone-review | 0.1 | 0.4 |
| 35. M2 boundary review | milestone-review | 0.1 | 0.4 |
| 36. M3 boundary review | milestone-review | 0.1 | 0.4 |
| 37. M4 boundary review | milestone-review | 0.1 | 0.4 |
| 38. M5 boundary review | milestone-review | 0.1 | 0.4 |
| 39. M6 boundary review | milestone-review | 0.1 | 0.4 |
| 40. issue-close boundary review | milestone-review | 0.1 | 0.4 |

```estimate
model: estimate-logic-v3.1
familiarity: 1.5
item: lua-neovim design=0.400 impl=0.400
item: lua-neovim design=0.200 impl=0.400
item: api-integration design=0.400 impl=0.600
item: lua-neovim design=0.600 impl=0.600
item: lua-neovim design=0.600 impl=0.600
item: lua-neovim design=0.600 impl=0.600
item: lua-neovim design=0.400 impl=0.600
item: lua-neovim design=0.400 impl=0.600
item: lua-neovim design=0.400 impl=0.400
item: lua-neovim design=0.600 impl=0.600
item: cross-cutting-refactor design=0.200 impl=0.200
item: lua-neovim design=0.400 impl=0.400
item: api-integration design=0.400 impl=0.600
item: lua-neovim design=0.400 impl=0.400
item: lua-neovim design=0.400 impl=0.400
item: cross-cutting-refactor design=0.200 impl=0.200
item: lua-neovim design=0.400 impl=0.400
item: api-integration design=0.400 impl=0.600
item: lua-neovim design=0.200 impl=0.200
item: lua-neovim design=0.400 impl=0.400
item: lua-neovim design=0.400 impl=0.600
item: api-integration design=0.400 impl=0.600
item: api-integration design=0.400 impl=0.600
item: api-integration design=0.400 impl=0.600
item: api-integration design=0.400 impl=0.600
item: lua-neovim design=0.200 impl=0.200
item: cross-cutting-refactor design=0.120 impl=0.200
item: atlas-docs design=0.020 impl=0.040
item: atlas-docs design=0.020 impl=0.040
item: atlas-docs design=0.020 impl=0.040
item: atlas-docs design=0.020 impl=0.040
item: atlas-docs design=0.020 impl=0.040
item: atlas-docs design=0.020 impl=0.040
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
item: milestone-review design=0.020 impl=0.160
design-buffer: 0.15
total: 33.107
```

Design subtotal 10.580; buffered design 12.167. Already-scaled
implementation subtotal 13.960; familiarity-adjusted implementation 20.940.
Total = 33.107 focused ship-hours.

## Plan

The durable plan specifies these implementation review boundaries; each requires
its own `sdlc milestone-close` after implementation:

- [ ] M1 — Durable audit regressions and process-lifecycle containment.
- [ ] M2 — Dependency-aware incremental sequence/grammar/structure core.
- [ ] M3 — Document ownership and shared highlighting/folding/layout index.
- [ ] M4 — Scoped concurrent generation/child-slot writes and human editing.
- [ ] M5 — Fixed batch identities and recoverable answer replacement.
- [ ] M6 — Asynchronous concurrent tools, resource/outcome enforcement, final verification.

### Earlier exploration checklist (superseded for execution)

- Earlier proposal: At implementation start, claim and enter planning; reconcile current code and
  editing restriction, then author a reviewed durable plan with real review boundaries.
- Earlier proposal: Promote audit reproductions to durable regression tests and correct lifecycle
  failures without first broadening editing concurrency.
- Earlier proposal: Enforce exchange identity, regional revisions, scoped generation writes, and
  ownership from the first asynchronous boundary while the editing guard remains.
- Earlier proposal: Enable typing ahead once preservation and event-order tests pass; then cover
  active-answer edits, boundary changes, undo, and document closure explicitly.
- Earlier proposal: Replace recursive batch orchestration with explicit selection/progress and
  revision-conflict policy using the same single-generation operation.
- Earlier proposal: Complete process/tool uncertainty and capability enforcement, sequence testing,
  atlas updates, and verification through SDLC review gates before closing the issue.

## Log

### 2026-09-14 — Claimed; structural design in progress

Claimed with `sdlc claim --issue 254`, then entered `sdlc start-plan`. The operator
authorized substantial design and planning before implementation. Current design
work is recorded in `workshop/plans/000254-chat-ownership-concurrency-plan.md`.
No implementation is authorized until the durable plan is reviewed and approved.

The discussion established a buffer-authoritative document coordinator: interpret
human changes against the previous structure, revoke overlapping write grants
immediately, then reconcile semantic identities without forcing malformed text
into valid exchanges. Rendering must consume an incremental index, never trigger
a whole-document parse on redraw. Ordinary edits must not copy document-sized
arrays or resolve every exchange anchor. Structural repair must account for
backward dependencies (reasoning terminators and closed-fence lookahead), not only
forward parser-state convergence (ARCH-ORDER, ARCH-CONSTRAINTS, ARCH-DRY).

Read-only audits cover structure/rendering and generation/process/tool lifetimes.
The repository currently has command-specific pending guards and `stopinsert` on
submission, but no generic chat typing lock was found; the reported deployed
restriction remains an operator/environment observation, not a core invariant.
The planning assumption is one Neovim process with human and asynchronous writers;
external reload revokes ownership. Cross-process concurrent saving is a distinct
persistence protocol; scope clarification was requested.

### 2026-09-14

Captured the read-only chat audit and operator discussion. Core insight: exchange
identity is distinct from current location; safe concurrent editing additionally
requires revision tracking and scoped write authority. Existing response-progress
and provider-architecture suites passed during the audit while the added probes
exposed missing sequence invariants. No implementation changes made. Issue remains
open for future hardening; the proposed steps are not a costed implementation plan.

### 2026-09-14 — Design review completed

The operator confirmed one Neovim instance and clarified concurrent tool/background
writers as a core requirement. Completed structure/rendering and lifecycle audits,
then wrote the six-milestone durable plan. Fresh-context review approved both plan
chunks after fixes for detached-document effect ownership, restart recovery
association, paused/stopping/queued lifecycle cases, and executable milestone
sequencing. Concurrent tool effects are delivered at M6; M4 proves the production
coordinator's disjoint generation/child-slot contract.

A synthetic Neovim 0.11.7 attached-TUI probe established native visual-range `zD`
removes intersecting folds and preserves disjoint closed folds. Exploratory samples
at 50,000 rows: about 0.63 ms for broad clearing of roughly 1,000 folds; indexed
removal of roughly 256 folds took about 1.43 ms. These are individual samples, not
p95 guarantees. Native broad-range cost scales with affected span; the plan states
that exception and an overload policy rather than claiming constant work.
Recreate these probes as repository conformance tests during M3; scratch paths are
`/tmp/parley254-fold-direct.lua` and `/tmp/parley254-fold-indexed-ui.lua`.

Validation: `sdlc issue validate --issue 254` passed; existing lifecycle, parsing,
exchange-model, and highlight test mappings all resolve actual specs. No production
code or tests changed. Operator plan approval remains pending; estimates wait for
the plan-quality gate. Plan/review lessons are locally committed, not published.

### 2026-09-14 — Operator approved implementation plan

The operator approved the reviewed design and said to proceed, asking for plan
review next. Run the SDLC plan-quality gate, derive/reconcile the estimate only
after acceptance, then enter implementation. No additional plan-approval request
is required for the approved scope.

### 2026-09-14 — Plan gate passed; M1 implementation checkpoint

The SDLC plan-quality round 2 returned CLEAN after replacing repeated case lists
with named-function adversarial verification strategies (PQ-1). The estimate gate
accepted 33.107 focused ship-hours with advisory calibration/allocation notes.
`change-code --issue 254 --agent codex --worktree=yes` entered implementation at
`/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency`
on branch `000254-chat-ownership-concurrency`. Operator approval remains valid.

M1 work in progress: private transport attempt reducer; owner-specific cancellation;
exit plus both-stream drain admission; rejected query preparation retirement;
completion preservation of typed-ahead questions and unmarked text. New production-
path ownership specs use a stateful process fake. Tests first reproduced the three
response bugs and pre-launch query leak, then passed after containment fixes.
Transport agent reports 134 focused tests passing; instrumentation agent reports
46 focused tests passing, both with scoped luacheck clean. Root dispatcher ownership
spec passed 2/2. Mapped lifecycle (530 tests) and exchange-model (281 tests) suites passed with
zero failures/errors; automatic M1 review remains outstanding;
no milestone is closed and concurrent document/tool scheduling is not implemented.

Schema-2 performance report `/tmp/parley-254-m1-perf.json` passes. Darwin/Neovim
0.11.7 baseline at 5,000 rows: newline insert/join copies 20,002 structure slots,
reads 3 lines and processes 6 rows; decoration reads 61 lines, neither makes a
full-buffer read. New byte counts are 78 for splice and 2,379 for decoration.
Baseline timing before implementation: decoration p95 0.354208 ms, structure
splice p95 0.291542 ms, full rebuild p95 7.262084 ms. Timing is report-only.
New counters cover bytes, index/dependency visits, anchors, outer fold groups,
and native fold operations. Anchor/fold unit cases exercise actual producers;
typing scenarios have zero anchor/fold work. Representative concurrent-stream and
fold-maintenance baseline scenarios still need checking against the M1 checklist.

Resume next: run `sdlc state` in the implementation worktree, read mapped lifecycle and exchange evidence in `/tmp/parley-254-m1-lifecycle.log`
and `/tmp/parley-254-m1-exchange.log`, finish baseline coverage and root
integration review, then commit
and use the single automatic `sdlc milestone-close --issue 254 --milestone M1`
review. Continue M2–M6 from the approved durable plan. Keep unrelated main-checkout
changes untouched. M1 intentionally retains unresolved attempts without timers;
global bounded admission/reconciliation scheduling remains later milestone work.

## Revisions

### 2026-09-14 — Incremental rendering is part of the core contract

Reason: the operator requires fast highlighting/colorization/folding while arbitrary
human edits can span and partially destroy exchanges. Delta: add incremental
structural reconciliation, explicit uncertain regions, bounded scheduled repair,
and rendering work-count acceptance to the detailed design. Preserve the original
audit and proposed policies below; the durable plan will specify refinements and
actual review boundaries before implementation.

### 2026-09-14 — Fine-grained ownership and exchange deletion

Follow-up discussion clarified that users seldom edit active answers: restrict the
streaming answer region initially while supporting typing ahead. Added the
write-conflict/input-dependency distinction and the whole-exchange deletion
contract. Recorded the gap between current anchor validation/positional indexing
and authoritative identity resolution, with deletion/undo/batch acceptance cases.
These additions refine the proposed design; no implementation was changed.

### 2026-09-14 — Multi-operation scope and review closure

Reason: the operator requires concurrent background/tool writers as well as human
typing. Delta: added confirmed scope and six concrete milestone rows; converted
the superseded exploration checklist to prose so it cannot act as duplicate
completion gates. Reviewed design now separates document lifetime from outstanding
effects, specifies safe recovery association, and explicitly bounds normal
rendering work while acknowledging broad native fold-clearing costs.
