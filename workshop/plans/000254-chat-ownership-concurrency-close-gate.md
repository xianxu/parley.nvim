---
gate: boundary-review
issue: 254
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-14T23:35:44-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Automatic topic generation escapes response cancellation ownership
          detail: chat_respond.lua:1755 cancels transport_owner, but generate_topic launches dispatcher.query at line 1216 without that identity. A scratch production-response regression completed the answer, deleted its header during topic generation, and observed no cancellation signal. Propagate ownership through response-owned launch paths and add a regression covering topic cancellation and unrelated-owner preservation (ARCH-PURPOSE, ARCH-ORDER, ARCH-FUNERAL).
          family: cancellation-owner-propagation
          round: 1
        - id: BR-2
          severity: Important
          title: Assign deferred attempt reconciliation to an explicit milestone
          detail: The plan at line 242 promises bounded reconciliation and visible unresolved status, while tasker.lua:130 implements no polling and its reconciliation function has no production caller. The issue log defers this work without an explicit remaining milestone task; add a Revisions entry and assign implementation, admission bounds, diagnostics, and deterministic verification (ARCH-CONSTRAINTS).
          family: deferred-contract-traceability
          round: 1
      boundary: M1
      blocked: true
    - "n": 2
      timestamp: "2026-09-14T23:46:39-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: chat_respond.lua:2127 propagates response ownership into automatic topics; dispatcher.lua:881 preserves it across retries. Removing topic ownership in a scratch copy makes both deletion regressions fail at chat_ownership_spec.lua:157. The pinned tests verify unrelated-owner preservation and retention until exit/drain.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The pinned plan adds an explicit M6 task at line 310 covering bounded reconciliation, admission limits, diagnostics, timer cleanup, and deterministic verification. Its Revisions entry at lines 443–451 accurately distinguishes tasker.lua:130's current retention-only behavior from future supervision.
          round: 2
      boundary: M1
      blocked: false
    - "n": 3
      timestamp: "2026-09-15T00:44:23-07:00"
      agent: codex
      findings:
        - id: BR-3
          severity: Critical
          title: Local text certificates permit stale confirmed semantic publication
          detail: 'lua/parley/document/structure.lua:115–154 captures only local text evidence and epoch. After changing an earlier question marker to an assistant marker and completing repair, publishing previously captured body metadata succeeds and restores question semantics with confirmed=true. ARCH-ORDER / ARCH-SECURE: validate incoming semantic state and dependencies, or restrict publication to lexical metadata; add controlled stale-publication and disjoint-edit regressions.'
          family: semantic-publication-evidence
          round: 3
        - id: BR-4
          severity: Critical
          title: Ordinary-fence suppression removes a required reasoning boundary
          detail: 'lua/parley/document/grammar.lua:202–225 rewrites fenced tool markers to text before reasoning termination. For question, answer, opening fence, reasoning marker, tool-result marker, closing fence, the new core marks the last two rows thinking while the legacy reducer marks them text. ARCH-PURPOSE: preserve original structural boundary semantics separately from tool-section admission and cover both tool-marker kinds across section states.'
          family: grammar-boundary-preservation
          round: 3
      boundary: M2
      blocked: true
    - "n": 4
      timestamp: "2026-09-15T01:01:56-07:00"
      agent: codex
      dispose:
        - id: BR-3
          disposition: addressed
          note: structure.lua:144–169 restricts publication to lexical metadata and invalidates changed classifications. document_structure_spec.lua:109 and :135 pass at HEAD and both fail with the pre-fix module substituted in memory; disjoint-edit acceptance remains covered.
          round: 4
        - id: BR-4
          disposition: addressed
          note: grammar.lua:225 retains original structural kind for termination. document_grammar_spec.lua:205 and document_semantic_spec.lua:61 pass at HEAD and both fail with the pre-fix module substituted in memory; coverage sweeps both tool-marker kinds across section and fence states.
          round: 4
      boundary: M2
      blocked: false
    - "n": 5
      timestamp: "2026-09-15T02:40:58-07:00"
      agent: codex
      findings:
        - id: BR-5
          severity: Critical
          title: Grouped undo can leave the settled index confirming incorrect marker kinds
          detail: 'lua/parley/document/init.lua:118–149 accepts callback text from matching row/byte extents. Native grouped insertion/deletion followed by undo restored a visible user marker but left its indexed token assistant, confirmed=true, with repair idle. This is the 2nd finding in this family: establish and sweep the callback provenance rule across edit shapes and undo/redo; add native settled-semantic parity regression coverage.'
          family: semantic-publication-evidence
          round: 5
        - id: BR-6
          severity: Critical
          title: Unconfirmed semantics still control highlights and native folds
          detail: 'document/structure.lua:49–59 preserves invalidated render/footer/draft state consumed by highlighter.lua:75–80; tool_folds.lua:260–271 retains affected folds while uncertain. Native reproduction and highlight_typing_spec.lua:44–56 confirm stale question styling after a role change; document_folds_spec.lua:42–47 requires stale folds. This is the 3rd finding in this family: enforce current semantic evidence across presentation consumers and replace assertions contrary to plan section C.'
          family: semantic-publication-evidence
          round: 5
        - id: BR-7
          severity: Critical
          title: M3 Core concepts and function declarations disagree with the pinned implementation
          detail: 'workshop/plans/000254-chat-ownership-concurrency-plan.md:59–72 declares fold_projection.lua and buffer_edit.lua modified at M3, but both are unchanged; indexed projection lives in document/projection.lua and the strategy names nonexistent fold_projection.project. This is the 2nd finding in this family: reconcile the full M3 entity/function inventory and add a Revisions entry. This prose-only correction does not require a wording test.'
          family: deferred-contract-traceability
          round: 5
        - id: BR-8
          severity: Important
          title: Detached documents and fold callbacks are not reclaimed
          detail: 'lua/parley/document/init.lua:176–191 leaves the weak-key registry value holding an editor callback that captures its document key. A native LuaJIT probe retained all 50 deleted documents after repeated full GC. tool_folds.lua also leaves four autocmd registrations after deletion. ARCH-FUNERAL: break retired callback references, remove scope-owned autocmds, and test reclamation through native weak references.'
          family: scope-owned-callback-cleanup
          round: 5
      boundary: M3
      blocked: true
    - "n": 6
      timestamp: "2026-09-15T03:30:11-07:00"
      agent: codex
      dispose:
        - id: BR-5
          disposition: addressed
          note: Native callback-frame regressions pass at head. Restoring pre-fix editor/coordinator code in scratch reproduces the equal-extent undo token mismatch and forbidden callback reads.
          round: 6
        - id: BR-6
          disposition: addressed
          note: Structure queries strip invalidated semantic presentation, and fold maintenance clears uncertain folds. Head regressions pass; restoring pre-fix modules causes three highlight and two fold regression failures.
          round: 6
        - id: BR-7
          disposition: addressed
          note: 'Plan lines 652–691 explicitly supersede the proposed inventory: document/projection.lua owns indexed projection; fold_projection.lua and buffer_edit.lua are unchanged; exchange_model.lua changes documentation only. The pinned diff and declared functions support these corrections.'
          round: 6
        - id: BR-8
          disposition: addressed
          note: Editor detach severs on_event and fold teardown deletes its autocmd group. Native retention tests pass at head; pre-fix scratch code fails four retention cases, including document collection and autocmd cleanup.
          round: 6
      findings:
        - id: BR-9
          severity: Critical
          title: Outline selection accepts surviving identity without current semantic evidence
          detail: 'lua/parley/outline.lua:139–145 checks only whether Document.lookup returns a row. Native reproduction: select "# heading", replace its preceding "intro" with an opening code fence, then invoke the saved selection. Navigation succeeds while metadata.confirmed=false; after repair, the outline contains zero items but the same selection still succeeds and highlights line 2. This violates Plan section C''s confirmed-navigation contract (ARCH-ORDER, ARCH-PURPOSE). This is the 4th finding in family semantic-publication-evidence. State and enforce the rule across consumers: surviving identity establishes location, never current semantic eligibility. Enumerate highlighting, folds, outline selection/navigation, and diagnostics; validate each action''s current semantic evidence. Add selection-after-invalidation and selection-after-reclassification regressions.'
          family: semantic-publication-evidence
          round: 6
      boundary: M3
      blocked: true
    - "n": 7
      timestamp: "2026-09-15T04:00:29-07:00"
      agent: codex
      dispose:
        - id: BR-9
          disposition: addressed
          note: outline.lua now checks current projection eligibility and revalidates after focus callbacks. Removing the fix in scratch produces six outline failures; removing the diagnostic correction also fails the pending-publication regression.
          round: 7
        - id: BR-5
          disposition: addressed
          note: Native callback-frame admission is enforced in document/editor.lua; all four native-history regressions pass against the pinned head.
          round: 7
        - id: BR-6
          disposition: addressed
          note: Semantic presentation uses confirmed document evidence. The six highlighter-document and seven document-fold integration cases pass, including uncertainty handling.
          round: 7
        - id: BR-7
          disposition: addressed
          note: The plan's M3 inventory revision explicitly supersedes proposed locations and identifies unchanged fold_projection/buffer_edit modules and the documentation-only exchange_model change; these statements match the pinned diff.
          round: 7
        - id: BR-8
          disposition: addressed
          note: Editor retirement breaks its coordinator callback reference, and fold teardown removes owned callbacks. All five document-retention regressions pass.
          round: 7
      findings:
        - id: BR-10
          severity: Critical
          title: Reentrant diagnostic publication overwrites a newer invalidation
          detail: 'lua/parley/diagnostic_refresh.lua:127–133 publishes through vim.diagnostic.set, which synchronously runs DiagnosticChanged callbacks. A callback editing the source sets s.job=nil and s.dirty=true through the subscription at line 185, but the returning publisher unconditionally resets s.dirty=false. A native regression removing the timestamp during publication leaves one obsolete diagnostic after repair/drain reports idle. ARCH-ORDER, ARCH-PURPOSE: this is the 5th finding in family semantic-publication-evidence. Earlier rounds fixed instances; enforce the class-wide rule that an effect completion may commit only while its captured job and eligibility remain current. Enumerate highlighting, fold recreation, outline navigation, and diagnostic publication across callback boundaries; preserve newer invalidation and stop superseded effects.'
          family: semantic-publication-evidence
          round: 7
      boundary: M3
      blocked: true
    - "n": 8
      timestamp: "2026-09-15T07:59:45-07:00"
      agent: claude
      dispose:
        - id: BR-10
          disposition: addressed
          note: diagnostic_refresh.lua captures the job and rechecks current() after materialization, each diagnostic set, and before the single dirty commit; clear yields to a replacement refresh. Reverting only the fix files in a scratch archive fails 7 of 9 diagnostic and 3 of 4 fold reentrancy regressions.
          round: 8
      findings:
        - id: BR-11
          severity: Important
          title: Superseded fold slices skip restoring operator foldenable and window view
          detail: 'lua/parley/tool_folds.lua:387-390 and :116-121 check current() before restoring foldenable and winrestview, so a callback edit during a slice leaves foldenable forced on; the rebuilt plan then captures the leaked value as the operator preference. Native reproduction: foldenable=false plus an inert edit in an OptionSet(foldenable) autocmd yields foldenable=true after flush (control stays false). This is the 2nd finding in family scope-owned-callback-cleanup: restore slice-altered operator state on every exit path and gate only job-output effects on ownership; sweep apply, clear_folds_in_span, and both discard loops, which also abandon suspended windows on the >50k-row path.'
          family: scope-owned-callback-cleanup
          round: 8
        - id: BR-12
          severity: Important
          title: Aborted window configuration leaves a truncated plan that reports idle with no folds
          detail: 'lua/parley/tool_folds.lua:315-325 assigns plan.windows={} then returns ''more'' when configure(win,current) fails on a tick-only change; the next slice finds no window, returns ''idle'', and M.step:416 clears s.first. Native reproduction: an inert same-length edit inside an OptionSet(foldminlines) autocmd during the apply-phase configure leaves foldlevel(3)==0 across repeated flushes (control gives 1). This is the 6th finding in family semantic-publication-evidence: a superseded slice must discard its job or leave it resumable, and completion may only be claimed from evidence gathered under the captured ownership. Enumerate every current() exit in tool_folds.lua (apply:319, apply:398, clear_uncertainty:273/279/284, setup:571) and fix the class, not the site.'
          family: semantic-publication-evidence
          round: 8
      boundary: M3
      blocked: true
    - "n": 9
      timestamp: "2026-09-15T09:19:02-07:00"
      agent: claude
      boundary: M3
      blocked: true
      protocol_error: no valid findings block
    - "n": 10
      timestamp: "2026-09-15T09:26:25-07:00"
      agent: codex
      dispose:
        - id: BR-11
          disposition: not-addressed
          note: Important; scope-owned-callback-cleanup. tool_folds.lua:347 captures temporary suspension as enabled=false. Detach inside the subsequent OptionSet callback releases the job, but :399-401 restores that temporary false value after retirement. A native 50,010-row reproduction fails on pinned head; moving detach outside the slice passes. Retain BR-11 and fix cleanup ownership across nested slices and job retirement (ARCH-ORDER, ARCH-FUNERAL).
          round: 10
        - id: BR-12
          disposition: addressed
          note: tool_folds.lua:324-335 constructs windows locally and discards interrupted plans. The configuration and surviving-window regressions pass on head and fail with the pre-fix tool_folds.lua substituted.
          round: 10
        - id: BR-5
          disposition: addressed
          note: Prior disposition retained. Native history regressions pass; editor.lua uses callback ordering evidence rather than matching extents alone.
          round: 10
        - id: BR-6
          disposition: addressed
          note: Prior disposition retained. Projection queries reject unconfirmed semantics; highlighting and fold invalidation consume the shared document evidence.
          round: 10
        - id: BR-7
          disposition: addressed
          note: Prior disposition retained. Plan Revisions at line 652 explicitly supersede the proposed inventory; the named modules and unchanged fold_projection/buffer_edit classifications match the pinned diff.
          round: 10
        - id: BR-8
          disposition: addressed
          note: Prior disposition retained. Document retirement tests pass; detach severs callbacks and removes the fold autocmd group.
          round: 10
        - id: BR-9
          disposition: addressed
          note: Prior disposition retained. Outline tests pass; navigation validates current semantic eligibility after resolving identity and focus callbacks.
          round: 10
        - id: BR-10
          disposition: addressed
          note: Prior disposition retained. Diagnostic reentrancy tests pass; publication checks captured-job ownership after native diagnostic effects.
          round: 10
      boundary: M3
      blocked: true
    - "n": 11
      timestamp: "2026-09-15T10:02:39-07:00"
      agent: codex
      dispose:
        - id: BR-11
          disposition: addressed
          note: tool_folds.lua:20-29 and :197-215 transfer preference-restoration ownership before callbacks and preserve captured views; both discard paths share release_windows. Both new retirement specs pass at HEAD and fail with the pre-2f784bb2 fold implementation.
          round: 11
        - id: BR-5
          disposition: addressed
          note: editor.lua:66 enforces callback-frame provenance; document_callback_frame_spec.lua and document_native_history_spec.lua pass native grouped undo/redo checks.
          round: 11
        - id: BR-6
          disposition: addressed
          note: structure.lua:49 removes unconfirmed semantic presentation; native fold uncertainty and highlighting tests pass.
          round: 11
        - id: BR-7
          disposition: addressed
          note: Plan revision at :652-688 explicitly supersedes proposed M3 symbols. The pinned diff confirms projection.lua owns projection, fold_projection.lua remains unchanged, buffer_edit.lua remains unchanged, and exchange_anchors.lua is deleted.
          round: 11
        - id: BR-8
          disposition: addressed
          note: Editor detach severs its event sink and fold teardown removes its autocmd group; document_retention_spec.lua passes native collection and retained-detached-handle checks.
          round: 11
        - id: BR-9
          disposition: addressed
          note: outline.lua revalidates current eligibility after focus callbacks; the outline suite passes uncertainty, reclassification, deletion, relocation, and stale tree-selection regressions.
          round: 11
        - id: BR-10
          disposition: addressed
          note: diagnostic_refresh.lua checks captured job ownership after callback-capable effects; all nine diagnostic_reentrancy_spec.lua tests pass.
          round: 11
        - id: BR-12
          disposition: addressed
          note: Fold configuration publishes its window list only after completion; document_presentation_reentrant_spec.lua passes interrupted-configuration and surviving-window regressions.
          round: 11
      findings:
        - id: BR-13
          severity: Important
          title: BR-11 regressions are missing from the documented verification mapping
          detail: 'atlas/traceability.yaml:280-285 omits document_fold_retirement_spec.lua and document_fold_uncertainty_retirement_spec.lua. scripts/spec_test_map.sh list-tests chat/document consequently excludes both, contrary to the plan''s verification contract at :377. This is the 3rd finding in family deferred-contract-traceability. Apply the rule that every new boundary regression must be registered in its documented suite: the complete added-spec sweep found exactly these two omissions. Register both and verify the mapping includes them.'
          family: deferred-contract-traceability
          round: 11
      boundary: M3
      blocked: false
    - "n": 12
      timestamp: "2026-09-15T10:23:31-07:00"
      agent: codex
      findings:
        - id: BR-14
          severity: Critical
          title: Pending tool reservations parse as completed non-error results
          detail: 'lua/parley/response_tools.lua:153 serializes an ordinary result before execution; a scratch production-fixture regression returned content="(pending)" and is_error=false. This is the 7th finding in family semantic-publication-evidence. Earlier rounds fixed instances: state and enforce the rule that only confirmed outcomes publish result evidence, sweeping reservation, cancellation, persistence, parsing, and provider projection (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER). Plan lines 150–155 explicitly prohibit this representation.'
          family: semantic-publication-evidence
          round: 12
        - id: BR-15
          severity: Critical
          title: Stale input can silently strand a response in paused state
          detail: lua/parley/generation_runner.lua:317 pauses stale-input continuation until an explicit resume policy arrives, but production callers do not invoke the session resume API or publish stale/paused state; response_session.lua:52 wires only ordinary pending presentation. Expose the state and an identity-validated continuation decision, retain the promised stale indication on completed answers, and test through the public response workflow (ARCH-PURPOSE, ARCH-ORDER).
          family: lifecycle-state-observability
          round: 12
        - id: BR-16
          severity: Important
          title: README omits the new StopDocument command and changed Stop contract
          detail: 'lua/parley/init.lua:1583–1584 introduces the user-facing command and selection behavior without any README change in the pinned range. This is the 4th finding in family deferred-contract-traceability. Do not repair only this command: enumerate all changed user-facing behavior, including active-output editing and native history, and complete the README gate for that inventory (ARCH-PURPOSE). Prose inspection is sufficient validation for this documentation correction.'
          family: deferred-contract-traceability
          round: 12
      boundary: M4
      blocked: true
    - "n": 13
      timestamp: "2026-09-15T10:55:58-07:00"
      agent: codex
      dispose:
        - id: BR-14
          disposition: addressed
          note: response_tools.lua:156 reserves inert text; lines 92–99 serialize only known outcomes. Regression tests cover pending, cancellation, reload, unknown/rejected outcomes, sibling completion, and provider projection. Restoring the previous implementation in scratch reproduces parsed content="(pending)", is_error=false.
          round: 13
        - id: BR-15
          disposition: addressed
          note: Public ChatResumeResponse now reaches identity-validated resume_original; stale annotations survive completion. Native public-workflow tests cover continuation, focus changes, revoked output, detach, and fresh-answer clearing. Restoring the previous runner in scratch makes four regression tests fail.
          round: 13
        - id: BR-16
          disposition: addressed
          note: README.md:64–87 documents Stop/StopDocument, active-output edits, deletion/reload, native history, pending results, and stale continuation. The pinned additions match init.lua:1583–1585, chat_history.lua:6–8, and the response adapters.
          round: 13
      findings:
        - id: BR-17
          severity: Critical
          title: Later-draft edits before admission falsely stale and pause an earlier response
          detail: 'response_target.lua:99–101 sets input_stale=true for every document edit, regardless of captured input dependencies. A scratch public-workflow regression submits the first question, immediately edits the later draft, then completes a tool round: the earlier generation becomes paused with stale_input=true and never issues its second request. This contradicts plan line 145. This is the 8th finding in family semantic-publication-evidence: do not patch only this site; enforce dependency-backed stale evidence across waiting-target admission, active generation, presentation, and continuation (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER).'
          family: semantic-publication-evidence
          round: 13
      boundary: M4
      blocked: true
---

# Gate ledger — 000254-chat-ownership-concurrency#254 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-14T23:35:44-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `cancellation-owner-propagation` Automatic topic generation escapes response cancellation ownership
  chat_respond.lua:1755 cancels transport_owner, but generate_topic launches dispatcher.query at line 1216 without that identity. A scratch production-response regression completed the answer, deleted its header during topic generation, and observed no cancellation signal. Propagate ownership through response-owned launch paths and add a regression covering topic cancellation and unrelated-owner preservation (ARCH-PURPOSE, ARCH-ORDER, ARCH-FUNERAL).
- **BR-2** [Important] `deferred-contract-traceability` Assign deferred attempt reconciliation to an explicit milestone
  The plan at line 242 promises bounded reconciliation and visible unresolved status, while tasker.lua:130 implements no polling and its reconciliation function has no production caller. The issue log defers this work without an explicit remaining milestone task; add a Revisions entry and assign implementation, admission bounds, diagnostics, and deterministic verification (ARCH-CONSTRAINTS).

## Round 2 — 2026-09-14T23:46:39-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — chat_respond.lua:2127 propagates response ownership into automatic topics; dispatcher.lua:881 preserves it across retries. Removing topic ownership in a scratch copy makes both deletion regressions fail at chat_ownership_spec.lua:157. The pinned tests verify unrelated-owner preservation and retention until exit/drain.
- BR-2 — addressed — The pinned plan adds an explicit M6 task at line 310 covering bounded reconciliation, admission limits, diagnostics, timer cleanup, and deterministic verification. Its Revisions entry at lines 443–451 accurately distinguishes tasker.lua:130's current retention-only behavior from future supervision.

## Round 3 — 2026-09-15T00:44:23-07:00 (codex) — BLOCKED

### Raised

- **BR-3** [Critical] `semantic-publication-evidence` Local text certificates permit stale confirmed semantic publication
  lua/parley/document/structure.lua:115–154 captures only local text evidence and epoch. After changing an earlier question marker to an assistant marker and completing repair, publishing previously captured body metadata succeeds and restores question semantics with confirmed=true. ARCH-ORDER / ARCH-SECURE: validate incoming semantic state and dependencies, or restrict publication to lexical metadata; add controlled stale-publication and disjoint-edit regressions.
- **BR-4** [Critical] `grammar-boundary-preservation` Ordinary-fence suppression removes a required reasoning boundary
  lua/parley/document/grammar.lua:202–225 rewrites fenced tool markers to text before reasoning termination. For question, answer, opening fence, reasoning marker, tool-result marker, closing fence, the new core marks the last two rows thinking while the legacy reducer marks them text. ARCH-PURPOSE: preserve original structural boundary semantics separately from tool-section admission and cover both tool-marker kinds across section states.

## Round 4 — 2026-09-15T01:01:56-07:00 (codex) — passed

### Disposed

- BR-3 — addressed — structure.lua:144–169 restricts publication to lexical metadata and invalidates changed classifications. document_structure_spec.lua:109 and :135 pass at HEAD and both fail with the pre-fix module substituted in memory; disjoint-edit acceptance remains covered.
- BR-4 — addressed — grammar.lua:225 retains original structural kind for termination. document_grammar_spec.lua:205 and document_semantic_spec.lua:61 pass at HEAD and both fail with the pre-fix module substituted in memory; coverage sweeps both tool-marker kinds across section and fence states.

## Round 5 — 2026-09-15T02:40:58-07:00 (codex) — BLOCKED

### Raised

- **BR-5** [Critical] `semantic-publication-evidence` Grouped undo can leave the settled index confirming incorrect marker kinds
  lua/parley/document/init.lua:118–149 accepts callback text from matching row/byte extents. Native grouped insertion/deletion followed by undo restored a visible user marker but left its indexed token assistant, confirmed=true, with repair idle. This is the 2nd finding in this family: establish and sweep the callback provenance rule across edit shapes and undo/redo; add native settled-semantic parity regression coverage.
- **BR-6** [Critical] `semantic-publication-evidence` Unconfirmed semantics still control highlights and native folds
  document/structure.lua:49–59 preserves invalidated render/footer/draft state consumed by highlighter.lua:75–80; tool_folds.lua:260–271 retains affected folds while uncertain. Native reproduction and highlight_typing_spec.lua:44–56 confirm stale question styling after a role change; document_folds_spec.lua:42–47 requires stale folds. This is the 3rd finding in this family: enforce current semantic evidence across presentation consumers and replace assertions contrary to plan section C.
- **BR-7** [Critical] `deferred-contract-traceability` M3 Core concepts and function declarations disagree with the pinned implementation
  workshop/plans/000254-chat-ownership-concurrency-plan.md:59–72 declares fold_projection.lua and buffer_edit.lua modified at M3, but both are unchanged; indexed projection lives in document/projection.lua and the strategy names nonexistent fold_projection.project. This is the 2nd finding in this family: reconcile the full M3 entity/function inventory and add a Revisions entry. This prose-only correction does not require a wording test.
- **BR-8** [Important] `scope-owned-callback-cleanup` Detached documents and fold callbacks are not reclaimed
  lua/parley/document/init.lua:176–191 leaves the weak-key registry value holding an editor callback that captures its document key. A native LuaJIT probe retained all 50 deleted documents after repeated full GC. tool_folds.lua also leaves four autocmd registrations after deletion. ARCH-FUNERAL: break retired callback references, remove scope-owned autocmds, and test reclamation through native weak references.

## Round 6 — 2026-09-15T03:30:11-07:00 (codex) — BLOCKED

### Disposed

- BR-5 — addressed — Native callback-frame regressions pass at head. Restoring pre-fix editor/coordinator code in scratch reproduces the equal-extent undo token mismatch and forbidden callback reads.
- BR-6 — addressed — Structure queries strip invalidated semantic presentation, and fold maintenance clears uncertain folds. Head regressions pass; restoring pre-fix modules causes three highlight and two fold regression failures.
- BR-7 — addressed — Plan lines 652–691 explicitly supersede the proposed inventory: document/projection.lua owns indexed projection; fold_projection.lua and buffer_edit.lua are unchanged; exchange_model.lua changes documentation only. The pinned diff and declared functions support these corrections.
- BR-8 — addressed — Editor detach severs on_event and fold teardown deletes its autocmd group. Native retention tests pass at head; pre-fix scratch code fails four retention cases, including document collection and autocmd cleanup.

### Raised

- **BR-9** [Critical] `semantic-publication-evidence` Outline selection accepts surviving identity without current semantic evidence
  lua/parley/outline.lua:139–145 checks only whether Document.lookup returns a row. Native reproduction: select "# heading", replace its preceding "intro" with an opening code fence, then invoke the saved selection. Navigation succeeds while metadata.confirmed=false; after repair, the outline contains zero items but the same selection still succeeds and highlights line 2. This violates Plan section C's confirmed-navigation contract (ARCH-ORDER, ARCH-PURPOSE). This is the 4th finding in family semantic-publication-evidence. State and enforce the rule across consumers: surviving identity establishes location, never current semantic eligibility. Enumerate highlighting, folds, outline selection/navigation, and diagnostics; validate each action's current semantic evidence. Add selection-after-invalidation and selection-after-reclassification regressions.

## Round 7 — 2026-09-15T04:00:29-07:00 (codex) — BLOCKED

### Disposed

- BR-9 — addressed — outline.lua now checks current projection eligibility and revalidates after focus callbacks. Removing the fix in scratch produces six outline failures; removing the diagnostic correction also fails the pending-publication regression.
- BR-5 — addressed — Native callback-frame admission is enforced in document/editor.lua; all four native-history regressions pass against the pinned head.
- BR-6 — addressed — Semantic presentation uses confirmed document evidence. The six highlighter-document and seven document-fold integration cases pass, including uncertainty handling.
- BR-7 — addressed — The plan's M3 inventory revision explicitly supersedes proposed locations and identifies unchanged fold_projection/buffer_edit modules and the documentation-only exchange_model change; these statements match the pinned diff.
- BR-8 — addressed — Editor retirement breaks its coordinator callback reference, and fold teardown removes owned callbacks. All five document-retention regressions pass.

### Raised

- **BR-10** [Critical] `semantic-publication-evidence` Reentrant diagnostic publication overwrites a newer invalidation
  lua/parley/diagnostic_refresh.lua:127–133 publishes through vim.diagnostic.set, which synchronously runs DiagnosticChanged callbacks. A callback editing the source sets s.job=nil and s.dirty=true through the subscription at line 185, but the returning publisher unconditionally resets s.dirty=false. A native regression removing the timestamp during publication leaves one obsolete diagnostic after repair/drain reports idle. ARCH-ORDER, ARCH-PURPOSE: this is the 5th finding in family semantic-publication-evidence. Earlier rounds fixed instances; enforce the class-wide rule that an effect completion may commit only while its captured job and eligibility remain current. Enumerate highlighting, fold recreation, outline navigation, and diagnostic publication across callback boundaries; preserve newer invalidation and stop superseded effects.

## Round 8 — 2026-09-15T07:59:45-07:00 (claude) — BLOCKED

### Disposed

- BR-10 — addressed — diagnostic_refresh.lua captures the job and rechecks current() after materialization, each diagnostic set, and before the single dirty commit; clear yields to a replacement refresh. Reverting only the fix files in a scratch archive fails 7 of 9 diagnostic and 3 of 4 fold reentrancy regressions.

### Raised

- **BR-11** [Important] `scope-owned-callback-cleanup` Superseded fold slices skip restoring operator foldenable and window view
  lua/parley/tool_folds.lua:387-390 and :116-121 check current() before restoring foldenable and winrestview, so a callback edit during a slice leaves foldenable forced on; the rebuilt plan then captures the leaked value as the operator preference. Native reproduction: foldenable=false plus an inert edit in an OptionSet(foldenable) autocmd yields foldenable=true after flush (control stays false). This is the 2nd finding in family scope-owned-callback-cleanup: restore slice-altered operator state on every exit path and gate only job-output effects on ownership; sweep apply, clear_folds_in_span, and both discard loops, which also abandon suspended windows on the >50k-row path.
- **BR-12** [Important] `semantic-publication-evidence` Aborted window configuration leaves a truncated plan that reports idle with no folds
  lua/parley/tool_folds.lua:315-325 assigns plan.windows={} then returns 'more' when configure(win,current) fails on a tick-only change; the next slice finds no window, returns 'idle', and M.step:416 clears s.first. Native reproduction: an inert same-length edit inside an OptionSet(foldminlines) autocmd during the apply-phase configure leaves foldlevel(3)==0 across repeated flushes (control gives 1). This is the 6th finding in family semantic-publication-evidence: a superseded slice must discard its job or leave it resumable, and completion may only be claimed from evidence gathered under the captured ownership. Enumerate every current() exit in tool_folds.lua (apply:319, apply:398, clear_uncertainty:273/279/284, setup:571) and fix the class, not the site.

## Round 9 — 2026-09-15T09:19:02-07:00 (claude) — BLOCKED

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 10 — 2026-09-15T09:26:25-07:00 (codex) — BLOCKED

### Disposed

- BR-11 — not-addressed — Important; scope-owned-callback-cleanup. tool_folds.lua:347 captures temporary suspension as enabled=false. Detach inside the subsequent OptionSet callback releases the job, but :399-401 restores that temporary false value after retirement. A native 50,010-row reproduction fails on pinned head; moving detach outside the slice passes. Retain BR-11 and fix cleanup ownership across nested slices and job retirement (ARCH-ORDER, ARCH-FUNERAL).
- BR-12 — addressed — tool_folds.lua:324-335 constructs windows locally and discards interrupted plans. The configuration and surviving-window regressions pass on head and fail with the pre-fix tool_folds.lua substituted.
- BR-5 — addressed — Prior disposition retained. Native history regressions pass; editor.lua uses callback ordering evidence rather than matching extents alone.
- BR-6 — addressed — Prior disposition retained. Projection queries reject unconfirmed semantics; highlighting and fold invalidation consume the shared document evidence.
- BR-7 — addressed — Prior disposition retained. Plan Revisions at line 652 explicitly supersede the proposed inventory; the named modules and unchanged fold_projection/buffer_edit classifications match the pinned diff.
- BR-8 — addressed — Prior disposition retained. Document retirement tests pass; detach severs callbacks and removes the fold autocmd group.
- BR-9 — addressed — Prior disposition retained. Outline tests pass; navigation validates current semantic eligibility after resolving identity and focus callbacks.
- BR-10 — addressed — Prior disposition retained. Diagnostic reentrancy tests pass; publication checks captured-job ownership after native diagnostic effects.

## Round 11 — 2026-09-15T10:02:39-07:00 (codex) — passed

### Disposed

- BR-11 — addressed — tool_folds.lua:20-29 and :197-215 transfer preference-restoration ownership before callbacks and preserve captured views; both discard paths share release_windows. Both new retirement specs pass at HEAD and fail with the pre-2f784bb2 fold implementation.
- BR-5 — addressed — editor.lua:66 enforces callback-frame provenance; document_callback_frame_spec.lua and document_native_history_spec.lua pass native grouped undo/redo checks.
- BR-6 — addressed — structure.lua:49 removes unconfirmed semantic presentation; native fold uncertainty and highlighting tests pass.
- BR-7 — addressed — Plan revision at :652-688 explicitly supersedes proposed M3 symbols. The pinned diff confirms projection.lua owns projection, fold_projection.lua remains unchanged, buffer_edit.lua remains unchanged, and exchange_anchors.lua is deleted.
- BR-8 — addressed — Editor detach severs its event sink and fold teardown removes its autocmd group; document_retention_spec.lua passes native collection and retained-detached-handle checks.
- BR-9 — addressed — outline.lua revalidates current eligibility after focus callbacks; the outline suite passes uncertainty, reclassification, deletion, relocation, and stale tree-selection regressions.
- BR-10 — addressed — diagnostic_refresh.lua checks captured job ownership after callback-capable effects; all nine diagnostic_reentrancy_spec.lua tests pass.
- BR-12 — addressed — Fold configuration publishes its window list only after completion; document_presentation_reentrant_spec.lua passes interrupted-configuration and surviving-window regressions.

### Raised

- **BR-13** [Important] `deferred-contract-traceability` BR-11 regressions are missing from the documented verification mapping
  atlas/traceability.yaml:280-285 omits document_fold_retirement_spec.lua and document_fold_uncertainty_retirement_spec.lua. scripts/spec_test_map.sh list-tests chat/document consequently excludes both, contrary to the plan's verification contract at :377. This is the 3rd finding in family deferred-contract-traceability. Apply the rule that every new boundary regression must be registered in its documented suite: the complete added-spec sweep found exactly these two omissions. Register both and verify the mapping includes them.

## Round 12 — 2026-09-15T10:23:31-07:00 (codex) — BLOCKED

### Raised

- **BR-14** [Critical] `semantic-publication-evidence` Pending tool reservations parse as completed non-error results
  lua/parley/response_tools.lua:153 serializes an ordinary result before execution; a scratch production-fixture regression returned content="(pending)" and is_error=false. This is the 7th finding in family semantic-publication-evidence. Earlier rounds fixed instances: state and enforce the rule that only confirmed outcomes publish result evidence, sweeping reservation, cancellation, persistence, parsing, and provider projection (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER). Plan lines 150–155 explicitly prohibit this representation.
- **BR-15** [Critical] `lifecycle-state-observability` Stale input can silently strand a response in paused state
  lua/parley/generation_runner.lua:317 pauses stale-input continuation until an explicit resume policy arrives, but production callers do not invoke the session resume API or publish stale/paused state; response_session.lua:52 wires only ordinary pending presentation. Expose the state and an identity-validated continuation decision, retain the promised stale indication on completed answers, and test through the public response workflow (ARCH-PURPOSE, ARCH-ORDER).
- **BR-16** [Important] `deferred-contract-traceability` README omits the new StopDocument command and changed Stop contract
  lua/parley/init.lua:1583–1584 introduces the user-facing command and selection behavior without any README change in the pinned range. This is the 4th finding in family deferred-contract-traceability. Do not repair only this command: enumerate all changed user-facing behavior, including active-output editing and native history, and complete the README gate for that inventory (ARCH-PURPOSE). Prose inspection is sufficient validation for this documentation correction.

## Round 13 — 2026-09-15T10:55:58-07:00 (codex) — BLOCKED

### Disposed

- BR-14 — addressed — response_tools.lua:156 reserves inert text; lines 92–99 serialize only known outcomes. Regression tests cover pending, cancellation, reload, unknown/rejected outcomes, sibling completion, and provider projection. Restoring the previous implementation in scratch reproduces parsed content="(pending)", is_error=false.
- BR-15 — addressed — Public ChatResumeResponse now reaches identity-validated resume_original; stale annotations survive completion. Native public-workflow tests cover continuation, focus changes, revoked output, detach, and fresh-answer clearing. Restoring the previous runner in scratch makes four regression tests fail.
- BR-16 — addressed — README.md:64–87 documents Stop/StopDocument, active-output edits, deletion/reload, native history, pending results, and stale continuation. The pinned additions match init.lua:1583–1585, chat_history.lua:6–8, and the response adapters.

### Raised

- **BR-17** [Critical] `semantic-publication-evidence` Later-draft edits before admission falsely stale and pause an earlier response
  response_target.lua:99–101 sets input_stale=true for every document edit, regardless of captured input dependencies. A scratch public-workflow regression submits the first question, immediately edits the later draft, then completes a tool round: the earlier generation becomes paused with stale_input=true and never issues its second request. This contradicts plan line 145. This is the 8th finding in family semantic-publication-evidence: do not patch only this site; enforce dependency-backed stale evidence across waiting-target admission, active generation, presentation, and continuation (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER).

## Open findings

- **BR-13** [Important] `deferred-contract-traceability` BR-11 regressions are missing from the documented verification mapping
- **BR-17** [Critical] `semantic-publication-evidence` Later-draft edits before admission falsely stale and pause an earlier response
