-- Issue finder module for Parley
-- Float picker UI for browsing, filtering, and managing issues

local issues_mod = require("parley.issues")
local finder_facets = require("parley.finder_facets")

local M = {}
local _parley

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- View-mode logic (pure)
--
-- The IssueFinder cycles a TWO-state `view_mode` via (view_mode + 1) % 2, on
-- both `<Tab>` (cycle_view — the natural key) and `<C-a>` (toggle_done, kept
-- for back-compat). View 0 = `issues` (everything in `workshop/issues/`);
-- view 1 = `history` (the archived items in `workshop/history/`). #158
-- (superseding the tri-state all/active/all+history from #152).
--------------------------------------------------------------------------------

M.VIEW_LABELS = { [0] = "issues", [1] = "history" }

-- Does this view mode scan archived files from the history dir? Only `history`.
M.includes_history = function(view_mode)
    return view_mode == 1
end

-- Which scanned issues survive the given view_mode, partitioned by the
-- `archived` flag: view 0 (`issues`) keeps non-archived items, view 1
-- (`history`) keeps archived items. A nil `archived` counts as non-archived.
-- Returns a fresh list (no mutation).
M.filter_for_view = function(view_mode, all_issues)
    local want_archived = view_mode == 1
    local filtered = {}
    for _, issue in ipairs(all_issues) do
        if (issue.archived == true) == want_archived then
            table.insert(filtered, issue)
        end
    end
    return filtered
end

M.sort_for_view = function(view_mode, issues)
    if view_mode ~= 1 then
        return issues_mod.topo_sort(issues)
    end

    local sorted = {}
    for _, issue in ipairs(issues) do
        table.insert(sorted, issue)
    end
    table.sort(sorted, function(a, b)
        local ma = a.mtime or 0
        local mb = b.mtime or 0
        if ma ~= mb then
            return ma < mb
        end
        return a.id < b.id
    end)
    return sorted
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
    local cycle_view_shortcut = issue_finder_mappings.cycle_view or { shortcut = "<Tab>" }

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
    local repo_facets = finder_facets.eligible_labels(roots, sr_issues ~= nil, function(root)
        return root.repo_name
    end)

    -- View mode: 0=issues (default), 1=history. Clamp with % 2 so any stale
    -- in-memory value (e.g. a `2` left by the pre-#158 tri-state) self-heals.
    local view_mode = (_parley._issue_finder.view_mode or 0) % 2
    local include_history = M.includes_history(view_mode)
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

    local sorted = M.sort_for_view(view_mode, M.filter_for_view(view_mode, all_issues))

    if repo_facets then
        _parley._issue_finder.repo_facet_state = finder_facets.merge_state(
            _parley._issue_finder.repo_facet_state,
            repo_facets
        )
    end

    local function issue_facets(issue)
        return { issue.repo_name }
    end

    local function render_issue(issue)
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
        return {
            display = display,
            search_text = string.format("%s%s %s %s %s", repo_prefix, issue.status, issue.id, issue.title, issue.slug),
            value = issue.path,
            issue = issue,
        }
    end

    local function build_picker_data()
        local visible = sorted
        if repo_facets then
            visible = finder_facets.filter(
                sorted,
                _parley._issue_finder.repo_facet_state,
                issue_facets
            )
        end
        local rendered = {}
        for _, issue in ipairs(visible) do
            table.insert(rendered, render_issue(issue))
        end
        local tags = nil
        if repo_facets then
            tags = finder_facets.project(repo_facets, _parley._issue_finder.repo_facet_state)
        end
        return rendered, tags
    end

    local items, repo_tag_bar_tags = build_picker_data()

    local source_win = _parley._issue_finder.source_win
    if not (source_win and vim.api.nvim_win_is_valid(source_win)) then
        source_win = vim.api.nvim_get_current_win()
        _parley._issue_finder.source_win = source_win
    end

    -- Cycle the 2-state view (issues ↔ history) and reopen. Shared by both the
    -- `<Tab>` (cycle_view) and `<C-a>` (toggle_done) mappings — one handler,
    -- two keys (#158, ARCH-DRY).
    local function cycle_view_fn(_, close_fn)
        _parley._issue_finder.view_mode = (view_mode + 1) % 2
        close_fn()
        vim.defer_fn(function()
            _parley._issue_finder.opened = false
            _parley._issue_finder.source_win = source_win
            _parley.cmd.IssueFinder()
        end, 100)
    end

    local chat_finder_mod = require("parley.chat_finder")

    local prompt_title = string.format(
        "Issues (%s  %s: cycle view)",
        M.VIEW_LABELS[view_mode] or M.VIEW_LABELS[0],
        cycle_view_shortcut.shortcut
    )

    local picker_ref = {}
    local tag_bar = nil
    if repo_tag_bar_tags then
        local function refresh_picker()
            items, repo_tag_bar_tags = build_picker_data()
            if picker_ref.update then
                picker_ref.update(items, repo_tag_bar_tags)
            end
        end
        local function set_all_repos(enabled)
            _parley._issue_finder.repo_facet_state = finder_facets.set_all(
                _parley._issue_finder.repo_facet_state,
                enabled
            )
            refresh_picker()
        end
        tag_bar = {
            tags = repo_tag_bar_tags,
            on_toggle = function(repo_name)
                _parley._issue_finder.repo_facet_state = finder_facets.toggle(
                    _parley._issue_finder.repo_facet_state,
                    repo_name
                )
                refresh_picker()
            end,
            on_all = function() set_all_repos(true) end,
            on_none = function() set_all_repos(false) end,
        }
    end

    local picker = _parley.float_picker.open({
        title = prompt_title,
        items = items,
        recall_key = "parley.issue_finder",
        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._issue_finder, items, "IssueFinder"),
        initial_query = _parley._issue_finder.query,
        anchor = "bottom",
        tag_bar = tag_bar,
        on_query_change = function(query)
            _parley._issue_finder.query = query
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
                key = cycle_view_shortcut.shortcut,
                fn = cycle_view_fn,
            },
            {
                key = toggle_done_shortcut.shortcut,
                fn = cycle_view_fn,
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
    if picker then
        picker_ref.update = picker.update
    end

    _parley._issue_finder.initial_index = nil
    _parley._issue_finder.initial_value = nil
    _parley._issue_finder.opened = false
end

return M
