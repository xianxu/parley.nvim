# Boundary Review — parley.nvim#335 (whole-issue close)

| field | value |
|-------|-------|
| issue | 335 — Alt+o doesn't recognise a markdown link whose text wraps across lines (falls back to a #NNN reference) |
| repo | parley.nvim |
| issue file | workshop/issues/000335-alt-o-doesn-t-recognise-a-markdown-link-whose-text-wraps-across-lines-falls-back-to-a-nnn-reference.md |
| boundary | whole-issue close |
| milestone | — |
| window | 83f3893a133af1d8f96a677ecc0fa6b5e2c514c0..04c87f5c37be8c0a09e86edb7da518c51cb04f59 |
| command | sdlc close --issue 335 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T15:28:34-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The main wrapped-link cases work, and the shared scanner preserves byte coordinates and destination rows. The mapped reference suite passes, but additional headless probes found two correctness gaps: unsupported destinations can open references embedded in their labels, and scanning can recognize links across chat boundaries or inside fenced examples.

1. **Strengths**

   - Multiline spans retain raw text and accurate byte coordinates, including multibyte prefixes.
   - Entity collection reserves continuation rows, preventing nested references from becoming separate picker choices.
   - README and atlas updates document the changed navigation behavior.

2. **Critical findings**

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: preserve-recognized-reference-identity
    title: |
      Direct wrapped links can open an @@ reference embedded in their label
    detail: |
      lua/parley/init.lua:5067 sends a recognized Markdown span through the generic reference opener. When its destination is unsupported, that opener proceeds to @@ parsing instead of falling back at the Markdown destination. A headless probe with "[long @@<absolute README.md path>@@\nlabel](https://example.invalid/path)" opened README.md from a cursor on line 2; destination fallback was never called. The affected family in this window is direct wrapped Markdown navigation; selected Markdown navigation at lines 5087–5089 already avoids this reinterpretation. Share a Markdown-only dispatch helper between these paths (ARCH-DRY), then fall back at the retained destination coordinates. Add direct-navigation regressions with existing and missing nested @@ targets.
  - id: new
    severity: Critical
    kind: defect
    family: preserve-document-scan-boundaries
    title: |
      The direct multiline scan ignores chat entity boundaries and plain Markdown fence context
    detail: |
      lua/parley/init.lua:5062 scans the entire buffer before obtaining entity context, while lua/parley/reference_candidates.lua:23 builds a partition-resetting fence memo unconditionally. Headless probes confirmed that "[unfinished" in a user turn joined "🤖: label](<absolute README.md path>)" in the next turn and opened README.md; a plain Markdown fenced example containing "🤖: [long" followed by "label](<absolute README.md path>)" also opened it. Family enumeration: markdown_spans lacks barriers for all eight structural prefixes—user, assistant, summary, reasoning, tool-use, tool-result, branch and local—and its default fence memo resets on user/assistant/branch/local prefixes even in plain Markdown. Both the direct scanner and collect's shared scanner must receive appropriate document context; collect's supplied memo already preserves the navigation caller's fence policy. Reuse the existing entity boundaries and transcript-aware fence policy, and add regressions covering boundary crossings and fenced chat-like examples. This violates the paragraph-scoped purpose (ARCH-PURPOSE).
```

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make -f Makefile.parley test-spec SPEC=context/file_references` passed, as did the pinned range’s `git diff --check`. Existing additions cover both wrapped rows, target positions, picker selection, destination-row fallback, masking, and several scan barriers. They miss direct unsupported destinations containing `@@` and document-context boundaries demonstrated above. Repository source files were unchanged.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — flag:** direct and selected Markdown dispatch have different fallback semantics; consolidate their Markdown-only opening chain.
   - **ARCH-PURE — pass:** parsing remains deterministic in the candidate module, with editor effects at the command boundary. Core-concept entities exist at their declared paths.
   - **ARCH-PURPOSE — flag:** ordinary wrapped links work, but paragraph confinement and reference identity remain incomplete.

7. **Plan revision recommendations**

   Add a `## Revisions` entry requiring shared Markdown-only dispatch and document-aware scan boundaries, with regression tests for both findings. The Core concepts classifications can remain unchanged.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"d305fbd0-fcdc-4a05-aa8c-8dba2fbe7efb","repository":"github.com/xianxu/parley.nvim","issue_id":"000335","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/098c5794f9b9f3e5","reviewed_head":"04c87f5c37be8c0a09e86edb7da518c51cb04f59","slot":"parley.nvim:1","requested_at":"2026-10-15T22:26:40.01448Z"},"phase":"finished","pid":70526,"started_at":"2026-10-15T22:26:40.410096Z","finished_at":"2026-10-15T22:28:33.39378Z","session_id":"01a141ac-b892-7293-94b5-dded29ca0c3e","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T15:45:25-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 335 — Alt+o doesn't recognise a markdown link whose text wraps across lines (falls back to a #NNN reference) |
| repo | parley.nvim |
| issue file | workshop/issues/000335-alt-o-doesn-t-recognise-a-markdown-link-whose-text-wraps-across-lines-falls-back-to-a-nnn-reference.md |
| boundary | whole-issue close |
| milestone | — |
| window | 83f3893a133af1d8f96a677ecc0fa6b5e2c514c0..dcdb95cf023e8c1b2e0b465381608d91fbd07fdf |
| command | sdlc close --issue 335 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T15:45:25-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior findings are corrected, with verified failing regressions when the fixes are removed. All 75 focused tests pass at the pinned head. However, the shared scanner still constructs links across Markdown block boundaries, violating the paragraph-scoped contract and opening unintended targets.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Direct and selected wrapped links share open_markdown_reference. The existing/missing nested-@@ regression passes at head and fails with the pre-fix production files.
  - id: BR-2
    disposition: addressed
    note: |
      Both consumers receive document context and the navigation fence memo. The transcript-marker and plain-Markdown-fence regressions pass at head; removing the correction produces one unit and two integration failures.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: preserve-document-scan-boundaries
    title: |
      Wrapped links still cross Markdown block boundaries
    detail: |
      lua/parley/reference_candidates.lua:29–35 omits thematic breaks, Setext heading underlines, and blockquote transitions from its paragraph barriers. Headless probes using {"[unfinished", boundary, "label](<absolute README.md path>)"} with each boundary "---", "***", "___", "===", and "> quoted" produced one Markdown candidate and opened README.md through OpenFileUnderCursor from row 3. The affected sites are the shared boundary predicate, direct scanning at lua/parley/init.lua:5071, and collect's shared scan at lua/parley/reference_candidates.lua:100. This is the 2nd finding in family preserve-document-scan-boundaries. Earlier rounds fixed instances. Do NOT fix only these spellings: state the paragraph/block-containment rule, enumerate its boundary classes, and enforce it for both consumers with failing regressions (ARCH-PURPOSE).
```

Done-when: current — the original navigation and invalid-link outcomes remain applicable; the revisions refine their boundary and dispatch constraints.

1. **Strengths**

   - Shared Markdown-only dispatch preserves recognized destination identity.
   - Full spans retain byte coordinates and fallback destination rows.
   - README and atlas explain the corrected behavior.
   - Prior corrections have independently confirmed red/green evidence.

2. **Critical findings**

   - Markdown block containment remains incomplete; see the finding above. Extend the shared scanner’s boundary policy and test both direct navigation and candidate collection.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   The unit suite passes 16 cases; integration passes 59. Removing the prior corrections causes four cases to fail without test errors. The five additional block-boundary probes reproduce unintended opening despite the passing suite. Production files were restored; the checkout is clean. Full-suite claims were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY: pass.** Both consumers reuse scanning and Markdown dispatch.
   - **ARCH-PURE: pass.** Parsing remains deterministic and directly tested; editor effects stay in the integration layer. Core-concept entities exist at their declared paths.
   - **ARCH-PURPOSE: flag.** Cross-block joining violates the promised paragraph scope.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining paragraph/block containment for both scanner consumers, enumerating the supported boundary classes, and requiring regression coverage for the confirmed thematic-break, Setext-heading, and blockquote cases.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"79884504-d136-4b45-b704-8dd120367d15","repository":"github.com/xianxu/parley.nvim","issue_id":"000335","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/84c1a2ac5fd10371","reviewed_head":"dcdb95cf023e8c1b2e0b465381608d91fbd07fdf","slot":"parley.nvim:1","requested_at":"2026-10-15T22:43:43.277005Z"},"phase":"finished","pid":98665,"started_at":"2026-10-15T22:43:43.399979Z","finished_at":"2026-10-15T22:45:25.153837Z","session_id":"01a141bc-54ea-77d0-9ff5-44e48912a835","outcome":"returned"}] -->
