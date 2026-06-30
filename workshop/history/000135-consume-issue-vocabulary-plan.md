# Consume Issue Vocabulary Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make parley's issue creation, status completion, and status cycling derive from `construct/generated/vocabulary/issue.json` instead of hardcoded Lua status lists.

**Architecture:** Add a small pure `IssueVocabulary` module that normalizes decoded `issue.json` into status/category/transition helpers, plus a thin IO loader that resolves the JSON file via runtimepath or the current repo root. Rewire `issues.lua`, `issue_finder.lua`, and the existing issue-buffer completion autocmd to use that single source, satisfying `ARCH-DRY`, `ARCH-PURE`, and `ARCH-PURPOSE`.

**Tech Stack:** Lua, Neovim runtimepath APIs, `vim.json.decode`, plenary-based unit tests, existing `make test-spec` / `make test` targets.

---

## Core Concepts

### Pure Entities

| Name | Lives in | Status |
|------|----------|--------|
| `IssueVocabulary` | `lua/parley/issue_vocabulary.lua` | new |
| `IssueStatusOrdering` | `lua/parley/issue_vocabulary.lua` | new |
| `IssueFrontmatterCompletion` | `lua/parley/issues.lua` | modified |

**IssueVocabulary** - Normalized in-memory representation of `issue.json`: `categories`, all statuses, terminal/active/open sets, lifecycle transitions, and enumerable frontmatter fields.
- **Relationships:** 1:1 with the decoded `construct/generated/vocabulary/issue.json`; many consumers read it through `issues.lua`.
- **DRY rationale:** Deletes the parallel Lua enum (`status_values`) and transition map currently shadowing `issue.cue`. `ARCH-DRY`
- **Future extensions:** If later vocabulary exports more issue frontmatter enums, `enumerable_values(field)` widens without UI consumers learning the raw JSON shape.

**IssueStatusOrdering** - Status sort/cycle semantics derived from vocabulary categories and lifecycle transitions.
- **Relationships:** 1:N from category groups to statuses; 1:N from each status to legal lifecycle successors.
- **DRY rationale:** Keeps picker sorting, active filtering, and status cycling on the same vocabulary table rather than embedding status priority in each UI path. `ARCH-PURPOSE`
- **Future extensions:** If the vocabulary adds an explicit UI order, only this pure helper changes.

**IssueFrontmatterCompletion** - Existing completion behavior in `issues.lua`, changed to ask the vocabulary for possible values.
- **Relationships:** Many buffers use the same helper; completion remains independent of Neovim UI mechanics.
- **DRY rationale:** Both omnifunc and insert-mode typeahead consume one completion helper.

### Integration Points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `IssueVocabularyLoader` | `lua/parley/issue_vocabulary.lua` | new | `vim.api.nvim_get_runtime_file`, `vim.fn.getcwd`, file IO, `vim.json.decode` |
| `IssueCreateTemplate` | `lua/parley/issues.lua` | modified | issue file creation |
| `IssueBufferTypeahead` | `lua/parley/init.lua` | modified | insert-mode `complete()` |
| `IssueFinderStatusActions` | `lua/parley/issue_finder.lua` | modified | picker filtering and status edits |
| `IssueAtlas` | `atlas/issues/issue-management.md`, `atlas/traceability.yaml` | modified | developer docs |

**IssueVocabularyLoader** - Resolves and decodes `construct/generated/vocabulary/issue.json` once, with deterministic fallback behavior for missing/corrupt files.
- **Injected into:** `IssueVocabulary` via `load(opts)` accepting an override path/table in tests; consumers use the module-level default.
- **Future extensions:** Support generated vocabulary from a sibling layer path if runtimepath layout changes.

**IssueCreateTemplate** - Continues to create new issues with the default open status, but obtains that default from the vocabulary's `categories.open[1]`.
- **Injected into:** `create_issue`.
- **Future extensions:** Additional vocabulary-derived default frontmatter fields.

**IssueBufferTypeahead** - Keeps current UX and uses existing `helper.complete_noselect` where possible, but receives candidates from `issues.complete_frontmatter_values`.
- **Injected into:** the existing issue-file `TextChangedI` autocmd.
- **Future extensions:** Complete other enumerable issue frontmatter fields without extra UI branches.

**IssueFinderStatusActions** - Uses vocabulary active/terminal sets for view filtering and lifecycle-derived cycle successors for `<C-s>`.
- **Injected into:** `issue_finder.open`.
- **Future extensions:** Display transition events or guard labels if the picker needs them.

## Chunk 1: Vocabulary Loader And Pure Helpers

**Files:**
- Create: `lua/parley/issue_vocabulary.lua`
- Test: `tests/unit/issue_vocabulary_spec.lua`

- [x] **Step 1: Write failing tests for normalization**

Add tests that build a fake decoded vocabulary table:

```lua
local vocab = require("parley.issue_vocabulary")

it("derives status values from categories", function()
    local model = vocab.from_table({
        categories = {
            open = { "open" },
            active = { "working", "blocked" },
            terminal = { "done", "wontfix", "punt" },
        },
        lifecycle = {
            { from = "open", to = "working", event = "claim", guards = {} },
            { from = "working", to = "blocked", event = "block", guards = {} },
        },
    })

    assert.are.same({ "open", "working", "blocked", "done", "wontfix", "punt" }, model:status_values())
    assert.is_true(model:is_active("working"))
    assert.is_true(model:is_terminal("punt"))
end)
```

- [x] **Step 2: Run the new spec and verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_vocabulary_spec.lua" -c "qa!"`

Expected: FAIL because `parley.issue_vocabulary` does not exist.

- [x] **Step 3: Implement `issue_vocabulary.lua`**

Implement:

```lua
local M = {}

function M.from_table(raw)
    -- validate table shape enough to fail closed, then return methods:
    -- status_values(), category(name), is_active(status), is_terminal(status),
    -- next_status(current), sort_rank(status), enumerable_values(field)
end

function M.load(opts)
    -- opts.path or runtimepath/repo-root resolution, then vim.json.decode
end

function M.default()
    -- cached load with reset_for_tests()
end

return M
```

Resolution order:
1. `opts.path`, for tests.
2. First runtimepath hit for `construct/generated/vocabulary/issue.json`.
3. Current repo root fallback: `<git-root-or-cwd>/construct/generated/vocabulary/issue.json`.

- [x] **Step 4: Run vocabulary unit tests**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_vocabulary_spec.lua" -c "qa!"`

Expected: PASS.

## Chunk 2: Rewire Issue Logic

**Files:**
- Modify: `lua/parley/issues.lua`
- Modify: `lua/parley/issue_finder.lua`
- Modify: `lua/parley/init.lua`
- Test: `tests/unit/issues_spec.lua`

- [x] **Step 1: Write failing issue tests for vocabulary-driven behavior**

Add tests in `tests/unit/issues_spec.lua` that:
- assert `issues.status_values()` matches `issue_vocabulary.default():status_values()`;
- assert `issues.cycle_status_value("open")` follows the lifecycle edge to `working`;
- assert `issues.complete_frontmatter_values("status", "wo")` returns `{ "working", "wontfix" }` based on the model;
- assert a temporary fake vocabulary containing an extra status appears in completion without editing `issues.lua`.

- [x] **Step 2: Run issue tests and verify failure**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issues_spec.lua" -c "qa!"`

Expected: FAIL because `issues.status_values()` / fake-vocabulary injection do not exist yet or still use the hardcoded table.

- [x] **Step 3: Replace hardcoded issue status helpers**

In `lua/parley/issues.lua`:
- require `parley.issue_vocabulary`;
- delete `M.status_values = { ... }`;
- replace the literal `next_status` map in `cycle_status_value` with `issue_vocabulary.default():next_status(current)`;
- replace `status_priority` with `issue_vocabulary.default():sort_rank(status)`;
- add pure helpers `M.status_values()`, `M.is_active_status(status)`, `M.is_terminal_status(status)`, and `M.complete_frontmatter_values(field, partial)`;
- keep `next_runnable` intentionally tied to `open`/`done` semantics unless vocabulary later models runnable-ness explicitly.

- [x] **Step 4: Rewire UI consumers**

In `lua/parley/issue_finder.lua`:
- replace `issue.status ~= "done" ...` active filtering with `issues_mod.is_active_status(issue.status)` or status is in `categories.open`;
- keep archived files excluded from active view.

In `lua/parley/init.lua`:
- replace the inline loop over `issues_mod.status_values` with `issues_mod.complete_frontmatter_values("status", partial)`;
- use `require("parley.helper").complete_noselect(col + 1, matches)` instead of open-coded `completeopt` handling if it matches the existing behavior.

In `lua/parley/issues.lua` omnifunc:
- return `M.complete_frontmatter_values("status", base)`.

- [x] **Step 5: Run targeted issue tests**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issues_spec.lua" -c "qa!"`

Expected: PASS.

## Chunk 3: Conformance, Docs, And Verification

**Files:**
- Modify: `tests/unit/issues_spec.lua` or `tests/unit/issue_vocabulary_spec.lua`
- Modify: `atlas/issues/issue-management.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000135-consume-issue-vocabulary.md`

- [x] **Step 1: Add fail-closed conformance test**

Add a test that decodes the repo's real `construct/generated/vocabulary/issue.json` and checks every status in every category is:
- present in `issues.status_values()`;
- offered by `issues.complete_frontmatter_values("status", "")`;
- assigned a stable sort rank;
- either has a lifecycle successor or is terminal.

- [x] **Step 2: Update atlas**

In `atlas/issues/issue-management.md`, replace the stale hardcoded lifecycle sentence with a note that statuses and transitions derive from `construct/generated/vocabulary/issue.json`.

In `atlas/traceability.yaml`, add `lua/parley/issue_vocabulary.lua` and `tests/unit/issue_vocabulary_spec.lua` under `issues/issue-management`.

- [x] **Step 3: Run targeted verification**

Run:

```bash
make test-spec SPEC=issues/issue-management
make lint
```

Expected: all pass. If `luacheck` is unavailable, record the exact failure and run the two test specs as the minimum proof.

- [x] **Step 4: Final shadow sweep**

Run:

```bash
rg -n "status_values|open.*working.*blocked|wontfix.*punt|status_priority|cycle_status_value|done.*wontfix" lua/parley tests/unit atlas
```

Expected: no remaining hardcoded status-domain shadow except tests that construct fake vocabulary data or docs describing example statuses.

- [x] **Step 5: Update issue checklist and log**

Check off completed plan items in `workshop/issues/000135-consume-issue-vocabulary.md` and add verification evidence to `## Log`.
