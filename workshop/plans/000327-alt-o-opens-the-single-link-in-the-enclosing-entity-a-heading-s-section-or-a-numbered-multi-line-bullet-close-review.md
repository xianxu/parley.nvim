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

---

## Re-review — 2026-10-15T05:06:37-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 327 — Alt+o opens the single link in the enclosing entity: a heading's section, or a numbered multi-line bullet |
| repo | parley.nvim |
| issue file | workshop/issues/000327-alt-o-opens-the-single-link-in-the-enclosing-entity-a-heading-s-section-or-a-numbered-multi-line-bullet.md |
| boundary | whole-issue close |
| milestone | — |
| window | 41899819358e94ad39ffaaa0f4cb94963792708c..26d0fd97f07f0fae29df288211944df3f763cd43 |
| command | sdlc close --issue 327 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-15T05:06:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The implementation matches the navigation Spec, preserves editing behavior, and fixes BR-1 with effective regressions. All 473 tests across the two mapped suites passed, alongside lint and whitespace checks. One Important architecture gap remains: the newly extended resolver fake lacks a corresponding live contract check.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      entity_range.lua:421-425 retains annotation continuations while protecting transcript turns. With the pre-fix range module loaded, the head's tests fail in 22 range cases and four command cases, including branch-reference navigation; all pass at head.
findings:
  - id: new
    severity: Important
    kind: defect
    family: external-dependency-conformance
    title: |
      New resolver fake has no live resolver contract check
    detail: |
      ARCH-MOCK: tests/fixtures/fake_sdlc:13-36 introduces modeled resolve argv and JSON output, but tests/integration/entity_resolve_spec.lua only compares this fake with seeded expectations. Makefile.parley:275-279 checks real sdlc help commands, not resolution. Add an opt-in conformance check using isolated temporary project state that verifies the real resolver's consumed argv/output contract, and document its execution cadence.
```

1. **Strengths**

   - Navigation has a separate entry point, preserving text-object/delete semantics (`lua/parley/entity_range.lua:395,407`).
   - Shared scanners preserve occurrence identity and prevent nested reference spellings from becoming extra choices.
   - Picker completion explicitly rejects canceled, duplicate and stale callbacks (`lua/parley/reference_candidates.lua:105`).
   - README, atlas and traceability updates cover the new interaction and internal surfaces.

2. **Critical findings**

   None. BR-1 is addressed.

3. **Important findings**

   The resolver conformance gap above. Extend the existing maintainer target to exercise actual resolution against temporary fixtures and compare the consumed response shape with the fake.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `context/file_references`: 364 passing tests across 15 files.
   - `chat/entity_delete`: 109 passing tests across five files.
   - Tests include native Normal/Insert Alt+o input, editing parity, configured prefixes, fenced samples, and controlled delayed resolver completion.
   - Loading the pre-fix range module produced the expected regression failures without modifying tracked files.
   - Luacheck: zero warnings/errors across eight inspected files. `git diff --check` passed.
   - Full repository suite and operator live acceptance were not independently rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** canonical scanners and existing opening/resolution helpers are reused.
   - **ARCH-PURE — pass:** range, occurrence and selection decisions consume values; editor effects remain at the boundary. Core-concept entities exist at the documented locations.
   - **ARCH-PURPOSE — pass:** numbered continuations, heading sections, ambiguity and fallback are delivered; BR-1’s prefix class is swept.
   - **ARCH-MOCK — flag:** stateful fake and production seam are shared, but resolver conformance is missing.
   - **ARCH-CONSTRAINTS — pass:** command-triggered scans, selected-only resolution and 5,000-line coverage match the declared envelope.
   - **ARCH-SECURE — pass:** selected destinations retain existing refusal and argument-safe resolver paths.
   - **ARCH-ORDER — pass:** explicit pending/settled selection and delayed-effect guards have controlled ordering tests.
   - **ARCH-FUNERAL — pass:** no new durable runtime artifacts; temporary fixtures have cleanup paths.

7. **Plan revision recommendations**

   Add a `## Revisions` entry naming the resolver conformance check, isolated fixture setup, consumed contract cases and execution cadence.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"bb184230-a2ac-4eab-b543-7d9e2a218972","repository":"github.com/xianxu/parley.nvim","issue_id":"000327","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5a16cdfc27c5da03","reviewed_head":"26d0fd97f07f0fae29df288211944df3f763cd43","slot":"parley.nvim:2","requested_at":"2026-10-15T12:03:19.578008Z"},"phase":"finished","pid":89869,"started_at":"2026-10-15T12:03:19.700149Z","finished_at":"2026-10-15T12:06:32.918347Z","session_id":"01a13f72-070c-74d3-b3f3-d4c80aded942","outcome":"returned"}] -->
