local parley = require("parley")
local chat_dir_picker = require("parley.chat_dir_picker")
local float_picker = require("parley.float_picker")

describe("chat dir management", function()
    local base_dir
    local primary_dir
    local secondary_dir
    local third_dir
    local state_dir
    local original_float_picker_open
    local original_ui_input
    local original_fn_input

    local function read_state()
        local state_file = state_dir .. "/state.json"
        if vim.fn.filereadable(state_file) == 0 then
            return {}
        end
        return parley.helpers.file_to_table(state_file) or {}
    end

    before_each(function()
        original_float_picker_open = float_picker.open
        original_ui_input = vim.ui.input
        original_fn_input = vim.fn.input
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
        float_picker.open = original_float_picker_open
        vim.ui.input = original_ui_input
        vim.fn.input = original_fn_input
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

        assert.equals("* primary [main] " .. vim.fn.resolve(primary_dir), items[1].display)
        assert.is_true(items[1].is_primary)
        assert.equals("secondary", items[2].label)
        assert.equals("  extra   [secondary] " .. vim.fn.resolve(secondary_dir), items[2].display)
        assert.is_false(items[2].is_primary)
        assert.equals(vim.fn.resolve(third_dir), items[3].dir)
    end)

    it("adds a chat dir with a prompted label", function()
        local captured = nil
        float_picker.open = function(opts)
            captured = opts
        end

        vim.fn.input = function(opts)
            assert.equals("Add chat dir: ", opts.prompt)
            return third_dir
        end

        local label_prompt = nil
        vim.ui.input = function(opts, cb)
            label_prompt = opts
            cb("family")
        end

        chat_dir_picker.chat_dir_picker(parley, secondary_dir)
        assert.is_truthy(captured)

        captured.mappings[1].fn(nil, function() end)
        vim.wait(200, function()
            return label_prompt ~= nil
        end)
        assert.equals("Label for chat dir (optional): ", label_prompt.prompt)
        assert.same({
            vim.fn.resolve(primary_dir),
            vim.fn.resolve(secondary_dir),
            vim.fn.resolve(third_dir),
        }, parley.get_chat_dirs())
        assert.equals("family", parley.get_chat_roots()[3].label)
    end)

    it("keeps the picker open while confirming secondary root removal", function()
        local captured = nil
        float_picker.open = function(opts)
            captured = opts
        end

        local prompt_seen = nil
        local close_calls = 0
        local focus_calls = 0
        local suspended = false
        local resumed = false

        vim.ui.input = function(opts, cb)
            prompt_seen = opts.prompt
            assert.is_true(suspended)
            assert.equals(0, close_calls)
            cb(nil)
        end

        chat_dir_picker.chat_dir_picker(parley, secondary_dir)

        assert.is_truthy(captured)
        captured.mappings[3].fn(captured.items[2], function()
            close_calls = close_calls + 1
        end, {
            suspend_for_external_ui = function()
                suspended = true
            end,
            resume_after_external_ui = function()
                resumed = true
            end,
            focus_prompt = function()
                focus_calls = focus_calls + 1
            end,
            skip_focus_restore = false,
        })

        vim.wait(200, function()
            return prompt_seen ~= nil
        end)

        assert.equals("Remove chat dir " .. vim.fn.resolve(secondary_dir) .. "? [y/N] ", prompt_seen)
        assert.equals(0, close_calls)
        assert.is_true(resumed)
        assert.equals(1, focus_calls)
        assert.same({
            vim.fn.resolve(primary_dir),
            vim.fn.resolve(secondary_dir),
        }, parley.get_chat_dirs())
    end)
end)
