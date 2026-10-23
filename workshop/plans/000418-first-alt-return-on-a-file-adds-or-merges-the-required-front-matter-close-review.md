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
