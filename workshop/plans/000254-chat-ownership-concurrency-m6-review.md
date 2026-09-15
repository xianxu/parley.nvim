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
