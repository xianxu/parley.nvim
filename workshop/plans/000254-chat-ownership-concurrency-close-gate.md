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

## Open findings

- **BR-9** [Critical] `semantic-publication-evidence` Outline selection accepts surviving identity without current semantic evidence
