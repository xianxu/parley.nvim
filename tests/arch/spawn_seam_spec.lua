-- #261 M3 review BR-40, BR-45, BR-46: the process seam, as executable
-- enumerations.
--
-- The atlas says how a process started through `tasker.run` is stopped
-- (atlas/providers/tool_execution.md#stopping-a-process). A statement about
-- every process needs a list of every process, so this file is that list: every
-- spawn outside tasker is classified from its own call form, and the count per
-- class is declared per file. A new spawn fails until it is routed through
-- tasker or declared; a declared spawn that no longer exists fails too.
--
-- The classification is derived, not asserted in prose (BR-46):
--   * `sync` — the call waits (`vim.fn.system*`, `io.popen`, `os.execute`, or
--     `vim.system(…):wait()`), so the process cannot outlive the call.
--   * `bounded` — the call carries `timeout =` or `--max-time`, directly or
--     through a declared argv helper whose own body carries the bound.
--   * `delegated` — the spawn sits in a declared wrapper whose argv is its
--     caller's; every call site of that wrapper must then carry the bound.
--   * `open` — none of those. Only these need a reason, and it is what the
--     atlas defers to.
--
-- Two more rules ride on the same seam: a deadline is a `tasker.deadline` kind,
-- not a literal; and how a run ended is rendered once, by `tasker.exit_reason`,
-- since `code` is nil whenever `io_error` says why.
--
-- What the matchers cannot see (the `single_source_sweeps_spec` convention):
-- a spawn behind a variable (`local spawn = uv.spawn`), a bound passed as a
-- computed value, a code rendered under another name or through
-- `string.format`, and a `.code` read off a table this file does not name.
local arch = require("tests.arch.arch_helper")

local SPAWN = { "uv%.spawn[%s%(,]", "vim%.system%(", "jobstart%(", "vim%.fn%.system%(", "vim%.fn%.systemlist%(",
    "io%.popen%(", "os%.execute%(", "termopen%(" }
local WAITS = { "vim%.fn%.system%(", "vim%.fn%.systemlist%(", "io%.popen%(", "os%.execute%(" }
local SEAM = "lua/parley/tasker.lua"

-- An argv helper that adds the bound itself, so a call through it is bounded.
-- Its own definition must carry the bound; the test checks that too.
local HELPERS = { ["lua/parley/cliproxy.lua"] = { "api_argv%(" } }

-- A wrapper that spawns its caller's argv. Every call site must carry the bound;
-- the test checks each one.
local DELEGATES = { ["lua/parley/cliproxy.lua"] = { "run" } }

-- file -> per-class counts, plus `why` for the open ones (required iff open > 0).
local OUTSIDE = {
    ["lua/parley/cliproxy.lua"] = { sync = 9, bounded = 3, delegated = 1, open = 2,
        why = "the managed proxy, spawned detached and unref'd so it outlives Neovim by design; and the login"
            .. " helper, which the login UI stops with jobstop when the operator closes it" },
    ["lua/parley/git_markdown_source.lua"] = { open = 1,
        why = "the markdown finder's `git ls-files --cached --others --exclude-standard`: its caller cancels"
            .. " it with one SIGTERM, with no timer and no escalation" },
    ["lua/parley/issues.lua"] = { open = 1, why = "`sdlc issue new`, user-invoked, reporting its own exit" },
    ["lua/parley/oauth.lua"] = { open = 1, why = "opens the browser for an OAuth login, detached and fire-and-forget" },
    ["lua/parley/artifact_ref.lua"] = { open = 1,
        why = "an `sdlc` reference lookup for a user command, reporting its own exit" },
    ["lua/parley/exporter.lua"] = { open = 2,
        why = "a pandoc export and revealing its output, user-invoked, each reporting its own exit" },
    ["lua/parley/clipboard_image.lua"] = { bounded = 1 },
    ["lua/parley/image_shrink.lua"] = { sync = 1 },
    ["lua/parley/init.lua"] = { sync = 1 },
    ["lua/parley/render_buffer.lua"] = { sync = 1 },
    ["lua/parley/log_emit.lua"] = { sync = 1 },
    ["lua/parley/memory_prefs.lua"] = { sync = 1 },
    ["lua/parley/discovery/local_types.lua"] = { sync = 1 },
    ["lua/parley/tools/builtin/ls.lua"] = { sync = 1 },
    ["lua/parley/tools/builtin/find.lua"] = { sync = 1 },
    ["lua/parley/tools/builtin/grep.lua"] = { sync = 1 },
    ["lua/parley/tools/builtin/ack.lua"] = { sync = 1 },
    ["lua/parley/tools/builtin/chat_history_search.lua"] = { sync = 1 },
}

-- A file's text with comment lines blanked, so line numbers still line up.
local function source(file)
    local kept = {}
    for _, line in ipairs(vim.fn.readfile(file)) do kept[#kept + 1] = line:match("^%s*%-%-") and "" or line end
    return table.concat(kept, "\n")
end

-- The call that starts at `from`: its own text up to the matching close paren,
-- and the few characters after it (where `:wait()` would be). Quoted strings are
-- skipped, so a paren inside an argument cannot unbalance it.
local function call_at(text, from)
    local depth, i, n = 0, from, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == '"' or c == "'" then
            local quote = c
            i = i + 1
            while i <= n do
                local d = text:sub(i, i)
                if d == "\\" then i = i + 1 elseif d == quote then break end
                i = i + 1
            end
        elseif c == "(" then depth = depth + 1
        elseif c == ")" then
            depth = depth - 1
            if depth == 0 then return text:sub(from, i), text:sub(i + 1, i + 12) end
        end
        i = i + 1
    end
    return text:sub(from, math.min(n, from + 512)), ""
end

-- The function a position sits in: the nearest definition above it.
local function enclosing(text, from)
    local name
    for candidate in text:sub(1, from):gmatch("function%s+([%w_%.:]+)%s*%(") do name = candidate end
    return name
end

local function classify(file, text, from, head)
    local call, after = call_at(text, from)
    for _, pattern in ipairs(WAITS) do if head:find(pattern) then return "sync" end end
    if after:find("^:wait%(") then return "sync" end
    if call:find("timeout%s*=") or call:find("%-%-max%-time") then return "bounded" end
    for _, helper in ipairs(HELPERS[file] or {}) do if call:find(helper) then return "bounded" end end
    local inside = enclosing(text, from)
    for _, delegate in ipairs(DELEGATES[file] or {}) do if inside == delegate then return "delegated" end end
    return "open"
end

-- file -> {sync = n, bounded = n, open = n}, counting every spawn in lua/.
local function census()
    local found = {}
    for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
        local text = source(file)
        for _, pattern in ipairs(SPAWN) do
            local init = 1
            while true do
                local from, stop = text:find(pattern, init)
                if not from then break end
                init = stop
                local class = classify(file, text, from, text:sub(from, stop))
                found[file] = found[file] or {}
                found[file][class] = (found[file][class] or 0) + 1
            end
        end
    end
    return found
end

describe("arch: every process has a named end", function()
    local found = census()

    it("the census finds the seam, so it cannot pass vacuously", function()
        assert.same({ open = 1 }, found[SEAM], "tasker's own spawn")
    end)

    it("classifies each spawn from its call form, and would catch a new one", function()
        local text = table.concat({
            'local a = vim.system({ "x" }):wait()',
            'local b = vim.system({ "x" }, { timeout = 10 }, cb)',
            'local c = vim.system({ "curl", "--max-time", "5" }, {}, cb)',
            'local d = vim.system({ "x" }, { text = true }, cb)',
            'local e = vim.fn.system({ "x" })',
            'local f = vim.system(api_argv(host, port), {}, cb)',
        }, "\n")
        local classes = {}
        local init = 1
        while true do
            local from, stop = text:find("vim%.[%w_]*%.?system%(", init)
            if not from then break end
            init = stop
            classes[#classes + 1] = classify("lua/parley/cliproxy.lua", text, from, text:sub(from, stop))
        end
        assert.same({ "sync", "bounded", "bounded", "open", "sync", "bounded" }, classes)
        -- A spawn inside a declared wrapper is delegated to its call sites.
        local wrapped = "function run(argv, cb)\n    vim.system(argv, { text = true }, cb)\nend"
        local from, stop = wrapped:find("vim%.system%(")
        assert.equals("delegated", classify("lua/parley/cliproxy.lua", wrapped, from, wrapped:sub(from, stop)))
    end)

    it("every call site of a declared wrapper carries the bound", function()
        for file, delegates in pairs(DELEGATES) do
            local text = source(file)
            for _, delegate in ipairs(delegates) do
                local sites, init = 0, 1
                while true do
                    local from, stop = text:find("[^%w_.]" .. delegate .. "%(", init)
                    if not from then break end
                    init = stop
                    if enclosing(text, from) ~= delegate then -- not its own definition
                        sites = sites + 1
                        local window = text:sub(math.max(1, from - 600), stop)
                        local bounded = window:find("%-%-max%-time") ~= nil
                        for _, helper in ipairs(HELPERS[file] or {}) do
                            if window:find(helper) then bounded = true end
                        end
                        assert.is_true(bounded, ("%s: a call of %s() near byte %d passes an unbounded argv")
                            :format(file, delegate, from))
                    end
                end
                assert.is_true(sites > 0, file .. ": " .. delegate .. " is declared as a wrapper but never called")
            end
        end
    end)

    it("an argv helper declared as bounding carries the bound itself", function()
        for file, helpers in pairs(HELPERS) do
            local text = source(file)
            for _, helper in ipairs(helpers) do
                local name = helper:gsub("%%%(", "")
                local from = text:find("function " .. name .. "%(")
                assert.is_truthy(from, file .. ": " .. name .. " is declared as bounding but is not defined here")
                local body = call_at(text, text:find("%(", from))
                local tail = text:sub(from, from + 800)
                assert.is_truthy(tail:find("%-%-max%-time") or tail:find("timeout%s*="),
                    file .. ": " .. name .. " is declared as bounding but adds no bound (" .. #body .. ")")
            end
        end
    end)

    it("spawns outside tasker are exactly the declared classes", function()
        local problems = {}
        for file, classes in pairs(found) do
            local entry = OUTSIDE[file]
            if file ~= SEAM and not entry then
                problems[#problems + 1] = file .. ": " .. vim.inspect(classes):gsub("%s+", " ")
                    .. " spawn(s) outside tasker; route them through tasker.run, or declare them here"
            elseif entry then
                for _, class in ipairs({ "sync", "bounded", "delegated", "open" }) do
                    if (classes[class] or 0) ~= (entry[class] or 0) then
                        problems[#problems + 1] = ("%s: %d %s spawn(s), declared %d"):format(
                            file, classes[class] or 0, class, entry[class] or 0)
                    end
                end
            end
        end
        for file, entry in pairs(OUTSIDE) do
            if not found[file] then problems[#problems + 1] = file .. ": declared, but spawns nothing now" end
            if (entry.open or 0) > 0 then
                assert.is_true(type(entry.why) == "string" and #entry.why > 0,
                    file .. " has an open spawn and needs its reason")
            else
                assert.is_nil(entry.why, file .. " has no open spawn, so its reason is dead prose")
            end
        end
        table.sort(problems)
        assert.same({}, problems)
    end)
end)

describe("arch: a deadline is a tasker.deadline kind", function()
    it("no deadline_ms is a numeric literal in lua/", function()
        local found = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            for i, line in ipairs(vim.fn.readfile(file)) do
                if not line:match("^%s*%-%-") and line:find("deadline_ms%s*=%s*%d") then
                    found[#found + 1] = file .. ":" .. i
                end
            end
        end
        assert.same({}, found)
    end)
end)

describe("arch: how a run ended is rendered once", function()
    -- Anchored on the value, not on one function's callers (BR-45): a raw exit
    -- code reaches a module either as a tasker callback argument, or on the
    -- dispatcher's failure table.
    local function raw_argument(line)
        if line:match("^%s*%-%-") then return 0 end
        local count = 0
        for _ in line:gmatch("tostring%(%s*[%w_]*code%d*%s*%)") do count = count + 1 end
        return count
    end
    -- The dispatcher renders the transport's end into `failure.exit`; the raw
    -- code is not on the table, so a read of it is a consumer that would print
    -- "nil" for every kill.
    local FIELDS = { "failure%.code", "failure%.signal", "failure%.io_error" }

    it("no module renders a tasker exit code itself", function()
        local problems = {}
        local ALLOWED = { ["lua/parley/dispatcher.lua"] = 1 } -- its structured log, beside io_error
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            local lines = vim.fn.readfile(file)
            local text = table.concat(lines, "\n")
            if file ~= SEAM and (text:find("tasker.run(", 1, true) or text:find("Tasker.run(", 1, true)) then
                local count = 0
                for _, line in ipairs(lines) do count = count + raw_argument(line) end
                if count ~= (ALLOWED[file] or 0) then
                    problems[#problems + 1] = ("%s: %d raw code render(s), allowed %d"):format(
                        file, count, ALLOWED[file] or 0)
                end
            end
            for i, line in ipairs(lines) do
                for _, field in ipairs(FIELDS) do
                    if not line:match("^%s*%-%-") and line:find(field) then
                        problems[#problems + 1] = file .. ":" .. i
                            .. " reads a raw transport field off the failure table; read `failure.exit`"
                    end
                end
            end
        end
        table.sort(problems)
        assert.same({}, problems)
    end)

    it("and would catch either form (counterfactual)", function()
        assert.equals(1, raw_argument('msg = "failed (exit " .. tostring(exit_code) .. ")"'))
        assert.equals(0, raw_argument("-- tostring(code) in a comment"))
        assert.is_truthy(('m = m .. " (exit " .. tostring(failure.code) .. ")"'):find(FIELDS[1]))
    end)
end)
