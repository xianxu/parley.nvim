---
gate: boundary-review
issue: 423
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 8b505bf7-c68d-49f2-96ec-fe8e48b45e31
            repository: github.com/xianxu/parley.nvim
            issue_id: "000423"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/b81687d11e46cbd5
            reviewed_head: 3f63c3b3a684d4452287b5e0619fb89e903e9012
            slot: parley.nvim:1
            requested_at: "2026-10-23T11:38:02.232548Z"
          phase: finished
          pid: 23957
          started_at: "2026-10-23T11:38:02.395336Z"
          finished_at: "2026-10-23T11:45:35.854935Z"
          session_id: 6f3c9f0a-2c45-42cd-8b1c-ee9d1ea1f71b
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 3f63c3b3a684d4452287b5e0619fb89e903e9012
        tracker_head: 06b3758a0a63f68ccdb51a471d2da276e20f37d3
        branch_point: a2dca3b56fd352edee6601eab68c6e88b2b6d4d7
        since: "2026-10-23T04:29:39-07:00"
        until: "2026-10-23T04:37:20-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T04:29:39-07:00"
              end: "2026-10-23T04:37:20-07:00"
              began: "2026-10-23T04:29:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 0007176f948cc0e9c8c92a3dbd74e6096683b3cc2bf9362422905ac0080e92a3
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 2715151
              windows:
                - start: "2026-10-23T04:29:39-07:00"
                  end: "2026-10-23T04:37:20-07:00"
      "n": 1
      timestamp: "2026-10-23T04:45:37-07:00"
      dispatched: "2026-10-23T04:38:02-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Length check runs before the 422 checks; guard specs fail on roots the guard accepts
          detail: 'scripts/test-placement.sh:31-37 runs the TMPDIR length refusal before the marker/checkout walk. The fixture roots in tests/arch/scratch_placement_spec.lua:195-226 are about 70 bytes longer than the harness TMPDIR. Reproduced: make test-spec SPEC=infra/test_harness TEST_ENV_ROOT=<171-byte path> fails all six pre-write guard cases, and the marker and checkout refusals are masked by the length message. The default root of this checkout passes with 2 bytes to spare. Same family: path_of at :229-234 asserts (bare assert) once base is longer than about 184 bytes. Fix: move the length check after the walk, and make the fixtures short or relative (vim.system cwd=base, relative roots) so they hold at any accepted root length.'
          family: guard-fixture-length-budget
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: test-placement.sh counts characters, not bytes, so a non-ASCII root over the limit passes
          detail: 'scripts/test-placement.sh:32 uses the ${#tmp} expansion. macOS /bin/sh is bash and counts characters under a UTF-8 locale (verified: éé gives 2). Neovim''s limit is in bytes, so a non-ASCII TEST_ENV_ROOT over 189 bytes passes the pre-write guard and prints a wrong byte count. Fix: printf %s "$tmp" | wc -c, or set LC_ALL=C before the expansion. Add a non-ASCII guard case.'
          family: byte-vs-char-length
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: The is-under prefix check is written three times in scratch_placement_spec
          detail: 'Lines 27, 45 and 262 each write sub(1, #dir+1) == dir .. "/". Extract an is_under(dir, path) helper (ARCH-DRY).'
          family: path-containment-helper
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 47e99c73-bed1-4908-a823-43b2f1b757f0
            repository: github.com/xianxu/parley.nvim
            issue_id: "000423"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/332d857b280cbfbf
            reviewed_head: f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08
            slot: parley.nvim:1
            requested_at: "2026-10-23T12:04:20.092404Z"
          phase: finished
          pid: 50229
          started_at: "2026-10-23T12:04:20.221228Z"
          finished_at: "2026-10-23T12:13:30.948171Z"
          session_id: 1e8bf238-ea07-4c5f-90d8-883c09b98af7
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08
        tracker_head: 06b3758a0a63f68ccdb51a471d2da276e20f37d3
        branch_point: a2dca3b56fd352edee6601eab68c6e88b2b6d4d7
        since: "2026-10-23T04:29:39-07:00"
        until: "2026-10-23T05:03:49-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T04:29:39-07:00"
              end: "2026-10-23T05:03:49-07:00"
              began: "2026-10-23T04:29:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 5e627659bf68a784c60f23a86a96686b1ce679dfefeef616815e4d9fbd1aaa3b
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 3128435
              windows:
                - start: "2026-10-23T04:29:39-07:00"
                  end: "2026-10-23T05:03:49-07:00"
        cuts:
            - dispatched: "2026-10-23T04:38:02-07:00"
              finalized: "2026-10-23T04:45:37-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-23T05:13:32-07:00"
      dispatched: "2026-10-23T05:04:20-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Reproduced fix: all guard and pin cases pass at a 185-byte TEST_ENV_ROOT (189-byte ROOT/tmp); moving the length check before the walk turns "reports a marker before the TMPDIR length" red.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: Reverting to the ${#tmp} expansion turns "counts the TMPDIR limit in bytes, not characters" red (93 é = 190 bytes / 97 chars); restored and green.
          round: 2
        - id: BR-3
          disposition: addressed
          note: is_under helper at scratch_placement_spec.lua:24-26 now serves the repo check, the in-process TMPDIR check and the pin probe.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Pre-write guard ignores Neovim's absolute-path limit, so a relative TEST_ENV_ROOT escapes it
          detail: 'scripts/test-placement.sh:44-52 measures only the raw ROOT/tmp string. Neovim also limits the absolute path (about 234 bytes; the spec comment at :275-277 says so). Probe: TMPDIR=t under a 240-byte cwd gave a truncated tempname "…/t/nvim.xianxu/", and the in-process :h-under-TMPDIR check would also pass on it. Fix: make ROOT absolute before measuring, or document that the guard assumes an absolute root. This is the only instance in the window.'
          family: nvim-tmpdir-limit-model
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: f0e50f6edcf4b76e2fe2655ec20587f0e61c0b08
      blocked: false
---

# Gate ledger — parley.nvim#423 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T04:45:37-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `guard-fixture-length-budget` (kind: defect) Length check runs before the 422 checks; guard specs fail on roots the guard accepts
  scripts/test-placement.sh:31-37 runs the TMPDIR length refusal before the marker/checkout walk. The fixture roots in tests/arch/scratch_placement_spec.lua:195-226 are about 70 bytes longer than the harness TMPDIR. Reproduced: make test-spec SPEC=infra/test_harness TEST_ENV_ROOT=<171-byte path> fails all six pre-write guard cases, and the marker and checkout refusals are masked by the length message. The default root of this checkout passes with 2 bytes to spare. Same family: path_of at :229-234 asserts (bare assert) once base is longer than about 184 bytes. Fix: move the length check after the walk, and make the fixtures short or relative (vim.system cwd=base, relative roots) so they hold at any accepted root length.
- **BR-2** [Important] `byte-vs-char-length` (kind: defect) test-placement.sh counts characters, not bytes, so a non-ASCII root over the limit passes
  scripts/test-placement.sh:32 uses the ${#tmp} expansion. macOS /bin/sh is bash and counts characters under a UTF-8 locale (verified: éé gives 2). Neovim's limit is in bytes, so a non-ASCII TEST_ENV_ROOT over 189 bytes passes the pre-write guard and prints a wrong byte count. Fix: printf %s "$tmp" | wc -c, or set LC_ALL=C before the expansion. Add a non-ASCII guard case.
- **BR-3** [Minor] `path-containment-helper` (kind: defect) The is-under prefix check is written three times in scratch_placement_spec
  Lines 27, 45 and 262 each write sub(1, #dir+1) == dir .. "/". Extract an is_under(dir, path) helper (ARCH-DRY).

## Round 2 — 2026-10-23T05:13:32-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Reproduced fix: all guard and pin cases pass at a 185-byte TEST_ENV_ROOT (189-byte ROOT/tmp); moving the length check before the walk turns "reports a marker before the TMPDIR length" red.
- BR-2 — addressed — Reverting to the ${#tmp} expansion turns "counts the TMPDIR limit in bytes, not characters" red (93 é = 190 bytes / 97 chars); restored and green.
- BR-3 — addressed — is_under helper at scratch_placement_spec.lua:24-26 now serves the repo check, the in-process TMPDIR check and the pin probe.

### Raised

- **BR-4** [Minor] `nvim-tmpdir-limit-model` (kind: defect) Pre-write guard ignores Neovim's absolute-path limit, so a relative TEST_ENV_ROOT escapes it
  scripts/test-placement.sh:44-52 measures only the raw ROOT/tmp string. Neovim also limits the absolute path (about 234 bytes; the spec comment at :275-277 says so). Probe: TMPDIR=t under a 240-byte cwd gave a truncated tempname "…/t/nvim.xianxu/", and the in-process :h-under-TMPDIR check would also pass on it. Fix: make ROOT absolute before measuring, or document that the guard assumes an absolute root. This is the only instance in the window.

## Open findings

- **BR-4** [Minor] `nvim-tmpdir-limit-model` (kind: defect) Pre-write guard ignores Neovim's absolute-path limit, so a relative TEST_ENV_ROOT escapes it
