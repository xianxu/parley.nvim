# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M2)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | dc715634428c3c66b59e869d54ed576c1bc13369..48c9d6c43e85225e87a10649a804e5fb77424fc8 |
| command | sdlc milestone-close --issue 254 --milestone M2 |
| reviewer | codex |
| timestamp | 2026-09-15T00:44:23-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M2 core has strong index, provenance, and bounded-work coverage, and its architectural documentation matches the intended staged migration. Two reproduced correctness bugs block closure: stale publication can restore invalid confirmed semantics, and answer-section classification differs from the legacy grammar. Review used the pinned range; no files changed.

## 1. Strengths

- Sequence storage separates text evidence from syntax evidence and returns copied metadata.
- Repair exposes bounded read requests and explicit continuations; missing lookahead remains uncertainty.
- Atlas and traceability updates describe the new modules and clearly assign live migration to M3.
- Existing pure tests exercise flat-reference comparisons, stale handles, selective dependencies, and controlled edit ordering.

## 2. Critical findings

### Stale publication can overwrite newer confirmed semantics

**Location:** `lua/parley/document/structure.lua:115–154`  
**Markers:** ARCH-ORDER, ARCH-SECURE

`capture` records local text evidence and epoch, but no incoming semantic checkpoint or dependency evidence. `publish` consequently accepts obsolete semantic metadata when the target text remains unchanged.

**Reproduced:**

1. Settle `{"💬: q", "one", "two", "three", "four"}`.
2. Capture row 3 and its question-role metadata.
3. Replace row 0 with `"🤖: a"` and settle again. Row 3 correctly becomes an answer.
4. Publish the captured metadata. Publication returns `published`; row 3 becomes `question` with `confirmed=true`.

**Fix:** Require semantic publications to validate their incoming state and dependency evidence, or restrict this API to lexical publication and route semantic projection through the validated worker. Add this ordering as a regression while retaining acceptance of genuinely unrelated edits.

### Fenced tool markers incorrectly extend thinking sections

**Location:** `lua/parley/document/grammar.lua:202–225`  
**Marker:** ARCH-PURPOSE

Inside an ordinary fence, the reducer changes tool-marker kind to `text` before checking whether it terminates reasoning. The legacy reducer uses the original structural kind for termination even when the marker cannot open a tool section (`lua/parley/answer_structure.lua:74–80`).

**Minimal reproduction:**

```text
💬: q
🤖: a
```
````text
```
🧠: think
📎: x
```
````

The legacy parser classifies rows 5–6 as `text`; the new core classifies both as `thinking`.

**Fix:** Separate structural boundary classification from permission to open a tool section. Sweep both tool-marker kinds across reasoning and existing section states, with golden and differential regressions.

## 3. Important findings

None additional.

## 4. Minor findings

None.

## 5. Test coverage notes

- Ran the supplied stat and name-status recipes, targeted patches, and `git diff --check`.
- Executed **118 existing pure document tests: all passed**, using an in-memory assertion runner. Skipped the subprocess/file-writing GC test to preserve read-only operation.
- Generated 1,000 transcript cases matching legacy exchange boundaries.
- Generated answer-section comparisons exposed the fence mismatch; a separate controlled publication probe reproduced stale confirmed metadata.
- Did not rerun the full integration or performance suites. Existing tests passing does not cover the two demonstrated failures.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | **Pass:** legacy fence/highlight entry points delegate shared lexical behavior. |
| ARCH-PURE | **Pass:** core logic runs without IO; reading remains an external seam. |
| ARCH-PURPOSE | **Flag:** promised grammar compatibility fails for fenced reasoning boundaries. |
| ARCH-MOCK | **Pass for M2:** bounded reader seam and reader conformance coverage exist; no new external service dependency. |
| ARCH-CONSTRAINTS | **Pass for isolated core:** explicit work budgets and scaling assertions exist; attached-editor acceptance remains M3. |
| ARCH-SECURE | **Flag:** local text evidence incorrectly authorizes context-dependent semantic publication. |
| ARCH-ORDER | **Flag:** an older publication can overwrite a newer semantic result. |
| ARCH-FUNERAL | **Pass by inspection:** weak stores, reload cleanup, and detached-storage reclamation coverage address new in-memory lifetimes. |

The M2 core-concept entities exist at their documented paths; revisions explain the additional helper modules. Atlas updates are present. No new user-facing command, configuration, or keybinding requires a README change.

## 7. Plan revision recommendations

Add `## Revisions` entries specifying:

- Semantic publication requires valid incoming checkpoint and dependency evidence, alongside local text provenance.
- Fence containment affects tool-section admission separately from structural reasoning termination.

Keep both corrections within M2.

```findings
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Local text certificates permit stale confirmed semantic publication
    detail: |
      lua/parley/document/structure.lua:115–154 captures only local text evidence and epoch. After changing an earlier question marker to an assistant marker and completing repair, publishing previously captured body metadata succeeds and restores question semantics with confirmed=true. ARCH-ORDER / ARCH-SECURE: validate incoming semantic state and dependencies, or restrict publication to lexical metadata; add controlled stale-publication and disjoint-edit regressions.
  - id: new
    severity: Critical
    family: grammar-boundary-preservation
    title: |
      Ordinary-fence suppression removes a required reasoning boundary
    detail: |
      lua/parley/document/grammar.lua:202–225 rewrites fenced tool markers to text before reasoning termination. For question, answer, opening fence, reasoning marker, tool-result marker, closing fence, the new core marks the last two rows thinking while the legacy reducer marks them text. ARCH-PURPOSE: preserve original structural boundary semantics separately from tool-section admission and cover both tool-marker kinds across section states.
```

---

## Re-review — 2026-09-15T01:01:56-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | dc715634428c3c66b59e869d54ed576c1bc13369..9851858c0d0c46eb69e63871a21a964ff9ea548d |
| command | sdlc milestone-close --issue 254 --milestone M2 |
| reviewer | codex |
| timestamp | 2026-09-15T01:01:56-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned M2 range satisfies the isolated-core boundary. Both prior Critical findings are addressed, with regressions confirmed to fail when their respective fixes are removed in memory. No new blocking findings emerged. Repository files remain unchanged.

## 1. Strengths

- Publication now separates lexical evidence from semantic authority and preserves newer semantics for equivalent results (`lua/parley/document/structure.lua:144`).
- Fence containment and structural termination have distinct rules, backed by golden and legacy-comparison tests (`lua/parley/document/grammar.lua:225`).
- Sequence tests exercise independent reference models, stale provenance, atomic updates, and bounded work.
- Atlas, traceability, and plan revisions document the new modules and explicitly reserve live-editor migration for M3.

## 2. Critical findings

None. BR-3 and BR-4 are addressed below.

## 3. Important findings

None.

## 4. Minor findings

None raised.

## 5. Test coverage notes

- Required stat and name-status inspections succeeded; inspected targeted patches and supporting source.
- **122 document tests passed** under Neovim using an in-memory assertion runner.
- **3 real-Neovim reader tests passed**, including bounded UTF-8 reads and final-empty-row handling.
- **400 additional seeded answer-section comparisons passed** against the legacy reducer.
- Removing the publication fix caused **two regression failures**; removing the grammar fix caused **two regression failures**.
- Skipped the file-writing subprocess GC test under the read-only constraint. Full mapped suites and performance reports were not rerun.
- `git diff --check` reported only two Markdown hard-break trailing spaces in the prior review artifact.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | **Pass:** legacy highlighting and fence entry points delegate shared lexical rules. |
| ARCH-PURE | **Pass:** core transitions operate without IO; text reads remain outside the core. Legacy comparison tests require the Neovim host, not mocked core behavior. |
| ARCH-PURPOSE | **Pass for M2:** isolated structural core delivered; live migration remains explicitly assigned to M3. |
| ARCH-MOCK | **Pass for M2:** controlled read responses share the production request interface; real-editor conformance tests pass. |
| ARCH-CONSTRAINTS | **Pass for M2:** row, byte, navigation, and copy bounds have executable coverage. Attached-editor timing remains unverified here. |
| ARCH-SECURE | **Pass:** publication rejects derived metadata; stale source evidence and malformed read requests fail explicitly. |
| ARCH-ORDER | **Pass:** private worker state and controlled edit/read sequences enforce publication ordering; both prior temporal regressions are covered. |
| ARCH-FUNERAL | **Pass by inspection:** weak stores, detached membership checks, and reload reset define in-memory lifetimes; reclamation regression exists but was not rerun. |

M2 core-concept entities exist at their stated paths; revisions explain the extracted helper modules. Atlas updates are present. No new user-facing command, keybinding, or configuration surface requires a README update.

## 7. Plan revision recommendations

None. The existing M2 boundary-review revision describes both corrections accurately.

```findings
dispose:
  - id: BR-3
    disposition: addressed
    note: |
      structure.lua:144–169 restricts publication to lexical metadata and invalidates changed classifications. document_structure_spec.lua:109 and :135 pass at HEAD and both fail with the pre-fix module substituted in memory; disjoint-edit acceptance remains covered.
  - id: BR-4
    disposition: addressed
    note: |
      grammar.lua:225 retains original structural kind for termination. document_grammar_spec.lua:205 and document_semantic_spec.lua:61 pass at HEAD and both fail with the pre-fix module substituted in memory; coverage sweeps both tool-marker kinds across section and fence states.
```
