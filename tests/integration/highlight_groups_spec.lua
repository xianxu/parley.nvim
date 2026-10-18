-- #386: parley's highlight groups survive :colorscheme (which runs :hi clear),
-- and ParleyEditChange — the one group for edited spans — is a quiet underline
-- by default, overridable through config.highlight.edit_change.
local tmp_dir = vim.fn.tempname() .. "-parley-highlight-groups"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")

local function setup(highlight)
    parley.setup({
        chat_dir = tmp_dir,
        state_dir = tmp_dir .. "/state",
        providers = {},
        api_keys = {},
        highlight = highlight,
    })
end

-- An underline that sets no color, link or background of its own.
local function assert_quiet_underline()
    local hl = vim.api.nvim_get_hl(0, { name = "ParleyEditChange" })
    assert.is_true(hl.underline)
    assert.is_nil(hl.link)
    assert.is_nil(hl.fg)
    assert.is_nil(hl.bg)
end

describe("highlight groups (#386)", function()
    it("ParleyEditChange is an underline with no color of its own", function()
        setup()
        assert_quiet_underline()
    end)

    it("config.highlight.edit_change overrides it", function()
        setup({ edit_change = { link = "Visual" } })
        assert.same({ link = "Visual" }, vim.api.nvim_get_hl(0, { name = "ParleyEditChange" }))
        setup()
    end)

    it("survives :colorscheme, with every other parley group", function()
        setup()
        vim.cmd("colorscheme default")
        assert_quiet_underline()
        assert.same({ link = "DiagnosticWarn" }, vim.api.nvim_get_hl(0, { name = "ParleyReviewUser" }))
        vim.cmd("colorscheme default") -- the autocmd outlives its first run
        assert_quiet_underline()
    end)
end)
