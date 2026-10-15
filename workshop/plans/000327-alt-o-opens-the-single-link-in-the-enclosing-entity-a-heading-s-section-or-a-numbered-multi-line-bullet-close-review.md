# Boundary Review — parley.nvim#327 (whole-issue close)

| field | value |
|-------|-------|
| issue | 327 — Alt+o opens the single link in the enclosing entity: a heading's section, or a numbered multi-line bullet |
| repo | parley.nvim |
| issue file | workshop/issues/000327-alt-o-opens-the-single-link-in-the-enclosing-entity-a-heading-s-section-or-a-numbered-multi-line-bullet.md |
| boundary | whole-issue close |
| milestone | — |
| window | 41899819358e94ad39ffaaa0f4cb94963792708c..4cc8d81d76e780845659cdbe94363960a840ba9b |
| command | sdlc close --issue 327 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T04:20:34-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation largely matches the plan, and both mapped test groups pass. One blocking contract mismatch remains: numbered-item navigation treats reference-bearing structural lines as terminators, excluding a valid sole reference from its enclosing item.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: navigation-entity-boundaries
    title: |
      Numbered items exclude branch references before candidate collection
    detail: |
      lua/parley/entity_range.lua:412-413 treats every structural prefix as an item boundary, including 🌿:. On plain Markdown {"1. Follow up", "🌿: answer.md: answer"}, navigation_range(nil, lines, 1) returns first=1,last=1 and collect returns zero candidates; collecting both rows correctly finds the branch reference. Alt+o therefore falls back instead of opening the item's sole reference. ARCH-PURPOSE: enforce the documented numbered-anchor/heading boundaries with actual transcript protection, rather than applying all paragraph structural walls; sweep the other structural prefixes and add range plus command-level regressions.
```

1. **Strengths**

   - Shared occurrence scanners preserve legacy cursor-parser behavior and selected occurrence identity.
   - Pure pending/settled transitions reject canceled, stale and duplicate entity-picker callbacks.
   - Resolver tests exercise the real subprocess seam with controlled delayed completion.
   - README, atlas and traceability updates cover the new interaction.

2. **Critical findings**

   - [entity_range.lua:412](/Users/xianxu/Library/Caches/sdlc/review-checkouts/3f581dc4842502ec/lua/parley/entity_range.lua:412): overbroad structural boundaries exclude references belonging to numbered items. Narrow the boundary rule while preserving actual transcript protections.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Both `context/file_references` and `chat/entity_delete` mapped groups passed, including native Normal/Insert input, delayed resolution and editing parity. Lint passed for nine relevant files; range whitespace checks passed. Existing tests omit the branch-reference continuation case reproduced above. I did not rerun the full suite.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared scanners and existing opening helpers are reused.
   - **ARCH-PURE — pass:** range, enumeration and selection decisions consume values without IO.
   - **ARCH-PURPOSE — flag:** numbered-item containment underdelivers the documented boundary contract.
   - **ARCH-MOCK — pass:** resolver integration shares the production subprocess seam; existing conformance tooling remains available.
   - **ARCH-CONSTRAINTS — pass:** explicit-command scans and 5,000-line fixtures match the declared envelope.
   - **ARCH-SECURE — pass:** existing path refusal and argument-safe resolution remain in selected opening paths.
   - **ARCH-ORDER — pass:** explicit selection transitions and final-effect guards cover controlled callback orderings.
   - **ARCH-FUNERAL — pass:** no new durable runtime artifact family is introduced.

7. **Plan revision recommendations**

   Add a `## Revisions` entry recording the corrected numbered-item boundary rule and the sweep of structural-prefix cases. Keep operator live acceptance pending until the separately planned pre-merge check occurs.
