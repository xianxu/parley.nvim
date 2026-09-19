-- #261 (target transcript-is-the-whole-truth): no sidecar under the profile
-- state directory may stop someone working on a chat. Every sidecar listed in
-- tests/helpers/sidecars.lua is written corrupt — invalid JSON, then each of
-- its wrongly typed bodies — its reader is run, and a chat is submitted through
-- the command, whose wrapper refreshes state first. The state directory made
-- unwritable must not block a submission either.
local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-sidecar-degrade-" .. os.time()
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    default_agent = "FixtureAnthropic",
    agents = {
        { name = "Choose a model", disable = true },
        { name = "FixtureAnthropic", provider = "anthropic",
          model = { model = "claude-sonnet-5" }, system_prompt = "You are a helpful assistant." },
    },
    providers = {},
    api_keys = {},
})
vim.fn.mkdir(tmp_dir, "p")

local Fixture = require("tests.helpers.respond_fixture")
local sidecars = require("tests.helpers.sidecars")
local Respond = require("parley.chat_respond")

describe("sidecars under the state directory degrade", function()
    local calls, restore, buf, saved_state
    local state_dir = parley.config.state_dir
    before_each(function()
        saved_state = vim.deepcopy(parley._state)
        calls, restore = Fixture.install(parley)
        buf = vim.api.nvim_create_buf(true, false)
        vim.api.nvim_buf_set_name(buf, tmp_dir .. "/2026-03-01-sidecar-" .. math.random(1000000) .. ".md")
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false,
            { "# topic: Fixture", "- file: fixture.md", "---", "", "💬: question", "" })
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        restore()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        for _, sidecar in ipairs(sidecars) do vim.fn.delete(state_dir .. "/" .. sidecar.file) end
        parley._remote_reference_cache = nil
        parley._state = saved_state
    end)

    local function submits()
        -- Cold, so the submission's own resolve_remote_references reads the
        -- cache file rather than what exercise() already loaded.
        parley._remote_reference_cache = nil
        vim.cmd("ParleyChatRespond")
        assert.is_true(vim.wait(5000, function() return #calls > 0 end, 1),
            "the submission did not reach the provider")
    end

    for _, sidecar in ipairs(sidecars) do
        local cases = { { label = "invalid JSON", body = "{" } }
        for i, shape in ipairs(sidecar.wrong_shapes) do
            cases[#cases + 1] = { label = "wrongly typed body " .. i, body = vim.json.encode(shape), typed = true }
        end
        for _, case in ipairs(cases) do
            it(sidecar.file .. " with " .. case.label .. " neither throws nor blocks a submission", function()
                local path = state_dir .. "/" .. sidecar.file
                vim.fn.mkdir(state_dir, "p")
                vim.fn.writefile({ case.body }, path)
                -- #261 M1 review BR-15: a file's diagnostics belong to its
                -- parse, and a parse to the user's action — at most one
                -- warning naming this file, however the reader loops.
                local logger, warning = require("parley.logger"), require("parley.logger").warning
                local about = 0
                logger.warning = function(msg, ...)
                    if tostring(msg):find(sidecar.file, 1, true) then about = about + 1 end
                    return warning(msg, ...)
                end
                local ok, err = pcall(sidecar.exercise, parley)
                logger.warning = warning
                assert(ok, err)
                assert.is_true(about <= 1, sidecar.file .. " warned " .. about .. " times in one read")
                -- An authored file's writes keep what the read filtered out.
                if case.typed and sidecar.writes == "preserve" then sidecar.preserve(parley, path) end
                submits()
            end)
        end
    end

    it("an unwritable state directory does not block a submission", function()
        vim.fn.mkdir(state_dir, "p")
        vim.uv.fs_chmod(state_dir, tonumber("500", 8))
        local ok, err = pcall(submits)
        vim.uv.fs_chmod(state_dir, tonumber("700", 8))
        assert(ok, err)
    end)
end)
