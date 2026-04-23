local base_tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-keybindings-" .. os.time()
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
        -- Should NOT include chat buffer, repo, or finder keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_false(has_line(lines, "<C-y>f", "Open issue finder"))
    end)

    it("chat context shows global + repo + buffer + chat keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g><C-g>", "Respond"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete chat"))
        assert.is_true(has_line(lines, "<C-g>w", "Toggle web_search"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        -- Should NOT include markdown or finder keys
        assert.is_false(has_line(lines, "<C-a>", "Cycle recency window left"))
        assert.is_false(has_line(lines, "<C-g>vi", "Insert review marker"))
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

    it("markdown context shows global + repo + buffer + markdown keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("markdown")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        assert.is_true(has_line(lines, "<C-g>d", "Delete file"))
        assert.is_true(has_line(lines, "<C-g>vi", "Insert review marker"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("issue context shows global + repo + buffer + markdown + issue keys", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue")
        assert.is_true(has_line(lines, "<C-g>?", "Show key bindings"))
        assert.is_true(has_line(lines, "<C-y>c", "New issue"))
        assert.is_true(has_line(lines, "<C-y>f", "Open issue finder"))
        assert.is_true(has_line(lines, "<C-g>o", "Open file reference"))
        assert.is_true(has_line(lines, "<C-y>s", "Cycle issue status"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("note context shows global + repo + buffer + markdown + note keys", function()
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

    it("global section includes copy shortcuts", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<leader>cl", "Copy location"))
        assert.is_true(has_line(lines, "<leader>cL", "Copy location + content"))
        assert.is_true(has_line(lines, "<leader>cc", "Copy context"))
        assert.is_true(has_line(lines, "<leader>cC", "Copy wide context"))
    end)

    it("repo scope includes issue and vision finders", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("repo")
        assert.is_true(has_line(lines, "<C-y>f", "Open issue finder"))
        assert.is_true(has_line(lines, "<C-j>f", "Open vision finder"))
        -- Should NOT include chat-specific keys
        assert.is_false(has_line(lines, "<C-g><C-g>", "Respond"))
    end)

    it("chat context includes toggle tool folds", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("chat")
        assert.is_true(has_line(lines, "<C-g>b", "Toggle tool folds"))
    end)

    it("markdown context includes review shortcuts", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("markdown")
        assert.is_true(has_line(lines, "<C-g>vi", "Insert review marker"))
        assert.is_true(has_line(lines, "<C-g>vr", "AI review"))
        assert.is_true(has_line(lines, "<C-g>ve", "Apply review marker"))
    end)

    it("issue context includes vision shortcuts via repo ancestry", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("issue")
        assert.is_true(has_line(lines, "<C-j>f", "Open vision finder"))
    end)

    it("review finder shows in global scope", function()
        setup_parley()

        local lines = parley._keybinding_help_lines("other")
        assert.is_true(has_line(lines, "<C-g>vf", "Review finder"))
    end)
end)

describe("keybinding registry", function()
    it("every entry has required fields", function()
        local reg = require("parley.keybinding_registry")
        for _, entry in ipairs(reg.entries) do
            assert.is_not_nil(entry.id, "entry missing id")
            assert.is_not_nil(entry.default_key, "entry " .. entry.id .. " missing default_key")
            assert.is_not_nil(entry.default_modes, "entry " .. entry.id .. " missing default_modes")
            assert.is_not_nil(entry.scope, "entry " .. entry.id .. " missing scope")
            assert.is_not_nil(entry.desc, "entry " .. entry.id .. " missing desc")
        end
    end)

    it("all entry ids are unique", function()
        local reg = require("parley.keybinding_registry")
        local seen = {}
        for _, entry in ipairs(reg.entries) do
            assert.is_nil(seen[entry.id], "duplicate entry id: " .. entry.id)
            seen[entry.id] = true
        end
    end)

    it("all scopes are valid", function()
        local reg = require("parley.keybinding_registry")
        -- Use scope_labels as the canonical set of valid scopes
        for _, entry in ipairs(reg.entries) do
            assert.is_not_nil(reg.scope_labels[entry.scope], "invalid scope '" .. entry.scope .. "' for entry " .. entry.id)
        end
    end)

    it("ancestor scopes for issue includes repo", function()
        local reg = require("parley.keybinding_registry")
        local scopes = reg.get_ancestor_scopes("issue")
        local has_repo = false
        for _, s in ipairs(scopes) do
            if s == "repo" then has_repo = true end
        end
        assert.is_true(has_repo)
    end)
end)
