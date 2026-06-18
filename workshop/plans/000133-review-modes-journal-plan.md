# Review Modes + Journal Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring parley's document review to coding-agent parity — staged review *modes*, free-form instruction, no-marker general review, a faster ping-pong menu, and a self-contained durable per-round journal — so parley drives review independently.

**Architecture:** Reuse the existing skill stack (`skill_invoke` driver, `skill_assembly`, the disk provider's `source(ctx)` composition, marker parsing, `skill_render`) rather than adding a parallel engine (`ARCH-DRY`). A *mode* is a pure data object (frontmatter flags + prompt body) parsed from a sub-markdown file; the review skill's `source(ctx)` composes `SKILL.md ⊕ mode.body ⊕ flag-directives ⊕ instruction`. Edit history is a pure serialize/parse layer over a markdown sidecar, with a thin IO seam (`ARCH-PURE`). The composite menu is the only genuinely new UI, built on `float_picker`'s layout helpers.

**Tech Stack:** Lua (Neovim plugin runtime), plenary.nvim test harness (`make test`), `vim.diff` (unified diffs), `vim.fn.sha256` (drift hash). Unit tests in `tests/unit/` (pure, no nvim APIs), integration in `tests/integration/` (full runtime).

---

## Scope check

This is one feature (independent document review) with coupled parts that all hang off the `review` skill, so it's **one plan with four milestones**, not separate sub-plans. Each milestone produces working, testable software: M1 is exercisable through the existing `<C-g>s` picker before the M4 menu exists; M2 widens the run flow; M3 adds durable history; M4 adds the dedicated entry UX that ties it together.

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `Mode` | `lua/parley/skills/review/mode.lua` | new |
| mode prompt files (6) | `lua/parley/skills/review/modes/<name>.md` | new |
| `review.source` composition | `lua/parley/skills/review/init.lua` (`M.skill.source`) | modified |
| `journal` (serialize / parse / diff / drift-compare) | `lua/parley/skills/review/journal.lua` | new |

- **`Mode`** — a parsed mode definition: `{ name, scope, deletions, frontier, body }`. `mode.parse(content) -> Mode|nil,err` splits YAML frontmatter from the markdown prompt body and validates the three behavior flags.
  - **Relationships:** 1:1 with a `modes/<name>.md` file; N:1 with the `review` skill (one skill owns all modes).
  - **DRY rationale:** First occurrence of "skill behavior driven by a sub-file's frontmatter." Centralizes flag parsing/validation so the menu, the `source` composition, and the run-flow all read flags from one parser instead of re-scanning files. (`ARCH-DRY`)
  - **Future extensions:** New flags (e.g. `commit: on|off`, `agent:` override) add a column + a validator line; new modes are just new files — zero code change.

- **`journal`** — pure functions over journal text and round data. `serialize_entry(entry) -> string` (one markdown round section), `parse(text) -> { base, entries }`, `diff(old, new) -> string` (unified, via `vim.diff`), `is_drift(recorded_hash, current_content) -> bool` (compare `sha256(current)` to the last entry's stored hash).
  - **Relationships:** 1:1 with a doc (one sidecar per document); the journal *is* the round history.
  - **DRY rationale:** Single serialization format used by both the writer (append) and any reader ("show round N", drift check). (`ARCH-DRY`)
  - **Future extensions:** "revert to round N" = replay `base ⊕ diffs[1..N]` (a pure `reconstruct(base, diffs, n)` added here); decoration re-projection reads the stored decoration sets.

**Test surface (unit, no mocks):** `tests/unit/review_mode_spec.lua` (parse valid/invalid frontmatter, each flag default, body split, fenced-`---` safety); `tests/unit/review_journal_spec.lua` (serialize→parse round-trip, multi-round parse, `is_drift` true/false, `diff` shape).

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `mode.load` / `mode.list` | `lua/parley/skills/review/mode.lua` | new | filesystem (reads `modes/`) |
| `journal.append` / `journal.read` | `lua/parley/skills/review/journal.lua` | new | filesystem (sidecar) |
| `skill_dir` injection | `lua/parley/skill_providers.lua` (`manifest_from_def`) | modified | discovery-time dir fact |
| `review.run_via_invoke` flow | `lua/parley/skills/review/init.lua` | modified | orchestration (markers, submit, journal hook) |
| `skill_render` deletion gutter + dismiss | `lua/parley/skill_render.lua` | modified | nvim diagnostics / extmarks |
| `review_menu` (composite float) | `lua/parley/review_menu.lua` | new | nvim windows/buffers/keymaps |
| `<M-o>` / `<M-CR>` bindings | `keybinding_registry.lua`, `config.lua`, `skills/review/init.lua` | modified | nvim keymaps |

- **`mode.load(dir, name)` / `mode.list(dir)`** — read `<dir>/<name>.md` (or all) and hand the content to `mode.parse`. The IO seam; `mode.parse` stays pure.
  - **Injected into:** `review.source(ctx)` (which receives `ctx.skill_dir`) and `review_menu` (to list modes). Keeps composition + UI testable with literal mode strings.
- **`skill_dir` injection** — `manifest_from_def`'s `source` wrapper already injects `ctx.skill_md`; add `ctx.skill_dir = dir` (the same discovery-time fact) so a skill's `source` can reach its own `modes/` without re-deriving the path (`ARCH-DRY` — one injection point, mirrors `skill_md`).
- **`journal.append(path, entry)` / `journal.read(path)`** — read-parse-append-write the sidecar; serialization is pure.
  - **Injected into:** `review.run_via_invoke`'s `on_done` hook (after a successful apply).
- **`review_menu`** — the composite float: top = 6-mode selector (sticky-preselected), bottom = multi-line instruction buffer. Reuses `float_picker.compute_layout`. On submit, calls `review.run_via_invoke(buf, { mode, instruction })`.
  - **Injected into:** the `<M-o>` / `<M-CR>` keymaps.

**Test surface (integration, real runtime / fakes):** `tests/integration/review_mode_load_spec.lua` (load the 6 shipped files; `skill_dir` injection reaches `modes/`); `tests/integration/review_journal_io_spec.lua` (append creates sidecar, second append grows it, drift detection on external edit); `tests/integration/review_menu_spec.lua` (open returns mode list, sticky recall, submit passes `{mode,instruction}`). `run_via_invoke` flow changes are covered by extending `tests/unit/review_spec.lua` where pure (marker pre-check branches) and `tests/integration/skill_invoke_spec.lua` patterns where they touch the driver.

---

## Chunk 1: M1 — Modes engine

### Task 1.1: `Mode` pure parser

**Files:**
- Create: `lua/parley/skills/review/mode.lua`
- Test: `tests/unit/review_mode_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/review_mode_spec.lua
local mode = require("parley.skills.review.mode")

describe("review.mode.parse", function()
  it("splits frontmatter flags from body", function()
    local m = mode.parse(table.concat({
      "---", "name: developmental", "scope: whole-doc",
      "deletions: apply-with-gutter-why", "frontier: off", "---",
      "You are a developmental editor.", "Restructure freely.",
    }, "\n"))
    assert.are.equal("developmental", m.name)
    assert.are.equal("whole-doc", m.scope)
    assert.are.equal("apply-with-gutter-why", m.deletions)
    assert.are.equal("off", m.frontier)
    assert.are.equal("You are a developmental editor.\nRestructure freely.", m.body)
  end)

  it("defaults missing flags (markers-only / propose-strike / on)", function()
    local m = mode.parse("---\nname: x\n---\nbody")
    assert.are.equal("markers-only", m.scope)
    assert.are.equal("propose-strike", m.deletions)
    assert.are.equal("on", m.frontier)
  end)

  it("rejects an unknown flag value", function()
    local m, err = mode.parse("---\nname: x\nscope: sideways\n---\nb")
    assert.is_nil(m)
    assert.is_truthy(err:match("scope"))
  end)

  it("returns error when frontmatter is missing", function()
    local m, err = mode.parse("no frontmatter here")
    assert.is_nil(m)
    assert.is_truthy(err)
  end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

Run: `make test` (or the unit spec directly). Expected: FAIL — `module 'parley.skills.review.mode' not found`.

- [ ] **Step 3: Implement `mode.parse`**

```lua
-- lua/parley/skills/review/mode.lua
-- Mode — a review mode parsed from a modes/<name>.md sub-file:
-- YAML frontmatter (behavior flags) + markdown prompt body. PURE parser;
-- the disk reads (load/list) are the thin IO seam below. See issue #133.
local M = {}

local VALID = {
  scope = { ["whole-doc"] = true, ["markers-only"] = true },
  deletions = { ["apply-with-gutter-why"] = true, ["propose-strike"] = true, ["apply"] = true },
  frontier = { ["on"] = true, ["off"] = true },
}
local DEFAULT = { scope = "markers-only", deletions = "propose-strike", frontier = "on" }

--- Parse a mode file's content. PURE. Returns Mode | nil,err.
--- @param content string
--- @return table|nil mode, string|nil err
function M.parse(content)
  local fm_start, fm_end = content:find("^%-%-%-\n")
  if not fm_start then return nil, "mode: missing frontmatter (--- … ---)" end
  local close = content:find("\n%-%-%-\n?", fm_end)
  if not close then return nil, "mode: unterminated frontmatter" end
  local fm = content:sub(fm_end + 1, close)
  local body = content:sub((content:find("\n", close + 1) or #content) + 1)
  -- A modes file has only flat scalar keys; a minimal k: v scan is enough
  -- (no nesting, no lists) — we deliberately do NOT pull in a YAML lib.
  local flags = {}
  for line in fm:gmatch("[^\n]+") do
    local k, v = line:match("^(%w[%w_]*):%s*(.-)%s*$")
    if k then flags[k] = v end
  end
  if not flags.name or flags.name == "" then return nil, "mode: frontmatter needs a name" end
  local out = { name = flags.name, body = (body:gsub("%s+$", "")) }
  for key, default in pairs(DEFAULT) do
    local val = flags[key] or default
    if not VALID[key][val] then
      return nil, ("mode '%s': invalid %s=%s"):format(flags.name, key, tostring(val))
    end
    out[key] = val
  end
  return out
end

return M
```

- [ ] **Step 4: Run test, verify it passes**

Run: `make test`. Expected: PASS (4 examples).

- [ ] **Step 5: Commit**

```bash
git add lua/parley/skills/review/mode.lua tests/unit/review_mode_spec.lua
git commit -m "#133 M1: Mode pure parser (frontmatter flags + body)"
```

### Task 1.2: `mode.load` / `mode.list` IO seam

**Files:**
- Modify: `lua/parley/skills/review/mode.lua`
- Test: `tests/integration/review_mode_load_spec.lua`

- [ ] **Step 1: Write the failing integration test** — write two temp `modes/*.md` files to a temp dir, assert `mode.list(dir)` returns both parsed, sorted by name, and `mode.load(dir, "a")` returns the `Mode` for `a`. (Use `vim.fn.tempname()` + `vim.fn.mkdir`.)
- [ ] **Step 2: Run, verify fail** (`mode.list`/`mode.load` nil).
- [ ] **Step 3: Implement** the IO seam:

```lua
local function read(path)
  local f = io.open(path, "r"); if not f then return nil end
  local c = f:read("*a"); f:close(); return c
end

--- Load one mode by name from <dir>/<name>.md. IO seam over M.parse.
function M.load(dir, name)
  local c = read(dir .. "/" .. name .. ".md")
  if not c then return nil, "mode: no file for '" .. tostring(name) .. "'" end
  return M.parse(c)
end

--- List all valid modes under dir (skips files that fail to parse). IO seam.
function M.list(dir)
  local out = {}
  local h = vim.loop.fs_scandir(dir)
  if not h then return out end
  while true do
    local fname, typ = vim.loop.fs_scandir_next(h)
    if not fname then break end
    local base = fname:match("^(.+)%.md$")
    if base and typ ~= "directory" then
      local m = M.parse(read(dir .. "/" .. fname) or "")
      if m then table.insert(out, m) end
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end
```

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M1: mode load/list IO seam`).

### Task 1.3: Ship the six mode files

**Files:**
- Create: `lua/parley/skills/review/modes/developmental.md`, `line-editing.md`, `copy-editing.md`, `proofreading.md`, `fact-check.md`, `free-form.md`

- [ ] **Step 1:** Write each file = frontmatter (per the Spec table) + a prompt body. Flag values:

| file | scope | deletions | frontier |
|------|-------|-----------|----------|
| developmental | whole-doc | apply-with-gutter-why | off |
| line-editing | whole-doc | propose-strike | on |
| copy-editing | whole-doc | propose-strike | on |
| proofreading | whole-doc | apply | on |
| fact-check | whole-doc | propose-strike | on |
| free-form | whole-doc | propose-strike | off |

Each body states the editing brief for that stage and instructs use of the `propose_edits` tool (the base `SKILL.md` already covers marker grammar + the tool contract — bodies should *not* duplicate it; they add only the stage-specific brief, per `ARCH-DRY`). `fact-check.md` says: insert `🤖{finding}` markers only, make **no** edits — resolution is handed to the main agent.

- [ ] **Step 2: Test** — extend `tests/integration/review_mode_load_spec.lua`: `mode.list(<plugin>/lua/parley/skills/review/modes)` returns exactly 6, names match the table, no parse errors. (Resolve the plugin path via `nvim_get_runtime_file`.)
- [ ] **Step 3: Run, verify pass.**
- [ ] **Step 4: Commit** (`#133 M1: six review mode prompt files`).

### Task 1.4: `skill_dir` injection in the provider

**Files:**
- Modify: `lua/parley/skill_providers.lua:42-64` (`manifest_from_def` source wrapper)
- Test: `tests/integration/skill_providers_spec.lua` (extend)

- [ ] **Step 1: Write failing test** — a disk skill whose `source(ctx)` returns `ctx.skill_dir` yields the absolute dir.
- [ ] **Step 2: Run, verify fail** (`skill_dir` nil).
- [ ] **Step 3: Implement** — inject `ctx.skill_dir = dir` in `manifest_from_def`'s source wrapper (`skill_providers.lua:46-59`), alongside `skill_md`. **Two cares:** (1) the dir must be available even when no `SKILL.md` exists, so the injection can't be gated on `file_exists(dir.."/SKILL.md")` the way `skill_md` is — restructure so `skill_dir` is set whenever absent. (2) **Never mutate the caller's `ctx`** — the existing code is careful to clone into `enriched` before writing; preserve that (clone in *all* branches where you set `skill_dir`, including the no-SKILL.md case). Also confirm review's `source` is the **function** form (M1.5) so it takes the function branch where enrichment happens — the `elseif` SKILL.md-only branch (line 60) does no enrichment, so a skill relying on `skill_dir` must define `source` as a function.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M1: inject ctx.skill_dir at skill discovery`).

### Task 1.5: Compose mode into `review` skill `source`

**Files:**
- Modify: `lua/parley/skills/review/init.lua` (`M.skill` — add `source` + `args`)
- Test: `tests/unit/review_spec.lua` (extend) / `tests/integration/skill_invoke_spec.lua`

- [ ] **Step 1: Write failing test** — call `M.skill.source({ skill_md = "BASE", skill_dir = <tmp with modes/>, args = { mode = "developmental", instruction = "tighten intro" } })`; assert the result contains `BASE`, the developmental body, a rendered flag directive (e.g. "Scope: whole document"), and `tighten intro`.
- [ ] **Step 2: Run, verify fail** (`M.skill.source` nil — today review has no `source`, falling back to SKILL.md).
- [ ] **Step 3: Implement** `M.skill.source` (pure given ctx) + `args`:

```lua
M.skill.args = { {
  name = "mode", description = "review mode",
  complete = function()
    local dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
    local names = {}
    for _, m in ipairs(dir and require("parley.skills.review.mode").list(dir) or {}) do
      table.insert(names, m.name)
    end
    return names
  end,
} }

M.skill.source = function(ctx)
  ctx = ctx or {}
  local base = ctx.skill_md or ""
  local args = ctx.args or {}
  local parts = { base }
  if args.mode and ctx.skill_dir then
    local m = require("parley.skills.review.mode").load(ctx.skill_dir .. "/modes", args.mode)
    if m then
      table.insert(parts, "\n\n## Review mode: " .. m.name .. "\n" .. m.body)
      table.insert(parts, "\n\n" .. require("parley.skills.review.mode_directives")(m))
    end
  end
  if args.instruction and args.instruction ~= "" then
    table.insert(parts, "\n\n## Operator instruction\n" .. args.instruction)
  end
  return table.concat(parts)
end
```

  `mode_directives(m)` is a tiny pure helper (add to `mode.lua` as `M.directives` or a sibling) translating flags → prose the model obeys: `scope` → "Edit the whole document" vs "Confine edits to text referenced by markers"; `frontier=on` → the settled-region rule; `deletions` → apply-with-gutter-why vs propose-as-`🤖~old~{new}`. Unit-test `directives` separately (pure, table-driven).

- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M1: review skill composes mode body + flags + instruction`).

### M1 review boundary

- [ ] **DRY check (do this before milestone-close):** open each of the 6 mode files and confirm none restates the marker grammar / `propose_edits` tool contract that `skills/review/SKILL.md` already owns — this is the plan's single biggest DRY risk (`ARCH-DRY`). Bodies hold only the stage-specific editing brief.
- [ ] `sdlc milestone-close --issue 133 --milestone M1` — fix Critical/Important, log the `Review-Verdict:` outcome in `## Log`.

---

## Chunk 2: M2 — Flexible review flow

### Task 2.1: No-marker general review

**Files:**
- Modify: `lua/parley/skills/review/init.lua:476-484` (`run_via_invoke` pre-check)
- Test: `tests/integration/skill_invoke_spec.lua` (extend) / `tests/unit/review_spec.lua`

- [ ] **Step 1: Write failing tests** — (a) `run_via_invoke(buf, { mode = "developmental" })` on a buffer with **no markers** must NOT early-return "no markers"; it proceeds to invoke (assert via a stubbed `skill_invoke.invoke` capturing the call). (b) **The fact-check 0→N case** — a mode run that *inserts* markers (start with 0 markers, the stubbed apply adds `🤖{finding}`) must run exactly once and **stop** (NOT resubmit), and must not log "no progress — stopping" as if it were an error.
- [ ] **Step 2: Run, verify fail** (current code returns early at `#markers == 0`).
- [ ] **Step 3: Implement** — gate the no-marker abort on the *absence* of a selected mode: if `args.mode` is set, skip the `#markers == 0` early-return and proceed. Keep the legacy abort only for a bare marker-only run with no mode (preserves today's `<C-g>ve` behavior). **Resubmit-guard fix (the real case is 0→N, not 0→0):** today `marker_count_before` is captured at line 497 and the `on_done` follow-up resubmits while markers shrink, stopping via `#remaining >= marker_count_before` (line 525). A whole-doc mode round is **inherently one-shot**: with no starting markers, a round that *inserts* N markers (e.g. fact-check) would trip `#remaining(N) >= marker_count_before(0)` → "no progress — stopping", which is the *desired* stop but logged as a stuck-state. **Make resubmit gated on *ready-marker* progress only**: a mode run resubmits iff a ready `[]` marker remains *and* the ready-marker count shrank; a `{}`-only or zero-ready remainder ends the round cleanly (info log "round complete", not "no progress"). See Task 2.2 for the unified terminal logic.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M2: no-marker general review for mode runs`).

### Task 2.2: Submission decoupled from pending `{}`

**Files:**
- Modify: `lua/parley/skills/review/init.lua:485-493` (pending block) and the `on_done` follow-up (`529-542`)
- Test: `tests/integration/skill_invoke_spec.lua` / `tests/unit/review_spec.lua`

- [ ] **Step 1: Write failing test** — `run_via_invoke` on a buffer with a pending `🤖{agent asked}` marker (and at least one ready `[]`) must proceed to invoke, NOT early-return after populating quickfix.
- [ ] **Step 2: Run, verify fail** (current code returns at `#pending > 0`).
- [ ] **Step 3: Implement** — remove the submission-time pending-`{}` abort (the `if #pending > 0 then populate_quickfix; return` block at `init.lua:485-493`). The agent already skips non-ready markers (SKILL.md contract), so submission processes ready markers and leaves `{}` ones. Leave `scan_on_enter` / `BufWritePost` quickfix untouched — pending markers still surface **on save**. **Unified terminal logic for the `on_done` resubmit loop (`init.lua:529-542`)** — replace the current `has_questions` early-stop branch entirely. New rule, stated explicitly so the loop isn't left subtly wrong:
  - `#remaining == 0` → "round complete" (unchanged, line 516).
  - else compute `ready_remaining` (markers whose last section is `[]`). **Resubmit iff `ready_remaining > 0` AND the ready count shrank** (progress on actionable work), bounded by `resubmit_count < 3`.
  - else (only `{}` / unanswerable / non-shrinking ready remain) → **stop cleanly** with an info log; the pending `{}` surface via quickfix-on-save, NOT via a submission-time block. The old no-progress guard (`#remaining >= marker_count_before`) folds into "ready count shrank".
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M2: allow submission with unaddressed {} markers (quickfix on save only)`).

### Task 2.3: Deletion gutter-why + decoration ride/dismiss

**Files:**
- Modify: `lua/parley/skill_render.lua` (`attach_diagnostics`, add a deletion path; add `dismiss`)
- Modify: `lua/parley/skill_invoke.lua:39-50` (`render_propose_edits` — pass deletions through)
- Test: `tests/unit/skill_render_spec.lua` (extend)

- [ ] **Step 1: Write failing test** — for an edit whose `new_string` is empty (a deletion), `skill_render` attaches an INFO diagnostic at the deletion's join line carrying the `explain` ("deleting … because …"), even though there's no new text to highlight.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — in `render_propose_edits` (`skill_invoke.lua:39-50`), classify each edit: if `new_string == ""`, route to a new `skill_render.attach_deletion_diagnostic(buf, edit.pos, explain)` anchoring an INFO diagnostic at the deletion's join line. **Guard `highlight_edits` against empty `new_string`:** today it does `new_content:find(edit.new_string, 1, true)` (`skill_render.lua:59-77`); `find("")` returns 1, which would spuriously highlight line 0 — so `highlight_edits` must **skip** empty-`new_string` edits (they're handled by the deletion path). Additions/rewrites keep the existing highlight+diagnostic path. Confirm highlights use edit-tracking extmarks so they **ride** subsequent edits (behavior B); they are cleared only at the next round start (`clear_decorations`, already called at `invoke` start) — add an explicit `skill_render.dismiss(buf)` (alias of `clear_decorations`) for the manual dismiss binding.
- [ ] **Step 3b (cross-milestone coupling with M3.3): `render_propose_edits` must now RETURN the decoration set it built** (the `edits` list of `{pos, explain, new_string, kind=add|delete}`) instead of returning nothing. M3.3's journal entry needs this set, and M3.3 also requires `skill_invoke.invoke` to surface it (+ `original`/`new_content`) through `on_done` — see the M3.3 blocker note. Adding the return value here keeps that change localized.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M2: deletion gutter-why diagnostic + dismiss; decorations ride until next round`).

### M2 review boundary

- [ ] `sdlc milestone-close --issue 133 --milestone M2`.

---

## Chunk 3: M3 — Self-contained journal sidecar

### Task 3.1: `journal` pure serialize / parse / diff / drift

**Files:**
- Create: `lua/parley/skills/review/journal.lua`
- Test: `tests/unit/review_journal_spec.lua`

- [ ] **Step 1: Write failing tests**

```lua
local J = require("parley.skills.review.journal")
describe("review.journal", function()
  it("serialize→parse round-trips an entry", function()
    local e = { round = 1, ts = "2026-06-17T10:00:00", mode = "copy editing",
                side = "agent", diff = "@@ -1 +1 @@\n-a\n+b", hash = "deadbeef",
                explains = { "fixed typo" }, decorations = {} }
    local parsed = J.parse(J.serialize_entry(e))
    assert.are.equal(1, parsed.entries[1].round)
    assert.are.equal("copy editing", parsed.entries[1].mode)
    assert.are.equal("deadbeef", parsed.entries[1].hash)
  end)
  it("parses multiple rounds in order", function() ... end)
  it("is_drift true when current content's hash differs from last entry", function()
    assert.is_true(J.is_drift("aaa", "content-hashing-to-bbb"))   -- via injected hasher in test
    assert.is_false(J.is_drift(vim.fn.sha256("x"), "x"))
  end)
end)
```

- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — markdown sections per round (`## Round N — <mode> (<side>) <ts>`, a `### Rationale` list, a fenced ```diff block, an HTML-comment metadata line `<!-- parley-journal: hash=… -->` for machine fields incl. the serialized decoration set). `parse` reads sections back. `diff(old,new) = vim.diff(old,new,{result_type="unified"})`. `is_drift(recorded_hash, current) = recorded_hash ~= vim.fn.sha256(current)`. Keep `serialize_entry`/`parse`/`is_drift`/`diff` pure (no file IO).
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M3: pure journal serialize/parse/diff/drift`).

### Task 3.2: `journal.append` / `journal.read` IO + base snapshot

**Files:**
- Modify: `lua/parley/skills/review/journal.lua`
- Test: `tests/integration/review_journal_io_spec.lua`

- [ ] **Step 1: Write failing test** — `append(sidecar_path, base_content, entry)` creates `<doc>.parley-journal.md` with a base snapshot (round 0) + round 1; a second `append` grows it to round 2 without rewriting base; `read(path)` returns `{ base, entries }`; `is_drift` against an externally-mutated doc returns true.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — `sidecar_path(doc_path)` = `doc_path .. ".parley-journal.md"`. `append` reads existing (if any), writes base on first call, appends the serialized entry. `read` loads + `parse`. Thin IO over the pure layer.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M3: journal sidecar IO (append/read, base snapshot)`).

### Task 3.3: Wire journal into the review round

**Files:**
- Modify: `lua/parley/skills/review/init.lua` (`run_via_invoke` `on_done`)
- Test: `tests/integration/review_journal_io_spec.lua` (extend) — drive a fake round

> **⚠ Contract fix (caught in plan review):** `skill_invoke.invoke`'s `on_done` today passes **only** `{ ok, applied, calls, results }` (`skill_invoke.lua:190-192`). It does **NOT** expose `original`, `new_content`, or the decoration set — those are locals (`skill_invoke.lua:103,174`) that never escape, and `render_propose_edits` returns nothing. So Step 3a below is **required prep**: widen the driver's `on_done` payload. Do NOT assume the data is already there.

- [ ] **Step 1: Write failing tests** — (a) `tests/integration/skill_invoke_spec.lua`: after a run, the `on_done` payload carries `original`, `new_content`, and `decorations`. (b) `tests/integration/review_journal_io_spec.lua`: after a successful `on_done` (stub the driver to apply a known edit + return the widened payload), a sidecar exists beside the doc with a round whose `mode`, `diff` (original→new), and `explains` (from the `propose_edits` calls) match.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3a (driver prep): widen `skill_invoke.invoke`'s `on_done` payload** — add `original = original`, `new_content = new_content`, and `decorations = <set returned by render_propose_edits>` (M2.3 Step 3b makes it return the set) to the `opts.on_done({...})` call at `skill_invoke.lua:190-192`. Pure-fed: the hook never re-reads the buffer.
- [ ] **Step 3b: build + append the entry** — in review's `on_done`, on `result.ok`, build: `mode = args.mode`, `side = "agent"`, `diff = journal.diff(result.original, result.new_content)`, `explains` from `result.calls` propose_edits inputs, `hash = vim.fn.sha256(result.new_content)`, `ts = os.date("!%Y-%m-%dT%H:%M:%S")`, `decorations = result.decorations`. Call `journal.append`. Skip journaling gracefully when the doc has no path. (No git, no branch — `ARCH-PURE`: the round's data is computed pure and handed to one thin `append`.)
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M3: append a journal round after each review apply`).

### M3 review boundary

- [ ] `sdlc milestone-close --issue 133 --milestone M3`.

---

## Chunk 4: M4 — Composite review menu + bindings

### Task 4.1: `review_menu` composite float

**Files:**
- Create: `lua/parley/review_menu.lua`
- Test: `tests/integration/review_menu_spec.lua`

- [ ] **Step 1: Write failing test** — `review_menu.open(buf, { on_submit = cb })` opens two windows (a mode-list results buffer + a multi-line `buftype=""` instruction buffer); the mode list contains the 6 mode names; the last-used mode is pre-selected (set via a prior submit / injected recall); invoking submit calls `cb({ mode = <selected>, instruction = <typed> })`.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3a: export the layout helper** — `float_picker.compute_layout` is currently **module-local** (`local function compute_layout`, `float_picker.lua:504`), not on `M`. Add `M.compute_layout = compute_layout` so `review_menu` reuses the geometry instead of duplicating it (`ARCH-DRY`). Cover with a one-line assertion that `float_picker.compute_layout` is callable.
- [ ] **Step 3b: implement** — reuse `float_picker.compute_layout` for geometry. Top = results window listing `mode.list(<modes dir>)` names, current selection highlighted, `j/k` to move; bottom = a normal modifiable buffer (`buftype=""`, several rows) for free-form instruction (full vim editing). Sticky mode via a module-level `_last_mode` (session recall; cross-session persistence is v2). Submit (`<CR>`/`<M-CR>`) closes and calls `on_submit({mode, instruction})`; free-form mode requires non-empty instruction (refuse + warn otherwise). Esc cancels. Keep this the *only* new UI; do not fold logic the pure layers own.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M4: composite review menu (mode selector + instruction editor)`).

### Task 4.2: `<M-o>` / `<M-CR>` bindings + wiring

**Files:**
- Modify: `lua/parley/keybinding_registry.lua` (add `review_menu` + `review_next` entries), `lua/parley/config.lua` (shortcut defaults), `lua/parley/skills/review/init.lua` (`setup_keymaps`)
- Test: `tests/integration/review_menu_spec.lua` (extend) — assert keymaps set on a markdown buffer

- [ ] **Step 1: Write failing test** — opening a markdown review doc sets buffer-local `<M-o>` (open menu) and `<M-CR>` (open menu pre-selected to sticky mode, then run). Assert via `nvim_buf_get_keymap`.
- [ ] **Step 2: Run, verify fail.**
- [ ] **Step 3: Implement** — add `config.review_shortcut_menu = { modes = {"n"}, shortcut = "<M-o>" }` and `config.review_shortcut_next = { modes = {"n","i"}, shortcut = "<M-CR>" }`. **Follow the existing `review_edit` pattern** (`keybinding_registry.lua:691` is `help_only=true`, registered "by review skill"; the actual `vim.keymap.set` lives in `setup_keymaps`, `init.lua:2089`): add `help_only=true` registry entries for help output, and do the real buffer-local binding in `setup_keymaps` — do NOT route through the generic `register_buffer` path. Bind `<M-o>` → `review_menu.open(buf, { on_submit = run })` and `<M-CR>` → open menu pre-selected to sticky mode (same callback). Both call `review.run_via_invoke(buf, { mode, instruction })`. `<M-CR>` "always works" — opens the menu even on a doc not yet in review (no session gate). Verified free: `<M-CR>` chat-respond is `chat`-scope (markdown buffers register only `{parley_buffer, markdown}`), and `<M-o>` is unbound today.
- [ ] **Step 4: Run, verify pass.**
- [ ] **Step 5: Commit** (`#133 M4: <M-o>/<M-CR> review menu bindings + sticky mode`).

### Task 4.3: Manual end-to-end verification

- [ ] **Step 1:** In a real nvim on a scratch markdown doc with no markers: `<M-o>` → pick **developmental** + type "expand these bullets into prose" → confirm whole-doc edits land, highlighted, with gutter explanations; confirm a `<doc>.parley-journal.md` sidecar appears with round 1 (mode, diff, rationale).
- [ ] **Step 2:** Add a `🤖[tighten this]` marker + a pending `🤖{question}`; `<M-CR>` → confirm menu pre-selected to last mode, run proceeds despite the pending `{}`; save → confirm the pending `{}` surfaces in quickfix.
- [ ] **Step 3:** Pick **proofreading** on a doc with a typo → confirm the deletion/replacement applies with a gutter "why"; pick **copy editing** → confirm a deletion shows as a `🤖~old~{new}` strike for accept/reject.
- [ ] **Step 4:** Pick **fact-check** → confirm only `🤖{finding}` markers are inserted, no edits.
- [ ] **Step 5:** Edit one region after a round → confirm decorations elsewhere persist (ride). Document the outcomes in `## Log`.

### M4 review boundary + close

- [ ] `sdlc milestone-close --issue 133 --milestone M4`.
- [ ] `sdlc close --issue 133 --verified '<evidence: make test green + manual e2e per Task 4.3>'` (let close compute `--actual`; update `atlas/` for the review-modes + journal surface and **link the new entries from `atlas/index.md`** per the constitution — note `atlas/modes/` already exists for an unrelated concept, so name the new surface to avoid conceptual collision, e.g. `atlas/.../review-modes.md`).

---

## Notes / risks

- **`ARCH-DRY`:** the modes engine adds *no* new driver — it rides `skill_invoke` + the provider's `source(ctx)` composition (mirrors `voice_apply`). Mode bodies must not restate the marker grammar/tool contract the base `SKILL.md` owns.
- **`ARCH-PURE`:** `Mode`, `journal` (serialize/parse/diff/drift), and `mode_directives` are pure and unit-tested without mocks; IO is the thin `load`/`list`/`append`/`read` seam and the menu. The journal round is computed pure and handed to one `append`.
- **Risk — frontmatter parser:** the minimal `k: v` scan (no YAML lib) is deliberate but must not choke on a `---` inside a body; `parse` keys off the *leading* `---\n` only. Covered by a test.
- **Risk — resubmit loop with whole-doc modes:** a zero-marker mode round must not trip the no-progress guard. Explicit test in Task 2.1.
- **Deferred (v2, out of scope):** active in-buffer undo-projection of past-round decorations; cross-session sticky mode; "revert/show round N" (the journal stores base+diffs+decoration sets to make these clean future adds).
