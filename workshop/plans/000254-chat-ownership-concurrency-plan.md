# Chat Ownership and Incremental Structure Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve arbitrary human buffer edits while an answer is generated into another region of that buffer, with bounded interactive rendering work and explicit ownership through cancellation and tool effects.

**Architecture:** Neovim owns text. One document coordinator owns an incrementally maintained structural index, regional revisions, and revocable generation write grants. Pure document/generation/attempt/tool/batch transitions decide effects; thin editor and process adapters execute them and return observed outcomes. Rendering queries confirmed index regions without parsing.

**Tech Stack:** Lua, Neovim 0.11 buffer callbacks/extmarks, libuv, Plenary, existing LineReader/performance harness.

**Status:** Operator-approved; plan-quality accepted and implementation underway. The operator will live-test before merge. Issue: `workshop/issues/000254-chat-ownership-concurrency.md`.

**Current M3 inventory:** The original proposed module/function tables below are
preserved as planning history. Their M3 entries are superseded by the complete
inventory in **Revisions → 2026-09-15 — M3 review inventory correction (BR-7)**.

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

- [x] Implement `sequence.splice`, `sequence.rank`, and `sequence.query` against their reference-model and work-count contracts below.
- [x] Extract pure grammar ownership with complete checkpoint state and backward/negative lookahead dependencies; preserve existing distinct fence rules, reasoning, annotations, prefaces, headerless chats, and footer/draft behavior.
- [x] Implement `structure.repair_step` returning continuation/deltas and `structure.publish` validating local provenance, using the differential/golden strategy below.
- [x] Implement `grammar.restart_origin` and dependency-certificate validation; drive their adversarial sequence strategy before integrating the scheduler.
- [x] Gate the structural functions against the declared workload envelope through the shared instrumented harness.
- [x] Run mapped parsing/highlights/exchange suites plus new mapped document suite; update atlas/traceability, commit, close M2. The new core must be usable in isolation; live authority migration follows M3.

### M3 — Own document edits and migrate live structure consumers

**Files:** create `lua/parley/document/state.lua`, `init.lua`, `editor.lua`, `tests/unit/document_state_spec.lua`, `tests/helpers/fake_document_editor.lua`, `tests/integration/document_edit_spec.lua`; modify `lua/parley/buffer_edit.lua`, `highlighter.lua`, `exchange_model.lua`, `exchange_anchors.lua`, `fold_projection.lua`, `tool_folds.lua`, `outline.lua`, `buffer_lifecycle.lua`; extend `tests/integration/highlight_typing_spec.lua`, `tool_folds_spec.lua`, `stream_view_spec.lua`, `tests/arch/buffer_mutation_spec.lua`, `performance_line_reader_spec.lua`; update `atlas/chat/exchange_model.md`, `atlas/chat/parsing.md`, `atlas/ui/highlights.md`, `TOOLING.md`, `atlas/traceability.yaml`.

- [x] Implement `state.transition` and `state.resolve` with private ownership, read-only query results, immediate grant invalidation, and the preservation/provenance strategies below.
- [x] Implement `editor.observe` and `editor.apply` with a stateful double and real Neovim conformance; no writes occur inside forbidden callback contexts.
- [x] Attach one index per chat and move highlighting to its viewport queries. Remove independent full-array/spontaneous full-rebuild cache ownership; replace tests that require 2N copying with bounded-work invariants. Conservative styling while unresolved must not blank unaffected text.
- [x] Prove the fold update strategy with attached UI, then migrate folds/layout/outline to confirmed IDs and local deltas. Preserve view/open state; remove all-anchor validation and per-chunk full-parse recovery. Keep full document parsing only for explicit materialization/oracle uses.
- [x] Enumerate current structural consumers and make adapters delegate to the new source; architecture tests prohibit mutable live models and redraw-time parsing. No dual authoritative cache may survive the boundary.
- [x] Run document, highlights, exchange, and lifecycle mapped suites plus `make perf`; update atlas/tooling with the new bounds, commit, close M3.

### M4 — Route every generation write through scoped authority

**Files:** create `lua/parley/generation.lua`, `generation_runner.lua`, `tests/unit/generation_spec.lua`, `tests/integration/generation_sequences_spec.lua`; modify `lua/parley/chat_respond.lua`, `dispatcher.lua`, `tool_loop.lua`, `chat_pending.lua`, `chat_lease.lua`, `chat_history.lua`, `init.lua`, `highlighter.lua`, `exchange_clipboard.lua`, `skills/review/init.lua`; extend `tests/integration/create_handler_spec.lua`, `chat_ownership_spec.lua`, `chat_pending_spec.lua`, `tests/unit/chat_history_spec.lua`; add `tests/arch/document_ownership_spec.lua`; update `atlas/chat/lifecycle.md`, `atlas/chat/response_progress.md`, user help/README where behavior changes, `atlas/traceability.yaml`.

- [x] Extract generation transitions/runner, acquire before provider readiness/reference preparation, and freeze input dependencies. Stale preparation callbacks cannot act on a new buffer/generation. Keep presentation reducer subordinate to this lifecycle.
- [x] Convert dispatcher stream assembly to position-free output intents; route text/tool blocks/topic/header/completion/failure cleanup through document operations. Reserve a tool round as all call blocks followed by ordered result slots; assign stable child operation/block IDs before dispatch. Support concurrent disjoint generations and delegated child-slot writes through the production coordinator using controllable async producers. M4 does not claim built-in tool effects run concurrently yet; their production async execution/resource/outcome boundary is M6. Delete naked index/range authority and tool-loop live-model registry after caller migration.
- [x] Sweep all chat mutation entry points: response/regeneration, tool append/cancel repair, auto-topic, reference repair, definition/drill-in transforms, marker insertion, cut/paste/prune/branch/move/delete. Explicit user operations get validated document transactions; out-of-band edits are still observed as external. Scratch buffers are explicitly classified outside this boundary.
- [x] Enforce `editor.can_join_undo` and mutation receipts through the real editor-history strategy below.
- [x] Drive `generation_runner.dispatch` through the deterministic scheduling strategy below, then repeat via actual asynchronous builtin dispatch at M6.
- [x] Remove obsolete pending controls only when their safety purpose is covered; document that editing active output cancels writing. Run mapped lifecycle/ownership/highlights/exchange/provider-tool suites, `make perf`, update atlas/traceability, commit, close M4.

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

### 2026-09-15 — M2 allocation and read-lifetime findings

Reason: allocation and interleaving probes exposed costs not visible in leaf
visit counts. Delta: replace all operation-local sequence traversal closures with
module-level workers carrying explicit state. Under hot LuaJIT, the original
50,000-row deletion retained approximately 90 MB through a captured leaf array;
the fixed probe retains 2.2–2.4 MB without disabling/flushing JIT. A fresh-process
regression defends this lifecycle (ARCH-FUNERAL). Forced GC time remains separate
from foreground detach work; no constant-time reclamation claim is made.

Refresh unread byte requests when a disjoint edit moves their source, while
validating an already-read response against its original frame and local source
evidence. Query semantic certainty once per viewport range rather than repeating
rank and deep-copy work per row. Real Neovim reader tests cover bounded UTF-8
chunks and its final empty-row separator convention.

### 2026-09-15 — M2 verification before boundary review

The complete document mapping passes 127 tests, including fresh-process JIT
reclamation, selective facts, bounded fragment transfer through 50,000 rows,
viewport work, and real-Neovim bounded reads. Existing parsing (239), highlights
(108), and exchange-model (281) mappings pass after shared lexical extraction.
Scoped lint and whitespace checks are clean.

The schema-3 direct-core report has 28 scenarios (one warmup, three measured
samples per scenario). At 50,000 rows, Enter plus join processes three semantic
rows, visits 358 index nodes and two dependency nodes, and copies 175 leaf
entries; median 3.020 ms and observed p95 3.387 ms. Setup/materialization is outside
that window. Across 100/1,000/10,000/50,000 rows the semantic work stays three rows.
These are isolated core measurements, not the M3 attached-editor acceptance.
M2 implementation tasks are verified; its review boundary is pending.

### 2026-09-15 — M2 boundary review: semantic authority and fence parity

Reason: BR-3 demonstrated that unchanged local text does not prove unchanged
semantic context; BR-4 found ordinary-fenced tool markers still terminate
reasoning in the existing answer reducer. Delta: `structure.publish` accepts
lexical-only metadata, rejects every derived-metadata field, preserves newer
semantics for equivalent lexical results, and routes changed classifications
through normal invalidation. Semantic publication remains solely in the worker
that validates context/dependencies (ARCH-PURPOSE). Section reduction now keeps
original structural kind for boundary termination while using fence-suppressed
kind for tool admission. Regressions cover delayed publication after an upstream
role change, each derived metadata family, classification invalidation, and 56
fenced tool/section combinations against the independent legacy reducer.

### 2026-09-15 — M3 native edit and fold integration evidence

Native grouped undo can deliver several logical edits while buffer reads already
show the final undone text. Editor row totals therefore follow callback deltas;
the coordinator accepts bounded callback text only when its byte extent matches,
otherwise retaining opaque evidence until scheduled repair. Whole-buffer deletion
normalizes Neovim's mandatory empty line. Marker bytes replaced with identical
text retire the old row identity; typing after an untouched marker preserves it.

Attached-UI probes establish that native manual folds already move correctly for
interior text growth and retain open/view state during next-question typing, but
survive marker deletion incorrectly. M3 uses native movement for equivalent body
edits and schedules certified section projection for structural changes. Queries
page through the shared index; no all-anchor scan or mutable-layout reparse is
part of the new fold path. Section/outline projection revisions are separate from
lexical proofs; payload-only edits preserve both when every relevant value is
unchanged. Actual consumer migrations and broad suites remain before M3 closure.

### 2026-09-15 — M3 consumer audit and write-plan revision evidence

The live rendering consumers now use the document index. The remaining mutable
`exchange_model` chain is generation writing: `chat_respond` stream-span reduction
and `tool_loop` append positions. Migrating those at M4 together with scoped write
plans avoids an interim second authority and lets M3 establish the read/observer
boundary first. Delta: the M3 architecture check forbids positional re-derivation
in rendering consumers; M4 explicitly removes numeric live writer models and
per-chunk active-answer re-reduction before claiming bounded generation work.
The pure materialized layout remains useful for preparation/serialization/oracles.

The audit also found timezone and footnote diagnostics reading the entire buffer
on edit convergence. This belongs to the requested rendering guarantee. Extend
M3 to shared-index candidate projection and bounded scheduled diagnostic parsing;
ordinary non-candidate edits must not trigger global derivation. Definition
changes have broad reference dependencies (including first-definition boundary
and duplicate-definition resolution), processed in slices. Native diagnostic
namespace publication is inherently O(diagnostic count/output size), accounted
separately from bounded parsing; no silent definition truncation.

Write plans require the grant revision they were built against. Both owned text
writes and disjoint edits that move grant coordinates advance that revision.
A stale plan is rejected without revoking a still-valid writer; subsequent plans
must resolve current coordinates. Regressions cover repeated matching bytes,
disjoint relocation and delegated insertion slots. This is an authority check,
not a document-global changedtick barrier (ARCH-PURPOSE).

### 2026-09-15 — M3 native callback timing and fair scheduling

Reason: native Insert-mode Backspace emits its byte-change callback while reads
can still expose the pre-join rows. Immediate safe invalidation therefore caused
whole-suffix repair debt after an otherwise ordinary join. Delta: keep one bounded
pre-edit fragment proof, splice an opaque extent immediately, and validate actual
new lexical data in a later slice before restoring local semantic confirmation.
Any intervening edit, reload, or detach cancels that proof. Retargeting cannot
admit token channels beyond those conservatively captured (ARCH-ORDER).

A second native regression proved recursive `vim.schedule` callbacks can occupy
one event-loop turn until all work finishes despite per-callback budgets. Add
`lua/parley/deferred_work.lua` as the single coalesced timer owner for document
repair, diagnostics, folds, and outline loading. Each continuation yields to a
new timer turn; cancellation invalidates queued callbacks and closes its timer.
Tests require native timers to fire before multi-slice work completes, and verify
reload/detach cleanup. This closes the scheduling class across live consumers
rather than just the first observed document callback (ARCH-DRY).

### 2026-09-15 — Repair ordering and M4 append preparation

The semantic pass has a dependency-ordered frontier: a later visible region cannot
be confirmed before its incoming fence/role/checkpoint evidence exists. The actual
mechanism therefore uses a global frontier and a scoped answer queue with local
certificates, rather than treating arbitrary dirty spans as independent semantic
jobs. Disjoint edits must retain valid queued reads and completed prefix work;
new coordinator stress tests enforce progress under continuous same-document
edits. Timer fairness applies across documents and consumers. M4 waiter priorities
may advance the lexical/fact demands needed by visible regions and grants, but
cannot bypass predecessor proofs. This refines the queue mechanism in §C while
preserving the non-starvation and conservative-authority requirements.

M4 streaming will use bounded append intents with private incremental lexical
cursors per admitted output slot. The editor already supports zero-width patches;
remove dispatcher growing-line replacement and response active-block reparsing.
An exact mutation receipt commits accepted output even if semantic confirmation
then suspends further writes; queued bytes must never replay that accepted prefix.
Caller-supplied lexical/semantic metadata cannot authorize this optimization.
Fresh slots start an empty scanner; existing tails require one bounded bootstrap,
with local entry proof that survives unrelated neighboring edits. Candidate-rich
long-line diagnostics require explicit work measurement rather than assuming
that bounded per-slice parsing also proves bounded aggregate append work.

### 2026-09-15 — M3 completed verification before review

Reason: native fold batches and starvation regressions now pass with final
consumer integration. Delta: mark M3 implementation tasks verified; its milestone
boundary remains pending the binary-owned review. Document mapping: 245 tests
across the completed prefix and resumed semantic/remainder runs. Two real
50,000-row corpora have scoped 180-second harness deadlines; other tests retain
50 seconds. Full feature benchmark on `ea933f51` passes all 30 schema-4 scenarios
with five warmups and 20 samples. Ordinary typing processes/copies one row;
Enter+join six; viewport redraw no semantic rows; all hot phases have zero full
buffer reads. Timing remains report-only and was collected with concurrent test
load: the 5,000-row stream/human p95 is 52.326 ms. This does not meet the 8 ms
aspiration; M4 still owns removal of the legacy generation model/stream rewrite.

### 2026-09-15 — M3 review inventory correction (BR-7)

Reason: the original proposal names anticipated files/functions that were not the
ones delivered. Delta: the following is the **current M3 inventory**, superseding
the original M3 rows in Core concepts, Integration points, Files, and the
function-level strategy table. The original proposal remains as design history.
No unchanged module is claimed as modified merely because a caller now reuses it.

| Current entity or integration | Actual module(s) | M3 change and ownership |
|---|---|---|
| Ownership transitions and resolution | `document/state.lua` | New private grants, dependency snapshots, lifetime transitions; no editor IO. |
| Buffer coordinator | `document/init.lua` | New composition of index, state, editor, query subscriptions and bounded repair. |
| Native editor boundary | `document/editor.lua` | New native observation, byte-frame normalization, scoped patches, exact receipts and undo separation. |
| Indexed semantic projection | `document/projection.lua` | New aggregate summaries, exchange lookup, fold pagination and projection validation; owns live projected ranges. |
| Existing fold policy | `fold_projection.lua` | Reused unchanged. `is_foldable` supplies policy; `desired_folds` remains the materialized-model oracle. There is no `fold_projection.project`. |
| Materialized layout | `exchange_model.lua` | Documentation-only correction of its scope. Existing pure layout implementation remains for materialization and legacy generation preparation; live rendering no longer treats it as authority. |
| Legacy buffer primitives | `buffer_edit.lua` | Unchanged at M3. Generation and explicit-user mutation migration remains M4; M3 adds the editor boundary that it will use. |
| Live rendering | `highlighter.lua`, `tool_folds.lua`, `outline.lua` | Modified to use coordinator queries; per-consumer authoritative structural caches removed. |
| Live diagnostics | `diagnostic_refresh.lua`, `define.lua`, `skill_render.lua`, `timezone_diagnostics.lua` | Modified to use indexed candidate discovery, bounded derivation and scheduled publication. |
| Fair scheduled work | `deferred_work.lua` | New coalesced timer work lifecycle shared by repair, folds, outline and diagnostics. |
| Teardown | `buffer_lifecycle.lua` | Modified to retire shared document and consumer state. |
| Extmark identity registry | `exchange_anchors.lua` | Deleted; indexed entities supply current identity/location. |
| Materialized parser | `chat_parser.lua` | Comment-only update removing obsolete anchor ownership description; parser remains an explicit materialization/oracle. |
| M2 core integration refinements | `document/sequence.lua`, `dependencies.lua`, `grammar.lua`, `lexical.lua`, `lexer.lua`, `semantic.lua`, `structure.lua` | Modified for bounded navigation, fragment convergence, fair read progress, projection and diagnostic integration. Existing facts implementation is reused unchanged in M3. |

Paths in this table are relative to `lua/parley/`. The complete production change
list was checked against `git diff --name-status 2afd7de9..626e565e -- lua`.

Current function-level verification replaces the corresponding proposed M3 names:

| Function | Verification strategy |
|---|---|
| `state.transition`, `state.resolve` | Seeded edit/ownership histories with independent exclusive-region, preservation and monotonic-revocation invariants. |
| `Editor.observe`, `Editor.apply`, `Editor.can_join_undo` | Native callback/undo histories and stateful fault schedules; compare settled text/semantics and exact partial receipts. |
| `Document.repair_step` | Continuous disjoint edits and source replacement between reads; progress plus byte/row/navigation limits per slice. |
| `projection.exchange`, `projection.folds`, `projection.validate` | Independently derived exchange/fold intervals, paginated queries and stale local proof rejection. |
| `highlighter._compute_window_decorations` | Native viewport, long-line and uncertainty corpus; independent style expectations and bounded reads. |
| `tool_folds.step`, `tool_folds.flush` | Actual native folds across uncertainty, batched clear/recreation, window edits and teardown; open/view state and operation counters. |
| `outline._load_live_items`, `diagnostic_refresh.step` | Indexed live candidate pages, disjoint progress, cancellation and independent final output parity. |
| `deferred_work.new` | Native timer fairness, coalescing, cancellation and no retained polling callback after retirement. |

### 2026-09-15 — M3 review evidence and retirement rules (BR-5, BR-6, BR-8)

Reason: fresh-context review reproduced equal-extent grouped-undo corruption,
stale semantic presentation and retired callback retention. Delta: reopen the
M3 implementation conclusion pending these fixes and verification. Native callback
text may be classified only with evidence that its byte coordinate frame belongs
to that event; equal row/byte extents alone are insufficient. Settled native
undo/redo tests compare token kinds and exchanges to actual buffer text.

Unconfirmed context cannot authorize role, reasoning, fence, footer/draft styling
or semantic folds. Only local lexical presentation and separately proven
unaffected context may survive; fold invalidation is separate from certified
recreation. Tests that required stale styling/folds must be replaced with the
plan's uncertainty invariants, retaining bounded foreground work.

Retirement must break document/editor callback reference cycles and remove all
buffer-owned fold autocmds. Native LuaJIT weak-reference tests verify reclamation,
while externally retained detached handles continue to return detached state.
M4 staging is paused until these M3 findings are resolved (ARCH-ORDER,
ARCH-PURPOSE, ARCH-FUNERAL).

### 2026-09-15 — M4 ephemeral source guards

Reason: a pending explicit-user command must keep its source provenance when the
index materializes opaque metadata without changing buffer text. Stable row
handles alone do not supply that guarantee. Delta: use at most 64 live ephemeral
source-region guards per document, maintained by the existing normalized native
edit observer. Every intersecting native edit permanently invalidates a guard,
including identical replacement and undo/redo. Preceding disjoint edits relocate
its byte endpoints; metadata repair never modifies it.

Opaque tokens retain guards; fixed registry slots hold weak references. Capture
and extension enforce capacity atomically, share existing guards without
refreshing provenance, and release on completion/cancellation/reload/detach.
Abandoned tokens are collectible. Empty insertions bind a containing row and
relative column, conservatively rejecting boundary joins. Guard visits are
counted and bounded by 64 per native edit. No payload cache, row-array index,
source-lineage hierarchy, or persistent edit journal is added (ARCH-PURPOSE,
ARCH-CONSTRAINTS, ARCH-FUNERAL).

Source guards prove unchanged text; they never authorize writes. Explicit user
transactions still emit user receipts without a generation grant. Generated
replacement additionally validates its leaf grant and consumes exact generated
receipts after every bounded slice. Native writes invalidate guards normally;
continuation after an owned patch requires a new checked successor proof rather
than exempting the writer from invalidation. M4 implementation remains paused
while M3 review fixes are verified.

### 2026-09-15 — Isolated M4 preparation resumes during final M3 verification

Reason: the M3 review fixes are integrated and released by their authors; remaining
feature verification and review do not depend on M4 source-guard implementation.
Delta: supersede the temporary M4 staging pause for the bounded source-guard task
only. Staging commits `6cf67e52` and `b6723424` preserve M4 preparation and its M3
review-base merge; 83 focused staging cases pass. The M3 milestone remains open,
and no M4 code enters the feature branch until its review fixes have cleared.

### 2026-09-15 — Reserve tool-round grant capacity before yielding

Reason: reserving ordered tool placeholders takes bounded writes across event
turns, while another generation may acquire grants in between. A free-slot count
is not a reservation. Delta: retain the document's 16-live-grant limit and the
runner's requirement that every declared child receives its grant before dispatch.
Reserve capacity for the whole round before its first output mutation.

The pure ownership state adds generation/round-scoped capacity tickets. Admission
counts live non-revoked grants plus outstanding reserved capacity. Ordinary
proof-checked acquisition atomically consumes its matching ticket only on success;
a ticket never authorizes text or bypasses entity validation. Tickets release
unused capacity on reservation failure/cancellation and generation retirement,
reload or detach. Ticket count is bounded by the same 16-slot budget. Production
rounds exceeding available capacity are refused before placeholder writes or tool
effects, even though the protocol reducer can represent 32 declared calls.

Once admitted, reservation writes still report exact partial progress if a human
edit or native failure interrupts them; no rollback or synthetic success hides
those bytes. Tests interleave competing admission during yielded reservation,
failed acquisition, foreign tickets and retirement (ARCH-ORDER, ARCH-CONSTRAINTS,
ARCH-PURPOSE). This is M4 staging work and does not enter the M3 review window.

### 2026-09-15 — M3 review fixes verified, review retry pending

Reason: native provenance, uncertainty and retirement fixes plus their conformance
tests pass the complete M3 verification mapping. Delta: implementation checks are
again supported by evidence: document263/highlights85/exchange264/lifecycle511,
504-file clean lint, and all30 full benchmark scenarios on `ebd0585b`. The issue
Log records timings and affected native fold costs without an 8 ms latency claim.
M3 closure still belongs to the binary-owned fresh-context review.

### 2026-09-15 — Delayed actions require current eligibility (BR-9)

Reason: the second M3 review addressed BR-5/6/7/8 but reproduced outline navigation
to an unconfirmed, then reclassified, surviving heading handle. Delta: distinguish
location from semantic eligibility at every delayed consumer boundary. A surviving
handle supplies coordinates only; the action must still qualify under its current
projection. No nearby positional substitute stands in for a vanished outline item.

| Consumer/action | Current eligibility boundary |
|---|---|
| Highlighting | Filtered document query supplies confirmed semantic context; unresolved rows retain only neutral/local lexical presentation. |
| Fold recreation | Validate the current paginated fold projection certificate immediately before native operations. Identity lookup for invalidation bounds or open-state hints does not authorize recreation. |
| Outline selection/navigation | Resolve identity for location, then require an exact current outline projection match, including after focus-changing editor callbacks. Reject unavailable/reclassified items; preserve harmless relocation. |
| Diagnostic derivation/publication | Candidate projection establishes eligibility. Retire in-flight derivation on candidate-text **or semantic-context** changes, including changes while a bounded read or final publication is pending. Membership lookup only relocates an otherwise valid derivation. |

The diagnostics sweep reproduced a pending publication that survived a preceding
text-to-fence edit because its lexical diagnostic-candidate flags were unchanged.
It now retires on semantic-context changes as well. Native regressions cover
pending reads, pending publication and unaffected text edits. Existing published
diagnostics are the last computed diagnostic snapshot during typing; they do not
authorize outline navigation or writes. Fresh publication awaits confirmed context.
Native outline tests cover uncertainty, reclassification, deletion, harmless
relocation and stale tree entries (ARCH-ORDER, ARCH-PURPOSE).


### 2026-09-15 — Publication ownership across reentrant effects (BR-10)

Reason: DiagnosticChanged edits and fold OptionSet edits expose the same lost
invalidation pattern after native effects return. Delta: a consumer captures its
job/projection and validates ownership after every callback-capable effect before
performing subsequent effects or committing completion. Newer invalidation always
wins; clearing, replacement refresh, reload and detach are ownership transitions.

| Consumer | Callback boundary and completion rule |
|---|---|
| Diagnostics | `vim.diagnostic.set/reset` invokes DiagnosticChanged; injected readers and converters can also call out. Check current buffer facade and job after each call. Stop superseded publication, preserve dirty state, and prevent recursive step of the same job. A retired clear cannot clear a replacement refresh. |
| Native folds | Window/option/fold operations and view restoration can invoke operator callbacks. Native slices and cleanup must retain captured-plan ownership; a returning old slice cannot clear dirty work from those callbacks. |
| Outline | Validate current projection after buffer/window focus callbacks immediately before cursor placement. Navigation and its highlight use the captured target; source identity alone is insufficient. |
| Highlights | Redraw decoration runs under native textlock; semantic reads require current confirmed document metadata. Any cache completion around view callbacks must commit only its captured current cache work. |

Native regressions cover publication edits at both diagnostic-set boundaries,
reload, detach, recursive publication, replacement refresh during clear, and fold
restoration edits. Work accounting records effects actually performed, including
partial publication interrupted by callbacks (ARCH-ORDER, ARCH-PURPOSE).

### 2026-09-15 — Fold cleanup and aborted configuration (BR-11/BR-12)

Reason: fourth review found that returning stale work could leave temporary fold
preferences/view changed, or treat a partially built empty window list as complete.
Delta: separate captured-window cleanup from publication ownership. Build window
plans locally, publish only after successful configuration, discard only expected
jobs, and restore every captured window even when cleanup reenters or one window
fails. Done phases cannot re-enter creation, and setup interruption schedules
surviving windows. Four new native controls fail on the prior implementation;
eight reentrancy tests plus 35 existing fold/batch/retention/join cases pass.

The review returned FIX-THEN-SHIP, but the ledger left BR-11/BR-12 open and
explicitly refused milestone finalization. The binary's next-action instruction
requires a further review to dispose those open findings; extend the per-boundary
round budget to five for that disposal rather than waive the ledger. This extra
review is required by the refused transition, not a second discretionary review.

### 2026-09-15 — Codex M3 review: suspended cleanup ownership

The Codex boundary review disposed BR-12 but retained BR-11. The preceding cleanup
claim was incomplete: cancellation inside an already-suspended native fold slice
could restore its temporary disabled value after retirement restored the operator
preference. Retirement must transfer preference-restoration ownership before any
callbacks; returning nested cleanup must not overwrite that completed transfer.
The fix covers apply, uncertainty clearing, and both discard paths, with native
suspended-slice tests for enabled/disabled operator preferences and preserved view.
ARCH-ORDER and ARCH-FUNERAL govern this ordering. All remaining boundary reviews
use Codex per the operator's explicit instruction. No gate is waived.

### 2026-09-15 — M3 final regression mapping sweep

Codex disposed BR-11 and returned FIX-THEN-SHIP with one verification mapping
omission (BR-13). The complete newly-added regression sweep found exactly the two
native retirement specs missing. Both are now registered under chat/document;
mapping output was checked against the added-spec inventory. No runtime changes
follow the reviewed cleanup fix. The close commit includes this correction and
the gate's M3 closure metadata; no redundant boundary review is required.

### 2026-09-15 — M4 finite replacement successor authority

Repeatedly repairing a shrinking opaque row between bounded deletion patches would
make regeneration quadratic. A private finite replacement cursor therefore captures
its immutable payload and initial confirmed leaf grant, then advances authority only
through exact editor receipts. Each armed patch is at most 4096 bytes; no public
apply/append flag or caller lexical metadata can bypass semantic confirmation.
Unexpected source edits, revoked identity, reload, and detach retire the cursor.
Disjoint structural uncertainty pauses it until ordinary authority is confirmed.
Only lexical reads intersecting an actively mutating finite range are deferred;
pause, cancellation, completion, and lifecycle invalidation release that deferral.
Rendering continues to expose those rows as uncertain until genuine repair.

An optional captured retained-prefix length may release the final generated suffix
at successful completion, before semantic reconciliation. It cannot enlarge a grant,
change its entity, or reclaim delegated slots, and never runs after partial failure.
This is release of ownership, not a second source of document facts (ARCH-DRY).

### 2026-09-15 — M4 cancellation-safe annotation replacement geometry

Finite answer replacement must exclude the original bytes of every surviving
annotation from every destructive grant. `response_layout.prepare` derives
half-open byte gaps from the already captured target span: a prefix gap installs
the answer shell, while later gaps remove generated prose and leave newline
separators between preserved annotations. The caller captures all disjoint gap
grants before mutation and refuses preparation if grant capacity is insufficient;
it resolves each gap independently after preceding mutations or disjoint human
edits. A first-offset-only cursor spanning the entire old answer is insufficient.
The question marker, later prefaces, next composer, and footnotes outside the
selected answer remain outside the replacement span. Geometry supplies no write
authority (ARCH-PURPOSE, ARCH-ORDER).

Line-start branch references and private notes retain their exact line text.
Inline branch links retain their original `[🌿:label](path)` bytes on standalone
lines instead of being reformatted as `🌿: path: label`. Both forms parse as the
same branch reference; preserving the original source throughout cancellation
supersedes the old delete-and-reinsert formatting behavior. The existing private
note grammar is single-line: an unmarked continuation line has no private-note
ownership implication. The helper uses canonical LF-terminated row byte offsets,
including the final buffer row; the native editor must normalize canonical EOF
rather than treating it as a physical `set_text` row. Pure provenance tests check
that every original protected byte survives every partial destructive operation,
including repeated identical links and UTF-8 columns.

### 2026-09-15 — M4 preparation uses physical-EOL source capture

`response_preparation.plan` narrows the canonical layout to the target capture's
physical-EOL contract: every final gap excludes its terminating LF, not only at
document EOF, and omits the equivalent final payload LF. Region offsets are
relative to the captured question EOL and are rebased once by source readiness
before atomic multi-grant admission. The prefix grant preserves the question's
newline through `first_offset=1`; a zero-width source first appends an owned
newline before replacement. Existing margins beyond the captured source remain
untouched, even where legacy cleanup would have trimmed them. Preparation uses
one bounded finite cursor at a time and positively retires its timer, subscription,
cursor, and ancillary grants before prepared input can reach the provider.


### 2026-09-15 — M4 admission and transport composition checkpoint

Reason: production migration needs explicit source-to-runner admission, finite
annotation-safe preparation and position-free provider transport. Delta: add
`response_submission` (capture/freeze then same-stack runner acquisition),
`response_target` (bounded confirmed target resolution), `response_layout` (pure
protected-source geometry), `response_preparation` (finite disjoint gap grants),
and `response_provider` (operation-scoped transport callbacks). They compose the
existing document/runner boundaries rather than inventing independent authority.

`Runner.start` acquires primary and ancillary preparation regions atomically;
provider admission refuses until ancillary grants retire. Native successor point
guards belong only to a live private replacement witness; ordinary user insertion
captures still protect the containing source row. Input dependencies distinguish
same-generation output insertion at the question seam from human question edits.
Waiting-target stale evidence enters the reducer before preparation begins.

Provider failure closes admission and drains already-admitted bytes while grants
remain valid, then retires with provider_failed; human revocation/cancellation can
still discard remaining staged bytes. Failed requests do not run success
finalization. Positive transport exit/drain or no-spawn abortion resolves the
operation; cancellation itself is not evidence of cleanup. Scoped readiness uses
captured source validation without restoring an unrelated current cursor.

This is an isolated WIP checkpoint. The legacy `chat_respond` production flow has
NOT yet been replaced and is temporarily incompatible with the new pending UI
API. Module/adapter regressions pass, but no end-to-end M4 completion is claimed.
The next integration wires these adapters, then tool rounds, topic/header grants,
scoped Stop/history, current lifecycle documentation, full mapping and M4 review.

### 2026-09-15 — Public response composition and integration findings

Reason: the old public writer still bypassed the released scoped adapters, and
integration tests expose contracts that component tests alone cannot establish.
Delta: compose source admission, finite preparation, provider/tool effects,
presentation, completion and independent topic ownership through response_session;
respond captures its buffer/config/input once and no callback reparses a live
numeric exchange model. Register sessions solely for explicit current-chat Stop.
Native undo/redo runs directly through document observation, revoking affected
grants without obsolete pending confirmation or synthetic cancellation results.

Request context before the selected question is a frozen input dependency, not a
write-conflict region: preceding stream edits while target repair waits mark it
stale and cannot deny admission of a disjoint answer. Captured trailing footnote
boundaries cap replacement before any IO. Failure notices follow terminal delivery
of already-admitted bytes. Topic header and origin-marker guards are captured
before topic IO; an independent header generation survives normal answer completion
but is cancelled by origin edits or unsuccessful completion (ARCH-ORDER).

Native full-path tests found two further implementation gaps: silent native tick
advances between finite preparation and streaming need explicit owned-mutation
frame evidence; a next-prompt insertion must release the inserted question from
future answer authority instead of extending the old grant across it. Reuse exact
native receipts and finite replacement's narrowing witness; never exempt human
edits or ignore revocation merely because a generation is finalizing
(ARCH-PURPOSE, ARCH-DRY). Preserve the red public/benchmark tests until these fixes
are verified. M4 remains isolated and incomplete pending compatibility sweep,
full mapping/performance, atlas and its boundary review.

### 2026-09-15 — M4 native streaming locality and cancellation receipts

Reason: the production response benchmark exposed global repair on a known short
answer header and on newline appends; a final-receipt callback could cancel and
release cursor state before its caller resumed. Delta: preserve the append source
row extent, restrict dependency lookup to proven old/new lexical channels, and
classify only a private exact final replacement receipt whose complete affected
rows fit 4096 bytes. Opaque/large/intermediate writes remain deferred. Charge
uncached dependency ranks against actual remaining index work, retaining fixed
node/entry limits and the 128-visit cap per dependency operation. Return an already
retired cursor after recording its exact receipt, without accessing released state.
These changes preserve ARCH-CONSTRAINTS and ARCH-FUNERAL rather than increasing
the benchmark timeout or weakening uncertainty handling.

Verification: 128 focused tests across 11 files pass, including independent budget
counters, atomic dependency-removal refusal, native final-callback cancellation,
semantic differential cases, and long UTF-8 replacement read caps. A single
5000-row production interleave sample completes in 57.6 ms, repairs 18 rows, and
performs zero full-buffer reads under the unchanged five-second setup deadline.
This is focused evidence; the full mapped lifecycle/performance report and M4
boundary review remain outstanding. M3's fifth ledger-disposition review runs
against the separate feature checkout; these changes remain staged in the M4
worktree until that boundary closes.

### 2026-09-15 — M4 public-command compatibility and IO lifetime audit

Reason: composition through the real command exposed gaps absent from isolated
adapter tests. Delta: explicit onboarding updates the placeholder model, header,
pending label, and tool limits as one prepared profile while retaining captured
source geometry; subsequent configuration/continuation changes cannot alter it.
Remote reference launches register child lifetimes before IO, stop admission on
failure, and retain unknown launches until positive callbacks arrive. Duplicate
callbacks cannot resolve siblings, and cancelled callbacks cannot publish cache
updates or spawn a provider. Failed utility topic transports reject partial text.

Drill-in gather now computes its result from frozen text and applies local hunks
through one captured user transaction. Intervening edits preserve human text and
stop further response admission; partial already-applied edits are not rolled
back. Message construction returns its system-prefix length so ancestor context
follows zero, one, or two leading messages, and automatic topics receive only the
current-file conversation. Architecture checks reject positional async writes,
current-selection rediscovery, pending-owned content authority, and production
calls to the retired streaming writer. ARCH-PURE and ARCH-FUNERAL shape these
boundaries; no new independent live exchange registry is introduced.

Focused evidence: onboarding/profile/session/tools/remote 34 tests; existing
remote references 11 and topic utility 9; branch/topic ordering 6; native drill-in
interruption 2 and existing public response compatibility 23; architecture 6.
Each targeted regression passed after its observed failure. The ownership
performance mapping now passes all 3 cases at 100/1000/5000 rows. Full performance
report and the combined mapped validation remain in progress; M4 is not closed.

### 2026-09-15 — M4 combined renderer integration and validation checkpoint

Integrated the M3 review fixes into a separate checkout while the feature branch's
fifth boundary review remained pinned. Editor/coordinator M4 receipt handling
already includes the M3 native-frame guards; keep that superset. Fold cleanup
uses the M3 reentrant ownership fixes. Diagnostic publication combines those
fences with M4 completion callbacks, retiring old state before any callback may
create replacement work. Preserve both milestones' revision history and lessons.

The final plan audit corrected Stop to select the captured generation under the
cursor, otherwise a document-local identity picker. StopDocument explicitly
cancels all generations in the chat. Picker callbacks validate the original
document epoch and entry membership; changed focus or retired generations cannot
redirect cancellation. Four native regressions plus six scoped-response cases pass.

The complete M4 staging performance report passed 30 scenarios with 20 samples
each. At 5000 rows, median/p95 milliseconds were: ordinary edit 10.08/11.62,
Enter/join 22.62/24.78, stream+human 54.87/61.47, redraw 0.66/1.41, and fold
maintenance 1.41/1.76. Streaming visited 18 structural rows and made zero full
reads; broad repair remained expensive at 4522/4801 ms cumulative convergence.
The legacy BR10 stream fixture used a different writer, so its timing is not an
identical workload comparison. This report predates the combined renderer merge;
combined mapped tests remain required. Full issue performance validation follows
again at M6. No timing thresholds were loosened.

### 2026-09-15 — M5 implementation seam preparation

Read-only inspection identified the next required revision seam. Existing sequence
text certificates retain scalar aggregates and handle strings, reject edit/undo
ABA through monotonic stamps, and do not retain detached trees. They are the
candidate substrate for batch question/context evidence. User transaction guards
are limited to 64 and intentionally invalidate closed-boundary contact; they must
not be expanded into an unbounded batch membership registry.

Before batch integration, prove a narrow regional text-certificate mode that
ignores outside neighbors while validating inside endpoints and current semantic
bounds. Preserve existing certificate behavior for other consumers. Also prove
that an exact owned newline insertion at the old question EOL can retain its
unchanged source row/text stamp while inserting the suffix; ambiguous/external
receipts cannot request this exemption. A proposed Document capture_revision /
validate_revision seam binds epoch, exchange identity, question/context bounds,
and text proof. Tests must cover predecessor regeneration, external boundary
edits, edit/undo ABA, semantic-boundary changes, >64 selected questions, and token
retention across detach. This is design preparation, not implemented evidence.

Batch admission will replace recursive ordinal/cursor retargeting with fixed
membership and an active-leg token. All terminal/rejected outcomes must reach its
controller, completed progress survives later failures, and explicit resume
revalidates remaining input. Recovery publication remains a prerequisite of the
shared single-response preparation path, so single and batch replacements receive
the same protection. No M5 scope is dropped or marked complete by this note.

### 2026-09-15 — M4 mapped verification and request-refusal correction

The combined tree passes all 131 unique files selected by chat/document,
chat/lifecycle, chat/ownership, chat/exchange_model, ui/highlights, and
providers/tool_use: 1624 tests, zero failures/errors. The missing ownership map
was added explicitly instead of treating an empty mapping as success. Full lint
passes across 556 Lua files. The attachment send-guard test exposed a missing
preparation failure notice; preparation now reports logical failure once while
retaining its independent IO completion barrier. An oversized image request
reports its byte limit and leaves the captured buffer unchanged before dispatch.
The real build-message suite passes all 84 cases, and remote lifetime tests still
pass after that correction. Logs are summarized in
/tmp/parley254-m4-mapped-verification.txt.

M4 implementation tasks are checked; the final combined performance run and SDLC
boundary review remain outstanding. The main feature checkout is still pinned
for the M3 ledger-disposition review. No milestone or issue is marked closed by
this checkpoint, and no merge to main is authorized before operator live testing.

### 2026-09-15 — M4 final boundary evidence

M3 closed at506d2c34; its final suspended-fold fix is integrated at0eb73979.
All M4 added specs were swept against traceability:13 ownership regressions were
missing and are now registered. Final unique verification covers146 files and
1700 tests, zero latest failures/errors/incomplete files. Final-head document
verification is31files/285tests and ownership25files/211tests; unchanged mappings
retain their earlier evidence. Full lint558files is clean.

The final mapped document invocation stopped without a complete perf_document
footer. Its isolated retry passed5tests in31.87seconds under the unchanged50second
deadline; the remaining15 unrun mapped files then passed198tests. No hard-counter
regression reproduced and no test limit changed. The original run remains recorded
as interrupted/failed, with cause unconfirmed; it is not presented as a passing
command. Consolidated per-file evidence: /tmp/parley254-m4-final-verification.txt.

Integrated make perf passed30scenarios x20samples. Stream/human interleave at5000
rows used17structuralrows and zero full reads (68.80/114.28ms median/p95). Broad
repair took11.01/13.02seconds with counters unchanged from staging; reviewer/CPU
overlap limits timing attribution. This remains an expensive documented exception.
M4 now enters its mandatory Codex review; M5/M6 stay isolated until their preceding
boundaries close. No merge to main is authorized before operator live testing.

### 2026-09-15 — M5 fixed input membership and completion evidence

Native public regression showed a newly inserted question could enter a later
batch request despite fixed response selection. The batch now restricts both
remote-reference preparation and provider messages to its captured exchange set;
write geometry still comes from the full current document. Inserted questions stay
in the buffer but do not become new context for the already-captured batch.

A successful generation callback must capture context evidence immediately, or
freeze the edit serial while structural repair completes. A later human edit
cannot become silently accepted completion evidence. A positive success advances
completed progress even when context evidence is unavailable; the batch pauses
and requires explicit adoption before continuing. Reload/detach retires obsolete
registry membership while Session retains physical effect cleanup.

Per-query bounds alone do not bound batch callbacks. Batch proof validation is
being split into at most eight Document queries per scheduled turn, with a shared
edit serial fencing staged evidence. Repeated concurrent edits pause validation
instead of spinning. Large explicit resume acknowledges queued validation and
keeps the batch paused until the complete proof is accepted.

Recovery core22 and Document adapter13 tests pass. Public response25 tests pass
including unavailable recovery publication preserving the original answer and
starting no provider IO. Recovery UI/save association and bounded batch validation
are still in progress; M5 is not closed. M6 implementation may stage independently
but must integrate only after M5 review. M6 inventory corrects the old file list:
tool_loop is already removed; response_tools owns production child dispatch, and
argv is a pure helper rather than an executable builtin.

### 2026-09-15 — M5 recovery integration and M6 handoff

M5 batch mapping now passes7files/87tests. Public response27tests include captured
request membership, registered bang-resume edit adoption, refused snapshot
publication, and deletion cleanup only after confirmed chat removal. Recovery
store22, adapter13, UI/save/deletion17 and path-exclusion4 tests have passed in
focused runs; the store is receiving an additional ambiguous-descriptor-close
regression before final mapped verification. Current changed runtime lint is clean.

Recovery files are excluded from explicit attachment reads and directory expansion,
including canonical/symlink aliases. The existing synchronous tool read/traversal
path bypasses the helper; M6's common tool admission and traversal migration must
apply the shared recovery_paths policy before content IO. This remaining tool
enforcement is not claimed by M5 and must pass before the issue reaches live testing.

M6 pure operation/resources prerequisites are staged at82a5fb12 in
/tmp/parley254-m6-stage:14tests including4200generated events/steps pass. Checked
asynchronous filesystem and process-supervision seams are in progress separately.
Numeric file descriptors are not reusable authority after an ambiguous close:
probe-only reconciliation must never close a descriptor that may now belong to
another operation. M5 recovery uses the same conservative rule and bounded retained
owners. No unresolved operation is removed to make an admission counter look clean.

### 2026-09-15 — M6 supervisor integration and bounded defaults

Reason: asynchronous builtins require a shared owner across chat and skill paths,
including cancelled document lifetimes. Delta: `tools/producer` captures allowed
functions/configuration, canonical input/claims and frozen roots before effect
submission, then normalizes only recorded outcomes. `skill_invoke` joins the same
supervisor rather than retaining a synchronous bypass. Missing-parent writes use
checked asynchronous directory creation and conservatively claim the write-root
subtree; numbered backup selection takes the same exclusive claim.

Distinguish local parent retirement from operation terminal state: a cancelled
child may transfer through the explicit stopping-only `operation_supervised`
event. Its outcome remains unknown when appropriate, and the supervisor retains
claims/IO independently of the retired Document. Normal completion cannot request
this handoff. `ToolOperations` exposes stable IDs and operator effect evidence;
operator input cannot supply physical cleanup. No effect replay is introduced.

Expose validated lowerable `tool_execution` limits: process16 providers/16tools,
total32 including utilities, four generations/document, eighttools/document,
fourtools/generation and16MiB process capture; resource16running/128queued,
32queued/generation and32claims;128records;512KiB result/16MiB totalresult;
1MiB file envelope. Existing arguments64KiB/8192nodes/depth32 remain bounded.
Five-second reconciliation uses50ms doubling to1s, emits one unresolved notice,
then retires its timer while keeping claims. Disjoint same-document work bypasses
blocked claims; conflicting and runnable-capacity waiters retain FIFO priority.
Public tests cover actual provider/Scheduler/native FS+Tasker concurrency, draft
editing, frozen capabilities, Stop/reload handoff and operator physical-evidence
refusal (ARCH-ORDER, ARCH-FUNERAL, ARCH-CONSTRAINTS, ARCH-DRY).

### 2026-09-15 — Bound resource queue callback work

Reason: worst-case128queued/32claims caused a644ms synchronous pump despite finite
admission counts. Delta: cache exact component-ordered claim intersections and
reuse the already-blocked prefix proof during one pump. Preserve FIFO conflicts,
runnable capacity priority and disjoint same-document bypass. Five native samples
measure max~13ms for both ordinary and4000-byte component chains; all-disjoint
capacity queues are below0.1ms. No limits changed. A deterministic JIT-disabled
VM-call budget fails the previous implementation; exact hash-collision/ancestry
oracles defend correctness (ARCH-CONSTRAINTS, ARCH-PURPOSE).
