-- #261 M1 review BR-16: every vim.json.decode in lua/ decodes input from
-- another process, version, network or crash, and must not raise into its
-- caller. A raise inside a transport callback strands the continuation it was
-- meant to resume. So each decode is guarded by pcall — on its own line, or
-- inside a `pcall(function` opened within the three lines before it.
local arch = require("tests.arch.arch_helper")

describe("arch: JSON from outside the process is decoded under pcall", function()
    it("finds the decodes it checks", function()
        local count = 0
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            for _, line in ipairs(vim.fn.readfile(file)) do
                if line:find("vim.json.decode", 1, true) and not line:match("^%s*%-%-") then count = count + 1 end
            end
        end
        -- A floor, so a pattern that stopped matching cannot pass vacuously
        -- (33 decodes on 2026-09-19).
        assert.is_true(count >= 30, "found only " .. count .. " decodes")
    end)

    it("guards every decode", function()
        local unguarded = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            local lines = vim.fn.readfile(file)
            for i, line in ipairs(lines) do
                if line:find("vim.json.decode", 1, true) and not line:match("^%s*%-%-") then
                    local window = table.concat(lines, "\n", math.max(1, i - 3), i)
                    if not line:find("pcall", 1, true) and not window:find("pcall(function", 1, true) then
                        unguarded[#unguarded + 1] = file .. ":" .. i
                    end
                end
            end
        end
        assert.same({}, unguarded, "decode external JSON under pcall and treat a failure as missing input")
    end)
end)
