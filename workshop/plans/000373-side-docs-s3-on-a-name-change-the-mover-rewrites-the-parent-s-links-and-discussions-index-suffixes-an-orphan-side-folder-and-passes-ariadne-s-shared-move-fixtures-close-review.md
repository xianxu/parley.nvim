# Boundary Review — parley.nvim#373 (whole-issue close)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | whole-issue close |
| milestone | — |
| window | f34baf2c691eaa841ce9f74f056e28958e03024a..e3be73356c6bff50b6dbcb1612d2880ed9d16217 |
| command | sdlc close --issue 373 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T19:12:20-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The documented rename, reference rewrite, shared fixtures, and replayable finalization are implemented and covered by passing tests. One blocking path-overlap case remains: orphan displacement can move OLD itself away before the document rename, leaving an operation that reopening cannot recover.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Paragraph-wide code masks and both rewrite APIs' multiline-code regression cases preserve the covered bytes; mapped tests pass.
  - id: BR-2
    disposition: addressed
    note: |
      read_output checks every expected leaf and ancestor before mutation; the exhaustive leaf-directory and ancestor-file regressions pass.
  - id: BR-3
    disposition: addressed
    note: |
      Destination scanning uses disjoint token spans; complete-rewrite malformed-opener scale tests pass.
  - id: BR-4
    disposition: addressed
    note: |
      markdown_blocks supplies shared boundaries for link scanning and code masks; boundary and continuation regressions pass.
  - id: BR-5
    disposition: addressed
    note: |
      atlas/modes/session_sync.md:273 documents supplied observations, ordered effects, orphan_destination, and refusal rules, matching document_move_plan.project.
  - id: BR-6
    disposition: addressed
    note: |
      Finalization intent and protection checkpoints precede journal retirement. Fresh/recovered unlink regressions pass at HEAD; restoring pre-fix production files makes both behavioral recovery checks fail.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: output-preflight-before-mutation
    title: |
      Orphan displacement can relocate OLD and strand its migration
    detail: |
      lua/parley/document_move_plan.lua:363 checks only targets inside the source side tree. Moving /repo/parent.side/child.md to /repo/parent.md admits /repo/parent.side as an orphan, then document_move.lua:1093 renames it to parent_1.side before moving OLD. A pinned-HEAD filesystem reproduction moved both child.md and an unrelated sibling into that suffix, left OLD and NEW absent, and stopped in document with "owned document rename has no matching inode witness"; recover then refused "recovery paths changed". This is the 2nd finding in family output-preflight-before-mutation. State and enforce the rule across all planned document/side/orphan path relationships: an earlier effect must not relocate a later source. Reject unsafe overlaps before effects, or explicitly support their relocated witnesses and recovery. Add pure and filesystem regressions, including nested OLD with and without its own side tree and both owned/native entry paths. ARCH-PURPOSE, ARCH-ORDER.
```

1. **Strengths**

   - Shared manifest fixtures compare complete before/after trees through both projection and real filesystem execution.
   - Parent rewrites synchronize editor content before metadata confirmation while preserving operator edits.
   - Finalization now retains replayable authority through lock release and journal-unlink failures.
   - README and atlas describe the added behavior. Tracker issue #378 records the permitted Alt+o registration follow-up with concrete evidence.

2. **Critical findings**

   The overlap finding above blocks shipping. The safest fix is admission-time rejection of effect paths that relocate later sources. Cover the whole relationship class rather than adding one filename-specific guard.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Passed all 21 session-sync mapped test files, 23 Python export tests, 20 reference-candidate tests, and `git diff --check`. The added disposable overlap reproduction failed with the filesystem and recovery outcomes quoted above. Disposable files were removed; the checkout is clean.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared scalar, link, block-boundary, and finalization helpers.
   - **ARCH-PURE — pass:** projection and reducer tests exercise logic without IO mocks; effects remain in adapters.
   - **ARCH-PURPOSE — flag:** admission does not yet cover the complete path-overlap class.
   - **ARCH-MOCK — pass:** registry integration uses the existing transport and persistent fake.
   - **ARCH-CONSTRAINTS — pass:** bounded suffix search, scans, journals, and malformed-input tests.
   - **ARCH-SECURE — pass:** inspected persisted authority, byte witnesses, and foreign-content refusal paths.
   - **ARCH-ORDER — flag:** orphan-first execution can invalidate the subsequent document source.
   - **ARCH-FUNERAL — pass:** journal/temp cleanup and bounded retained operations have explicit ownership.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining the path-interference invariant, the supported or refused overlap relationships, and tests proving refusal occurs before any filesystem or protection effects.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4f0f0cba-eab4-49f4-b54f-40d574480977","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":7,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/c89ff574d82da946","reviewed_head":"e3be73356c6bff50b6dbcb1612d2880ed9d16217","slot":"parley.nvim:1","requested_at":"2026-10-18T02:08:11.381859Z"},"phase":"finished","pid":82244,"started_at":"2026-10-18T02:08:11.489592Z","finished_at":"2026-10-18T02:12:15.564866Z","session_id":"01a14cc4-3df5-7a92-9099-ede2ed0798ca","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T19:44:10-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | whole-issue close |
| milestone | — |
| window | f34baf2c691eaa841ce9f74f056e28958e03024a..06304d247169c708ac43a457c25ca76fc6e4d120 |
| command | sdlc close --issue 373 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T19:44:10-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies the issue’s Spec and revised Plan. BR-7 is addressed by a shared, reachable geometry guard, with independently verified regression failures when disabled. No new blocking findings remain.

1. **Strengths**

   - Geometry validation covers document, side-root, and selected orphan relationships before frontend saves or direct admission (`document_move_plan.lua:41`, `document_move.lua:52`, `agentic_document.lua:746`).
   - Shared fixtures exercise both pure projection and filesystem execution through the persistent registry fake (`document_move_shared_spec.lua:137`).
   - Fresh and recovered moves share checkpointed finalization, preserving protection authority until journal retirement (`document_move.lua:705`).
   - README and atlas document the new surface. Issue #378 records the permitted Alt+o registration follow-up.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - All 21 session-sync mapped specs passed after rerunning one spec interrupted by my overlapping harness invocation.
   - All 18 review mapped specs, 20 reference-candidate cases, and 23 Python export tests passed.
   - Lint passed across 786 files; range whitespace checks passed.
   - Negative control: disabling only `validate_geometry` produced **2 pure, 4 mover, and 16 frontend failures**, including the original stranded-source scenario. The temporary copy was removed.
   - The reviewed checkout is clean.

6. **Architectural notes**

   - **ARCH-DRY — pass:** one geometry predicate serves projection, admission, and journal validation.
   - **ARCH-PURE — pass:** projection and transition logic remain pure; filesystem fixture loading is classified as integration.
   - **ARCH-PURPOSE — pass:** parent references, orphan displacement, shared fixtures, and the registration audit are delivered.
   - **ARCH-MOCK — pass:** registry tests use the existing stateful fake behind the production transport seam.
   - **ARCH-CONSTRAINTS — pass:** file, tree, journal, and suffix bounds remain explicit; malformed-input scale regressions pass.
   - **ARCH-SECURE — pass:** persisted authority and path relationships are validated; unknown bytes are preserved.
   - **ARCH-ORDER — pass:** the reducer owns v2 progression; publication, checkpoint, recovery, and stale-event cases are exercised.
   - **ARCH-FUNERAL — pass:** journal/temp retirement is explicit; displaced orphan content is retained deliberately.

7. **Plan revision recommendations:** None. The existing BR-7 revision states the implemented rule and its regression matrix.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Paragraph-wide exact-width code masks are shared by both rewrite APIs; preservation regressions pass.
  - id: BR-2
    disposition: addressed
    note: |
      read_output preflights expected regular-file leaves and directory ancestors before mutation; Python regressions pass.
  - id: BR-3
    disposition: addressed
    note: |
      Malformed destination scanning advances through disjoint tokens; complete-rewrite scale regressions pass.
  - id: BR-4
    disposition: addressed
    note: |
      Code containment and reference scanning share markdown_blocks; boundary and continuation regressions pass.
  - id: BR-5
    disposition: addressed
    note: |
      atlas/modes/session_sync.md:274 documents supplied observations, effect ordering and orphan_destination, matching document_move_plan.project.
  - id: BR-6
    disposition: addressed
    note: |
      Finalization persists protection intent before release and retires disk effects before unlink; interruption and legacy recovery regressions pass.
  - id: BR-7
    disposition: addressed
    note: |
      Shared validate_geometry rejects interfering document/side/orphan relationships before effects and during journal validation. Disabling it independently produces 2 pure, 4 mover and 16 frontend failures; pinned-head regressions pass, including nested OLD with/without its side tree through owned/native paths.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"cc8cdccd-dd91-4ccf-aa3d-1100cbd273eb","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"milestone-review","round":8,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5f6af2146bf7b05e","reviewed_head":"06304d247169c708ac43a457c25ca76fc6e4d120","slot":"parley.nvim:1","requested_at":"2026-10-18T02:40:10.726331Z"},"phase":"finished","pid":59908,"started_at":"2026-10-18T02:40:10.819665Z","finished_at":"2026-10-18T02:44:04.648888Z","session_id":"01a14ce1-8733-7cc3-a591-5360f311d2d1","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T20:43:49-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 373 — side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000373-side-docs-s3-on-a-name-change-the-mover-rewrites-the-parent-s-links-and-discussions-index-suffixes-an-orphan-side-folder-and-passes-ariadne-s-shared-move-fixtures.md |
| boundary | whole-issue close |
| milestone | — |
| window | 955896049f49d0233a3c917c72e0ae0e081d358f..2af674c93083b7e2253ba0fd6d45991a07a87e3a |
| command | sdlc close --issue 373 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-17T20:43:49-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned interdiff preserves both sides of the test conflict resolution and introduces no production behavior or scope changes. No new defects found. Prior findings remain disposed; this narrow review does not reopen them.

1. **Strengths**

   - All 11 temporary-directory fixtures honor platform defaults and canonicalize paths before exporter checks (`tests/unit/review_protocol_export_test.py:101`).
   - Conflict resolution retains collaboration-mode, corruption, symlink, and mutation-free preflight assertions.
   - Issue Spec, Done-when, and implementation plan remain unchanged.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - All 23 export tests passed with default temporary-directory settings.
   - All 23 passed again with `TMPDIR=/tmp`.
   - Range whitespace checks passed; checkout remains clean at pinned HEAD.

6. **Architectural notes**

   - **ARCH-DRY — pass:** no duplicated production logic introduced.
   - **ARCH-PURE — pass:** filesystem setup remains in integration tests; production separation is unchanged.
   - **ARCH-PURPOSE — pass:** resolution preserves canonical-path safety and configurable temporary placement across every affected fixture.
   - No new user-facing or architectural surface requires README or atlas updates.

7. **Plan revision recommendations:** None.

No pending prior findings require disposition, and no new findings were raised.

```findings
{}
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"99603697-415e-4943-8063-600218ddfaee","repository":"github.com/xianxu/parley.nvim","issue_id":"000373","recipe":"fix-review","round":9,"attempt":1,"agent":"codex","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/4861a43fa861b0e3","reviewed_head":"2af674c93083b7e2253ba0fd6d45991a07a87e3a","slot":"parley.nvim:1","requested_at":"2026-10-18T03:43:10.751848Z"},"phase":"finished","pid":47505,"started_at":"2026-10-18T03:43:10.864934Z","finished_at":"2026-10-18T03:43:49.353804Z","session_id":"01a14d1b-34fd-78c3-87b2-83c0da777838","outcome":"returned"}] -->
