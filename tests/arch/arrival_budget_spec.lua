-- #374 (the #370 lesson): a positive wait, one asserted true, returns the
-- moment its outcome arrives, so a short literal bound only turns machine load
-- into a flake. Each one in the suite's specs is bounded by
-- tests/helpers/arrival.lua's MS, or by a product deadline the spec observes.
-- A wait whose bound is the property under test keeps its literal with a
-- trailing `-- bound: <reason>` comment. The rule reads the three assert forms;
-- a wait assigned to a local and asserted later is out of its reach.
local arch = require("tests.arch.arch_helper")

local FORMS = { "assert%.is_true%(%s*vim%.wait%(%s*", "assert%.truthy%(%s*vim%.wait%(%s*", "assert%(%s*vim%.wait%(%s*" }
local SCOPE = { "tests/unit/*_spec.lua", "tests/integration/*_spec.lua" } -- git pathspec: * crosses /

local function scan(visit)
    for _, file in ipairs(arch.worktree_files(SCOPE)) do
        for n, line in ipairs(vim.fn.readfile(file)) do
            if not line:match("^%s*%-%-") then
                for _, form in ipairs(FORMS) do
                    local bound = line:match(form .. "([^,]+),")
                    if bound then visit(file, n, line, vim.trim(bound)) break end
                end
            end
        end
    end
end

describe("arch: positive waits use the arrival budget (#374)", function()
    it("finds the waits it checks", function()
        local count = 0
        scan(function() count = count + 1 end)
        -- A floor, so a pattern that stopped matching cannot pass vacuously
        -- (275 waits on 2026-10-17).
        assert.is_true(count >= 250, "found only " .. count .. " positive waits")
    end)

    it("bounds none of them with a bare literal", function()
        local literal = {}
        scan(function(file, n, line, bound)
            if bound:match("^[%d_]+$") and not line:find("%-%- bound: %S") then
                literal[#literal + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
            end
        end)
        assert.same({}, literal, "a positive wait takes require('tests.helpers.arrival').MS (or a product deadline),"
            .. " or a trailing '-- bound: <reason>' when the bound is what the spec tests")
    end)
end)
