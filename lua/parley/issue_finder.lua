-- Issue finder module for Parley
-- Float picker UI for browsing, filtering, and managing issues

local issues_mod = require("parley.issues")
local finder_sticky = require("parley.finder_sticky")

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
        issues_mod.invalidate_path(item_value)
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

    -- Compute issue roots: in super-repo mode, one per member; otherwise just the single repo.
    local sr_issues = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.issues_dir) or nil
    local sr_history = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.history_dir) or nil
    local roots
    if sr_issues then
        roots = {}
        for i, r in ipairs(sr_issues) do
            table.insert(roots, {
                issues_dir = r.dir,
                history_dir = sr_history and sr_history[i] and sr_history[i].dir or nil,
                repo_name = r.repo_name,
            })
        end
    else
        roots = { {
            issues_dir = issues_mod.get_issues_dir(),
            history_dir = issues_mod.get_history_dir(),
            repo_name = nil,
        } }
    end
    if #roots == 0 or not roots[1].issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        _parley._issue_finder.opened = false
        return
    end

    -- View mode: 0=active (open+working+blocked), 1=all (incl done+wontfix), 2=all+history
    local view_mode = _parley._issue_finder.view_mode or 0
    local include_history = view_mode == 2
    local all_issues = {}
    for _, root in ipairs(roots) do
        if root.issues_dir then
            local got = issues_mod.scan_issues(root.issues_dir, {
                include_history = include_history,
                history_dir_override = root.history_dir,
                repo_name = root.repo_name,
            })
            vim.list_extend(all_issues, got)
        end
    end

    -- Filter based on view mode
    local filtered = {}
    for _, issue in ipairs(all_issues) do
        if view_mode == 0 then
            -- Active issues only: open, working, blocked (exclude done, wontfix, punt, archived)
            if issue.status ~= "done" and issue.status ~= "wontfix" and issue.status ~= "punt" and not issue.archived then
                table.insert(filtered, issue)
            end
        else
            -- view_mode 1 or 2: show all
            table.insert(filtered, issue)
        end
    end
    local sorted = issues_mod.topo_sort(filtered)

    -- Build picker items
    local items = {}
    for _, issue in ipairs(sorted) do
        local prefix = issue.archived and "[archived]" or string.format("[%s]", issue.status)
        local label = issue.title ~= "" and issue.title or issue.slug
        local repo_prefix = issue.repo_name and ("{" .. issue.repo_name .. "} ") or ""
        local display = string.format("%s%s %s %s", repo_prefix, prefix, issue.id, label)
        if issue.github_issue then
            display = display .. " (#" .. issue.github_issue .. ")"
        end
        if issue.created ~= "" then
            display = display .. " [" .. issue.created .. "]"
        end
        table.insert(items, {
            display = display,
            search_text = string.format("%s%s %s %s %s", repo_prefix, issue.status, issue.id, issue.title, issue.slug),
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

    local view_labels = { [0] = "active", [1] = "all", [2] = "all+history" }
    local prompt_title = string.format(
        "Issues (%s  %s: cycle view)",
        view_labels[view_mode] or "open+blocked",
        toggle_done_shortcut.shortcut
    )

    _parley.float_picker.open({
        title = prompt_title,
        items = items,
        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
        initial_query = finder_sticky.format_initial_query(_parley._issue_finder.sticky_query),
        anchor = "bottom",
        on_query_change = function(query)
            _parley._issue_finder.sticky_query = finder_sticky.extract(query, { "root" })
        end,
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
                        issues_mod.invalidate_path(item.value)
                    end
                    -- Reopen to refresh
                    close_fn()
                    M.reopen(source_win, nil, item.value)
                end,
            },
            {
                key = toggle_done_shortcut.shortcut,
                fn = function(_, close_fn)
                    _parley._issue_finder.view_mode = (view_mode + 1) % 3
                    close_fn()
                    vim.defer_fn(function()
                        _parley._issue_finder.opened = false
                        _parley._issue_finder.source_win = source_win
                        _parley.cmd.IssueFinder()
                    end, 100)
                end,
            },
            -- Show key bindings help
            {
                key = (_parley.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }).shortcut,
                fn = function(_, _)
                    vim.schedule(function()
                        _parley.cmd.KeyBindings("issue_finder")
                    end)
                end,
            },
        },
    })

    _parley._issue_finder.initial_index = nil
    _parley._issue_finder.initial_value = nil
    _parley._issue_finder.opened = false
end

return M
