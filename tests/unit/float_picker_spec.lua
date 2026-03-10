local float_picker = require("parley.float_picker")

-- Helper: find the current floating window (relative ~= ""), or nil.
local function find_float_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" then
            return win
        end
    end
    return nil
end

-- Helper: close any open float windows between tests.
local function close_floats()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

describe("float_picker", function()
    local original_notify

    before_each(function()
        original_notify = vim.notify
        vim.notify = function() end
        close_floats()
    end)

    after_each(function()
        vim.notify = original_notify
        close_floats()
    end)

    -- -------------------------------------------------------------------------
    -- Window creation
    -- -------------------------------------------------------------------------
    describe("window creation", function()
        it("opens a floating window", function()
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
            })
            assert.is_not_nil(find_float_win(), "expected a floating window to be open")
        end)

        it("creates one line per item", function()
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = 1 },
                    { display = "beta",  value = 2 },
                    { display = "gamma", value = 3 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            assert.equals(3, #lines)
        end)

        it("preserves item order (top-to-bottom)", function()
            float_picker.open({
                title = "Test",
                items = {
                    { display = "first",  value = 1 },
                    { display = "second", value = 2 },
                    { display = "third",  value = 3 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            assert.truthy(lines[1]:find("first",  1, true))
            assert.truthy(lines[2]:find("second", 1, true))
            assert.truthy(lines[3]:find("third",  1, true))
        end)

        it("does not open a window when items list is empty", function()
            local warned = false
            vim.notify = function() warned = true end

            local wins_before = #vim.api.nvim_list_wins()
            float_picker.open({ title = "Test", items = {}, on_select = function() end })

            assert.equals(wins_before, #vim.api.nvim_list_wins())
            assert.is_true(warned)
        end)

        it("truncates long items with an ellipsis", function()
            float_picker.open({
                title = "Test",
                items = { { display = string.rep("x", 300), value = 1 } },
                on_select = function() end,
            })
            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            assert.is_true(#lines[1] < 200, "line should be truncated")
            assert.truthy(lines[1]:find("…", 1, true), "truncated line should end with ellipsis")
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Key mappings
    -- -------------------------------------------------------------------------
    describe("key mappings", function()
        it("<CR> calls on_select with the current item and closes the window", function()
            local selected = nil
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = "the_value" } },
                on_select = function(item) selected = item end,
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", true
            )
            vim.wait(200, function() return selected ~= nil end)

            assert.is_not_nil(selected)
            assert.equals("the_value", selected.value)
            assert.is_nil(find_float_win(), "window should be closed after confirm")
        end)

        it("<Esc> calls on_cancel and closes the window", function()
            local cancelled = false
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
                on_cancel = function() cancelled = true end,
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true
            )
            vim.wait(200, function() return cancelled end)

            assert.is_true(cancelled)
            assert.is_nil(find_float_win(), "window should be closed after cancel")
        end)

        it("q calls on_cancel and closes the window", function()
            local cancelled = false
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
                on_cancel = function() cancelled = true end,
            })

            vim.api.nvim_feedkeys("q", "x", true)
            vim.wait(200, function() return cancelled end)

            assert.is_true(cancelled)
            assert.is_nil(find_float_win(), "window should be closed after cancel")
        end)

        it("extra mappings are called with the current item", function()
            local mapped_item = nil
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = "extra_val" } },
                on_select = function() end,
                mappings = {
                    { key = "x", fn = function(item, _) mapped_item = item end },
                },
            })

            vim.api.nvim_feedkeys("x", "x", true)
            vim.wait(200, function() return mapped_item ~= nil end)

            assert.is_not_nil(mapped_item)
            assert.equals("extra_val", mapped_item.value)
        end)

        it("extra mapping close_fn closes the window", function()
            local closed_via_mapping = false
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
                mappings = {
                    {
                        key = "d",
                        fn = function(_, close_fn)
                            close_fn()
                            closed_via_mapping = true
                        end,
                    },
                },
            })

            vim.api.nvim_feedkeys("d", "x", true)
            vim.wait(200, function() return closed_via_mapping end)

            assert.is_true(closed_via_mapping)
            assert.is_nil(find_float_win(), "window should be closed by mapping close_fn")
        end)
    end)
end)
