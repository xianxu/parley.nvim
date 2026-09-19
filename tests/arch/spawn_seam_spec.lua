-- #261 M3 review BR-40 and BR-38: the process seam, as executable enumerations.
--
-- The atlas says how a process started through `tasker.run` is stopped
-- (atlas/providers/tool_execution.md#stopping-a-process). A statement about
-- every process needs a list of every process, so this file is that list:
-- each spawn outside tasker is named here with how it ends, and a new one
-- fails until it is routed through tasker or added with its reason. Each entry
-- is an exact count, so an entry whose spawn was removed fails too.
--
-- Two rules ride on the same seam: a deadline is a `tasker.deadline` kind, not
-- a literal; and an exit callback renders how its run ended through
-- `tasker.exit_reason`, since `code` is nil whenever `io_error` says why.
local arch = require("tests.arch.arch_helper")

-- `uv.spawn` also matches when passed as a value, e.g. `pcall(run_uv.spawn, …)`.
local SPAWN = { "uv%.spawn[%s%(,]", "vim%.system%(", "jobstart%(", "vim%.fn%.system%(", "vim%.fn%.systemlist%(",
    "io%.popen%(", "os%.execute%(", "termopen%(" }

local function spawns(line)
    if line:match("^%s*%-%-") then return 0 end
    local count = 0
    for _, pattern in ipairs(SPAWN) do
        for _ in line:gmatch(pattern) do count = count + 1 end
    end
    return count
end

-- file -> {count, reason}. "Synchronous" means the call waits for the process,
-- so it ends before Neovim can do anything else, and cannot outlive the call.
local OUTSIDE = {
    ["lua/parley/cliproxy.lua"] = { 15, "the managed proxy: spawned detached and unref'd so it outlives Neovim"
        .. " by design; its admin calls, probes and downloads carry curl or vim.system timeouts" },
    ["lua/parley/git_markdown_source.lua"] = { 1, "a bounded `git show` read with its own cancel" },
    ["lua/parley/issues.lua"] = { 1, "`sdlc issue new`, an explicit user command reporting its exit" },
    ["lua/parley/oauth.lua"] = { 1, "opens the browser for an OAuth login, detached, fire-and-forget" },
    ["lua/parley/clipboard_image.lua"] = { 1, "a clipboard read with a vim.system timeout" },
    ["lua/parley/artifact_ref.lua"] = { 1, "an artifact lookup for a user command, reporting its exit" },
    ["lua/parley/exporter.lua"] = { 2, "an export command and revealing its output, user-invoked" },
    ["lua/parley/image_shrink.lua"] = { 1, "synchronous" },
    ["lua/parley/init.lua"] = { 1, "synchronous" },
    ["lua/parley/render_buffer.lua"] = { 1, "synchronous" },
    ["lua/parley/log_emit.lua"] = { 1, "synchronous" },
    ["lua/parley/memory_prefs.lua"] = { 1, "synchronous" },
    ["lua/parley/discovery/local_types.lua"] = { 1, "synchronous" },
    ["lua/parley/tools/builtin/ls.lua"] = { 1, "synchronous fallback outside the async tool path" },
    ["lua/parley/tools/builtin/find.lua"] = { 1, "synchronous fallback outside the async tool path" },
    ["lua/parley/tools/builtin/grep.lua"] = { 1, "synchronous fallback outside the async tool path" },
    ["lua/parley/tools/builtin/ack.lua"] = { 1, "synchronous fallback outside the async tool path" },
    ["lua/parley/tools/builtin/chat_history_search.lua"] = { 1, "synchronous fallback outside the async tool path" },
}
local SEAM = "lua/parley/tasker.lua"

local function census(count_line)
    local found = {}
    for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
        local count = 0
        for _, line in ipairs(vim.fn.readfile(file)) do count = count + count_line(line) end
        if count > 0 then found[file] = count end
    end
    return found
end

describe("arch: every process has a named end", function()
    it("the census finds the seam, so it cannot pass vacuously", function()
        assert.equals(1, census(spawns)[SEAM])
    end)

    it("spawns outside tasker are exactly the reasoned list", function()
        local found = census(spawns)
        local problems = {}
        for file, count in pairs(found) do
            local entry = OUTSIDE[file]
            if file ~= SEAM and not entry then
                problems[#problems + 1] = file .. ": " .. count .. " spawn(s) outside tasker; route them through"
                    .. " tasker.run, or list them here with how they end"
            elseif entry and entry[1] ~= count then
                problems[#problems + 1] = file .. ": " .. count .. " spawn(s), listed as " .. entry[1]
            end
        end
        for file, entry in pairs(OUTSIDE) do
            if not found[file] then problems[#problems + 1] = file .. ": listed, but spawns nothing now" end
            assert.is_true(type(entry[2]) == "string" and #entry[2] > 0, file .. " needs its reason")
        end
        table.sort(problems)
        assert.same({}, problems)
    end)

    it("and would catch a new one (counterfactual)", function()
        assert.equals(1, spawns('    local job = vim.fn.jobstart({ "x" })'))
        assert.equals(0, spawns("    -- vim.system(argv) in a comment"))
        assert.equals(2, spawns("vim.system(a); uv.spawn(b, {})"))
        assert.equals(1, spawns("local ok = pcall(run_uv.spawn, cmd, {})"))
    end)
end)

describe("arch: a deadline is a tasker.deadline kind", function()
    local function literal(line)
        if line:match("^%s*%-%-") then return 0 end
        return line:find("deadline_ms%s*=%s*%d") and 1 or 0
    end
    it("no deadline_ms is a numeric literal in lua/", function()
        assert.same({}, census(literal))
        assert.equals(1, literal("{ deadline_ms = 60000 }"), "counterfactual")
    end)
end)

describe("arch: an exit callback renders how its run ended through tasker.exit_reason", function()
    -- A module that hands callbacks to tasker. `tostring(<...>code)` there would
    -- print "nil" for a kill; exit_reason prints its io_error instead.
    local function raw(line)
        if line:match("^%s*%-%-") then return 0 end
        local count = 0
        for _ in line:gmatch("tostring%(%s*[%w_]*code%d*%s*%)") do count = count + 1 end
        return count
    end
    -- The dispatcher's structured failure diagnostic prints code beside io_error.
    local ALLOWED = { ["lua/parley/dispatcher.lua"] = 1 }
    it("finds no raw exit code rendered where tasker's callbacks land", function()
        local problems = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            local lines = vim.fn.readfile(file)
            local text = table.concat(lines, "\n")
            if file ~= SEAM and (text:find("tasker.run(", 1, true) or text:find("Tasker.run(", 1, true)) then
                local count = 0
                for _, line in ipairs(lines) do count = count + raw(line) end
                if count ~= (ALLOWED[file] or 0) then
                    problems[#problems + 1] = file .. ": " .. count .. " raw code render(s), allowed "
                        .. (ALLOWED[file] or 0)
                end
            end
        end
        assert.same({}, problems)
        assert.equals(1, raw('msg = "failed (exit " .. tostring(exit_code) .. ")"'), "counterfactual")
    end)
end)
