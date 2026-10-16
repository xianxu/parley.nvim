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

    -- #265 close BR-2: the policy is the WORDS as well as the entry point. A
    -- command that captures and applies by hand (multi-region, deferred, or
    -- held across a lookup) must still report through buffer_edit.report_refusal
    -- or refusal.edit. Every file that calls the capture/apply API directly is
    -- named here with its reason, so a new direct caller is a finding until
    -- someone decides which side of the policy it is on.
    local DIRECT = {
        -- Keystroke commands: report through report_refusal / refusal.edit.
        ["lua/parley/init.lua"] = "commands needing multi-region, deferred or held captures",
        ["lua/parley/interview.lua"] = "the interview timestamp keystroke",
        ["lua/parley/spell_source.lua"] = "the spell correction completion",
        ["lua/parley/chat_finder.lua"] = "the picker's reference insert, held across the picker",
        ["lua/parley/paste_image.lua"] = "the image paste, held across the clipboard read",
        -- Not chat commands: their refusals have their own channel.
        ["lua/parley/chat_respond.lua"] = "the respond pipeline's own captures, worded by refuse()",
        ["lua/parley/response_target.lua"] = "generation target guards, worded by the respond pipeline",
        ["lua/parley/skill_invoke.lua"] = "the skill pipeline's source authority, worded by its own refuse",
        ["lua/parley/tools/file_refresh.lua"] = "a tool's buffer refresh; its result is the tool's",
        ["lua/parley/highlighter.lua"] = "the background branch-topic refresh; silent by design, the next refresh retries",
        ["lua/parley/response_topic.lua"] = "the automatic topic generator's guards; its caller words the outcome",
    }
    local KEYSTROKE = { "lua/parley/init.lua", "lua/parley/interview.lua", "lua/parley/spell_source.lua",
        "lua/parley/chat_finder.lua", "lua/parley/paste_image.lua" }
    local DIRECT_CALL = { "capture_user%(", "apply_user%(", "apply_user_line_hunks%(" }
    -- A refusal worded by hand: a warning or notice built from the raw reason.
    local function hand_worded(line)
        return line:find("warning(", 1, true) or line:find("notify(", 1, true)
    end
    local function worded_by_hand(line)
        if not hand_worded(line) then return false end
        return line:find("tostring%(%s*[%w_]*reason") or line:find("tostring%(%s*capture_error")
            or line:find("tostring%(%s*why") or line:find("tostring%(%s*stale")
            or line:find("%.reason%s+or") or line:find("%.error%s+or")
    end

    it("names every file that calls the capture/apply API directly", function()
        local found = {}
        for _, file in ipairs(arch.worktree_files({ "lua/**/*.lua" })) do
            if file ~= "lua/parley/buffer_edit.lua" and not file:match("^lua/parley/document/") then
                for _, line in ipairs(vim.fn.readfile(file)) do
                    if not line:match("^%s*%-%-") then
                        for _, pat in ipairs(DIRECT_CALL) do
                            if line:find(pat) then found[file] = true end
                        end
                    end
                end
            end
        end
        local unnamed, stale = {}, {}
        for file in pairs(found) do if not DIRECT[file] then unnamed[#unnamed + 1] = file end end
        for file in pairs(DIRECT) do if not found[file] then stale[#stale + 1] = file end end
        table.sort(unnamed); table.sort(stale)
        assert.same({}, unnamed, "a new direct capture/apply caller: route it through edit_user_lines, or name it here")
        assert.same({}, stale, "a named direct caller no longer calls the API: drop its entry")
    end)

    it("keystroke commands that capture by hand word their refusals through the policy", function()
        assert.is_truthy(worded_by_hand('M.logger.warning("Define: " .. tostring(reason))'), "the guard is blind")
        assert.is_falsy(worded_by_hand('edits.report_refusal("Define", reason)'))
        local offenders = {}
        for _, file in ipairs(KEYSTROKE) do
            for n, line in ipairs(vim.fn.readfile(file)) do
                if not line:match("^%s*%-%-") and worded_by_hand(line) then
                    offenders[#offenders + 1] = file .. ":" .. n .. ": " .. vim.trim(line)
                end
            end
        end
        assert.same({}, offenders, "word it through buffer_edit.report_refusal (or refusal.edit for a notify channel)")
    end)

    it("the spell correction reports a refusal instead of raising it", function()
        local src = table.concat(vim.fn.readfile("lua/parley/spell_source.lua"), "\n")
        assert.is_nil(src:find('error("spell correction', 1, true))
    end)

    it("the raw replace no longer raises its refusals", function()
        local src = table.concat(vim.fn.readfile("lua/parley/buffer_edit.lua"), "\n")
        assert.is_nil(src:find('error("User edit', 1, true), "a refusal must be returned, not raised")
    end)
end)
