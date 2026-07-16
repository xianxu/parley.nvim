local float_picker = require("parley.float_picker")

-- PROMPT_OVERHEAD: 5 rows consumed by prompt window borders + content.
-- Must match the constant in float_picker.lua.
local PROMPT_OVERHEAD = 5

-- Helper: find the results window (the float that is NOT currently focused).
-- After M.open(), the prompt window is focused, so results is the other float.
local function find_float_win()
    local cur = vim.api.nvim_get_current_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" and win ~= cur then
            return win
        end
    end
    return nil
end

-- Helper: find ANY floating window (used to verify all floats are closed).
local function find_any_float_win()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" then
            return win
        end
    end
    return nil
end

local function find_float_win_with_text(text)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg.relative ~= "" then
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            if table.concat(lines, "\n"):find(text, 1, true) then
                return win
            end
        end
    end
    return nil
end

-- Helper: return {width, height, row, col} for the float window config.
local function float_layout(win)
    local cfg = vim.api.nvim_win_get_config(win)
    return { width = cfg.width, height = cfg.height, row = cfg.row, col = cfg.col }
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
            assert.is_not_nil(find_float_win(), "expected a results floating window to be open")
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

        it("renders logical item order from bottom to top", function()
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
            assert.truthy(lines[1]:find("third",  1, true))
            assert.truthy(lines[2]:find("second", 1, true))
            assert.truthy(lines[3]:find("first",  1, true))
        end)

        it("selects the first logical item on the bottom row by default", function()
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
            local cursor = vim.api.nvim_win_get_cursor(win)
            assert.equals(3, cursor[1])
        end)

        it("keeps the selected row on the bottom edge when the list exceeds window height", function()
            float_picker.open({
                title = "Test",
                height = 3,
                items = {
                    { display = "one", value = 1 },
                    { display = "two", value = 2 },
                    { display = "three", value = 3 },
                    { display = "four", value = 4 },
                    { display = "five", value = 5 },
                },
                on_select = function() end,
            })

            local win = find_float_win()
            local cursor = vim.api.nvim_win_get_cursor(win)
            local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)

            assert.equals(5, cursor[1])
            assert.equals(3, view.topline)
        end)

        it("keeps short filtered lists pinned to the bottom of a taller window", function()
            float_picker.open({
                title = "Test",
                height = 5,
                items = {
                    { display = "alpha", value = 1 },
                    { display = "beta",  value = 2 },
                },
                on_select = function() end,
            })

            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            local cursor = vim.api.nvim_win_get_cursor(win)

            assert.equals(5, #lines)
            assert.equals("", lines[1])
            assert.equals("", lines[2])
            assert.equals("", lines[3])
            assert.truthy(lines[4]:find("beta", 1, true))
            assert.truthy(lines[5]:find("alpha", 1, true))
            assert.equals(5, cursor[1])
        end)

        it("does not open a window when items list is empty", function()
            local warned = false
            vim.notify = function() warned = true end

            local wins_before = #vim.api.nvim_list_wins()
            float_picker.open({ title = "Test", items = {}, on_select = function() end })

            assert.equals(wins_before, #vim.api.nvim_list_wins())
            assert.is_true(warned)
        end)

        it("opens an empty picker with a nonselectable loading status", function()
            local warned = false
            vim.notify = function() warned = true end

            local picker = float_picker.open({
                title = "Loading",
                items = {},
                status = { message = "scanning…", animated = true },
                on_select = function() error("status must not be selectable") end,
            })

            assert.is_table(picker)
            assert.is_not_nil(find_float_win_with_text("scanning…"))
            assert.is_false(warned)
            picker.close()
        end)

        it("keeps status visible under a retained query and replaces it atomically", function()
            local picker = float_picker.open({
                title = "Loading",
                items = {},
                initial_query = "hidden query",
                status = { message = "scanning…", animated = true },
                on_select = function() end,
            })

            assert.is_not_nil(find_float_win_with_text("scanning…"))
            assert.equals("hidden query", picker.current_query())

            picker.update({ { display = "hidden query result", value = 1 } })

            assert.is_nil(find_float_win_with_text("scanning…"))
            assert.is_not_nil(find_float_win_with_text("hidden query result"))
            picker.close()
        end)

        it("can replace loading with a persistent nonanimated error status", function()
            local picker = float_picker.open({
                title = "Loading",
                items = {},
                status = { message = "scanning…", animated = true },
                on_select = function() end,
            })

            picker.set_status({ message = "scan failed", animated = false })

            assert.is_nil(find_float_win_with_text("scanning…"))
            assert.is_not_nil(find_float_win_with_text("scan failed"))
            picker.close()
        end)

        it("opens an empty picker when facets can restore its items", function()
            local picker = float_picker.open({
                title = "Test",
                items = {},
                tag_bar = {
                    tags = { { label = "alpha", enabled = false } },
                    on_toggle = function() end,
                    on_all = function() end,
                    on_none = function() end,
                },
                on_select = function() end,
            })

            assert.is_table(picker)
            assert.is_function(picker.update)
            assert.is_not_nil(find_float_win_with_text("(no matches)"))

            picker.update(
                { { display = "alpha item", search_text = "alpha item", value = 1 } },
                { { label = "alpha", enabled = true } }
            )

            assert.is_not_nil(find_float_win_with_text("alpha item"))
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

        it("seeds the prompt and filtered results from initial_query", function()
            float_picker.open({
                title = "Test",
                initial_query = "beta",
                items = {
                    { display = "alpha", value = 1 },
                    { display = "beta", value = 2 },
                },
                on_select = function() end,
            })

            local prompt_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)

            assert.equals("> beta", prompt_line)
            assert.equals(2, #lines)
            assert.equals("", lines[1])
            assert.truthy(lines[2]:find("beta", 1, true))
        end)

        it("preserves a synchronized live query when items and facets update", function()
            local picker = float_picker.open({
                title = "Test",
                initial_query = "alpha",
                items = {
                    { display = "alpha beta", search_text = "alpha beta", value = 1 },
                    { display = "alpha gamma", search_text = "alpha gamma", value = 2 },
                },
                tag_bar = {
                    tags = { { label = "repo", enabled = true } },
                    on_toggle = function() end,
                    on_all = function() end,
                    on_none = function() end,
                },
                on_select = function() end,
            })

            local prompt_buf = vim.api.nvim_get_current_buf()
            local live_prompt = ">   alpha beta  "
            vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { live_prompt })
            vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt_buf })

            picker.update({
                { display = "alpha beta", search_text = "alpha beta", value = 1 },
                { display = "alpha gamma", search_text = "alpha gamma", value = 2 },
            }, { { label = "repo", enabled = false } })

            assert.equals(live_prompt, vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1])
            local results_win = find_float_win_with_text("alpha beta")
            assert.is_not_nil(results_win)
            local results = table.concat(
                vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(results_win), 0, -1, false),
                "\n"
            )
            assert.is_nil(results:find("alpha gamma", 1, true))
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Key mappings
    -- -------------------------------------------------------------------------
    describe("key mappings", function()
        it("ignores confirm while a status row is active", function()
            local selected = false
            local cancelled = false
            local picker = float_picker.open({
                title = "Loading",
                items = {},
                status = { message = "scanning…", animated = true },
                on_select = function() selected = true end,
                on_cancel = function() cancelled = true end,
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", true
            )
            vim.wait(50, function() return false end)

            assert.is_false(selected)
            assert.is_false(cancelled)
            assert.is_false(picker.is_closed())
            assert.is_not_nil(find_float_win_with_text("scanning…"))
            picker.close()
        end)

        it("tears down an animated status exactly once on cancel", function()
            local active = false
            local stop_count = 0
            local controller = {
                start = function(_, message, render)
                    active = true
                    render(" frame " .. message)
                end,
                stop = function()
                    if active then
                        active = false
                        stop_count = stop_count + 1
                    end
                end,
            }
            local cancel_count = 0
            local picker = float_picker.open({
                title = "Loading",
                items = {},
                status = { message = "scanning…", animated = true },
                status_controller = controller,
                on_select = function() end,
                on_cancel = function() cancel_count = cancel_count + 1 end,
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true
            )
            vim.wait(200, function() return cancel_count == 1 end)
            picker.close()

            assert.equals(1, cancel_count)
            assert.equals(1, stop_count)
            assert.is_false(active)
        end)

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
            assert.is_nil(find_any_float_win(), "window should be closed after confirm")
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
            assert.is_nil(find_any_float_win(), "window should be closed after cancel")
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
            assert.is_nil(find_any_float_win(), "window should be closed after cancel")
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

        it("does not let a <C-m> extra mapping override <CR> confirm", function()
            local selected = nil
            local extra_mapping_called = false
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = "the_value" } },
                on_select = function(item) selected = item end,
                mappings = {
                    { key = "<C-m>", fn = function() extra_mapping_called = true end },
                },
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", true
            )
            vim.wait(200, function() return selected ~= nil end)

            assert.is_not_nil(selected)
            assert.equals("the_value", selected.value)
            assert.is_false(extra_mapping_called)
            assert.is_nil(find_any_float_win(), "window should be closed after confirm")
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
            assert.is_nil(find_any_float_win(), "window should be closed by mapping close_fn")
        end)

        it("extra mapping close_fn does not trigger on_cancel", function()
            local cancelled = false
            local closed_via_mapping = false
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
                on_cancel = function() cancelled = true end,
                mappings = {
                    {
                        key = "<C-d>",
                        fn = function(_, close_fn)
                            close_fn()
                            closed_via_mapping = true
                        end,
                    },
                },
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<C-d>", true, false, true), "x", true
            )
            vim.wait(200, function() return closed_via_mapping end)
            vim.wait(50)

            assert.is_true(closed_via_mapping)
            assert.is_false(cancelled)
            assert.is_nil(find_any_float_win(), "window should be closed by mapping close_fn")
        end)

        it("control-key extra mappings are called from the prompt buffer", function()
            local mapped_item = nil
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = "ctrl_d_val" } },
                on_select = function() end,
                mappings = {
                    { key = "<C-d>", fn = function(item, _) mapped_item = item end },
                },
            })

            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<C-d>", true, false, true), "x", true
            )
            vim.wait(200, function() return mapped_item ~= nil end)

            assert.is_not_nil(mapped_item)
            assert.equals("ctrl_d_val", mapped_item.value)
        end)

        it("maps short bottom-padded visual rows back to logical indices", function()
            assert.equals(5, float_picker._visual_row_for_index(1, 2, 5, "bottom"))
            assert.equals(4, float_picker._visual_row_for_index(2, 2, 5, "bottom"))
            assert.equals(1, float_picker._index_for_visual_row(5, 2, 5, "bottom"))
            assert.equals(2, float_picker._index_for_visual_row(4, 2, 5, "bottom"))
            assert.equals(2, float_picker._index_for_visual_row(3, 2, 5, "bottom"))
        end)

        it("maps top-anchored visual rows back to logical indices", function()
            assert.equals(1, float_picker._visual_row_for_index(1, 2, 5, "top"))
            assert.equals(2, float_picker._visual_row_for_index(2, 2, 5, "top"))
            assert.equals(1, float_picker._index_for_visual_row(1, 2, 5, "top"))
            assert.equals(2, float_picker._index_for_visual_row(2, 2, 5, "top"))
            -- rows beyond content count clamp to last item
            assert.equals(2, float_picker._index_for_visual_row(3, 2, 5, "top"))
            assert.equals(2, float_picker._index_for_visual_row(5, 2, 5, "top"))
        end)

    end)

    -- -------------------------------------------------------------------------
    -- Top-anchored picker
    -- -------------------------------------------------------------------------
    describe("anchor=top", function()
        it("renders logical item order from top to bottom", function()
            float_picker.open({
                title = "Test",
                anchor = "top",
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

        it("selects the first logical item on the top row by default", function()
            float_picker.open({
                title = "Test",
                anchor = "top",
                items = {
                    { display = "first",  value = 1 },
                    { display = "second", value = 2 },
                    { display = "third",  value = 3 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            local cursor = vim.api.nvim_win_get_cursor(win)
            assert.equals(1, cursor[1])
        end)

        it("keeps short lists pinned to the top of a taller window", function()
            float_picker.open({
                title = "Test",
                height = 5,
                anchor = "top",
                items = {
                    { display = "alpha", value = 1 },
                    { display = "beta",  value = 2 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            local cursor = vim.api.nvim_win_get_cursor(win)

            assert.equals(5, #lines)
            assert.truthy(lines[1]:find("alpha", 1, true))
            assert.truthy(lines[2]:find("beta",  1, true))
            assert.equals("", lines[3])
            assert.equals("", lines[4])
            assert.equals("", lines[5])
            assert.equals(1, cursor[1])
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Sizing and layout
    -- -------------------------------------------------------------------------
    describe("sizing and layout", function()
        local ui

        before_each(function()
            ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
        end)

        it("height equals number of items when fewer than screen allows", function()
            float_picker.open({
                title = "Test",
                items = {
                    { display = "a", value = 1 },
                    { display = "b", value = 2 },
                    { display = "c", value = 3 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            assert.equals(3, float_layout(win).height)
        end)

        it("opts.height overrides the item-count default", function()
            float_picker.open({
                title  = "Test",
                height = 2,
                items  = {
                    { display = "a", value = 1 },
                    { display = "b", value = 2 },
                    { display = "c", value = 3 },
                    { display = "d", value = 4 },
                },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            assert.equals(2, float_layout(win).height)
        end)

        it("opts.width overrides the content-driven default", function()
            float_picker.open({
                title = "Test",
                width = 40,
                items = { { display = "short", value = 1 } },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            assert.equals(40, float_layout(win).width)
        end)

        it("width is capped so the window stays within screen bounds", function()
            -- Request a window wider than the screen
            float_picker.open({
                title = "Test",
                width = 9999,
                items = { { display = "item", value = 1 } },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            -- Must fit inside the screen with at least MARGIN_H (4) on each side
            assert.is_true(float_layout(win).width <= ui.width - 8,
                "width should leave at least 4-col margin on each side")
        end)

        it("height is capped so the window stays within screen bounds", function()
            -- Request more items than the screen can show
            local many_items = {}
            for i = 1, 999 do
                table.insert(many_items, { display = "item " .. i, value = i })
            end
            float_picker.open({
                title = "Test",
                items = many_items,
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            -- Must fit inside the screen accounting for margins and prompt overhead
            assert.is_true(float_layout(win).height <= ui.height - 6 - PROMPT_OVERHEAD,
                "height should leave room for margins and prompt")
        end)

        it("window is centered horizontally and vertically", function()
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)
            local layout = float_layout(win)
            -- col is centered on win_w
            local expected_col = math.floor((ui.width  - layout.width)  / 2)
            -- row is centered on total height (results + prompt overhead)
            local expected_row = math.floor((ui.height - (layout.height + PROMPT_OVERHEAD)) / 2)
            assert.equals(expected_col, layout.col)
            assert.equals(expected_row, layout.row)
        end)

        it("VimResized repositions the window without closing it", function()
            float_picker.open({
                title = "Test",
                items = { { display = "item", value = 1 } },
                on_select = function() end,
            })
            local win = find_float_win()
            assert.is_not_nil(win)

            -- Fire VimResized while the picker is open
            vim.api.nvim_command("doautocmd VimResized")

            -- Window should still be valid
            assert.is_true(vim.api.nvim_win_is_valid(win),
                "window should remain open after VimResized")
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Fuzzy scoring
    -- -------------------------------------------------------------------------
    describe("_fuzzy_score", function()
        it("returns 0 for empty query", function()
            assert.equals(0, float_picker._fuzzy_score("", "anything"))
        end)

        it("matches a simple subsequence (case-insensitive)", function()
            local s = float_picker._fuzzy_score("gpt", "gpt-4")
            assert.is_not_nil(s)
            assert.is_true(s >= 0)
        end)

        it("returns nil when word is not a subsequence", function()
            assert.is_nil(float_picker._fuzzy_score("xyz", "abc"))
        end)

        it("is case-insensitive", function()
            local s1 = float_picker._fuzzy_score("GPT", "gpt-4")
            local s2 = float_picker._fuzzy_score("gpt", "GPT-4")
            assert.is_not_nil(s1)
            assert.is_not_nil(s2)
        end)

        it("requires ALL words to match (AND logic)", function()
            -- 'gpt' matches but 'xyz' does not
            assert.is_nil(float_picker._fuzzy_score("gpt xyz", "gpt-4 openai"))
        end)

        it("word order in query does not matter", function()
            local s1 = float_picker._fuzzy_score("gpt open", "openai gpt-4")
            local s2 = float_picker._fuzzy_score("open gpt", "openai gpt-4")
            assert.is_not_nil(s1)
            assert.is_not_nil(s2)
        end)

        it("prefix match scores higher than mid-string token match", function()
            local s_prefix = float_picker._fuzzy_score("ag", "agent-a")
            local s_mid = float_picker._fuzzy_score("ag", "tools agent")
            assert.is_not_nil(s_prefix)
            assert.is_not_nil(s_mid)
            assert.is_true(s_prefix > s_mid,
                "prefix match should outscore mid-string match")
        end)

        it("consecutive characters score higher than scattered", function()
            local s_consec = float_picker._fuzzy_score("gpt", "gpt-4")
            local s_spread = float_picker._fuzzy_score("gpt", "a-g-path-tool")
            assert.is_not_nil(s_consec)
            assert.is_not_nil(s_spread)
            assert.is_true(s_consec >= s_spread,
                "consecutive match should score at least as high as spread")
        end)

        it("accepts small typos in token prefixes", function()
            local score = float_picker._fuzzy_score("anthrpic", "anthropic claude")
            assert.is_not_nil(score)
        end)

        it("requires approximate prefix matches to keep the first query character", function()
            assert.is_nil(float_picker._fuzzy_score("bnthrpic", "anthropic claude"))
        end)

        it("rejects tokens that are too far from any candidate prefix", function()
            assert.is_nil(float_picker._fuzzy_score("zzzz", "anthropic claude"))
        end)

        it("does not match by collapsing to a too-short prefix", function()
            assert.is_nil(float_picker._fuzzy_score("tech", "Family Chores App"))
        end)

        it("prefers token prefix matches over whole-string scattered matches", function()
            local prefix_score = float_picker._fuzzy_score("cla", "claude sonnet")
            local scattered_score = float_picker._fuzzy_score("cla", "specical layout")
            assert.is_not_nil(prefix_score)
            assert.is_not_nil(scattered_score)
            assert.is_true(prefix_score > scattered_score)
        end)

        it("does not match full plain words across word boundaries", function()
            assert.is_nil(float_picker._fuzzy_score("open", "only pen"))
        end)

        it("matches bracketed query tokens only against bracketed haystack tags", function()
            local score = float_picker._fuzzy_score("[tech]", "release notes [tech] roadmap")
            assert.is_not_nil(score)
            assert.is_nil(float_picker._fuzzy_score("[tech]", "release notes tech roadmap"))
        end)

        it("matches braced query tokens only against braced haystack labels", function()
            local score = float_picker._fuzzy_score("{family}", "{family} release notes")
            assert.is_not_nil(score)
            assert.is_nil(float_picker._fuzzy_score("{family}", "family release notes"))
        end)

        it("matches empty braced query tokens only against empty braced haystack labels", function()
            local score = float_picker._fuzzy_score("{}", "{} release notes")
            assert.is_not_nil(score)
            assert.is_nil(float_picker._fuzzy_score("{}", "{family} release notes"))
            assert.is_nil(float_picker._fuzzy_score("{}", "release notes"))
        end)

        it("matches in-progress { query (no closing brace) against braced haystack labels", function()
            assert.is_not_nil(float_picker._fuzzy_score("{char", "{charon} release notes"))
            assert.is_not_nil(float_picker._fuzzy_score("{c", "{charon} release notes"))
            -- still scoped to braced haystack tokens, not plain words
            assert.is_nil(float_picker._fuzzy_score("{char", "charon release notes"))
        end)

        it("matches in-progress [ query (no closing bracket) against bracketed haystack tags", function()
            assert.is_not_nil(float_picker._fuzzy_score("[te", "release notes [tech] roadmap"))
            assert.is_nil(float_picker._fuzzy_score("[te", "release notes tech roadmap"))
        end)
    end)

    describe("_tokenize_query", function()
        it("classifies completed brace tokens as root", function()
            local tokens = float_picker._tokenize_query("{charon}")
            assert.same({ { kind = "root", text = "charon" } }, tokens)
        end)

        it("classifies in-progress brace tokens as root", function()
            local tokens = float_picker._tokenize_query("{char")
            assert.same({ { kind = "root", text = "char" } }, tokens)
        end)

        it("classifies in-progress bracket tokens as tag", function()
            local tokens = float_picker._tokenize_query("[te")
            assert.same({ { kind = "tag", text = "te" } }, tokens)
        end)

        it("ignores lone { or [ with no payload", function()
            assert.same({}, float_picker._tokenize_query("{"))
            assert.same({}, float_picker._tokenize_query("["))
        end)
    end)

    describe("_fuzzy_match_details", function()
        it("marks edit-distance positions separately for approximate prefix matches", function()
            local details = float_picker._fuzzy_match_details("tehc", "tech stack")
            assert.is_not_nil(details)
            assert.equals(1, #details)
            assert.is_true(details[1].approximate)
            assert.same({ 1, 2 }, details[1].positions)
            assert.same({ 3, 4 }, details[1].edit_positions)
        end)

        it("rejects approximate prefix details when the first query character differs", function()
            local details = float_picker._fuzzy_match_details("behc", "tech stack")
            assert.is_nil(details)
        end)

        it("keeps exact prefix matches on the exact highlight path only", function()
            local details = float_picker._fuzzy_match_details("tech", "tech stack")
            assert.is_not_nil(details)
            assert.equals(1, #details)
            assert.is_false(details[1].approximate)
            assert.same({ 1, 2, 3, 4 }, details[1].positions)
            assert.same({}, details[1].edit_positions)
        end)
    end)

    -- -------------------------------------------------------------------------
    -- Recall: remember last confirmed selection across reopens
    -- -------------------------------------------------------------------------
    describe("recall", function()
        before_each(function()
            float_picker._last_selection = {}
        end)

        local function feed_cr()
            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<CR>", true, false, true), "x", true
            )
        end

        it("records confirmed item.value under recall_key", function()
            local picked = nil
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = "a" },
                    { display = "beta",  value = "b" },
                    { display = "gamma", value = "g" },
                },
                recall_key = "spec.basic",
                on_select = function(item) picked = item.value end,
            })
            feed_cr()
            vim.wait(200, function() return picked ~= nil end)
            assert.equals("a", float_picker._last_selection["spec.basic"])
        end)

        it("restores cursor to recalled value on reopen", function()
            float_picker._last_selection["spec.restore"] = "b"
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = "a" },
                    { display = "beta",  value = "b" },
                    { display = "gamma", value = "g" },
                },
                recall_key = "spec.restore",
                on_select = function() end,
            })

            local picked = nil
            -- Override on_select to capture what gets confirmed at the cursor.
            -- Simpler: read back cursor row and verify it points to "beta".
            local win = find_float_win()
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            local cursor = vim.api.nvim_win_get_cursor(win)
            assert.truthy(lines[cursor[1]]:find("beta", 1, true),
                "expected cursor on beta, got: " .. lines[cursor[1]])
            -- Suppress unused
            local _ = picked
        end)

        it("falls back when recalled value is no longer in items", function()
            float_picker._last_selection["spec.stale"] = "deleted_value"
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = "a" },
                    { display = "beta",  value = "b" },
                },
                recall_key = "spec.stale",
                on_select = function() end,
            })
            local win = find_float_win()
            local cursor = vim.api.nvim_win_get_cursor(win)
            -- With no recall match and no initial_index, cursor sits on the
            -- first logical item, which renders on the bottom row.
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            assert.truthy(lines[cursor[1]]:find("alpha", 1, true),
                "expected fallback to first item, got: " .. lines[cursor[1]])
        end)

        it("explicit initial_index wins over recall", function()
            float_picker._last_selection["spec.precedence"] = "a"
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = "a" },
                    { display = "beta",  value = "b" },
                    { display = "gamma", value = "g" },
                },
                recall_key = "spec.precedence",
                initial_index = 3,  -- gamma
                on_select = function() end,
            })
            local win = find_float_win()
            local cursor = vim.api.nvim_win_get_cursor(win)
            local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
            assert.truthy(lines[cursor[1]]:find("gamma", 1, true),
                "expected initial_index to win, got: " .. lines[cursor[1]])
        end)

        it("recall_id_fn extracts identity from a non-value field", function()
            local picked = nil
            float_picker.open({
                title = "Test",
                items = {
                    { display = "agent-A", name = "agent-A" },
                    { display = "agent-B", name = "agent-B" },
                },
                recall_key = "spec.agents",
                recall_id_fn = function(item) return item.name end,
                on_select = function(item) picked = item.name end,
            })
            feed_cr()
            vim.wait(200, function() return picked ~= nil end)
            assert.equals("agent-A", float_picker._last_selection["spec.agents"])
        end)

        it("Esc / cancel does not update recall", function()
            float_picker._last_selection["spec.cancel"] = "preserved"
            float_picker.open({
                title = "Test",
                items = {
                    { display = "alpha", value = "a" },
                    { display = "beta",  value = "b" },
                },
                recall_key = "spec.cancel",
                on_select = function() end,
                on_cancel = function() end,
            })
            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true
            )
            vim.wait(200, function() return find_any_float_win() == nil end)
            assert.equals("preserved", float_picker._last_selection["spec.cancel"])
        end)
    end)
end)
