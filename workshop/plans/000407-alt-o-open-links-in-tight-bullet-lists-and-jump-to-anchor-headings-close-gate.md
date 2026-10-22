---
gate: boundary-review
issue: 407
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 82ab64a5-f261-4af6-9b8f-6e994ebdd019
            repository: github.com/xianxu/parley.nvim
            issue_id: "000407"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/a1538422336d9009
            reviewed_head: 97b6fdd13e633765a7eeafe6437f8044d725de6a
            slot: parley.nvim:2
            requested_at: "2026-10-21T20:03:01.342784Z"
          phase: finished
          pid: 95352
          started_at: "2026-10-21T20:03:01.450449Z"
          finished_at: "2026-10-21T20:06:19.838619Z"
          session_id: 01a1600f-5bde-7221-aef6-4347e72104db
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 97b6fdd13e633765a7eeafe6437f8044d725de6a
        tracker_head: 346dbbcc26b6d61639607e0526e7e3a923b97f7d
        branch_point: 220b67af621c39fce796dc9a901b81d4d33c8d50
        since: "2026-10-21T08:52:51-07:00"
        until: "2026-10-21T13:02:44-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T08:52:51-07:00"
              end: "2026-10-21T13:02:44-07:00"
              began: "2026-10-21T08:52:51-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 6062af71dcd911fb8dcd8baa619699786c93b20a8071fd85fbe9cdb2f2548051
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 65195225
              windows:
                - start: "2026-10-21T08:52:51-07:00"
                  end: "2026-10-21T13:02:44-07:00"
            - harness: codex
              id: 01a15f2a-cb84-75e2-ac43-0756ea7d3166
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e11f7236b68fea41303a58d0d0f1f0c10584246b86a5f3fd310c34645cf5bb77
              started: "2026-10-21T15:53:22.681Z"
              spawned: true
              bytes: 464175
              windows:
                - start: "2026-10-21T15:53:22.681Z"
                  end: "2026-10-21T13:02:44-07:00"
            - harness: codex
              id: 01a15f2c-08fd-7e41-b003-4e483a250212
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 3266063c816da0abc2c4f9be4d55ca7f52432ce3cdba187da6556d3c134a4ef9
              started: "2026-10-21T15:54:44.03Z"
              spawned: true
              bytes: 365783
              windows:
                - start: "2026-10-21T15:54:44.03Z"
                  end: "2026-10-21T13:02:44-07:00"
        queue_waits:
            - attempt_id: b82743bbb46e9281aaf07b62cd3fa8a5
              slot: parley.nvim:2
              record_digest: a39c969e463bac1818051ab6d4b66ac7aa7c82947ea00df65413fef2cd65f422
              start: "2026-10-21T16:07:08.824199Z"
              end: "2026-10-21T17:33:16.104628Z"
              queue_seconds: 5167.280429
              raw_seconds: 5167.280429
              exact: true
      "n": 1
      timestamp: "2026-10-21T13:06:20-07:00"
      dispatched: "2026-10-21T13:03:01-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      findings:
        - id: BR-1
          severity: Critical
          title: GitHub-style anchors fail for whitespace and formatted headings
          detail: 'lua/parley/markdown_heading.lua:31-35 slugs raw Markdown without trimming heading whitespace or extracting rendered text. Probes return nil for fragment "target" against "# Target ", "# _Target_", "# [Target](file.md)", and "# <em>Target</em>". The whitespace conversion also turns tabs into hyphens rather than removing them. These are all instances in the new normalization pipeline: whitespace trimming/conversion and inline-markup removal. Normalize heading content before slugging, preserve literal underscores appropriately, and add regressions for these cases and their duplicate suffixes. ARCH-PURPOSE: the documented GitHub-style anchor contract is not yet fulfilled.'
          family: heading-anchor-normalization
          round: 1
        - id: BR-2
          severity: Critical
          title: Anchor lookup treats shorter or different fence delimiters as closers
          detail: 'lua/parley/markdown_heading.lua:28 uses document.lexical.code_block_memo, whose boolean toggle ignores opener character and length. For lines {"````md", "```", "# Fake", "````", "# Real"}, anchor_row returns row 3 for "fake" and nil for "real": it exposes a code example and hides the actual heading. All affected delimiter classes are shorter backtick closers, shorter tilde closers, and mixed backtick/tilde delimiters; the new anchor lookup consumes the shared memo for all of them. Correct the shared fence-state implementation, retaining the existing partition policy, and add regressions for false headings inside and real headings after each case. ARCH-DRY: repair the shared implementation rather than adding an anchor-only fence parser.'
          family: fence-containment
          round: 1
        - id: BR-3
          severity: Critical
          title: A dedented fenced block lets a bullet absorb an outside paragraph
          detail: 'lua/parley/entity_range.lua:419-428 skips boundary detection on a fence opener because that row is already marked in_code. For {"- Chosen prose", "", "```md", "sample", "```", "[outside](outside.md)"}, navigation_range at row 1 returns rows 1-6, and reference_candidates.collect returns the outside link as its sole candidate. Alt+O therefore opens a reference outside the selected item. The same probe reproduces with tilde fences; the shared branch affects all three accepted bullet markers (-, +, *). Detect a dedented block boundary before skipping fenced contents, while retaining genuinely indented fences inside items. Add range and mapped navigation regressions for both fence styles. ARCH-PURPOSE: item navigation must remain confined to its enclosing item.'
          family: navigation-item-boundaries
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 95a3ee9a-b4ed-4cc6-87d5-8bc8479c1233
            repository: github.com/xianxu/parley.nvim
            issue_id: "000407"
            recipe: milestone-review
            round: 2
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/32b04cd88f21d5d0
            reviewed_head: 2222dd74e8451675e1252eda02b9b433a93ade62
            slot: parley.nvim:2
            requested_at: "2026-10-21T23:31:16.075406Z"
          phase: finished
          pid: 81888
          started_at: "2026-10-21T23:31:16.246311Z"
          finished_at: "2026-10-21T23:34:57.235616Z"
          session_id: 01a160ce-040d-7750-89ca-cb7ffaa18c74
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 2222dd74e8451675e1252eda02b9b433a93ade62
        tracker_head: 48c611eb21ea691293b0fcb721cf6b6cbf3c2d3a
        branch_point: 220b67af621c39fce796dc9a901b81d4d33c8d50
        since: "2026-10-21T08:52:51-07:00"
        until: "2026-10-21T16:30:50-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T08:52:51-07:00"
              end: "2026-10-21T16:30:50-07:00"
              began: "2026-10-21T08:52:51-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 64fe86316a7e401fc4a2b544d4ff25c159e2ae0683d74e47a7db1255540d680e
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 66433103
              windows:
                - start: "2026-10-21T08:52:51-07:00"
                  end: "2026-10-21T16:30:50-07:00"
            - harness: codex
              id: 01a15f2a-cb84-75e2-ac43-0756ea7d3166
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e11f7236b68fea41303a58d0d0f1f0c10584246b86a5f3fd310c34645cf5bb77
              started: "2026-10-21T15:53:22.681Z"
              spawned: true
              bytes: 464175
              windows:
                - start: "2026-10-21T15:53:22.681Z"
                  end: "2026-10-21T16:30:50-07:00"
            - harness: codex
              id: 01a15f2c-08fd-7e41-b003-4e483a250212
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 3266063c816da0abc2c4f9be4d55ca7f52432ce3cdba187da6556d3c134a4ef9
              started: "2026-10-21T15:54:44.03Z"
              spawned: true
              bytes: 365783
              windows:
                - start: "2026-10-21T15:54:44.03Z"
                  end: "2026-10-21T16:30:50-07:00"
            - harness: codex
              id: 01a16044-5881-74c0-a2b6-ead7290fb9ed
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 15f0962aa54ae5424cf9e89322d91442796e24a5a54e5497421708fac7d92593
              started: "2026-10-21T21:00:54.365Z"
              spawned: true
              bytes: 736494
              windows:
                - start: "2026-10-21T21:00:54.365Z"
                  end: "2026-10-21T16:30:50-07:00"
        queue_waits:
            - attempt_id: b82743bbb46e9281aaf07b62cd3fa8a5
              slot: parley.nvim:2
              record_digest: a39c969e463bac1818051ab6d4b66ac7aa7c82947ea00df65413fef2cd65f422
              start: "2026-10-21T16:07:08.824199Z"
              end: "2026-10-21T17:33:16.104628Z"
              queue_seconds: 5167.280429
              raw_seconds: 5167.280429
              exact: true
            - attempt_id: 61931a910072cb5f0afd04b1c306ef11
              slot: parley.nvim:2
              record_digest: 7b4149bd9f67a09aaaa7a389a0e81928810e4e1e8be92a80a156dd006bcfb247
              start: "2026-10-21T21:12:53.382512Z"
              end: "2026-10-21T22:23:56.872603Z"
              queue_seconds: 4263.490091
              raw_seconds: 4263.490091
              exact: true
        cuts:
            - dispatched: "2026-10-21T13:03:01-07:00"
              finalized: "2026-10-21T13:06:20-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-21T16:34:58-07:00"
      dispatched: "2026-10-21T16:31:16-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'The original examples now pass, and loading the pre-repair heading module makes five current tests fail. However, rendered-content normalization remains incomplete at lua/parley/markdown_heading.lua:104-106,149-151: anchor_row({"# <em title=\"> more\">Target</em>"}, "target") returns nil and accepts "moretarget"; "# &#84;arget" accepts "84arget" instead of "target". Their normalized duplicate suffixes also fail. Complete the rendered-text rule across quoted HTML attributes and character references, preserving code/escaped-text controls, and add regression cases. ARCH-PURPOSE.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: The shared memo retains opener character/width and accepts only sufficient-length matching closers with whitespace-only suffixes. Current lexical tests pass 10/10; loading the pre-repair lexical module makes six tests fail, including shorter, mixed-character and invalid-suffix delimiters. Anchor-consumer and partition tests pass.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Opening-fence boundary detection now precedes fenced-content exclusion. Current range tests pass 84/84; loading the pre-repair range module fails all six bullet-marker/fence-style regressions. Native Normal/Insert mapping tests cover both fence styles, and indented-fence controls retain the inside link.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Critical
          title: Bullet navigation still absorbs links after outside Markdown blocks
          detail: 'lua/parley/entity_range.lua:425-430 uses the editing dialect''s column-zero, level-1–3 heading predicate and otherwise requires a preceding blank. For {"- Chosen prose", "#### Outside", "[outside](outside.md)"}, navigation_range returns bullet rows 1–3 and reference_candidates.collect returns outside.md as its sole candidate. Empty ATX headings, one-space-indented outside headings, thematic breaks and block quotes also reproduce containment failures. A sweep of three bullet markers, six heading levels, zero/one-space indentation and empty/nonempty headings fails 63/72 cases. This is the 2nd finding in family `navigation-item-boundaries`. Earlier rounds fixed instances. Do NOT fix this instance alone: state and enforce the rule that an outside block opener ends the item, enumerate the supported block classes and indentation ownership, and sweep them with range and mapped negative tests. Reuse navigation block classification without changing editing textobjects. ARCH-PURPOSE, ARCH-DRY.'
          family: navigation-item-boundaries
          round: 2
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 7bc92e0c-3066-43e2-adb7-8575fe9c3115
            repository: github.com/xianxu/parley.nvim
            issue_id: "000407"
            recipe: milestone-review
            round: 3
            attempt: 1
            agent: codex
            root: /Volumes/TestScratch/review-checkouts/1f88525da1432c80
            reviewed_head: fd85af66acd406f68f6f7dc65cb59bc85a6357df
            slot: parley.nvim:2
            requested_at: "2026-10-22T02:58:11.470274Z"
          phase: finished
          pid: 27169
          started_at: "2026-10-22T02:58:11.666531Z"
          finished_at: "2026-10-22T03:03:26.70307Z"
          session_id: 01a1618b-75f6-7e32-998c-780f11583d59
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: fd85af66acd406f68f6f7dc65cb59bc85a6357df
        tracker_head: 3821fadb4d0bfac2e58f74dead32cfc4d76e8856
        branch_point: 220b67af621c39fce796dc9a901b81d4d33c8d50
        since: "2026-10-21T08:52:51-07:00"
        until: "2026-10-21T19:51:03-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-21T08:52:51-07:00"
              end: "2026-10-21T19:51:03-07:00"
              began: "2026-10-21T08:52:51-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: 14b8f22b88f2f6be7c44f8fe2ca8f253c49f707a0614bc575f258d69b6bed4d5
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 68502298
              windows:
                - start: "2026-10-21T08:52:51-07:00"
                  end: "2026-10-21T19:51:03-07:00"
            - harness: codex
              id: 01a15f2a-cb84-75e2-ac43-0756ea7d3166
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: e11f7236b68fea41303a58d0d0f1f0c10584246b86a5f3fd310c34645cf5bb77
              started: "2026-10-21T15:53:22.681Z"
              spawned: true
              bytes: 464175
              windows:
                - start: "2026-10-21T15:53:22.681Z"
                  end: "2026-10-21T19:51:03-07:00"
            - harness: codex
              id: 01a15f2c-08fd-7e41-b003-4e483a250212
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 3266063c816da0abc2c4f9be4d55ca7f52432ce3cdba187da6556d3c134a4ef9
              started: "2026-10-21T15:54:44.03Z"
              spawned: true
              bytes: 365783
              windows:
                - start: "2026-10-21T15:54:44.03Z"
                  end: "2026-10-21T19:51:03-07:00"
            - harness: codex
              id: 01a16044-5881-74c0-a2b6-ead7290fb9ed
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 15f0962aa54ae5424cf9e89322d91442796e24a5a54e5497421708fac7d92593
              started: "2026-10-21T21:00:54.365Z"
              spawned: true
              bytes: 736494
              windows:
                - start: "2026-10-21T21:00:54.365Z"
                  end: "2026-10-21T19:51:03-07:00"
            - harness: codex
              id: 01a160e6-e83d-7442-afe2-dd0ae6d79092
              slot: parley.nvim:2
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              parent_id: 01a13b56-32ec-7310-8650-104071939f2f
              digest: 153c7c0a07dcb55c3c8e392226d5416b5e55e34d84f47dafb70f5e272513a51a
              started: "2026-10-21T23:58:28.077Z"
              spawned: true
              bytes: 869288
              windows:
                - start: "2026-10-21T23:58:28.077Z"
                  end: "2026-10-21T19:51:03-07:00"
        queue_waits:
            - attempt_id: b82743bbb46e9281aaf07b62cd3fa8a5
              slot: parley.nvim:2
              record_digest: a39c969e463bac1818051ab6d4b66ac7aa7c82947ea00df65413fef2cd65f422
              start: "2026-10-21T16:07:08.824199Z"
              end: "2026-10-21T17:33:16.104628Z"
              queue_seconds: 5167.280429
              raw_seconds: 5167.280429
              exact: true
            - attempt_id: 61931a910072cb5f0afd04b1c306ef11
              slot: parley.nvim:2
              record_digest: 7b4149bd9f67a09aaaa7a389a0e81928810e4e1e8be92a80a156dd006bcfb247
              start: "2026-10-21T21:12:53.382512Z"
              end: "2026-10-21T22:23:56.872603Z"
              queue_seconds: 4263.490091
              raw_seconds: 4263.490091
              exact: true
            - attempt_id: aa7b70d092639e85051983e51eb972a5
              slot: parley.nvim:2
              record_digest: e54140153d4aabfee409c5899a0c17a98d59ffe38aa931e132704955a0cb0de0
              start: "2026-10-22T00:08:32.304692Z"
              end: "2026-10-22T01:19:33.77842Z"
              queue_seconds: 4261.473728
              raw_seconds: 4261.473728
              exact: true
        cuts:
            - dispatched: "2026-10-21T13:03:01-07:00"
              finalized: "2026-10-21T13:06:20-07:00"
              finalizing: false
            - dispatched: "2026-10-21T16:31:16-07:00"
              finalized: "2026-10-21T16:34:58-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-21T20:03:27-07:00"
      dispatched: "2026-10-21T19:58:11-07:00"
      agent: codex
      reviewer: codex (openai; author openai)
      dispose:
        - id: BR-1
          disposition: not-addressed
          note: 'The HTML/entity dispute is supported: the revised Spec excludes those forms, and the current heading tests pass 15/15; loading the pre-correction module makes the unsupported-HTML regression fail. However, supported Markdown normalization remains incorrect at lua/parley/markdown_heading.lua:49-137. Headings "# _one _two_ three_", "# _Target __more___", "# ` a ` b", and "# [Target](file.md \"(title\")" fail their rendered-text anchors and duplicate suffixes: all eight checks fail. Retain BR-1 for these in-scope cases; ARCH-PURPOSE.'
          round: 3
        - id: BR-4
          disposition: addressed
          note: Shared markdown_blocks metadata now supplies block classes and content indentation to navigation_range. The 72-case heading boundary sweep passes at HEAD; loading the pre-fix range module in memory reproduces 63/72 failures. Current range tests pass 256/256 and native mapping tests pass 48/48, including outside-block negatives.
          round: 3
        - id: BR-2
          disposition: addressed
          note: 'Previously accepted correction remains intact: shared fence state retains opener character and width and requires a matching whitespace-only closer. Current lexical tests pass 10/10, with heading-consumer false-closer regressions also passing.'
          round: 3
        - id: BR-3
          disposition: addressed
          note: Previously accepted correction remains intact through the shared fence-opener metadata. Range and native mapping regressions retain dedented-fence exclusion and indented-fence ownership.
          round: 3
      recipe: milestone-review
      isolation: fenced
      blocked: true
disputes:
    - id: BR-1
      rationale: The remaining round-2 instances require HTML rendering and character-reference decoding. Hub delivery 8887bf7d-ec9d-40df-8c27-89b898c13b51 explicitly narrows the approved contract to Markdown ATX headings with inline Markdown formatting and excludes HTML/entity decoding; Spec, plan Revisions, README and atlas record that scope. Unsupported headings now define no anchor and use the existing file-top notice.
      evidence: 'make -k test-spec with temporary MAP_FILE selecting tests/unit/markdown_heading_spec.lua: RED /tmp/parley407-narrow-red.log fails the unsupported-HTML assertion; GREEN /tmp/parley407-narrow-green.log passes 15/15, including quoted HTML, decimal/hex/named entity rejection, protected code literals, normalized Markdown duplicates and bounded malformed-angle scans. Native fallback cases are included for the next mapped run; original Markdown normalization remains tested.'
      after: 2
      timestamp: "2026-10-22T00:05:26Z"
      by: Xian Xu on Xian’s MacBook Pro at parley.nvim:2 (/Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim)
---

# Gate ledger — parley.nvim#407 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-21T13:06:20-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `heading-anchor-normalization` GitHub-style anchors fail for whitespace and formatted headings
  lua/parley/markdown_heading.lua:31-35 slugs raw Markdown without trimming heading whitespace or extracting rendered text. Probes return nil for fragment "target" against "# Target ", "# _Target_", "# [Target](file.md)", and "# <em>Target</em>". The whitespace conversion also turns tabs into hyphens rather than removing them. These are all instances in the new normalization pipeline: whitespace trimming/conversion and inline-markup removal. Normalize heading content before slugging, preserve literal underscores appropriately, and add regressions for these cases and their duplicate suffixes. ARCH-PURPOSE: the documented GitHub-style anchor contract is not yet fulfilled.
- **BR-2** [Critical] `fence-containment` Anchor lookup treats shorter or different fence delimiters as closers
  lua/parley/markdown_heading.lua:28 uses document.lexical.code_block_memo, whose boolean toggle ignores opener character and length. For lines {"````md", "```", "# Fake", "````", "# Real"}, anchor_row returns row 3 for "fake" and nil for "real": it exposes a code example and hides the actual heading. All affected delimiter classes are shorter backtick closers, shorter tilde closers, and mixed backtick/tilde delimiters; the new anchor lookup consumes the shared memo for all of them. Correct the shared fence-state implementation, retaining the existing partition policy, and add regressions for false headings inside and real headings after each case. ARCH-DRY: repair the shared implementation rather than adding an anchor-only fence parser.
- **BR-3** [Critical] `navigation-item-boundaries` A dedented fenced block lets a bullet absorb an outside paragraph
  lua/parley/entity_range.lua:419-428 skips boundary detection on a fence opener because that row is already marked in_code. For {"- Chosen prose", "", "```md", "sample", "```", "[outside](outside.md)"}, navigation_range at row 1 returns rows 1-6, and reference_candidates.collect returns the outside link as its sole candidate. Alt+O therefore opens a reference outside the selected item. The same probe reproduces with tilde fences; the shared branch affects all three accepted bullet markers (-, +, *). Detect a dedented block boundary before skipping fenced contents, while retaining genuinely indented fences inside items. Add range and mapped navigation regressions for both fence styles. ARCH-PURPOSE: item navigation must remain confined to its enclosing item.

## Round 2 — 2026-10-21T16:34:58-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The original examples now pass, and loading the pre-repair heading module makes five current tests fail. However, rendered-content normalization remains incomplete at lua/parley/markdown_heading.lua:104-106,149-151: anchor_row({"# <em title=\"> more\">Target</em>"}, "target") returns nil and accepts "moretarget"; "# &#84;arget" accepts "84arget" instead of "target". Their normalized duplicate suffixes also fail. Complete the rendered-text rule across quoted HTML attributes and character references, preserving code/escaped-text controls, and add regression cases. ARCH-PURPOSE.
- BR-2 — addressed — The shared memo retains opener character/width and accepts only sufficient-length matching closers with whitespace-only suffixes. Current lexical tests pass 10/10; loading the pre-repair lexical module makes six tests fail, including shorter, mixed-character and invalid-suffix delimiters. Anchor-consumer and partition tests pass.
- BR-3 — addressed — Opening-fence boundary detection now precedes fenced-content exclusion. Current range tests pass 84/84; loading the pre-repair range module fails all six bullet-marker/fence-style regressions. Native Normal/Insert mapping tests cover both fence styles, and indented-fence controls retain the inside link.

### Raised

- **BR-4** [Critical] `navigation-item-boundaries` (kind: defect) Bullet navigation still absorbs links after outside Markdown blocks
  lua/parley/entity_range.lua:425-430 uses the editing dialect's column-zero, level-1–3 heading predicate and otherwise requires a preceding blank. For {"- Chosen prose", "#### Outside", "[outside](outside.md)"}, navigation_range returns bullet rows 1–3 and reference_candidates.collect returns outside.md as its sole candidate. Empty ATX headings, one-space-indented outside headings, thematic breaks and block quotes also reproduce containment failures. A sweep of three bullet markers, six heading levels, zero/one-space indentation and empty/nonempty headings fails 63/72 cases. This is the 2nd finding in family `navigation-item-boundaries`. Earlier rounds fixed instances. Do NOT fix this instance alone: state and enforce the rule that an outside block opener ends the item, enumerate the supported block classes and indentation ownership, and sweep them with range and mapped negative tests. Reuse navigation block classification without changing editing textobjects. ARCH-PURPOSE, ARCH-DRY.

## Round 3 — 2026-10-21T20:03:27-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — not-addressed — The HTML/entity dispute is supported: the revised Spec excludes those forms, and the current heading tests pass 15/15; loading the pre-correction module makes the unsupported-HTML regression fail. However, supported Markdown normalization remains incorrect at lua/parley/markdown_heading.lua:49-137. Headings "# _one _two_ three_", "# _Target __more___", "# ` a ` b", and "# [Target](file.md \"(title\")" fail their rendered-text anchors and duplicate suffixes: all eight checks fail. Retain BR-1 for these in-scope cases; ARCH-PURPOSE.
- BR-4 — addressed — Shared markdown_blocks metadata now supplies block classes and content indentation to navigation_range. The 72-case heading boundary sweep passes at HEAD; loading the pre-fix range module in memory reproduces 63/72 failures. Current range tests pass 256/256 and native mapping tests pass 48/48, including outside-block negatives.
- BR-2 — addressed — Previously accepted correction remains intact: shared fence state retains opener character and width and requires a matching whitespace-only closer. Current lexical tests pass 10/10, with heading-consumer false-closer regressions also passing.
- BR-3 — addressed — Previously accepted correction remains intact through the shared fence-opener metadata. Range and native mapping regressions retain dedented-fence exclusion and indented-fence ownership.

## Disputes

Findings the implementer declined (`sdlc finding dispute`), each answered by the
next review round.

- **BR-1** — after round 2 (2026-10-22T00:05:26Z, Xian Xu on Xian’s MacBook Pro at parley.nvim:2 (/Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim))
  rationale: The remaining round-2 instances require HTML rendering and character-reference decoding. Hub delivery 8887bf7d-ec9d-40df-8c27-89b898c13b51 explicitly narrows the approved contract to Markdown ATX headings with inline Markdown formatting and excludes HTML/entity decoding; Spec, plan Revisions, README and atlas record that scope. Unsupported headings now define no anchor and use the existing file-top notice.
  evidence: make -k test-spec with temporary MAP_FILE selecting tests/unit/markdown_heading_spec.lua: RED /tmp/parley407-narrow-red.log fails the unsupported-HTML assertion; GREEN /tmp/parley407-narrow-green.log passes 15/15, including quoted HTML, decimal/hex/named entity rejection, protected code literals, normalized Markdown duplicates and bounded malformed-angle scans. Native fallback cases are included for the next mapped run; original Markdown normalization remains tested.

## Open findings

- **BR-1** [Critical] `heading-anchor-normalization` GitHub-style anchors fail for whitespace and formatted headings
