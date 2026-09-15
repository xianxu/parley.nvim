# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M5)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | 8c40b9c637acfb5763ba339e8e2d5d5d5783d46b..cebb38ebe0755f3af54b5603c0864969af1c4d33 |
| command | sdlc milestone-close --issue 254 --milestone M5 |
| reviewer | codex |
| timestamp | 2026-09-15T11:41:52-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The batch implementation preserves captured identities, uses the shared response lifecycle, and has strong ordering tests. Recovery is not ready for M5 close: ordinary successful replacements miss settlement, failed replacements cannot follow the promised retry path, and a corrupt sole snapshot can be treated as absent. Five additional regression assertions fail against the pinned head. Repository files were left unchanged.

## 1. Strengths

- Batch state is private, immutable to callers, and tested across generated histories, cancellation, duplicate completion, and explicit resume.
- Regional revision proofs distinguish question edits from answer changes and reject edit/undo ABA without invalidating unrelated questions.
- Recovery publication checks writes, close, rename, and directory synchronization. Stateful filesystem tests cover partial failures and ambiguous descriptor ownership.
- README, atlas pages, and test mappings accompany the new commands and concepts.

## 2. Critical findings

1. **Successful replacement misses recovery settlement.** [chat_respond.lua:1653](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/chat_respond.lua:1653) attempts settlement while structural repair is pending, then permanently proceeds past it. A normal completed response followed by a confirmed save retains its snapshot. Preserve an edit-fenced settlement obligation through bounded repair.

2. **Failure retirement breaks retry association.** [chat_recovery.lua:145](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/chat_recovery.lua:145) removes the association needed to retain the original across retries. The next attempt compares partial output against the original replacement evidence and refuses. Retain bounded association metadata separately from retired write authority.

3. **Corruption can manufacture a new “original.”** [answer_recovery.lua:117](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/answer_recovery.lua:117) blocks a corrupt record’s key only when a readable sibling supplies it. With the sole record corrupted, publication accepts partial output as a fresh original. Unknown association must not imply absence.

## 3. Important findings

4. **Detach leaves recovery registry ownership behind.** [response_recovery.lua:62](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/response_recovery.lua:62) releases the adapter, but the host’s `entries[job]` still retains its document and store. Route retirement through both ownership layers.

5. **Cleanup failures disappear at the UI boundary.** [chat_recovery.lua:174](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/chat_recovery.lua:174) ignores failed save cleanup; settlement also ignores `cleanup_error` returned by the store. Surface storage failures while retaining their accounting.

## 4. Minor findings

None.

## 5. Test coverage notes

Verified against the pinned head:

- `chat/batch`: **87 passed**
- `chat/recovery`: **65 passed**
- `chat/lifecycle`: **722 passed across 58 files**
- `git diff --check`: passed

Scratch regressions reproduced all five findings:

- [/tmp/m5_review_save_spec.lua](/tmp/m5_review_save_spec.lua): confirmed save leaves one snapshot.
- [/tmp/m5_review_retry_spec.lua](/tmp/m5_review_retry_spec.lua): adding the production failure callback breaks the existing retry test.
- [/tmp/m5_review_corrupt_spec.lua](/tmp/m5_review_corrupt_spec.lua): sole-record corruption permits publication.
- [/tmp/m5_review_cleanup_spec.lua](/tmp/m5_review_cleanup_spec.lua): cleanup error visibility and registry retirement both fail.

There are no prior findings to dispose of.

## 6. Architectural notes

| Principle | Result |
|---|---|
| ARCH-DRY | Pass: shared Document proofs and single-response execution replace ordinal recursion. |
| ARCH-PURE | Pass for declared PURE entities: batch decisions require no IO mocks; adapters perform IO. |
| ARCH-PURPOSE | Flag: successful-save cleanup and failure retry do not deliver the documented recovery contract. |
| ARCH-MOCK | Pass: stateful filesystem faults and controlled provider callbacks share production seams; isolated native publication is tested. |
| ARCH-CONSTRAINTS | Pass for tested bounds: scheduled proof queries and storage admission have explicit limits. |
| ARCH-SECURE | Flag: corrupt persisted association becomes apparent absence. |
| ARCH-ORDER | Flag: pending settlement and failed-attempt association are retired prematurely. |
| ARCH-FUNERAL | Flag: completed snapshots and detached host entries lack effective automatic retirement in the reproduced paths. |

## 7. Plan revision recommendations

Add `## Revisions` entries defining:

- Completion evidence retained while semantic repair is pending, including intervening edits and teardown.
- Separate lifetimes for write authority, retry association, settlement evidence, and host registry membership.
- Conservative admission when quarantined records have unknown associations.
- A common policy for reporting publication and cleanup failures.

Keep M5 open until these regressions pass. Add the new recovery/controller adapters to the integration inventory when recording the corrected implementation.

```findings
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Successful replacement abandons settlement while semantic repair is pending
    detail: |
      lua/parley/chat_respond.lua:1653 and lua/parley/chat_recovery.lua:141 attempt settlement once, then release completion despite an unconfirmed exchange. A public response followed by confirmed save leaves its snapshot retained. This is the 10th finding in family semantic-publication-evidence. Fix the rule across single and batch completion: retain edit-fenced evidence until bounded settlement succeeds or a real conflict invalidates it; test repair, edits, cancellation and detach.
  - id: new
    severity: Critical
    family: recovery-retry-association
    title: |
      Provider failure removes the association required for retrying partial replacements
    detail: |
      lua/parley/chat_recovery.lua:145 releases the runtime association on failure; lines 115–118 then require partial output to match the original persisted replacement bytes. Adding C.finish(job,'provider_failed') to the existing retry fixture makes retry refuse. Separate bounded retry association from retired grants and verify public failure/cancellation followed by single retry and batch resume.
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Corruption of the sole recovery record permits partial output to become a new original
    detail: |
      lua/parley/answer_recovery.lua:117–122 derives blocked keys only from readable sibling records. Corrupting the sole committed record makes a same-key retry publish successfully with partial bytes. This is the 11th finding in family semantic-publication-evidence. ARCH-SECURE/ARCH-ORDER require unknown persisted evidence never to imply absence; sweep sole-record, all-revisions-corrupt, quarantine and restart cases under one conservative admission rule.
  - id: new
    severity: Important
    family: scope-owned-callback-cleanup
    title: |
      Recovery adapter retirement leaves the host registry retaining detached documents
    detail: |
      lua/parley/response_recovery.lua:62–64 releases only adapter state; lua/parley/chat_recovery.lua:135 retains entries containing the document and store until separate host cleanup. A detach regression confirms the entry remains after status becomes released. This is the 4th finding in family scope-owned-callback-cleanup. ARCH-FUNERAL: define one retirement rule covering every recovery ownership layer and sweep detach, reload, wipeout and failed settlement.
  - id: new
    severity: Important
    family: lifecycle-state-observability
    title: |
      Recovery cleanup IO failures are swallowed by production callers
    detail: |
      lua/parley/chat_recovery.lua:174 ignores failed RR.saved results, and lua/parley/chat_respond.lua:1655 ignores successful settlement results carrying cleanup_error. Injected unlink EACCES during confirmed-save cleanup produces no notification. This is the 2nd finding in family lifecycle-state-observability. Define and enforce one error-publication rule across save cleanup, superseded-record cleanup, discard and deletion; retain physical accounting and test visible outcomes.
```

---

## Re-review — 2026-09-15T12:10:21-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | 8c40b9c637acfb5763ba339e8e2d5d5d5783d46b..b07a6c5d4768794825a3a39237026cd567827713 |
| command | sdlc milestone-close --issue 254 --milestone M5 |
| reviewer | codex |
| timestamp | 2026-09-15T12:10:21-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Three prior findings are addressed with regression evidence. BR-20 and BR-24 remain partially unresolved: saves arriving before settlement are forgotten, and saved-file probe failures remain silent. Both reproduce against the pinned head. Repository files were unchanged.

## 1. Strengths

- Batch execution preserves captured identities, validates revisions, and shares the single-response lifecycle.
- Failed-attempt retry metadata survives retirement without retaining write grants.
- Corrupt recovery records now conservatively block publication, including across restart and failed quarantine.
- README, atlas pages, and traceability mappings cover the new batch and recovery surfaces.

## 2. Critical findings

**BR-20 — not-addressed: save-before-settlement remains uncovered.**  
[chat_recovery.lua:295](lua/parley/chat_recovery.lua#L295) ignores saves unless the job is already `settled`. The settlement callback at line 229 never revisits an earlier save.

Reproduction: publish → replace → queue settlement → execute real `:write` → settlement succeeds → finish successfully. One snapshot remains instead of zero.

**Fix:** model successful settlement and confirmed-save evidence as an ordering-independent join. Retain pending save evidence and validate it when settlement completes. Cover both event orders, edits, cancellation, and teardown across single and batch execution. This remains BR-20 in `semantic-publication-evidence`, not a new finding. **ARCH-ORDER, ARCH-PURPOSE, ARCH-FUNERAL.**

## 3. Important findings

**BR-24 — not-addressed: saved-file probe errors are swallowed.**  
[chat_recovery.lua:298](lua/parley/chat_recovery.lua#L298) discards the error returned by `fs_stat`; line 299 silently returns. Injecting `EACCES` produces zero notifications while retaining the snapshot.

**Fix:** route saved-file probe failures through the common reporting rule, preserving physical accounting. Sweep every save-cleanup IO stage, including stat and read-back. This remains BR-24 in `lifecycle-state-observability`.

## 4. Minor findings

None.

## 5. Test coverage notes

Pinned-head validation passed:

| Suite | Passed |
|---|---:|
| `chat/recovery` | 84 |
| `chat/batch` | 92 |
| `chat/lifecycle` | 722 across 58 files |

`git diff --check` passed.

Scratch copies using the pre-fix implementation made the committed corruption, retry, settlement, registry-retirement, and cleanup-notification regressions fail.

Two additional pinned-head regressions fail in [the scratch spec](/tmp/parley-m5-save-order-spec.lua:357): save-before-settlement and failed saved-file stat. The existing 32 tests in that spec pass.

## 6. Architectural notes

| Marker | Result |
|---|---|
| ARCH-DRY | Pass — shared response lifecycle, revision proofs, and reporting helper. |
| ARCH-PURE | Pass — batch decisions remain IO-free; adapters own effects. |
| ARCH-PURPOSE | Flag — BR-20 leaves successful-save cleanup incomplete. |
| ARCH-MOCK | Pass — controlled provider callbacks and stateful filesystem faults exercise production seams. |
| ARCH-CONSTRAINTS | Pass — tested query budgets and storage admission limits. |
| ARCH-SECURE | Pass — corrupt association no longer implies absence. |
| ARCH-ORDER | Flag — confirmed save arriving before settlement is discarded. |
| ARCH-FUNERAL | Flag — that ordering strands a snapshot until another save or explicit cleanup. |

## 7. Plan revision recommendations

Add `## Revisions` entries specifying:

- Settlement and confirmed-save evidence must converge in either arrival order, with explicit invalidation rules.
- Every failed cleanup IO stage must publish an actionable error while retaining recovery accounting.

```findings
dispose:
  - id: BR-20
    disposition: not-addressed
    note: |
      Delayed settlement now works, but chat_recovery.lua:295 ignores a confirmed save while settlement is queued, and settlement completion never revisits it. A native-write scratch regression leaves one snapshot after successful settlement. Preserve and join save/settlement evidence in either order; ARCH-ORDER, ARCH-PURPOSE, ARCH-FUNERAL.
  - id: BR-21
    disposition: addressed
    note: |
      Bounded revision-checked retry metadata survives failed-attempt retirement. Public single/batch failure and cancellation retry tests pass; runtime retry and public batch retry regressions fail against the pre-fix implementation.
  - id: BR-22
    disposition: addressed
    note: |
      Unknown corrupt association blocks new publication. All five committed sole-record, all-revisions, quarantine, failed-quarantine, and unknown-name regressions pass at head and fail against the pre-fix implementation.
  - id: BR-23
    disposition: addressed
    note: |
      Adapter release now invokes host retirement and cancels pending settlement. Detach registry assertions pass at head and fail against the pre-fix implementation; cancellation, reload, and failed-settlement retirement tests also pass.
  - id: BR-24
    disposition: not-addressed
    note: |
      Unlink failures now notify, with a regression that fails without the fix. However, chat_recovery.lua:298-299 discards saved-file fs_stat errors and silently returns. Injected EACCES yields zero notifications. Apply the common error-publication rule to every cleanup IO stage.
```

---

## Re-review — 2026-09-15T12:26:49-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M5 |
| milestone | M5 |
| window | 8c40b9c637acfb5763ba339e8e2d5d5d5783d46b..b4cf59a0a64135c85245e07518e0264bbb49d554 |
| command | sdlc milestone-close --issue 254 --milestone M5 |
| reviewer | codex |
| timestamp | 2026-09-15T12:26:49-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned M5 range delivers fixed batch membership and recoverable answer replacement. Both open findings are addressed with reachable production changes and regression tests that fail when those changes are disabled. All 14 changed test files pass: 222 tests. No new blocking findings identified. Review scope is M5; this does not establish M6 readiness.

```findings
dispose:
  - id: BR-20
    disposition: addressed
    note: |
      chat_recovery.lua retains save evidence and joins it with guarded settlement; chat_respond.lua waits for settlement before completing. Disabling the join in a scratch copy fails six recovery tests and both public single/batch early-save tests. Edit/undo, cancellation, reload, detach, and disjoint-edit cases pass.
  - id: BR-24
    disposition: addressed
    note: |
      The shared recovery reporter publishes cleanup errors and saved-file stat/read failures while retaining physical accounting. Disabling stat-error reporting fails two regression tests. Save unlink failure, repeated-error suppression, and retained-byte tests pass.
  - id: BR-21
    disposition: addressed
    note: |
      Public single/batch failure and cancellation retry tests preserve the original snapshot identity and bytes; fresh revision evidence rejects affected edit/undo while allowing disjoint draft edits.
  - id: BR-22
    disposition: addressed
    note: |
      Store scanning distinguishes unavailable association evidence from absence and blocks unsafe original publication. Corruption, restart, and failed-quarantine regression cases pass.
  - id: BR-23
    disposition: addressed
    note: |
      Adapter release invokes host retirement, removes registry membership, and cancels pending settlement. Detach and retained-snapshot lifetime regression cases pass.
```

### 1. Strengths

- **Completion preserves evidence across event ordering.** `chat_recovery.lua:198` and `:331` retain guarded settlement and confirmed-save observations; public single/batch tests exercise the join.
- **Batch progress has one pure owner.** `batch.lua` encapsulates membership and transitions; tests cover stale events, cancellation races, unknown outcomes, and independently stated progress invariants.
- **Recovery publication is checked before destructive replacement.** `answer_recovery.lua` tests short writes, durability failures, corruption, ambiguous closes, descriptor reuse, and physical capacity.
- **User documentation covers the new surface.** README links to batch and recovery guides documenting resume, explicit adoption, restore, and retention behavior.

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

None.

### 5. Test coverage notes

- Ran all 14 changed spec files against the pinned head: **222 passed**.
- Scratch mutations confirmed BR-20 and BR-24 regressions fail without their fixes.
- Tests use isolated storage, stateful filesystem doubles, controlled callbacks, and real Neovim save events.
- Did not rerun the entire repository suite or performance report. The unrelated working-tree modification was left untouched.

### 6. Architectural notes

| Marker | Result | Evidence |
|---|---|---|
| ARCH-DRY | Pass | Single and batch responses share generation and recovery paths. |
| ARCH-PURE | Pass | Batch decisions remain IO-free; Document and recovery adapters execute effects. |
| ARCH-PURPOSE | Pass | Fixed membership, revision validation, partial progress, and original-answer recovery are implemented. |
| ARCH-MOCK | Pass | Stateful filesystem faults share the production seam; isolated native filesystem tests check real behavior. |
| ARCH-CONSTRAINTS | Pass | Scheduled validation enforces aggregate query budgets; recovery enforces serialized and physical limits. |
| ARCH-SECURE | Pass | Persisted records are validated; corruption cannot establish absence or authorize replacement. |
| ARCH-ORDER | Pass | Production transitions and save/settlement joins have cancellation, late-event, and interruption coverage. |
| ARCH-FUNERAL | Pass | Document retirement releases volatile ownership; saved, discarded, and deleted snapshots have cleanup paths with failure accounting. |

M6’s documented tool-path exclusion and effect-admission work remains outside this verdict.

### 7. Plan revision recommendations

None required for the reviewed corrections. Existing revisions describe the implemented evidence join and retirement rules.
