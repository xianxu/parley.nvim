local theme = require("parley.theme")

describe("Parley theme registry", function()
    it("derives the five picker choices from one registry", function()
        local items = theme.items()
        assert.equals(5, #items)
        assert.same({
            "catppuccin-mocha",
            "tokyonight-storm",
            "catppuccin-latte",
            "solarized-light",
            "startup",
        }, vim.tbl_map(function(item) return item.id end, items))
        assert.equals("moonfly", theme.default().colorscheme)
    end)

    it("validates persisted ids and falls back to startup", function()
        assert.equals("catppuccin-mocha", theme.valid_id("catppuccin-mocha"))
        assert.equals("startup", theme.valid_id("unknown"))
        assert.equals("startup", theme.valid_id(nil))
        assert.equals("startup", theme.valid_id({}))
    end)

    it("describes each packaged option by mode and contrast", function()
        local by_id = {}
        for _, item in ipairs(theme.items()) do by_id[item.id] = item end
        assert.same({ mode = "dark", style = "colorful" },
            { mode = by_id["catppuccin-mocha"].mode, style = by_id["catppuccin-mocha"].style })
        assert.same({ mode = "dark", style = "subdued" },
            { mode = by_id["tokyonight-storm"].mode, style = by_id["tokyonight-storm"].style })
        assert.same({ mode = "light", style = "colorful" },
            { mode = by_id["catppuccin-latte"].mode, style = by_id["catppuccin-latte"].style })
        assert.same({ mode = "light", style = "subdued" },
            { mode = by_id["solarized-light"].mode, style = by_id["solarized-light"].style })
    end)

    it("round trips a committed preference and recovers malformed state", function()
        local state_dir = vim.fn.tempname()
        assert.is_true(theme.save(state_dir, "tokyonight-storm"))
        assert.equals("tokyonight-storm", theme.load(state_dir))
        vim.fn.writefile({ "not json" }, theme.preference_path(state_dir))
        assert.equals("startup", theme.load(state_dir))
    end)

    it("falls back when the preference file cannot be read", function()
        local readfile = vim.fn.readfile
        local filereadable = vim.fn.filereadable
        vim.fn.readfile = function() error("unreadable") end
        vim.fn.filereadable = function() return 1 end
        local ok, value = pcall(theme.load, "/tmp/parley-theme-unreadable")
        vim.fn.readfile = readfile
        vim.fn.filereadable = filereadable
        assert.is_true(ok)
        assert.equals("startup", value)
    end)

    it("applies a scheme through an injectable runner and refreshes highlights", function()
        local applied
        local refreshed
        local ok, spec = theme.apply("catppuccin-latte", {
            apply_colorscheme = function(name) applied = name end,
            on_applied = function(value) refreshed = value.id end,
        })
        assert.is_true(ok)
        assert.equals("catppuccin-latte", applied)
        assert.equals("catppuccin-latte", spec.id)
        assert.equals("catppuccin-latte", refreshed)
    end)
end)
