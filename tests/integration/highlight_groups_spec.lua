-- #386: parley's highlight groups survive :colorscheme (which runs :hi clear)
-- through parley.highlight_groups, and ParleyEditChange — the one group for
-- edited spans — is a quiet underline by default, overridable through
-- config.highlight.edit_change.
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

    it("keep re-runs each module's definer on every ColorScheme, one per name", function()
        local groups = require("parley.highlight_groups")
        local runs = { a = 0, b = 0, old = 0 }
        groups.keep("spec_a", function() runs.old = runs.old + 1 end)
        groups.keep("spec_a", function() runs.a = runs.a + 1 end) -- replaces
        groups.keep("spec_b", function() runs.b = runs.b + 1; return true end)
        vim.cmd("colorscheme default")
        vim.cmd("colorscheme default")
        assert.same({ a = 2, b = 2, old = 0 }, runs)
        groups.keep("spec_a", function() end)
        groups.keep("spec_b", function() end)
    end)

    -- Class guard: every module that sets a Parley group hands its definer to
    -- highlight_groups.keep, so no group is lost to :hi clear. (`Search` is the
    -- theme's own group, which parley restyles once at setup.)
    it("every module defining a group registers it with highlight_groups", function()
        local missing = {}
        for _, path in ipairs(vim.fn.globpath("lua/parley", "**/*.lua", false, true)) do
            local text = table.concat(vim.fn.readfile(path), "\n")
            local defines = false
            for name in text:gmatch("nvim_set_hl%(0,%s*([^,]+),") do
                if name ~= '"Search"' then defines = true end
            end
            if defines and not text:find('highlight_groups").keep(', 1, true) then
                missing[#missing + 1] = path
            end
        end
        assert.same({}, missing)
    end)
end)
