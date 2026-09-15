# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M3)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 2afd7de993dc028c6132df4687695e83dcbb8fe0..626e565e2fa614fd30269ffce7d502bb42924dfc |
| command | sdlc milestone-close --issue 254 --milestone M3 |
| reviewer | codex |
| timestamp | 2026-09-15T02:40:58-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M3 establishes useful ownership and rendering boundaries, and both reviewed test mappings pass. However, a real grouped undo can leave the settled index confidently describing different text from the buffer. Pending rendering also violates the plan’s conservative-styling contract. Document retention and inaccurate M3 entity declarations need correction. The pinned range was inspected; no repository files were changed.

## 1. Strengths

- Private grant state, copied snapshots, revision checks, and delegated-slot exclusions are exercised by meaningful tests.
- The editor adapter preserves partial mutation receipts and rejects reentrant writes; native undo tests cover ownership isolation.
- Rendering uses bounded index queries and text reads. Native fold batching and timer-fairness tests exercise production seams.
- Atlas, traceability, and tooling updates accompany the new internal surface. No new user command, keybinding, or configuration key requiring a README update was identified.

## 2. Critical findings

### C1. Grouped undo can permanently confirm incorrect marker kinds

**Location:** `lua/parley/document/init.lua:118–149`

The callback fast path accepts text when its row count and byte length match the intermediate edit descriptor. Those checks cannot distinguish intermediate text from the final buffer text exposed during grouped undo.

**Reproduced in real Neovim:**

1. Start with alternating `💬: q1`, `🤖: a1`, `💬: q2`, `🤖: a2`, `💬: q3`, `🤖: a3`.
2. In one undo block, insert `xxxxxxxx` at row zero, then delete zero-based row three.
3. Undo and drain document repair.

The buffer correctly restores `💬: q2`, but its indexed token is **`assistant`, `confirmed=true`**, and repair reports **`idle`**. Exchange boundaries and future authority queries therefore consume fabricated structural evidence.

**Fix:** Validate callback-read provenance beyond matching extents, or defer classification until the final coordinate frame is established. Sweep replacement, insertion, deletion, undo, and redo fast paths. Add a native regression asserting settled token and exchange parity, not merely byte totals.

**ARCH-ORDER, ARCH-SECURE, ARCH-PURPOSE. This is the 2nd finding in family `semantic-publication-evidence`: fix the evidence rule across admission paths, not just this undo example.**

### C2. Unconfirmed semantics still control highlights and folds

**Locations:** `lua/parley/document/structure.lua:49–59`, `lua/parley/highlighter.lua:75–80`, `lua/parley/tool_folds.lua:260–271`

`presentation=true` preserves invalidated `render_before` and footer/draft semantics. Replacing a question marker with an assistant marker consequently leaves its body styled `ParleyQuestion` until repair finishes. I reproduced this directly.

Similarly, affected native folds remain visible while their structure is uncertain. The new tests explicitly require both behaviors:

- `tests/integration/highlight_typing_spec.lua:44–56`
- `tests/integration/document_folds_spec.lua:42–47`

This contradicts plan §C: unresolved regions receive neutral/local styling, and invalidation clears affected semantic folds. Surviving row identity does not prove surviving semantic context.

**Fix:** Require current context evidence for semantic presentation; retain styling only where that evidence survives. Invalidate affected folds separately from certified recreation. Replace the contrary assertions with independent uncertainty invariants covering roles, reasoning, fences, footer/draft styling, and folds.

**ARCH-ORDER, ARCH-PURPOSE. This is the 3rd finding in family `semantic-publication-evidence`: apply one evidence rule across presentation consumers.**

### C3. Core concepts declarations do not match delivered M3 entities

**Location:** `workshop/plans/000254-chat-ownership-concurrency-plan.md:59–72`

The table declares `fold_projection.lua` and `buffer_edit.lua` **modified at M3**, but neither changes in the pinned range. The new indexed projection lives in `document/projection.lua`; the function strategy still names nonexistent `fold_projection.project`.

**Fix:** Reconcile the complete M3 entity/function inventory: identify reused policy, the actual new projection module, editor-owned mutation behavior, and any explicitly deferred buffer-edit migration. This is a documentation correction; a wording-presence test is unnecessary.

**ARCH-PURPOSE. This is the 2nd finding in family `deferred-contract-traceability`: reconcile the inventory as a whole.** Classified Critical under the requested Core concepts contradiction rule.

## 3. Important findings

### I1. Detached document objects remain retained

**Locations:** `lua/parley/document/init.lua:176–191`, `lua/parley/tool_folds.lua:295–298`

The weak-key document registry stores an editor callback that closes over its own document key. Detach clears the structure but leaves this reference cycle. Under the actual LuaJIT runtime, an isolated probe created and deleted 50 buffers; **all 50 document objects remained reachable through weak references after repeated full collections**.

Fold setup adds another retention path: four autocmd registrations remain after buffer deletion, with callbacks capturing document-associated state.

**Fix:** Break document/editor callback references on retirement while preserving the intended detached-query contract, and remove scope-owned autocmds. Add native weak-reference reclamation and autocmd-cleanup tests.

**ARCH-FUNERAL.**

## 4. Minor findings

None.

## 5. Test coverage notes

- Passed `make test-spec SPEC=chat/document`.
- Passed `make test-spec SPEC=ui/highlights`.
- Passed pinned-range `git diff --check`; checkout remained clean.
- Independent native probes reproduced C1, C2, and I1.
- Existing grouped-undo coverage misses equal-size, shifted-frame semantic corruption. Some rendering tests assert behavior contrary to the Spec.
- Full lifecycle/exchange suites and `make perf` were not rerun in this review.
- No prior findings required disposition.

## 6. Architectural notes

| Principle | Result |
|---|---|
| **ARCH-DRY** | **Pass:** shared index, fold policy, and deferred-work helper consolidate production behavior. |
| **ARCH-PURE** | **Pass:** authority and structural logic remain separate from editor IO; pure state tests need no IO doubles. |
| **ARCH-PURPOSE** | **Flag:** C1–C3 prevent the claimed M3 contract from being complete. |
| **ARCH-MOCK** | **Flag:** the stateful editor seam is useful, but conformance misses the grouped-undo ordering exposed by C1. |
| **ARCH-CONSTRAINTS** | **Pass for inspected bounds:** viewport, batching, and scheduling tests pass; timing claims were not independently remeasured. |
| **ARCH-SECURE** | **Flag:** C1 treats matching extents as evidence of the correct external text. |
| **ARCH-ORDER** | **Flag:** intermediate native callbacks and unconfirmed presentation are mishandled. |
| **ARCH-FUNERAL** | **Flag:** document and callback retirement leaks remain. |

M4’s explicitly assigned generation-writer migration remains future work; it was not treated as missing M3 implementation.

## 7. Plan revision recommendations

Add `## Revisions` entries that:

- Define callback-text evidence across grouped undo/redo, including equal-size intermediate frames.
- Enumerate semantic presentation consumers and their uncertainty behavior.
- Correct all M3 entity paths, statuses, and function names.
- Specify document callback/autocmd retirement and native reclamation verification.

```findings
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Grouped undo can leave the settled index confirming incorrect marker kinds
    detail: |
      lua/parley/document/init.lua:118–149 accepts callback text from matching row/byte extents. Native grouped insertion/deletion followed by undo restored a visible user marker but left its indexed token assistant, confirmed=true, with repair idle. This is the 2nd finding in this family: establish and sweep the callback provenance rule across edit shapes and undo/redo; add native settled-semantic parity regression coverage.
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Unconfirmed semantics still control highlights and native folds
    detail: |
      document/structure.lua:49–59 preserves invalidated render/footer/draft state consumed by highlighter.lua:75–80; tool_folds.lua:260–271 retains affected folds while uncertain. Native reproduction and highlight_typing_spec.lua:44–56 confirm stale question styling after a role change; document_folds_spec.lua:42–47 requires stale folds. This is the 3rd finding in this family: enforce current semantic evidence across presentation consumers and replace assertions contrary to plan section C.
  - id: new
    severity: Critical
    family: deferred-contract-traceability
    title: |
      M3 Core concepts and function declarations disagree with the pinned implementation
    detail: |
      workshop/plans/000254-chat-ownership-concurrency-plan.md:59–72 declares fold_projection.lua and buffer_edit.lua modified at M3, but both are unchanged; indexed projection lives in document/projection.lua and the strategy names nonexistent fold_projection.project. This is the 2nd finding in this family: reconcile the full M3 entity/function inventory and add a Revisions entry. This prose-only correction does not require a wording test.
  - id: new
    severity: Important
    family: scope-owned-callback-cleanup
    title: |
      Detached documents and fold callbacks are not reclaimed
    detail: |
      lua/parley/document/init.lua:176–191 leaves the weak-key registry value holding an editor callback that captures its document key. A native LuaJIT probe retained all 50 deleted documents after repeated full GC. tool_folds.lua also leaves four autocmd registrations after deletion. ARCH-FUNERAL: break retired callback references, remove scope-owned autocmds, and test reclamation through native weak references.
```

---

## Re-review — 2026-09-15T03:30:11-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 2afd7de993dc028c6132df4687695e83dcbb8fe0..976bf963e5c5f9afedea5623529f5597b7a836d0 |
| command | sdlc milestone-close --issue 254 --milestone M3 |
| reviewer | codex |
| timestamp | 2026-09-15T03:30:11-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The four prior findings are addressed, with verified regression evidence. The document and highlight suites pass. One remaining contract violation blocks M3: outline selection treats a surviving row handle as proof that the row remains a valid outline item, even when its semantics are unconfirmed or have changed.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      Native callback-frame regressions pass at head. Restoring pre-fix editor/coordinator code in scratch reproduces the equal-extent undo token mismatch and forbidden callback reads.
  - id: BR-6
    disposition: addressed
    note: |
      Structure queries strip invalidated semantic presentation, and fold maintenance clears uncertain folds. Head regressions pass; restoring pre-fix modules causes three highlight and two fold regression failures.
  - id: BR-7
    disposition: addressed
    note: |
      Plan lines 652–691 explicitly supersede the proposed inventory: document/projection.lua owns indexed projection; fold_projection.lua and buffer_edit.lua are unchanged; exchange_model.lua changes documentation only. The pinned diff and declared functions support these corrections.
  - id: BR-8
    disposition: addressed
    note: |
      Editor detach severs on_event and fold teardown deletes its autocmd group. Native retention tests pass at head; pre-fix scratch code fails four retention cases, including document collection and autocmd cleanup.
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Outline selection accepts surviving identity without current semantic evidence
    detail: |
      lua/parley/outline.lua:139–145 checks only whether Document.lookup returns a row. Native reproduction: select "# heading", replace its preceding "intro" with an opening code fence, then invoke the saved selection. Navigation succeeds while metadata.confirmed=false; after repair, the outline contains zero items but the same selection still succeeds and highlights line 2. This violates Plan section C's confirmed-navigation contract (ARCH-ORDER, ARCH-PURPOSE). This is the 4th finding in family semantic-publication-evidence. State and enforce the rule across consumers: surviving identity establishes location, never current semantic eligibility. Enumerate highlighting, folds, outline selection/navigation, and diagnostics; validate each action's current semantic evidence. Add selection-after-invalidation and selection-after-reclassification regressions.
```

## 1. Strengths

- Native callback admission now distinguishes delivery frames from matching row/byte extents.
- Uncertainty filtering lives in `document/structure.lua:49`, giving consumers a shared conservative query boundary.
- Write-plan tests exercise disjoint writers, delegated slots, stale revisions, and partial failures through both fake and native editors.
- Native reclamation tests cover all production consumers together, including queued callbacks and retained detached facades.

## 2. Critical findings

**Outline selection bypasses semantic validation — `lua/parley/outline.lua:139`.**

`Document.lookup` deliberately returns surviving rows with `confirmed=false`; it also returns confirmed rows that no longer qualify as outline items. Selection checks neither condition.

Fix by validating the selected identity through the current outline projection immediately before navigation. Await repair or report unavailable while uncertain; reject a reclassified item. Preserve navigation when unrelated edits merely relocate a valid item.

The native reproduction is available in [the scratch probe](/tmp/parley254-outline-review.lua).

## 3. Important findings

None additional.

## 4. Minor findings

None.

## 5. Test coverage notes

- Passed `make test-spec SPEC=chat/document`.
- Passed `make test-spec SPEC=ui/highlights`: **85 tests**.
- Confirmed BR-5/6/8 regression failures against pre-fix modules in an isolated scratch copy.
- Existing tests miss delayed outline selection after semantic invalidation and reclassification.
- Did not rerun the complete repository suite or full `make perf`.
- The reviewed checkout remains unchanged.

## 6. Architectural notes

| Principle | Result |
|---|---|
| **ARCH-DRY** | Pass: shared structural queries and timer lifecycle replace separate consumer ownership. |
| **ARCH-PURE** | Pass: indexed structure and grant decisions remain separate from editor IO. |
| **ARCH-PURPOSE** | **Flag:** outline selection does not enforce the confirmed-consumer contract. |
| **ARCH-MOCK** | Pass: stateful editor doubles share the production seam; native tests check their assumptions. |
| **ARCH-CONSTRAINTS** | Pass for inspected M3 paths: bounded reads, repair slices, and native fold batches have coverage. |
| **ARCH-SECURE** | Pass for inspected text/ownership boundaries: uncertain text cannot manufacture write authority. |
| **ARCH-ORDER** | **Flag:** delayed outline selection uses identity captured before a semantic change without revalidating eligibility. |
| **ARCH-FUNERAL** | Pass: native tests verify callback, document, timer, and fold-autocmd retirement. |

Atlas changes cover the introduced architecture. No new command, keybinding, or configuration surface requiring a README update was identified.

## 7. Plan revision recommendations

Add a `## Revisions` entry defining **location versus semantic eligibility** for delayed consumer actions. Enumerate the presentation/navigation consumers and their validation points, and require native tests for outline selections during uncertainty, after reclassification, and after harmless relocation.

---

## Re-review — 2026-09-15T04:00:29-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 2afd7de993dc028c6132df4687695e83dcbb8fe0..654687ddbb310880b10a3ce5713588c326a1a15b |
| command | sdlc milestone-close --issue 254 --milestone M3 |
| reviewer | codex |
| timestamp | 2026-09-15T04:00:29-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-9’s outline correction is supported by passing regressions that fail when the fix is removed. The shared document boundary, native undo handling, and retirement tests also hold up. One blocking publication race remains: a reentrant diagnostic callback invalidates the current job, but its publisher subsequently erases that invalidation, leaving obsolete diagnostics indefinitely. The repository was unchanged; tests and reproductions ran in an isolated archive of the pinned head.

```findings
dispose:
  - id: BR-9
    disposition: addressed
    note: |
      outline.lua now checks current projection eligibility and revalidates after focus callbacks. Removing the fix in scratch produces six outline failures; removing the diagnostic correction also fails the pending-publication regression.
  - id: BR-5
    disposition: addressed
    note: |
      Native callback-frame admission is enforced in document/editor.lua; all four native-history regressions pass against the pinned head.
  - id: BR-6
    disposition: addressed
    note: |
      Semantic presentation uses confirmed document evidence. The six highlighter-document and seven document-fold integration cases pass, including uncertainty handling.
  - id: BR-7
    disposition: addressed
    note: |
      The plan's M3 inventory revision explicitly supersedes proposed locations and identifies unchanged fold_projection/buffer_edit modules and the documentation-only exchange_model change; these statements match the pinned diff.
  - id: BR-8
    disposition: addressed
    note: |
      Editor retirement breaks its coordinator callback reference, and fold teardown removes owned callbacks. All five document-retention regressions pass.
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Reentrant diagnostic publication overwrites a newer invalidation
    detail: |
      lua/parley/diagnostic_refresh.lua:127–133 publishes through vim.diagnostic.set, which synchronously runs DiagnosticChanged callbacks. A callback editing the source sets s.job=nil and s.dirty=true through the subscription at line 185, but the returning publisher unconditionally resets s.dirty=false. A native regression removing the timestamp during publication leaves one obsolete diagnostic after repair/drain reports idle. ARCH-ORDER, ARCH-PURPOSE: this is the 5th finding in family semantic-publication-evidence. Earlier rounds fixed instances; enforce the class-wide rule that an effect completion may commit only while its captured job and eligibility remain current. Enumerate highlighting, fold recreation, outline navigation, and diagnostic publication across callback boundaries; preserve newer invalidation and stop superseded effects.
```

## 1. Strengths

- Outline selection distinguishes identity from eligibility and checks again after focus callbacks.
- Ownership state is private, with explicit transitions and bounded generation/grant admission.
- Native history, write-plan, scheduler, and retention tests exercise real ordering and independently check outcomes.
- Atlas and tooling document the new coordinator, projections, work bounds, and staged M4 migration.

## 2. Critical findings

**Diagnostic publication loses reentrant invalidation** — [diagnostic_refresh.lua:127](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/diagnostic_refresh.lua:127).

Reproduction:

1. Prepare publication for a buffer containing one timestamp.
2. Register a one-shot `DiagnosticChanged` callback that replaces it with `no timestamp`.
3. Publish, then drain document and diagnostic work.
4. Drain reports `idle`, but one timestamp diagnostic remains.

Fix sketch: capture publication ownership, recheck it after each callback-capable effect, and clear dirty state only if that same job remains current. Preserve edits, reloads, and detach events observed during publication.

The failing native regression is available in [review_reentrant_spec.lua](/tmp/parley-m3-review-v404f4cp/tests/integration/review_reentrant_spec.lua).

## 3. Important findings

None additional.

## 4. Minor findings

None.

## 5. Test coverage notes

- Passed the complete `ui/outline` mapping and **77 additional focused cases** covering diagnostics, native history, retention, ownership, folds, highlighting, scheduling, projections, and write plans.
- Removing BR-9’s executable correction caused **six outline failures and one diagnostic failure**.
- The new reentrant-publication regression fails on the pinned head: expected zero diagnostics, observed one.
- Full-suite and performance benchmark results were not independently rerun.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | Pass: shared projection and deferred-work ownership consolidate live consumers. |
| ARCH-PURE | Pass: ownership/projection logic is separated from native editor effects; pure tests need no IO doubles. |
| ARCH-PURPOSE | **Flag:** current publication evidence is still lost across a reentrant effect. |
| ARCH-MOCK | Pass: injected stateful editor seam plus native conformance tests. |
| ARCH-CONSTRAINTS | Pass in inspected scope: explicit page, byte, grant, and scheduling bounds; no independent latency certification. |
| ARCH-SECURE | Pass in inspected scope: callback provenance and exact write receipts are checked; review tests used isolated storage. |
| ARCH-ORDER | **Flag:** a superseded publisher can overwrite newer authoritative job state. |
| ARCH-FUNERAL | Pass: timer, document, and fold callback retirement have passing native tests. |

The revised M3 inventory matches the delivered module boundaries. Atlas updates cover the architectural surface; no new command, keybinding, or configuration key requiring a README update was identified.

## 7. Plan revision recommendations

Add a `## Revisions` entry defining **publication ownership across reentrant effects**: enumerate the four semantic consumers, identify callback-capable effects, and require captured-job validation before subsequent effects or completion commits. Include native sequences for edit, reload, and detach during diagnostic publication.
