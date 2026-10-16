---
id: 000342
status: open
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
github_issue:
---

# A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache

## Problem

A test or review run outside the `make` harness wrote real user state. This is the same class as #338: tests reaching state the operator owns.

Evidence (2026-10-15):
- The operator's real cache `~/.local/share/nvim/parley/cliproxy/catalog.json` (mode 0600) has mtime 19:26:08. Its content is exactly `fake_cliproxy`'s 7-model list: claude-opus-5, claude-opus-4-8, claude-sonnet-4-6, gpt-5-codex, gpt-5.6-sol, gemini-pro-agent and gpt-oss-120b-medium (`tests/fixtures/fake_cliproxy:238-244`). On 2026-09-10 the same file held the real 41-model catalog that #230 measured, so that measurement can no longer be reproduced from it.
- The parley.nvim:3 full suite (`make -k test`, harness HOME and XDG isolated) finished at 19:24:30. 19:26 falls inside the #341 close review's window. That review runs specs in its own checkout, so a spec invoked outside the harness, with the real HOME, is the likely writer. The exact writer is not pinned.
- Every spec that fetches the catalog either redirects the cliproxy data dir (`_set_data_dir`) or uses in-memory data. Under the harness none can reach the real path, so the hole is "run without isolation", not one spec.

Impact today is low: the file is a cache refetched when stale. The class is not low: the same route reaches credentials, chats and state under the real XDG roots.
