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

---

## Re-review — 2026-09-15T07:59:45-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 2afd7de993dc028c6132df4687695e83dcbb8fe0..d349c02e70b5c18e2ee2d689bdd9a82616a9600a |
| command | sdlc milestone-close --issue 254 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-15T07:59:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

BR-10 is addressed with real regression evidence: the diagnostic publisher now captures its job and re-checks ownership after every callback-capable effect, and the same rule was swept into folds, outline, and highlights. Reverting only the BR-10 production files in a scratch archive of the head turns 7 of 9 diagnostic-reentrancy cases and 3 of 4 native fold-reentrancy cases red, so the fix is reachable. The full chat/document mapping (29 files), ui/highlights, and ui/outline all pass at head, and the checkout is clean. Two gaps remain, both introduced by the BR-10 fix's new supersession exits in the native fold path and both reproduced in a scratch Neovim: a superseded slice skips restoring the operator's `foldenable`, and an aborted window configuration leaves a truncated plan that the next slice reports as idle with no folds created. Both are narrow (they need an operator OptionSet autocmd that synchronously edits the buffer) and cheap to fix, so they do not block the gate.

## 1. Strengths

- `lua/parley/diagnostic_refresh.lua:119-149` implements the class rule cleanly: one `current(s,job)` predicate, checked after materialization, after each `vim.diagnostic.set`, and before the single commit of `s.job=nil;s.dirty=false`. The clear path (`:236-244`) also yields to a replacement refresh started inside its own DiagnosticChanged callback.
- `tests/integration/diagnostic_reentrancy_spec.lua` asserts independent invariants (zero diagnostics after drain reports idle, replacement refresh survives clear, recursive step reports busy, reload fences the old publisher) rather than restating the implementation. Confirmed red without the fix.
- `tests/integration/document_presentation_reentrant_spec.lua:66-85` proves the highlighter's textlock assumption natively instead of asserting it in prose.
- Plan revision "Publication ownership across reentrant effects (BR-10)" enumerates all four consumers with their callback boundary and completion rule, and `atlas/chat/document.md` gained a matching "Reentrant consumer effects" section. The BR-7 inventory table still matches the pinned diff (exchange_model and chat_parser comment-only, fold_projection and buffer_edit untouched, exchange_anchors deleted).
- The issue log discloses the post-BR-10 benchmark and the broad-repair timing anomaly honestly, including the controlled JIT comparison, rather than claiming a latency guarantee.

## 2. Critical findings

None.

## 3. Important findings

**I1. Superseded fold slices skip restoring the operator's `foldenable` and window view** — `lua/parley/tool_folds.lua:387-390` and `:116-121`. ARCH-ORDER, ARCH-FUNERAL lens on captured state. Inside the `nvim_win_call`, the slice sets `vim.wo.foldenable=true`, then on the way out checks `current()` *before* restoring `foldenable` and calling `winrestview`. If an OptionSet callback edits the buffer (tick changes), the slice bails with the operator's setting still forced on. The discarded plan is then rebuilt, and `apply` captures `enabled` from the now-leaked value, so the preference is permanently flipped. The same ordering exists in `clear_folds_in_span` after `nvim_exec2`. Native reproduction: operator sets `foldenable=false`, an OptionSet(foldenable) autocmd performs an inert edit during `apply_folds`; after flush `foldenable` reads `true` (control without the edit reads `false`). This contradicts the code's own comment ("Restore both even if the walk fails") and the atlas contract that cancellation restores operator fold preferences. Sibling site: the `break` in `discard_plan`/`discard_uncertainty` (`:230-234`, `:295-298`) abandons still-suspended windows on the >50k-row path, leaving `foldenable=false` and letting the next plan capture it as the operator's preference.

  **This is the 2nd finding in family `scope-owned-callback-cleanup`.** Earlier rounds fixed instances. Do not fix only this line. Rule: state a slice alters on the operator's behalf (window options, view) is that slice's own cleanup and must be restored on every exit path, superseded or not; only *job output* effects (fold creation, diagnostic publication, dirty-state commit) are gated on ownership. Sweep: `apply` win_call tail, `clear_folds_in_span` tail, both discard loops, `release_window` callers. Add a native regression: operator `foldenable=false`, callback edit during a slice, assert the preference survives.

**I2. An aborted window configuration leaves a truncated plan that the next slice reports as complete** — `lua/parley/tool_folds.lua:315-325`. ARCH-ORDER. `apply` assigns `plan.windows={}` and then loops over windows calling `configure(win,current)`; when `current()` fails because of a tick change alone (an inert edit in an OptionSet callback, which neither marks nor discards the plan), it returns `'more'` with a partially built or empty `plan.windows`. The next step revalidates the certificate (still valid after an equal-byte inert edit), finds no window at `plan.window`, returns `'idle'`, and `M.step:416` clears `s.first/s.last`. No fold is ever created and nothing reschedules until the next semantic edit. Native reproduction: OptionSet(foldminlines) autocmd performs an inert same-length edit on the apply-phase configure; `flush` returns `idle` twice with `foldlevel(3)==0` (control gives `1`), and a further inert edit does not recover it.

  **This is the 6th finding in family `semantic-publication-evidence`.** Earlier rounds fixed instances. Do not fix only this site. Rule: when a slice learns it is superseded, its exit must either discard the job or leave it resumable from the same point; completion may be claimed only from evidence gathered under the captured tick and ownership, never from state the abort itself produced. Enumerate every `if not current() then return ... end` exit in `tool_folds.lua` and classify it: `apply:319` (truncated windows, this finding), `apply:398` (window stays `done`, re-enters the create branch and emits a duplicate `reconcile` notification), `clear_uncertainty:273/279/284` (resumes from the same window, acceptable), `M.setup:571` (returns without `schedule`, see Minor). Fix the class by building the window list locally and committing it only when every configure succeeded, or by discarding the plan on any configure abort. Add a native regression asserting folds exist after an inert edit inside the apply-phase OptionSet.

## 4. Minor findings

- ARCH-DRY: the six identical VimL ownership guard lines in `clear_folds_in_span` (`:69-92`) should be one `s:live()` function; the three identical `current` closures passed to `configure` (`:520`, `:526`, `:569`) and the near-identical `discard_plan`/`discard_uncertainty` loops should share a helper.
- `lua/parley/tool_folds.lua:568-571`: `M.setup` returns before `schedule(buf,s)` if a window becomes invalid mid-configure, so remaining windows get no folds until the next event.
- `lua/parley/document/init.lua:16-18`: `notify` iterates `pairs(s.subscribers)` while a callback may `Document.subscribe`; inserting a new key during `next` traversal is undefined in Lua. Snapshot the callbacks before iterating.
- Test placement: `deferred_work_spec`, `document_coordinator_spec`, `document_write_plan_spec`, `document_identity_spec`, `diagnostic_refresh_spec`, and `outline_spec` live in `tests/unit/` but drive real buffers or timers. They test INTEGRATION entities correctly; they just contradict the plan's "unit = no Neovim or IO" convention.
- `b:parley_fold_generation` is a shared buffer variable any plugin can overwrite; the code fails closed (walk stops), which is the right direction, but a non-numeric value silently halts all fold maintenance for that buffer.

## 5. Test coverage notes

| Run | Result |
|---|---|
| `make test-spec SPEC=chat/document` | 29 files, no failures |
| `make test-spec SPEC=ui/highlights` | pass |
| `make test-spec SPEC=ui/outline` | pass |
| BR-10 revert in scratch archive: `diagnostic_reentrancy_spec` | 7 of 9 fail |
| BR-10 revert in scratch archive: `document_presentation_reentrant_spec` | 3 of 4 fail |
| `git diff --check` on the range | clean |

Not independently rerun: full suite, `make perf`. The issue log records a 30-scenario benchmark on `b62c2b59` and discloses the broad-repair timing question. No existing test covers the I1 or I2 exits; both were found by scratch native probes.

## 6. Architectural notes

| Principle | Result |
|---|---|
| ARCH-DRY | Flag (Minor): guard and closure duplication in `tool_folds.lua`. |
| ARCH-PURE | Pass: `state.lua` and `projection.lua` unit tests use no IO; ownership predicates are small closures over IO state. |
| ARCH-PURPOSE | Pass with I1/I2: the BR-10 rule was swept across all four consumers; the two remaining gaps are in the sweep's own exit paths, not unswept consumers. |
| ARCH-MOCK | Pass: `fake_document_editor.lua` is a stateful double behind the driver seam, with native conformance tests alongside. |
| ARCH-CONSTRAINTS | Pass: bounds unchanged; benchmark on the fix commit exists. The native walk now evaluates six guards per fold group; `normal!` commands inside a script cannot fire autocmds, so most of those checks are cost without coverage. |
| ARCH-SECURE | Pass: the VimL command is built from numeric arguments only; buffer-variable tampering fails closed. |
| ARCH-ORDER | Flag: I1 and I2 are supersession exit paths that leave state neither restored nor resumable. |
| ARCH-FUNERAL | Pass: generation scalar removed on detach, timers closed, per-window caches cleared on WinClosed. |

For M4: the generation writer will add another effect owner to this pattern. Consider a single `slice(owner, body, finally)` helper in `tool_folds`/`diagnostic_refresh` that runs `finally` unconditionally and gates only `body`'s commits, so the next consumer cannot repeat I1.

## 7. Plan revision recommendations

Add a "## Revisions" entry, "Supersession exit paths", stating: (1) operator state altered by a slice is restored on every exit, superseded or not; (2) a superseded slice discards its job or leaves it resumable, and completion is never derived from abort-produced state; (3) the enumerated abort sites in `tool_folds.lua` and their classification; (4) native regressions for operator `foldenable` survival and folds-after-inert-edit-in-configure.

```findings
dispose:
  - id: BR-10
    disposition: addressed
    note: |
      diagnostic_refresh.lua captures the job and rechecks current() after materialization, each diagnostic set, and before the single dirty commit; clear yields to a replacement refresh. Reverting only the fix files in a scratch archive fails 7 of 9 diagnostic and 3 of 4 fold reentrancy regressions.
findings:
  - id: new
    severity: Important
    family: scope-owned-callback-cleanup
    title: |
      Superseded fold slices skip restoring operator foldenable and window view
    detail: |
      lua/parley/tool_folds.lua:387-390 and :116-121 check current() before restoring foldenable and winrestview, so a callback edit during a slice leaves foldenable forced on; the rebuilt plan then captures the leaked value as the operator preference. Native reproduction: foldenable=false plus an inert edit in an OptionSet(foldenable) autocmd yields foldenable=true after flush (control stays false). This is the 2nd finding in family scope-owned-callback-cleanup: restore slice-altered operator state on every exit path and gate only job-output effects on ownership; sweep apply, clear_folds_in_span, and both discard loops, which also abandon suspended windows on the >50k-row path.
  - id: new
    severity: Important
    family: semantic-publication-evidence
    title: |
      Aborted window configuration leaves a truncated plan that reports idle with no folds
    detail: |
      lua/parley/tool_folds.lua:315-325 assigns plan.windows={} then returns 'more' when configure(win,current) fails on a tick-only change; the next slice finds no window, returns 'idle', and M.step:416 clears s.first. Native reproduction: an inert same-length edit inside an OptionSet(foldminlines) autocmd during the apply-phase configure leaves foldlevel(3)==0 across repeated flushes (control gives 1). This is the 6th finding in family semantic-publication-evidence: a superseded slice must discard its job or leave it resumable, and completion may only be claimed from evidence gathered under the captured ownership. Enumerate every current() exit in tool_folds.lua (apply:319, apply:398, clear_uncertainty:273/279/284, setup:571) and fix the class, not the site.
```
