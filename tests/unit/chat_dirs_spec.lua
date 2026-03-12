local parley = require("parley")
local chat_dir_picker = require("parley.chat_dir_picker")

describe("chat dir management", function()
    local base_dir
    local primary_dir
    local secondary_dir
    local third_dir
    local state_dir

    local function read_state()
        local state_file = state_dir .. "/state.json"
        if vim.fn.filereadable(state_file) == 0 then
            return {}
        end
        return parley.helpers.file_to_table(state_file) or {}
    end

    before_each(function()
        base_dir = vim.fn.tempname() .. "-parley-chat-dirs"
        primary_dir = base_dir .. "/primary"
        secondary_dir = base_dir .. "/secondary"
        third_dir = base_dir .. "/third"
        state_dir = base_dir .. "/state"

        parley._state = {}

        parley.setup({
            chat_dir = primary_dir,
            chat_dirs = { secondary_dir },
            state_dir = state_dir,
            providers = {},
            api_keys = {},
        })
    end)

    after_each(function()
        if base_dir then
            vim.fn.delete(base_dir, "rf")
        end
    end)

    it("persists added chat dirs into state", function()
        local dirs = parley.add_chat_dir(third_dir, true)

        assert.same({
            vim.fn.resolve(primary_dir),
            vim.fn.resolve(secondary_dir),
            vim.fn.resolve(third_dir),
        }, dirs)
        assert.same(dirs, read_state().chat_dirs)
    end)

    it("reloads persisted chat dirs on setup", function()
        parley.add_chat_dir(third_dir, true)

        parley.setup({
            chat_dir = primary_dir,
            state_dir = state_dir,
            providers = {},
            api_keys = {},
        })

        assert.same({
            vim.fn.resolve(primary_dir),
            vim.fn.resolve(secondary_dir),
            vim.fn.resolve(third_dir),
        }, parley.get_chat_dirs())
    end)

    it("does not allow removing the primary root", function()
        local dirs, err = parley.remove_chat_dir(primary_dir, true)

        assert.is_nil(dirs)
        assert.equals("cannot remove the primary chat directory", err)
        assert.same({
            vim.fn.resolve(primary_dir),
            vim.fn.resolve(secondary_dir),
        }, parley.get_chat_dirs())
    end)

    it("removing a secondary root keeps the primary intact", function()
        local dirs = parley.remove_chat_dir(secondary_dir, true)

        assert.same({ vim.fn.resolve(primary_dir) }, dirs)
        assert.equals(vim.fn.resolve(primary_dir), parley.config.chat_dir)
        assert.same(dirs, read_state().chat_dirs)
    end)

    it("picker items preserve order and mark the primary root", function()
        parley.add_chat_dir(third_dir, true)

        local items = chat_dir_picker._build_items(parley)

        assert.equals("* primary " .. vim.fn.resolve(primary_dir), items[1].display)
        assert.is_true(items[1].is_primary)
        assert.equals("  extra   " .. vim.fn.resolve(secondary_dir), items[2].display)
        assert.is_false(items[2].is_primary)
        assert.equals(vim.fn.resolve(third_dir), items[3].dir)
    end)
end)
