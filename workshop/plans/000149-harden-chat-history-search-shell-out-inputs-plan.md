# Harden Chat History Search Shell-Out Inputs Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the remaining shell-string execution path from `chat_history_search` while preserving its chat-root search behavior.

**Architecture:** Keep chat-root discovery and path rewriting in `chat_history_search.lua`, but move command construction to argv lists and reuse `parley.tools.builtin.argv.nonnegative_int` for numeric validation (`ARCH-DRY`, `ARCH-PURE`). The only process boundary remains `vim.fn.system(argv)` inside `search_root`; all LLM-controlled numeric inputs are validated before process launch (`ARCH-PURPOSE`).

**Tech Stack:** Lua, Neovim `vim.fn.system({ ... })`, Plenary/Busted tests, ripgrep/system grep.

---

## Core Concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `ChatHistorySearchArgs` | `lua/parley/tools/builtin/chat_history_search.lua` | modified |
| `NonnegativeIntegerInput` | `lua/parley/tools/builtin/argv.lua` | existing |

**ChatHistorySearchArgs** — validated argv arguments for the selected `rg`/`grep` backend.
- **Relationships:** Built once per root search from one tool input and one chat root.
- **DRY rationale:** Reuses the #144 argv helper instead of adding another numeric validator.
- **Future extensions:** If `chat_history_search` later gains more structured fields, they should be validated here before command construction.

**NonnegativeIntegerInput** — existing pure helper that accepts only Lua numbers that are non-negative integers.
- **Relationships:** Shared by `grep` and `chat_history_search`.
- **DRY rationale:** Keeps numeric process-flag validation under one helper.
- **Future extensions:** Error wording can be made more field-specific at call sites without widening the helper.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ChatHistoryProcessSearch` | `lua/parley/tools/builtin/chat_history_search.lua` | modified | `rg` / `grep` subprocess |
| `ChatHistoryRoots` | `lua/parley/tools/builtin/chat_history_search.lua` | existing | `parley.get_chat_roots()` |

**ChatHistoryProcessSearch** — executes the selected grep backend with argv-list execution.
- **Injected into:** No explicit injection in this issue; keep the IO call narrow and regression-test through the handler.
- **Future extensions:** A process fake can be introduced if backend-specific behavior grows beyond current fixture tests.

**ChatHistoryRoots** — reads configured chat roots, intentionally bypassing cwd confinement because this tool searches saved chat memory outside the current repo.
- **Injected into:** Handler obtains roots from `parley.get_chat_roots()`.
- **Future extensions:** Root filtering can stay separate from command argv construction.

## Task 1: Numeric Input Rejection Tests

**Files:**
- Modify: `tests/unit/tools_builtin_chat_history_search_spec.lua`

- [ ] **Step 1: Add failing tests for injection-shaped numeric fields**

Add table-driven tests that call:

```lua
handler({ pattern = "aws", before = "0; echo PARLEY_SENTINEL_149" })
handler({ pattern = "aws", after = "$(echo PARLEY_SENTINEL_149)" })
handler({ pattern = "aws", max_count = "1 | echo PARLEY_SENTINEL_149" })
```

Each result must be `is_error = true`, mention the offending field, and not include `PARLEY_SENTINEL_149`.

- [ ] **Step 2: Add boundary validation tests**

Reject floats and negatives for `before`, `after`, and `max_count`, and preserve valid zero context:

```lua
handler({ pattern = "aws", before = 0, after = 0, max_count = 1 })
```

- [ ] **Step 3: Run the focused spec and confirm RED**

Run:

```bash
nvim --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/tools_builtin_chat_history_search_spec.lua" -c "qa!"
```

Expected: new rejection tests fail because current code accepts string numeric fields into shell command construction.

## Task 2: Argv Execution

**Files:**
- Modify: `lua/parley/tools/builtin/chat_history_search.lua`
- Test: `tests/unit/tools_builtin_chat_history_search_spec.lua`

- [ ] **Step 1: Require the argv helper**

Add:

```lua
local argv = require("parley.tools.builtin.argv")
```

- [ ] **Step 2: Replace shell command construction**

Delete `shell_quote`. Change `build_cmd(input, root_dir)` to return argv tables:

```lua
local cmd = { "rg", "--line-number", "--with-filename", "--no-heading", "-B", tostring(before), "-A", tostring(after), "--glob", glob }
```

For grep fallback, use `{ "grep", "-rn", "-B", tostring(before), "-A", tostring(after), "--include=" .. glob }`, then `-i`, `-m`, `-E`, `--`, `pattern`, `root_dir`.

- [ ] **Step 3: Validate numeric fields before building argv**

Use `argv.nonnegative_int` for `before`, `after`, and `max_count`. Preserve defaults:

```lua
local before = input.before == nil and 1 or argv.nonnegative_int(input.before, "before")
```

If a provided field fails validation, return an error from the handler before searching any roots.

- [ ] **Step 4: Run the focused spec and confirm GREEN**

Run the same Plenary command from Task 1. Expected: all chat-history tests pass.

## Task 3: Docs And Full Verification

**Files:**
- Modify: `atlas/providers/tool_use.md`
- Modify: `atlas/traceability.yaml` if the changed test file is not already represented.
- Modify: `workshop/issues/000149-harden-chat-history-search-shell-out-inputs.md`

- [ ] **Step 1: Update atlas docs**

Document that `chat_history_search` intentionally searches configured chat roots outside cwd, but now executes `rg`/`grep` via argv-list execution with validated numeric context/count fields.

- [ ] **Step 2: Tick issue plan and append log evidence**

After code and docs pass, tick the four issue plan rows and add the verification commands to `## Log`.

- [ ] **Step 3: Run verification**

Run:

```bash
make test-spec SPEC=providers/tool_use
make test
make lint
```

Expected: all pass.
