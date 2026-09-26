local parley = require("parley")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
local theme = require("parley.theme")
-- Execute real :colorscheme commands without downloading packages in unit CI.
-- Every fixture clears highlights, as real schemes do, so restoration and the
-- Parley ColorScheme hooks are exercised through the production path.
vim.fn.mkdir(root .. "/runtime/colors", "p")
for _, spec in ipairs(theme.items()) do
    vim.fn.writefile({
        "vim.cmd('highlight clear')",
        "vim.g.colors_name = " .. string.format("%q", spec.colorscheme),
        "vim.api.nvim_set_hl(0, 'Normal', {fg=0xdddddd,bg=0x222222})",
        "vim.api.nvim_set_hl(0, 'Comment', {fg=0x999999})",
    }, root .. "/runtime/colors/" .. spec.colorscheme .. ".lua")
end
vim.opt.runtimepath:prepend(root .. "/runtime")
vim.cmd.colorscheme("moonfly")
parley.setup({
    chat_dir = root .. "/chats",
    state_dir = root .. "/state",
    providers = {},
    api_keys = {},
    cliproxy = { manage = false },
})

local function close_floats()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" then pcall(vim.api.nvim_win_close, win, true) end
    end
end

local function mapping(buf, mode, key)
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
        if map.lhs == key then return map.callback end
    end
    error("missing mapping " .. key)
end

local function query(text)
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "> " .. text })
    vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })
    vim.wait(100, function() return false end)
end

local function settle()
    vim.wait(50, function() return false end)
end

describe(":ParleyTheme", function()
    before_each(function()
        close_floats()
        vim.fn.delete(theme.preference_path(parley.config.state_dir))
        vim.cmd.colorscheme("moonfly")
    end)
    after_each(function() close_floats(); settle() end)

    it("is registered and opens the packaged theme picker", function()
        assert.equals(2, vim.fn.exists(":ParleyTheme"))
        vim.cmd("ParleyTheme")
        local found = false
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
            if ok and cfg.relative ~= "" then
                local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
                if table.concat(lines, "\n"):find("Catppuccin Mocha", 1, true) then found = true end
            end
        end
        assert.is_true(found)
    end)

    it("previews filtered results without persistence and restores on cancel", function()
        vim.cmd("ParleyTheme")
        query("Catppuccin Latte")
        assert.equals("catppuccin-latte", vim.g.colors_name)
        assert.equals("light", vim.o.background)
        assert.is_nil(theme.load(parley.config.state_dir))
        mapping(0, "n", "<Esc>")()
        settle()
        assert.equals("moonfly", vim.g.colors_name)
        assert.is_nil(theme.load(parley.config.state_dir))
    end)

    it("commits the preview through Enter and persists it", function()
        vim.cmd("ParleyTheme")
        query("carbonfox")
        mapping(0, "i", "<CR>")()
        settle()
        assert.equals("carbonfox", vim.g.colors_name)
        assert.equals("carbonfox", theme.load(parley.config.state_dir))
    end)

    it("previews another filter result even when its index remains one", function()
        vim.cmd("ParleyTheme")
        query("carbonfox")
        assert.equals("carbonfox", vim.g.colors_name)
        query("dayfox")
        assert.equals("dayfox", vim.g.colors_name)
        assert.equals("light", vim.o.background)
        mapping(0, "n", "<Esc>")()
        settle()
    end)

    it("loads Solarized in light mode", function()
        vim.cmd("ParleyTheme")
        query("Solarized Light")
        assert.equals("solarized", vim.g.colors_name)
        assert.equals("light", vim.o.background)
        mapping(0, "i", "<CR>")()
        settle()
        assert.equals("solarized-light", theme.load(parley.config.state_dir))
    end)

    it("restores startup after reopening with a persisted nondefault theme", function()
        assert.is_true(theme.save(parley.config.state_dir, "carbonfox", parley.helpers))
        assert.is_true(theme.apply(theme.load(parley.config.state_dir)))
        vim.cmd("ParleyTheme")
        query("Restore startup")
        assert.equals("moonfly", vim.g.colors_name)
        -- Preview must leave the previous durable preference untouched.
        assert.equals("carbonfox", theme.load(parley.config.state_dir))
        mapping(0, "i", "<CR>")()
        settle()
        assert.equals("startup", theme.load(parley.config.state_dir))
    end)

    it("captures a custom light startup before restoring a saved choice on restart", function()
        vim.fn.writefile({ "vim.g.colors_name = 'custom-startup'" }, root .. "/runtime/colors/custom-startup.lua")
        vim.o.background = "light"
        vim.cmd.colorscheme("custom-startup")
        -- A new module instance models the per-process startup state.
        local restarted = dofile("lua/parley/theme.lua")
        restarted.capture_startup()
        assert.is_true(restarted.save(parley.config.state_dir, "carbonfox", parley.helpers))
        assert.is_true(restarted.apply(restarted.load(parley.config.state_dir)))
        assert.equals("carbonfox", vim.g.colors_name)
        assert.is_true(restarted.apply("startup"))
        assert.equals("custom-startup", vim.g.colors_name)
        assert.equals("light", vim.o.background)
    end)

    it("rolls back a failed colorscheme including partial highlight changes", function()
        assert.is_true(theme.apply("onedark-warm"))
        local before = theme.snapshot()
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
        local path = root .. "/runtime/colors/nightfox.lua"
        local original = vim.fn.readfile(path)
        vim.fn.writefile({
            "vim.g.colors_name = 'broken'",
            "vim.api.nvim_set_hl(0, 'Normal', {fg=0xff0000})",
            "error('fixture colorscheme failed')",
        }, path)
        local applied = theme.apply("nightfox")
        vim.fn.writefile(original, path)
        assert.is_false(applied)
        assert.same(before, theme.snapshot())
        assert.same(normal, vim.api.nvim_get_hl(0, { name = "Normal", link = false }))
    end)

    it("keeps the opening theme when a package is absent", function()
        local before = theme.snapshot()
        local path = root .. "/runtime/colors/nightfox.lua"
        local original = vim.fn.readfile(path)
        vim.fn.delete(path)
        local applied = theme.apply("nightfox")
        vim.fn.writefile(original, path)
        assert.is_false(applied)
        assert.same(before, theme.snapshot())
    end)

    it("restores the exact OneDark variant when cancelling a different variant", function()
        assert.is_true(theme.apply("onedark-warm"))
        vim.cmd("ParleyTheme")
        query("OneDark cool")
        assert.equals("cool", vim.g.onedark_config.style)
        mapping(0, "n", "<Esc>")()
        settle()
        assert.equals("onedark", vim.g.colors_name)
        assert.equals("warm", vim.g.onedark_config.style)
    end)

    it("uses the shared result mouse mappings to preview and commit", function()
        vim.cmd("ParleyTheme")
        local target_win, target_row
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
                if line:find("Catppuccin Latte", 1, true) then target_win, target_row = win, row end
            end
        end
        assert.truthy(target_win)
        local buf = vim.api.nvim_win_get_buf(target_win)
        vim.api.nvim_win_set_cursor(target_win, { target_row, 0 })
        mapping(buf, "n", "<LeftMouse>")()
        assert.equals("catppuccin-latte", vim.g.colors_name)
        assert.is_nil(theme.load(parley.config.state_dir))
        mapping(buf, "n", "<2-LeftMouse>")()
        settle()
        assert.equals("catppuccin-latte", theme.load(parley.config.state_dir))
    end)
end)
