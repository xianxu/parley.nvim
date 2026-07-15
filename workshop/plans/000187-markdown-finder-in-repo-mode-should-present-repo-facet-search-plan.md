# Contextual Markdown Finder Facets Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep directory facets in ordinary repo mode while making Markdown Finder use stable repository-only facets and verbatim query persistence in super-repo mode.

**Architecture:** Extend the canonical pure `finder_facets` model with shared labelled-root eligibility, then make `markdown_finder.build_picker_data` a pure contextual policy over scanned entries and two independent state maps. `markdown_finder.open` remains a thin shell that obtains runtime super-repo state, scans files, stores session state, and adapts the policy result to `float_picker`.

**Tech Stack:** Lua, Neovim Lua API, busted/plenary test harness, Parley `float_picker` and `super_repo` runtime APIs.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `finder_facets.eligible_labels` | `lua/parley/finder_facets.lua` | new |
| `markdown_finder.build_picker_data` | `lua/parley/markdown_finder.lua` | new |

- **`finder_facets.eligible_labels`** — validates a labelled facet universe and returns its canonical sorted distinct labels only when the caller declares the contextual facet domain active and at least two complete labels exist.
  - **Relationships:** N input roots produce 0-or-1 eligible label set; Issue Finder and Markdown Finder both consume the same helper.
  - **DRY rationale:** replaces Issue Finder's private `eligible_repo_facets` and prevents Markdown Finder from copying the same complete-label/multi-label rule (`ARCH-DRY`).
  - **Future extensions:** accept a label projection callback, already sufficient for other labelled-root finders without embedding repo vocabulary.
- **`markdown_finder.build_picker_data`** — selects the contextual facet domain, merges only that domain's state, filters scanned entries, and projects picker items/tags without Vim, `_parley`, filesystem, or module-local state.
  - **Relationships:** one active mode chooses exactly one of two state domains; N entries map to N-or-fewer visible picker items plus one projected tag set.
  - **DRY rationale:** composes canonical `finder_facets` operations instead of preserving Markdown's bespoke discover/toggle/filter implementation (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** a new contextual facet domain widens the explicit input/result tables rather than adding hidden module state.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `markdown_finder.open` | `lua/parley/markdown_finder.lua` | modified | Vim filesystem scan, `super_repo.get_state`, session state, `float_picker.open/update` |
| `_markdown_finder` session state | `lua/parley/init.lua` | modified | Neovim-session query and facet ownership |

- **`markdown_finder.open`** — obtains the active runtime mode/member roots, invokes filesystem scanning, applies the pure policy, and wires tag-bar callbacks to immutable state transitions and picker repaint.
  - **Injected into:** passes plain data into `markdown_finder.build_picker_data`; no IO dependency enters the pure function.
  - **Future extensions:** scanning strategy may change independently while preserving the policy contract.
- **`_markdown_finder` session state** — owns `query`, `directory_facet_state`, and `repo_facet_state` for the lifetime of the current Parley/Neovim session.
  - **Injected into:** read/written only by the `open` shell; state maps are values passed to the pure policy.
  - **Future extensions:** disk persistence would be a separate explicit integration and is out of scope.

## Chunk 1: Contextual facet policy and adapter

### Task 1: Canonical shared facet eligibility

**Files:**
- Modify: `lua/parley/finder_facets.lua`
- Modify: `lua/parley/issue_finder.lua`
- Test: `tests/unit/finder_facets_spec.lua`
- Test: `tests/unit/issue_finder_spec.lua`

- [ ] **Step 1: Write failing pure eligibility tests**

Add cases proving inactive context, nil/empty labels, and fewer than two distinct labels return `nil`, while complete duplicated inputs return sorted distinct labels:

```lua
assert.is_nil(finder_facets.eligible_labels(roots, false, labels))
assert.is_nil(finder_facets.eligible_labels({ { repo_name = "alpha" }, {} }, true, labels))
assert.same({ "alpha", "beta" }, finder_facets.eligible_labels(valid_roots, true, labels))
```

- [ ] **Step 2: Run the focused test and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"`

Expected: FAIL because `eligible_labels` does not exist.

- [ ] **Step 3: Implement `finder_facets.eligible_labels` minimally**

Validate every projected label as a non-empty string, use `discover` for sorted/deduplicated output, and require at least two labels. Do not mutate roots or store state.

- [ ] **Step 4: Replace Issue Finder's private eligibility helper**

Delete `eligible_repo_facets`; call the shared helper with `root.repo_name`. Keep existing #186 behavior byte-for-byte and add/retain the integration assertions for incomplete, duplicated, and valid roots.

- [ ] **Step 5: Run focused regressions and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c "qa!"`

Expected: PASS.

- [ ] **Step 6: Commit the shared policy**

```bash
git add lua/parley/finder_facets.lua lua/parley/issue_finder.lua tests/unit/finder_facets_spec.lua tests/unit/issue_finder_spec.lua
git commit -m "finder: #187 share facet eligibility"
```

### Task 2: Pure contextual Markdown policy

**Files:**
- Modify: `lua/parley/markdown_finder.lua`
- Create: `tests/unit/markdown_finder_spec.lua`

- [ ] **Step 1: Write failing policy tests**

Drive `markdown_finder.build_picker_data` with plain Lua tables and assert:

```lua
local result = markdown_finder.build_picker_data({
  mode = "super_repo",
  entries = entries,
  member_roots = roots,
  directory_state = { workshop = false },
  repo_state = { alpha = false },
})
assert.equals("repo", result.facet_domain)
assert.same({ { label = "alpha", enabled = false }, { label = "beta", enabled = true } }, result.tags)
assert.is_false(result.directory_state.workshop)
```

Cover ordinary mode directory-only facets; eligible super-repo repository-only facets; stable empty-member labels; ineligible active expansion returning all rows with no bar; eligible zero-row expansion retaining its bar; new labels default-on; absent labels retain state; and input/state non-mutation.

- [ ] **Step 2: Run the new test and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c "qa!"`

Expected: FAIL because `build_picker_data` is not exported.

- [ ] **Step 3: Implement the pure policy**

Use `finder_facets.eligible_labels`, `discover`, `merge_state`, `filter`, and `project`. Return fresh `{ items, tags, facet_domain, directory_state, repo_state }`; never read `_parley`, Vim, or module-local variables. Directory facets remain row-derived and appear only when at least two distinct directories exist. Super-repo facets come from eligible runtime member roots and never mix directory keys.

- [ ] **Step 4: Run policy and canonical helper suites**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"`

Expected: PASS.

- [ ] **Step 5: Commit the pure policy**

```bash
git add lua/parley/markdown_finder.lua tests/unit/markdown_finder_spec.lua
git commit -m "finder: #187 model contextual markdown facets"
```

### Task 3: Wire runtime state, verbatim query, and picker repaint

**Files:**
- Modify: `lua/parley/markdown_finder.lua`
- Modify: `lua/parley/init.lua`
- Test: `tests/unit/markdown_finder_spec.lua`
- Test: `tests/unit/super_repo_spec.lua`

- [ ] **Step 1: Add failing finder-entry tests with a fake picker**

Set up a fake Parley shell and runtime `super_repo.get_state`. Assert the actual `open` options/callbacks provide:

- ordinary mode directory tags only;
- super-repo mode sorted repo tags only, including a member with no rows;
- verbatim `initial_query` after whitespace-bearing input and exact empty-string clearing;
- facet toggle/ALL/NONE repaint through `picker.update` without calling `on_query_change` or altering `query`;
- separate directory/repo states across close, mode switch, and reopen;
- NONE reopening with zero items and ALL restoring rows;
- invalid labels retaining aggregated rows without a bar;
- eligible zero-row expansion retaining its bar.

The invalid-label case must reach the policy: member scanning accepts every
valid member path independently of label validity and uses a safe display/search
prefix only when the label is a non-empty string. It must not concatenate an
invalid label or discard that member's successfully scanned rows.

- [ ] **Step 2: Run the finder-entry suite and verify RED**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c "qa!"`

Expected: FAIL against the module-local `_tag_state`, structured-only sticky query, and config-cache member lookup.

- [ ] **Step 3: Replace hidden state with `_markdown_finder` session fields**

Initialize in `lua/parley/init.lua`:

```lua
M._markdown_finder = {
  query = nil,
  directory_facet_state = nil,
  repo_facet_state = nil,
}
```

Remove `_tag_state` and Markdown's `finder_sticky` dependency. Store every query callback value verbatim, including `""`, and pass the exact stored value as `initial_query`.

- [ ] **Step 4: Make `open` a thin adapter**

Read active members from `_parley.super_repo.get_state()`; scan those member paths when active, otherwise scan the ordinary repo root. Pass plain inputs to `build_picker_data`, assign returned states to `_parley._markdown_finder`, and use `finder_facets.toggle/set_all` on the active domain before recomputing. Preserve the live picker query by using only `picker.update(items, tags)`.

- [ ] **Step 5: Reconcile scan tests with explicit repo identity**

Keep `_scan_members` coverage for display/search repo prefixes and adjust assertions to the policy's entry facet field if it changes. Confirm scanning stays IO-only and does not decide bar eligibility.

- [ ] **Step 6: Run focused integration suites and verify GREEN**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/super_repo_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c "qa!"`

Expected: PASS.

- [ ] **Step 7: Commit the adapter**

```bash
git add lua/parley/markdown_finder.lua lua/parley/init.lua tests/unit/markdown_finder_spec.lua tests/unit/super_repo_spec.lua
git commit -m "finder: #187 persist contextual markdown facets"
```

### Task 4: Documentation and full verification

**Files:**
- Modify: `atlas/modes/super_repo.md`
- Modify: `atlas/ui/pickers.md`
- Modify: `atlas/issues/issue-management.md`
- Modify: `atlas/traceability.yaml`
- Modify: `workshop/issues/000187-markdown-finder-in-repo-mode-should-present-repo-facet-search.md`

- [ ] **Step 1: Update the atlas at the changed boundaries**

Document the contextual Markdown bar, shared eligibility policy, separate session states, verbatim complete-query behavior, and empty/ineligible expansion behavior. Add `lua/parley/markdown_finder.lua` and `tests/unit/markdown_finder_spec.lua` to the `ui/pickers` traceability surface, and retain/add both under `modes/super_repo`. Keep `atlas/index.md` unchanged because all edited pages are already linked.

- [ ] **Step 2: Run formatting/static checks**

Run: `make lint`

Run: `git diff --check`

Expected: PASS with no warnings or whitespace errors.

- [ ] **Step 3: Run focused and full verification**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/markdown_finder_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c "qa!"`

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/super_repo_spec.lua" -c "qa!"`

Run: `make test`

Expected: all PASS.

- [ ] **Step 4: Reconcile durable checkboxes and log evidence**

Tick completed steps in this plan and the issue summary plan; append verification commands/results and any architecture decisions to `## Log`. Do not mark the close step complete before the boundary gate succeeds.

- [ ] **Step 5: Commit documentation and issue evidence**

```bash
git add atlas/modes/super_repo.md atlas/ui/pickers.md atlas/issues/issue-management.md atlas/traceability.yaml workshop/issues/000187-markdown-finder-in-repo-mode-should-present-repo-facet-search.md workshop/plans/000187-markdown-finder-in-repo-mode-should-present-repo-facet-search-plan.md
git commit -m "docs: #187 map contextual markdown facets"
```

## Boundary procedure after every implementation checkbox is complete

This is gate metadata, not an implementation checkbox: leaving the close itself
unchecked would make the durable plan appear incomplete to its own reviewer.

1. Run `sdlc actual --issue 187`, then `sdlc close --issue 187 --verified '<focused suites, full make test, lint, diff-check, and behavior evidence>'`. Let the binary dispatch the mandatory fresh-context review; fix Critical/Important findings and rerun the same gate.
2. Inspect the gate-produced issue/log and review sidecar. If the sidecar contains a raw transcript, ANSI plumbing, or generated bulk, compact it to durable metadata, findings, resolutions, verdict, and evidence while preserving the review result.
3. Run `git diff --check` and the relevant focused test if a review fix changed code.
4. Commit the close mutations and normalized sidecar with the required `Co-Authored-By:` trailer; do not leave gate-generated artifacts uncommitted.
