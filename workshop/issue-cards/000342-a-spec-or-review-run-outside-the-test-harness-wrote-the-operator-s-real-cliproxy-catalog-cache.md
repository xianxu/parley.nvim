---
id: 000342
status: done
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
started: 2026-10-15T20:29:30-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.88
tracker:
    version: 1
    completion:
        token: close-04584b781c98
        repository: github.com/xianxu/parley.nvim
        reviewed_head: d4677890cc2ba8539394c6d4f9c97ded4d3176f3
        evidence_commit: 8fcfc96f784e43949c9d4542ef3b3e883356322d
        landed_commit: 6a418d25a0654b7ac949a1cba332be86438d20d0
---

# A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache

## Problem

A test or review run outside the `make` harness wrote real user state. This is the same class as #338: tests reaching state the operator owns.

Evidence (2026-10-15):
- The operator's real cache `~/.local/share/nvim/parley/cliproxy/catalog.json` (mode 0600) has mtime 19:26:08. Its content is exactly `fake_cliproxy`'s 7-model list: claude-opus-5, claude-opus-4-8, claude-sonnet-4-6, gpt-5-codex, gpt-5.6-sol, gemini-pro-agent and gpt-oss-120b-medium (`tests/fixtures/fake_cliproxy:238-244`). On 2026-09-10 the same file held the real 41-model catalog that #230 measured, so that measurement can no longer be reproduced from it.
- The parley.nvim:3 full suite (`make -k test`, harness HOME and XDG isolated) finished at 19:24:30. 19:26 falls inside the #341 close review's window. That review runs specs in its own checkout, so a spec invoked outside the harness, with the real HOME, is the likely writer. The exact writer is not pinned.
- Every spec that fetches the catalog either redirects the cliproxy data dir (`_set_data_dir`) or uses in-memory data. Under the harness none can reach the real path, so the hole is "run without isolation", not one spec.

Impact today is low: the file is a cache refetched when stale. The class is not low: the same route reaches credentials, chats and state under the real XDG roots.
