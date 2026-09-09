-- Chat references resolve in exactly one place (#224).
--
-- The defect this guards against is not a wrong answer; it is a SECOND
-- resolver that only does exact matching. That one works for every reference
-- whose parent has not been renamed yet, which is most of them — so it ships,
-- and then a fork silently submits with no parent context at all.
--
-- The obvious rule ("no module joins a chat-reference path itself") greps clean
-- over a tree that still has the bug: after #225 the offending modules did not
-- join anything, they DELEGATED to a naive shared helper. A guard over the
-- wrong term is the #225 round-3 failure exactly, where the rule was over
-- `expand` while `glob` was the live sink. So this is over RESOLUTION.

local function repo_lua_files()
    local out = vim.fn.systemlist("find lua -name '*.lua' -type f")
    table.sort(out)
    return out
end

local function lines_of(file)
    local out = {}
    for line in io.lines(file) do out[#out + 1] = line end
    return out
end

-- `helper.resolve_relative_path` is the NAIVE resolver: base_dir join, no
-- chat-root search, no timestamp glob. It is correct only inside the real
-- resolver, which layers prefix identity on top. Keyed "<file>:<enclosing fn>".
local NAIVE_ALLOW = {
    ["lua/parley/init.lua:_resolve_chat_path_candidates"] =
        "inside resolve_chat_path — this IS the layer prefix identity is built on",
}

local function enclosing_fn_scan(file, want)
    local hits, enclosing = {}, "<file scope>"
    local n = 0
    for _, line in ipairs(lines_of(file)) do
        n = n + 1
        local fname = line:match("^%s*local function ([%w_]+)%(")
            or line:match("^%s*function [%w_]+[%.:]([%w_]+)%(")
            or line:match("^%s*[%w_]+%.([%w_]+) = function%(")
            or line:match("^%s*local ([%w_]+) = function%(")
        if fname then enclosing = fname end
        if not line:match("^%s*%-%-") and line:find(want, 1, true) then
            hits[#hits + 1] = { file = file, line = n, fn = enclosing,
                                key = file .. ":" .. enclosing }
        end
    end
    return hits
end

describe("arch: chat references resolve in one place", function()
    it("the naive resolver is reached only from inside resolve_chat_path", function()
        local unlisted = {}
        for _, file in ipairs(repo_lua_files()) do
            if file ~= "lua/parley/helper.lua" then   -- its definition site
                for _, h in ipairs(enclosing_fn_scan(file, "resolve_relative_path")) do
                    if not NAIVE_ALLOW[h.key] then
                        unlisted[#unlisted + 1] =
                            ("%s:%d  in %s()"):format(h.file, h.line, h.fn)
                    end
                end
            end
        end
        assert.same({}, unlisted,
            "resolve_relative_path does not search the chat roots and does not glob the "
            .. "timestamp, so it resolves a renamed file to nothing. Call "
            .. "parley.resolve_chat_path, or add a stated reason to NAIVE_ALLOW")
    end)

    it("the allowlist has no dead entries", function()
        local seen = {}
        for _, file in ipairs(repo_lua_files()) do
            for _, h in ipairs(enclosing_fn_scan(file, "resolve_relative_path")) do
                seen[h.key] = true
            end
        end
        local dead = {}
        for key in pairs(NAIVE_ALLOW) do
            if not seen[key] then dead[#dead + 1] = key end
        end
        assert.same({}, dead, "delete these, or the allowlist becomes the stale list it replaced")
    end)

    it("no module defines its own `resolve_path`", function()
        -- THREE modules defined one: chat_respond, outline and highlighter.
        -- (An earlier count said six — that was CALL SITES read as definitions,
        -- and the 2+3+1 breakdown double-counted the same functions before and
        -- after #225 merged two of them.) Two resolved exact-only, one was
        -- already correct; the correct one is gone too, because the shared NAME
        -- is what made the broken pair look like the working one at a glance.
        local defs = vim.fn.systemlist(
            [[grep -rn 'local function resolve_path\|local resolve_path =' lua/ 2>/dev/null]])
        assert.same({}, defs,
            "call parley.resolve_chat_path directly; a local wrapper by this name is "
            .. "how the second resolver hid in plain sight")
    end)

    it("every module that reads a chat reference resolves it through resolve_chat_path", function()
        -- The class, stated positively: if a module pulls `.path` off a parsed
        -- chat reference, it must reach the one resolver.
        local READS = { "parent_link.path", "branch.path", "link.path" }
        -- annotation.lua matches on the LINE text (is this an annotation?) and
        -- never resolves — it has no business calling a resolver.
        local NO_RESOLVE = { ["lua/parley/annotation.lua"] = "matches line text; never resolves a path" }

        local offenders = {}
        for _, file in ipairs(repo_lua_files()) do
            local body = table.concat(lines_of(file), "\n")
            local reads = false
            for _, r in ipairs(READS) do
                if body:find(r, 1, true) then reads = true end
            end
            if reads and not NO_RESOLVE[file]
                and not body:find("resolve_chat_path", 1, true) then
                offenders[#offenders + 1] = file
            end
        end
        assert.same({}, offenders,
            "this module reads a chat reference's path but never reaches resolve_chat_path")
    end)
end)
