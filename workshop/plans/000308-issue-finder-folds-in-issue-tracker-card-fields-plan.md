# Issue-tracker card fields in parley's issue views — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In a repository tracked by ariadne#252, the issue finder and opened issue buffers show the authoritative card fields from the `issue-tracker` branch, painting in amber every field where the tracker disagrees with the local `card_mirror`.

**Architecture:** A pure `issue_cards` module parses git output and card blobs, overlays card values onto finder records, and computes buffer annotations. A thin `issue_tracker` IO shell reads `refs/remotes/<remote>/issue-tracker` asynchronously (`git ls-tree` + one `git cat-file --batch`, OID-cached), and runs a throttled background `git fetch` that reports when the ref moved. The finder overlays the cards before it sorts and re-renders when the cards arrive or move. Issue buffers get end-of-line virtual text. `float_picker` gains a generic per-item highlight-span field.

**Tech Stack:** Lua, Neovim 0.11 (`vim.system`, extmarks), git, plenary busted specs (`make test`, `make test-spec`).

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_card`, `parse_tree`, `parse_batch` | `lua/parley/issue_cards.lua` | new |
| `select_remote`, `card_field_names` | `lua/parley/issue_cards.lua` | new |
| `overlay`, `annotations` | `lua/parley/issue_cards.lua` | new |
| `render` (issue_finder_records) | `lua/parley/issue_finder_records.lua` | new (moved out of `issue_finder.open`) |
| float_picker item `highlights` | `lua/parley/float_picker.lua` | modified (new optional item field) |

- **Card** `{id, title, fields = {name = value}}` — one parsed `workshop/issue-cards/NNNNNN-*.md` blob. Top-level `key: value` frontmatter lines only (the nested `tracker:` envelope is internal and ignored); quotes and trailing `# comment` are stripped; title is the first H1.
  - **Relationships:** N cards : 1 tracker tip; 1 card : 0..1 details record (joined by `id` within one repo root).
  - **DRY rationale:** the card-owned field list comes from the vocabulary JSON (`card.fields`), and the card directory and tracker branch come from `discovery.cards` and `discovery.tracker`. Parley hardcodes none of them (ARCH-DRY).
  - **Future extensions:** listing card-only issues (details absent here), which needs an "open card blob" action.
- **overlay(record, card, names)** → a new record. For each card-owned field the record carries (`status`, `title`, `created`, `updated`, `github_issue`), the card value wins, and `record.tracker_stale[name] = true` when the card value differs from the details value. `nil` and `""` count as equal. Sets `record.tracked = true`. A record without a card is returned unchanged (read-only view: keep the details value and invent nothing).
- **annotations(lines, card, names)** → `{ {row0, text} }`: one entry for each card-owned frontmatter line whose value differs from the card, plus one for the H1 when `title` differs. Text: `← tracker: <value>` (`(empty)` for blank).
- **render(issue)** → `{display, search_text, highlights}`: the existing row format, built from segments so the span of a stale field is known. Stale `status`, `title`, `github_issue` and `created` segments carry `ParleyIssueTracker`.
- **select_remote(upstream_remote, tracker_remotes)** → the upstream's remote if it carries the tracker ref, else the only remote that carries it, else nil. Parley picks the remote only to read; sdlc still owns where writes go.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `load`, `refresh`, `repo_root`, `field_names` (issue_tracker) | `lua/parley/issue_tracker.lua` | new | `git` via `vim.system` |
| `ensure_highlight`, `fetch_enabled` (issue_tracker) | `lua/parley/issue_tracker.lua` | new | highlight group; fetch switch (off under the test harness) |
| `reset_for_tests`, `_on_git`, `_blob_count_for_tests`, `_fetching_for_tests` | `lua/parley/issue_tracker.lua` | new | test seams over in-memory state |
| `attach`, `setup`, `NS` (issue_tracker_buffer) | `lua/parley/issue_tracker_buffer.lua` | new | extmarks + autocmds |
| finder overlay wiring | `lua/parley/issue_finder.lua` | modified | picker session |
| issue-buffer autocmd hook | `lua/parley/init.lua` (issue `*.md` BufRead autocmd) | modified | Neovim autocmd |

- **issue_tracker** keeps per-root, in-memory state `{remote, ref, tip, cards, blobs, fetched_at, loading, fetching}`.
  - `load(root, cb)` → `cb(cards|nil)`. It returns nil when the marker is missing, no ref resolves, or git fails, and that nil keeps today's behaviour. Concurrent loads for one root share a single run through a waiter list.
  - `refresh(root, on_moved)`: when `fetched_at` is at least `M.fetch_interval_s` old (default 60), it runs `git fetch --quiet <remote> issue-tracker` with `GIT_TERMINAL_PROMPT=0` and a 15s timeout, then reloads. It calls `on_moved(cards)` only when the tip changed. A failed fetch goes to the debug log and the local ref stays in use.
  - **Tests:** real git in disposable repos (a bare remote and two clones). Git is the external system, and the test drives the real binary behind the same seam (ARCH-MOCK). No function-call mocks.
- **issue_tracker_buffer.attach(buf, path)** runs only for details files in a tracked repo. It annotates through `issue_cards.annotations`, re-annotates on `BufWritePost`, and re-annotates when `refresh` reports a move.

### Operating envelope (ARCH-CONSTRAINTS)
- **Path:** finder open and buffer open, both interactive. Every git call is async, so neither path blocks on git. Rows render first from the details and are then re-rendered with tracker values.
- **Load:** the tracker in this repo has about 300 cards (ariadne measures 10k cards at about 1s). Each load runs `for-each-ref` + `rev-parse` + `ls-tree`, plus one `cat-file --batch` that only receives OIDs not already cached. After the first load the cache makes this nearly free.
- **Network:** at most one fetch per root per 60s, with a 15s timeout. It never runs on the render path.

### Ordering (ARCH-ORDER)
- A card delivery that arrives after the picker closes is dropped (`closed` guard).
- A load that resolves after a newer load for the same root has started is discarded (generation counter), so a slow old read cannot overwrite a newer tip.

### Trust (ARCH-SECURE)
- Card blobs come from a git ref that anyone with push access can write. They are parsed as text and shown as text. Nothing from them is executed or used to build a path; `id` must match `^%d+$`.
- git runs with argv only, never a shell string.

### Lifecycle (ARCH-FUNERAL)
- Nothing durable is created. Per-root state and the OID blob cache live in memory and die with the Neovim session. Each successful load prunes the blob cache down to the OIDs in the current tree, so its size is bounded by the tracker's card count.
- The fetch updates `refs/remotes/<remote>/issue-tracker`, a ref git and sdlc already own. Parley adds no new ref.
- Extmarks live in one namespace and are cleared before each re-annotation.

---

## Tasks

### Task 1: pure `issue_cards`

**Files:** Create `lua/parley/issue_cards.lua`, `tests/unit/issue_cards_spec.lua`.

- [ ] Write failing specs:
  - `parse_card` on a real #296 card blob (nested `tracker:` handoff block, `started:`, `status: wontfix`, H1 title) returns `id=000296`, `fields.status=wontfix`, no `handoff`/`token` keys, `title="Package Screenkey for app recordings"`. Also: no frontmatter → nil; non-numeric id → nil; quoted values and trailing `# comment` are stripped.
  - `parse_tree("100644 blob abc\tworkshop/issue-cards/000296-x.md\n...")` → `{ {oid="abc", path=..., id="000296"} }`; non-`.md` lines and lines without an id are skipped.
  - `parse_batch` decodes two `<oid> blob <size>\n<bytes>\n` frames (one containing an embedded blank line) plus `<oid> missing`, giving `{oid → text}` without the missing entry. A truncated frame stops parsing without raising an error.
  - `select_remote("origin", {"origin","fork"})="origin"`; `select_remote(nil, {"fork"})="fork"`; `select_remote(nil, {"a","b"})=nil`; `select_remote("x", {})=nil`.
  - `card_field_names(raw)` on the shipped vocab JSON contains `status`, `title` and `github_issue` but not `id`. It returns nil when `raw.card` is missing.
  - `overlay`: a details record with `status=open` and a card with `status=wontfix` gives status `wontfix` and `tracker_stale.status=true`. Equal fields are not stale. `github_issue` nil vs `""` is not stale. A differing title is flagged. No card → the same values, and `tracked` is nil.
  - `annotations` on #296's details lines vs its card gives rows for `status`, `created`/`updated` only when they differ, and none for `deps` or `card_mirror`. A title diff annotates the H1 row.
- [ ] Run `make test-spec SPEC=issues/issue-management` (or `nvim --headless … PlenaryBustedFile tests/unit/issue_cards_spec.lua`, per TOOLING.md). Expected: FAIL (module missing).
- [ ] Implement as described in Core concepts, with no IO. `parse_batch` walks the payload by byte offsets, using the size taken from each header.
- [ ] Run the spec again: PASS. Commit `#308: issue_cards: pure card parsing and overlay`.

### Task 2: `float_picker` per-item highlight spans

**Files:** Modify `lua/parley/float_picker.lua` (`refresh_results`, around L909–938). Test: `tests/unit/float_picker_spec.lua`.

- [ ] Failing spec: open a picker with `items = {{display="[wontfix] 000296 x", value="a", highlights={{1, 9, "ParleyIssueTracker"}}}}`. Assert that the results buffer has a `ParleyIssueTracker` highlight over columns 2..10 (shifted by the 1-column leading space) in the `parley_picker_items` namespace. Assert it is still there after `update()` with filtered items, and that spans past the truncated line length are clipped instead of raising an error.
- [ ] Implement: `local ITEM_NS = vim.api.nvim_create_namespace("parley_picker_items")`. After `nvim_buf_set_lines` in `refresh_results`, clear `ITEM_NS`, then for each visible `filtered[idx]` with `highlights`, call `nvim_buf_add_highlight(results_buf, ITEM_NS, group, visual_row_for_index(idx)-1, s+1, math.min(e+1, #line))`. Skip this while `status_line` is set.
- [ ] Spec PASS; run the existing float_picker specs for regressions. Commit `#308: float_picker: item highlight spans`.

### Task 3: `issue_finder_records.render` (segment-built rows)

**Files:** Modify `lua/parley/issue_finder_records.lua` and `lua/parley/issue_finder.lua` (`render_issue`, L386–403), which now delegates. Test: `tests/unit/issue_finder_records_spec.lua`.

- [ ] Failing specs: `render` of an untracked issue gives the exact same `display`/`search_text` as today's `render_issue`, using the existing format strings (pins the current behaviour). An overlaid issue with `tracker_stale={status=true}` gives a `highlights` span covering exactly `[wontfix]`. A stale `github_issue` spans `(#N)`.
- [ ] Implement with an `append(text, group)` helper that tracks the byte offset. Define `ParleyIssueTracker` once in `issue_cards.HIGHLIGHT = "ParleyIssueTracker"`, and add `issue_tracker.ensure_highlight()` (`nvim_set_hl(0, HIGHLIGHT, {fg="#FFBF00", default=true})`, overridable by users).
- [ ] PASS + `tests/unit/issue_finder_spec.lua` still PASS. Commit `#308: issue finder rows built from segments`.

### Task 4: `issue_tracker` IO shell

**Files:** Create `lua/parley/issue_tracker.lua`, `tests/integration/issue_tracker_spec.lua`.

- [ ] Failing integration spec. In `$TMPDIR`, create `remote.git` (bare) and clone A with `workshop/issue-tracker.json` on main. Create an orphan `issue-tracker` branch in A with two cards and push it. Clone B and fetch. Cases:
  1. `load(B)` → cards for both ids, `status` as written.
  2. A pushes a status change, then with `fetch_interval_s=0`, `refresh(B, on_moved)` fires `on_moved` with the new status; a second `refresh` with no remote change does not fire.
  3. A repo without the marker → `load` cb(nil), and no git commands beyond the stat run.
  4. A repo with the marker but no tracker ref → cb(nil).
  5. Two concurrent `load`s → one ls-tree run (count through a `M._on_git` debug hook used only by tests), and both callbacks receive the cards.
  6. A second `load` after an unchanged tip sends no cat-file batch, because every blob is cached.
- [ ] Implement:
  - `repo_root(path)` = `vim.fs.root(path, ".git")`.
  - `load` sequence: stat the marker (`workshop/issue-tracker.json`, ariadne's cutover marker), then `git for-each-ref --format=%(refname:lstrip=2) %(objectname) refs/remotes/*/<tracker>`, then `git rev-parse --abbrev-ref --symbolic-full-name @{u}` (failure is fine), then `select_remote`, then `git ls-tree <tip> -- <cards>/`, then `git cat-file --batch` with stdin = OIDs not yet cached, then build `cards[id]` and prune the blob cache.
  - Include the generation guard and the waiter list.
  - All callbacks run on the main loop via `vim.schedule`.
- [ ] PASS. Commit `#308: issue_tracker: async card reader with throttled fetch`.

### Task 5: finder overlay wiring

**Files:** Modify `lua/parley/issue_finder.lua` (`M.open`, the materialize callback near L495). Test: extend `tests/unit/issue_finder_spec.lua`, or add `tests/integration/issue_finder_tracker_spec.lua`, using Task 4's disposable repo.

- [ ] Failing spec: open the finder against the tracked temp repo, whose details say `open` while the card says `wontfix`. After the scan settles and cards are delivered, the row reads `[wontfix]` with a `ParleyIssueTracker` span, and sort order uses the card status. The untracked fixture's rows are unchanged.
- [ ] Implement:
  - Keep `raw_records` from `outcome.records`.
  - Keep a `cards_by_root` map.
  - `recompute()` overlays each record whose `repo_root(record.path)` has cards, then runs `issue_records.materialize`, then `build_picker_data`.
  - At open, for each distinct repo root among `roots`, call `issue_tracker.load(root, deliver)` and then `issue_tracker.refresh(root, deliver)`.
  - `deliver` stores the cards. If the picker has materialized and is not closed, it calls `recompute()` and `picker_ref.update(items, tags)`.
  - Set a `closed` flag in `on_select`/`on_cancel`.
- [ ] PASS + full `make test`. Commit `#308: issue finder folds in tracker cards`.

### Task 6: issue-buffer annotations

**Files:** Create `lua/parley/issue_tracker_buffer.lua`. Modify `lua/parley/init.lua` (the issue `*.md` BufRead autocmd around L1091; call `attach` beside the completion hook). Test: `tests/integration/issue_tracker_buffer_spec.lua`.

- [ ] Failing spec: edit the stale details file from the temp repo. After cards load, the `parley_issue_tracker` namespace holds an eol virt_text extmark `← tracker: wontfix` with `ParleyIssueTracker` on the `status:` row. After the buffer is edited to `status: wontfix` and written, the extmark is gone. A non-tracked repo buffer gets no extmarks.
- [ ] Implement `attach(buf)`:
  - Derive the id from the filename `^(%d+)%-`, then `issue_tracker.load(root, ...)`, then `annotate(buf, card)`.
  - `annotate` clears the namespace, reads the buffer lines, and places extmarks from `issue_cards.annotations`.
  - Register a buffer-local `BufWritePost` that re-annotates from the cached cards.
  - Call `refresh(root, ...)`, which re-annotates if the buffer is still valid.
- [ ] PASS + full `make test`. Commit `#308: amber tracker values in issue buffers`.

### Task 7: atlas + verification

- [ ] Update `atlas/issues/issue-management.md` with a "Tracker cards (ariadne#252)" paragraph covering source, freshness, amber semantics and the read-only scope. Link the new modules. Note the follow-up: the status-cycling keys still write the mirror.
- [ ] Run `make test` and `make lint`.
- [ ] Manual check in this repo: `:ParleyIssueFinder` shows #296 as `[wontfix]` in amber, and opening `workshop/issues/000296-app-screenkey.md` shows amber `← tracker: wontfix`. Record this in the issue Log.
- [ ] `sdlc close --issue 308 --verified '…'`.

## Revisions

- 2026-09-30 — the single-source arch guard needs every added export as its own backticked name in a Core-concepts row, so the entity tables were split per name. Added `fetch_enabled`: specs never fetch from a real remote unless they opt in. Added the `_fetching_for_tests` seam. No design change.
