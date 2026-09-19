-- #261 M2 review: a function that reports whether its effect happened is marked
-- `---@nodiscard` (the LuaLS annotation for exactly this), and every call must
-- consume the result — the family where a dropped "did it happen?" let the
-- prompt editor announce a save that had not happened (BR-14), and where a
-- guard listing functions by name missed each new one (BR-24). Members are
-- selected by the annotation, the class property, not by spelling.
--
-- A call is matched through the calling file's own `require` aliases (plus the
-- declared injected handles below), so `table.remove(t)` is never mistaken for
-- `custom_prompts.remove(name)`. A bare-statement call is allowed only where
-- DROPPED names the file, the callee, exactly how many such calls, and why.
--
-- Statement heads it sees: the start of a line, and what follows `then`, `do`,
-- `else` or `;` on it; a bare `pcall`/`xpcall` whose first argument is the
-- member. What it cannot see, stated so it is not mistaken for more: a module
-- re-aliased by assignment (`local cp = custom_prompts`), a method call with
-- `:`, a call whose member access starts on an earlier line, and a result
-- dropped inside another higher-order function.
local arch = require("tests.arch.arch_helper")

-- Handles that reach a module without a `require` in the calling file.
local INJECTED = {
    ["helpers"] = "parley.helper", ["_helpers"] = "parley.helper",
    ["M.helpers"] = "parley.helper", ["_parley.helpers"] = "parley.helper",
}
local DROPPED = {
    ["lua/parley/vault.lua"] = { ["helpers.table_to_file"] = { count = 1,
        why = "the copilot bearer cache; a failed write re-fetches, and table_to_file has warned" } },
    ["lua/parley/chat_respond.lua"] = {
        ["_parley.helpers.table_to_file"] = { count = 1,
            why = "the remote-reference cache; a failed write re-fetches, and table_to_file has warned" },
        ["D.set_previous_answer"] = { count = 1,
            why = "false means the generation already lost its grant on the exchange; the transcript is then the right context, and nothing waits on the slot" },
    },
}

local function module_of(file)
    return (file:gsub("^lua/", ""):gsub("%.lua$", ""):gsub("/init$", ""):gsub("/", "."))
end

local function annotated()
    local out = {}
    for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
        local lines = vim.fn.readfile(file)
        for i, line in ipairs(lines) do
            if line:match("^%s*%-%-%-%s*@nodiscard") then
                for j = i + 1, math.min(#lines, i + 8) do
                    local name = lines[j]:match("^%s*function%s+[%w_]+[.:]([%w_]+)%s*%(")
                        or lines[j]:match("^%s*[%w_]+%.([%w_]+)%s*=%s*function")
                    if name then out[module_of(file) .. "." .. name] = file; break end
                end
            end
        end
    end
    return out
end

describe("arch: a did-it-happen result is consumed", function()
    local marked = annotated()

    it("finds the annotated functions", function()
        for _, required in ipairs({ "parley.helper.table_to_file", "parley.custom_prompts.set",
            "parley.document.set_previous_answer" }) do
            assert.is_not_nil(marked[required], required .. " is not marked ---@nodiscard")
        end
    end)

    it("never drops one as a bare statement unless declared", function()
        local offenders, seen = {}, {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            local lines = vim.fn.readfile(file)
            local alias = { M = module_of(file) }
            for _, line in ipairs(lines) do
                local a, mod = line:match("^%s*local%s+([%w_]+)%s*=%s*require%(%s*[\"']([%w_.]+)[\"']%s*%)")
                if a then alias[a] = mod end
            end
            for n, line in ipairs(lines) do
                if not line:match("^%s*%-%-") and not line:match("^%s*function") then
                    -- Every statement head on the line.
                    local heads = { line }
                    for _, word in ipairs({ "then", "do", "else" }) do
                        for rest in line:gmatch("%f[%w]" .. word .. "%f[%W](.*)") do heads[#heads + 1] = rest end
                    end
                    for rest in line:gmatch(";(.*)") do heads[#heads + 1] = rest end
                    for _, head in ipairs(heads) do
                        local body = head:match("^%s*x?pcall%(%s*(.*)") or head
                        local prefix, name = body:match("^%s*([%w_.]+)%.([%w_]+)%s*[(,)]")
                        local req, rname = body:match("^%s*require%(%s*[\"']([%w_.]+)[\"']%s*%)%.([%w_]+)%s*[(,)]")
                        local mod = req or (prefix and (alias[prefix] or INJECTED[prefix]))
                        name = rname or name
                        if mod and marked[mod .. "." .. name] then
                            local callee = (req and ("require('" .. req .. "')") or prefix) .. "." .. name
                            local key = file .. "|" .. callee
                            seen[key] = (seen[key] or 0) + 1
                            local declared = DROPPED[file] and DROPPED[file][callee]
                            if not declared or seen[key] > declared.count then
                                offenders[#offenders + 1] = file .. ":" .. n .. " " .. callee
                            end
                        end
                    end
                end
            end
        end
        assert.same({}, offenders, "consume the result, or declare the call in DROPPED with why")
        -- A declaration outlives the call it excuses only if nothing checks it.
        local stale = {}
        for file, calls in pairs(DROPPED) do
            for callee, declared in pairs(calls) do
                local got = seen[file .. "|" .. callee] or 0
                if got ~= declared.count then
                    stale[#stale + 1] = file .. " " .. callee .. ": declared " .. declared.count .. ", found " .. got
                end
            end
        end
        table.sort(stale)
        assert.same({}, stale, "DROPPED must match the calls it excuses exactly")
    end)
end)
