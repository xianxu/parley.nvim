# Better Luabar Information In Repo Mode Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Shorten long git branch labels in luabar so SDLC branches render as compact orientation text such as `000149...`.

**Architecture:** Add one pure branch-label formatter in `lua/parley/lualine.lua` and use it only at the luabar display boundary. This keeps full git branch names untouched while satisfying ARCH-PURE and ARCH-DRY with direct unit coverage.

**Tech Stack:** Lua, Neovim plugin runtime, busted/plenary test suite.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `BranchLabelFormatter` | `lua/parley/lualine.lua` | new |

`BranchLabelFormatter` turns a full branch name into the compact luabar label.

- **Relationships:** 1:1 with a raw git branch string; owned by the lualine display layer.
- **DRY rationale:** One formatter prevents future statusline code from re-implementing truncation rules.
- **Future extensions:** If repo-mode grows additional branch display contexts, they should call this helper rather than duplicating string rules.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| Luabar branch component | `lua/parley/lualine.lua` | modified | lualine status text |

The lualine setup should render the compact label while leaving git, issue files, and branch state untouched.

---

## Chunk 1: Compact Branch Label

### Task 1: Add Formatter Test

**Files:**
- Modify: `tests/unit/super_repo_spec.lua`
- Modify: `lua/parley/lualine.lua`

- [x] **Step 1: Write the failing test**

Add assertions that `require("parley.lualine").format_branch_label` returns:

```lua
assert.equal("000149...", lualine.format_branch_label("000149-harden-chat-history-search-shell-out-inputs"))
assert.equal("main", lualine.format_branch_label("main"))
assert.equal("abcdefghij...", lualine.format_branch_label("abcdefghijklmno"))
assert.equal("release...", lualine.format_branch_label("release_candidate"))
assert.equal("", lualine.format_branch_label(nil))
assert.equal("", lualine.format_branch_label(""))
```

- [x] **Step 2: Run test to verify it fails**

Run:

```bash
mkdir -p .test-home .test-xdg/data .test-xdg/state .test-xdg/cache .test-tmp
HOME="$PWD/.test-home" XDG_DATA_HOME="$PWD/.test-xdg/data" XDG_STATE_HOME="$PWD/.test-xdg/state" XDG_CACHE_HOME="$PWD/.test-xdg/cache" TMPDIR="$PWD/.test-tmp" NVIM_TEST_PLENARY="/Users/xianxu/.local/share/nvim/lazy/plenary.nvim" nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/super_repo_spec.lua" -c "qa!"
```

Expected: FAIL because `format_branch_label` and `create_branch_component` do not exist yet.

- [x] **Step 3: Implement the formatter**

In `lua/parley/lualine.lua`, add `M.format_branch_label(branch)`:

- Return `""` for nil or empty input.
- Split at the first space, hyphen, or underscore.
- Cap the selected token at 10 characters.
- Append `...` only when the label is shorter than the original input.

- [x] **Step 4: Wire branch display**

Wrap existing lualine `branch` components in `M.create_branch_component`, composing any existing `fmt` callback and applying `M.format_branch_label` at the display boundary only.

- [x] **Step 5: Verify**

Run the direct Plenary file command from Step 2 again.

Expected: PASS.

- [x] **Step 6: Broader verification**

Run: `make test` and `make lint`.

Expected: PASS. `make test` includes lint in this repo; it passed with 0 warnings / 0 errors and all unit, integration, and arch tests green. `make test-spec SPEC=ui/lualine` also passed after the traceability mapping was updated.
