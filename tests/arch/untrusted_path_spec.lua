-- The provenance rule, enforced rather than remembered (#225 close review C3).
--
-- `vim.fn.expand()` runs backtick commands. A chat buffer holds MODEL OUTPUT,
-- so any path parsed out of buffer text — `@@` references, `🌿:` links, inline
-- `[🌿:…](file)`, anything derived from `chat_parser` output — is an injection
-- sink when expanded.
--
-- Two rounds of this issue tried to fix it by enumeration. Round 1 named three
-- sites; the sweep found ten; the review then found four more in `outline.lua`
-- and `exporter.lua`, including a byte-identical copy of a function the sweep
-- HAD guarded elsewhere. Enumeration is the wrong instrument: the list is only
-- correct until someone writes the next `vim.fn.expand`.
--
-- So the rule is mechanical. Every call to a COMMAND-EXECUTING vim function
-- with a non-literal argument is either on the allowlist below — with a stated
-- reason why the argument is operator-derived — or it is a bug.
--
-- Round 2 wrote this rule over `vim.fn.expand` alone, declared the class
-- closed, and left `vim.fn.glob` open; a transcript reached it through
-- `find_files`' pattern half. So the sink SET is derived by a probe below
-- rather than remembered, and the probe fails in both directions — a sink that
-- stops executing must leave the set, and one that starts must join it.
--
-- Transcript-derived paths go through `helper.expand_path` (refuses, so you can
-- report it), `helper.abs_path` (total, degrades to the unexpanded literal), or
-- `helper.safe_glob`.

-- Established by `the sink set is probed, not remembered` below.
local SINKS = { "expand", "glob", "globpath", "expandcmd" }

local function repo_lua_files()
    local out = vim.fn.systemlist("find lua -name '*.lua' -type f")
    table.sort(out)
    return out
end

-- Argument is operator-derived, i.e. it came from config or from the
-- filesystem, never from buffer text. Keyed "<file>:<argument token>".
local ALLOW = {
    ["lua/parley/neighborhood.lua:root"] = "configured_roots entry (config)",
    ["lua/parley/root_dirs.lua:dir"] = "a configured chat/note root",
    ["lua/parley/root_dir_picker.lua:dir"] = "a configured root, picker side",
    ["lua/parley/root_dir_picker.lua:item.dir"] = "picker item built from config",
    ["lua/parley/super_repo.lua:dir"] = "a configured super-repo dir",
    ["lua/parley/init.lua:d"] = "resolve_dir_key, called on config *_dir values",
    ["lua/parley/init.lua:root.dir"] = "a configured note root",
    ["lua/parley/init.lua:M.config.src_root"] = "config.src_root",
    ["lua/parley/chat_finder.lua:root.dir"] = "a configured chat root",
    ["lua/parley/vision_finder.lua:root.dir"] = "a configured vision root",
    ["lua/parley/vision_finder.lua:_parley.config.vision_dir"] = "config.vision_dir",
    ["lua/parley/note_finder.lua:root.dir"] = "a configured note root",
    ["lua/parley/issue_finder.lua:value"] = "absolute_configured_dir's config value",
    ["lua/parley/issue_finder.lua:root.dir"] = "a configured issue root",
    ["lua/parley/memory_prefs.lua:_parley.config.chat_dir"] = "config.chat_dir",
    ["lua/parley/memory_prefs.lua:root.dir"] = "a configured chat root",
    ["lua/parley/tools/dispatcher.lua:root"] = "a tool's configured root",
    -- THE guards themselves: the only places a transcript string may reach a sink.
    ["lua/parley/helper.lua:path"] = "helper.expand_path — the guard; refuses backticks first",
    ["lua/parley/helper.lua:pattern"] = "helper.safe_glob — the guard; refuses backticks first",
    -- glob sinks whose argument is a configured directory
    ["lua/parley/super_repo.lua:workspace_root"] = "the configured workspace root",
    ["lua/parley/vision.lua:dir"] = "a configured vision dir",
    ["lua/parley/vision.lua:current_dir"] = "cwd, not buffer text",
    ["lua/parley/vision.lua:base_dir"] = "a configured vision dir",
    ["lua/parley/dispatcher.lua:D.query_dir"] = "the configured query store",
    ["lua/parley/memory_prefs.lua:pattern"] = "built from prefs_dir(), a config path",
    ["lua/parley/skills/review/init.lua:dir"] = "a configured review root",
}

local function sink_pattern(fn)
    return ("vim%%.fn%%.%s%%(([%%w_%%.]+)"):format(fn)
end

-- Every (file, first-argument-token) pair where a sink is called with a
-- non-literal argument.
local function sink_calls()
    local calls = {}
    for _, file in ipairs(repo_lua_files()) do
        local n = 0
        for line in io.lines(file) do
            n = n + 1
            -- skip comments: this file's own prose names these functions a lot
            if not line:match("^%s*%-%-") then
                for _, fn in ipairs(SINKS) do
                    for arg in line:gmatch(sink_pattern(fn)) do
                        calls[#calls + 1] =
                            { file = file, line = n, fn = fn, arg = arg,
                              key = file .. ":" .. arg }
                    end
                end
            end
        end
    end
    return calls
end

describe("arch: transcript-derived paths never reach vim.fn.expand", function()
    it("the sink set is probed, not remembered", function()
        -- The finding that reopened this class was "glob executes too, and your
        -- rule only knows about expand". A memorised set cannot fail; this can.
        local dir = vim.fn.tempname() .. "-sinkprobe"
        vim.fn.mkdir(dir, "p")
        local function executes(fn, build)
            local marker = dir .. "/" .. fn .. "-" .. math.random(1e6)
            pcall(build, "`touch " .. marker .. "`")
            vim.wait(50, function() return vim.fn.filereadable(marker) == 1 end)
            return vim.fn.filereadable(marker) == 1
        end
        local probed = {}
        local candidates = {
            expand = function(p) return vim.fn.expand(p) end,
            glob = function(p) return vim.fn.glob(p) end,
            globpath = function(p) return vim.fn.globpath(dir, p) end,
            expandcmd = function(p) return vim.fn.expandcmd(p) end,
            resolve = function(p) return vim.fn.resolve(p) end,
            filereadable = function(p) return vim.fn.filereadable(p) end,
            isdirectory = function(p) return vim.fn.isdirectory(p) end,
            simplify = function(p) return vim.fn.simplify(p) end,
            fnamemodify = function(p) return vim.fn.fnamemodify(p, ":p") end,
        }
        for fn, build in pairs(candidates) do
            if executes(fn, build) then probed[#probed + 1] = fn end
        end
        table.sort(probed)
        local declared = vim.deepcopy(SINKS)
        table.sort(declared)
        assert.same(declared, probed,
            "the declared sink set no longer matches what actually executes — "
            .. "update SINKS (and the guards in helper.lua) to match the probe")
    end)

    it("every command-executing sink call is allowlisted as operator-derived", function()
        local unlisted = {}
        for _, c in ipairs(sink_calls()) do
            if not ALLOW[c.key] then
                unlisted[#unlisted + 1] =
                    ("%s:%d  vim.fn.%s(%s)"):format(c.file, c.line, c.fn, c.arg)
            end
        end
        assert.same({}, unlisted,
            "this argument must be operator-derived (add it to ALLOW with the reason) or "
            .. "transcript-derived (route it through helper.expand_path / abs_path / safe_glob)")
    end)

    it("the allowlist has no dead entries", function()
        local seen = {}
        for _, c in ipairs(sink_calls()) do seen[c.key] = true end
        local dead = {}
        for key in pairs(ALLOW) do
            if not seen[key] then dead[#dead + 1] = key end
        end
        table.sort(dead)
        assert.same({}, dead,
            "these allowlist entries no longer match any call — delete them, or the "
            .. "allowlist becomes the stale memorised list this guard replaced")
    end)

    it("the matcher actually sees a violation, for every sink", function()
        -- The guard is worth nothing if the pattern misses. Drive it over
        -- synthetic lines rather than trusting the grep.
        for _, fn in ipairs(SINKS) do
            local hits = {}
            local line = ("local p = vim.fn.%s(ref_path, false, true)"):format(fn)
            for arg in line:gmatch(sink_pattern(fn)) do hits[#hits + 1] = arg end
            assert.same({ "ref_path" }, hits, "matcher missed vim.fn." .. fn)

            -- and does NOT fire on a string literal, which is always safe
            local lit = {}
            for arg in ('vim.fn.%s("~")'):format(fn):gmatch(sink_pattern(fn)) do
                lit[#lit + 1] = arg
            end
            assert.same({}, lit, "matcher fired on a literal for vim.fn." .. fn)
        end
    end)

    it("every caller that USES prepare_dir's return value handles nil", function()
        -- prepare_dir gained a nil return in #225 and the sweep came up one
        -- site short twice. The mechanical enumeration is `grep -rn '<name>('`
        -- filtered to the calls whose value is consumed; each must have a
        -- fallback, because `nil` reaches an index otherwise.
        local unguarded = {}
        for _, line in ipairs(vim.fn.systemlist(
            -- `[ ]*` not `[[:space:]]*`: the latter opens a `[[` inside this
            -- Lua long string and is a syntax error.
            [[grep -rn 'prepare_dir(' lua/ | grep -E '=[ ]*[A-Za-z_.]*prepare_dir\(']])) do
            if not line:match("%)%s*or%s") then
                unguarded[#unguarded + 1] = line
            end
        end
        assert.same({}, unguarded,
            "prepare_dir can return nil; a call site that consumes the value needs `or <fallback>`")
    end)

    it("resolve_relative_path has exactly one implementation", function()
        -- It had four, two byte-identical, and the round that guarded one of
        -- the identical pair missed the other. Copies are how the guard rots.
        --
        -- Matched on the BODY, not the predicate: `path:match("^~/")` also
        -- appears in a legitimate DISPATCH (init decides whether to add
        -- chat-root candidates), and a first version of this check flagged it.
        -- The thing that must be singular is the resolution itself.
        local hits = vim.fn.systemlist(
            [[grep -rln 'base_dir .. "/" .. path' lua/ 2>/dev/null]])
        assert.same({ "lua/parley/helper.lua" }, hits)
    end)
end)
