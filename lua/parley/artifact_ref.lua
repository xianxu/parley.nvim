-- lua/parley/artifact_ref.lua — navigate ariadne artifact references (#160).
--
-- A THIN editor layer over ariadne's `sdlc resolve` (ariadne#144). This module
-- owns a *loose* ref-shape detector (for cursor extraction + highlighting) and
-- the parse of `sdlc resolve`'s output; the authoritative grammar + resolution
-- live in `sdlc resolve` (single source — parley shells to it, never re-encodes
-- the grammar). An over-match here is simply rejected by sdlc at resolve time.
--
-- Pure core (no Neovim/spawn): iter_refs, parse_ref_at_cursor,
-- parse_resolve_output. IO seam: run_resolve (subprocess behind an injected
-- runner). The editor wiring (highlight/keymap/picker) lives in
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
        while pos <= #line do
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
        return nil
    end
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
-- and call on_done(files|nil, err|nil). opts: { cwd, sdlc_cmd, shell }. The
-- `runner(argv, on_complete)` seam defaults to vim.system; tests inject a fake so
-- no real spawn happens. Reuses issues.build_spawn_argv (handles the "sdlc is a
-- shell function, not a binary" case).
function M.run_resolve(ref, opts, on_done, runner)
    opts = opts or {}
    local issues = require("parley.issues")
    local sdlc_cmd = opts.sdlc_cmd or "sdlc"
    local is_exec = vim.fn.executable(sdlc_cmd) == 1
    local shell = opts.shell or vim.o.shell
    local argv = issues.build_spawn_argv({ sdlc_cmd, "resolve", "--json", ref }, is_exec, shell)
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

return M
