-- #386: parley's highlight groups survive :colorscheme (which runs :hi clear)
-- through parley.highlight_groups. #387: the edit groups are faint tints of
-- the theme's Normal background — ParleyEditAdd toward green, ParleyEditChange
-- toward blue — re-derived on every ColorScheme, overridable through
-- config.highlight.edit_add / edit_change.
local tmp_dir = vim.fn.tempname() .. "-parley-highlight-groups"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
local color = require("parley.color")

local function setup(highlight)
    parley.setup({
        chat_dir = tmp_dir,
        state_dir = tmp_dir .. "/state",
        providers = {},
        api_keys = {},
        highlight = highlight,
    })
end

local function bg(name) return vim.api.nvim_get_hl(0, { name = name }).bg end

-- The tints the groups must carry over a given Normal background.
local function expect_tints(normal_bg)
    assert.equals(color.blend(normal_bg, 0x3fb950, 0.15), bg("ParleyEditAdd"))
    assert.equals(color.blend(normal_bg, 0x58a6ff, 0.15), bg("ParleyEditChange"))
    for _, name in ipairs({ "ParleyEditAdd", "ParleyEditChange" }) do
        local hl = vim.api.nvim_get_hl(0, { name = name })
        assert.is_nil(hl.fg, name .. " keeps the text's own color")
        assert.is_nil(hl.underline, name)
    end
end

describe("highlight groups (#386, #387)", function()
    it("tints Normal's background green for added, blue for changed", function()
        vim.api.nvim_set_hl(0, "Normal", { bg = 0x1e1e2e, fg = 0xcdd6f4 })
        setup()
        expect_tints(0x1e1e2e)
        assert.are_not.equal(bg("ParleyEditAdd"), bg("ParleyEditChange"))
    end)

    it("re-derives the tints when the theme's background changes", function()
        setup()
        vim.api.nvim_set_hl(0, "Normal", { bg = 0xfafafa, fg = 0x202020 })
        vim.cmd("doautocmd ColorScheme")
        expect_tints(0xfafafa)
    end)

    it("blends from black or white by 'background' when Normal has no bg", function()
        setup()
        local was = vim.o.background
        -- Setting 'background' reloads the colorscheme, so clear Normal after it.
        for _, mode in ipairs({ { "light", 0xffffff }, { "dark", 0x000000 } }) do
            vim.o.background = mode[1]
            vim.api.nvim_set_hl(0, "Normal", {})
            vim.cmd("doautocmd ColorScheme")
            expect_tints(mode[2])
        end
        vim.o.background = was
    end)

    it("config.highlight.edit_add / edit_change override them", function()
        setup({ edit_add = { link = "DiffAdd" }, edit_change = { link = "Visual" } })
        assert.same({ link = "DiffAdd" }, vim.api.nvim_get_hl(0, { name = "ParleyEditAdd" }))
        assert.same({ link = "Visual" }, vim.api.nvim_get_hl(0, { name = "ParleyEditChange" }))
        setup()
    end)

    it("survives :colorscheme, with every other parley group", function()
        setup()
        vim.cmd("colorscheme default")
        expect_tints(vim.api.nvim_get_hl(0, { name = "Normal" }).bg
            or (vim.o.background == "light" and 0xffffff or 0x000000))
        assert.same({ link = "DiagnosticWarn" }, vim.api.nvim_get_hl(0, { name = "ParleyReviewUser" }))
        vim.cmd("colorscheme default") -- the autocmd outlives its first run
        assert.is_not_nil(bg("ParleyEditAdd"))
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
