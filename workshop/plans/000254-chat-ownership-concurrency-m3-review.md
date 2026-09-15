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
