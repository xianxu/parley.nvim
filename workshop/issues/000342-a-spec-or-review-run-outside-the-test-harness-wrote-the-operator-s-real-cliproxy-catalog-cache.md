---
id: 000342
status: open
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: 'eed1b6f242b542ac57f1409f1fcb17126ddc6d2d' # card fields mirrored from issue-cards; edit via sdlc
---

# A spec or review run outside the test harness wrote the operator's real cliproxy catalog cache

## Problem

A test or review run outside the `make` harness wrote real user state. This is the same class as #338: tests reaching state the operator owns.

Evidence (2026-10-15):
- The operator's real cache `~/.local/share/nvim/parley/cliproxy/catalog.json` (mode 0600) has mtime 19:26:08. Its content is exactly `fake_cliproxy`'s 7-model list: claude-opus-5, claude-opus-4-8, claude-sonnet-4-6, gpt-5-codex, gpt-5.6-sol, gemini-pro-agent and gpt-oss-120b-medium (`tests/fixtures/fake_cliproxy:238-244`). On 2026-09-10 the same file held the real 41-model catalog that #230 measured, so that measurement can no longer be reproduced from it.
- The parley.nvim:3 full suite (`make -k test`, harness HOME and XDG isolated) finished at 19:24:30. 19:26 falls inside the #341 close review's window. That review runs specs in its own checkout, so a spec invoked outside the harness, with the real HOME, is the likely writer. The exact writer is not pinned.
- Every spec that fetches the catalog either redirects the cliproxy data dir (`_set_data_dir`) or uses in-memory data. Under the harness none can reach the real path, so the hole is "run without isolation", not one spec.

Impact today is low: the file is a cache refetched when stale. The class is not low: the same route reaches credentials, chats and state under the real XDG roots.

## Spec

Make the write impossible rather than finding this one writer:
- Specs fail fast when they run outside an isolated HOME and XDG roots. One shared guard, loaded by every spec entry point (the harness's minimal init and any direct `PlenaryBustedFile` / `-l` run), refuses to run when HOME or XDG_DATA_HOME resolves to the operator's real roots. The message says how to run the spec through `make`.
- Defense in depth at the writer: the cliproxy catalog and config writers refuse to write under the real XDG data dir whenever the endpoint is a fake (a loopback `fake_cliproxy` port, or a test marker the harness sets). Decide which signal is reliable, and prefer one that cannot be spoofed by production config.
- Reviewers and agents running a single spec use the harness entry point (`make test-spec`), and the close-review instructions say so.

## Done when

- A spec run directly with the real HOME (no harness) fails before executing any test, naming the reason. The regression launches a child nvim on a spec file with a non-isolated env and asserts the refusal and that no file appears under that env's data dir.
- With the harness, every spec still runs; the full suite passes.
- A catalog fetch against a fake endpoint with a non-isolated data dir refuses to write (unit or integration test), if the writer-side guard is adopted.

## Plan

- [ ]

## Log

### 2026-10-15
