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

local function setup_parley(extra)
    local opts = vim.tbl_extend("force", {
        chat_dir = base_tmp_dir .. "/chat",
        state_dir = base_tmp_dir .. "/state",
        providers = {},
        api_keys = {},
    }, extra or {})
    parley.setup(opts)
end

describe("key bindings help", function()
    it("other context shows global keys only", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g>f", "Open chat finder"))
        assert.is_true(has_line(lines, "<C-n>f", "Open note finder"))
        assert.is_true(has_line(lines, "<C-g>h", "Manage chat roots"))
        -- Should NOT include chat buffer or finder keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
    end)

    it("chat context shows global + chat buffer keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete chat"))
        assert.is_true(has_line(lines, "<C-g>w", "Toggle web_search"))
        -- Should NOT include markdown or finder keys
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
    end)

    it("chat_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat_finder")
        assert.is_true(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_true(has_line(lines, "<C-s>", "Cycle recency window right"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected chat"))
        assert.is_true(has_line(lines, "<C-x>", "Move selected chat"))
        -- Should NOT include global or chat buffer keys
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("note_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("note_finder")
        assert.is_true(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected note"))
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
    end)

    it("issue_finder context shows only finder keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue_finder")
        assert.is_true(has_line(lines, "<C-s>", "Cycle issue status"))
        assert.is_true(has_line(lines, "<C-a>", "Toggle show done/history"))
        assert.is_true(has_line(lines, "<C-d>", "Delete selected issue"))
        assert.is_false(has_line(lines, "<C-g>?", "Show key bindings"))
    end)

    it("markdown context shows global + markdown buffer keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("markdown")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete file"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("issue context shows global + issue globals + markdown keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-y>c", "New issue"))
        assert.is_true(has_line(lines, "<C-y>f", "Open issue finder"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("note context shows global + note globals + markdown keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("note")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-n>i", "Enter interview mode"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("title reflects context", function()
        setup_parley()

        local chat_lines = parley._keybinding_help_lines("chat")
        assert.is_true(chat_lines[1]:find("(Chat)", 1, true) ~= nil)

        local other_lines = parley._keybinding_help_lines("other")
        assert.is_nil(other_lines[1]:find("(", 1, true))

        local finder_lines = parley._keybinding_help_lines("chat_finder")
        assert.is_true(finder_lines[1]:find("(Chat Finder)", 1, true) ~= nil)
    end)

    it("uses configured shortcut for key bindings help", function()
        setup_parley({
            global_shortcut_keybindings = { modes = { "n" }, shortcut = "<C-g>k" },
        })

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>k", "Show key bindings"))
    end)
end)
