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

        it("keeps exact prefix matches on the exact highlight path only", function()
            local details = float_picker._fuzzy_match_details("tech", "tech stack")
            assert.is_not_nil(details)
            assert.equals(1, #details)
            assert.is_false(details[1].approximate)
            assert.same({ 1, 2, 3, 4 }, details[1].positions)
            assert.same({}, details[1].edit_positions)
        end)
    end)
end)
