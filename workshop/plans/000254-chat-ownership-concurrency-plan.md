# Chat Ownership and Incremental Structure Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve arbitrary human buffer edits while an answer is generated into another region of that buffer, with bounded interactive rendering work and explicit ownership through cancellation and tool effects.

**Architecture:** Neovim owns text. One document coordinator owns an incrementally maintained structural index, regional revisions, and revocable generation write grants. Pure document/generation/attempt/tool/batch transitions decide effects; thin editor and process adapters execute them and return observed outcomes. Rendering queries confirmed index regions without parsing.

**Tech Stack:** Lua, Neovim 0.11 buffer callbacks/extmarks, libuv, Plenary, existing LineReader/performance harness.

**Status:** Operator-approved; plan-quality accepted and implementation underway. The operator will live-test before merge. Issue: `workshop/issues/000254-chat-ownership-concurrency.md`.

---

## Chunk 1: Design and contracts

### Scope and decisions

- The operator confirmed one live Neovim buffer with human edits and generated output. File reload invalidates current writes. This does not implement concurrent file saving across processes, a CRDT, or persistent exchange IDs in Markdown.
- Support multiple active background operations in one document from the outset, including concurrent tool children within an answer and generations on distinct exchanges. Acquire each generation before asynchronous preparation. The ordinary UI flow remains typing the next question while an answer streams; core APIs and production-path tests must also exercise concurrent disjoint writers.
- Human edits are observed after Neovim applies them; preservation never depends on intercepting every mapping. An edit inside generated output revokes that generation's write grant. No edit is automatically rolled back. A purported region-level `modifiable` lock is not the safety mechanism.
- The repository has `stopinsert` at response submission, history confirmation, and pending guards for specific commands. No general chat typing lock was found. Revisit those controls individually once production-path ownership tests pass.
- The buffer may be malformed or temporarily ambiguous. Unresolved text remains visible and editable; it is not a target for automatic writes or speculative folds.
- Existing grammar remains the compatibility contract. In particular, ordinary closed-fence detection and tool-body recovery have different rules. This change does not simplify them silently.
- All transcript writers, including topic changes, completion cleanup, tool insertion, definition/drill-in edits, and chat editing commands, must participate. Scratch picker/help buffers remain outside the coordinator.
- Keep process/tool outcome hardening in this issue because revocation must not lose ownership of outstanding work or authorize repeated side effects. Implement it at separate, reviewable boundaries.

### Facts that shape the design

| Current source | Fact and consequence |
|---|---|
| `highlight_structure.lua:429` | Same-fingerprint replacement shares arrays; structural/newline splice copies two document-sized arrays and rederives marker indexes. Replace storage, not just the parser entry point. |
| `highlighter.lua:950` | Dirty repair/full resync rebuilds the whole structure; redraw itself is already viewport-oriented. Preserve the renderer query shape and replace its cache ownership. |
| `exchange_model.lua:169` | Relative sizes avoid stored absolute rows but prefix summation still grows with exchange ordinal. An indexed sequence must own positions. |
| `exchange_anchors.lua:75` | Every changed tick resolves all exchange anchors to defend ordinal identity. Stable entities should remove that global proof. |
| `tool_folds.lua:149` | Drift recovery performs a full parse; exchange updates clear/recreate folds even for ordinary body changes. Consume structural deltas instead. |
| `fence.lua:143`, `chat_parser.lua:824` | Later fence/reasoning terminators can change earlier interpretation. Dependency invalidation must travel backward as well as forward. |
| `chat_respond.lua:1323` | Preparation precedes pending ownership; completion and resubmit use captured indexes/ranges. Acquire ownership first and resolve every write through the document. |
| `dispatcher.lua:894` | Stream handler retains its own position/count and joins undo entries. Make it a text assembler; editor owns positions and undo grouping. |
| `tasker.lua` | Probe failure, failed stop, and retention can discard unresolved work. Preserve exit-plus-pipe-drain barrier and distinguish uncertainty from termination. |

Line references describe the planning baseline and are navigation aids, not tests.

### Core concepts — pure entities

The following are proposed entities, introduced only at their listed milestone. Do not demand that future-milestone symbols exist in earlier reviews. Existing helper modules remain reusable; the tables describe ownership changes, not a second implementation of every parser.

| Name | Lives in | Status | Introduced |
|---|---|---|---|
| Indexed sequence | `lua/parley/document/sequence.lua` | new | M2 |
| Grammar checkpoints and dependency queries | `lua/parley/document/grammar.lua` | new | M2 |
| Incremental structure | `lua/parley/document/structure.lua` | new | M2 |
| Document transitions and identity reconciliation | `lua/parley/document/state.lua` | new | M3 |
| Generation transitions | `lua/parley/generation.lua` | new | M4 |
| Attempt transitions | `lua/parley/attempt.lua` | new | M1 |
| Batch transitions | `lua/parley/batch.lua` | new | M5 |
| Tool operation outcomes | `lua/parley/tools/operation.lua` | new | M6 |
| Resource admission | `lua/parley/tools/resources.lua` | new | M6 |
| Fold projection | `lua/parley/fold_projection.lua` | modified | M3 |
| Layout projection | `lua/parley/exchange_model.lua` | modified | M3 |

The indexed sequence owns location, not full authoritative text. One document owns one structure and a map of exchange/block identities. An exchange has one question, zero or more answer components, optional preface, and monotonically increasing regional revisions. A generation captures one exchange and input snapshot; it owns an answer envelope, one provider attempt at a time, and a round of potentially concurrent tool children. Its envelope delegates disjoint leaf write grants to children; the parent cannot write a delegated child region. Tool rounds are sequential, but children within a round may run concurrently. A batch owns a fixed ordered list of selected exchange identities and expected revisions. Multiple documents share a transport adapter without sharing cancellation authority.

`ARCH-DRY`: reuse `highlight_structure.classify`, `fence`, `answer_structure`, question-preface helpers, `render_buffer`, and the existing presentation reducer. Grammar extraction moves decision ownership into a pure layer; full parsing, incremental parsing, highlighting, and folds derive from that owner. No permanent independent live layout in tool_loop or dispatcher. Pure units follow the repository convention of tests in `tests/unit/`, with no Neovim or IO mocks.

### Integration points

| Name | Lives in | Status | Wraps | Introduced |
|---|---|---|---|---|
| Document coordinator | `lua/parley/document/init.lua` | new | Private state, event serialization, effect dispatch | M3 |
| Editor adapter | `lua/parley/document/editor.lua` | new | Buffer attachment, generation epochs, patch receipts, scheduler | M3 |
| Buffer edit primitives | `lua/parley/buffer_edit.lua` | modified | Neovim text mutation and undo boundaries | M3 |
| Provider/process supervisor | `lua/parley/tasker.lua` | modified | Process-scoped operation ownership, libuv handles/probes/signals/drain | M1 |
| Generation runner | `lua/parley/generation_runner.lua` | new | Preparation/provider/tool effects | M4 |
| Recovery store | `lua/parley/answer_recovery.lua` | new | Portable private folder and verified snapshots | M5 |
| Tool filesystem adapter | `lua/parley/tools/filesystem.lua` | new | Checked open/write/close/backup operations | M6 |
| Tool scheduler | `lua/parley/tools/scheduler.lua` | new | Async child execution and process-wide resource claims | M6 |

These adapters invoke pure transitions; pure functions do not call them. Stateful editor/process/filesystem doubles implement the consumed interfaces with controlled scheduling and failures. Owned test stores are scratch folders, never production chat/profile directories. Real isolated Neovim tests establish callback, undo, extmark, and fold behavior against the doubles' assumptions.

### A. Text changes, identities, and permissions

The editor receives granular `on_bytes` events (old coordinates/length and new coordinates/length), plus reload, detach, and nontext changedtick events. Normalize to a half-open byte edit in old-document coordinates. New text is read through LineReader only within work budgets. `on_lines` is not a second independent mutation event source. Test callback order, multiline columns, UTF-8, empty-buffer normalization, and command preview against the installed Neovim runtime.

The event path is:

1. Against the old index, intersect the edit with grants and semantic boundaries; revoke touched output grants immediately. A pure insertion strictly inside a leaf region belongs to that region. A human insertion exactly at a shared boundary suspends adjoining grants until structure confirms attribution; do not guess that it extends generated output. Generated insertions require a named insertion slot with one owner, so two writers never race to append at the same coordinate. Native ambiguous boundary edits revoke rather than extend ownership.
2. Splice index coordinates and increment affected content revisions. Large/unread insertions become opaque unresolved spans with known aggregate size; do not allocate one entry per pasted line in the callback.
3. Mark dependent structure unresolved, including backward dependencies. If a grant may fall within that uncertainty, suspend writes until it resolves; if its identity/output boundary is no longer provable, revoke it. No expensive semantic repair is necessary to stop an unsafe writer.
4. Schedule bounded repair against a document epoch, local text-provenance stamps, and dependency certificates. Publish only results whose specific inputs still match; unrelated edits may advance the buffer revision without discarding this work. Rendering and further edits may proceed while repair is pending.
5. Reconcile surviving marker provenance with new structure. Surviving question-marker bytes with the same semantic role preserve identity; body edits only advance regional revisions. Deleted markers retire identities. New/ambiguous markers get new identities after confirmation. Text equality, ordinal, row, or an extmark restored by undo cannot resurrect an old grant.

An explicit Parley move operation carries source identity through its validated edit transaction. Native cut/paste has no trustworthy move intent and creates new identity on insertion. Partial deletion may leave readable fragments without an actionable exchange. Restoring text through undo does not restore generation state. A headerless initial assistant exchange uses a document-scoped synthetic identity tied to its surviving initial boundary; restructuring that boundary revokes its grant.

Bound active ownership by explicit admission limits: at most four generations and sixteen leaf write grants per document, with at most four running tool children per generation and eight per document. Check this bounded grant set directly on every edit before lazy structural work; count that work. Overlapping grants are rejected, including shared insertion slots. A multi-region tool mutation acquires all required grants atomically or none; it never waits holding a subset. The sequence index handles arbitrary numbers of inactive exchanges without visiting each deleted entity synchronously. Retired identities are recognized by absence/provenance and monotonic IDs rather than a growing tombstone table. Every identity lookup proves membership in the current live sequence root; a node retained by repair or recovery cannot resolve after subtree detachment. Node splits preserve provenance only for surviving marker bytes; changing marker bytes invalidates that evidence. Jobs retain bounded IDs/checkpoints, not detached document trees.

`resolve(document_epoch, operation_id, grant_id, block_id)` is an internal query, never a durable handle. A generated operation names an intent, such as append answer bytes, fill a result slot, finalize answer, or update topic if header revision matches. The coordinator validates the current grant, identity, region revision, and dependency certainty, then issues one narrow patch in the same non-yielding turn. Multi-patch operations validate a complete plan and revalidate after each observed patch; any unexpected reentrant edit stops the remainder. A mutation receipt advances the index; failure never speculatively commits model state. Partially applied edits remain visible and trigger reconciliation.

Our patch token labels only the exact expected callback edit(s), not every callback occurring while a boolean is set. Any nested or mismatching edit is external. Buffer epochs prevent callbacks for a deleted/reused buffer number from finding a new document.

### B. Incremental index and grammar repair

Use a balanced sequence tree with bounded line-metadata leaves and subtree row/byte counts. Local offsets, stable node provenance, lazy unresolved spans, and rank/select queries avoid top-level array shifting and repeated prefix sums. Suggested leaf bound: 128 rows; byte scanning is separately limited. Mutating a local span copies/visits bounded leaves plus a logarithmic path. A large removal detaches subtrees; reclamation must be accounted for separately from foreground semantic work.

Public read-only queries: structure intersecting rows, parser state at a confirmed boundary, exchange/block by identity, current range, next/previous exchange, and fold blocks in a changed region. No consumer receives mutable backing tables. Payload strings are materialized only for request/export commands from a captured revision, not per keystroke or redraw.

Checkpoint state includes component/role, applicable fence modes and widths, tool-body recovery state, reasoning mode/opener dependency, preface association, and footer/draft state. Extract this from existing grammar rather than use the smaller highlighting state as semantic proof.

Maintain searchable marker summaries plus dependency intervals for lookahead decisions:

- A matched ordinary fence depends on its closer; an unmatched opener depends on the searched suffix, including the negative fact that no closer exists. Inserting a closer must invalidate the earlier unmatched opener.
- Tool body matching depends on its closer or first structural barrier, with its existing column/width rules.
- Reasoning mode depends on the first explicit END or terminating structural barrier; changes can invalidate earlier blank-line interpretation.
- Prefaces depend on adjacency to the following question; footer/draft metadata has explicit region dependencies.

Store dependency intervals in an augmented search tree whose overlap query returns the minimum affected restart origin without enumerating matches. Endpoints use stable sequence provenance rather than absolute suffix rows; subtree lazy invalidation tags retire overlapping certificates. Reparsing enumerates affected certificates only under slice budgets. This must handle thousands of unmatched openers depending on EOF, not merely one opener. Repair resumes from a confirmed checkpoint before that point, updating dependencies as well as tokens. Reuse a suffix only when complete parser state, unchanged-text provenance, and dependency certificates agree. A token-kind match alone does not certify payload/revision equality. Cascading dependencies may require the whole remainder; process it in slices, never promise constant total work for adversarial syntax.

Repair queues prioritize visible regions and grant-dependent regions fairly, with round-robin progress for other dirty spans. A hot streaming region cannot continually restart a disjoint job; overlapping edits preserve confirmed prefix work and restart only invalidated dependencies. Keep a full materialization path for initial compatibility/differential testing and explicit send/export commands. Runtime consumers ultimately share the same grammar implementation; independent golden expectations and preservation invariants remain tests after differential parity stops being an independent oracle. Initial attachment and reload build incrementally; there is no hidden synchronous full-build fallback on redraw, typing, or per-chunk paths.

### C. Highlighting, colorization, and folding

Highlighter queries only visible/context rows plus the confirmed entry state, under a byte budget as well as a row budget. A physically long visible line cannot force a full-line read or unbounded regex scan: use bounded byte slices and neutral styling outside the analyzed slice. Confirmed unaffected regions retain semantic styling. Unresolved regions get neutral/local styling that makes no claim about roles or fences; pending status belongs to decorations, not transcript bytes. No dirty-cache semantic reuse solely because row coordinates are aligned.

Fold projection consumes confirmed stable block IDs and ranges. Ordinary text edits with unchanged fold topology do not clear/recreate folds. Position movement follows editor behavior and index deltas; topology changes update only affected folds in each window. Invalidation clears affected semantic folds, not unrelated folds or the complete buffer. Store per-window open/closed state by stable block ID; preserve full view as in #253. For ordinary topology changes, query affected materialized folds by stable identity and delete/recreate only those folds. For broad structural invalidation, use a native visual-range `zD` in the affected window, preserving view, marks, mode, and foldenable. This removes partially intersecting/nested folds without a Lua row scan and preserves disjoint folds. Its native cost is O(affected span/fold structure), an explicit exceptional cost for broad edits, not constant-time work. Recreate confirmed folds in scheduled batches. The existing ownership rule applies: manual folds inside an affected exchange are Parley-owned; unrelated folds outside it survive. On documents above the 50,000-row interactive envelope, broad invalidation temporarily disables folds in affected windows while cleanup/recreation runs in slices, then restores operator foldenable and open/closed preferences. Ordinary editing has no fold-count cap.

Remove independent highlighter repair ownership, global exchange-anchor verification, and fold full-parse recovery once each consumer migrates. Outline/navigation/context operations use the same confirmed identities; while a requested region is unresolved they schedule/await repair or report unavailable, never choose a nearby positional substitute.

### D. Lifecycle state contracts

Separate machines avoid a Cartesian product of unrelated flags. Authoritative tables are private; callers get values/snapshots. Every unlisted event is explicitly rejected or ignored with no effects in transition tests.

| Machine | States | Principal events and effects |
|---|---|---|
| Document region | confirmed, unresolved, absent | edit aligns/invalidate; repair confirms only matching revision; reload replaces epoch and revokes all grants; detach releases index |
| Write grant | valid, suspended, revoked | direct output/boundary edit revokes; dependency uncertainty suspends; confirmed unchanged ownership resumes; revoked never resumes |
| Generation | preparing, requesting, executing_tools, paused, finalizing, stopping, terminal | acquire before prepare; prepared starts attempt only if owned; chunks request scoped patches; tool round reserves ordered child slots; children run concurrently within capacity; join all required outcomes before continuation; completion finalizes owned answer; cancel retires its subtree only |
| Attempt | starting, running, stop_requested, exit_observed, draining, resolved | spawn outcome; signal/probe evidence; exit plus stdout/stderr EOF resolve; failed probe/stop retains ownership; late events match attempt identity |
| Tool operation | queued, authorized, executing, rejected, cancelled_before_effect, outcome_known, outcome_unknown | reserve call/result IDs before dispatch; capability/resource check before effect; independent children finish out of order; preserve confirmed/partial/unknown effect evidence; formatting failure does not erase effect outcome; duplicate call does not rerun effect |
| Batch | ready, running, paused, completed | fixed selection; start validates question/context revisions; successful step advances dependency snapshot; conflict/failure/cancel pauses; explicit resume revalidates remaining work |

Context changes outside the output do not rewrite an in-flight input snapshot. Mark the answer stale using a captured dependency set; edits to a later question do not stale the current answer. Preparation completion cannot use a new buffer/window or silently substitute new input. Topic generation uses separate header revision authority. Completion flushes staged chunks before finalizing and only inserts a next prompt if the current successor structure warrants it.

Each provider round owns an ordered call list and a child-operation map. Preserve
provider declaration index in `tools/wire_anthropic.lua` and `tools/wire_openai.lua`;
neither completion order nor first received fragment is authoritative call order.
Reserve all call blocks followed by all result slots in that order before effects
start. A result slot can be empty model state with a decoration; do not insert
fabricated completed-result Markdown. Out-of-order completion fills the named
slot by canonical predecessor/successor identity. The next provider request joins
all required children and consumes the operation ledger, never a parser's
historical missing-result repair while children are still running.

The parent owns allocation/finalization, not an overlapping writable region:
delegated child grants exclude those slots from the parent's answer-tail grant.
Cancellation of a child revokes only its grant and attempts; siblings may finish.
A human edit to a child result slot preserves that edit and pauses automatic
parent continuation, because provider input must not silently mix edited visible
text with a different recorded result. Confirmed sibling effects remain recorded.
Deleting the whole exchange or canceling its generation revokes the subtree.
Parent finalization cannot release children while they retain unresolved work.
All completion events carry epoch, generation, round, operation, and attempt IDs;
buffer-local singleton pending/lease/tool registries must become operation-scoped.

Transition details that must not be collapsed into generic failure:

- Cancel during preparation enters stopping, cancels owned preparation handles,
  and rejects late preparation completion. It reaches terminal only when owned
  preparation/attempt/child work has resolved; no process means no exit event is
  required. Cancellation while queued removes admission without executing.
- Spawn failure before process/pipe creation is confirmed failure and resolves
  immediately; partially created handles are closed and acknowledged before slot
  release. EOF may precede exit, so attempt state records observed exit and each
  pipe's drain evidence rather than assuming callback order.
- Paused generation keeps completed results and may let already-running siblings
  finish, but admits no continuation. Explicit resume validates the changed target
  and input policy; a revoked grant cannot resume, so edited output requires a new
  generation/explicit regenerate rather than restoring old authority.
- Stopping generation has no writable grants and retains child ownership in the
  supervisor until resolution; only then is it terminal. Publishing an uncertainty
  diagnosis is a separate presentation event, not a terminal tool state:
  outcome_unknown keeps its resource claims and reconciliation path.
- Rejected and cancelled-before-effect children release queued claims immediately;
  executed children release claims only on a confirmed outcome. The round joins
  confirmed results or stops/pauses on policy-terminal refusal; an unresolved
  child never becomes a fabricated successful result to make the join finish.

Explicit Stop targets the generation containing the cursor; outside any active generation, a picker names the document's active generations. A separately named stop-document action cancels all its generations. Stop-all, if retained, is a separately named command. Revocation does not imply process exit. An attempt remains owned until exit/drain confirmation; after bounded reconciliation retries it becomes visibly unresolved and retains its resource/operation admission slot, rather than disappearing. Unrelated regions may still admit work within limits; conflicting resources remain unavailable until resolved. No new automatic tool round starts after cancellation.

Undo joins are allowed only across consecutive generated writes from the same generation with no intervening human/other-owner mutation or undo-sequence change. Native undo/redo is observed like any other edit. Remove blanket pending-history cancellation only after tests demonstrate that undoing unrelated typing preserves the stream and undoing generated output revokes it.

### E. Regeneration and batch recovery

Capture ordered exchange IDs and question revisions once. Each step uses the same single-generation runner. Validate selected questions and previously refreshed context revisions before advancing; new questions/cursor movement do not change membership. Missing identity pauses. Completed steps remain completed after later failure; tool effects are never rolled back by restoring text.

Before replacing an existing answer, persist its exact previous bytes and annotations through a checked private recovery store; failure to make a confirmed recovery snapshot refuses replacement. Stream the replacement in the normal owned answer region. On failure/cancellation retain partial output plus an explicit restore action. Restore is itself a validated document edit and never overwrites intervening human edits without an explicit conflict decision. Exclude recovery artifacts from chat discovery/provider input/logs.

Use at most one retained pre-replacement snapshot per exchange while a replacement remains unsaved/failed; retries retain the original snapshot instead of replacing it with partial output. After successful replacement and a confirmed save containing that revision, remove its snapshot. Explicit discard or confirmed chat deletion also removes it. Recovery records include the durable chat timestamp plus root/path evidence, question/predecessor fingerprints, and the expected replacement bytes/revision evidence. These are association evidence, not persistent exchange IDs. After restart, restore automatically resolves a target only if document association and replacement evidence are unique and exact; renamed chats use the existing chat resolver and ambiguity refuses. Otherwise offer snapshot inspection/export or explicit target selection with a fresh conflict check. Never select a duplicate question by ordinal. Each immutable snapshot record contains its metadata and bytes, is written/closed in a private temporary file, then atomically published on the same filesystem before replacement starts. A discovery index is derived from records, so a crash cannot strand an authoritative snapshot behind an uncommitted index. Truncated/unknown versions are quarantined as unavailable, never guessed. Budget proposal: 16 MiB per snapshot and 256 MiB per profile, refusing new replacement before exceeding the cap. Failed cleanup is surfaced and remains accounted for. No age-based deletion of the only recovery copy.

### F. Tool authority and process uncertainty

Capture allowed tool names/configuration with the generation and check each actual call against that snapshot, not the global registry. Scope call identity by generation, attempt/round, and provider call ID; a duplicate with changed arguments is a protocol conflict. Record accepted operation before effect dispatch. Known completed operations reuse the recorded result; unknown or partially completed operations never automatically replay. This is an in-process execution guarantee, not cross-restart exactly-once semantics.

Centralize checked file and backup IO for `write_file`, `edit_file`, and `propose_edits`. A failed backup prevents destructive overwrite. Write/flush/close failures retain partial/unknown outcome evidence. Wrap result normalization, paging, and serialization separately from effect execution; report result-processing failure without claiming the tool did nothing. Bound retained output and avoid raw payload/credential logging. The same stateful filesystem/process seams model fault sequences in production-path tests.

Document grants protect buffer regions; external resource claims protect tool
effects. A process-wide admission service accepts canonical file read/shared and
write/exclusive claims, subtree claims for traversals, and a conservative global
effect claim for undeclared custom tools. Resolve existing aliases and nearest
existing parent for new files through the same path-policy owner. Acquire all
claims atomically after capability/path validation; queue fairly without holding
partial claims. Read/backup/transform/write for an edit share the same exclusive
claim. Unknown effects keep their claims quarantined; unrelated resources remain
available. This coordinates Parley operations, not arbitrary external writers;
recheck observed file identity/revision before destructive writes.

Concurrency must be real async execution: scheduling a synchronous `handler()` on
the main loop is insufficient. Add `execute_async(call, context, completion)` and
cancellation handles. Builtin filesystem tools use callback-based IO with bounded
transforms; command tools use owned asynchronous subprocesses with explicit cwd
and argv, never global chdir or blocking `vim.fn.system`. Editor-only effects are
short scheduled coordinator operations. Classify all registered builtins, including
read_file, write_file, edit_file, propose_edits, grep, ack, find, ls, argv,
chat_history_search, parley_help, and emit_definition. Legacy custom synchronous
handlers require an explicit compatibility mode with no responsiveness/concurrency
promise; refuse them in concurrent scheduling by default and name the migration
contract. Worker callbacks never call Neovim APIs off its main loop. Keep serialized
buffer commits short while independent IO proceeds concurrently.

### Operating envelope and artifact lifetimes

`ARCH-CONSTRAINTS`: these are proposed engineering budgets to validate during M1/M2, not measured promises. Changes to them require a plan revision with the benchmark evidence.

| Path/resource | Proposed bound and behavior |
|---|---|
| Typing/redraw/chunk latency | Target p95 under 8 ms Parley-owned foreground work on the development machine, report-only timing; deterministic work limits are CI gates. |
| Ordinary edit | Changed text plus bounded leaf work and O(log N) navigation; no O(N) array copy, anchor scan, fold visit, payload materialization, or full read. |
| Broad fold invalidation | Native range clear is an explicit O(affected span/folds) exception within 50,000 rows; no Lua parse or row scan. Beyond that envelope, temporarily disable affected windows' folds and reconcile in slices. Native fold creation/deletion time is measured independently from Lua work counters. |
| Repair slice | At most 256 rows and 64 KiB scanned, additionally yield at 2 ms; counters include dependency/index visits and copies. Long lines use resumable byte scanning with persisted lexer position and bounded reads; they eventually reconcile after input quiesces. Never execute an unbounded full-line pattern scan as a repair step. |
| Scale corpus | 100/1,000/10,000/50,000 rows; ordinary edits at beginning/middle/end, huge paste/delete, long line, unmatched fences, sustained stream; up to four visible windows. |
| Queue/load | One scheduled pump per document multiplexes dirty regions fairly; only overlapping/dependent jobs supersede. Four generations/sixteen leaf grants/eight running tools per document; four running tools per generation. Per-generation staged bytes capped at 1 MiB aggregate across children; overflow revokes that generation with explicit partial-output outcome. Admission queues are capped at 32 child operations per generation; excess provider fan-out is a protocol/capacity failure before launching the round. |
| Process-wide admission | At most sixteen active generations/provider attempts, sixteen running tool effects, 128 queued child operations, and 16 MiB aggregate staged output. Fair rotation across documents/generations; unresolved operations retain their admission slots. Resource caps are named configuration values with validated finite bounds, not incidental table limits. |
| Attempt reconciliation | Poll with capped backoff for up to 5 seconds; thereafter visibly unresolved, no repeated busy polling; conflicting resource/operation slots remain reserved until positive resolution or explicit operator disposition. Other disjoint work can continue. |
| Retention | Only terminal drained attempts enter age/count history cleanup. Unresolved records are never history; admission refusal bounds outstanding resources instead of evicting them. |

Document index nodes, grants, repair timers, presentation state, and per-window folds die with their document/window scope; stale callbacks hold identifiers rather than large document snapshots. The process-scoped tasker/scheduler supervisor retains bounded outstanding operation records, reconciliation timers, and resource claims after document detach/reload/deletion until confirmed resolution. It has no authority to recreate document state. Process shutdown requests cancellation and reports unresolved outcomes; cross-restart effect replay is forbidden, and this issue does not promise crash-proof process supervision. Superseded jobs release checkpoints. Detached subtrees and dependency records are reclaimed; allocation/GC pressure is measured in the performance corpus. Recovery snapshots have the deletion/cap policy above. Existing tasker body/log artifacts retain their bounded cleanup rules, now excluding unresolved active work. No keystroke event journal is persisted.

`ARCH-SECURE`: buffer text, reloads, provider/tool output, and recovery files are untrusted. Parse before granting authority; malformed data remains visible but cannot manufacture ownership. New process/filesystem tests use isolated stores and synthetic content. `ARCH-FUNERAL`: no background operation or new artifact family is exempt from cleanup/admission rules. `ARCH-PURPOSE`: rendering, ownership, and every live mutation consumer must derive from the coordinator before completion.

## Chunk 2: Implementation milestones and verification

Each M-row below is a real `sdlc milestone-close` boundary, with its own fresh-context review and issue Log entry. M1–M6 remain unchecked until implemented and verified. Each task follows red test → observed failure → implementation → focused green → commit; tests describe independent preservation/ownership/performance invariants, not source-text mirrors. Implement only after operator approval and `sdlc change-code` plan-quality/estimate gates.

### M1 — Reproduce and contain lifecycle failures

**Files:** modify `lua/parley/tasker.lua`, `lua/parley/chat_respond.lua`; create `lua/parley/attempt.lua`, `tests/unit/attempt_spec.lua`, `tests/helpers/fake_process.lua`, `tests/integration/chat_ownership_spec.lua`; extend `tests/unit/tasker_unit_spec.lua`, `tests/integration/tasker_run_spec.lua`, `tests/integration/chat_respond_spec.lua`, `tests/perf/chat_typing.lua`, `tests/perf/harness.lua`; update `atlas/chat/lifecycle.md`, `atlas/traceability.yaml`.

- [x] Promote the audit to durable regression specs for `chat_respond.respond` and tasker, using the function strategies below; no dependency on old `/tmp` artifacts.
- [x] Extract attempt transitions; route tasker ownership/probe/stop/cleanup decisions through them and existing `_uv` seam. Introduce generation/attempt correlation for the current caller without claiming the new document architecture exists yet.
- [x] Contain completion suffix deletion and global cancellation through current lease-guarded narrow operations. Treat these as migration prerequisites with tests, not the final ownership proof.
- [x] Capture baseline work/timing for representative typing, newline, structural edit, fold maintenance, and concurrent stream. Extend counters for nodes/dependencies/anchors/folds and record environment and scaling summary in issue Log.
- [x] Run mapped lifecycle and exchange suites, update atlas/traceability, commit, then close M1 with actual command/results evidence. No concurrency-enabled claim at this boundary.

### M2 — Build the incremental structural core

**Files:** create `lua/parley/document/sequence.lua`, `grammar.lua`, `structure.lua`, `tests/unit/document_sequence_spec.lua`, `document_grammar_spec.lua`, `document_structure_spec.lua`; modify `lua/parley/highlight_structure.lua`, `fence.lua`, `answer_structure.lua`, `chat_parser.lua`, `line_reader.lua`; add `tests/fixtures/document_edits.lua`; update `atlas/chat/parsing.md`, `atlas/traceability.yaml`.

- [ ] Implement `sequence.splice`, `sequence.rank`, and `sequence.query` against their reference-model and work-count contracts below.
- [ ] Extract pure grammar ownership with complete checkpoint state and backward/negative lookahead dependencies; preserve existing distinct fence rules, reasoning, annotations, prefaces, headerless chats, and footer/draft behavior.
- [ ] Implement `structure.repair_step` returning continuation/deltas and `structure.publish` validating local provenance, using the differential/golden strategy below.
- [ ] Implement `grammar.restart_origin` and dependency-certificate validation; drive their adversarial sequence strategy before integrating the scheduler.
- [ ] Gate the structural functions against the declared workload envelope through the shared instrumented harness.
- [ ] Run mapped parsing/highlights/exchange suites plus new mapped document suite; update atlas/traceability, commit, close M2. The new core must be usable in isolation; live authority migration follows M3.

### M3 — Own document edits and migrate live structure consumers

**Files:** create `lua/parley/document/state.lua`, `init.lua`, `editor.lua`, `tests/unit/document_state_spec.lua`, `tests/helpers/fake_document_editor.lua`, `tests/integration/document_edit_spec.lua`; modify `lua/parley/buffer_edit.lua`, `highlighter.lua`, `exchange_model.lua`, `exchange_anchors.lua`, `fold_projection.lua`, `tool_folds.lua`, `outline.lua`, `buffer_lifecycle.lua`; extend `tests/integration/highlight_typing_spec.lua`, `tool_folds_spec.lua`, `stream_view_spec.lua`, `tests/arch/buffer_mutation_spec.lua`, `performance_line_reader_spec.lua`; update `atlas/chat/exchange_model.md`, `atlas/chat/parsing.md`, `atlas/ui/highlights.md`, `TOOLING.md`, `atlas/traceability.yaml`.

- [ ] Implement `state.transition` and `state.resolve` with private ownership, read-only query results, immediate grant invalidation, and the preservation/provenance strategies below.
- [ ] Implement `editor.observe` and `editor.apply` with a stateful double and real Neovim conformance; no writes occur inside forbidden callback contexts.
- [ ] Attach one index per chat and move highlighting to its viewport queries. Remove independent full-array/spontaneous full-rebuild cache ownership; replace tests that require 2N copying with bounded-work invariants. Conservative styling while unresolved must not blank unaffected text.
- [ ] Prove the fold update strategy with attached UI, then migrate folds/layout/outline to confirmed IDs and local deltas. Preserve view/open state; remove all-anchor validation and per-chunk full-parse recovery. Keep full document parsing only for explicit materialization/oracle uses.
- [ ] Enumerate current structural consumers and make adapters delegate to the new source; architecture tests prohibit mutable live models and redraw-time parsing. No dual authoritative cache may survive the boundary.
- [ ] Run document, highlights, exchange, and lifecycle mapped suites plus `make perf`; update atlas/tooling with the new bounds, commit, close M3.

### M4 — Route every generation write through scoped authority

**Files:** create `lua/parley/generation.lua`, `generation_runner.lua`, `tests/unit/generation_spec.lua`, `tests/integration/generation_sequences_spec.lua`; modify `lua/parley/chat_respond.lua`, `dispatcher.lua`, `tool_loop.lua`, `chat_pending.lua`, `chat_lease.lua`, `chat_history.lua`, `init.lua`, `highlighter.lua`, `exchange_clipboard.lua`, `skills/review/init.lua`; extend `tests/integration/create_handler_spec.lua`, `chat_ownership_spec.lua`, `chat_pending_spec.lua`, `tests/unit/chat_history_spec.lua`; add `tests/arch/document_ownership_spec.lua`; update `atlas/chat/lifecycle.md`, `atlas/chat/response_progress.md`, user help/README where behavior changes, `atlas/traceability.yaml`.

- [ ] Extract generation transitions/runner, acquire before provider readiness/reference preparation, and freeze input dependencies. Stale preparation callbacks cannot act on a new buffer/generation. Keep presentation reducer subordinate to this lifecycle.
- [ ] Convert dispatcher stream assembly to position-free output intents; route text/tool blocks/topic/header/completion/failure cleanup through document operations. Reserve a tool round as all call blocks followed by ordered result slots; assign stable child operation/block IDs before dispatch. Support concurrent disjoint generations and delegated child-slot writes through the production coordinator using controllable async producers. M4 does not claim built-in tool effects run concurrently yet; their production async execution/resource/outcome boundary is M6. Delete naked index/range authority and tool-loop live-model registry after caller migration.
- [ ] Sweep all chat mutation entry points: response/regeneration, tool append/cancel repair, auto-topic, reference repair, definition/drill-in transforms, marker insertion, cut/paste/prune/branch/move/delete. Explicit user operations get validated document transactions; out-of-band edits are still observed as external. Scratch buffers are explicitly classified outside this boundary.
- [ ] Enforce `editor.can_join_undo` and mutation receipts through the real editor-history strategy below.
- [ ] Drive `generation_runner.dispatch` through the deterministic scheduling strategy below, then repeat via actual asynchronous builtin dispatch at M6.
- [ ] Remove obsolete pending controls only when their safety purpose is covered; document that editing active output cancels writing. Run mapped lifecycle/ownership/highlights/exchange/provider-tool suites, `make perf`, update atlas/traceability, commit, close M4.

### M5 — Batch selection and recoverable replacement

**Files:** create `lua/parley/batch.lua`, `answer_recovery.lua`, `tests/unit/batch_spec.lua`, `tests/integration/answer_recovery_spec.lua`, `batch_respond_spec.lua`; modify `lua/parley/chat_respond.lua`, `generation_runner.lua`, `init.lua`, `keybinding_registry.lua`; update `atlas/chat/lifecycle.md`, `atlas/index.md`, user help, `atlas/traceability.yaml`.

- [ ] Implement `answer_recovery.publish`, `resolve`, `restore`, and `cleanup` against the fault/recovery strategies below. Make snapshot confirmation a precondition of destructive answer replacement.
- [ ] Replace recursive ordinal batching with fixed IDs/revisions and explicit progress. Single and batch calls use the same generation runner, never current-buffer/window or global cursor configuration as authority.
- [ ] Validate `batch.transition` and `batch.validate_next` against the fixed-membership/revision strategies below.
- [ ] Run mapped batch/recovery/lifecycle suites and production sequence integration, update atlas/help, commit, close M5.

### M6 — Tool outcomes and final enforcement

**Files:** create `lua/parley/tools/operation.lua`, `filesystem.lua`, `resources.lua`, `scheduler.lua`, `tests/unit/tool_operation_spec.lua`, `tool_resources_spec.lua`, `tests/helpers/fake_tool_filesystem.lua`, `tests/integration/tool_effect_sequences_spec.lua`, `concurrent_tools_spec.lua`; modify `lua/parley/tools/dispatcher.lua`, `backup.lua`, `wire_anthropic.lua`, `wire_openai.lua`, `types.lua`, all twelve registered files under `lua/parley/tools/builtin/`, `lua/parley/tool_loop.lua`, `generation_runner.lua`, `defaults.lua`; extend `tests/unit/tools_dispatcher_spec.lua`, `tools_builtin_propose_edits_spec.lua`, `tests/integration/openai_tool_loop_spec.lua`, `tests/arch/document_ownership_spec.lua`; update `atlas/providers/tool_use.md`, `atlas/providers/architecture.md`, `atlas/traceability.yaml`, `workshop/lessons.md` for actual review findings.

- [ ] Add callback-based tool dispatch, explicit cancellation handles, async builtin IO/commands, and a fair scheduler backed by pure resource admission. Preserve provider declaration indexes and normalize ordered call/result slots. Replace global cwd switching with explicit paths/cwd. Use the scheduler conformance strategy below to establish real overlap and responsiveness.
- [ ] Implement process-scoped `tasker.reconcile_step` scheduling for cancelled/missing/unknown attempts: capped backoff for at most five seconds, then a visible unresolved diagnostic with no busy polling. Keep exit/drain and resource admission reserved until positive resolution; teardown/reload cannot erase this state. Enforce the declared process/document/generation admission caps before launches and release reconciliation timers on resolution or the diagnostic transition. Use an injected clock and the stateful process seam to verify bounded retries, delayed exit/drain, failed signals, detached documents, cap refusal, disjoint progress, and no retained polling timer after the deadline.
- [ ] Enforce the generation's selected capability snapshot, concurrent round join, resource admission, and scoped tool-call ledger before effect execution. Verify `operation.transition` and `dispatcher.execute_async` using their authority/effect strategies below.
- [ ] Route backup/open/write/flush/close through checked filesystem outcomes; exercise stateful partial failures across each write/edit/proposal consumer. Do not report success before checked completion or repeat an unknown effect automatically.
- [ ] Sweep lifetime/authority bypasses and add architecture enforcement, including direct transcript API calls through command strings and mutable tables returned from public APIs. Verify all production callers use the final boundaries.
- [ ] Run all focused mappings, `make test`, `make lint`, and `make perf PERF_OUTPUT=/tmp/parley-254-final-perf.json`. Compare attached-UI and deterministic work reports to M1 baseline; record measured limits and retained risks. Full suite runs once per checkout at a time.
- [ ] Update atlas indexes/traceability and referencing project files discovered by SDLC, commit, close M6 with evidence. Then issue-close with the binary's mandatory review and measured actuals; publish through `sdlc pr`/`sdlc merge` only when the implementation is complete.

### Function-level test strategies (PQ-1)

Names below define the intended module APIs; new symbols enter at their owning
milestone. Each strategy applies to the adversarial class, with concrete cases
living in executable specs. Behavioral policies remain in Chunk 1.

| Milestone / function | Strategy and mechanical guard |
|---|---|
| M1 `attempt.transition` | Generate reordered lifecycle evidence; assert terminal delivery and resource release require independently stated completion evidence. |
| M1 `attempt.can_deliver_terminal` | Enumerate observation combinations against the exit/drain oracle, including confirmed no-process launch failure. |
| M1 `tasker.run` | Stateful process/pipe schedules with reentrant terminal callbacks; assert once-only delivery and admission release by attempt identity. |
| M1 `tasker.is_busy` | Fault-injected process observations; unresolved admission remains busy regardless of probe uncertainty. |
| M1 `tasker.cleanup_stale_handles` | Adversarial observation histories; cleanup cannot infer terminal state from absent/failed probes. |
| M1 `tasker.stop_owner` | Multi-owner process schedules; only named attempts receive cancellation and unresolved ownership survives. |
| M1 `tasker.cleanup_old_queries` | Generated age/count pressure over lifecycle states; only privately confirmed terminal records are eligible. |
| M1 `tasker.get_active_query_by_buf` | Mixed active/history records with timestamp ties; compare to active-only creation-order reference. |
| M1 `chat_respond.respond` | Real response flow with controlled edits/completion; assert independently authored text is preserved and cancellation stays scoped. |
| M2 `sequence.splice` | Seeded arbitrary text-range changes against flat sequence reference; assert metadata/size equality and bounded copy work. |
| M2 `sequence.rank` | Random tree shape/provenance histories; compare positions and live-root membership to independent flattened reference. |
| M2 `sequence.query` | Adversarial region queries over opaque and confirmed spans; assert exact intersections with bounded visits. |
| M2 `grammar.advance` | Fuzz malformed syntax and supported dialects; compare golden semantic expectations and pre-migration full parser. |
| M2 `grammar.restart_origin` | Generated backward/negative dependency changes; compare earliest affected origin to exhaustive dependency oracle under visit budgets. |
| M2 `structure.repair_step` | Seeded syntax/edit sequences; settled result matches reference semantics and every continuation respects work bounds. |
| M2 `structure.publish` | Interleave local and unrelated changes with repair; provenance oracle rejects stale effects without starving disjoint work. |
| M3 `state.transition` | Generate edits and owner events; assert text preservation, exclusive grants, and monotonic revocation after every transition. |
| M3 `state.resolve` | Random deletion/move/reinsertion provenance histories; current-root identity oracle forbids stale or ordinal substitution. |
| M3 `editor.observe` | Real Neovim event traces compared with stateful double; normalized byte edits reconstruct actual buffer coordinates. |
| M3 `editor.apply` | Inject reentrant mutations and partial failures; receipts reflect only observed edits and remaining patches lose authority. |
| M3 `editor.can_join_undo` | Real editor-history sequences with mixed writers; undo grouping never absorbs another owner's changes. |
| M3 `highlighter._compute_window_decorations` | Viewport/long-line/unresolved-region corpus; independent styling oracle plus bounded read/byte counters. |
| M3 `fold_projection.project` | Generated confirmed block structures; compare desired intervals to independent semantic ownership oracle. |
| M3 `tool_folds.reconcile` | Attached-UI structural edit sequences; assert actual fold/view state and measure native affected-range work. |
| M4 `generation.transition` | Model-based multi-owner event schedules; independent lifecycle/grant invariants prohibit stale writes and orphaned effects. |
| M4 `generation_runner.dispatch` | Production runner with stateful editor/provider/process scheduler; assert preservation, disjoint progress, and bounded queues per event. |
| M4 `dispatcher.create_handler` | Arbitrarily fragmented byte streams; assembler output equals original text while owning no document coordinates. |
| M4 `generation.reserve_round` | Permuted declaration/completion histories; stable call/result identity order is independent of completion timing. |
| M5 `batch.transition` | Generated selection/progress histories; immutable membership and completed-progress preservation are independent invariants. |
| M5 `batch.validate_next` | Adversarial revision dependencies; reference snapshot comparison pauses every conflicting advance. |
| M5 `answer_recovery.publish` | Stateful filesystem fault schedules; replacement authority requires confirmed immutable snapshot publication. |
| M5 `answer_recovery.resolve` | Mutated persisted association evidence; only a unique exact target resolves, otherwise inspection/explicit selection remains available. |
| M5 `answer_recovery.restore` | Concurrent edit/failure schedules; fresh target evidence prevents restoration over human changes. |
| M5 `answer_recovery.cleanup` | Generated save/retention/failure histories; needed snapshots remain recoverable and caps account for failed deletion. |
| M6 `tasker.reconcile_step` | Deterministic clock/process schedules; bounded probes and timers, visible unresolved evidence, retained admission, and independent progress after cancellation/detach. |
| M6 `tasker.run` admission | Generated cross-document owner launches at each configured limit; count admitted attempts/effects and prove unresolved records cannot be evicted to admit more work. |
| M6 `operation.transition` | Capability/call/effect event sequences; independently assert no unauthorized effect, replay of uncertainty, or fabricated success. |
| M6 `resources.admit` | Random overlapping multi-resource claims; serial reference proves exclusivity, atomic admission, and fair bounded queues. |
| M6 `resources.release` | Unknown/resolved effect histories; only confirmed resolution frees conflicting claims. |
| M6 `dispatcher.execute_async` | Stateful tool effects plus result-processing failures; execution authority and honest effect evidence survive presentation failure. |
| M6 `scheduler.pump` | Controlled async completions plus disposable real subprocesses; overlap/liveness oracle and bounded admission counters prove responsiveness. |
| M6 `filesystem.write_checked` | Stateful partial-IO failures; bytes/evidence oracle forbids success before checked completion. |
| M6 `filesystem.backup_checked` | Faults at publication boundaries; destructive writes are forbidden without confirmed backup evidence. |
| M6 `wire_anthropic.decode_tool_calls_from_stream` | Permuted indexed protocol fragments; declared-index reference preserves call order and identity. |
| M6 `wire_openai.decode_tool_calls_from_stream` | Permuted indexed protocol fragments; declared-index reference preserves call order and identity. |

### Verification command contract

Existing commands verified from `TOOLING.md`/`atlas/traceability.yaml`: `make test-spec SPEC=chat/lifecycle`, `make test-spec SPEC=chat/parsing`, `make test-spec SPEC=chat/exchange_model`, `make test-spec SPEC=ui/highlights`, and `make perf`. New tests must be registered in `atlas/traceability.yaml` under `chat/document`, `chat/ownership`, `chat/batch`, and `providers/tool_use` before invoking those mappings; first confirm each mapping lists the intended tests using `scripts/spec_test_map.sh list-tests <key>`. A missing mapping is not a successful test run.

Pure tests use independent reference models, golden grammar examples, and seeded event sequences. Integration uses stateful doubles with deterministic queue/probe/effect ordering plus real isolated Neovim. Rendering work gates cover reads, bytes, copied entries, nodes/dependencies visited, anchors resolved, folds visited, and scheduled-slice work. Timing is evidence, not a flaky pass/fail oracle. Production network access and real user chats are unnecessary for ownership acceptance; real process/pipe/filesystem conformance uses disposable resources.

### Approval and sequencing

The operator reviews the design, especially identity recovery, conservative rendering during uncertainty, native undo policy, and recovery storage. A fresh-context spec/plan review runs before presenting the final proposal. After approval, `sdlc change-code` owns branching, plan-quality review, and only then estimation. Keep the current unrelated user changes outside issue/plan commits. Every milestone updates its atlas and logs its boundary verdict; no final sweep substitutes for those boundaries.

## Revisions

### 2026-09-14 — Initial proposal

Reason: operator authorized claiming #254 and substantial design/planning. Delta:
specified buffer-authoritative identity reconciliation, dependency-aware incremental
structure, bounded rendering, scoped generation/attempt/tool/batch lifecycles,
recovery policy, and six implementation/review boundaries. Scope clarification:
human edits and generation share one live buffer; reload invalidates writes.

### 2026-09-14 — Concurrent child operations are required

Reason: the operator clarified that the core must support concurrent tool calls
and several background operations editing disjoint exchange regions in one
buffer. Delta: replaced the one-generation-per-document assumption with bounded
multiple generations, delegated exclusive leaf grants, ordered concurrent tool
slots, scoped cancellation/resource admission, and production sequence tests.
Review also requires local-provenance repair validation to avoid starvation from
unrelated streams, explicit negative-dependency indexing, and resumable long-line
analysis.

### 2026-09-14 — Fresh-context review approved

Reason: review found lifecycle and recovery gaps in the first draft. Delta:
retained unresolved effects in a process-scoped supervisor after document teardown,
added durable recovery association/publication evidence, enumerated paused/stopping
and pre-effect cancellation states, and separated M4 coordinator concurrency from
M6 actual asynchronous tool execution. The fold probe selected native manual-fold
deltas and an explicit broad-edit cost/overload policy. Both design and
implementation-plan chunks received Approved on the second review. This is plan
review evidence, not proof of implementation or operator approval.

### 2026-09-14 — Operator approval

Reason: operator said “looks good. let's go. plan review next?” Delta: the design
is approved for SDLC plan-quality review and implementation; previous pending
approval statements record the earlier stage. Estimate remains deferred until
the gate accepts.

### 2026-09-14 — Plan-quality PQ-1 refinement

Reason: the SDLC judge required named risky functions and concise strategy lines,
rather than prose case inventories. Delta: compressed test instructions across
all six milestones and added the function-to-strategy table with independent
oracles/work guards. Behavioral contracts and scope are unchanged.

### 2026-09-14 — Implementation and final handoff authorization

Reason: plan-quality accepted and the operator explicitly requested uninterrupted
implementation through #254. Delta: update current status; execute all approved
milestone gates without further confirmation, prepare final branch/PR for operator
live testing, and defer merge until that testing is approved. This refines the
final M6 publication instruction; it does not reduce implementation or review scope.

### 2026-09-14 — M1 implementation and verification evidence

Reason: containment regressions, process lifecycle, performance coverage and
mapped verification now pass. Delta: record M1 task completion pending its
automatic milestone verdict; issue M1 boundary remains owned by sdlc. Added
production-path fold/stream baseline fixtures and migrated the progress admission
fixture to the private owner gate. No future milestone is marked complete.

### 2026-09-14 — M1 review BR-2: assign deferred supervision to M6

Reason: M1 deliberately retains unresolved attempts without a polling scheduler,
but the remaining checklist did not explicitly own delivery of the promised
reconciliation policy. Delta: M6 now explicitly implements process-scoped bounded
reconciliation, visible unresolved diagnostics, global/document/generation
admission enforcement, timer cleanup, and deterministic clock/process tests. The
five-second operating envelope remains unchanged. M1 supplies safe retention; M6
supplies bounded operational supervision (ARCH-CONSTRAINTS, ARCH-FUNERAL).

### 2026-09-15 — M2 structural core refinements

Reason: implementation and differential tests exposed distinct grammar scopes,
and work-count tests distinguish text authority from syntactic evidence.
Delta: share lexical ownership in `document/lexical.lua`; keep global and
answer-scoped semantic transitions separate. Factor bounded reading, indexed
facts, dependency intervals, and semantic scheduling into `lexer.lua`, `facts.lua`,
`dependencies.lua`, and `semantic.lua`, composed by `structure.lua` (ARCH-DRY,
ARCH-PURE). `dependencies.restart_origin` owns the planned restart query rather
than expanding the grammar transition module with interval storage.

A classified same-row edit can retain syntax evidence only when its complete
lexical descriptor and indexed summary match. Its text revision always advances;
syntax certificates require explicit validation and cannot authorize text writes.
Unknown lexical edits use conservative sliced repair. Ordinary Enter/range-edit
integration still needs the M3 bounded invalidation path; the M2 direct-index
splice measurement is not evidence of final live semantic convergence.

Dependency queries use logarithmic interval navigation whose handle ranks each
require logarithmic sequence navigation: total navigation is O(log² N), measured
without suffix enumeration. On the 50,000-row pure-core corpus, EOF dependency
query plus suffix removal used 58 dependency visits and 310 sequence-node visits.
Typed-row update plus syntax-proof validation used 56 sequence visits and 128
copied leaf entries. Million-row opaque paste/removal used 89 visits and 129
copies. An 800,000-byte line was classified in 196 reads of at most 4096 bytes,
retaining bounded lexer state; its total work is intentionally proportional to
payload size. These isolate index operations; M3 owns attached-editor timing,
fold preservation, and foreground acceptance.

### 2026-09-15 — M2 newline audit: selective facts and fragment convergence

Reason: same-row syntax preservation alone does not prevent broad semantic
repair on ordinary Enter/Backspace. Delta: complete the pure-core solution in M2,
before live migration, with selector-specific fact evidence and bounded fragment
transfer. Fixed predicate channels summarize matching-token counts and maximum
syntax revisions without hashes. Stable fact bounds permit irrelevant row-count
changes; adjacency facts remain explicit. Footer search and its previous-nonblank
lookup keep separate trigger ranges. The interval index retains semantic restart
origins separately from those trigger starts, under explicit visit budgets.

A classified fragment can reuse untouched suffix metadata only after its complete
global and answer-section outgoing checkpoints agree with the previous state and
relevant facts remain valid. Text evidence always expires and inserted rows receive
fresh identities. Unknown/oversized fragments and semantic changes retain the
conservative sliced path. This refines the existing complete-checkpoint convergence
contract; it adds no external concurrency or persistence scope (ARCH-PURPOSE).
