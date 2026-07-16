-- Issue finder module for Parley
-- Float picker UI for browsing, filtering, and managing issues

local issues_mod = require("parley.issues")
local finder_facets = require("parley.finder_facets")
local finder_scan = require("parley.finder_scan")
local finder_loader = require("parley.finder_loader")
local finder_producer = require("parley.finder_producer")
local async_file_source = require("parley.async_file_source")
local issue_records = require("parley.issue_finder_records")

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
-- Asynchronous discovery
--------------------------------------------------------------------------------

local function discovery_dependencies()
    local injected = _parley._finder_dependencies or {}
    return {
        async_file_source = injected.async_file_source or async_file_source,
        schedule = injected.schedule or vim.schedule,
        now = injected.now or function()
            return (vim.uv or vim.loop).hrtime() / 1000000
        end,
    }
end

local function absolute_configured_dir(value, fallback)
    if type(value) == "string" and value:sub(1, 1) == "/" then
        return vim.fn.fnamemodify(vim.fn.expand(value), ":p"):gsub("/+$", "")
    end
    return fallback()
end

local function discovery_roots(view_mode)
    local issue_roots = _parley.super_repo
        and _parley.super_repo.expand_roots(_parley.config.issues_dir) or nil
    local history_roots = _parley.super_repo
        and _parley.super_repo.expand_roots(_parley.config.history_dir) or nil
    local archived = M.includes_history(view_mode)
    local selected = archived and history_roots or issue_roots
    local roots = {}

    if selected then
        for _, root in ipairs(selected) do
            if type(root.dir) == "string" and root.dir ~= "" then
                roots[#roots + 1] = {
                    path = vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"):gsub("/+$", ""),
                    label = root.repo_name,
                    repo_name = root.repo_name,
                    archived = archived,
                    optional = true,
                }
            end
        end
    else
        local path
        if archived then
            path = absolute_configured_dir(_parley.config.history_dir, issues_mod.get_history_dir)
        else
            path = absolute_configured_dir(_parley.config.issues_dir, issues_mod.get_issues_dir)
        end
        if path then
            roots[1] = { path = path, archived = archived, optional = true }
        end
    end
    return roots, issue_roots ~= nil
end

local function discovery_snapshot(view_mode)
    local roots, super_repo = discovery_roots(view_mode)
    return finder_scan.snapshot({
        kind = "issue",
        roots = roots,
        recursion = false,
        max_depth = 1,
        pattern = "*.md",
        backend = { source = "libuv", read = "all", view = view_mode },
    }), super_repo
end

local function split_lines(payload)
    local lines = {}
    for line in ((payload or "") .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function identity_for(candidate)
    return finder_scan.path_identity({
        unresolved_absolute = candidate.unresolved_absolute,
        resolved_absolute = candidate.resolved_absolute,
        root_ordinal = candidate.root_ordinal,
    })
end

local function file_cache()
    return issues_mod.get_cache()
end

local function read_decision(candidate)
    local identity = identity_for(candidate)
    local mtime = candidate.stat and candidate.stat.mtime and candidate.stat.mtime.sec
    local cached = file_cache()[identity.key]
    if type(cached) == "table" and cached.mtime == mtime and type(cached.issue_data) == "table" then
        return { kind = "ready", value = cached.issue_data }
    end
    return { kind = "read", mode = "all" }
end

local function cached_record(candidate, identity)
    local record = vim.deepcopy(candidate.precomputed)
    record.path = candidate.unresolved_absolute
    record.mtime = candidate.stat.mtime.sec
    record.archived = candidate.root.archived == true
    record.repo_name = candidate.root.repo_name
    record.identity = identity
    return { kind = "record", value = record }
end

local function cache_entry(record)
    return {
        mtime = record.mtime,
        root_path = record.root_path,
        issue_data = {
            id = record.id,
            slug = record.slug,
            title = record.title,
            status = record.status,
            deps = vim.deepcopy(record.deps),
            created = record.created,
            updated = record.updated,
            github_issue = record.github_issue,
            path = record.path,
        },
    }
end

local function new_session(snapshot)
    local dependencies = discovery_dependencies()
    return finder_loader.new_session({
        snapshot = snapshot,
        ownership = "picker",
        schedule = dependencies.schedule,
        producer_factory = function(settle)
            local data = snapshot:copy()
            return finder_producer.run({
                roots = data.roots,
                acquire = function(on_root, on_complete)
                    return dependencies.async_file_source.scan({
                        roots = data.roots,
                        recurse = false,
                        max_depth = 1,
                        match = function(relative)
                            return relative:match("%.md$") ~= nil
                        end,
                        read_policy = read_decision,
                        concurrency = 16,
                    }, on_root, on_complete)
                end,
                adapter = function(candidate)
                    local identity = candidate.identity or identity_for(candidate)
                    if candidate.precomputed ~= nil then
                        return cached_record(candidate, identity)
                    end
                    return issue_records.adapt({
                        path = candidate.unresolved_absolute,
                        name = candidate.relative:match("([^/]+)$") or candidate.relative,
                        mtime = candidate.stat.mtime.sec,
                        lines = split_lines(candidate.payload),
                        archived = candidate.root.archived == true,
                        repo_name = candidate.root.repo_name,
                        identity = identity,
                    })
                end,
                finalize = function(records)
                    return finder_scan.deduplicate(records)
                end,
                batch = {
                    item_budget = 25,
                    time_budget_ms = 5,
                    now = dependencies.now,
                    schedule = dependencies.schedule,
                },
                on_record = function(record)
                    record.root_path = data.roots[record.identity.source.root_ordinal].path
                    file_cache()[record.identity.key] = cache_entry(record)
                    record.root_path = nil
                end,
                on_root_success = function(root_ordinal, seen_keys)
                    local seen = {}
                    for _, key in ipairs(seen_keys) do
                        seen[key] = true
                    end
                    local root_path = data.roots[root_ordinal].path
                    for key, cached in pairs(file_cache()) do
                        if cached.root_path == root_path and not seen[key] then
                            file_cache()[key] = nil
                        end
                    end
                end,
            }, settle)
        end,
    })
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

    -- View mode: 0=issues (default), 1=history. Clamp with % 2 so any stale
    -- in-memory value (e.g. a `2` left by the pre-#158 tri-state) self-heals.
    local view_mode = (_parley._issue_finder.view_mode or 0) % 2
    local snapshot, super_repo = discovery_snapshot(view_mode)
    local roots = snapshot:copy().roots
    if #roots == 0 then
        _parley.logger.warning(M.includes_history(view_mode)
            and "history_dir is not configured" or "issues_dir is not configured")
        _parley._issue_finder.opened = false
        return
    end
    local session = new_session(snapshot)
    local repo_facets = finder_facets.eligible_labels(roots, super_repo, function(root)
        return root.repo_name
    end)
    local sorted = {}

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

    local loading = finder_loader.open_picker({
        session = session,
        picker_open = _parley.float_picker.open,
        finder_name = "Issue finder",
        warning = function(failed_roots, failed_records)
            _parley.logger.warning(string.format(
                "Issue finder: partial scan (%d roots, %d files failed)",
                failed_roots,
                failed_records
            ))
        end,
        materialize = function(outcome)
            sorted = issue_records.materialize(outcome.records, {
                archived = M.includes_history(view_mode),
            })
            items, repo_tag_bar_tags = build_picker_data()
            return {
                items = items,
                tags = repo_tag_bar_tags,
                initial_index = chat_finder_mod.resolve_finder_initial_index(
                    _parley._issue_finder,
                    items,
                    "IssueFinder"
                ),
            }
        end,
        picker_options = {
            title = prompt_title,
            recall_key = "parley.issue_finder",
            initial_index = chat_finder_mod.resolve_finder_initial_index(
                _parley._issue_finder,
                items,
                "IssueFinder"
            ),
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
        },
    })
    if loading and loading.picker then
        picker_ref.update = loading.picker.update
    end
    session:start()

    _parley._issue_finder.initial_index = nil
    _parley._issue_finder.initial_value = nil
    _parley._issue_finder.opened = false
end

return M
