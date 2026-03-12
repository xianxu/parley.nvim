local base_tmp_dir = "/tmp/parley-test-keybindings-" .. os.time()
local parley = require("parley")

local function has_line(lines, shortcut, description)
    for _, line in ipairs(lines) do
        if line:find(shortcut, 1, true) and line:find(description, 1, true) then
            return true
        end
    end
    return false
end

describe("key bindings help", function()
    it("includes default key binding entries", function()
        parley.setup({
            chat_dir = base_tmp_dir .. "/default-chat",
            state_dir = base_tmp_dir .. "/default-state",
            providers = {},
            api_keys = {},
        })

        local lines = parley._keybinding_help_lines()
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_true(has_line(lines, "<C-g>f", "Open chat finder"))
        assert.is_true(has_line(lines, "<C-g>h", "Manage chat roots"))
        assert.is_true(has_line(lines, "<C-a>", "Cycle chat recency window left"))
        assert.is_true(has_line(lines, "<C-s>", "Cycle chat recency window right"))
        assert.is_true(has_line(lines, "<C-m>", "Move selected chat"))
    end)

    it("uses configured shortcut for key bindings help", function()
        parley.setup({
            chat_dir = base_tmp_dir .. "/custom-chat",
            state_dir = base_tmp_dir .. "/custom-state",
            providers = {},
            api_keys = {},
            global_shortcut_keybindings = { modes = { "n" }, shortcut = "<C-g>k" },
        })

        local lines = parley._keybinding_help_lines()
        assert.is_true(has_line(lines, "<C-g>k", "Show key bindings"))
    end)
end)
