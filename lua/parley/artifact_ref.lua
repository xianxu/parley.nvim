-- lua/parley/artifact_ref.lua — navigate ariadne artifact references (#160).
--
-- A THIN editor layer over ariadne's `sdlc resolve` (ariadne#144). This module
-- owns a *loose* ref-shape detector (for cursor extraction + highlighting) and
-- the parse of `sdlc resolve`'s output; the authoritative grammar + resolution
-- live in `sdlc resolve` (single source — parley shells to it, never re-encodes
-- the grammar). An over-match here is simply rejected by sdlc at resolve time.
--
-- Pure core (no IO/spawn — some use vim.json/vim.fn utils but no side effects):
-- iter_refs, parse_ref_at_cursor, parse_resolve_output, highlight_spans,
-- dispatch_resolve_result, family_picker_items. IO seam: run_resolve (subprocess
-- behind an injected runner). The editor wiring (highlight/keymap/picker) lives in
-- highlighter.lua / keybinding_registry.lua / init.lua.

local M = {}

-- REPO_PAT covers `repo#id` AND `gh#id` (a repo token attached directly to '#').
-- BARE_PAT covers a bare `#id`. Both deliberately loose — sdlc adjudicates.
local REPO_PAT = "[%w][%w._-]*#%d+"
local BARE_PAT = "#%d+"
local MS_PAT = "^ M%d+%a?" -- optional trailing " Mx" milestone, anchored at be+1

-- iter_refs(line) -> iterator yielding (byte_start, ref_text, byte_end_exclusive).
-- byte_start is 1-indexed; byte_end is one past the last byte (Lua-sub friendly).
-- At each step it takes the EARLIEST of the repo-shaped and bare matches (Lua has
-- no pattern alternation, and searching repo-first would leapfrog an earlier bare
-- `#id` — e.g. drop `#15` in "ariadne#11 and #15").
function M.iter_refs(line)
    local pos = 1
    return function()
        -- Not a loop: iteration is driven by repeated closure calls, with `pos`
        -- persisting as an upvalue. Each call advances past one ref (or ends).
        if pos > #line then
            return nil
        end
        local sr, er = line:find(REPO_PAT, pos)
        local sb, eb = line:find(BARE_PAT, pos)
        local s, e
        if sr and (not sb or sr <= sb) then
            s, e = sr, er -- repo wins ties (it starts before its own '#')
        elseif sb then
            s, e = sb, eb
        else
            pos = #line + 1
            return nil
        end
        -- absorb an optional trailing " Mx" milestone
        local _, me = line:find(MS_PAT, e + 1)
        if me then
            e = me
        end
        pos = e + 1
        return s, line:sub(s, e), e + 1
    end
end

-- highlight_spans(line) -> { { col_start, col_end }, ... }: the 0-indexed extmark
-- columns for each ref-shaped span (col_start inclusive, col_end exclusive — the
-- nvim_buf_add_highlight/decoration convention). iter_refs' byte_end is one-past
-- (1-indexed), so col_start = s-1 and col_end = e-1. Pure; the single source of
-- the col math the highlighter's push_artifact_refs consumes (so it's tested).
function M.highlight_spans(line)
    local spans = {}
    for s, _, e in M.iter_refs(line) do
        spans[#spans + 1] = { col_start = s - 1, col_end = e - 1 }
    end
    return spans
end

-- parse_ref_at_cursor(line, col) -> { ref, byte_start, byte_end } | nil.
-- col is 1-indexed. Returns the ref-shaped span containing the cursor (which may
-- include an interior space, e.g. "#15 M4" — <cword>/<cfile> can't capture that).
function M.parse_ref_at_cursor(line, col)
    for s, ref, e in M.iter_refs(line) do
        if col >= s and col < e then
            return { ref = ref, byte_start = s, byte_end = e }
        end
    end
    return nil
end

-- parse_resolve_output(stdout, is_json) -> { {path, kind?, milestone?}, ... }.
-- JSON: reads `.files[]`; a github label resolves to {} (empty). Plain: one
-- absolute path per non-empty line.
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
    for ln in (stdout or ""):gmatch("[^\n]+") do
        local p = ln:match("^%s*(.-)%s*$")
        if p ~= "" then
            files[#files + 1] = { path = p }
        end
    end
    return files
end

-- run_resolve(ref, opts, on_done, runner): shell to `sdlc resolve --json <ref>`
-- and call on_done(files|nil, err|nil). opts: { cwd, sdlc_cmd, shell, kind }.
-- kind (e.g. "project", ariadne#171 M4) appends `--kind <kind>` so the same
-- flow resolves fleet-wide project records instead of the issue family. The
-- `runner(argv, on_complete)` seam defaults to vim.system; tests inject a fake so
-- no real spawn happens. Reuses issues.build_spawn_argv (handles the "sdlc is a
-- shell function, not a binary" case).
function M.run_resolve(ref, opts, on_done, runner)
    opts = opts or {}
    local issues = require("parley.issues")
    local sdlc_cmd = opts.sdlc_cmd or "sdlc"
    local is_exec = vim.fn.executable(sdlc_cmd) == 1
    -- Match issues.lua's shell resolution so an rc-defined `sdlc` function loads
    -- from the user's login shell, not just vim.o.shell.
    local shell = opts.shell or vim.env.SHELL or vim.o.shell or "sh"
    local cmd = { sdlc_cmd, "resolve", "--json" }
    if opts.kind then
        cmd[#cmd + 1] = "--kind"
        cmd[#cmd + 1] = opts.kind
    end
    cmd[#cmd + 1] = ref
    local argv = issues.build_spawn_argv(cmd, is_exec, shell)
    local run = runner
        or function(a, on_complete)
            vim.system(a, { text = true, cwd = opts.cwd }, function(res)
                on_complete(res.stdout or "", res.code or 1, res.stderr or "")
            end)
        end
    run(argv, function(stdout, code, stderr)
        if code ~= 0 then
            local msg = (stderr ~= "" and stderr or stdout) or ""
            on_done(nil, (msg:gsub("%s+$", "")))
            return
        end
        on_done(M.parse_resolve_output(stdout, true), nil)
    end)
end

-- dispatch_resolve_result decides what to do with a resolve outcome, calling the
-- injected deps so it's unit-testable without Neovim: err -> notify(warn); 0 files
-- (a github/external ref) -> notify(info); 1 -> open; N (a family) -> picker.
-- deps = { notify(msg, level), open(path), picker(ref, files) }. Returns the
-- action taken ("error"|"external"|"open"|"picker") for assertions.
function M.dispatch_resolve_result(ref, files, err, deps)
    if err or not files then
        deps.notify("parley resolve: " .. (err or "no result"), "warn")
        return "error"
    end
    if #files == 0 then
        deps.notify("parley: " .. ref .. " is a github/external ref (no local file)", "info")
        return "external"
    end
    if #files == 1 then
        deps.open(files[1].path)
        return "open"
    end
    deps.picker(ref, files)
    return "picker"
end

-- family_picker_items maps resolved files to float_picker item shape. Pure.
function M.family_picker_items(files)
    local items = {}
    for _, f in ipairs(files) do
        items[#items + 1] = {
            display = (f.kind or "file")
                .. (f.milestone and (" " .. f.milestone) or "")
                .. "  "
                .. vim.fn.fnamemodify(f.path, ":t"),
            search_text = f.path,
            value = f.path,
        }
    end
    return items
end

-- goto_ref_at_cursor: the editor entry (thin IO shell). Reads the ref under the
-- cursor, resolves it against the buffer's repo, and opens/pickers the result.
-- opts.on_no_ref (optional): called when the cursor is NOT on an artifact ref —
-- the smart-gf binding passes native `gf` here so `gf` resolves refs but still
-- goes-to-file on plain paths; the dedicated key omits it (notifies instead).
-- opts.kind (optional): resolve kind, e.g. "project" — the always-cross-repo
-- project class (ariadne#171 M4): jumps to the project record(s) referencing
-- the issue under the cursor, wherever in the fleet they live.
-- Delegated to by parley init's M.cmd.ResolveRef* commands.
function M.goto_ref_at_cursor(opts)
    opts = opts or {}
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed byte col
    local hit = M.parse_ref_at_cursor(line, col)
    if not hit then
        if opts.on_no_ref then
            opts.on_no_ref()
        else
            vim.notify("parley: no artifact ref under cursor", vim.log.levels.INFO)
        end
        return
    end
    local _parley = require("parley")
    local neighborhood = require("parley.neighborhood")
    local float_picker = require("parley.float_picker")
    local cwd = neighborhood.for_buf(vim.api.nvim_get_current_buf())
    local sdlc_cmd = (_parley.config and _parley.config.sdlc_cmd) or "sdlc"
    M.run_resolve(hit.ref, { cwd = cwd, sdlc_cmd = sdlc_cmd, kind = opts.kind }, function(files, err)
        vim.schedule(function()
            M.dispatch_resolve_result(hit.ref, files, err, {
                notify = function(msg, level)
                    vim.notify(msg, level == "warn" and vim.log.levels.WARN or vim.log.levels.INFO)
                end,
                open = function(path)
                    _parley.open_buf(path, true)
                end,
                picker = function(ref, family)
                    float_picker.open({
                        title = "Resolve " .. ref,
                        items = M.family_picker_items(family),
                        on_select = function(item)
                            _parley.open_buf(item.value, true)
                        end,
                    })
                end,
            })
        end)
    end)
end

return M
