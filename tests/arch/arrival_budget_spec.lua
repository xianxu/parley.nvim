-- #374 (the #370 lesson): a positive wait returns the moment its outcome
-- arrives, so a short literal bound only turns machine load into a flake. Every
-- `vim.wait(<literal>, <predicate>)` in the suite's specs is therefore either
-- bounded by tests/helpers/arrival.lua's MS (or a product deadline the spec
-- observes), or carries a trailing reason on its own line:
--   -- absence: <reason>  the spec expects the predicate to stay false here
--   -- drain: <reason>    best-effort teardown; nothing is asserted on it
--   -- bound: <reason>    the bound itself is the property under test
-- A plain sleep (`vim.wait(N)`, or a `return false` predicate) needs no reason.
-- Whatever form the wait takes (asserted, bare, or assigned to a local), the
-- rule reads the line that opens it.
local arch = require("tests.arch.arch_helper")

local SCOPE = { "tests/unit/*_spec.lua", "tests/integration/*_spec.lua" } -- git pathspec: * crosses /
local REASON = { "%-%- absence: %S", "%-%- drain: %S", "%-%- bound: %S" }

local function scan(visit)
    for _, file in ipairs(arch.worktree_files(SCOPE)) do
        for n, line in ipairs(vim.fn.readfile(file)) do
            if not line:match("^%s*%-%-") then
                local bound, rest = line:match("vim%.wait%(%s*([^,%)]+)%s*,%s*(.*)$")
                if bound and not rest:match("^function%s*%(%s*%)%s*return%s+false%s+end") then
                    visit(file, n, line, vim.trim(bound))
                end
            end
        end
    end
end

local function reasoned(line)
    for _, pattern in ipairs(REASON) do
        if line:find(pattern) then return true end
    end
    return false
end

describe("arch: predicate waits use the arrival budget or say why not (#374)", function()
    it("finds the waits it checks", function()
        local count = 0
        scan(function() count = count + 1 end)
        -- A floor, so a pattern that stopped matching cannot pass vacuously
        -- (about 460 predicate waits on 2026-10-17).
        assert.is_true(count >= 400, "found only " .. count .. " predicate waits")
    end)

    it("bounds none of them with an unexplained literal", function()
        local literal = {}
        scan(function(file, n, line, bound)
            if bound:match("^[%d_]+$") and not reasoned(line) then
                literal[#literal + 1] = ("%s:%d: %s"):format(file, n, vim.trim(line))
            end
        end)
        assert.same({}, literal, "a predicate wait takes require('tests.helpers.arrival').MS (or a product deadline),"
            .. " or a trailing '-- absence:', '-- drain:' or '-- bound:' reason")
    end)
end)
