-- #401: a spec that drives a child nvim does it through
-- tests/helpers/embedded_nvim.lua, whose every request is bounded and fails
-- naming its method. A raw vim.rpcrequest has no deadline: a wedged child
-- stalls its case silently until the harness's idle kill, which names no cause.
local arch = require("tests.arch.arch_helper")

local SCOPE = { "tests/*.lua" } -- git pathspec: * crosses /
local HELPER = "tests/helpers/embedded_nvim.lua"
local RAW = { "rpcrequest%(", "['\"]%-%-embed['\"]" }

local function scan(visit)
    for _, file in ipairs(arch.worktree_files(SCOPE)) do
        if not vim.endswith(file, HELPER) and not vim.endswith(file, "tests/arch/embedded_rpc_spec.lua") then
            for n, line in ipairs(vim.fn.readfile(file)) do
                for _, pattern in ipairs(RAW) do
                    if not line:match("^%s*%-%-") and line:find(pattern) then visit(file, n, line) end
                end
            end
        end
    end
end

describe("arch: embedded nvim requests go through the bounded helper (#401)", function()
    it("scans the suite, including the helper's own users", function()
        local users = 0
        for _, file in ipairs(arch.worktree_files(SCOPE)) do
            for _, line in ipairs(vim.fn.readfile(file)) do
                if line:find("tests.helpers.embedded_nvim", 1, true) then users = users + 1; break end
            end
        end
        -- A floor, so a scope that stopped matching cannot pass vacuously
        -- (nine specs on 2026-10-19).
        assert.is_true(users >= 9, "found only " .. users .. " helper users")
    end)

    it("starts and drives no child nvim outside the helper", function()
        local raw = {}
        scan(function(file, n, line) raw[#raw + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line)) end)
        assert.same({}, raw, "drive a child nvim with require('tests.helpers.embedded_nvim').start()")
    end)
end)
