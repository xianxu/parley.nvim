# Navigate ariadne artifact references — Implementation Plan (parley#160)

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In parley chat/markdown buffers, make symbolic artifact refs (`ariadne#11`, `#15 M4`, `pair#84`, `gh#42`) read as navigable (highlighted) and jump from the ref under the cursor to the current file — shelling to `sdlc resolve` (ariadne#144, now merged) for the authoritative resolution, with a picker when a ref resolves to a family (issue + plan + reviews).

**Architecture:** A new **pure** Lua module `lua/parley/artifact_ref.lua` owns a *loose* ref detector (for cursor extraction + highlighting) and the parse of `sdlc resolve`'s output. Actual resolution shells to `sdlc resolve --json` through parley's existing `issues.build_spawn_argv` seam (which already handles "`sdlc` is a shell function, not a binary") behind an **injected runner** so it's unit-testable without spawning. The editor surface reuses parley's established infrastructure: the decoration-provider highlighter, the keybinding registry, and `float_picker`. **No grammar is reimplemented** — parley's Lua pattern is deliberately loose and delegates all authority to `sdlc resolve` (ARCH-DRY: sdlc is the single source; a Lua over-match just yields a "not resolvable" message).

**Tech Stack:** Lua / Neovim (plugin), `vim.system` for the shell-out, `vim.json` for `--json`, plenary.nvim (busted-style) tests. Depends on ariadne#144's `sdlc resolve` (merged to ariadne main).

---

## Design decisions (surfaced for operator review)

1. **Loose Lua detector, authoritative sdlc parse (ARCH-DRY / ARCH-PURPOSE).** `artifact_ref.grammar_pattern` matches ref-*shaped* tokens (`[repo]#digits` optionally ` M…`, `gh#digits`) only to (a) find the token under the cursor and (b) highlight it. It is NOT the grammar — `sdlc resolve` is. If the loose pattern over-matches something sdlc rejects, parley shows "not a resolvable ref" from sdlc's stderr. This is the whole point of ariadne#144: one parser, in sdlc; parley shells to it. The shadow-sweep consumer (this editor UX) *derives* from sdlc, never restates its grammar.

2. **Shell to `sdlc resolve --json`** via `issues.build_spawn_argv` (`issues.lua:369`) — it already spawns a real `sdlc` binary directly, else wraps in `{shell,"-i","-c",…}` so an rc-defined `sdlc` function loads. Reused verbatim; no new binary-discovery code. A `config.sdlc_cmd` (default `"sdlc"`) allows override.

3. **Injected runner, async (house pattern).** `run_resolve(ref, opts, on_done, runner)` mirrors `issues.run_sdlc_issue_new` (`issues.lua:380`): the `runner` defaults to a `vim.system`-based spawn and is swapped for a fake in tests (never spawns real `sdlc`). Read-only + fast (~10–40ms), but async keeps Neovim non-blocking and matches the established seam.

4. **Child `cwd` = the buffer's repo** (`neighborhood.for_buf(buf)`, `neighborhood.lua:96`) so a bare `#id` anchors to the repo that owns the current file, and `sdlc resolve` handles cross-repo (`pair#84`) itself. parley does NOT re-implement repo→dir mapping (`super_repo`/`neighborhood` are used only to pick the `cwd`).

5. **Single result → direct open; family → `float_picker`.** Mirror `issues.cmd_issue_goto` (direct `edit`) and `issue_finder.lua:227` (`float_picker.open` → `_parley.open_buf`). One path resolved ⇒ jump straight; multiple ⇒ picker of the family.

6. **Highlight in BOTH chat and markdown** buffers (refs appear in both) via the decoration provider (`highlighter.lua`), reusing the `gmatch`-over-visible-lines idiom; new `ParleyArtifactRef` group (underline = navigable), theme-agnostic via `link`.

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `M.grammar_pattern` / `M.iter_refs(line)` | `lua/parley/artifact_ref.lua` | new |
| `M.parse_ref_at_cursor(line, col)` | `lua/parley/artifact_ref.lua` | new |
| `M.parse_resolve_output(stdout, is_json)` | `lua/parley/artifact_ref.lua` | new |

- **iter_refs / grammar_pattern** — a *loose* Lua matcher yielding each ref-shaped span in a line: `(byte_start, ref_text, byte_end)`. Covers `[%w][%w._-]*#%d+` with an optional trailing ` M%d+%a?`, and bare `#%d+` / `gh#%d+`. Deliberately permissive — it flags candidates; sdlc adjudicates.
  - **Relationships:** 1 line → N spans. Shared by `parse_ref_at_cursor` (point in span) and the highlighter (all spans).
  - **DRY rationale:** the ONE place the ref-shape lives in Lua; both cursor-extraction and highlighting consume it, and neither re-encodes the authoritative grammar (that's sdlc's).
  - **Future extensions:** if refs gain a new surface form, widen this one pattern; sdlc still owns acceptance.

- **parse_ref_at_cursor(line, col)** — pure `(string, 1-indexed col) → { ref, byte_start, byte_end } | nil`. Returns the ref-shaped span containing the cursor column (must absorb an interior space, e.g. `#15 M4`, which `<cword>`/`<cfile>` cannot). Structural analog: `vision.cmd_goto_ref` span-finding (`vision.lua:1744-1780`).

- **parse_resolve_output(stdout, is_json)** — pure `(string, bool) → { {path, kind?, milestone?}, … }`. Plain mode: one absolute path per non-empty line (`kind` unknown). JSON mode: `pcall(vim.json.decode)` → `.files[]` (each `{kind, path, milestone}`); a `github:*` label (no files) returns `{}` with a `github` flag. Guarded decode per `cliproxy.lua:104`.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.run_resolve(ref, opts, on_done, runner)` | `lua/parley/artifact_ref.lua` | new | `sdlc resolve` subprocess |
| `M.cmd.ResolveRefUnderCursor` | `lua/parley/init.lua` | new | cursor/buffer + open/picker |
| `ParleyArtifactRef` highlight scan | `lua/parley/highlighter.lua` | modified | decoration provider |
| `resolve_ref` registry entry + wiring | `lua/parley/keybinding_registry.lua` + `init.lua` | modified | keymap |

- **run_resolve(ref, opts, on_done, runner)** — builds the argv `{sdlc_cmd, "resolve", "--json", ref}` via `issues.build_spawn_argv`, runs it (default runner: `vim.system(argv,{text=true,cwd=opts.cwd}, cb)`; injected fake in tests), and calls `on_done(files|nil, err|nil)` where `files` is `parse_resolve_output`'s result. Non-zero exit ⇒ `err` = trimmed stderr (sdlc's "not resolvable"/"no artifact" message).
  - **Injected into:** `ResolveRefUnderCursor`. The `runner` seam keeps the pure parse + control flow unit-testable with no spawn (idiom: `issues.lua:411`).

- **ResolveRefUnderCursor** — the keymap handler: read `line`/`col` (`nvim_win_get_cursor`), `parse_ref_at_cursor` → ref (or notify "no ref under cursor"), compute `cwd` via `neighborhood.for_buf(0)`, `run_resolve(ref, {cwd=cwd}, on_done)`. `on_done`: 0 files → notify sdlc's error; 1 → `open_buf(path, true)`; N → `float_picker.open` of the family. Modeled on `issues.cmd_issue_goto` (`issues.lua:894`) + `issue_finder.lua:227`.

- **ParleyArtifactRef highlight scan** — add a `M.iter_refs(line)` loop to `compute_markdown_highlights` (`highlighter.lua:437`) AND `compute_chat_highlights` (`:246`), emitting `{hl_group="ParleyArtifactRef", col_start=s-1, col_end=e}` (0-indexed byte, exclusive end); define `ParleyArtifactRef` in `setup_highlights` (`:627`) linking `{underline=true}` with a `config.highlight.artifact_ref` override.

- **resolve_ref registry entry + wiring** — a `keybinding_registry.M.entries` row `{ id="resolve_ref", config_key="chat_shortcut_resolve_ref", default_key="gf", default_modes={"n"}, scope="parley_buffer", buffer_local=true, desc=… }` (template: `open_file`, `:416`); callback `resolve_ref = M.cmd.ResolveRefUnderCursor` added to the `callbacks` at both `register_buffer` sites (`init.lua:1972` chat, `init.lua:2219` markdown). Help text auto-generates from the registry.

**Test surface.** Pure entities → `tests/unit/artifact_ref_spec.lua` (no Neovim APIs; copy `tests/unit/issues_spec.lua` bootstrap). `run_resolve` → unit test with an injected fake runner (no spawn). The keymap/open/picker flow → `tests/integration/` (or a focused unit test of `on_done` dispatch with fakes). Per TOOLING.md: `tests/unit/` = pure, `tests/integration/` = runtime; run via `make test` / `make test-spec SPEC=…`.

---

## Chunk 1: pure core — `lua/parley/artifact_ref.lua`

The entire testable-without-Neovim engine: loose detector, cursor extraction, output parse, and the injected-runner shell-out. TDD in `tests/unit/artifact_ref_spec.lua`.

### Task 1.1: `iter_refs` / `grammar_pattern` — the loose detector

**Files:**
- Create: `lua/parley/artifact_ref.lua`
- Test: `tests/unit/artifact_ref_spec.lua`

- [ ] **Step 1: Write the failing test** (copy the bootstrap from `tests/unit/issues_spec.lua:1-15`, then):

```lua
local ar = require("parley.artifact_ref")

describe("iter_refs", function()
  local function collect(line)
    local out = {}
    for s, ref, e in ar.iter_refs(line) do out[#out+1] = { s = s, ref = ref, e = e } end
    return out
  end

  it("finds repo#id, bare #id, gh#id, and #id Mx", function()
    local got = collect("see ariadne#11 and #15 M4 plus gh#42 end")
    assert.are.equal("ariadne#11", got[1].ref)
    assert.are.equal("#15 M4", got[2].ref)   -- absorbs the interior space
    assert.are.equal("gh#42", got[3].ref)
  end)

  it("gives byte spans that bracket the ref", function()
    local got = collect("x ariadne#11 y")
    assert.are.equal("ariadne#11", string.sub("x ariadne#11 y", got[1].s, got[1].e - 1))
  end)

  it("does not match a lone # or a bare number", function()
    assert.are.equal(0, #collect("# heading and 1234 alone"))
  end)
end)
```

- [ ] **Step 2: Run — expect FAIL** (module missing). NOTE (verified): `make
  test-spec SPEC=…` takes an *atlas key* (from `atlas/traceability.yaml`), NOT a
  file path, so `SPEC=unit/artifact_ref` won't work. A new `tests/unit/*_spec.lua`
  is auto-discovered by `make test-unit` (`find tests/unit -name '*_spec.lua'`). To
  run this one spec in isolation, invoke plenary directly:

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/artifact_ref_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.artifact_ref' not found`.

(Every later "Run: …spec…" step in this plan uses this same direct-plenary
invocation; the full suite is `make test` = `lint test-unit test-integration`.)

- [ ] **Step 3: Implement** `iter_refs`:

```lua
local M = {}

-- A LOOSE ref-shape detector — NOT the grammar. sdlc resolve is the single
-- authority (ariadne#144); this only flags candidates for highlight + cursor
-- extraction. Over-matches are adjudicated (rejected) by sdlc at resolve time.
-- Core body: an optional repo token attached to '#', then 1+ digits, then an
-- optional " Mx" milestone; plus the bare/gh forms.
M.grammar_pattern = "[%w][%w._-]*#%d+"  -- repo#id core (bare/gh handled in iter)

-- iter_refs(line) -> iterator of (byte_start, ref_text, byte_end_exclusive).
-- byte_start is 1-indexed; byte_end is one past the last byte (Lua sub-friendly).
function M.iter_refs(line)
    local pos = 1
    return function()
        while pos <= #line do
            -- match an optional repo token (incl. "gh"), then #digits
            local s, e = line:find("[%w][%w._-]*#%d+", pos)
            local bs, be
            if s then
                bs, be = s, e
            else
                -- bare #id (no repo token)
                s, e = line:find("#%d+", pos)
                if not s then pos = #line + 1; return nil end
                -- ensure it's not the tail of a repo#id already covered
                bs, be = s, e
            end
            -- absorb an optional trailing " Mx" milestone
            local ms, me = line:find("^ M%d+%a?", be + 1)
            if me then be = me end
            pos = be + 1
            return bs, line:sub(bs, be), be + 1  -- byte_end exclusive
        end
        return nil
    end
end

return M
```

Note: keep the pattern permissive; correctness of *acceptance* is sdlc's job. Verify the `#` heading case doesn't match (`#%d+` requires a digit right after `#`, so `# heading` won't match; `#15` will).

- [ ] **Step 4: Run — expect PASS.** Iterate the pattern until the three tests pass. Watch the interior-space absorb and the byte-span math.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/artifact_ref.lua tests/unit/artifact_ref_spec.lua
git commit -m "#160: loose artifact-ref detector (iter_refs) — sdlc owns the grammar"
```

### Task 1.2: `parse_ref_at_cursor(line, col)`

**Files:**
- Modify: `lua/parley/artifact_ref.lua`
- Test: `tests/unit/artifact_ref_spec.lua`

- [ ] **Step 1: Write the failing test:**

```lua
describe("parse_ref_at_cursor", function()
  it("returns the ref span under the cursor (1-indexed col)", function()
    local line = "see ariadne#11 here"
    local r = ar.parse_ref_at_cursor(line, 8)  -- col within 'ariadne#11'
    assert.are.equal("ariadne#11", r.ref)
  end)
  it("absorbs an interior-space milestone when cursor is on the id", function()
    local line = "see #15 M4 here"
    local r = ar.parse_ref_at_cursor(line, 6)  -- on '15'
    assert.are.equal("#15 M4", r.ref)
  end)
  it("returns nil when the cursor is not on a ref", function()
    assert.is_nil(ar.parse_ref_at_cursor("nothing here", 3))
  end)
end)
```

- [ ] **Step 2: Run — expect FAIL** (undefined).

- [ ] **Step 3: Implement** — reuse `iter_refs`, return the span whose `[byte_start, byte_end)` contains `col`:

```lua
function M.parse_ref_at_cursor(line, col)
    for s, ref, e in M.iter_refs(line) do
        if col >= s and col < e then
            return { ref = ref, byte_start = s, byte_end = e }
        end
    end
    return nil
end
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/artifact_ref.lua tests/unit/artifact_ref_spec.lua
git commit -m "#160: parse_ref_at_cursor — reuse iter_refs, span-under-cursor"
```

### Task 1.3: `parse_resolve_output(stdout, is_json)`

**Files:**
- Modify: `lua/parley/artifact_ref.lua`
- Test: `tests/unit/artifact_ref_spec.lua`

- [ ] **Step 1: Write the failing test:**

```lua
describe("parse_resolve_output", function()
  it("plain: one path per line", function()
    local files = ar.parse_resolve_output("/a/000144-foo.md\n/a/000144-foo-plan.md\n", false)
    assert.are.equal(2, #files)
    assert.are.equal("/a/000144-foo.md", files[1].path)
  end)
  it("json: reads .files[] with kind + milestone", function()
    local json = '{"ref":"#144","id":144,"files":[{"kind":"issue","path":"/a/i.md"},{"kind":"review","path":"/a/m2.md","milestone":"M2"}]}'
    local files = ar.parse_resolve_output(json, true)
    assert.are.equal("issue", files[1].kind)
    assert.are.equal("M2", files[2].milestone)
  end)
  it("json github label: empty files, github flag", function()
    local files = ar.parse_resolve_output('{"ref":"gh#42","id":42,"github":true,"files":[]}', true)
    assert.are.equal(0, #files)
  end)
end)
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement:**

```lua
function M.parse_resolve_output(stdout, is_json)
    local files = {}
    if is_json then
        local ok, decoded = pcall(vim.json.decode, stdout or "")
        if ok and type(decoded) == "table" and decoded.files then
            for _, f in ipairs(decoded.files) do
                files[#files + 1] = { path = f.path, kind = f.kind, milestone = f.milestone }
            end
        end
        return files
    end
    for line in (stdout or ""):gmatch("[^\n]+") do
        local p = line:match("^%s*(.-)%s*$")
        if p ~= "" then files[#files + 1] = { path = p } end
    end
    return files
end
```

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/artifact_ref.lua tests/unit/artifact_ref_spec.lua
git commit -m "#160: parse_resolve_output — plain + --json (files[]/github label)"
```

### Task 1.4: `run_resolve(ref, opts, on_done, runner)` — injected shell-out

**Files:**
- Modify: `lua/parley/artifact_ref.lua`
- Test: `tests/unit/artifact_ref_spec.lua`

- [ ] **Step 1: Write the failing test** with a fake runner (never spawns):

```lua
describe("run_resolve", function()
  it("passes the built argv and returns parsed files on exit 0", function()
    local seen
    local fake = function(argv, on_complete)
      seen = argv
      on_complete('{"id":144,"files":[{"kind":"issue","path":"/a/i.md"}]}', 0, "")
    end
    local got
    ar.run_resolve("#144", { cwd = "/repo", sdlc_cmd = "sdlc" },
      function(files, err) got = { files = files, err = err } end, fake)
    assert.is_nil(got.err)
    assert.are.equal("/a/i.md", got.files[1].path)
    -- argv includes resolve + --json + the ref
    assert.is_truthy(vim.tbl_contains(seen, "resolve") and vim.tbl_contains(seen, "--json") and vim.tbl_contains(seen, "#144"))
  end)
  it("returns stderr as err on non-zero exit", function()
    local fake = function(_, on_complete) on_complete("", 1, "no artifact resolves for #999") end
    local got
    ar.run_resolve("#999", {}, function(files, err) got = { files = files, err = err } end, fake)
    assert.is_truthy(got.err:match("no artifact resolves"))
  end)
end)
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** — reuse `issues.build_spawn_argv`; default runner via `vim.system`:

```lua
local issues = require("parley.issues")

-- default_runner(argv, on_complete): spawn sdlc, call on_complete(stdout, code, stderr).
local function default_runner(cwd)
    return function(argv, on_complete)
        vim.system(argv, { text = true, cwd = cwd }, function(res)
            on_complete(res.stdout or "", res.code or 1, res.stderr or "")
        end)
    end
end

function M.run_resolve(ref, opts, on_done, runner)
    opts = opts or {}
    local sdlc_cmd = opts.sdlc_cmd or "sdlc"
    local is_exec = vim.fn.executable(sdlc_cmd) == 1
    local shell = opts.shell or vim.o.shell
    local argv = issues.build_spawn_argv({ sdlc_cmd, "resolve", "--json", ref }, is_exec, shell)
    local run = runner or default_runner(opts.cwd)
    run(argv, function(stdout, code, stderr)
        if code ~= 0 then
            on_done(nil, (stderr ~= "" and stderr or stdout):gsub("%s+$", ""))
            return
        end
        on_done(M.parse_resolve_output(stdout, true), nil)
    end)
end
```

Confirm `issues.build_spawn_argv` is exported (it is — `issues.lua:369`); if it is local, export it or copy its 6-line body with a `-- mirrors issues.build_spawn_argv (ARCH-DRY: shared shell-fn handling)` note and file a follow-up to share it.

- [ ] **Step 4: Run — expect PASS.**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/artifact_ref.lua tests/unit/artifact_ref_spec.lua
git commit -m "#160: run_resolve — sdlc resolve --json via build_spawn_argv + injected runner"
```

---

## Chunk 2: editor surface — highlight, keymap, picker

Wires the pure core into parley's buffers. Reuses the decoration highlighter, the keybinding registry, and `float_picker`.

### Task 2.1: `ParleyArtifactRef` highlight in chat + markdown

**Files:**
- Modify: `lua/parley/highlighter.lua` (`setup_highlights` + `compute_markdown_highlights` + `compute_chat_highlights`)
- Test: `tests/unit/` (a pure test of the scan helper, if factored) or `tests/integration/` (extmark assertion)

- [ ] **Step 1: Define the highlight group** in `setup_highlights` (`highlighter.lua:627`), mirroring `ParleyReference` (`:705`):

```lua
vim.api.nvim_set_hl(0, "ParleyArtifactRef", config.highlight.artifact_ref or { underline = true })
```

- [ ] **Step 2: Add the scan** to `compute_markdown_highlights` (`:437`) AND `compute_chat_highlights` (`:246`). Factor a tiny shared local so the two don't diverge (ARCH-DRY):

```lua
-- near the top of highlighter.lua
local artifact_ref = require("parley.artifact_ref")
local function push_artifact_refs(result, row, line)
    for s, _, e in artifact_ref.iter_refs(line) do
        result[row] = result[row] or {}
        table.insert(result[row], { hl_group = "ParleyArtifactRef", col_start = s - 1, col_end = e - 1 })
    end
end
```

Call `push_artifact_refs(result, row, line)` inside both compute functions' per-line loops (alongside the existing reference-span scan at `:489`).

- [ ] **Step 3: Verify** in a scratch buffer (manual, Task 2.4 covers the full manual pass) or an integration test asserting an extmark on `ariadne#11`. If a pure test is feasible (call the compute function with a fake buffer-lines source), prefer `tests/unit/`.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/highlighter.lua tests/*
git commit -m "#160: highlight artifact refs (ParleyArtifactRef) in chat + markdown"
```

### Task 2.2: `ResolveRefUnderCursor` command

**Files:**
- Modify: `lua/parley/init.lua` (define `M.cmd.ResolveRefUnderCursor` near `M.cmd.OpenFileUnderCursor` `:3738`; delegate like `M.cmd.IssueGoto` `:4015`)
- Test: `tests/integration/` (or a unit test of the `on_done` dispatch with fakes)

- [ ] **Step 1: Write the flow** — modeled on `issues.cmd_issue_goto` (`issues.lua:894`):

```lua
M.cmd.ResolveRefUnderCursor = function()
    local artifact_ref = require("parley.artifact_ref")
    local neighborhood = require("parley.neighborhood")
    local float_picker = require("parley.float_picker")

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed byte col
    local hit = artifact_ref.parse_ref_at_cursor(line, col)
    if not hit then
        vim.notify("parley: no artifact ref under cursor", vim.log.levels.INFO)
        return
    end
    local cwd = neighborhood.for_buf(0) or (M.config and M.config.repo_root)
    artifact_ref.run_resolve(hit.ref, { cwd = cwd, sdlc_cmd = (M.config and M.config.sdlc_cmd) or "sdlc" },
        function(files, err)
            vim.schedule(function()
                if err or not files then
                    vim.notify("parley resolve: " .. (err or "no result"), vim.log.levels.WARN)
                    return
                end
                if #files == 0 then
                    vim.notify("parley: ref is a github/external ref (no local file)", vim.log.levels.INFO)
                elseif #files == 1 then
                    M.open_buf(files[1].path, true)
                else
                    float_picker.open({
                        title = "Resolve " .. hit.ref,
                        items = vim.tbl_map(function(f)
                            return { display = (f.kind or "file") .. (f.milestone and (" " .. f.milestone) or "") .. "  " .. vim.fn.fnamemodify(f.path, ":t"),
                                     search_text = f.path, value = f.path }
                        end, files),
                        on_select = function(item) M.open_buf(item.value, true) end,
                    })
                end
            end)
        end)
end
```

Confirm the exact names at implementation time: `M.open_buf` (used by `vision_finder`/`issue_finder` — `_parley.open_buf`), `neighborhood.for_buf`, `float_picker.open` opts (`issue_finder.lua:227`). Adjust to the real signatures.

- [ ] **Step 2: Test** the dispatch: a unit/integration test that stubs `run_resolve` to yield 0/1/N files and asserts notify / open_buf / picker is chosen. Use the injected-runner or monkeypatch `artifact_ref.run_resolve` in the spec.

- [ ] **Step 3: Commit**

```bash
git add lua/parley/init.lua tests/*
git commit -m "#160: ResolveRefUnderCursor — cursor -> sdlc resolve -> open/picker"
```

### Task 2.3: `resolve_ref` keymap registry entry + wiring

**Files:**
- Modify: `lua/parley/keybinding_registry.lua` (add entry; template `open_file` `:416`)
- Modify: `lua/parley/init.lua` (add `resolve_ref = M.cmd.ResolveRefUnderCursor` to the `callbacks` at both `register_buffer` sites: chat `:1972`, markdown `:2219`)
- Test: `tests/integration/` (assert the mapping is bound in a chat buffer)

- [ ] **Step 1: Add the registry entry** after `open_file` (`keybinding_registry.lua:416`):

```lua
{
    id = "resolve_ref",
    config_key = "chat_shortcut_resolve_ref",
    default_key = "<C-g>r",          -- <C-g> chord family (open_file is <C-g>o)
    default_modes = { "n" },
    scope = "parley_buffer",
    buffer_local = true,
    desc = "Resolve the artifact ref under the cursor (sdlc resolve) and open it",
    help_desc = "Jump from ariadne#11 / #15 M4 / pair#84 to its current file (family picker when it resolves to many)",
},
```

`<C-g>r` (verified): parley's buffer bindings all live in the `<C-g>…` chord family (`open_file` is `<C-g>o`, 34 `<C-g>` bindings total), so this is consistent AND avoids shadowing Vim's native `gf` (go-to-file) inside chat/markdown buffers — which a buffer-local `gf` in `parley_buffer` scope would do.

- [ ] **Step 2: Wire the callback** at both `register_buffer` call sites (`init.lua:1972`, `:2219`): add `resolve_ref = M.cmd.ResolveRefUnderCursor` to the `callbacks` table (alongside `open_file = M.cmd.OpenFileUnderCursor`).

- [ ] **Step 3: Test** — an integration spec opening a chat/markdown buffer and asserting `maparg("gf", "n")` (or the chosen key) resolves to the plug/callback. Reuse `tests/integration/neighborhood_completion_spec.lua` as the buffer-setup template.

- [ ] **Step 4: Run the full suite:**

Run: `make test`
Expected: PASS (unit + integration).

- [ ] **Step 5: Commit**

```bash
git add lua/parley/keybinding_registry.lua lua/parley/init.lua tests/*
git commit -m "#160: bind resolve_ref keymap (registry entry + chat/markdown wiring)"
```

### Task 2.4: Manual end-to-end verification in Neovim

- [ ] **Step 1:** Ensure `sdlc` resolves (ariadne#144 merged): from any repo, `sdlc resolve '#144'` prints a path. Confirm parley's `sdlc_cmd` reaches it (real binary on PATH, or the shell-fn fallback via `build_spawn_argv`).

- [ ] **Step 2:** Open a parley chat or a `workshop/issues/*.md` buffer containing refs (`ariadne#11`, `#15 M4`, `pair#84`, `gh#42`). Confirm they render highlighted (underlined) as navigable.

- [ ] **Step 3:** Cursor on `ariadne#144` (or a local `#NNN`), press the keymap → jumps to the current file. On an archived id, confirm it opens the `history/` path (sdlc handles archive-correctness). On a family id, confirm the `float_picker` lists issue + plan + reviews and opening a selection works. On `gh#42`, confirm the informative "github/external ref" notice.

- [ ] **Step 4:** Cross-repo: from within parley, cursor on `ariadne#144` → opens the ariadne file (sdlc's sibling resolution). Record the exact refs tried + outcomes in the issue `## Log`.

### Task 2.5: Atlas / docs + close

**Files:**
- Modify: parley `atlas/` (add the artifact-ref navigation surface + the `resolve_ref` keymap; link from `atlas/index.md`)
- Modify: `workshop/issues/000160-*.md` (tick Done-when + Plan; `## Log` with verification evidence)

- [ ] **Step 1: Atlas** — document `lua/parley/artifact_ref.lua` (the loose-detector-delegates-to-sdlc design), the `ParleyArtifactRef` highlight, and the `resolve_ref` keymap. Note the ariadne#144 dependency (parley shells to `sdlc resolve`; grammar single-sourced there).

- [ ] **Step 2: Tick** the issue Done-when + Plan boxes; write the `## Log` verification entry (Task 2.4 evidence).

- [ ] **Step 3: Compute actuals** (measured, not typed):

Run: `sdlc actual --issue 160`

- [ ] **Step 4: Close** (single boundary; auto-dispatches the fresh-context whole-issue review over the branch — fix Critical/Important first):

Run: `sdlc close --issue 160 --verified '<evidence: highlight + resolve/open/picker/gh + cross-repo + archived, full suite green>'`
Expected: passes actual/verified/atlas gates; lands a `Review-Verdict:` trailer; flips to `codecomplete`.

---

## Notes on skills & conventions

- Single close boundary (like ariadne#144's revised approach): Chunk 1 (pure) + Chunk 2 (UI) are logical phases of one cohesive feature, reviewed together at close — not two `milestone-close` dispatches (AGENTS.md §3: don't over-split cohesive work).
- TDD throughout (plenary busted): pure entities in `tests/unit/`, the spawn behind the injected runner, the flow/keymap in `tests/integration/`.
- ARCH-DRY: the ref-shape lives once (`iter_refs`), consumed by cursor-extraction AND highlighting; the authoritative grammar is NOT reimplemented — parley shells to `sdlc resolve` (the ariadne#144 single source). ARCH-PURE: `artifact_ref.lua`'s parse/detect functions are pure (unit-tested, no Neovim/spawn); the spawn + editor wiring are the thin IO shell.
- STYLE.md: 4-space indent, `local M = {}` / `return M`, snake_case, `pcall` around API calls, pure separated from IO.
