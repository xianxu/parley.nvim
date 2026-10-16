-- #265: one refusal policy for every user edit a chat command makes.
--
-- `buffer_edit.edit_user_lines(command, …)` is the only way a command edits
-- the user's chat: a refusal leaves the buffer unchanged and is reported once,
-- naming the command, in parley.refusal's words — never a bare Lua error. The
-- raw replace (`_replace_user_lines`) is private to buffer_edit.lua, and the
-- policy never raises, so a pcall around it is either dead or a second policy.
local arch = require("tests.arch.arch_helper")

describe("arch: user edit refusal policy", function()
    it("no call site reaches the raw replace outside buffer_edit.lua", function()
        arch.assert_pattern_scoping({
            pattern = "replace_user_lines",
            scope = "lua/**/*.lua",
            allow_only_in = { "lua/parley/buffer_edit.lua" },
        })
    end)

    it("no call site wraps the edit API in its own pcall", function()
        local offenders, policy_sites = {}, 0
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            for n, line in ipairs(vim.fn.readfile(file)) do
                if not line:match("^%s*%-%-") then
                    if line:find("edit_user_lines(", 1, true) then policy_sites = policy_sites + 1 end
                    if line:match("pcall%s*%(%s*[%w_.]*edit_user_lines") or line:match("pcall%s*%(%s*[%w_.]*replace_user_lines") then
                        offenders[#offenders + 1] = file .. ":" .. n
                    end
                end
            end
        end
        -- The selection guard: the audit counted 17 call sites (#265). A scan
        -- that finds none is broken, not clean.
        assert.is_true(policy_sites >= 17, ("found only %d edit_user_lines sites"):format(policy_sites))
        assert.same({}, offenders, "the policy reports refusals itself; do not catch them again")
    end)

    it("the raw replace no longer raises its refusals", function()
        local src = table.concat(vim.fn.readfile("lua/parley/buffer_edit.lua"), "\n")
        assert.is_nil(src:find('error("User edit', 1, true), "a refusal must be returned, not raised")
    end)
end)
