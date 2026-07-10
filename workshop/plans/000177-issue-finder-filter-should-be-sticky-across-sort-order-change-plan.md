# Sticky Issue Finder Query Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the complete Issue Finder prompt query across view repaints and later invocations.

**Architecture:** Keep the query on the existing `_parley._issue_finder` state object. `issue_finder.open` passes that raw value directly to `float_picker.initial_query` and replaces it from `on_query_change`; no query parsing or formatting is added, so `float_picker` remains the filtering owner and other finders keep their structured-only policy.

**Tech Stack:** Lua, Neovim, Plenary/Busted, existing `float_picker` and Issue Finder state.

---

## Core concepts

### Pure entities

No pure entity changes. The feature preserves an opaque user-input string without transforming it; introducing a query abstraction would add behavior the issue does not need.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `IssueFinderQueryState` | `lua/parley/init.lua`, `lua/parley/issue_finder.lua` | modified | `float_picker` prompt input and `_parley._issue_finder` session state |

- **IssueFinderQueryState** — captures every prompt value and supplies the last value verbatim to each Issue Finder invocation.
  - **Injected into:** `float_picker.open` through its existing `initial_query` and `on_query_change` options; no new dependency is introduced.
  - **Future extensions:** None planned. Full-query persistence remains Issue Finder-specific because shared `finder_sticky` intentionally implements a different structured-filter policy (`ARCH-DRY`, `ARCH-PURPOSE`).

## Chunk 1: Persist and verify the complete query

### Task 1: Pin the Issue Finder query-state contract

**Files:**
- Modify: `tests/unit/issue_finder_spec.lua`

- [x] **Step 1: Add an isolated real-`open` test harness**

  In a new `describe`, require `parley.issues` as `issues`, save/restore `vim.defer_fn`, and call `issue_finder.setup(fake_parley)` in each `before_each`. Give the fake a fresh `_issue_finder` table, one scanned issue, the current valid source window, an ordered `picker_calls` list, and a `deferred` queue:

  ```lua
  local picker_calls = {}
  local deferred = {}
  local fake = {
      _issue_finder = { opened = false, view_mode = 0 },
      config = {
          issues_dir = "/unused/issues",
          history_dir = "/unused/history",
          issue_finder_mappings = {},
      },
      float_picker = {
          open = function(opts) table.insert(picker_calls, opts) end,
      },
      helpers = {},
      logger = { warning = function() end },
      cmd = {},
      open_buf = function() end,
  }

  local original_scan = issues.scan_issues
  issues.scan_issues = function(_, opts)
      return opts.include_history
          and { { id = "000002", status = "done", title = "Archived", slug = "archived", path = "/tmp/archived.md", archived = true, mtime = 2 } }
          or { { id = "000001", status = "open", title = "Active", slug = "active", path = "/tmp/active.md", archived = false } }
  end
  vim.defer_fn = function(fn) table.insert(deferred, fn) end
  fake.cmd.IssueFinder = function() issue_finder.open() end
  ```

  Restore `issues.scan_issues` and `vim.defer_fn` in `after_each`. This runs the real Issue Finder orchestration while faking only scanning, picker IO, and time.

- [x] **Step 2: Write the raw-query and cancel/reinvoke failing test**

  Open once, feed the exact mixed query through the first picker call, cancel, then open again through the real entry point:

  ```lua
  issue_finder.open()
  picker_calls[1].on_query_change("  sticky {repo} query  ")
  picker_calls[1].on_cancel()
  issue_finder.open()
  assert.equals("  sticky {repo} query  ", picker_calls[2].initial_query)
  ```

  Assert the saved raw query remains on `fake._issue_finder.query`. Expected RED: the current structured extractor stores only `{repo}` and the formatter appends a space.

- [x] **Step 3: Run the focused spec and verify the raw-query case is RED**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: FAIL in `preserves the raw query after cancel and later invocation`, with actual `{repo} ` instead of the exact mixed string.

- [x] **Step 4: Write the clearing and selection/reinvoke failing cases**

  In separate tests with fresh state, feed `"needle"`, call `on_select` with the first item, invoke again, and assert the second `initial_query == "needle"`. Then feed `""`, cancel, invoke again, and assert the second `initial_query == ""` and state contains the empty string. These cases pin both picker-close paths and prevent an old value from being resurrected.

- [x] **Step 5: Write the controlled view-cycle failing case**

  Feed `"needle {repo}"`, locate the cycle mapping by its configured/default key `<Tab>`, and call its `fn(item, close_fn)` with a close spy. Assert it queued one deferred callback; execute `deferred[1]()` so the real `fake.cmd.IssueFinder → issue_finder.open` path collects `picker_calls[2]`. Assert the close spy ran, the second title contains `history`, its item is the archived fixture, and `picker_calls[2].initial_query == "needle {repo}"`.

- [x] **Step 6: Run the focused spec and verify all new cases are RED for query restoration**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: the new named raw-query, selection, clearing, and view-cycle cases fail on the old structured-only query behavior; all pre-existing cases pass.

### Task 2: Store and restore the raw Issue Finder query

**Files:**
- Modify: `lua/parley/init.lua`
- Modify: `lua/parley/issue_finder.lua`
- Modify: `tests/unit/issue_finder_spec.lua`
- Modify: `atlas/ui/pickers.md`
- Modify: `atlas/modes/super_repo.md`
- Modify: `atlas/issues/issue-management.md`

- [x] **Step 1: Implement the minimal state wiring**

  Rename the initialized Issue Finder state field from structured-only `sticky_query` to opaque `query`, update its comment, and replace Issue Finder's use of `finder_sticky` with direct state:

  ```lua
  initial_query = _parley._issue_finder.query,
  on_query_change = function(query)
      _parley._issue_finder.query = query
  end,
  ```

  Remove the now-unused `finder_sticky` import. Do not trim, parse, append whitespace, or clear the state from selection/cancel/view-cycle handlers (`ARCH-PURE`).

- [x] **Step 2: Run the focused spec and verify GREEN**

  Run: `make test-spec SPEC=issues/issue-management`

  Expected: all issue-management specs pass, including the named raw whitespace, mixed query, clearing, selection/cancel reinvocation, and view-cycle repaint cases. Existing `finder_sticky` specs remain unchanged, proving other finders retain their structured-only policy.

- [x] **Step 3: Run lint and the full suite**

  Run: `make lint`

  Expected: exit 0 with no warnings.

  Run: `make test`

  Expected: exit 0 for lint, unit, integration, and architecture checks.

- [x] **Step 4: Reconcile the documented finder-persistence policy**

  Update `atlas/ui/pickers.md` and `atlas/modes/super_repo.md`, whose current statements say plain text is never preserved and every finder uses `finder_sticky`, to document Issue Finder as the intentional full-query exception. Update `atlas/issues/issue-management.md` to describe the complete query surviving view repaint and later invocation. Search `README.md` and the rest of `atlas/` for additional Issue Finder persistence claims, then run `git diff --check` on #177 paths and inspect `git status --short` so unrelated issue edits remain unstaged (`ARCH-PURPOSE`).

- [x] **Step 5: Commit the implementation**

  Stage only `lua/parley/init.lua`, `lua/parley/issue_finder.lua`, `tests/unit/issue_finder_spec.lua`, `atlas/ui/pickers.md`, `atlas/modes/super_repo.md`, `atlas/issues/issue-management.md`, and the #177 issue/plan. Commit using the repository convention and a `Co-Authored-By:` trailer.
