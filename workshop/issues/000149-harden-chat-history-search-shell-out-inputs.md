---
id: 000149
status: done
deps: []
github_issue:
created: 2026-06-26
updated: 2026-06-27
estimate_hours: 1.5
started: 2026-06-27T11:19:29-07:00
actual_hours: 0.13
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

## Estimate

```estimate
model: estimate-logic-v2
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.8
item: atlas-docs design=0.05 impl=0.1
item: milestone-review design=0.0 impl=0.3
design-buffer: 0.30
total: 1.5
```

## Plan

- [x] Add failing tests for numeric field injection/rejection.
- [x] Convert `chat_history_search` command construction to argv-list execution.
- [x] Update atlas/tool-use docs and traceability if new tests are added.
- [x] Run `make test-spec SPEC=providers/tool_use`, `make test`, and `make lint`.

## Log

### 2026-06-26
- Created from #144 close boundary review. That review returned
  `FIX-THEN-SHIP` for #144 with no critical findings in declared scope, but
  identified this adjacent pre-existing shell-string vector as a follow-up.

### 2026-06-27
- 2026-06-27: closed — TDD red/green verified: focused chat_history_search spec failed before the fix and passed after argv conversion. make test-spec SPEC=providers/tool_use, make test, make lint, sdlc issue validate, and git diff --check all passed. Atlas documents #149 argv safety for chat_history_search. Prior Claude boundary-review attempts hung twice with no verdict, so this rerun uses --agent codex.; review verdict: SHIP
- Renumbered from duplicate `000147` to `000149` before starting work. The older
  neighborhood-path issue already owned `000147`, and `sdlc claim --issue 147`
  refused because both files matched.
- `sdlc start-plan --issue 149` delivered `ARCH-DRY`, `ARCH-PURE`, and
  `ARCH-PURPOSE`; the design reuses the #144 argv helper, validates numeric
  fields before the IO boundary, and converts both `rg` and `grep` branches.
- TDD red: the focused chat-history spec failed as expected because
  injection-shaped and non-integer `before`/`after`/`max_count` values were not
  rejected.
- Implemented argv-list execution for `chat_history_search` and numeric
  validation through `argv.nonnegative_int`, preserving chat-root cwd bypass and
  output path rewriting.
- Verification passed: focused Plenary
  `tools_builtin_chat_history_search_spec.lua`, `make test-spec
  SPEC=providers/tool_use`, `make test`, and `make lint`.
