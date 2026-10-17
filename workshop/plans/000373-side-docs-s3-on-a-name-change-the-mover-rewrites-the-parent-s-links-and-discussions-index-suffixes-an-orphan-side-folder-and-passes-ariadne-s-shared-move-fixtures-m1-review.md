# Boundary Review — parley.nvim#373 (milestone M1)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | f9a4a11cde712b47ef25d94e9debffd874e298a7..e53020d4cceeb064d73331a91f03f5fd4c7f46f1 |
| command | sdlc milestone-close --issue 373 --milestone M1 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T11:09:53-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 delivers the versioned export, manifest-driven fixtures, and pure projection within the revised milestone scope. Existing focused tests pass, but independent checks reproduced code-span corruption, partial output mutation after failed preflight, and quadratic scanning. The code-span corruption blocks this boundary.

1. **Strengths**

   - Shared fixtures derive their cases and expected bytes from `export.json`, with size/hash checks and complete tree comparison.
   - Scalar parsing, link rewriting, and byte-edit assembly are shared between parent and child projections.
   - Export tests cover malformed manifests, corrupted members, symlinks, stale outputs, and standalone packaging.

2. **Critical findings**

   - `lua/parley/document_move_plan.lua:123–129`: multiline Markdown spans are checked against single-line code masks. Both rewrite APIs change link-like text inside a multiline backtick code span. This also reaches the existing child-backlink runtime path. Mask inline code across paragraph lines and add preservation regressions for both APIs.

3. **Important findings**

   - `scripts/sync-review-protocol.py:156–158`: recursive preflight accepts directories at expected file paths. Replacing an expected fixture file with an empty directory caused sync to replace `SKILL.md`, then fail with `IsADirectoryError`. Validate expected leaf and ancestor types before any writes.
   - `lua/parley/document_move_plan.lua:150`: the malformed-link fallback repeatedly copies and scans remaining suffixes. For repeated `](` input, measured CPU times were approximately 0.025s/2KB, 0.095s/4KB, 0.374s/8KB, and 1.465s/16KB. Make this scan monotonic and test the complete rewrite.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Passed independently: 21 Python contracts; 106 Lua tests across four focused files; 374 mapped review tests across 18 files; whitespace checks. Both shared fixture groups passed.

   The independent code-span preservation assertions failed for both rewrite APIs. The exporter failure and quadratic timing measurements were also reproduced. Initial concurrent mapped runs collided through their cleanup guard; serial rechecks passed. Repository files remain unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared scalar/link/edit helpers reduce duplication.
   - **ARCH-PURE — pass:** projection logic remains deterministic and free of IO; fixture loading stays in integration tests.
   - **ARCH-PURPOSE — flag:** preserving unrelated bytes fails for multiline code spans.
   - **ARCH-MOCK — pass:** no new external service seam is introduced in M1.
   - **ARCH-CONSTRAINTS — flag:** the complete rewrite still has a quadratic malformed-input path.
   - **ARCH-SECURE — flag:** unexpected filesystem types are accepted as preflight-safe, allowing partial mutation.
   - **ARCH-ORDER — pass for M1:** the projection holds no state between events. The approved revision defers the reducer and dispatcher together to M2.
   - **ARCH-FUNERAL — pass:** generated snapshots have explicit stale-file handling; orphan effects rename retained user content.

   Atlas documents export v2 and fixture ownership. The runtime journal/editor changes and their user documentation remain M2 obligations.

7. **Plan revision recommendations**

   Add `## Revisions` entries covering paragraph-wide inline-code preservation, expected-output type validation before mutation, and complete-rewrite scale tests for repeated malformed destination openers. Mark Core concepts rows by milestone so deferred M2 entities are explicit in the table.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: markdown-code-preservation
    title: |
      Multiline inline code is rewritten as a live Markdown link
    detail: |
      lua/parley/document_move_plan.lua:123–129 builds code masks per line while markdown_spans recognizes multiline links. Input "`[example\nlabel](design.side/q.md)`\n" is changed to spec.side by rewrite_side_references; rewrite_parent likewise changes "../design.md" to "../spec.md" inside the same code shape. This violates unrelated-byte preservation and affects existing child-backlink callers (ARCH-PURPOSE). Mask inline code across paragraph lines and add failing preservation tests for both APIs.
  - id: new
    severity: Important
    kind: defect
    family: output-preflight-before-mutation
    title: |
      Expected file paths can pass preflight as directories and cause partial sync
    detail: |
      scripts/sync-review-protocol.py:156–158 recursively accepts directories without checking expected leaf types. Replacing examples/move-test/before/nested/old.md with an empty directory and making SKILL.md stale caused sync to replace SKILL.md before failing with IsADirectoryError. Validate every expected file and ancestor type before writing, with mutation-free failure regressions for both modes and fixtures (ARCH-SECURE).
  - id: new
    severity: Important
    kind: defect
    family: bounded-reference-scanning
    title: |
      Complete parent rewriting retains a quadratic malformed-link scan
    detail: |
      lua/parley/document_move_plan.lua:150 copies and scans the remaining suffix for every unmatched "](" opener. Through rewrite_side_references, repeated "](" input measured approximately 0.025s/2KB, 0.095s/4KB, 0.374s/8KB, and 1.465s/16KB, despite accepting documents up to 4MiB. Use monotonic delimiter scanning and add complete-rewrite scale coverage; the existing opening-bracket test misses this path (ARCH-CONSTRAINTS).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2c0f9f4d-a166-42de-b6fa-36cd4b810334","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/287636a3e395e856","reviewed_head":"e53020d4cceeb064d73331a91f03f5fd4c7f46f1","slot":"parley.nvim:1","requested_at":"2026-10-17T18:05:59.354762Z"},"phase":"finished","pid":47336,"started_at":"2026-10-17T18:05:59.453754Z","finished_at":"2026-10-17T18:09:52.939614Z","session_id":"01a14b0a-c609-7112-bd51-31973620b709","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T11:24:32-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | f9a4a11cde712b47ef25d94e9debffd874e298a7..c8dddf5bf201a8194f5d6bedd4b20bc344844c08 |
| command | sdlc milestone-close --issue 373 --milestone M1 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T11:24:32-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The prior three fixes have effective regression tests, confirmed by removing each fix in a disposable checkout. M1’s exporter and shared projections pass their targeted suites. One new correctness defect blocks shipping: inline-code masks cross Markdown block boundaries and suppress required live-link rewrites.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Paragraph-wide preservation tests cover both rewrite APIs; restoring the previous line-local masker produces three failing tests.
  - id: BR-2
    disposition: addressed
    note: |
      Expected leaves and ancestors are validated before mutation. Removing that validation produces 21 failing regression subtests across protocol files, modes, and fixtures.
  - id: BR-3
    disposition: addressed
    note: |
      Complete-rewrite scale coverage passes for both APIs. Restoring suffix scanning makes the malformed-destination regression fail.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: markdown-code-preservation
    title: |
      Inline-code masks cross block boundaries and leave live links pointing at the old path
    detail: |
      lua/parley/document_move_plan.lua:110 ends code-mask paragraphs only at blank lines or fences. Input "` unmatched\n# Heading\n[live](design.side/q.md) `\n" remains unchanged when design.md becomes spec.md, although the heading separates the backticks and the live destination must become spec.side/q.md. Both rewrite APIs fail equivalent probes across headings, thematic breaks, blockquotes, and list starts: eight failures. This is the 2nd finding in family `markdown-code-preservation`. Do NOT fix only this instance: state and enforce the block-boundary rule across the supported Markdown structures, sharing segmentation with reference_candidates.markdown_spans where appropriate, and test both APIs. ARCH-DRY and ARCH-PURPOSE.
```

1. **Strengths**

   - Export preflight checks expected regular-file leaves and directory ancestors before writing (`scripts/sync-review-protocol.py:151`).
   - Shared fixture tests discover cases through manifest records and compare complete resulting path-to-byte maps.
   - Scanner differential tests check compatibility against the previous pattern over 1,208 inputs.
   - The plan explicitly revises the M1/M2 boundary to defer the reducer until its dispatcher consumes it.

2. **Critical findings**

   The finding above affects both parent side references and existing child backlinks. Consolidate block segmentation with `reference_candidates.lua:49–62`; its boundary rules already include structures omitted by the new masker. Preserve multiline code within a block while preventing backtick pairing between blocks.

3. **Important findings**

   None additional.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Passed: 43 projection cases, 19 reference cases, one shared-fixture test covering both exported groups, and 23 Python exporter tests. All three prior fixes passed negative-control verification. Eight additional block-boundary probes failed on pinned-head code. Full suite was not rerun. Disposable checkout removed; repository working tree is clean.

6. **Architectural notes**

   - **ARCH-DRY — flag:** link scanning and code masking maintain inconsistent block-boundary rules.
   - **ARCH-PURE — pass:** projection decisions remain deterministic and receive observations from callers.
   - **ARCH-PURPOSE — flag:** the new masking behavior leaves required references unresolved.
   - **ARCH-MOCK — pass:** M1 adds no external runtime dependency; registry integration remains M2.
   - **ARCH-CONSTRAINTS — pass:** targeted malformed-input scale tests pass; the old suffix scan fails their negative control.
   - **ARCH-SECURE — pass:** output shape validation precedes mutation, with adversarial regression coverage.
   - **ARCH-ORDER — pass for M1:** this boundary adds projections; durable transition ownership is explicitly deferred to M2.
   - **ARCH-FUNERAL — pass:** fixtures have deliberate snapshot ownership and stale-output refusal; orphan projection renames retained content.

   Core-concept classifications match the revised milestone scope. Atlas documents the export surface. M1 introduces no new command, flag, keybinding, or configuration option requiring a README usage update.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining one shared Markdown block-segmentation contract for reference scanning and inline-code masks. Enumerate supported boundaries and require preservation plus live-link rewrite tests across each boundary for both APIs.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ac49aa83-3627-4b07-8c11-2adb16760667","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/585e79ecc387df91","reviewed_head":"c8dddf5bf201a8194f5d6bedd4b20bc344844c08","slot":"parley.nvim:1","requested_at":"2026-10-17T18:22:25.958047Z"},"phase":"finished","pid":12166,"started_at":"2026-10-17T18:22:26.058249Z","finished_at":"2026-10-17T18:24:31.875707Z","session_id":"01a14b19-d41d-7b32-b8ef-57054aa0d7f8","outcome":"returned"}] -->
