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
-- So the rule is mechanical. Every `vim.fn.expand(<variable>)` in lua/ is
-- either on the allowlist below — with a stated reason why the argument is
-- operator-derived — or it is a bug. Transcript-derived paths go through
-- `helper.expand_path` (refuses, so you can report it) or `helper.abs_path`
-- (total, degrades to the unexpanded literal).

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
    -- THE guard itself: the one place a transcript path may be expanded.
    ["lua/parley/helper.lua:path"] = "helper.expand_path — the guard; refuses backticks first",
}

describe("arch: transcript-derived paths never reach vim.fn.expand", function()
    it("every vim.fn.expand(<variable>) is allowlisted as operator-derived", function()
        local unlisted = {}
        for _, file in ipairs(repo_lua_files()) do
            local n = 0
            for line in io.lines(file) do
                n = n + 1
                -- skip comments: this file's own prose says vim.fn.expand a lot
                if not line:match("^%s*%-%-") then
                    for arg in line:gmatch("vim%.fn%.expand%(([%w_%.]+)") do
                        local key = file .. ":" .. arg
                        if not ALLOW[key] then
                            unlisted[#unlisted + 1] = ("%s:%d  vim.fn.expand(%s)"):format(file, n, arg)
                        end
                    end
                end
            end
        end
        assert.same({}, unlisted,
            "a path expanded here must be operator-derived (add it to ALLOW with the reason) "
            .. "or transcript-derived (route it through helper.expand_path / helper.abs_path)")
    end)

    it("the allowlist has no dead entries", function()
        local seen = {}
        for _, file in ipairs(repo_lua_files()) do
            for line in io.lines(file) do
                if not line:match("^%s*%-%-") then
                    for arg in line:gmatch("vim%.fn%.expand%(([%w_%.]+)") do
                        seen[file .. ":" .. arg] = true
                    end
                end
            end
        end
        local dead = {}
        for key in pairs(ALLOW) do
            if not seen[key] then dead[#dead + 1] = key end
        end
        table.sort(dead)
        assert.same({}, dead,
            "these allowlist entries no longer match any call — delete them, or the "
            .. "allowlist becomes the stale memorised list this guard replaced")
    end)

    it("the matcher actually sees a violation", function()
        -- The guard is worth nothing if the pattern misses. Drive it over a
        -- synthetic line rather than trusting the grep.
        local hits = {}
        for arg in ('local p = vim.fn.expand(ref_path)'):gmatch("vim%.fn%.expand%(([%w_%.]+)") do
            hits[#hits + 1] = arg
        end
        assert.same({ "ref_path" }, hits)
        -- and does NOT fire on a string literal, which is always safe
        local lit = {}
        for arg in ('vim.fn.expand("~")'):gmatch("vim%.fn%.expand%(([%w_%.]+)") do
            lit[#lit + 1] = arg
        end
        assert.same({}, lit)
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
