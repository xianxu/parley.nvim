# Issue Finder Repository Facets Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract Chat Finder's current facet behavior into a reusable pure model and add persistent repository facets to Issue Finder only for completely labelled multi-repository super-repo scans.

**Architecture:** A new pure `finder_facets` module owns discovered-key merging, OR filtering, state transitions, and float-picker tag projection. Chat Finder and Issue Finder remain integration adapters: each supplies entry facets, owns persistent session state, renders its existing items, and refreshes the existing picker in place so query state is untouched.

**Tech Stack:** Lua, Neovim, Plenary/Busted, Parley's existing `float_picker` tag bar and headless test harness.

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `FinderFacetModel` | `lua/parley/finder_facets.lua` | new |

- **FinderFacetModel** — deterministic functions for merging discovered facet keys into persistent state, applying ALL/NONE/toggle transitions, OR-filtering entries by injected facet keys, and projecting ordered picker tags.
  - **Relationships:** one model serves N finder adapters; each finder session owns one state table; each entry maps to 0..N facet keys.
  - **DRY rationale:** it replaces Chat Finder's inline facet state machine and prevents Issue Finder and #187 from copying the same policy (`ARCH-DRY`, `ARCH-PURE`).
  - **Future extensions:** #187 can inject repository keys for Markdown Finder without changing the model; #115's registry-driven shared finder must consume this engine by injecting descriptor-derived keys rather than defining parallel facet policy. Registry/type-descriptor declarations and finder unification remain outside #186.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `ChatFinderFacetAdapter` | `lua/parley/chat_finder.lua` | modified | chat scan entries, `_chat_finder.tag_state`, and `float_picker` |
| `IssueFinderRepoFacetAdapter` | `lua/parley/issue_finder.lua` | modified | super-repo roots, issue scans, `_issue_finder.repo_facet_state`, and `float_picker` |
| `IssueFinderSessionState` | `lua/parley/init.lua` | modified | persistent in-memory finder state |

- **ChatFinderFacetAdapter** — maps each chat entry's tags (or `""` for untagged) into the pure model and converts surviving entries back into the exact current picker items.
  - **Injected into:** `FinderFacetModel` receives the entry-to-facets function; the adapter supplies model output to the existing float picker.
  - **Future extensions:** Chat-specific recency and sticky-query behavior remain outside the model.
- **IssueFinderRepoFacetAdapter** — enables repo facets only when all expanded roots have non-empty labels and at least two unique labels, maps `issue.repo_name` into the model, and updates the picker in place.
  - **Injected into:** `FinderFacetModel` receives repository keys only after the complete-label eligibility check; scanner and picker stay fakeable in production-shaped tests.
  - **Future extensions:** the same eligibility adapter pattern can be reused by Markdown Finder in #187.
- **IssueFinderSessionState** — owns one `repo_facet_state` shared by issue/history views and later invocations.
  - **Injected into:** `IssueFinderRepoFacetAdapter` reads and replaces/merges this table while the existing `query` field remains independent.
  - **Future extensions:** additional persistent Issue Finder presentation preferences belong beside, not inside, the pure model.

## Preflight: Verify cross-issue ownership

- [ ] Run: `rg -n '^deps:.*000186' workshop/issues/000115-improve-c-g-m-so-that-it-works-to-find-artifacts-of-interest.md`
- [ ] Run: `rg -n 'must consume that engine' workshop/issues/000115-improve-c-g-m-so-that-it-works-to-find-artifacts-of-interest.md`
- [ ] Run: `rg -n 'must not introduce a second facet-policy' workshop/issues/000115-improve-c-g-m-so-that-it-works-to-find-artifacts-of-interest.md`
- [ ] Run: `sdlc issue validate --issue 115`

Expected: every grep finds its independent dependency/ownership assertion and
schema validation passes. Stop and repair the planning artifact before Task 1
if any command fails.

## Chunk 1: Extract and regression-lock the canonical facet model

### Task 1: Build the pure finder facet model with TDD

**Files:**
- Create: `lua/parley/finder_facets.lua`
- Create: `tests/unit/finder_facets_spec.lua`

- [ ] **Step 1: Write failing tests for discovery and state merging**

  Cover deterministic sorted discovery, injected entry-to-facets mapping, new keys defaulting to `true`, prior enabled/disabled choices surviving, and temporarily undiscovered keys remaining in the returned state. Include the Chat Finder untagged mapping (`{ "" }`) as an ordinary facet key.

- [ ] **Step 2: Run the pure spec and verify the missing module failure**

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"`

  Expected: FAIL because `parley.finder_facets` does not exist.

- [ ] **Step 3: Implement the specified discovery and merge contracts**

  Add a dependency-free module with these exact contracts:

  - `discover(entries, facets_for_entry) -> keys`: call the injected function once per entry; deduplicate returned string keys; sort non-empty keys lexicographically; append `""` last; return `{}` when no keys are discovered.
  - `merge_state(state, discovered) -> state_copy`: copy every boolean entry in `state` (or start empty for nil), retain undiscovered keys, and add each missing discovered key as `true`; never mutate either input.

  ```lua
  local M = {}

  function M.discover(entries, facets_for_entry)
      local seen = {}
      for _, entry in ipairs(entries) do
          for _, key in ipairs(facets_for_entry(entry)) do
              seen[key] = true
          end
      end
      local keys = {}
      local has_empty = seen[""] == true
      seen[""] = nil
      for key in pairs(seen) do table.insert(keys, key) end
      table.sort(keys)
      if has_empty then table.insert(keys, "") end
      return keys
  end

  function M.merge_state(state, discovered)
      local merged = {}
      for key, enabled in pairs(state or {}) do merged[key] = enabled end
      for _, key in ipairs(discovered) do
          if merged[key] == nil then merged[key] = true end
      end
      return merged
  end
  ```

  Do not embed chat, issue, repository, display-label, or picker knowledge. Preserve Chat Finder's canonical order: lexicographic non-empty keys, then the empty-string untagged key.

- [ ] **Step 4: Run the focused spec and verify the merge cases pass**

  Run the Task 1 headless command.

  Expected: PASS for discovery and merge tests.

- [ ] **Step 5: Write failing tests for transitions, filtering, and projection**

  Pin these contracts:

  - `toggle(state, key)` changes only that key without mutating the input;
  - `set_all(state, true|false)` changes every retained key;
  - OR filtering keeps an entry when at least one injected key is enabled;
  - a zero-facet entry is excluded when its adapter supplies no enabled key;
  - all-enabled is a no-op in result semantics and NONE returns zero mapped entries;
  - projection returns `{ label = key, enabled = state[key] ~= false }` in discovered order and returns `nil` for no discovered keys.

- [ ] **Step 6: Run the focused spec and verify the new assertions fail**

  Run the Task 1 headless command.

  Expected: FAIL because the transition/filter/projection functions are absent.

- [ ] **Step 7: Implement the specified immutable pure operations**

  Complete the API with these exact contracts: `toggle(state, key)` copies state and assigns `not (state[key] ~= false)` to `key`; `set_all(state, enabled)` copies state and assigns the boolean to every retained key; `filter(entries, state, facets_for_entry)` returns a fresh ordered list containing an entry iff any injected key has state value other than `false`; and `project(discovered, state)` returns `nil` for zero discovered keys or ordered `{ label = key, enabled = state[key] ~= false }` records otherwise. Adapters explicitly assign returned state to their session owner. Retained undiscovered keys never affect entries that do not carry those keys.

- [ ] **Step 8: Run the pure spec and full diff check**

  Run the Task 1 headless command.

  Run: `git diff --check`

  Expected: all tests PASS and no whitespace errors.

- [ ] **Step 9: Commit the pure model**

  ```bash
  git add lua/parley/finder_facets.lua tests/unit/finder_facets_spec.lua
  git commit -m "finder: #186 extract pure facet model" -m "Centralize persistent facet merging, transitions, OR filtering, and picker projection so finder adapters share one deterministic policy.\n\nCo-Authored-By: Codex <noreply@openai.com>"
  ```

### Task 2: Replace Chat Finder's inline facet state machine without behavior change

**Files:**
- Modify: `lua/parley/chat_finder.lua:590-750`
- Modify: `tests/unit/chat_finder_logic_spec.lua`
- Modify: `tests/unit/float_picker_spec.lua`

- [ ] **Step 1: Characterize real picker update query preservation**

  Add a production-shaped test to `tests/unit/float_picker_spec.lua` that opens the real picker with a tag bar and an initial query of `"alpha"`, then finds the real prompt buffer, replaces its line with the prompt prefix plus the distinct whitespace-sensitive live query `"  alpha beta  "`, and executes the buffer's real `TextChanged` autocmd so `sync_query_from_prompt()` and `apply_filter()` run exactly as they do for user typing. Capture that exact prompt line, call the returned `picker.update()` with projected tags and items containing both `"alpha beta"` and `"alpha gamma"`, then assert the prompt line is byte-for-byte unchanged and only the `"alpha beta"` row remains visible. A stale initial/partial query would show both rows, so the result assertion independently proves update used the complete synchronized live query. Use the real prompt/results buffers and picker return value, not a capture fake.

- [ ] **Step 2: Run the real picker characterization and record the green baseline**

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c "qa!"`

  Expected: PASS on the existing `float_picker.update` implementation, proving the live prompt/query contract before finder adapters are changed. If it fails, stop and treat the picker defect as implementation work required by this issue before adapter refactoring.

- [ ] **Step 3: Add a concrete passing characterization harness for Chat Finder facets**

  Add a `describe("ChatFinder facet compatibility")` block to `tests/unit/chat_finder_logic_spec.lua`. Reuse its real temporary chat roots and write three minimal chat markdown files whose frontmatter produces `alpha`, `beta`, and no tags. Replace `M.float_picker.open` with a capture fake that stores its `opts` and returns `{ update = function(new_items, new_tags) ... end }`; initialize `M._chat_finder.tag_state = { alpha = false, missing = false }` and `M._chat_finder.sticky_query` with a non-empty query before calling `M.cmd.ChatFinder()`.

  Assert the current implementation's observable contract before refactoring:

  - picker tags remain alphabetically ordered with `""` last;
  - existing disabled state and new-enabled defaults survive reopening;
  - toggle, ALL, and NONE call `picker.update` with the correct OR-filtered items and tag projection;
  - the exact typed/sticky query is not reset by a facet update;
  - retained temporarily absent tag state is restored when that tag reappears.

- [ ] **Step 4: Run the Chat Finder characterization and record the green baseline**

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c "qa!"`

  Expected: PASS on the existing inline implementation. These are characterization tests, so their green baseline proves the extraction preserves behavior; the pure model itself was developed red-green in Task 1.

- [ ] **Step 5: Adapt Chat Finder to `finder_facets`**

  Require `parley.finder_facets` near the module imports. Replace only the inline collection/merge/filter/transition/projection block with calls to the pure API:

  ```lua
  local function chat_facets(entry)
      return #entry.tags == 0 and { "" } or entry.tags
  end

  local discovered = finder_facets.discover(entries, chat_facets)
  _parley._chat_finder.tag_state = finder_facets.merge_state(
      _parley._chat_finder.tag_state,
      discovered
  )
  ```

  `build_picker_data` filters through the model and then renders the same `{display, search_text = ordinal, value}` item shape. Tag callbacks assign the model's fresh state back to `_chat_finder.tag_state` before calling the existing `picker_ref.update`; leave `float_picker.lua`, tag-bar styling, recency, initial selection, and sticky-query handling unchanged.

- [ ] **Step 6: Run focused Chat and facet specs**

  Run:

  ```bash
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c "qa!"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c "qa!"
  ```

  Expected: PASS, including unchanged Chat Finder presentation and persistence behavior.

- [ ] **Step 7: Run related picker/sticky regressions**

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_sticky_spec.lua" -c "qa!"`

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/float_picker_spec.lua" -c "qa!"`

  Expected: PASS.

- [ ] **Step 8: Commit the Chat Finder adapter**

  ```bash
  git add lua/parley/chat_finder.lua tests/unit/chat_finder_logic_spec.lua tests/unit/float_picker_spec.lua
  git commit -m "finder: #186 reuse facets in chat finder" -m "Keep the established facet UI and sticky-query behavior while moving its deterministic policy behind the reusable model.\n\nCo-Authored-By: Codex <noreply@openai.com>"
  ```

## Chunk 2: Add Issue Finder repo facets and deliver

### Task 3: Integrate persistent repository facets into Issue Finder

**Files:**
- Modify: `lua/parley/issue_finder.lua:130-350`
- Modify: `lua/parley/init.lua:3140-3160`
- Modify: `tests/unit/issue_finder_spec.lua`

- [ ] **Step 1: Extend the fake Issue Finder harness for super-repo roots and picker updates**

  Make the existing production-shaped describe block accept configurable `super_repo.expand_roots` results, root-specific `scan_issues` fixtures, and a fake picker whose returned object exposes `update(items, tags)`. Preserve the existing query-persistence assertions.

- [ ] **Step 2: Write failing eligibility and initial-render tests**

  Cover:

  - two fully labelled expanded repos produce `[ALL] [NONE]` callbacks plus sorted repo tags and all rows;
  - ordinary single-root mode has `tag_bar == nil`;
  - one unique label, any nil/empty label, or a partially labelled expanded set has `tag_bar == nil` and leaves every scanned row unfiltered;
  - eligibility is derived from expanded roots, not whichever current view happens to contain issues.

- [ ] **Step 3: Run the Issue Finder spec and verify the facet assertions fail**

  Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c "qa!"`

  Expected: FAIL because Issue Finder does not expose a repo tag bar.

- [ ] **Step 4: Add persistent state, eligibility, and the initial repo tag bar**

  Initialize `repo_facet_state = nil` in `_parley._issue_finder` in `init.lua`. In `issue_finder.lua`, add a small pure/local eligibility helper that returns sorted unique repository labels only when `sr_issues` exists, every constructed root has a non-empty `repo_name`, and at least two unique labels exist; otherwise return `nil`.

  Merge eligible labels through `finder_facets.merge_state`. For an eligible set, construct initial rendered items through a local `build_picker_data()` and pass a `tag_bar` with projected tags plus ALL/NONE/toggle callbacks to `float_picker.open`; the callbacks may call a local refresh function whose full current-item contract is pinned in Steps 6–7. Never filter or construct `tag_bar` when eligibility is nil (`ARCH-PURPOSE`). This is the minimum implementation needed for Step 2's initial-render tests to turn green.

- [ ] **Step 5: Run the Issue Finder spec and verify initial eligibility passes**

  Run the Task 3 headless command.

  Expected: initial render and fallback tests PASS; transition tests are not added yet.

- [ ] **Step 6: Write failing in-place filtering and persistence tests**

  Assert:

  - individual toggles change only one repo and `picker.update` receives remaining rows;
  - ALL restores every row and NONE yields no rows;
  - the current complete query remains stored and is not rewritten during any update;
  - state survives cancel/reopen and the issues/history view-cycle repaint;
  - a new repo defaults enabled without re-enabling an earlier disabled repo;
  - a temporarily missing repo key remains disabled when it returns;
  - repository filtering runs after view filtering/sorting and preserves survivor order/item shapes.

- [ ] **Step 7: Implement the picker-data and tag-bar adapter**

  Retain the sorted issue records separately from rendered items. Add one `build_picker_data()` function that conditionally filters sorted issues through `finder_facets.filter`, renders the existing item shape, and projects eligible repo tags. Add `picker_ref` and tag callbacks matching Chat Finder's current pattern:

  ```lua
  local function refresh_picker()
      items, tag_bar_tags = build_picker_data()
      if picker_ref.update then
          picker_ref.update(items, tag_bar_tags)
      end
  end
  ```

  Declare `items` and `tag_bar_tags` as the adapter's current rendered state, assign both before every `picker.update`, and make delete-selection lookup plus `context.issue_finder_items` read that current `items` variable. Assign the return of `toggle`/`set_all` into `_parley._issue_finder.repo_facet_state`, refresh in place, and pass `tag_bar` plus the existing `initial_query`/`on_query_change` to `float_picker.open`.

- [ ] **Step 8: Run Issue Finder, pure facet, and Chat Finder specs**

  Run the three headless commands from Tasks 1–3.

  Expected: PASS with query, view, reopen, new-repo, rediscovery, and Chat compatibility coverage.

- [ ] **Step 9: Commit the Issue Finder feature**

  ```bash
  git add lua/parley/issue_finder.lua lua/parley/init.lua tests/unit/issue_finder_spec.lua
  git commit -m "issues: #186 add super-repo facets" -m "Expose repository selection only for complete multi-repository root metadata, retaining query and facet choices across Issue Finder sessions and views.\n\nCo-Authored-By: Codex <noreply@openai.com>"
  ```

### Task 4: Update maps, traceability, and verification evidence

**Files:**
- Modify: `atlas/issues/issue-management.md`
- Modify: `atlas/traceability.yaml`
- Modify: `README.md` only if its current Issue Finder description mirrors super-repo behavior
- Modify: `workshop/issues/000186-issue-finder-in-repo-mode-should-present-repo-facet-search.md`

- [ ] **Step 1: Update the Issue Finder architecture map**

  Amend `atlas/issues/issue-management.md` to describe the complete-label, multi-repository eligibility rule, `[ALL] [NONE]` repo bar, persistent repo selection shared across issues/history, and query-preserving in-place refresh. Point to `finder_facets.lua` as the shared pure policy and note that Chat Finder remains the presentation contract.

- [ ] **Step 2: Update traceability**

  Add `lua/parley/finder_facets.lua`, `tests/unit/finder_facets_spec.lua`, `tests/unit/chat_finder_logic_spec.lua`, and `tests/unit/issue_finder_spec.lua` to the relevant `modes/super_repo` and `issues/issue-management` code/test entries without removing existing coverage. Keep the YAML deterministic and deduplicated.

- [ ] **Step 3: Check whether README requires a narrowly scoped update**

  Run: `rg -n "Issue Finder|IssueFinder|super-repo" README.md`

  Expected: either no mirrored behavioral claim (leave README untouched) or one existing description updated to mention the repo bar. Do not add a new broad documentation section.

- [ ] **Step 4: Run focused feature verification**

  Run:

  ```bash
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_facets_spec.lua" -c "qa!"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/chat_finder_logic_spec.lua" -c "qa!"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/issue_finder_spec.lua" -c "qa!"
  nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/finder_sticky_spec.lua" -c "qa!"
  ```

  Expected: all focused specs PASS.

- [ ] **Step 5: Run traceability and full-suite verification**

  Run: `make test-spec SPEC=modes/super_repo`

  Run: `make test-spec SPEC=issues/issue-management`

  Run: `make test`

  Run: `git diff --check`

  Expected: traceability checks and the complete test suite PASS; no whitespace errors.

- [ ] **Step 6: Review the final diff for architectural economy**

  Run: `git diff --stat main...HEAD && git diff main...HEAD -- lua/parley/finder_facets.lua lua/parley/chat_finder.lua lua/parley/issue_finder.lua lua/parley/init.lua`

  Confirm the shared module contains no finder-specific UI/session policy, both adapters call one model rather than duplicating transitions/filtering, `float_picker.lua` remains unchanged unless a test proved a real contract gap, and #187 can map Markdown entries to repo keys without an API change (`ARCH-DRY`, `ARCH-PURE`, Simplicity First).

- [ ] **Step 7: Update issue plan/log and commit documentation**

  Mark the four issue-plan checkboxes complete only after their evidence exists. Append a dated `## Log` entry naming focused/full commands and outcomes; if implementation changed the approved plan, append (do not overwrite) a timestamped `## Revisions` entry explaining why and what changed.

  ```bash
  git add atlas/issues/issue-management.md atlas/traceability.yaml README.md workshop/issues/000186-issue-finder-in-repo-mode-should-present-repo-facet-search.md
  git commit -m "docs: #186 map reusable finder facets" -m "Record the shared facet boundary, Issue Finder super-repo eligibility, and verified coverage so #187 can consume the same policy.\n\nCo-Authored-By: Codex <noreply@openai.com>"
  ```

- [ ] **Step 8: Cross the issue close boundary**

  Run: `sdlc actual --issue 186`

  Then run `sdlc close --issue 186 --verified '<focused specs, traceability specs, make test, git diff --check, and final diff-review evidence>'`; add `--no-atlas` only if the atlas gate does not recognize the already committed atlas update and explain that exact mismatch in the evidence. The command owns the mandatory fresh-context boundary review; fix every Critical/Important finding and rerun the same close command until it succeeds.

  Publish using the next action reported by `sdlc state`/`sdlc close` (`sdlc pr` then `sdlc merge` on a feature branch, or `sdlc push` only if the workflow remained on main).

## Revisions

### 2026-07-14T17:01:00-07:00 — code-entry plan-quality gate

- Reason: adapter capture fakes could prove that callbacks use `picker.update`,
  but could not prove the real picker preserves its live prompt and fuzzy query.
- Delta: add a production-shaped `float_picker_spec.lua` characterization that
  opens the real picker, updates items/tags in place, and compares prompt text
  byte-for-byte while confirming filtering still uses the same query.

### 2026-07-14T17:08:00-07:00 — cross-issue ownership review

- Reason: #115's future registry-driven shared finder also names Issue Finder
  repository facets and could otherwise grow a parallel state machine.
- Delta: declare `finder_facets` as the registry-independent policy engine that
  #115 must consume; leave descriptor declarations and finder unification to
  #115, and add #186 as its dependency.

### 2026-07-14T17:15:00-07:00 — executable dependency and estimate review

- Reason: the committed #115 dependency was not represented as an executable
  verification step, and the real-picker regression deserved its own estimate
  primitive rather than being hidden inside adapter work.
- Delta: add a pre-delivery grep/schema check for #115's dependency and
  ownership contract; recalibrate #186 to 4.0 ship-hours with three focused
  Lua/Neovim primitives.
