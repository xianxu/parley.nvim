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

- [x] M1 — Durable audit regressions and process-lifecycle containment.
- [x] M2 — Dependency-aware incremental sequence/grammar/structure core.
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
- 2026-09-14: closed M1 — BR-1 topic/header/buffer cancellation, delayed scratch cleanup and retry ownership covered; lifecycle 536 and response-progress 345 pass, exchange-model 281 previously passed; focused ownership 5 plus dispatcher3 pass; scoped lint/diff clean; baseline perf passed. BR-2 explicitly assigned M6. Actual N/A: worktree transcript attribution unavailable/inconsistent; no estimated actual supplied.; review verdict: SHIP

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

### 2026-09-14 — Continue autonomously through final live-test handoff

The operator explicitly authorized continuing without waiting between milestones.
Complete #254 implementation and automated review/verification, then hand over the
branch for extensive operator live testing before merging to main. Do not merge
until that live-testing approval arrives. Normal local milestone reviews and
fixes remain authorized. Context checkpoints preserve progress and do not require
another operator message to resume.

### 2026-09-14 — M1 verification and scaling baseline complete

Mapped lifecycle: 530 tests; exchange-model: 281; response-progress: 345, all zero
failures/errors. The broader progress suite exposed an obsolete busy-predicate
stub; replaced it with an actual competing private admission through the process
fake and verified launch rejection clears pending presentation. New ownership
performance specs plus existing typing specs: 17 pass; scoped lint clean.

`make perf TEST_ENV_ROOT=/tmp/parley-254-metrics-env
PERF_OUTPUT=/tmp/parley-254-m1-ownership-perf.json` passes, Darwin/Neovim 0.11.7,
20 measured samples per phase/size. At 100/1000/5000 rows, fold maintenance resolves
12/125/625 anchors (p95 0.355/1.567/4.662 ms); stream plus actual typed-ahead keyboard
input resolves 24/250/1250 anchors and copies 1068/10068/50068 entries (p95
8.042/7.210/15.768 ms). Each phase visits one outer fold and issues five native
fold operations. Inclusive stream samples also capture scheduled convergence:
the 1000-row maximum includes five full reads, 5080 requested lines, and 3027
processed rows. These are baseline costs to eliminate, not boundedness claims.
Ordinary Enter/join remains 402/4002/20002 copied slots. Fixtures preserve human
text and exercise actual fold maintenance/response handlers with controlled
provider delivery; concurrent builtin tools remain M6 scope.

M1 implementation and required baseline coverage are ready for the automatic
milestone review. No M2 implementation edits have begun; read-only API preparation
covered balanced sequence spans, resumable lexical facts, and local provenance.

### 2026-09-14 — M1 review round 1 and fixes

Automatic review returned REWORK: BR-1 found automatic topic requests escaped the
response cancellation owner; BR-2 required an explicit milestone for deferred
reconciliation. Reproduced BR-1 with a production response plus stateful process
fixture: answer completion starts topic request; deleting the answer produced no
signal. Propagated owner/admission through `generate_topic` to dispatcher, including
its retry closure. Moved parent lease validation before spinner target lookup and
buffer validity so missing/nonanimated topic text cannot skip lifetime checks.
Header-deletion and buffer-deletion topic regressions now pass, preserve unrelated
work, and retain signaled attempts until exit/drain. Added actual dispatcher retry
ownership coverage. Enumerated launches: response provider and automatic topic
carry response ownership; recursive tool responses validate then acquire their own
lease; standalone manual topic is independent. Deferred prelaunch generation
ownership remains the explicit M4 task.

BR-2 is assigned explicitly to M6 in the durable plan: capped five-second process
reconciliation, visible unresolved status, retained admissions/resource claims,
validated global/document/generation caps, timer cleanup and deterministic tests.
Timing attribution for M1 was unavailable/inconsistent across worktree and main
sources, so the gate uses only `--no-actual`, records N/A, and preserves all other
gates. No hand-estimated actual was supplied. Re-run automatic M1 review after
mapped verification of these fixes; no future milestone implementation has started.

Read-only editor conformance probe for M3 found whole-buffer deletion emits zero
inserted bytes while Neovim retains one empty line. Normalize this empty-buffer
case against observed line count/offsets in the adapter and add a durable test;
other UTF-8/multiline byte events reconstructed the actual buffer in the probe.

### 2026-09-14 — M1 round-2 verification

Affected mappings pass after topic ownership fixes: lifecycle 536 tests and
response-progress 345 tests, zero failures/errors. Focused ownership 5/5 and
dispatcher ownership 3/3 pass. Topic tests also verify scratch buffers survive
signaling but disappear after confirmed process completion, while unrelated work
remains active. Scoped luacheck and whitespace checks pass. BR-1 and BR-2 fixes
are ready for the required repeated review after REWORK.

### 2026-09-15 — M1 closed; M2 integration checkpoint
- 2026-09-15: closed M2 — Document 131 and parsing 239 tests pass; scoped lint and diff clean. BR-3 delayed semantic publication and BR-4 56 fenced tool/section differential cases fixed. Existing 50k Enter+join 3 semantic rows, 358 index visits, 175 leaf copies and JIT retention regression pass. Actual attribution unavailable for this worktree as recorded at M1; no guessed actuals.; review verdict: SHIP

M1 passed the repeated boundary review with SHIP, committed at dc715634.
M2 work continues in /tmp/parley254-m2-stage (detached staging from 2ab8f40e),
with sequence, grammar, dependencies, facts, and structure modules under
lua/parley/document/. Sequence has 15 passing focused tests, grammar 13,
dependencies 7, preliminary local publication 6. These are component results,
not a completed M2 claim. The structural repair driver and integration remain.
The operator authorized uninterrupted implementation through #254 completion;
main merge remains deferred until their extensive live testing.

Compatibility evidence requires separate document and answer-scoped semantic
transitions sharing lexical facts: a fence closed beyond an answer can suppress
a global tool marker while the answer reducer recognizes a tool section.
Dependency interval navigation performs O(log² N) total index navigation because
stable handle rank lookup is logarithmic; measured 50k-entry queries inspected
16 dependency nodes and 158 sequence nodes, with no suffix sweep. This refines
the original complexity shorthand while preserving bounded hot-path work.

### 2026-09-15 — M2 assembled core verification

The staged core is integrated into the feature worktree. The document mapping
passed 94 tests; existing parsing passed 239 and highlighting 108. The newest
syntax-certificate and disjoint-section-progress additions are receiving a final
mapped rerun. Root integration covers opaque bootstrap, partial exchange deletion,
legacy malformed-fence parity, 100 seeded range edits, and zero-row semantic
repair after a classified body-only edit. Scoped lint is clean. Live consumers
remain scheduled for M3; M2 is not yet closed.

### 2026-09-15 — Durable M2 checkpoint and newline follow-up

Committed the verified assembled core at 9f1ca367: document mapping 96 tests,
parsing 239, highlights 108, exchange model 281, all passing. Schema 3 exposes
index-entry visits and nested metadata/summary copies. M2 remains open while the
newline audit's selective fact proofs and bounded fragment convergence are
implemented in /tmp/parley254-m2-stage. Sequence, facts/dependencies, and semantic
workers have separate file owners; root composes and verifies integration.
A bounded production line-reader chunk seam also passes real-Neovim tests for
100KB UTF-8 lines, the final empty row, and rejected unbounded requests.

### 2026-09-15 — M2 ready for boundary review

Completed selective fact channels, compound footer triggers, bounded Enter/join
transfer, and viewport certainty queries. Document mapping: 127 passed, zero
failures/errors. Parsing 239, highlights 108, exchange model 281 remain green;
scoped lint/diff checks pass. Hot-JIT deletion regression reduces retained memory
from roughly 90 MB to 2.2–2.4 MB without disabling/flushing JIT. The 50k Enter+join
benchmark processes three semantic rows with 358 index visits, two dependency
visits, and 175 leaf copies; median 3.020 ms across three measured samples.
The pure core is ready for mandatory review; live authority/rendering migration
remains M3, with the end-of-issue operator live-test handoff unchanged.


### 2026-09-15 — M2 review correction and M3 staging checkpoint

M2 boundary review returned REWORK (BR-3: a text-only publication certificate
could overwrite confirmed semantics after context changed; BR-4: fenced tool
markers failed to terminate reasoning under the legacy section grammar). M2
remains open. Fix publication authority and grammar parity with regressions,
then repeat the gate. M3 preparation is isolated at `/tmp/parley254-m3-stage`
(base `48c9d6c4`): editor adapter/fake (9 tests), pure grant state (14 tests),
and shared projection summaries/queries in progress. No live consumer migration
has landed. The operator authorized autonomous completion through #254, with
extensive operator live testing before any merge to main.

### 2026-09-15 — M2 review fixes verified

BR-3/BR-4 regressions and class sweep pass. Document mapping: 131 passed,
zero failures/errors; parsing mapping: 239 passed, zero failures/errors.
Scoped lint and diff checks pass. Lexical publication can no longer install
semantic state, and fenced tool markers retain the legacy boundary behavior.
Repeat M2 boundary review on the correction commit.

### 2026-09-15 — M3 tested foundation checkpoint

Shared editor/coordinator/state/projection and live highlighter/native fold path
checkpointed from isolated staging. Targeted evidence: state14, coordinator13,
editor14, projection6, structure22, sequence32; highlighter visual/typing/shared
renderer/fence/unit suites51; fold adapter5 and attached-UI native probes3 pass.
Outline, undo hardening and performance migration remain staged agent tasks.
Legacy layout/anchor consumers and old fold regression harness migration remain
before the M3 boundary; no M3 completion claim. M2 closed SHIP at `2afd7de9`.

### 2026-09-15 — M3 integration findings and remaining work

Checkpoint `d88ad5de` passes the expanded document mapping (192 tests). Staging
adds native logical detach, whole-row endpoint identity preservation, mandatory
write-plan revisions (state15/coordinator15 tests), scoped undo18, bounded outline
12+15+54 tests, and migrated fold/identity/UI coverage. Header manual-fold repair
passes15 fold regressions. Pending: bounded diagnostics discovered in the live
consumer audit, tall/long-line viewport progress, final attached performance
report, broad mapped suites, atlas update and mandatory M3 review. Writer-model
retirement/per-chunk answer reduction move explicitly with M4 scoped-write routing;
no claim of completed generation concurrency before that milestone.

### 2026-09-15 — M3 integrated rendering and write-plan checkpoint

Integrated shared viewport paging, certified native folds, outline candidates,
bounded diagnostic parsing/publication, logical editor detach, grouped-undo
normalization, and revision-checked multi-patch writes. Deleted the exchange-anchor
array and migrated identity tests to document handles. Adversarial write plans
pass10 cases including independent seeded text oracles, delegated slots, nested
human edits, stale replay, and mutate-then-error receipts (ARCH-ORDER).

Integrated document mapping passes217 tests; highlights mapping passes84; changed
Lua lint is clean across46 files. Response mapping exposed a timing-dependent
stream observer test during initial index hydration; it now uses controlled
pending scheduling, explicit hydration, and separate native writer deliveries
(the rerun is in progress). Full mapped lifecycle/exchange and final performance
report remain pending, as does mandatory M3 review. No M3 completion claim.

Large-chat bootstrap exposed over-reserved dependency rank work: a5000-row index
could return a budget refusal forever under the default budget. Actual bounded
rank admission now progresses with a512-visit dependency cap; an adaptive retry
budget regression is being added separately. Standalone5000-row ownership sample
passes: native fold maintenance1.48ms with0native operations; stream+human32.14ms,
2deliveries, typed-ahead text preserved, and0whole-buffer reads. Timings are
report-only. The full report still must verify preceding-phase interactions.

Performance report schema4 counts bounded diagnostic bytes/matches and native
publication entries/message bytes separately. Atlas now names document authority
and clearly retains legacy generation-only model/reducer retirement in M4. The
operator's end-of-issue live testing and no-merge-before-approval instruction
remain in force.

### 2026-09-15 — M3 deferred-work corrections

Native timer regressions failed before fair scheduling and now pass for document
repair, diagnostics, and outline pagination. All four consumers, including folds,
use the shared coalesced deferred-work owner; reload/cancel closes timers and
retired callbacks cannot restart work. Native Backspace requires deferred text
validation: its callback can still expose the old split rows. The single-result-row
optimization retains bounded metadata evidence, reads in admitted byte slices,
and finalizes only after current lexical data and semantic checkpoints agree.
Broader mismatched frames remain conservatively opaque. Rapid edits, inverse
edits, reload, explicit tiny budgets, long rows, and existing unfinished repair
are covered by eight deferred-fragment tests (ARCH-ORDER, ARCH-DRY).

The document mapping passes 233 tests; the response integration file passes 74.
The broader exchange and lifecycle mappings reached legacy synchronous-fold and
timer-count assumptions, respectively; fixtures now explicitly converge shared
rendering and isolate the timers under test. Remaining mapped files are running.
Production lint is clean across 20 core/consumer files. M3 review is pending.

A fresh staging performance report passes all 30 schema-4 scenarios. Timed native
input includes up to four bounded repair steps: at 1,000/5,000 rows, Enter plus join
copies six rows and visits 815/929 nodes; ordinary typing copies one row and
visits 261/288 nodes. Every hot phase has zero full-buffer reads. Diagnostic phases
now observe zero deferred semantic rows, and an explicit 5,000-row fixture cleanup
probe is idle with zero work. This removes the earlier hidden whole-document
repair debt; an exact feature-commit `make perf` run will anchor review evidence.

### 2026-09-15 — M3 full feature benchmark and contract audit

`make perf` passed all 30 scenarios on feature commit `7d320240`, with five
warmups and 20 measured samples per scenario. At 5,000 rows: typing median/p95
8.346/10.193 ms, Enter+join 18.274/27.298 ms, viewport redraw 0.458/0.510 ms,
and current production stream+human interleaving 22.312/24.098 ms. Ordinary input
and viewport phases perform no full-buffer reads. The explicit structural-change
repair phase costs 3.538 s median across its repair/restore workload; this is
scheduled broad invalidation, not hidden debt after ordinary input. Report:
`/tmp/parley254-m3-feature-perf.json` (schema 4; environment records exact commit).

Mapped verification is green: document 233, lifecycle 510, exchange/layout 264,
highlights 84, outline 216 tests; mappings overlap. Full `make lint` passes all
496 Lua files. Two remaining contract-audit fixes precede M3 review: batched native
fold application (including the >50,000-row mode) and preservation/relocation of
an unread repair request under continuous disjoint edits. The latter reproduced
zero bytes of progress across 1,000 slices because every keystroke cleared the
coordinator's pending request. These are active fixes, not waived requirements.

` sdlc actual --issue 254` currently reports 0.28 cumulative hours and attributes
the window across #192 and #254. Existing worktree attribution remains unreliable
for this multi-hour effort; retain explicit N/A rather than invent a per-milestone
increment or pollute calibration with that undercount.

### 2026-09-15 — M3 repair progress and native fold batches

Removed the coordinator's disposable numeric read cache. Unread lexical requests
now refresh local source evidence immediately before bounded IO, so continuous
disjoint edits cannot starve or misdirect repair. Four regressions cover sustained
edits, row relocation, source overlap, and insufficient-budget zero-IO behavior.
The document mapping passes 237 tests before adding native fold batch coverage.

Native fold application now captures and creates at most 64 groups per slice;
above 50,000 affected rows, cleanup is also capped and folds are temporarily
disabled with per-window preference/view restoration. Deferred ordinary joins
preserve existing folds while allowing previously dirty work to resume. Native
join coverage passes three tests; the full exchange mapping passes 264 tests.
The five-test native batch suite passes independently in 35–44 seconds but hit
Plenary's 50-second timeout during the mapped run. A narrowly scoped harness
timeout is being added; final integrated verification and M3 review remain pending.
The timed-out child has exited; no process cleanup is required.

### 2026-09-15 — M3 final verification and review submission

Document mapping: 245 passing tests (`document-complete`, `semantic-final`, and
`document-rest` logs under `/tmp/parley254-m3-*`). The large semantic corpus also
hit Plenary's default deadline under load; both 50,000-row corpora now have exact
file-scoped 180-second deadlines. The selection regression passes, normal test
deadlines remain unchanged, and the resumed corpus passes all 20 tests.
Exchange/layout 264, lifecycle 510, highlights 84, outline 216 are green as
recorded above; mappings overlap. Full lint passes 501 files, with the final
runner-only changes re-linted separately.

`make perf` passes 30 schema-4 scenarios on `ea933f51` (five warmups, 20 samples;
report `/tmp/parley254-m3-current-perf.json`). At 5,000 rows, median/p95 milliseconds:
typing 7.870/13.452; Enter+join 17.447/19.493; redraw 0.529/0.894; fold maintenance
1.343/1.626; stream/human 23.556/52.326. Samples ran alongside conformance tests,
so timing includes contention. Deterministic work remains one copied typing row,
six Enter/join rows, zero redraw semantic rows, and zero hot full-buffer reads.
Broad explicit repair/restore costs 3.867 s median. No 8 ms streaming claim is
made; its old production writer is explicitly the next milestone's migration.
M3 implementation is ready for mandatory review. Actual-time attribution remains
N/A for the unreliable cross-issue worktree measurement explained above.

### 2026-09-15 — M3 review REWORK

The mandatory `2afd7de9..626e565e` review raised BR-5 (grouped-undo callback
provenance), BR-6 (unconfirmed semantic presentation), BR-7 (stale proposed entity
inventory), and BR-8 (document/editor and fold-autocmd retention). M3 remains
open. M4 staging is preserved and paused while three bounded fixes proceed in
`/tmp/parley254-m3-review-stage`; the feature branch owns documentation and review
state. The plan now contains a complete current M3 module/function inventory,
explicitly superseding the original proposed paths and deferred migration claims.
No review finding is waived; grouped-undo parity, uncertainty presentation, and
native reclamation regressions precede the next gate.

### 2026-09-15 — Preserved M4 staging checkpoint during M3 rework

`/tmp/parley254-m4-stage` retains isolated, uncommitted M4 work, based on
`85a3d793` plus the later M3 read-progress core copied before staging began.
It is not part of the reviewed feature branch. Pure `generation.lua` passes 28
tests: bounded staging, exact partial receipts, child isolation, separate logical
completion/cleanup and 100-round retention. `generation_runner.lua` passes 18
stateful integration tests, acquiring before preparation, handling synchronous
callbacks, private append contexts, stale-input continuation pauses and bounded
blob retention. `document/append.lua` passes 12 tests, including large lines,
split syntax, UTF-8 byte lookup and accepted-prefix accounting.

Root's `dispatcher.create_output_handler` has five passing fragmentation/long-line
tests. A new header-only authority branch has three passing native tests; header
grants cannot cross rows and remain independent of answer/question edits. Neither
is connected to the final response flow yet. Scoped replacement is designed but
unimplemented: a private cursor will remove old owned text in bounded slices and
append replacement bytes with receipt accounting, via the runner's staging cap.

Non-generation caller migration removed the delayed drill-in whole-buffer fallback
and routes picker/image/reference/branch/skill-result edits toward captured user
transactions. Native regressions reproduced disjoint-text loss and deleted-marker
resurrection before fixes. User transaction core has ten passing unit tests, but
its source certificates currently expire when an opaque region is materialized
without a native text change. This safely rejects callbacks but blocks unchanged
async skill/image paths; stable text provenance through metadata materialization
remains an explicit M4 blocker. No repair suppression or fresh post-IO authority
workaround is accepted. Generic disk-writing skills with unknown target ranges
use conservative pre-IO whole-source guards; conflicts leave the live buffer intact
and surface the external result for explicit reconciliation.

All M4 agents paused at this state for BR-5/6/8. Preserve their files when bringing
M3 frame/presentation/retirement fixes into that staging tree; do not overwrite
shared document/editor/sequence hooks with whole-file copies.


### 2026-09-15 — M3 review verification and isolated staging durability

BR-5/6/8 fixes are now on the feature working tree, including native callback-frame,
undo-history and retention conformance. Highlight mapping passes 85 cases and lint
passes 504 files. The document mapping's sole attachment fixture failure was an
obsolete assertion that no `on_lines` hook exists: the same byte observer now owns
a non-mutating frame barrier. The corrected fixture checks one paired attachment;
the resumed document mapping passes. Exchange mapping still fails the first
stream-observer assertion in `chat_respond_spec`; root-cause investigation and
lifecycle checks are ongoing. No final benchmark or review clearance is claimed.

M4 preparation is now committed in its isolated staging checkout: `6cf67e52`, then
`b6723424` merges current M3 review fixes while preserving generation/user hooks.
Its focused append/generation/runner/frame/retention/header/user tests pass 83 cases.
Only the bounded ephemeral source-guard task resumes there; integration waits for
M3 review clearance. The source-materialization blocker remains open.

### 2026-09-15 — M3 review suites complete

The streaming fixture now crosses an explicit native bootstrap barrier before
its timed delivery assertions. A probe showed the first timed wait evaluated its
predicate once, spent 1,572 ms in queued setup work, and returned timeout although
the observer count was already one. No production code or stream timeout changed.
The full response spec passes 74 cases. Combining passing mapped files, including
the corrected attachment fixture and the resumed remainder, gives complete
coverage: chat/document 263, ui/highlights 85, chat/exchange_model 264 and
chat/lifecycle 511; 952 cases across 76 unique files (mapping overlap excluded).
Full performance proof is still running on production commit `ebd0585b`. Its
run overlaps the short focused response verification and small M4 unit probes;
report-only timing will disclose that load rather than claim a pristine host.

### 2026-09-15 — Final M3 review-fix performance evidence

`make perf PERF_OUTPUT=/tmp/parley254-m3-reviewed-perf.json` completed with all
30 schema-4 scenarios, five warmups and 20 samples on `ebd0585b` (Darwin, Neovim
0.11.7). Subsequent feature changes are test/docs only. At 5,000 rows:

| Phase | Median / p95 ms | Structural rows / copied entries | Full-buffer reads |
|---|---:|---:|---:|
| Ordinary typing | 7.836 / 10.001 | 1 / 1 | 0 |
| Enter + Backspace | 18.147 / 24.543 | 5 / 6 | 0 |
| Viewport redraw | 0.537 / 1.108 | 0 / 0 | 0 |
| Ordinary fold maintenance | 1.222 / 1.427 | 1 / 1 | 0 |
| Legacy stream + human input | 30.017 / 32.883 | 20 / 22 | 0 |
| Explicit broad repair | 3403.101 / 3498.989 | 18,987 / 18,987 | 0 |

Ordinary Enter/join performs zero native fold operations. The legacy streamed
interleave now honestly clears uncertain semantic folds: 126 outer groups /
252 native operations at 5,000 rows, across bounded consumer batches. That
affected-output work is not a constant-work claim, and the stream p95 does not
meet the 8 ms aspiration. M4 owns removal of growing stream-row replacement and
its materialized live-model reconciliation. Broad structural repair is incremental
and yields to input; its aggregate time still scales with affected structure.
The report overlaps short response/spec and M4 unit probes; timing is report-only.

All four required mapped suites have passing file coverage (document263,
highlights85, exchange264, lifecycle511), and final lint reports zero warnings
/errors in 504 files. BR-5/6/8 production fixes, their native regressions and BR-7
inventory correction are committed. M3 remains pending the mandatory review retry.

### 2026-09-15 — M3 second review and complete consumer evidence sweep

Second review `2afd7de9..976bf963` is REWORK with all prior BR-5/6/7/8 findings
addressed (including pre-fix red comparisons). New BR-9 rejects outline selection
that uses a surviving handle without current semantic eligibility. M3 remains
2/6 closed. The fix checks the exact current outline projection before navigation;
its native uncertainty/reclassification/deletion/relocation/tree tests are underway.

The same sweep reproduced an additional delayed diagnostic-publication defect:
a preceding text-to-fence edit left candidate flags unchanged, so a pending job
published while its context was unconfirmed. Pending jobs now retire on semantic
changes too. Red observed; the focused diagnostic lifecycle/publication, adapter
and parser suites pass. The plan records every consumer's eligibility boundary.
M4 remains isolated; its source guards, capacity tickets, presentation-only pending
UI, delayed user callers and bounded replacement preparation are not M3 changes.

### 2026-09-15 — M3 BR-9 verification and third boundary review

Committed `a8d9d770` validates exact current outline eligibility before navigation
and after focus callbacks, binds disk selections to bounded source evidence, and
retires pending diagnostics on semantic-context changes. The whole outline mapping
passes 223/223 across six files; diagnostic integration/unit/text suites pass
12/14/6. Native red reproductions precede the fixes. Lint is clean in 504 files;
consumer eligibility contracts and review lessons are recorded in atlas and plan.

The full performance run `/tmp/parley254-br9-perf.json` completed on `a8d9d770`
(Darwin, Neovim 0.11.7, 30 scenarios, five warmups and 20 samples). At 5,000 rows,
median/p95 milliseconds are typing 7.778/14.652, Enter/join 15.702/18.545, redraw
0.717/1.539, folds 0.751/0.959, legacy stream/human 29.905/52.275, and explicit
broad repair 2434.630/2504.419. Every measured phase has zero full-buffer reads.
Typing processes/copies 1/1 rows; Enter/join 5/6; legacy interleave 23/25 and clears
126 affected outer fold groups with 252 native operations. These are measured
aggregate costs, not constant-time or 8 ms guarantees. Short isolated M4 probes
ran concurrently; timing remains report-only. M4 will replace the legacy writer.

The third M3 review uses this committed consumer class sweep. M4 remains isolated
and incomplete: submission-to-runner admission, annotation-preserving replacement,
scoped readiness and provider adapters are being integrated, with no main merge.

### 2026-09-15 — M3 third review: reentrant effect ownership

The third boundary review (`2afd7de9..654687dd`) confirms BR-9 addressed but
raises BR-10: DiagnosticChanged can invalidate a publication synchronously, then
the returning old job clears the newer dirty flag. The feature remains 2/6 closed.
A native class sweep reproduces both diagnostic effects, detach, recursive step,
and replacement refresh during clear. Nine diagnostic reentrancy tests now pass,
including real reload, injected-reader failure and converter reentry. Publication
checks captured job identity after callback-capable effects, preserves newer
invalidation, and accounts only effects actually performed. Reentrant step reports
busy instead of publishing the same job recursively.

The same sweep reproduces a fold OptionSet callback editing the source during
restoration, after which the old job erased new dirty work. Its native fix/test
is in progress. M4 continues in its isolated checkout; no gate was bypassed and
no M3 completion is claimed. The next review must include both fixes and the
cross-consumer callback-boundary contract, even though the default three-round
review budget has been used.

### 2026-09-15 — BR-10 fixes ready for broad verification

The diagnostic class sweep passes nine new native cases plus existing 12/14/6
integration/unit/text cases. Four native presentation tests pass: source edits
during fold restoration, replacement fold jobs without text changes, detach
inside option configuration, and redraw textlock. Existing document-fold,
tool-fold, join, retention and highlighter-document suites all pass. Four-file
lint and diff checks are clean. Detach now removes the fold-generation scalar;
standalone native fold clearing also supports an unattached buffer.

M4 checkpoint `38e0ed14` preserves the released adapters and caller migrations.
Additional reservation cancellation, copied continuation input, provider result
and preparation geometry fixes remain isolated. The tool-round adapter draft is
not yet verified or wired. No milestone or whole-issue completion is claimed.


### 2026-09-15 — BR-10 verification completed; timing comparison under investigation

Production commit `b62c2b59` passes the complete chat/document mapping: 276 tests
in 29 files, including native broad-fold conformance. Lint checks 506 files with
zero warnings/errors. Full benchmark `/tmp/parley254-br10-perf.json` completes
30 scenarios with 20 samples each; every scenario reports zero full-buffer reads.
At 5,000 rows, median/p95 milliseconds are typing 9.273/10.127, Enter/join
21.149/22.520, redraw 0.650/1.324, folds 1.201/2.245 and legacy stream/human
interleave 37.610/54.511. Broad repair is 8777.140/8843.768 versus the prior
2434.630/2504.419, despite identical 18,987 processed/copied rows and 2,567,147
index visits. This timing difference is being investigated before boundary close;
it is not dismissed as noise or claimed as a responsiveness guarantee.

M4 isolated tool-round integration passes five tests including ordered completion,
unknown-to-known evidence with explicit resume, sibling-only cancellation and
positive fixture cleanup. Production respond wiring remains outstanding.


### 2026-09-15 — Controlled repair comparison and fourth M3 review

Read-only investigation `/tmp/parley254-br10-perf-investigation.md` compares
old/current fold code under the same 1,000-row repair probe. With JIT disabled,
medians differ by less than 1% (about 724 ms); JIT-enabled identical current code
varies from 287–302 ms to 550–621 ms across processes. The full benchmark uses
`pairs()` phase order, changing trace/warmup context between reports. No consistent
BR-10 algorithmic regression was reproduced; the full-run 8.8-second broad repair
latency remains disclosed and is not replaced by the smaller probe.

The fourth M3 boundary review extends `WF_BOUNDARY_ROUND_CAP` to four because
BR-10 was newly raised at the third review and its native class fixes require a
fresh review. Review and open-finding gates remain enabled. Use Claude for this
review after earlier Codex agent usage exhaustion. Actual-time attribution remains
N/A: the measured window mixes #192/#254 and cannot reliably attribute this work;
only that measurement gate is waived, without entering invented hours.


### 2026-09-15 — Fourth review and production response migration

Fourth M3 review window `2afd7de9..d349c02e` disposes BR-10, returns
FIX-THEN-SHIP, and raises BR-11/BR-12 for superseded fold restoration and truncated
window-configuration plans. The ledger refuses milestone finalization while these
are open. Native class fixes are in progress; M3 is not closed and no gate was
waived. The exact review evidence remains in the M3 review and close-gate sidecars.

M4 now replaces the old public respond writer in its isolated staging checkout.
Six public-command cases pass: disjoint generations, human next-draft edits,
overlap refusal, preceding-stream edits during next-question admission, source
deletion during remote preparation, scoped Stop, and automatic topic integration
(the disjoint test combines the first two behaviors). Session/ordered-tool/topic
and completion adapters have native/fake integration coverage. Input-prefix edits
mark frozen input stale instead of rejecting disjoint output admission. Completion
now carries its real operation identity. Native history is observed directly;
old pending confirmation and global Stop repair are removed.

Migrating older tests and the production benchmark exposed remaining integration
issues: an unobserved native tick advance can deny the first owned append after
preparation; next-prompt insertion can extend the finishing grant across the new
exchange and revoke it; old parser answer ranges can include trailing footnotes;
provider failure notification can precede committed admitted bytes. Regression
assertions remain in place. Editor frame proof and finite released insertion fixes
are underway; captured footer exclusion and terminal failure-notice ordering have
been implemented and are being rechecked. This is WIP, not an M4 completion claim.


### 2026-09-15 — BR-11/BR-12 fixed and M4 checkpoint preserved

The fold class fix restores captured window state regardless of publication
supersession, constructs window plans atomically, discards only the expected job,
and reschedules surviving windows after setup interruption. Four added native
controls fail with the prior file; 43 focused tests (eight reentrancy plus existing
fold/batch/retention/join suites) pass, including broad native folds. Full lint
checks 506 files without warnings/errors. The fourth review's ledger refusal
requires another review to dispose BR-11/BR-12; the per-boundary budget is extended
to five, with all review/ledger gates still enabled.

M4 checkpoint `3954cc0d` commits production response composition in isolated
staging. Follow-up native regressions now pass: 23 migrated public response cases,
21 completion cases, five ownership cases, seven stateful-process progress cases,
six public scoped-response cases and 62 branch cases. Lint checked 548 files clean.
The first owned native append now authenticates a captured frame even after save
advances changedtick without callbacks. Normal typing/streaming aggregate repair
remains under investigation: a 1,000-row probe preserved bytes but repaired 1,639
rows. Tracing identifies structural-token fallback overbroad dependency channels
and loss of the prepared tail-row extent for a newline append. No performance
completion is claimed; M4 legacy removal/full verification and M5/M6 remain.

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


### 2026-09-15 — M4 integration verification checkpoint

Production response composition, captured onboarding profiles, per-child remote
preparation cleanup, guarded drill-in transforms, scoped Stop/StopDocument,
independent topics, ordered tool slots, and bounded append/replacement receipts
are implemented. Legacy tool_loop/chat_lease production registries are removed.
M4 staging checkpoints: 3954cc0d, 97c854f3, 3f89893e, 48c67ce2, 785674c9.
The combined renderer integration is 0cf9bf23 in /tmp/parley254-integrate.
The feature branch remains unchanged while M3's fifth review runs against
0257ddad; its open ledger findings must be disposed before milestone closure.

Verified the combined tree across 131 unique mapped files (1624 tests, zero
failures/errors) and full lint (556 files clean). The mapped attachment send-guard
failure was corrected: oversized requests report the configured limit before
answer preparation or provider IO, preserving source text. New ownership mapping
is nonempty and its tests are included. The complete M4 staging benchmark passed
30 scenarios x20 samples; stream/human interleave at 5000 rows was54.87ms median,
18 structural rows, zero full reads; broad repair still costs4.52s cumulative.
An additional full report is running against the combined renderer tree because
that merge changes production presentation code. See the durable plan Revisions
for measured bounds, compatibility decisions and M5 source-revision prerequisites.

Remaining: receive/dispose M3 review, finish combined performance evidence, close
M4 through its mandatory review, implement M5 recovery/batch and M6 asynchronous
builtin/resource supervision. Do not merge to main; operator live testing follows
the completed issue and precedes merge. No fabricated actual-time value recorded.

### 2026-09-15 — M5 isolated implementation checkpoint

Codex is the reviewer for all remaining boundaries, as requested by the operator.
Its M3 review retained BR-11: cancellation inside an already-suspended fold slice
can overwrite retirement cleanup. The feature worktree owns that focused fix; M5
continues separately in /tmp/parley254-m5-stage until M3/M4 gates close.

Combined M4 performance completed: all30 scenarios x20 samples passed hard gates;
27 non-stream scenarios have identical work counters to staging. At5000 rows,
stream median/p9568.80/114.28ms,17 structural rows, zero full reads. Broad repair
11.01/13.02s with unchanged counters; reviewer CPU overlap limits timing attribution.
Report: /tmp/parley254-m4-integrated-perf-summary.md.

M5 recovery core has22 passing tests and clean lint, including native temporary
filesystem publication and stateful fault coverage. Root batch reducer tests have
the expected missing-module red (/tmp/parley254-batch-red.log); implementation is
next. Document question/context revision proofs are independently in progress.
Batch membership is fixed; only positive leg completion advances progress; opaque
proofs defer and unknown effects cannot be replayed by resume. Recovery host/UI
integration and atomic Document restore proof remain outstanding.

### 2026-09-15 — M5 staged implementation checkpoint

M3 closed506d2c34; verified M4 now on feature head ae2e12ec and under Codex review
(log /tmp/parley254-m4-gate-codex.log). M5 stays in /tmp/parley254-m5-stage.
Batch7files/87tests and publicresponse27tests pass, including frozen request
membership and real registered resume! command. Recovery store/adapter/UI/privacy
focused suites pass; ambiguous close reconciliation is being strengthened before
final mapped recovery run. Tool-side recovery-path exclusion belongs to the M6
common admission/traversal migration and remains mandatory before issue completion.
M6 pure operation/resource contracts committed82a5fb12; async filesystem and
Tasker supervision work proceeds in /tmp/parley254-m6-stage. No main merge or final
completion is claimed. Operator live testing follows all six completed boundaries.
