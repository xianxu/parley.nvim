local parley = require("parley")

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
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

describe(":ParleyTheme", function()
    before_each(close_floats)
    after_each(close_floats)

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
end)
