# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M6)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M6 |
| milestone | M6 |
| window | 4e8088ecefd6a3c4187dc8e76868fd6a8c9d1a31..0377362ca3911e4b4aad17b47c05f793e4180f97 |
| command | sdlc milestone-close --issue 254 --milestone M6 |
| reviewer | codex |
| timestamp | 2026-09-15T12:34:37-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The pinned range delivers substantial async execution, ownership, admission, and documentation work. I independently ran 13 specs: **144 assertions passed**, with no failures. However, native probes reproduced three correctness gaps: escaped path authority, stale open buffers after successful writes, and unmarked truncated results. These block M6 closure. Repository files were left unchanged.

## 1. Strengths

- Operation/resource reducers enforce scoped identity, atomic claims, duplicate handling, and retained uncertainty.
- Cancellation transfers ownership explicitly through `operation_supervised`; operator evidence cannot fabricate physical cleanup.
- Stateful filesystem tests exercise partial writes, missing callbacks, cancellation boundaries, and ambiguous descriptor closure.
- README and atlas document the new commands, custom-tool compatibility change, limits, and supervision model. The final M6 entity inventory matches the inspected modules.

## 2. Critical findings

### C1 — Captured paths can escape their authority before execution

**Locations:** `lua/parley/tools/dispatcher.lua:431`, `lua/parley/tools/filesystem.lua:157`.

Preparation canonicalizes paths, but execution later establishes its first revision from the pathname without revalidating its ancestors against captured authority.

**Reproduction:** Start a production producer read of `allowed/child/file`, then rename `child` and replace it with a symlink to an outside directory before scheduled execution. The result successfully contained `OUTSIDE_SECRET`. Leaf `lstat`/`fstat` checks agree because both inspect the newly redirected target.

**Fix:** Bind resource authority to identity evidence that remains valid at execution. Sweep reads, writes, backup destinations, directory creation, and subprocess traversal; a queued canonical string must not authorize a redirected resource. Add controlled ancestor-replacement tests. **ARCH-SECURE, ARCH-ORDER.**

### C2 — Async file mutations omit open-buffer refresh

**Location:** `lua/parley/tools/async_builtin.lua:109`.

The async path returns success immediately after checked filesystem completion without the editor refresh performed by the retained handlers (`write_file.lua:63`, `edit_file.lua:175`, `propose_edits.lua:84`).

**Reproduction:** With an open, unmodified, `autoread` buffer containing `old`, all three synchronous handlers update it to `changed`. All three async implementations successfully change disk contents while the buffer remains `old`.

**Fix:** Restore a shared, ownership-safe completion/refresh path for all three writers. Preserve intervening human edits and surface reconciliation when refreshing is unsafe. Test both unchanged and concurrently edited buffers. **ARCH-PURPOSE, ARCH-ORDER.**

### C3 — Scheduler truncation disappears from published evidence

**Locations:** `lua/parley/tools/scheduler.lua:63`, `lua/parley/tools/dispatcher.lua:245`, `lua/parley/response_tools.lua:84`.

The scheduler cuts content and sets `truncated=true`. Normalization adds a textual marker only when the already-cut content exceeds its budget; response projection drops the flag.

**Reproduction:** A production `read_file` of 600,000 bytes with the supported 524,288-byte result limit returned `is_error=false`, exactly 524,288 content bytes, and no truncation notice in serialized output.

**This is the 12th finding in family `semantic-publication-evidence`.** Fix the governing rule: every lossy result stage must preserve truthful incompleteness through every consumer. Enumerate scheduler per-result/aggregate caps, paging, normalization, transcript serialization, and provider continuation—including zero remaining capacity. **ARCH-PURPOSE, ARCH-CONSTRAINTS.**

## 3. Important findings

### I1 — File transformation logic now has parallel implementations

**Locations:** `lua/parley/tools/async_builtin.lua:23`, `lua/parley/tools/builtin/edit_file.lua:78`; numbered-read formatting at `async_builtin.lua:89` and `builtin/read_file.lua:54`.

The new async adapter duplicates insertion, replacement, validation, and numbered-read logic while retaining independently maintained compatibility handlers.

**Fix:** Extract shared pure transformation/formatting functions consumed by both execution paths. Test those functions directly; keep filesystem and editor completion in their adapters. **ARCH-DRY, ARCH-PURE.**

## 4. Minor findings

None.

## 5. Test coverage notes

- **Passed:** operation, resources, scheduler, filesystem, wire ordering, async builtins, captured dispatch, producer, public chat concurrency, Tasker supervision, native filesystem, skill invocation, and document ownership architecture.
- **Additional probes:** reproduced C1–C3; C2 included synchronous-handler controls for all three writers.
- Required stat/name-status inspections and scoped `git diff --check` succeeded.
- Full-suite and performance claims were not independently rerun. No prior findings required disposition.

## 6. Architectural notes

| Marker | Result | Review conclusion |
|---|---|---|
| ARCH-DRY | **Flag** | I1: duplicated transformation policy. |
| ARCH-PURE | **Flag** | I1: extract shared pure logic from execution adapters. Declared PURE inventory otherwise checks out. |
| ARCH-PURPOSE | **Flag** | C2/C3: migration loses existing refresh behavior and truthful result publication. |
| ARCH-MOCK | **Pass** | Stateful process/filesystem seams and native conformance tests exercise production boundaries. |
| ARCH-CONSTRAINTS | **Flag** | C3: enforced byte caps lose their visible incompleteness signal. |
| ARCH-SECURE | **Flag** | C1: captured path authority does not survive deferred execution. |
| ARCH-ORDER | **Flag** | C1/C2: resource identity and editor state need validation across asynchronous boundaries. |
| ARCH-FUNERAL | **Pass** | Inspected records, timers, descriptors, temporary files, and numbered backups have retirement, retained-ownership, or capacity behavior. |

## 7. Plan revision recommendations

Add specific `## Revisions` entries covering:

- **Authority at execution:** identity/revalidation rules and ancestor-replacement tests across filesystem and traversal consumers.
- **File-to-editor completion:** refresh and reconciliation behavior for all three mutation tools.
- **Lossy-result publication:** the complete truncation-stage/consumer enumeration and end-to-end evidence tests.
- **Shared pure transformations:** extracted entities, paths, classification, and direct tests.

```findings
findings:
  - id: new
    severity: Critical
    family: resource-authority-at-effect
    title: |
      Deferred tool execution can follow a replaced ancestor outside captured roots
    detail: |
      lua/parley/tools/dispatcher.lua:431 and lua/parley/tools/filesystem.lua:157: a native production-producer probe replaced an admitted path's parent with an outside symlink before scheduled execution; read_file successfully returned OUTSIDE_SECRET. Enforce identity-bound authority at execution and sweep filesystem reads/writes, backup destinations, directory creation, and subprocess traversal with controlled replacement tests. ARCH-SECURE, ARCH-ORDER.
  - id: new
    severity: Critical
    family: file-editor-completion-consistency
    title: |
      Async file writers report success while open buffers retain old contents
    detail: |
      lua/parley/tools/async_builtin.lua:109 omits the editor refresh retained in write_file.lua:63, edit_file.lua:175, and propose_edits.lua:84. Native controls confirmed all three handlers refresh an unmodified autoread buffer, while all three async paths leave old text after successful disk writes. Restore shared ownership-safe refresh/reconciliation and test concurrent human edits. ARCH-PURPOSE, ARCH-ORDER.
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Scheduler-truncated results reach serialized output without a truncation notice
    detail: |
      lua/parley/tools/scheduler.lua:63 cuts content and sets truncated; dispatcher.lua:245 does not mark already-truncated content, and response_tools.lua:84 drops the flag. A 600000-byte native read produced a successful 524288-byte result with no serialized notice. This is the 12th finding in family semantic-publication-evidence. State and enforce the rule across every lossy stage and consumer, including aggregate-cap exhaustion, rather than patching only this instance. ARCH-PURPOSE, ARCH-CONSTRAINTS.
  - id: new
    severity: Important
    family: shared-transformation-policy
    title: |
      Async and compatibility handlers independently implement file transformations
    detail: |
      lua/parley/tools/async_builtin.lua:23 duplicates insertion/replacement policy from builtin/edit_file.lua:78; async_builtin.lua:89 duplicates numbered-read formatting from builtin/read_file.lua:54. Extract shared pure transformation and formatting functions consumed by both adapters, with direct tests. ARCH-DRY, ARCH-PURE.
```

---

## Re-review — 2026-09-15T13:14:33-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M6 |
| milestone | M6 |
| window | 4e8088ecefd6a3c4187dc8e76868fd6a8c9d1a31..fae8a7241b357930e4f565a2c75d6a85aaa6d4ce |
| command | sdlc milestone-close --issue 254 --milestone M6 |
| reviewer | codex |
| timestamp | 2026-09-15T13:14:33-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The pinned range implements substantial M6 functionality, and the 18-file tool-execution mapping passes. BR-26, BR-27, and BR-28 have supporting regression evidence. BR-25 remains open: backup publication can certify a replaced temporary file. Two additional production-path failures block shipping: private recovery contents can escape through grep glob precedence, and skill completion mistakes its own buffer refresh for a human edit.

## 1. Strengths

- Shared file transformations replace duplicated async/compatibility policies, with direct pure tests.
- Cancellation retains physical ownership and conflicting resource claims; controlled tests cover late completion and bounded reconciliation.
- Incomplete-result notices survive scheduler limits, normalization, serialization, and exhausted aggregate capacity.
- README and atlas updates cover the new command, configuration, execution model, and compatibility restrictions.

## 2. Critical findings

### BR-25 — Not addressed: backup publication loses source identity

At `lua/parley/tools/path_authority.lua:135` and `lua/parley/tools/filesystem.lua:368`, `linkat` publishes the temporary pathname without validating its leaf identity against the completed pre-image.

A native controlled probe replaced that temporary file with a symlink immediately before `fs_link`. The operation returned:

- `certainty="known"`, `effect="applied"`, `backup_confirmed=true`
- Target contents: `CHANGED`
- Backup contents: `OUTSIDE_SECRET`

The ancestor checks work, but the required identity sweep remains incomplete. Retain verifiable pre-image identity through publication and cleanup; reject substituted backup evidence before truncating the target. **ARCH-SECURE, ARCH-ORDER.**

### New — Search globs override private recovery exclusions

At `lua/parley/tools/async_builtin.lua:91`, the mandatory negative glob precedes the model-supplied positive glob. Ripgrep gives the later matching glob precedence.

A native production-producer control excluded recovery content. Adding only `glob="**/*"` returned `PRIVATE_SECRET` from `state/answer-recovery/secret` with `is_error=false`.

**This is the 2nd finding in family `resource-authority-at-effect`.** Do not fix only this instance: enforce mandatory exclusions independently of optional search filters, and sweep every traversal adapter and multi-target expansion. **ARCH-SECURE, ARCH-PURPOSE.**

### New — Skill completion rejects its own successful refresh

At `lua/parley/tools/file_refresh.lua:56`, the tool refresh changes the Document through its own captured proof. Subsequently, `lua/parley/skill_invoke.lua:391` validates the older whole-source proof and reports “Live text changed.”

The existing skill suite passes 19 tests. Enabling `autoread` in its fixture produces two failures in successful `propose_edits` scenarios, without an intervening human edit.

**This is the 2nd finding in family `file-editor-completion-consistency`.** Establish one completion/reconciliation owner across tool and skill consumers; distinguish an authorized refresh receipt from human mutation. Preserve the existing human-edit refusal tests. **ARCH-DRY, ARCH-ORDER, ARCH-PURPOSE.**

## 3. Important findings

None separately raised.

## 4. Minor findings

None.

## 5. Test coverage notes

- Required stat and name-status inspections succeeded; HEAD matches the pinned commit.
- `providers/tool_execution`: all 18 mapped spec files passed.
- Existing skill integration suite: 19 passed.
- Scratch restoration of pre-fix async code caused 12 refresh-test failures.
- Scratch restoration of pre-fix result-publication modules caused four evidence-test failures.
- Additional native probes reproduced backup substitution and private-content disclosure.
- Repository files were not edited. Full-suite and performance claims were not independently rerun.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | **Flag:** skill and tool layers independently own refresh completion. Shared transformations are validated. |
| ARCH-PURE | **Pass:** inspected pure entities have direct tests; filesystem/editor effects remain in integration adapters. |
| ARCH-PURPOSE | **Flag:** private-data enforcement and shared completion behavior remain incomplete across consumers. |
| ARCH-MOCK | **Pass:** stateful filesystem/process seams and native conformance tests exercise production boundaries; expand their cases as above. |
| ARCH-CONSTRAINTS | **Pass:** inspected admission, output, queue, and reconciliation bounds have targeted tests. Performance was not remeasured. |
| ARCH-SECURE | **Flag:** backup leaf substitution and overridable private exclusions. |
| ARCH-ORDER | **Flag:** publication loses temporary-file identity; skill completion misclassifies an authorized earlier mutation. |
| ARCH-FUNERAL | **Pass:** inspected owners provide retirement, quarantine, or capacity behavior; cleanup identity belongs in the BR-25 correction. |

The final M6 entity inventory matches the inspected module locations and classifications. M6 checklist items appropriately remain unchecked pending closure.

## 7. Plan revision recommendations

Add `## Revisions` entries specifying:

- Pre-image identity obligations through publication, verification, and cleanup, with controlled leaf-replacement tests.
- Mandatory traversal exclusions that optional filters cannot override, including an adapter/option enumeration.
- A shared tool-to-skill reconciliation contract, tested with `autoread` enabled and disabled, and with concurrent human edits.

```findings
dispose:
  - id: BR-25
    disposition: not-addressed
    note: |
      Ancestor replacement tests pass, but lua/parley/tools/path_authority.lua:135 and lua/parley/tools/filesystem.lua:368 publish an unverified temporary leaf. A native replacement before fs_link produced effect=applied and backup_confirmed=true while the overwritten target's backup read OUTSIDE_SECRET. Preserve pre-image identity through publication and cleanup. ARCH-SECURE, ARCH-ORDER.
  - id: BR-26
    disposition: addressed
    note: |
      All three async writers now share captured, ownership-safe refresh with compatibility handlers. The current refresh suite passes; restoring the pre-fix async module in a scratch copy causes 12 failures, including stale-buffer and missing-reconciliation assertions. A distinct skill-consumer regression is reported below.
  - id: BR-27
    disposition: addressed
    note: |
      Shared result evidence preserves visible incompleteness through native large reads, aggregate exhaustion, normalization, serialization, and skill delivery. Restoring pre-fix publication modules in a scratch copy makes all four integration evidence tests fail.
  - id: BR-28
    disposition: addressed
    note: |
      Async and compatibility adapters consume tools/file_transform.lua for edits and numbered reads; proposals reuse skill_edits.compute_edits. Direct pure tests cover literal replacement, insertion, limits, proposals, and numbering, and pass in the mapped suite.
findings:
  - id: new
    severity: Critical
    family: resource-authority-at-effect
    title: |
      Model-supplied search globs override private recovery exclusions
    detail: |
      lua/parley/tools/async_builtin.lua:91 inserts the mandatory negative rg glob before user filters. A native producer control excludes recovery bytes, but glob="**/*" returns PRIVATE_SECRET from state/answer-recovery/secret with is_error=false. This is the 2nd finding in this family: do not fix only this instance; enforce non-overridable exclusions across every traversal adapter, optional filter, and target expansion. ARCH-SECURE, ARCH-PURPOSE.
  - id: new
    severity: Critical
    family: file-editor-completion-consistency
    title: |
      Skill completion treats its own successful buffer refresh as a human conflict
    detail: |
      lua/parley/tools/file_refresh.lua:56 applies the tool refresh, then lua/parley/skill_invoke.lua:391 rejects its older source proof and returns ok=false with a live-text-changed warning. Enabling autoread in the existing skill fixture turns two successful proposal tests red without human edits. This is the 2nd finding in this family: establish one reconciliation owner and propagate authorized completion evidence across all consumers, retaining human-edit refusal tests. ARCH-DRY, ARCH-ORDER, ARCH-PURPOSE.
```

---

## Re-review — 2026-09-15T13:43:12-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M6 |
| milestone | M6 |
| window | 4e8088ecefd6a3c4187dc8e76868fd6a8c9d1a31..4bba51cbc458f21163cf8b978c9497e046fcc7ff |
| command | sdlc milestone-close --issue 254 --milestone M6 |
| reviewer | codex |
| timestamp | 2026-09-15T13:43:12-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: medium
```

The three open behavioral findings are addressed, with regression tests that fail when their fixes are removed in scratch copies. Targeted tests and lint pass. One Important architecture gap remains: lifecycle decisions still live in mutable integration-layer state rather than being enforced by the promised pure transition model. The repository and tracker were left unchanged.

## 1. Strengths

- Descriptor-relative filesystem operations reject redirected ancestors and substituted backup leaves; native tests exercise publication, cleanup, and truncation boundaries.
- Mandatory traversal exclusions now follow optional filters and target expansion. Tests cover multiple roots, metacharacter names, and chat-history searches.
- Skills retain one source-buffer completion owner while preserving human-edit, reload, cancellation, and late-cleanup protections.
- README and atlas changes document asynchronous tools, configuration limits, reconciliation, and compatibility requirements.

## 2. Critical findings

None.

## 3. Important findings

### Lifecycle decisions bypass the pure transition boundary

**Locations:** `lua/parley/tools/scheduler.lua:76`, `:88`, `:115`; `lua/parley/tools/operation.lua:74`; `lua/parley/skill_invoke.lua:146`.

The scheduler directly changes `known`, `physical`, `released`, and polling state, then uses those fields to release claims and retire records. The operation reducer has no physical-completion or owner-retirement events. Its `effect_start` permission has **zero production consumers**: the scheduler calls the transitions and starts execution without checking their results. The new skill final-read lifecycle likewise makes admission, cancellation, deadline, and retirement decisions through mutable locals.

This violates the Spec’s structural requirement that authoritative lifecycle decisions pass through pure transitions. Existing integration tests cover useful sequences, but do not establish that the model controls those decisions. **ARCH-PURE, ARCH-ORDER.**

**This is the 3rd finding in family `lifecycle-state-observability`.** State the rule for the complete class: lifecycle transitions must authorize execution, release, and retirement. Enumerate the scheduler, filesystem-operation owner, and skill final-read owner; move those decisions into explicit pure models, retaining handles and IO execution in adapters. Add enforcement and sequence tests, including rejected transitions and both effect/cleanup completion orders.

## 4. Minor findings

None.

## 5. Test coverage notes

Validated:

- Required pinned-range stat, name-status, targeted diffs, and `diff --check`.
- All **19 files** mapped to `providers/tool_execution`.
- Skill invocation: **37 passed**.
- Document ownership architecture: **6 passed**.
- Lint: **612 files, zero warnings/errors**.

Scratch mutation checks:

| Finding | Removed protection | Result |
|---|---|---|
| BR-25 | Cleanup leaf identity validation | Replacement-preservation regression failed |
| BR-29 | Mandatory exclusion precedence | Five traversal regressions failed |
| BR-30 | Deferred source-buffer refresh | Twelve skill regressions failed |

Full-suite and performance reports were not independently rerun.

## 6. Architectural notes

| Marker | Assessment |
|---|---|
| ARCH-DRY | **Pass:** shared transforms, exclusions, and refresh policy. |
| ARCH-PURE | **Flag:** lifecycle decisions remain in integration owners. |
| ARCH-PURPOSE | **Pass:** prior fixes cover enumerated consumers rather than isolated symptoms. |
| ARCH-MOCK | **Pass:** controlled stateful seams and native conformance tests. |
| ARCH-CONSTRAINTS | **Pass:** admission, output, queue-work, and reconciliation bounds have targeted coverage. |
| ARCH-SECURE | **Pass:** inspected replacement and exclusion regressions pass. |
| ARCH-ORDER | **Flag:** pure transition results do not structurally control the complete lifecycle. |
| ARCH-FUNERAL | **Pass:** inspected artifacts and handles have cleanup, retained ownership, or capacity policies. |

The revised entity inventory matches the inspected files; no PURE classification contradiction was found.

## 7. Plan revision recommendations

Add a `## Revisions` entry identifying the pure owner of execution permission, effect/cleanup joins, cancellation, deadline handling, and retirement. Update the entity inventory and enforcement-test mapping accordingly.

```findings
dispose:
  - id: BR-25
    disposition: addressed
    note: |
      Native tests cover ancestor and backup-leaf replacement, publication, truncation, and directory creation. Removing cleanup identity validation in a scratch module makes the replacement-preservation regression fail.
  - id: BR-29
    disposition: addressed
    note: |
      Shared traversal policy applies mandatory exclusions after optional filters and target expansion. Restoring the old rg exclusion ordering causes five native traversal regressions to fail.
  - id: BR-30
    disposition: addressed
    note: |
      Skills defer intermediate refresh of their captured source and perform an identity-bound final read. The 37-test skill suite passes; removing refresh deferral causes twelve failures, including successful proposal cases.
  - id: BR-26
    disposition: addressed
    note: |
      Prior disposition retained. Shared guarded file refresh remains in place and its mapped integration tests pass.
  - id: BR-27
    disposition: addressed
    note: |
      Prior disposition retained. Bounded result-evidence tests pass across publication and serialization consumers.
  - id: BR-28
    disposition: addressed
    note: |
      Prior disposition retained. Async and compatibility adapters consume shared transformation policy; direct transformation tests pass.
findings:
  - id: new
    severity: Important
    family: lifecycle-state-observability
    title: |
      Authoritative cleanup and execution decisions bypass the pure transition boundary
    detail: |
      scheduler.lua:76-115 releases claims and starts effects from integration-owned flags; operation.lua:85 emits effect_start with zero production consumers. skill_invoke.lua:146-216 independently owns final-read admission and retirement transitions. This is the 3rd finding in this family: enumerate scheduler, filesystem-operation, and skill final-read lifecycle owners, enforce execution/release/retirement through pure transition results, and test rejected transitions plus reordered completion evidence. ARCH-PURE, ARCH-ORDER.
```

---

## Re-review — 2026-09-15T14:00:30-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M6 |
| milestone | M6 |
| window | 4e8088ecefd6a3c4187dc8e76868fd6a8c9d1a31..3c77070a28b2feb78b91ebf81ad7233860944208 |
| command | sdlc milestone-close --issue 254 --milestone M6 |
| reviewer | codex |
| timestamp | 2026-09-15T14:00:30-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

BR-31 is addressed: pure transition results now control execution, cleanup, and retirement across all three identified owners. Regression tests fail when the pre-fix adapters are restored in scratch. Focused suites and lint pass. One minor reconciliation-timer overrun remains; it does not release unresolved ownership or authorize effects.

## 1. Strengths

- Scheduler launch, claim release, and retirement consume model permissions; rejection tests exercise each boundary.
- Filesystem completion IDs reject stale callbacks, while pending operations retain ownership through cancellation.
- Skill final reads separate logical completion from physical retirement, with deterministic event-order tests.
- README, atlas, and traceability document the new commands, configuration, lifecycle models, and compatibility requirements.

## 2. Critical findings

None.

## 3. Important findings

None.

## 4. Minor findings

- **Reconciliation deadline overshoots:** `lua/parley/tools/operation.lua:121` schedules `next=event.now+delay` without clamping to the deadline. A deterministic run produces probes through 4550 ms, then the diagnostic at **5550 ms**, despite the documented five-second limit. Clamp the next tick to `math.min(deadline, now+delay)` and test the complete scheduled sequence. **ARCH-CONSTRAINTS.**

## 5. Test coverage notes

Passed:

- `providers/tool_execution` mapped suite.
- `skills/skill-system` mapped suite.
- Document ownership architecture tests: seven passed.
- `make lint`: 616 files, zero warnings/errors.

Scratch restoration of each pre-fix adapter made the relevant rejection regressions fail: scheduler start/release/retirement, filesystem request/completion/publication, and skill admission/completion/observation.

The full suite, performance benchmark, and operator live testing were not rerun in this review. Repository files were unchanged.

## 6. Architectural notes

| Marker | Assessment |
|---|---|
| ARCH-DRY | **Pass:** shared transformation, traversal, and result-evidence policies serve their consumers. |
| ARCH-PURE | **Pass:** the three BR-31 lifecycle owners are IO-free; adapters execute their permissions. |
| ARCH-PURPOSE | **Pass:** correction covers the enumerated scheduler, filesystem, and skill owners. |
| ARCH-MOCK | **Pass:** stateful process/filesystem seams and isolated native conformance tests exercise production boundaries. |
| ARCH-CONSTRAINTS | **Flag, Minor:** reconciliation tick can exceed its declared deadline by 550 ms. Admission and retention remain bounded. |
| ARCH-SECURE | **Pass:** captured capabilities, identity-bound paths, private exclusions, and bounded evidence remain enforced. |
| ARCH-ORDER | **Pass:** rejected transitions and reordered completion evidence are tested; uncertainty retains ownership. |
| ARCH-FUNERAL | **Pass:** model-authorized retirement releases records, handles, and read slots; unresolved work retains bounded admission. |

The revised M6 inventory matches the inspected module locations and PURE/INTEGRATION roles.

## 7. Plan revision recommendations

No structural revision needed. Keep the five-second contract and correct the timer arithmetic.

```findings
dispose:
  - id: BR-31
    disposition: addressed
    note: |
      All three enumerated owners consume pure lifecycle permissions. Reordered-completion and rejection tests pass; restoring each pre-fix adapter in scratch makes its rejection regressions fail.
  - id: BR-25
    disposition: addressed
    note: |
      Identity-bound path and backup publication protections remain present; mapped native path-authority regressions pass.
  - id: BR-26
    disposition: addressed
    note: |
      Shared committed-byte buffer reconciliation remains wired into mutation tools; mapped file-refresh tests pass.
  - id: BR-27
    disposition: addressed
    note: |
      Bounded result-evidence publication retains truncation notices; mapped result-evidence tests pass.
  - id: BR-28
    disposition: addressed
    note: |
      Async and compatibility adapters consume the shared file-transform policy; mapped transformation tests pass.
  - id: BR-29
    disposition: addressed
    note: |
      Mandatory exclusions remain applied through shared traversal policy after optional filters; mapped traversal tests pass.
  - id: BR-30
    disposition: addressed
    note: |
      Skill completion retains sole source-buffer refresh ownership and original proof; the skill-system suite passes.
findings:
  - id: new
    severity: Minor
    family: reconciliation-deadline-enforcement
    title: |
      Scheduler reconciliation schedules beyond its five-second deadline
    detail: |
      lua/parley/tools/operation.lua:121 does not clamp the next tick to the deadline. Deterministic scheduled ticks reach the diagnostic at 5550 ms instead of 5000 ms. Clamp next to min(deadline, now + delay) and test the complete timer sequence. Ownership remains retained throughout. ARCH-CONSTRAINTS.
```
