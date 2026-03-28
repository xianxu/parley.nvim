-- Issue finder module for Parley
-- Float picker UI for browsing, filtering, and managing issues

local issues_mod = require("parley.issues")

local M = {}
local _parley

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- Reopen helper
--------------------------------------------------------------------------------

M.reopen = function(source_win, selection_index, selection_value)
    vim.defer_fn(function()
        _parley._issue_finder.opened = false
        _parley._issue_finder.source_win = source_win
        _parley._issue_finder.initial_index = selection_index
        _parley._issue_finder.initial_value = selection_value
        _parley.cmd.IssueFinder()
    end, 100)
end

--------------------------------------------------------------------------------
-- Delete confirmation
--------------------------------------------------------------------------------

M.handle_delete_response = function(input, item_value, selected_index, items_count, source_win, close_fn, context)
    if input and input:lower() == "y" then
        _parley.helpers.delete_file(item_value)
        if close_fn then
            close_fn()
        end
        local next_index = math.min(selected_index, math.max(1, items_count - 1))
        local next_value = nil
        local items = context and context.issue_finder_items or nil
        if type(items) == "table" then
            local next_item = items[selected_index + 1] or items[selected_index - 1]
            next_value = next_item and next_item.value or nil
        end
        M.reopen(source_win, next_index, next_value)
        return
    end

    if context then
        context.resume_after_external_ui()
        vim.schedule(function()
            if context.focus_prompt then
                context.focus_prompt()
            end
        end)
        vim.defer_fn(function()
            if context.focus_prompt then
                context.focus_prompt()
            end
        end, 10)
        return
    end

    M.reopen(source_win, selected_index, item_value)
end

M.prompt_delete_confirmation = function(item_value, selected_index, items_count, source_win, close_fn, context)
    if source_win and vim.api.nvim_win_is_valid(source_win) then
        vim.api.nvim_set_current_win(source_win)
    end

    vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " }, function(input)
        M.handle_delete_response(
            input,
            item_value,
            selected_index,
            items_count,
            source_win,
            close_fn,
            context
        )
    end)
end

--------------------------------------------------------------------------------
-- Main IssueFinder open function
--------------------------------------------------------------------------------

M.open = function(_options)
    if _parley._issue_finder.opened then
        _parley.logger.warning("Issue finder is already open")
        return
    end
    _parley._issue_finder.opened = true

    local issue_finder_mappings = _parley.config.issue_finder_mappings or {}
    local delete_shortcut = issue_finder_mappings.delete or { shortcut = "<C-d>" }
    local cycle_status_shortcut = issue_finder_mappings.cycle_status or { shortcut = "<C-s>" }
    local toggle_done_shortcut = issue_finder_mappings.toggle_done or { shortcut = "<C-a>" }

    local issues_dir = issues_mod.get_issues_dir()
    if not issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        _parley._issue_finder.opened = false
        return
    end

    local all_issues = issues_mod.scan_issues(issues_dir)
    local show_done = _parley._issue_finder.show_done or false

    -- Filter and sort
    local filtered = {}
    for _, issue in ipairs(all_issues) do
        if show_done or issue.status ~= "done" then
            table.insert(filtered, issue)
        end
    end
    local sorted = issues_mod.topo_sort(filtered)

    -- Build picker items
    local items = {}
    for _, issue in ipairs(sorted) do
        local display = string.format("[%s] %s %s", issue.status, issue.id, issue.title ~= "" and issue.title or issue.slug)
        if issue.created ~= "" then
            display = display .. " [" .. issue.created .. "]"
        end
        table.insert(items, {
            display = display,
            search_text = string.format("%s %s %s %s", issue.status, issue.id, issue.title, issue.slug),
            value = issue.path,
            issue = issue,
        })
    end

    local source_win = _parley._issue_finder.source_win
    if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
        source_win = vim.api.nvim_get_current_win()
        _parley._issue_finder.source_win = source_win
    end

    local chat_finder_mod = require("parley.chat_finder")

    local done_label = show_done and "all" or "open+blocked"
    local prompt_title = string.format(
        "Issues (%s  %s: toggle done)",
        done_label,
        toggle_done_shortcut.shortcut
    )

    _parley.float_picker.open({
        title = prompt_title,
        items = items,
        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
        anchor = "bottom",
        on_select = function(item)
            if source_win and vim.api.nvim_win_is_valid(source_win) then
                vim.api.nvim_set_current_win(source_win)
            end
            _parley.open_buf(item.value, true)
        end,
        on_cancel = function()
            _parley._issue_finder.opened = false
            _parley._issue_finder.initial_index = nil
            _parley._issue_finder.initial_value = nil
        end,
        mappings = {
            {
                key = delete_shortcut.shortcut,
                fn = function(item, close_fn, context)
                    if not item then
                        return
                    end
                    local selected_index = 1
                    for idx, picker_item in ipairs(items) do
                        if picker_item.value == item.value then
                            selected_index = idx
                            break
                        end
                    end

                    context.skip_focus_restore = true
                    context.issue_finder_items = items
                    context.suspend_for_external_ui()
                    vim.defer_fn(function()
                        M.prompt_delete_confirmation(
                            item.value,
                            selected_index,
                            #items,
                            source_win,
                            close_fn,
                            context
                        )
                    end, 20)
                end,
            },
            {
                key = cycle_status_shortcut.shortcut,
                fn = function(item, close_fn)
                    if not item or not item.issue then
                        return
                    end
                    -- Read the file, cycle status, write back
                    local lines = vim.fn.readfile(item.value)
                    local fm = issues_mod.parse_frontmatter(lines)
                    if fm then
                        local new_status = issues_mod.cycle_status_value(fm.status)
                        for i = 2, fm.header_end - 1 do
                            if lines[i]:match("^status:") then
                                lines[i] = "status: " .. new_status
                            end
                            if lines[i]:match("^updated:") then
                                lines[i] = "updated: " .. os.date("%Y-%m-%d")
                            end
                        end
                        vim.fn.writefile(lines, item.value)
                    end
                    -- Reopen to refresh
                    close_fn()
                    M.reopen(source_win, nil, item.value)
                end,
            },
            {
                key = toggle_done_shortcut.shortcut,
                fn = function(_, close_fn)
                    _parley._issue_finder.show_done = not show_done
                    close_fn()
                    vim.defer_fn(function()
                        _parley._issue_finder.opened = false
                        _parley._issue_finder.source_win = source_win
                        _parley.cmd.IssueFinder()
                    end, 100)
                end,
            },
        },
    })

    _parley._issue_finder.initial_index = nil
    _parley._issue_finder.initial_value = nil
    _parley._issue_finder.opened = false
end

return M
