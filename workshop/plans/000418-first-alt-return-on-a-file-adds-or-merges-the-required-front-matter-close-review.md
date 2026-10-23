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
