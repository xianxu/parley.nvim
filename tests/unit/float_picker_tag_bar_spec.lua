local float_picker = require("parley.float_picker")
local facet_bar_layout = require("parley.facet_bar_layout")
local compute_layout = float_picker.compute_layout

local function display_text_units(text)
    local units = {}
    local count = vim.fn.strchars(text, true)
    for index = 0, count - 1 do
        table.insert(units, vim.fn.strcharpart(text, index, 1, true))
    end
    return units
end

local text_ops = {
    units = display_text_units,
    width = vim.fn.strdisplaywidth,
}

local function close_floats()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and config.relative ~= "" then
            pcall(vim.api.nvim_win_close, win, true)
        end
    end
end

local function find_float(predicate)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ok, config = pcall(vim.api.nvim_win_get_config, win)
        if ok and config.relative ~= "" then
            local buf = vim.api.nvim_win_get_buf(win)
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            if predicate(lines, config, win, buf) then
                return win, buf, config, lines
            end
        end
    end
end

local function open_picker(tags, opts)
    opts = opts or {}
    local tag_bar = nil
    if not opts.no_capability then
        tag_bar = {
            tags = tags,
            on_toggle = opts.on_toggle or function() end,
            on_all = opts.on_all or function() end,
            on_none = opts.on_none or function() end,
        }
    end
    return float_picker.open({
        title = "Facet test",
        width = opts.width,
        height = opts.height or 4,
        initial_query = opts.initial_query,
        items = opts.items or {
            { display = "alpha item", value = 1 },
            { display = "beta item", value = 2 },
            { display = "gamma item", value = 3 },
            { display = "delta item", value = 4 },
        },
        tag_bar = tag_bar,
        on_select = function() end,
    })
end

local function facet_float()
    return find_float(function(lines)
        return lines[1] and lines[1]:sub(1, 4) == " ALL"
    end)
end

local function prompt_float()
    return find_float(function(_, _, _, buf)
        return vim.bo[buf].buftype == "prompt"
    end)
end

local function results_float()
    return find_float(function(lines, _, _, buf)
        return vim.bo[buf].buftype == "nofile" and not (lines[1] and lines[1]:sub(1, 4) == " ALL")
    end)
end

local function highlight_spans(buf)
    local namespace = vim.api.nvim_get_namespaces().float_picker_tag_bar
    local spans = {}
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })) do
        table.insert(spans, {
            row = mark[2],
            byte_start = mark[3],
            byte_end = mark[4].end_col,
            hl = mark[4].hl_group,
        })
    end
    table.sort(spans, function(a, b)
        if a.row == b.row then return a.byte_start < b.byte_start end
        return a.row < b.row
    end)
    return spans
end

local function click_facet_cell(facet_win, cell0)
    local position = vim.api.nvim_win_get_position(facet_win)
    local _, prompt_buf = prompt_float()
    local mapping = vim.api.nvim_buf_call(prompt_buf, function()
        return vim.fn.maparg("<LeftMouse>", "n", false, true)
    end)
    local original_getmousepos = vim.fn.getmousepos
    vim.fn.getmousepos = function()
        return {
            screenrow = position[1] + 2,
            screencol = position[2] + 2 + cell0,
        }
    end
    mapping.callback()
    vim.fn.getmousepos = original_getmousepos
    vim.wait(100)
end

describe("float_picker facet bar geometry", function()
    it("adds numeric facet content height and two border rows to the visible stack", function()
        local win_w, win_h, row, col, tag_bar_row, prompt_row, facet_h =
            compute_layout(50, 10, { width = 100, height = 40 }, 3)

        assert.are.same({ 50, 10, 10, 25 }, { win_w, win_h, row, col })
        assert.equals(22, tag_bar_row)
        assert.equals(3, facet_h)
        assert.equals(tag_bar_row + facet_h + 2, prompt_row)
    end)

    it("shrinks results for the facet stack without going below one row", function()
        local _, shrunk_h = compute_layout(50, 50, { width = 100, height = 20 }, 3)
        local _, minimum_h, _, _, _, _, facet_h =
            compute_layout(50, 50, { width = 100, height = 15 }, 99)

        assert.equals(4, shrunk_h)
        assert.equals(1, minimum_h)
        assert.equals(1, facet_h)
    end)

    it("caps excessive facet height after reserving margins, prompt, borders, and results", function()
        local _, win_h, row, _, tag_bar_row, prompt_row, facet_h =
            compute_layout(50, 50, { width = 100, height = 18 }, 99)

        assert.equals(4, facet_h)
        assert.equals(1, win_h)
        assert.equals(3, row)
        assert.equals(6, tag_bar_row)
        assert.equals(12, prompt_row)
    end)

    it("keeps false and nil on the exact historical non-faceted geometry", function()
        local expected = { 70, 6, 6, 5, nil, 14, 0 }

        assert.are.same(expected, { compute_layout(70, 6, { width = 80, height = 24 }, false) })
        assert.are.same(expected, { compute_layout(70, 6, { width = 80, height = 24 }, nil) })
    end)

    it("treats true as the legacy one-row facet height", function()
        local legacy = { compute_layout(50, 10, { width = 100, height = 40 }, true) }
        local numeric = { compute_layout(50, 10, { width = 100, height = 40 }, 1) }

        assert.are.same(numeric, legacy)
        assert.equals(1, legacy[7])
    end)
end)

describe("float_picker facet bar rendering", function()
    local original_columns
    local original_lines

    before_each(function()
        original_columns = vim.o.columns
        original_lines = vim.o.lines
        close_floats()
    end)

    after_each(function()
        close_floats()
        vim.o.columns = original_columns
        vim.o.lines = original_lines
    end)

    it("renders every model row at the visible height and places the prompt after its border", function()
        local tags = {
            { label = "ordinary", enabled = true },
            { label = "extraordinarily-long-facet", enabled = false },
        }
        open_picker(tags, { width = 20 })

        local facet_win, _, facet_config, lines = facet_float()
        assert.is_not_nil(facet_win)
        local model = facet_bar_layout.build(tags, facet_config.width, text_ops)
        local _, _, _, _, facet_row, prompt_row, visible_height =
            compute_layout(20, 4, { width = vim.o.columns, height = vim.o.lines }, model.height)
        local _, _, prompt_config = prompt_float()

        assert.are.same(model.lines, lines)
        assert.equals(visible_height, facet_config.height)
        assert.equals(facet_row, facet_config.row)
        assert.equals(prompt_row, prompt_config.row)
        assert.equals(facet_config.row + facet_config.height + 2, prompt_config.row)
    end)

    it("keeps the wide one-row bar visually identical without trailing padding", function()
        open_picker({ { label = "repo", enabled = true } }, { width = 60 })

        local _, _, config, lines = facet_float()
        assert.equals(1, config.height)
        assert.are.same({ " ALL NONE  [repo]" }, lines)
    end)

    it("applies highlights from every model byte span including split continuations", function()
        local tags = {
            { label = "enabled", enabled = true },
            { label = "disabled-and-split-across-rows", enabled = false },
        }
        open_picker(tags, { width = 20 })

        local _, buf, config = facet_float()
        local model = facet_bar_layout.build(tags, config.width, text_ops)
        local expected = {}
        for _, segment in ipairs(model.segments) do
            local hl
            if segment.kind == "action" then
                hl = segment.active and "ParleyTagAction" or "ParleyTagOff"
            else
                hl = segment.enabled and "ParleyTagOn" or "ParleyTagOff"
            end
            table.insert(expected, {
                row = segment.row,
                byte_start = segment.byte_start,
                byte_end = segment.byte_end,
                hl = hl,
            })
        end

        assert.are.same(expected, highlight_spans(buf))
        local split_rows = {}
        for _, segment in ipairs(model.segments) do
            if segment.label == "disabled-and-split-across-rows" then
                split_rows[segment.row] = true
            end
        end
        local count = 0
        for _ in pairs(split_rows) do count = count + 1 end
        assert.is_true(count > 1)
    end)

    it("highlights active ALL and NONE actions and enabled and disabled facets", function()
        local cases = {
            {
                tags = { { label = "one", enabled = true }, { label = "two", enabled = true } },
                action_hls = { "ParleyTagAction", "ParleyTagOff" },
            },
            {
                tags = { { label = "one", enabled = false }, { label = "two", enabled = false } },
                action_hls = { "ParleyTagOff", "ParleyTagAction" },
            },
            {
                tags = { { label = "one", enabled = true }, { label = "two", enabled = false } },
                action_hls = { "ParleyTagOff", "ParleyTagOff" },
            },
        }

        for _, case in ipairs(cases) do
            close_floats()
            open_picker(case.tags, { width = 60 })
            local _, buf = facet_float()
            local spans = highlight_spans(buf)
            assert.equals(case.action_hls[1], spans[1].hl)
            assert.equals(case.action_hls[2], spans[2].hl)
            assert.equals(case.tags[1].enabled and "ParleyTagOn" or "ParleyTagOff", spans[3].hl)
            assert.equals(case.tags[2].enabled and "ParleyTagOn" or "ParleyTagOff", spans[4].hl)
        end
    end)

    it("keeps extended grapheme clusters intact through the production adapter", function()
        local clusters = { "é", "👩‍💻", "🇺🇸", "👍🏽", "1️⃣", "क्ष" }
        local tags = {}
        for _, cluster in ipairs(clusters) do
            table.insert(tags, { label = cluster:rep(7), enabled = true })
        end
        open_picker(tags, { width = 20 })

        local _, _, config, lines = facet_float()
        local model = facet_bar_layout.build(tags, config.width, text_ops)
        assert.are.same(model.lines, lines)
        for _, cluster in ipairs(clusters) do
            assert.equals(1, #display_text_units(cluster))
        end
    end)

    it("reflows exact rows and geometry on resize without rewriting the live query", function()
        vim.o.columns = 70
        vim.o.lines = 30
        local tags = {
            { label = "one-ordinary-facet", enabled = true },
            { label = "another-extraordinarily-long-facet", enabled = false },
        }
        open_picker(tags, { width = 999, height = 12, initial_query = "alpha" })
        local _, prompt_buf = prompt_float()
        local live_query = ">   alpha item  "
        vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, { live_query })
        local expected_cursor_col = #live_query - 2
        vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { 1, expected_cursor_col })
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt_buf })

        vim.o.columns = 36
        vim.api.nvim_exec_autocmds("VimResized", {})

        local _, _, facet_config, facet_lines = facet_float()
        local _, _, results_config = results_float()
        local _, _, prompt_config = prompt_float()
        local model = facet_bar_layout.build(tags, facet_config.width, text_ops)
        local _, results_height, _, _, facet_row, prompt_row, facet_height =
            compute_layout(999, 12, { width = vim.o.columns, height = vim.o.lines }, model.height)

        assert.are.same(model.lines, facet_lines)
        assert.equals(facet_height, facet_config.height)
        assert.equals(facet_row, facet_config.row)
        assert.equals(results_height, results_config.height)
        assert.equals(prompt_row, prompt_config.row)
        assert.equals(live_query, vim.api.nvim_buf_get_lines(prompt_buf, 0, 1, false)[1])
        assert.equals(expected_cursor_col, vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[2])
    end)

    it("withholds a zero-height facet float on open and restores it when space returns", function()
        vim.o.columns = 40
        vim.o.lines = 10
        local tags = { { label = "still-logically-active", enabled = true } }

        local ok, picker = pcall(open_picker, tags, { width = 30, height = 4 })

        assert.is_true(ok, picker)
        assert.is_table(picker)
        assert.is_nil(facet_float())
        assert.is_not_nil(results_float())
        assert.is_not_nil(prompt_float())

        vim.o.lines = 24
        vim.api.nvim_exec_autocmds("VimResized", {})

        local facet_win, _, _, lines = facet_float()
        assert.is_not_nil(facet_win)
        assert.truthy(table.concat(lines, "\n"):find("still-logically-active", 1, true))
        assert.equals(1, vim.api.nvim_win_call(facet_win, vim.fn.winsaveview).topline)
    end)

    it("withholds a facet float when resize leaves zero rows and recreates it later", function()
        vim.o.columns = 40
        vim.o.lines = 24
        local tags = { { label = "survives-collapse", enabled = true } }
        open_picker(tags, { width = 30, height = 4 })
        assert.is_not_nil(facet_float())

        vim.o.lines = 10
        local collapse_ok, collapse_error = pcall(vim.api.nvim_exec_autocmds, "VimResized", {})

        assert.is_true(collapse_ok, collapse_error)
        assert.is_nil(facet_float())
        assert.is_not_nil(results_float())
        assert.is_not_nil(prompt_float())

        vim.o.lines = 24
        local restore_ok, restore_error = pcall(vim.api.nvim_exec_autocmds, "VimResized", {})

        assert.is_true(restore_ok, restore_error)
        local facet_win, _, _, lines = facet_float()
        assert.is_not_nil(facet_win)
        assert.truthy(table.concat(lines, "\n"):find("survives-collapse", 1, true))
        assert.equals(1, vim.api.nvim_win_call(facet_win, vim.fn.winsaveview).topline)
    end)

    it("does not dispatch a lower-row facet from first-row whitespace", function()
        local toggled = nil
        open_picker({ { label = "ordinary", enabled = true } }, {
            width = 20,
            on_toggle = function(label) toggled = label end,
        })
        local facet_win, _, _, lines = facet_float()
        assert.are.same({ " ALL NONE", " [ordinary]" }, lines)

        click_facet_cell(facet_win, 10)

        assert.is_nil(toggled)
    end)

    it("removes and recreates the facet float while reclaiming geometry", function()
        vim.o.columns = 42
        vim.o.lines = 22
        local tags = {
            { label = "a-long-facet-for-several-rows", enabled = true },
            { label = "another-long-facet-for-several-rows", enabled = false },
        }
        local all_calls = 0
        local picker = open_picker(tags, {
            width = 34,
            height = 12,
            on_all = function() all_calls = all_calls + 1 end,
        })
        local old_facet_win = facet_float()
        vim.api.nvim_win_call(old_facet_win, function()
            vim.fn.winrestview({ topline = 2 })
        end)

        picker.update({ { display = "replacement", value = 5 } }, {})

        assert.is_nil(facet_float())
        local _, _, inactive_results = results_float()
        local _, expected_inactive_height =
            compute_layout(34, 12, { width = vim.o.columns, height = vim.o.lines }, 0)
        assert.equals(expected_inactive_height, inactive_results.height)

        picker.update({ { display = "replacement", value = 5 } }, tags)

        local new_facet_win, _, new_facet_config, lines = facet_float()
        assert.is_not_nil(new_facet_win)
        assert.is_false(new_facet_win == old_facet_win)
        assert.are.same(facet_bar_layout.build(tags, new_facet_config.width, text_ops).lines, lines)
        local view = vim.api.nvim_win_call(new_facet_win, vim.fn.winsaveview)
        assert.equals(1, view.topline)
        click_facet_cell(new_facet_win, 1)
        assert.equals(1, all_calls)
    end)

    it("retains facets when update omits tags and preserves their numeric topline", function()
        vim.o.columns = 32
        vim.o.lines = 18
        local tags = {
            { label = "first-extraordinarily-long-facet", enabled = true },
            { label = "second-extraordinarily-long-facet", enabled = false },
            { label = "third-extraordinarily-long-facet", enabled = true },
        }
        local picker = open_picker(tags, { width = 24, height = 5 })
        local facet_win, _, _, before_lines = facet_float()
        vim.api.nvim_win_call(facet_win, function()
            vim.fn.winrestview({ topline = 3 })
        end)

        picker.update({ { display = "new item", value = 9 } })

        local same_win, _, config, after_lines = facet_float()
        assert.equals(facet_win, same_win)
        assert.are.same(before_lines, after_lines)
        local view = vim.api.nvim_win_call(same_win, vim.fn.winsaveview)
        local max_topline = math.max(1, #after_lines - config.height + 1)
        assert.equals(math.min(3, max_topline), view.topline)
    end)

    it("can activate an initially empty capable facet bar", function()
        local picker = open_picker({}, { width = 30 })
        assert.is_nil(facet_float())

        picker.update({ { display = "later item", value = 2 } }, {
            { label = "later", enabled = true },
        })

        local facet_win = facet_float()
        assert.is_not_nil(facet_win)
    end)

    it("never adds a facet float when the picker was opened without capability", function()
        local picker = open_picker(nil, { width = 30, no_capability = true })
        assert.is_nil(facet_float())

        picker.update({ { display = "later item", value = 2 } }, {
            { label = "ignored", enabled = true },
        })

        assert.is_nil(facet_float())
    end)

    it("makes update after close a no-op", function()
        local picker = open_picker({ { label = "one", enabled = true } }, { width = 30 })
        close_floats()

        local ok, error_message = pcall(picker.update, {
            { display = "later", value = 2 },
        }, { { label = "later", enabled = true } })

        assert.is_true(ok, error_message)
        assert.is_nil(facet_float())
    end)

    it("does not recreate orphan floats after a facet or results window is invalidated", function()
        local picker = open_picker({ { label = "one", enabled = true } }, { width = 30 })
        local facet_win = facet_float()
        vim.api.nvim_win_close(facet_win, true)

        local update_ok, update_error = pcall(picker.update, {
            { display = "later item", value = 2 },
        }, {
            { label = "one", enabled = false },
        })
        assert.is_true(update_ok, update_error)
        assert.is_nil(facet_float())

        close_floats()
        picker = open_picker({ { label = "two", enabled = true } }, { width = 30 })
        local results_win = results_float()
        vim.api.nvim_win_close(results_win, true)

        local resize_ok, resize_error = pcall(vim.api.nvim_exec_autocmds, "VimResized", {})
        assert.is_true(resize_ok, resize_error)
        assert.is_nil(results_float())
        assert.is_nil(facet_float())
        assert.is_nil(prompt_float())
    end)
end)
