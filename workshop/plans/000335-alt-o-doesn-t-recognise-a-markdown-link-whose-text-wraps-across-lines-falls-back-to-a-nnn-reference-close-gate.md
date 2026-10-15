---
gate: boundary-review
issue: 335
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d305fbd0-fcdc-4a05-aa8c-8dba2fbe7efb
            repository: github.com/xianxu/parley.nvim
            issue_id: "000335"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/098c5794f9b9f3e5
            reviewed_head: 04c87f5c37be8c0a09e86edb7da518c51cb04f59
            slot: parley.nvim:1
            requested_at: "2026-10-15T22:26:40.01448Z"
          phase: finished
          pid: 70526
          started_at: "2026-10-15T22:26:40.410096Z"
          finished_at: "2026-10-15T22:28:33.39378Z"
          session_id: 01a141ac-b892-7293-94b5-dded29ca0c3e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 04c87f5c37be8c0a09e86edb7da518c51cb04f59
        tracker_head: da9dac92866eb2e12f4b0e6e9f8d2a1470cdc793
        branch_point: 83f3893a133af1d8f96a677ecc0fa6b5e2c514c0
        since: "2026-10-15T14:41:15-07:00"
        until: "2026-10-15T15:26:00-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T14:41:15-07:00"
              end: "2026-10-15T15:26:00-07:00"
              began: "2026-10-15T14:41:15-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: ff3d1a74934e8dbd30ff4d218b58364919bb7254e39e798cd1e8c19a46b4af5e
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 11995245
              windows:
                - start: "2026-10-15T14:41:15-07:00"
                  end: "2026-10-15T15:26:00-07:00"
            - harness: codex
              id: 01a14183-71cd-7f63-8f66-cd1fe2633763
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6a4848abe1f328f79916ea370d69c8b7a5b0524c934ef25811578aca2c088828
              started: "2026-10-15T21:41:35.947Z"
              spawned: true
              bytes: 529137
              windows:
                - start: "2026-10-15T21:41:35.947Z"
                  end: "2026-10-15T15:26:00-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.029516666666666667
      "n": 1
      timestamp: "2026-10-15T15:28:34-07:00"
      dispatched: "2026-10-15T15:26:40-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Direct wrapped links can open an @@ reference embedded in their label
          detail: lua/parley/init.lua:5067 sends a recognized Markdown span through the generic reference opener. When its destination is unsupported, that opener proceeds to @@ parsing instead of falling back at the Markdown destination. A headless probe with "[long @@<absolute README.md path>@@\nlabel](https://example.invalid/path)" opened README.md from a cursor on line 2; destination fallback was never called. The affected family in this window is direct wrapped Markdown navigation; selected Markdown navigation at lines 5087–5089 already avoids this reinterpretation. Share a Markdown-only dispatch helper between these paths (ARCH-DRY), then fall back at the retained destination coordinates. Add direct-navigation regressions with existing and missing nested @@ targets.
          family: preserve-recognized-reference-identity
          round: 1
        - kind: defect
          id: BR-2
          severity: Critical
          title: The direct multiline scan ignores chat entity boundaries and plain Markdown fence context
          detail: "lua/parley/init.lua:5062 scans the entire buffer before obtaining entity context, while lua/parley/reference_candidates.lua:23 builds a partition-resetting fence memo unconditionally. Headless probes confirmed that \"[unfinished\" in a user turn joined \"\U0001F916: label](<absolute README.md path>)\" in the next turn and opened README.md; a plain Markdown fenced example containing \"\U0001F916: [long\" followed by \"label](<absolute README.md path>)\" also opened it. Family enumeration: markdown_spans lacks barriers for all eight structural prefixes—user, assistant, summary, reasoning, tool-use, tool-result, branch and local—and its default fence memo resets on user/assistant/branch/local prefixes even in plain Markdown. Both the direct scanner and collect's shared scanner must receive appropriate document context; collect's supplied memo already preserves the navigation caller's fence policy. Reuse the existing entity boundaries and transcript-aware fence policy, and add regressions covering boundary crossings and fenced chat-like examples. This violates the paragraph-scoped purpose (ARCH-PURPOSE)."
          family: preserve-document-scan-boundaries
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 79884504-d136-4b45-b704-8dd120367d15
            repository: github.com/xianxu/parley.nvim
            issue_id: "000335"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/84c1a2ac5fd10371
            reviewed_head: dcdb95cf023e8c1b2e0b465381608d91fbd07fdf
            slot: parley.nvim:1
            requested_at: "2026-10-15T22:43:43.277005Z"
          phase: finished
          pid: 98665
          started_at: "2026-10-15T22:43:43.399979Z"
          finished_at: "2026-10-15T22:45:25.153837Z"
          session_id: 01a141bc-54ea-77d0-9ff5-44e48912a835
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: dcdb95cf023e8c1b2e0b465381608d91fbd07fdf
        tracker_head: e46cdb07f99e8142e1f03f9a1f5e63424cb95911
        branch_point: 83f3893a133af1d8f96a677ecc0fa6b5e2c514c0
        since: "2026-10-15T14:41:15-07:00"
        until: "2026-10-15T15:43:23-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T14:41:15-07:00"
              end: "2026-10-15T15:43:23-07:00"
              began: "2026-10-15T14:41:15-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: c4a08ee04b8f5d9e1277450d0ef6606a7000cbfdd1715003c79d36d8c607e99d
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 12669586
              windows:
                - start: "2026-10-15T14:41:15-07:00"
                  end: "2026-10-15T15:43:23-07:00"
            - harness: codex
              id: 01a14183-71cd-7f63-8f66-cd1fe2633763
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 6a4848abe1f328f79916ea370d69c8b7a5b0524c934ef25811578aca2c088828
              started: "2026-10-15T21:41:35.947Z"
              spawned: true
              bytes: 529137
              windows:
                - start: "2026-10-15T21:41:35.947Z"
                  end: "2026-10-15T15:43:23-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.029516666666666667
        cuts:
            - dispatched: "2026-10-15T15:26:40-07:00"
              finalized: "2026-10-15T15:28:34-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T15:45:25-07:00"
      dispatched: "2026-10-15T15:43:43-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Direct and selected wrapped links share open_markdown_reference. The existing/missing nested-@@ regression passes at head and fails with the pre-fix production files.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Both consumers receive document context and the navigation fence memo. The transcript-marker and plain-Markdown-fence regressions pass at head; removing the correction produces one unit and two integration failures.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Critical
          title: Wrapped links still cross Markdown block boundaries
          detail: 'lua/parley/reference_candidates.lua:29–35 omits thematic breaks, Setext heading underlines, and blockquote transitions from its paragraph barriers. Headless probes using {"[unfinished", boundary, "label](<absolute README.md path>)"} with each boundary "---", "***", "___", "===", and "> quoted" produced one Markdown candidate and opened README.md through OpenFileUnderCursor from row 3. The affected sites are the shared boundary predicate, direct scanning at lua/parley/init.lua:5071, and collect''s shared scan at lua/parley/reference_candidates.lua:100. This is the 2nd finding in family preserve-document-scan-boundaries. Earlier rounds fixed instances. Do NOT fix only these spellings: state the paragraph/block-containment rule, enumerate its boundary classes, and enforce it for both consumers with failing regressions (ARCH-PURPOSE).'
          family: preserve-document-scan-boundaries
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#335 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T15:28:34-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `preserve-recognized-reference-identity` (kind: defect) Direct wrapped links can open an @@ reference embedded in their label
  lua/parley/init.lua:5067 sends a recognized Markdown span through the generic reference opener. When its destination is unsupported, that opener proceeds to @@ parsing instead of falling back at the Markdown destination. A headless probe with "[long @@<absolute README.md path>@@\nlabel](https://example.invalid/path)" opened README.md from a cursor on line 2; destination fallback was never called. The affected family in this window is direct wrapped Markdown navigation; selected Markdown navigation at lines 5087–5089 already avoids this reinterpretation. Share a Markdown-only dispatch helper between these paths (ARCH-DRY), then fall back at the retained destination coordinates. Add direct-navigation regressions with existing and missing nested @@ targets.
- **BR-2** [Critical] `preserve-document-scan-boundaries` (kind: defect) The direct multiline scan ignores chat entity boundaries and plain Markdown fence context
  lua/parley/init.lua:5062 scans the entire buffer before obtaining entity context, while lua/parley/reference_candidates.lua:23 builds a partition-resetting fence memo unconditionally. Headless probes confirmed that "[unfinished" in a user turn joined "🤖: label](<absolute README.md path>)" in the next turn and opened README.md; a plain Markdown fenced example containing "🤖: [long" followed by "label](<absolute README.md path>)" also opened it. Family enumeration: markdown_spans lacks barriers for all eight structural prefixes—user, assistant, summary, reasoning, tool-use, tool-result, branch and local—and its default fence memo resets on user/assistant/branch/local prefixes even in plain Markdown. Both the direct scanner and collect's shared scanner must receive appropriate document context; collect's supplied memo already preserves the navigation caller's fence policy. Reuse the existing entity boundaries and transcript-aware fence policy, and add regressions covering boundary crossings and fenced chat-like examples. This violates the paragraph-scoped purpose (ARCH-PURPOSE).

## Round 2 — 2026-10-15T15:45:25-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Direct and selected wrapped links share open_markdown_reference. The existing/missing nested-@@ regression passes at head and fails with the pre-fix production files.
- BR-2 — addressed — Both consumers receive document context and the navigation fence memo. The transcript-marker and plain-Markdown-fence regressions pass at head; removing the correction produces one unit and two integration failures.

### Raised

- **BR-3** [Critical] `preserve-document-scan-boundaries` (kind: defect) Wrapped links still cross Markdown block boundaries
  lua/parley/reference_candidates.lua:29–35 omits thematic breaks, Setext heading underlines, and blockquote transitions from its paragraph barriers. Headless probes using {"[unfinished", boundary, "label](<absolute README.md path>)"} with each boundary "---", "***", "___", "===", and "> quoted" produced one Markdown candidate and opened README.md through OpenFileUnderCursor from row 3. The affected sites are the shared boundary predicate, direct scanning at lua/parley/init.lua:5071, and collect's shared scan at lua/parley/reference_candidates.lua:100. This is the 2nd finding in family preserve-document-scan-boundaries. Earlier rounds fixed instances. Do NOT fix only these spellings: state the paragraph/block-containment rule, enumerate its boundary classes, and enforce it for both consumers with failing regressions (ARCH-PURPOSE).

## Open findings

- **BR-3** [Critical] `preserve-document-scan-boundaries` (kind: defect) Wrapped links still cross Markdown block boundaries
