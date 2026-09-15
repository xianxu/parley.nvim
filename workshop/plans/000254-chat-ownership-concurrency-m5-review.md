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
