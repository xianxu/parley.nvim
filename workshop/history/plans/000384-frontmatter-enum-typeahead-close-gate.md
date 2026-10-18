---
gate: boundary-review
issue: 384
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 4c9dc90a-9f65-4ec5-8633-55c052871ee9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000384"
            recipe: milestone-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/3df66a58c64a6a70
            reviewed_head: 2ebbd9e0c3dda31b52ba9d7df1a2c4a29af88f7e
            slot: parley.nvim:3
            requested_at: "2026-10-18T08:27:45.733548Z"
          phase: finished
          pid: 42690
          started_at: "2026-10-18T08:27:45.829522Z"
          finished_at: "2026-10-18T08:29:27.695015Z"
          session_id: a7f497bb-5ccd-4a61-acfe-6ad8487a5e3f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2ebbd9e0c3dda31b52ba9d7df1a2c4a29af88f7e
        tracker_head: 5be351563815f349f6a3f321a29f9ccfe8b913c8
        branch_point: 48d7874c658aa3a0bc60f27cfb2216bcc2dc510c
        since: "2026-10-18T00:28:57-07:00"
        until: "2026-10-18T01:27:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T00:28:57-07:00"
              end: "2026-10-18T01:27:30-07:00"
              began: "2026-10-18T00:28:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 73774aaa489d6dc2124efe6a02be0ee96578c877a9be07ebd9ebdc3322bfaed6
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 29298622
              windows:
                - start: "2026-10-18T00:28:57-07:00"
                  end: "2026-10-18T01:27:30-07:00"
        queue_waits:
            - attempt_id: f08b75714d7659d1dff169175d0cbb7c
              slot: parley.nvim:3
              record_digest: e66e1343bcdfb870fa5d33a9b4a547740e8f4702c8b428e190343e8e3d37ecce
              start: "2026-10-18T07:55:32.012565Z"
              end: "2026-10-18T08:24:39.728537Z"
              queue_seconds: 1747.715972
              raw_seconds: 1747.715972
              exact: true
      "n": 1
      timestamp: "2026-10-18T01:29:31-07:00"
      dispatched: "2026-10-18T01:27:45-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: status applies() dropped the symlink resolution the deleted init.lua typeahead did
          detail: frontmatter_enum.lua:30-33 compares the raw buffer name to get_issues_dir() (built from getcwd's git root) without vim.fn.resolve; the removed init.lua block resolved both sides. In a symlinked workspace, issue files silently lose status completion. Resolve both paths and add a symlinked-dir integration case.
          family: path-canonicalization-before-prefix-match
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Spec promises an omnifunc fallback and the Plan's Integration bullet omits the cmp source that shipped
          detail: No omnifunc exists. The frontmatter_enum.lua:4 header claims one, and the Plan bullet and first Log entry say no cmp source is added, which a later Log entry reverses. Add a Revisions entry describing the cmp source plus Vim-popup fallback, and fix the header comment.
          family: plan-spec-drift-from-shipped-mechanism
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: issues.complete_frontmatter_values has no production caller and repeats the candidates prefix filter
          detail: issues.lua:210 is now used only by tests. Delete it and move its tests onto the registry, or have the status declaration go through it (ARCH-DRY, ARCH-FUNERAL).
          family: orphaned-duplicate-helper
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Unit spec declares test-mode/test-scoped into the global registry with no teardown
          detail: M.keys() permanently includes the test keys for any later spec in the same process; there is no undeclare.
          family: test-global-state-leak
          round: 1
        - kind: defect
          id: BR-5
          severity: Minor
          title: cmp path is covered only by a hand-written stub of the nvim-cmp API
          detail: get_config().enabled, setup.buffer and register_source semantics are assumed. The real-config check was manual and recorded only in the Log (ARCH-MOCK).
          family: stub-without-conformance
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a5341ddc-e057-462e-a48c-d01a6526bbec
            repository: github.com/xianxu/parley.nvim
            issue_id: "000384"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/d0542d1c0f803c5c
            reviewed_head: 9e3ea59d8048877d821f8b18a8af690530a5c02b
            slot: parley.nvim:3
            requested_at: "2026-10-18T08:59:06.585637Z"
          phase: finished
          pid: 24601
          started_at: "2026-10-18T08:59:06.894225Z"
          finished_at: "2026-10-18T09:01:53.268347Z"
          session_id: 80ae0c69-c096-42f2-8e2f-ee655e3fa1d0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9e3ea59d8048877d821f8b18a8af690530a5c02b
        tracker_head: 846b14dc755cb99caeb73f35864d9a1248e32e62
        branch_point: 48d7874c658aa3a0bc60f27cfb2216bcc2dc510c
        since: "2026-10-18T00:28:57-07:00"
        until: "2026-10-18T01:31:55-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-18T00:28:57-07:00"
              end: "2026-10-18T01:31:55-07:00"
              began: "2026-10-18T00:28:57-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 72a609154e5ba29093af81c09c28106381f81b0fa169d9abd54c565f9d751fd4
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 29606596
              windows:
                - start: "2026-10-18T00:28:57-07:00"
                  end: "2026-10-18T01:31:55-07:00"
        queue_waits:
            - attempt_id: f08b75714d7659d1dff169175d0cbb7c
              slot: parley.nvim:3
              record_digest: e66e1343bcdfb870fa5d33a9b4a547740e8f4702c8b428e190343e8e3d37ecce
              start: "2026-10-18T07:55:32.012565Z"
              end: "2026-10-18T08:24:39.728537Z"
              queue_seconds: 1747.715972
              raw_seconds: 1747.715972
              exact: true
        cuts:
            - dispatched: "2026-10-18T01:27:45-07:00"
              finalized: "2026-10-18T01:29:31-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-18T02:01:54-07:00"
      dispatched: "2026-10-18T01:59:06-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: real() resolves both sides (frontmatter_enum.lua:31). Reverting it in the disposable checkout fails the symlinked-workspace spec, and restoring it passes.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The Spec bullet, the Plan Integration bullet (cmp source plus Vim fallback, no omnifunc), the Revisions entries and the header comment at frontmatter_enum.lua:4-5 all match the code.
          round: 2
        - id: BR-3
          disposition: addressed
          note: complete_frontmatter_values and enumerable_values are deleted, a grep finds no remaining references, and their tests now go through status_values() and the registry.
          round: 2
        - id: BR-4
          disposition: addressed
          note: M.undeclare was added, the unit spec's after_each tears down both test keys, and a spec checks keys() afterwards.
          round: 2
        - id: BR-5
          disposition: addressed
          note: scripts/check-frontmatter-cmp.lua is a repeatable live check against the real cmp, documented in atlas. Not run here because it loads the operator's config; its make wiring is raised as a new Minor finding.
          round: 2
      findings:
        - kind: defect
          id: BR-6
          severity: Minor
          title: Live cmp conformance script is not a make check-*-conformance target
          detail: '2nd in family. Rule: every stub of an external dependency gets its conformance check as a named make check-*-conformance target in the Makefile.parley help, as with the sdlc and couch checks. Add check-frontmatter-cmp-conformance running scripts/check-frontmatter-cmp.lua.'
          family: stub-without-conformance
          round: 2
        - kind: defect
          id: BR-7
          severity: Minor
          title: status applies() re-implements the issue-file check from init.lua detect_buffer_context
          detail: '2nd in family. Rule: whether a path is inside a configured directory is decided by one helper that resolves both sides and compares with a trailing separator. Prevalence: 16 resolve(fnamemodify) sites in lua/. For this issue, add issues.is_issue_file(path) and use it from frontmatter_enum.lua and from init.lua around line 1662.'
          family: path-canonicalization-before-prefix-match
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 9e3ea59d8048877d821f8b18a8af690530a5c02b
      blocked: false
---

# Gate ledger — parley.nvim#384 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-18T01:29:31-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `path-canonicalization-before-prefix-match` (kind: defect) status applies() dropped the symlink resolution the deleted init.lua typeahead did
  frontmatter_enum.lua:30-33 compares the raw buffer name to get_issues_dir() (built from getcwd's git root) without vim.fn.resolve; the removed init.lua block resolved both sides. In a symlinked workspace, issue files silently lose status completion. Resolve both paths and add a symlinked-dir integration case.
- **BR-2** [Important] `plan-spec-drift-from-shipped-mechanism` (kind: defect) Spec promises an omnifunc fallback and the Plan's Integration bullet omits the cmp source that shipped
  No omnifunc exists. The frontmatter_enum.lua:4 header claims one, and the Plan bullet and first Log entry say no cmp source is added, which a later Log entry reverses. Add a Revisions entry describing the cmp source plus Vim-popup fallback, and fix the header comment.
- **BR-3** [Minor] `orphaned-duplicate-helper` (kind: defect) issues.complete_frontmatter_values has no production caller and repeats the candidates prefix filter
  issues.lua:210 is now used only by tests. Delete it and move its tests onto the registry, or have the status declaration go through it (ARCH-DRY, ARCH-FUNERAL).
- **BR-4** [Minor] `test-global-state-leak` (kind: defect) Unit spec declares test-mode/test-scoped into the global registry with no teardown
  M.keys() permanently includes the test keys for any later spec in the same process; there is no undeclare.
- **BR-5** [Minor] `stub-without-conformance` (kind: defect) cmp path is covered only by a hand-written stub of the nvim-cmp API
  get_config().enabled, setup.buffer and register_source semantics are assumed. The real-config check was manual and recorded only in the Log (ARCH-MOCK).

## Round 2 — 2026-10-18T02:01:54-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — real() resolves both sides (frontmatter_enum.lua:31). Reverting it in the disposable checkout fails the symlinked-workspace spec, and restoring it passes.
- BR-2 — addressed — The Spec bullet, the Plan Integration bullet (cmp source plus Vim fallback, no omnifunc), the Revisions entries and the header comment at frontmatter_enum.lua:4-5 all match the code.
- BR-3 — addressed — complete_frontmatter_values and enumerable_values are deleted, a grep finds no remaining references, and their tests now go through status_values() and the registry.
- BR-4 — addressed — M.undeclare was added, the unit spec's after_each tears down both test keys, and a spec checks keys() afterwards.
- BR-5 — addressed — scripts/check-frontmatter-cmp.lua is a repeatable live check against the real cmp, documented in atlas. Not run here because it loads the operator's config; its make wiring is raised as a new Minor finding.

### Raised

- **BR-6** [Minor] `stub-without-conformance` (kind: defect) Live cmp conformance script is not a make check-*-conformance target
  2nd in family. Rule: every stub of an external dependency gets its conformance check as a named make check-*-conformance target in the Makefile.parley help, as with the sdlc and couch checks. Add check-frontmatter-cmp-conformance running scripts/check-frontmatter-cmp.lua.
- **BR-7** [Minor] `path-canonicalization-before-prefix-match` (kind: defect) status applies() re-implements the issue-file check from init.lua detect_buffer_context
  2nd in family. Rule: whether a path is inside a configured directory is decided by one helper that resolves both sides and compares with a trailing separator. Prevalence: 16 resolve(fnamemodify) sites in lua/. For this issue, add issues.is_issue_file(path) and use it from frontmatter_enum.lua and from init.lua around line 1662.

## Open findings

- **BR-6** [Minor] `stub-without-conformance` (kind: defect) Live cmp conformance script is not a make check-*-conformance target
- **BR-7** [Minor] `path-canonicalization-before-prefix-match` (kind: defect) status applies() re-implements the issue-file check from init.lua detect_buffer_context
