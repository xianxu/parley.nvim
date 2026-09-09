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
    -- THE guards themselves: the only places a transcript string may reach a sink.
    ["lua/parley/helper.lua:expand_path:path"] = "the guard; refuses backticks first",
    ["lua/parley/helper.lua:safe_glob:pattern"] = "the guard; refuses backticks first",

    -- Configured directories. Operator-derived: they come from setup() or from
    -- a discovered repo root, never from buffer text.
    ["lua/parley/chat_finder.lua:discovery_snapshot:root.dir"] = "a configured chat root",
    ["lua/parley/note_finder.lua:discovery_snapshot:root.dir"] = "a configured note root",
    ["lua/parley/issue_finder.lua:discovery_roots:root.dir"] = "a configured issue root",
    ["lua/parley/issue_finder.lua:absolute_configured_dir:value"] = "a config value, by the function's own name",
    ["lua/parley/vision_finder.lua:discovery_roots:root.dir"] = "a configured vision root",
    ["lua/parley/vision_finder.lua:discovery_roots:_parley.config.vision_dir"] = "config.vision_dir",
    ["lua/parley/memory_prefs.lua:prefs_dir:_parley.config.chat_dir"] = "config.chat_dir",
    ["lua/parley/memory_prefs.lua:extract_summaries:root.dir"] = "a configured chat root",
    ["lua/parley/init.lua:detect_buffer_context:root.dir"] = "a configured note root",
    ["lua/parley/init.lua:resolve_src_link:M.config.src_root"] = "config.src_root",
    ["lua/parley/neighborhood.lua:canonical:root"] = "a configured_roots entry",
    ["lua/parley/tools/dispatcher.lua:resolve_root:root"] = "a tool's configured root",

    -- resolve_dir_key: the same one-liner in three modules, always over a
    -- config *_dir value. (The duplication is pre-existing and noted in #225.)
    ["lua/parley/init.lua:resolve_dir_key:d"] = "a config *_dir value",
    ["lua/parley/root_dirs.lua:resolve_dir_key:dir"] = "a config *_dir value",
    ["lua/parley/super_repo.lua:resolve_dir_key:dir"] = "a config *_dir value",
    ["lua/parley/root_dir_picker.lua:item_index_by_dir:dir"] = "a configured root, picker side",
    ["lua/parley/root_dir_picker.lua:item_index_by_dir:item.dir"] = "a picker item built from config",
    ["lua/parley/root_dir_picker.lua:open:dir"] = "a configured root, picker side",

    -- glob over a configured directory with a LITERAL pattern half. The pattern
    -- half is what carried the payload in round 3's C2, so each of these is
    -- allowlisted on the strength of its pattern being a literal.
    ["lua/parley/dispatcher.lua:setup:D.query_dir .. \"/*.json\""] = "configured query store, literal pattern",
    ["lua/parley/super_repo.lua:compute_members:workspace_root .. \"/*/.parley\""] = "configured workspace root, literal pattern",
    ["lua/parley/memory_prefs.lua:load:pattern"] = "built from prefs_dir() with a literal suffix",
    ["lua/parley/skills/review/init.lua:scan_pending:dir .. \"/**/*.md\""] = "a configured review root, literal pattern",
    ["lua/parley/skills/review/init.lua:scan_pending:dir .. \"/*.md\""] = "a configured review root, literal pattern",
    ["lua/parley/vision.lua:load_vision_dir:dir .. \"/*.yaml\""] = "a configured vision dir, literal pattern",
    ["lua/parley/vision.lua:discover_quarters:dir .. \"/*\""] = "a configured vision dir, literal pattern",
    ["lua/parley/vision.lua:load_vision_quarterly:current_dir .. \"/*.yaml\""] = "cwd, literal pattern",
    ["lua/parley/vision.lua:load_vision_quarterly:base_dir .. \"/*.yaml\""] = "a configured vision dir, literal pattern",
}

-- The first argument of a call, as source text: everything from the open paren
-- to the matching close or the first top-level comma. Balanced over (), [], {}
-- and quotes, so `f(("%s"):format(x), 1)` yields `("%s"):format(x)`.
--
-- The first version captured only a leading identifier (`[%w_%.]+`), which saw
-- `vim.fn.glob(pattern)` and was blind to `vim.fn.glob("/tmp/" .. pattern)` —
-- an ordinary spelling, and one already in the tree. Its self-test drove the
-- single shape it already handled, which is the "my probe shared my
-- misconception" failure one layer up (#225 round 4 I1).
local function first_arg(text, open_at)
    local depth, i, quote = 0, open_at, nil
    while i <= #text do
        local c = text:sub(i, i)
        if quote then
            if c == "\\" then i = i + 1
            elseif c == quote then quote = nil end
        elseif c == '"' or c == "'" then
            quote = c
        elseif c == "(" or c == "[" or c == "{" then
            depth = depth + 1
        elseif c == ")" or c == "]" or c == "}" then
            depth = depth - 1
            if depth == 0 then return text:sub(open_at + 1, i - 1) end
        elseif c == "," and depth == 1 then
            return text:sub(open_at + 1, i - 1)
        end
        i = i + 1
    end
    return nil -- unbalanced on this line; caller treats as unparsed
end

-- A single string literal argument is always safe: nothing transcript-derived
-- can be spelled as one.
local function is_literal(expr)
    return expr:match([[^%s*"[^"]*"%s*$]]) ~= nil or expr:match("^%s*'[^']*'%s*$") ~= nil
end

-- Every non-literal sink argument on ONE line. Shared by the tree scan and by
-- the matcher's own self-test, so the self-test cannot pass against a different
-- implementation than the one that guards the tree.
local function line_sink_args(line)
    local hits = {}
    for _, fn in ipairs(SINKS) do
        local from = 1
        while true do
            local s2, e2 = line:find("vim%.fn%." .. fn .. "%s*%(", from)
            if not s2 then break end
            local expr = first_arg(line, e2)
            if expr and not is_literal(expr) then
                expr = expr:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
                hits[#hits + 1] = { fn = fn, arg = expr }
            end
            from = e2 + 1
        end
    end
    return hits
end

-- Every sink call whose argument is not a bare string literal, keyed by
-- <file>:<enclosing function>:<argument expression>. Keying on the ENCLOSING
-- FUNCTION as well as the file matters: the old `<file>:<token>` key meant
-- expand_path's entry pre-approved every `vim.fn.expand(path)` anywhere in
-- helper.lua, including one written later.
local function sink_calls()
    local calls = {}
    for _, file in ipairs(repo_lua_files()) do
        local n, enclosing = 0, "<file scope>"
        for line in io.lines(file) do
            n = n + 1
            local fname = line:match("^%s*local function ([%w_]+)%(")
                or line:match("^%s*function [%w_]+[%.:]([%w_]+)%(")
                or line:match("^%s*[%w_]+%.([%w_]+) = function%(")
                or line:match("^%s*local ([%w_]+) = function%(")
            if fname then enclosing = fname end
            -- skip comments: this file's own prose names these functions a lot
            if not line:match("^%s*%-%-") then
                for _, hit in ipairs(line_sink_args(line)) do
                    calls[#calls + 1] = {
                        file = file, line = n, fn = hit.fn, arg = hit.arg,
                        key = ("%s:%s:%s"):format(file, enclosing, hit.arg),
                    }
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

    it("the matcher sees every argument SHAPE the codebase uses", function()
        -- #225 round 4 I1: the previous self-test drove exactly one shape —
        -- `vim.fn.<fn>(ident, …)` — which is the shape the matcher already
        -- handled, so it confirmed nothing. Concatenation and format-call
        -- spellings were invisible, and one such call is in the tree
        -- (skills/voice_apply/init.lua:43).
        local shapes = {
            { 'vim.fn.expand(ref_path)', 'ref_path' },
            { 'vim.fn.glob(ref_path, false, true)', 'ref_path' },
            { 'vim.fn.expand("/tmp/" .. ref_path)', '"/tmp/" .. ref_path' },
            { 'vim.fn.glob(dir .. "/" .. pattern, false, true)', 'dir .. "/" .. pattern' },
            { 'vim.fn.expand(("%s/x"):format(p))', '("%s/x"):format(p)' },
            { 'vim.fn.expand(vim.fn.fnamemodify(p, ":h"))', 'vim.fn.fnamemodify(p, ":h")' },
            { 'vim.fn.expand(cfg.dir)', 'cfg.dir' },
            { 'vim.fn.globpath(root, "*" .. ext)', 'root' },
            { 'vim.fn.expand(t[1])', 't[1]' },
        }
        for _, case in ipairs(shapes) do
            local hits = line_sink_args(case[1])
            assert.equals(1, #hits, "matcher missed: " .. case[1])
            assert.equals(case[2], hits[1].arg, "wrong extraction for: " .. case[1])
        end

        -- A bare string literal is always safe and must NOT be flagged.
        for _, safe in ipairs({
            'vim.fn.expand("~")',
            "vim.fn.expand('~/.config')",
            'vim.fn.glob("/etc/*.conf", false, true)',
        }) do
            assert.same({}, line_sink_args(safe), "matcher fired on a literal: " .. safe)
        end

        -- Every declared sink is reachable by the scanner, not just expand.
        for _, fn in ipairs(SINKS) do
            local hits = line_sink_args(("x = vim.fn.%s(ref_path)"):format(fn))
            assert.equals(1, #hits, "matcher missed vim.fn." .. fn)
        end
    end)

    it("an allowlist entry does not pre-approve a call written later", function()
        -- The old key was <file>:<token>, so expand_path's entry covered every
        -- `vim.fn.expand(path)` anywhere in helper.lua. Keys carry the
        -- enclosing function now; assert two calls with the same token in
        -- different functions get different keys.
        local seen = {}
        for _, c in ipairs(sink_calls()) do
            assert.is_nil(seen[c.key], "two sites share a key: " .. c.key)
            seen[c.key] = true
        end
        -- and every key names a function, not just a file
        for key in pairs(seen) do
            local _, colons = key:gsub(":", "")
            assert.is_true(colons >= 2, "key is not site-scoped: " .. key)
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

    it("every producer of the tri-state reference status is dispositioned", function()
        -- #225 round 4 I3, and the FOURTH sweep on this issue that came up one
        -- member short. A return-contract change (true|false ->
        -- "opened"|"failed"|nil) has a producer set as well as a consumer set,
        -- and the producer set was enumerated by memory: the inline-link arm
        -- was converted and never driven through the chain.
        --
        -- Declaring the set here forces the next conversion to be listed, and
        -- the comment says what listing obliges you to do: give the new member
        -- a test that distinguishes the NEW values, not just "it worked".
        local DISPOSITIONED = {
            -- function                     test that distinguishes its values
            ["try_open_inline_branch_link"] = "open_reference_spec: the inline [🌿:…](file) arm",
            ["open_branch_ref"] = "open_reference_spec + untrusted_path_spec: the 🌿: arms",
            ["try_open_src_link"] = "open_reference_spec: D1, both buffer types",
            ["open_reference_under_cursor"] = "open_reference_spec: the three-valued contract",
        }
        -- The enclosing function of every `return "opened"` in lua/.
        local producers, current = {}, nil
        for _, file in ipairs(repo_lua_files()) do
            for line in io.lines(file) do
                local fname = line:match("^%s*local function ([%w_]+)%(")
                    or line:match("^%s*function [%w_]+%.([%w_]+)%(")
                    or line:match("^%s*[%w_]+%.([%w_]+) = function%(")
                    or line:match("^%s*local ([%w_]+) = function%(")
                if fname then current = fname end
                -- not the `---@return "opened"|…` annotations: those sit
                -- ABOVE the function, so counting them attributed every
                -- producer to the PREVIOUS function. Seen, not assumed.
                if line:match('return "opened"') and current
                    and not line:match("^%s*%-%-") then
                    producers[current] = true
                end
            end
        end
        local undeclared = {}
        for name in pairs(producers) do
            if not DISPOSITIONED[name] then undeclared[#undeclared + 1] = name end
        end
        table.sort(undeclared)
        assert.same({}, undeclared,
            'this function returns "opened" but is not dispositioned — add it to '
            .. "DISPOSITIONED naming the test that distinguishes its new values")

        local stale = {}
        for name in pairs(DISPOSITIONED) do
            if not producers[name] then stale[#stale + 1] = name end
        end
        table.sort(stale)
        assert.same({}, stale, "these no longer produce the tri-state — drop them")
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
