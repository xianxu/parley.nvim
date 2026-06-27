---
id: 000147
status: open
deps: []
github_issue:
created: 2026-06-26
updated: 2026-06-26
estimate_hours:
---

# Harden chat_history_search shell-out inputs

## Problem
The #144 boundary review found a pre-existing sibling injection surface in
`lua/parley/tools/builtin/chat_history_search.lua`.

Unlike the hardened `ls`/`grep`/`find`/`ack` tools, `chat_history_search` still
builds a shell string and runs `vim.fn.system(cmd)`. It quotes `glob`,
`pattern`, and root paths, but interpolates `before`, `after`, and `max_count`
with `tostring()` directly into the shell command. Since JSON schema integer
types are advisory at the LLM boundary, a crafted string such as
`before = "0; <cmd> #"` can become shell syntax.

## Spec
- Keep `chat_history_search`'s cwd-bypass behavior: it intentionally searches
  configured chat roots outside the current repo, so it should not use the
  dispatcher path guard.
- Remove shell-string construction. Build an argv list for `rg`/fallback search
  execution so all user-controlled values are data, not shell syntax.
- Validate `before`, `after`, and `max_count` as non-negative integers before
  process launch. Reject string, float, negative, and empty values.
- Preserve existing output path rewriting, default context/glob behavior, and
  no-match sentinel.
- Reuse the #144 `argv` helper where it fits (`ARCH-DRY`, `ARCH-PURE`).

## Done when

- `chat_history_search` has no `vim.fn.system(<string>)` call path for
  user-controlled inputs.
- Regression tests prove `before`/`after`/`max_count` injection-shaped strings
  are rejected and do not execute.
- Existing `tools_builtin_chat_history_search_spec.lua` behavior still passes.
- `atlas/providers/tool_use.md` documents that `chat_history_search` uses argv
  execution while retaining its explicit chat-root cwd-bypass.

## Plan

- [ ] Add failing tests for numeric field injection/rejection.
- [ ] Convert `chat_history_search` command construction to argv-list execution.
- [ ] Update atlas/tool-use docs and traceability if new tests are added.
- [ ] Run `make test-spec SPEC=providers/tool_use`, `make test`, and `make lint`.

## Log

### 2026-06-26
- Created from #144 close boundary review. That review returned
  `FIX-THEN-SHIP` for #144 with no critical findings in declared scope, but
  identified this adjacent pre-existing shell-string vector as a follow-up.
