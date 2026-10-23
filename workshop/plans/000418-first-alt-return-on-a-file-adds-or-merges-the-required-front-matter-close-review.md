# Boundary Review — parley.nvim#418 (whole-issue close)

| field | value |
|-------|-------|
| issue | 418 — First Alt+Return on a file adds or merges the required front matter |
| repo | parley.nvim |
| issue file | workshop/issues/000418-first-alt-return-on-a-file-adds-or-merges-the-required-front-matter.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9..f2a99a337abe8510b23ee3763f1fa287bb4cc4ae |
| command | sdlc close --issue 418 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T09:36:47-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared resolver, witnessed preparation stage, and save-before-send tests are sound approaches. Both mapped suites pass, but additional checks expose two correctness gaps: generated instruction values can fail on the next submit, and valid indented frontmatter cannot be filled. The plan’s Core-concepts inventory also contradicts the pinned diff.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: persisted-scalar-roundtrip
    title: |
      Materialized instructions do not reliably round-trip as strings
    detail: |
      lua/parley/editorial_frontmatter.lua:84-85 uses quoting rules that emit legacy instructions such as "true", "123", and "null" as unquoted canonical values. First fill succeeds, but filling its output fails with "processing-instruction: expected a scalar string"; this reproduces on Neovim 0.12.5 and 0.11.7. Escaped newlines also become literal newline characters inside an insertion entry. ARCH-EVOLVE / ARCH-SECURE: use a string serializer that preserves YAML types and escapes control characters, then add round-trip/idempotence and native insertion regressions covering these value classes.
  - id: new
    severity: Critical
    kind: defect
    family: preserve-root-mapping-layout
    title: |
      Filling valid indented frontmatter refuses its own projected output
    detail: |
      lua/parley/editorial_frontmatter.lua:96-114 always inserts root keys at column zero. For a header containing "  title: Example", resolve succeeds, but fill returns "frontmatter: inconsistent root mapping indentation"; the same failure reproduces with root indentation widths 1 through 4. ARCH-PURPOSE / ARCH-EVOLVE: preserve the existing root mapping indentation when inserting keys, and test successful fill, existing-byte preservation, and idempotence for indented headers.
  - id: new
    severity: Critical
    kind: defect
    family: core-concept-inventory-accuracy
    title: |
      Core-concepts tables classify an unchanged module as modified
    detail: |
      workshop/plans/000418-first-submit-frontmatter-plan.md:53 and :72 list lua/parley/skills/review/instruction.lua as modified, but its pinned base-to-head diff is empty; the plan's own :186 explicitly says its primitives remain unchanged. Under the required Core-concepts cross-check this contradiction is Critical. ARCH-PURPOSE: correct both table entries to describe reuse and add a Revisions entry aligning the inventory with the implemented ownership.
```

1. **Strengths**

   - Preparation uses the existing operation witness and explicitly distinguishes planning, awaiting-edit, and observed-edit.
   - Native tests verify undo, saved bytes at send time, persisted registration, reentrant edits, reload, and write failure.
   - Additive insertion preserves existing metadata lines without YAML reserialization.
   - README and atlas document defaults, canonical precedence, legacy compatibility, and refusal behavior.

2. **Critical findings**

   The three findings above require correction. The inventory correction is documentation-only; the two behavior fixes need regression tests that fail without them.

3. **Important findings**

   None additional.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/review`: passed.
   - `make test-spec SPEC=modes/session_sync`: passed all 33 mapped files.
   - Both runs completed with clean process censuses.
   - `git diff --check`: passed.
   - Added read-only checks reproduced scalar round-trip failure on both supported runtimes and indentation failure at widths 1–4.
   - The checkout remains unchanged.

6. **Architectural notes**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | Pass: existing scanner, selector primitives, and submission owner are reused. |
   | ARCH-PURE | Pass: settings/projection logic stays separate from editor effects. |
   | ARCH-PURPOSE | Flag: valid partial headers still fail the required merge behavior. |
   | ARCH-MOCK | Pass: production transport seam is exercised through the persistent fake. |
   | ARCH-CONSTRAINTS | Pass: header bounds and counted linear-work coverage are present. |
   | ARCH-SECURE | Flag: decoded instruction text is emitted without sufficient scalar encoding. |
   | ARCH-ORDER | Pass: explicit stages and controlled interruption tests protect preparation. |
   | ARCH-FUNERAL | Pass: preparation introduces no durable artifact family. |
   | ARCH-EVOLVE | Flag: generated scalar types and root layout must survive rewriting. |

7. **Plan revision recommendations**

   Add `## Revisions` entries documenting string-preserving serialization and indentation-preserving insertion, with their regression strategies. Correct both `instruction.lua` inventory entries to describe unchanged, reused primitives.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"1179896a-842c-47e1-89af-73910defb03a","repository":"github.com/xianxu/parley.nvim","issue_id":"000418","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/f59b742183b52f72","reviewed_head":"f2a99a337abe8510b23ee3763f1fa287bb4cc4ae","slot":"parley.nvim:3","requested_at":"2026-10-23T16:28:53.69265Z"},"phase":"finished","pid":97727,"started_at":"2026-10-23T16:28:53.8697Z","finished_at":"2026-10-23T16:36:45.263058Z","session_id":"01a16998-0a8c-7591-bcb8-272a68ce1f4d","outcome":"returned"}] -->

---

## Re-review — 2026-10-23T09:49:13-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 418 — First Alt+Return on a file adds or merges the required front matter |
| repo | parley.nvim |
| issue file | workshop/issues/000418-first-alt-return-on-a-file-adds-or-merges-the-required-front-matter.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9..46d9d0d195905092cf27f466d93ae1921b1bbbf7 |
| command | sdlc close --issue 418 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T09:49:13-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

All three prior findings are addressed, with regression failures confirmed when the behavioral fixes are removed. The preparation lifecycle, byte preservation, documentation, and pinned protocol snapshot check out. One correctness defect remains: valid unquoted instruction strings containing ordinary punctuation prevent submission.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Generated implicit-type/control-character round-trip tests and native insertion tests pass. Removing the serializer fix in a disposable pinned-head copy causes two existing regression tests to fail.
  - id: BR-2
    disposition: addressed
    note: |
      Widths 1–4 preserve existing bytes and produce idempotent output; native indented submission passes. Removing indentation preservation causes the existing generated regression to fail.
  - id: BR-3
    disposition: addressed
    note: |
      Plan lines 53 and 73 now identify instruction.lua as unchanged reuse; line 72 lists the actual modified consumers. The pinned instruction.lua diff is empty, and the Revisions entry explains the corrected ownership.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: persisted-scalar-roundtrip
    title: |
      Valid plain instruction strings are rejected using flow-collection parsing rules
    detail: |
      lua/parley/skills/review/collaboration_value.lua:257 calls decode(text) without block-scalar context. Consequently processing-instruction: Keep voice, fix typos fails with "expected a scalar string"; interior brackets and closing braces fail too. Reproduced on Neovim 0.12.5 and 0.11.7, including complete headers requiring no insertion. This blocks both submission routes for valid existing settings (ARCH-PURPOSE / ARCH-EVOLVE). This is the 2nd finding in family persisted-scalar-roundtrip: fix the rule across scalar reading and writing, rather than special-casing punctuation. Enumerate plain and quoted canonical/legacy instructions containing flow punctuation, verify effective-value preservation and idempotence, and add native submission coverage. Decode root scalar values in block context while retaining rejection of actual collections and invalid known-field types.
```

1. **Strengths**

   - Preparation stays within the existing operation model; native tests exercise expected edits, reentrant edits, reload, busy presses, and write failure.
   - Additive insertion preserves unknown metadata and existing bytes without YAML reserialization.
   - README and atlas describe the new settings and routing. The generated protocol snapshot matches the pinned substrate.

2. **Critical findings**

   - The scalar-context defect above blocks valid documents. At `collaboration_value.lua:257`, use the decoder’s block-scalar context for root scalar values and add the enumerated regressions.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/review` passed on Neovim 0.12.5.
   - On 0.11.7, focused checks passed: 16 resolver, 57 lifecycle, 16 native-submit, and 40 architecture cases.
   - All 25 Python export tests, pinned snapshot verification, and `git diff --check` passed.
   - Mutation checks confirmed BR-1 and BR-2 regressions fail without their fixes. The disposable copy was removed; the reviewed checkout remains clean.
   - Existing tests miss valid plain instruction strings containing flow punctuation. The full suite was not rerun.

6. **Architectural notes**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | Pass — shared resolver, scanner, and insertion seam. |
   | ARCH-PURE | Pass — resolution and lifecycle decisions remain separate from native effects. |
   | ARCH-PURPOSE | **Flag** — valid existing instructions prevent submission. |
   | ARCH-MOCK | Pass — native integration uses the persisted fake registry and transport seam. |
   | ARCH-CONSTRAINTS | Pass — header bounds and linear-work tests cover the declared envelope. |
   | ARCH-SECURE | Pass — malformed settings refuse visibly; preparation verifies identity and content. |
   | ARCH-ORDER | Pass — explicit preparation stages and deterministic interruption coverage. |
   | ARCH-FUNERAL | Pass — no new durable artifact family or background worker. |
   | ARCH-EVOLVE | **Flag** — compatible persisted scalar spellings are rejected. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining scalar-context compatibility: root plain scalars retain interior flow punctuation, actual collections remain invalid for string settings, and all canonical/legacy read-and-fill paths receive preservation and native-submit coverage.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"af8e98c2-6632-433d-98c6-0f6bcc1fa727","repository":"github.com/xianxu/parley.nvim","issue_id":"000418","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/0849fc9bc9c49259","reviewed_head":"46d9d0d195905092cf27f466d93ae1921b1bbbf7","slot":"parley.nvim:3","requested_at":"2026-10-23T16:45:29.720946Z"},"phase":"finished","pid":56622,"started_at":"2026-10-23T16:45:29.934339Z","finished_at":"2026-10-23T16:49:09.222372Z","session_id":"01a169a7-3d63-76b3-a9a5-18570676b62b","outcome":"returned"}] -->

---

## Re-review — 2026-10-23T10:05:03-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 418 — First Alt+Return on a file adds or merges the required front matter |
| repo | parley.nvim |
| issue file | workshop/issues/000418-first-alt-return-on-a-file-adds-or-merges-the-required-front-matter.md |
| boundary | whole-issue close |
| milestone | — |
| window | 3bec977814f3648275f9e2f3f2fcb4f9aea8dcc9..2617a3b471acf68263b917b341d32d34c7963d69 |
| command | sdlc close --issue 418 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-23T10:05:03-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation delivers additive, undoable preparation through the existing submission owner, with meaningful native and lifecycle tests. Documentation covers the new settings. BR-4 remains blocking: root-scalar decoding was corrected, but the preceding header scanner still applies quoted-value rules inside valid plain instruction strings.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      editorial_frontmatter.lua:84–97 preserves materialized string types and escapes controls. Regression tests pass; removing JSON encoding in memory produces four failing cases.
  - id: BR-2
    disposition: addressed
    note: |
      editorial_frontmatter.lua:118–120 preserves root indentation. Pure width-1–4 and native submission cases pass; removing indentation in memory makes the regression fail.
  - id: BR-3
    disposition: addressed
    note: |
      Both plan inventory rows now classify instruction.lua as unchanged, reused (lines 53 and 73), supported by its empty pinned-range diff and the explanation at line 203.
  - id: BR-4
    disposition: not-addressed
    note: |
      Critical; family persisted-scalar-roundtrip; ARCH-PURPOSE / ARCH-EVOLVE. collaboration_value.lua:18–20 still recognizes a quote following punctuation as a quoted-value opener inside a root plain scalar. Valid processing-instruction: Keep commas, "please therefore fails with frontmatter: unclosed quoted value, including a complete header needing no insertion. The same occurs for Keep ["asides] intact and Keep -"voice intact: all 12 canonical/legacy × partial/complete combinations were rejected on Neovim 0.11.7, with representative failures also reproduced on 0.12.5. Ruby YAML accepts these strings. An in-memory extension of the existing native complete-header regression fails at editorial_submit_spec.lua:147 with no submission. Correct lexical context throughout header scanning, comment handling and scalar decoding; enumerate embedded quotes after punctuation across plain/quoted canonical/legacy values and partial/complete headers. Retain actual collection/type rejection and original-byte preservation.
```

1. **Strengths**
   - Preparation uses the existing operation and exact edit witnesses; native tests verify cancellation on unrelated edits and reload.
   - Tests inspect saved bytes and persisted registration at the fake transport boundary, proving save/register/send ordering.
   - Additive insertion preserves existing metadata and body bytes, including indented mappings.
   - README and atlas describe defaults, legacy precedence, refusals, and submission routes.

2. **Critical findings**
   
   **BR-4 remains open** at `lua/parley/skills/review/collaboration_value.lua:18`. The scanner must distinguish quotes that begin YAML scalars from literal quotes inside an already-started plain scalar. Fix the shared lexical rule across the reader pipeline; adding punctuation exceptions would leave the family unresolved.

3. **Important findings**
   
   None newly raised. Extend BR-4’s existing regressions with the failing combinations documented above.

4. **Minor findings**
   
   None.

5. **Test coverage notes**
   - `make test-spec SPEC=modes/review` passed on Neovim 0.12.5.
   - Editorial pure tests: **20 passed**; native submission tests: **24 passed**, on both supported runtimes.
   - Document lifecycle tests: **57 passed** on 0.12.5.
   - Removing BR-4’s decoder-context fix in memory produced **two regression failures**, confirming reachability.
   - The additional native plain-scalar probe produced the expected blocking failure.
   - Writer and indentation mutation controls also failed as expected. Repository files remained unchanged; process censuses were clean.
   - Full suite and complete session-sync mapping were not rerun during this review.

6. **Architectural notes for upcoming work**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | Pass: shared resolver, insertion seam, and existing selectors reused. |
   | ARCH-PURE | Pass: settings and transitions remain pure; native editing stays at the boundary. |
   | ARCH-PURPOSE | **Flag BR-4:** valid existing settings still prevent submission. |
   | ARCH-MOCK | Pass: native flow uses the persistent fake Couch boundary; existing conformance probes remain available. |
   | ARCH-CONSTRAINTS | Pass: header bounds and counted growth tests exercise the declared envelope. |
   | ARCH-SECURE | Pass: malformed metadata refuses visibly; tests isolate external state. |
   | ARCH-ORDER | Pass: witnessed transitions and reproducible interruption tests cover preparation ownership. |
   | ARCH-FUNERAL | Pass: no new durable artifact family; operation state has existing terminal cleanup. |
   | ARCH-EVOLVE | **Flag BR-4:** valid persisted plain strings remain unreadable. |

7. **Plan revision recommendations**
   
   Add a `## Revisions` entry extending BR-4’s root-context rule to **header lexical scanning and comment handling**, with embedded quote/punctuation combinations, canonical/legacy readers, and partial/complete native submissions. The current revision at plan line 207 describes the correct intent but does not yet have complete implementation or regression coverage.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"bdad0e79-c0a4-467b-a731-5c5706528596","repository":"github.com/xianxu/parley.nvim","issue_id":"000418","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/563af1230bae8ddb","reviewed_head":"2617a3b471acf68263b917b341d32d34c7963d69","slot":"parley.nvim:3","requested_at":"2026-10-23T17:00:56.913048Z"},"phase":"finished","pid":17336,"started_at":"2026-10-23T17:00:57.080144Z","finished_at":"2026-10-23T17:05:02.362414Z","session_id":"01a169b5-62fa-70c0-a68a-1264cc5af9cc","outcome":"returned"}] -->
