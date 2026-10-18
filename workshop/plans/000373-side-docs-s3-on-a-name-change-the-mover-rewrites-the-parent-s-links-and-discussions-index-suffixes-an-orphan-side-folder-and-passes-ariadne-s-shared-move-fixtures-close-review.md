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
