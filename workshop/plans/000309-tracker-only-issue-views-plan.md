# Tracker-only Issue Views Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tracker cards without local details appear in the Issue Finder as amber
"card only · read only" rows and open in a read-only scratch view of the card,
with an honest freshness line, on top of #308's tracker reader.

**Architecture:** Pure additions in `parley.issue_cards`: keep the card body,
synthesize card-only finder records, and render the card view and its freshness
line. `parley.issue_tracker` gains a first-fetch bootstrap and a per-root fetch
status. The finder merges card-only records next to the disk-scanned records,
keyed by (repo root, id). A new IO module, `parley.issue_card_view`, owns the
scratch buffer. Mutation paths (finder delete and cycle-status, `:ParleyIssueStatus`,
`:ParleyIssueDecompose`) refuse card-only targets with a message.

**Tech Stack:** Lua (Neovim 0.10+), plenary busted, real git through
`tests/helpers/tracker_repo.lua` (a bare remote plus writer and reader clones).

---

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_card` (keeps `body`) | `lua/parley/issue_cards.lua` | modified |
| `card_ref` | `lua/parley/issue_cards.lua` | new |
| `card_only_records` | `lua/parley/issue_cards.lua` | new |
| `freshness` | `lua/parley/issue_cards.lua` | new |
| `view_lines` | `lua/parley/issue_cards.lua` | new |
| `render` (card-only label) | `lua/parley/issue_finder_records.lua` | modified |

- **parse_card**: now also returns `body`, the card text after the closing
  `---` (the H1, `## Problem` and anything else the card carries). The cache
  stays bounded by the tracker's card count because `read` prunes blobs to the
  current tree on every load (ARCH-FUNERAL; no new cache).
- **card_ref(root, id)** → `"parley-card://" .. root .. "#" .. id`. It is the
  finder row's `value`, the identity key, and the scratch buffer name, so opening
  a card twice reuses one buffer (ARCH-DRY: one name for one thing).
- **card_only_records(cards, local_ids, opts)** → finder records for every card
  whose id is not in `local_ids`. `opts = { root, repo_name, is_terminal }`.
  Record: `{ id, title, slug = "", status, created, updated, github_issue,
  deps = {}, card_only = true, card_root = root, archived = is_terminal(status),
  mtime = <epoch of updated, else 0>, path = nil, identity = { key = card_ref,
  source = { root_ordinal = 0, unresolved = card_ref } } }`.
  - **Relationships:** 1 record per card id with no details file; N:1 with repo root.
  - **DRY rationale:** the finder's `materialize`, filter, sort and dedupe run
    unchanged on these records. There is no second list or code path.
  - **Join rule:** `local_ids` covers the details ids in **both** the issues and
    history dirs of that repo. A card whose details were archived is not card-only.
- **freshness(status)** → one line of text (times via `os.date`, so the tests build epochs with `os.time`). Cases:
  - `fetched HH:MM`: the last fetch succeeded and nothing failed since.
  - `cached · last fetch failed HH:MM: <first stderr line>`: a fetch failed after
    the last success, or no fetch has succeeded yet. This never claims a fetch
    succeeded.
  - `local ref · not fetched yet`: no attempt has been made (fetch disabled or throttled).
  - Each case gains ` · refreshing…` while a fetch is running.
- **view_lines(card, id, status)** → `{ lines, label_rows }` (`card` may be nil). Layout:
  ```
  card only · read only — <ref> @ <tip7> · <freshness>
  Details for #<id> are not in this checkout (they may be on another branch).
  Card fields are sdlc's to change: `sdlc issue set-status`, `sdlc claim`.

  status: … / created: … / updated: … / github_issue: … / estimate_hours: …
  (top-level card fields, the `tracker:` envelope omitted)

  <card body: H1, ## Problem, …>
  ```
  If the card is missing from the tip, the body becomes one line: `Card #<id> is
  no longer on <ref>.` Nothing is fabricated: no Spec or Plan headings and no
  local file.
- **render**: card-only rows show `card only · read only` after the id. Those
  bytes get the `ParleyIssueTracker` (amber) highlight, so the provenance is
  readable text, not only colour. `search_text` includes `card only`.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `issue_tracker.refresh` (bootstrap) | `lua/parley/issue_tracker.lua` | modified | `git fetch` |
| `issue_tracker.status` | `lua/parley/issue_tracker.lua` | new | in-memory fetch state |
| `issue_card_view` | `lua/parley/issue_card_view.lua` | new | Neovim scratch buffer |
| `issue_finder` card rows + refusals | `lua/parley/issue_finder.lua` | modified | picker, `uv.fs_scandir` |
| `refuse_card_only` | `lua/parley/issues.lua` | new | buffer-scoped issue commands |
| `tracker_repo` fixture | `tests/helpers/tracker_repo.lua` | modified | real git |

- **refresh / bootstrap.** When a load found no tracker ref (`st.remote` nil),
  refresh resolves the remote the same way the reader does:
  `select_remote(<upstream remote>, <git remote list>)`. It then fetches with an
  explicit refspec, `+refs/heads/<tracker>:refs/remotes/<remote>/<tracker>`. The
  explicit refspec is used on every fetch, so a single-branch clone works too.
  After a successful fetch the existing `read` runs; a moved tip (nil → oid)
  notifies subscribers. Throttling is unchanged: `fetched_at` stamps attempts.
  The status fields are `fetch_ok_at` and `fetch_failed_at`/`fetch_error`, in
  wall-clock seconds via `os.time()`.
- **status(root)** → `{ ref, tip, fetching, fetch_ok_at, fetch_failed_at, fetch_error }`,
  or nil when the root is untracked or not loaded. In-memory, with one entry per
  root already held in `states`, so there is nothing new to collect.
- **issue_card_view.open(root, id)**: reuses or creates the buffer named
  `card_ref(root, id)` with `buftype=nofile`, `bufhidden=wipe`, `swapfile=false`,
  `modifiable=false`, `readonly=true`, `filetype=markdown`, and
  `b.parley_card_only = { root, id }`. Renders `view_lines` and paints label
  rows amber via an extmark `hl_group`. It subscribes to the tracker
  (`alive = buffer valid`), loads, then refreshes; `on_settled` re-renders the
  freshness line. ARCH-FUNERAL: the buffer wipes when hidden, and its subscriber
  drops on the next notify.
- **issue_finder.** After cards arrive for a root, compute `local_ids` by
  scanning `<root>/<issues_dir>` and `<root>/<history_dir>` filenames with
  `uv.fs_scandir`. These are two directory listings per delivery, not per
  keystroke; the cost is that listing. Merge
  `card_only_records(...)` into the record list before `materialize`. On select
  of a card-only row → `issue_card_view.open`. The delete and cycle-status keys
  on card-only rows warn `#<id> is a tracker card without local details (read
  only)` and do nothing.
- **refuse_card_only.** `cmd_issue_status` and `cmd_issue_decompose` return early
  with the same warning when `vim.b.parley_card_only` is set.
- **Fixture.** `card_text` accepts an optional `problem`, written under
  `## Problem`. `create(cards, details)` gets an explicit `details[name] == false`
  branch, meaning "no details file on main" (today's `or fields` fallback would
  swallow `false`). A details override may carry `dir = "workshop/history/issues"`
  to place the file in the history dir. `M.details_on_branch(repos, branch, name,
  fields)` commits a details file on another branch of the writer and pushes it.

## Tasks

### Task 1: pure card model (issue_cards)

**Files:** Modify `lua/parley/issue_cards.lua`; Test `tests/unit/issue_cards_spec.lua`

- [ ] Failing tests:
  - `parse_card` returns `body` beginning `# Title` and containing `## Problem\nText`.
  - `card_only_records` skips ids in `local_ids`, marks a `done` card
    `archived` via the injected `is_terminal`, sets `card_only`, `value`-ready
    identity key `parley-card://<root>#<id>`, and `mtime` from `updated`
    (`2026-09-01` → `os.time{year=2026,month=9,day=1,hour=12}`).
  - `freshness`: ok only → `fetched 10:00`; failed after ok →
    `cached · last fetch failed 10:05: fatal: x`; never → `local ref · not fetched yet`;
    fetching → suffix ` · refreshing…` (fixed `os.date` input via injected epoch).
  - `view_lines`: label row 1 contains `card only · read only`, `origin/issue-tracker @ abc1234`;
    no `tracker:`/`version:` lines; the body is included verbatim; a missing
    card gives `Card #000005 is no longer on origin/issue-tracker.`; there is no
    `## Spec` or `## Plan` unless the card body has one.
- [ ] Run `make test-spec SPEC=issues/issue-management` (or
  `PlenaryBustedFile tests/unit/issue_cards_spec.lua`): FAIL.
- [ ] Implement:

```lua
-- parse_card: after computing `close`
local body = table.concat(vim.list_slice(lines, close + 1), "\n"):gsub("^\n+", "")
return { id = fields.id, title = title, fields = fields, body = body }

M.card_ref = function(root, id)
    return "parley-card://" .. root .. "#" .. id
end

local function epoch(date)
    local y, m, d = tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    return y and os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) or 0
end

M.card_only_records = function(cards, local_ids, opts)
    local out = {}
    for id, card in pairs(cards or {}) do
        if not local_ids[id] then
            local ref = M.card_ref(opts.root, id)
            local f = card.fields
            out[#out + 1] = {
                id = id, title = card.title, slug = "", deps = {},
                status = f.status, created = f.created, updated = f.updated,
                github_issue = not blank(f.github_issue) and f.github_issue or nil,
                card_only = true, card_root = opts.root, repo_name = opts.repo_name,
                archived = opts.is_terminal(f.status) == true, mtime = epoch(f.updated),
                identity = { key = ref, source = { root_ordinal = 0, unresolved = ref } },
            }
        end
    end
    return out
end

local function clock(t) return os.date("%H:%M", t) end

M.freshness = function(status)
    local text
    if status.fetch_failed_at and (not status.fetch_ok_at or status.fetch_failed_at >= status.fetch_ok_at) then
        text = "cached · last fetch failed " .. clock(status.fetch_failed_at)
            .. ": " .. ((status.fetch_error or ""):match("[^\n]+") or "unknown error")
    elseif status.fetch_ok_at then
        text = "fetched " .. clock(status.fetch_ok_at)
    else
        text = "local ref · not fetched yet"
    end
    return status.fetching and (text .. " · refreshing…") or text
end

M.view_lines = function(card, id, status)
    local ref = status.ref or "issue-tracker"
    local lines = {
        "card only · read only — " .. ref .. (status.tip and (" @ " .. status.tip:sub(1, 7)) or "")
            .. " · " .. M.freshness(status),
        "Details for #" .. id .. " are not in this checkout (they may be on another branch).",
        "Card fields are sdlc's to change: `sdlc issue set-status`, `sdlc claim`.",
        "",
    }
    if not card then
        lines[#lines + 1] = "Card #" .. id .. " is no longer on " .. ref .. "."
        return { lines = lines, label_rows = { 0 } }
    end
    for _, key in ipairs({ "status", "created", "updated", "github_issue", "estimate_hours" }) do
        if card.fields[key] ~= nil then
            lines[#lines + 1] = key .. ": " .. card.fields[key]
        end
    end
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(card.body or "", "\n", { plain = true }))
    return { lines = lines, label_rows = { 0 } }
end
```

  (`freshness` is pure: the caller passes the status; the tests pin `os.date`
  output by building epochs with `os.time` in local time.)
- [ ] Tests PASS; commit `#309: issue_cards: card body, card-only records, card view text`.

### Task 2: card-only row label (issue_finder_records)

**Files:** Modify `lua/parley/issue_finder_records.lua:116-155`; Test `tests/unit/issue_finder_records_spec.lua`

- [ ] Failing test: `render({ card_only = true, id = "000005", status = "open", title = "T", slug = "" })`
  display contains `[open] 000005 card only · read only T`; highlights contain
  exactly one span covering `card only · read only` with `ParleyIssueTracker`;
  `search_text` contains `card only`.
- [ ] Implement inside `render`, after the id:
  `if issue.card_only then append("card only · read only", "card_only"); append(" ") end`,
  with `stale.card_only` treated as always-on: `local stale = vim.tbl_extend("force", issue.tracker_stale or {}, { card_only = issue.card_only or nil })`.
  Append `card only` to `search_text` for card-only rows.
- [ ] PASS; commit `#309: finder rows label card-only issues`.

### Task 3: tracker bootstrap fetch + fetch status

**Files:** Modify `lua/parley/issue_tracker.lua:235-260`, `tests/helpers/tracker_repo.lua`; Test `tests/integration/issue_tracker_spec.lua`

- [ ] Fixture: `card_text` writes `"## Problem", "", fields.problem` when given;
  `create` skips details whose override is exactly `false` (explicit branch, not
  `or`), writes an override with `dir` under that dir instead of `workshop/issues`;
  add `details_on_branch`.
- [ ] Failing tests (real git):
  - **bootstrap:** `update-ref -d refs/remotes/origin/issue-tracker` in the reader;
    `load` → nil; `refresh` → settles; `load` now returns both cards; a subscriber
    registered before the refresh was notified once.
  - **success status:** after a refresh, `status(root)` has `fetch_ok_at`, no
    `fetch_failed_at`, `ref == "origin/issue-tracker"`, and a `tip` of 40 hex characters.
  - **failure status:** `git remote set-url origin <base>/missing.git`, refresh →
    cards from `load` unchanged, `status.fetch_failed_at` set, `fetch_error` non-empty,
    `fetch_ok_at` nil (never claims freshness).
- [ ] Implement: keep `fetched_at` as the throttle stamp; add a remote resolver.

```lua
local function resolve_remote(root, st, done)
    if st.remote then return done(st.remote) end
    git(root, { "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}" }, {}, function(has_upstream, upstream)
        git(root, { "remote" }, {}, function(ok, out)
            local remotes = ok and vim.split(vim.trim(out), "\n", { trimempty = true }) or {}
            done(issue_cards.select_remote(has_upstream and upstream:match("^([^/\n]+)/") or nil, remotes))
        end)
    end)
end
```

  `refresh`: drop `not st.remote` from the early return. Set `st.fetching`, then
  `resolve_remote`; if nil, clear `fetching` and settle. Otherwise fetch
  `{ "fetch", "--quiet", "--no-tags", "--no-write-fetch-head", remote,
  "+refs/heads/" .. found.tracker .. ":refs/remotes/" .. remote .. "/" .. found.tracker }`.
  `fetched_at` (throttle) and `fetching` are set **before** `resolve_remote`, so the
  bootstrap path is throttled and concurrent refreshes coalesce. On failure:
  `st.fetch_failed_at, st.fetch_error = os.time(), err`. On success:
  `st.fetch_ok_at = os.time()`, clear `fetch_failed_at`/`fetch_error` (same-second
  stamps would otherwise keep reporting the failure), set a provisional
  `st.remote = remote` so `status()` names the ref while the read runs, then `read`.
  `M.status = function(root) local st = states[root]; if not st or not st.remote and not st.fetch_failed_at then return nil end; return { ref = st.remote and (st.remote .. "/" .. (discovery() or {}).tracker) or nil, tip = st.tip, fetching = st.fetching == true, fetch_ok_at = st.fetch_ok_at, fetch_failed_at = st.fetch_failed_at, fetch_error = st.fetch_error } end`.
  Update the existing throttle test's git-call counts if `remote` is now called.
- [ ] PASS (`tests/integration/issue_tracker_spec.lua` whole file); commit
  `#309: issue_tracker: first-fetch bootstrap and fetch status`.

### Task 4: card view (scratch buffer)

**Files:** Create `lua/parley/issue_card_view.lua`; Modify `lua/parley/issues.lua` (`refuse_card_only`
in `cmd_issue_status`, `cmd_issue_decompose`); Test `tests/integration/issue_card_view_spec.lua`

- [ ] Failing tests (fixture with `000005` card-only, `problem = "Why it matters"`):
  - `open(reader, "000005")` → current buffer named `parley-card://<reader>#000005`,
    `buftype == "nofile"`, `modifiable == false`, `readonly == true`; line 1 has
    `card only · read only` and `origin/issue-tracker @`; a line equals `## Problem`
    and one `Why it matters`; an extmark on row 0 has `hl_group == "ParleyIssueTracker"`.
  - opening again reuses the buffer (same bufnr).
  - `require("parley.issues").cmd_issue_status()` and `cmd_issue_decompose()` (the
    refusal runs before any cursor check, so the cursor position is irrelevant)
    each leave the lines unchanged and log the read-only warning (logger stub).
  - spec setup: `before_each` sets `issue_tracker.fetch_enabled = true`,
    `fetch_interval_s = 0` and `reset_for_tests()`; `after_each` restores 60 / false.
  - a writer pushes a new status for `000005`; `refresh` → the view's `status:` line updates.
  - remote URL broken → refresh → content kept, line 1 contains `last fetch failed`.
- [ ] Implement:

```lua
local issue_cards = require("parley.issue_cards")
local issue_tracker = require("parley.issue_tracker")
local M = {}
M.NS = vim.api.nvim_create_namespace("parley_issue_card_view")

local function render(buf, root, id, cards)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local view = issue_cards.view_lines(cards and cards[id], id, issue_tracker.status(root) or {})
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, view.lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
    vim.api.nvim_buf_clear_namespace(buf, M.NS, 0, -1)
    for _, row in ipairs(view.label_rows) do
        vim.api.nvim_buf_set_extmark(buf, M.NS, row, 0, {
            end_row = row, end_col = #view.lines[row + 1], hl_group = issue_cards.HIGHLIGHT,
        })
    end
end

M.open = function(root, id)
    issue_tracker.ensure_highlight()
    local name = issue_cards.card_ref(root, id)
    local buf = -1
    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
        -- exact match: bufnr() treats its argument as a file pattern
        if vim.api.nvim_buf_get_name(candidate) == name then buf = candidate end
    end
    local fresh = buf == -1
    if fresh then
        buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(buf, name)
        for option, value in pairs({ buftype = "nofile", bufhidden = "wipe", swapfile = false,
            filetype = "markdown", modifiable = false, readonly = true }) do
            vim.bo[buf][option] = value
        end
        vim.b[buf].parley_card_only = { root = root, id = id }
    end
    vim.api.nvim_set_current_buf(buf)
    local cards
    local function show(next_cards)
        cards = next_cards or cards
        render(buf, root, id, cards)
    end
    if fresh then
        issue_tracker.subscribe(root, { notify = show, alive = function() return vim.api.nvim_buf_is_valid(buf) end })
    end
    issue_tracker.load(root, function(loaded)
        show(loaded)
        issue_tracker.refresh(root, function() show(nil) end)
        show(nil) -- refresh has set `fetching`: paint "refreshing…"
    end)
    return buf
end

return M
```

  In `issues.lua`, add near `can_use_issue_actions`:

```lua
-- The text only: each caller logs through its own _parley (the finder spec
-- injects a fake whose logger must see it).
M.card_only_warning = function(id)
    return "#" .. id .. " is a tracker card without local details (read only)"
end

local function refuse_card_only()
    local card = vim.b.parley_card_only
    if not card then return false end
    _parley.logger.warning(M.card_only_warning(card.id))
    return true
end
```

  and `if refuse_card_only() then return end` first in `cmd_issue_status` and `cmd_issue_decompose`.
- [ ] PASS; commit `#309: read-only card view for issues without local details`.

### Task 5: finder card-only rows, open, refusals

**Files:** Modify `lua/parley/issue_finder.lua:372-392, 536-607, 642-672`; Test `tests/integration/issue_finder_tracker_spec.lua`

- [ ] Test harness: `open_finder` passes **absolute** fixture dirs
  (`issues_dir = reader .. "/workshop/issues"`, `history_dir = reader ..
  "/workshop/history/issues"`); a relative `history_dir` would resolve through
  the real parley's `project_root()` to this repository.
- [ ] Failing tests (fixture: `000001` with details, `000005` card-only open card with
  details committed only on writer branch `000005-x`, `000009` card `done` whose
  details live in `workshop/history/issues` on main via the `dir` override):
  - issues view: exactly one row per id; `000005` row has `issue.card_only`, display
    contains `card only · read only`, value `parley-card://<reader>#000005`; no
    `000009` row; `000001` row is not card-only and its value is its path.
  - history view (`view_mode = 1`): `000009` appears exactly once, as its local
    details row (not `card_only`). This is the assertion that tests the join; the
    issues view hides `000009` anyway because a `done` card is archived.
  - a card `000011` (`done`, no details anywhere) appears only in the history view.
  - search/filter/sort: `000005`'s search text contains its title and `card only`;
    with `000001` (`wontfix` card) and `000002` (`open`, details) present, the issues
    view orders exactly `000002, 000005, 000001` (open by id, then wontfix); in a
    super-repo fake with two repo facets, where the second repo is untracked (no
    marker, so it yields no card rows), toggling the fixture's facet off hides `000005`.
  - untracked repo (existing case at `issue_finder_tracker_spec.lua:137`): no row has `card_only`.
  - `on_select` with the `000005` row opens the card view (current buffer name is the ref).
  - delete and cycle-status mappings on `000005` write nothing and warn (logger stub).
  - bootstrap: reader with the tracker ref deleted → the finder still shows `000005`
    after its refresh fetch.
- [ ] Implement:
  - `local function local_ids(root)`: union of ids (`^(%d+)%-`) from
    `uv.fs_scandir` of the issues and history dirs, resolved like
    `resolve_against_git_root` (absolute config wins; else `root .. "/" .. rel`).
  - `overlay_cards(records)` → after the overlay, append for every root in
    `cards_by_root`: `issue_cards.card_only_records(cards, local_ids(root), { root =
    root, repo_name = repo_name_of_root[root], is_terminal = function(s) local v =
    issue_vocabulary.default(); return v and v:is_terminal(s) end })`.
    `repo_name_of_root` is filled in the subscribe loop from `root.repo_name`.
  - `render_issue`: `row.value = issue.card_only and issue_cards.card_ref(issue.card_root, issue.id) or issue.path`.
  - `local issue_vocabulary = require("parley.issue_vocabulary")` at the top of
    `issue_finder.lua` (it is not required there today).
  - `on_select`: the card-only branch goes **after** `nvim_set_current_win(source_win)`,
    so the card buffer lands in the source window, not the picker's:
    `if item.issue and item.issue.card_only then require("parley.issue_card_view").open(item.issue.card_root, item.issue.id) return end`.
  - delete + cycle-status mappings: `if item.issue and item.issue.card_only then _parley.logger.warning(issues_mod.card_only_warning(item.issue.id)) return end`
    (one text, each caller logs through its own `_parley`, ARCH-DRY).
  - `local_ids`: comment that it builds dirs from config relative to the Git root,
    which matches the super-repo `expand_roots` dirs for relative config (today's case).
- [ ] PASS; full `make test`; commit `#309: issue finder shows tracker-only cards`.

### Task 6: atlas + verification

- [ ] `atlas/issues/issue-management.md`: a "Tracker-only cards" paragraph covering the
  card-only rows, card view, freshness line, bootstrap fetch and refusals; add
  `tests/integration/issue_card_view_spec.lua` to `atlas/traceability.yaml`.
- [ ] Live check in this repo: `:ParleyIssueFinder` shows `#305` as card-only; opening
  it shows its card and `origin/issue-tracker @`.
- [ ] Commit `#309: atlas: tracker-only cards`.
