-- parley/issues.lua — issue management subsystem
--
-- Repo-local issue tracking with single-file-per-issue markdown format.
-- Each issue has YAML frontmatter (status, deps, created, updated) and
-- markdown sections (Done when, Plan, Log).
--
-- Pure functions (no vim deps): parse_frontmatter, next_runnable,
-- cycle_status_value, topo_sort, parse_deps_value, slugify
-- IO functions (require vim): setup, get_issues_dir, create_issue,
-- scan_issues, write_frontmatter, cmd_*

local chat_parser = require("parley.chat_parser")

local M = {}

local _parley = nil

-- Mtime-based cache: avoids re-reading unchanged issue files.
-- Key: file path, Value: { mtime, issue_data }
local _file_cache = {}

M.setup = function(parley)
    _parley = parley
end

M.clear_cache = function()
    _file_cache = {}
end

M.get_cache = function()
    return _file_cache
end

M.invalidate_path = function(path)
    _file_cache[path] = nil
end

--------------------------------------------------------------------------------
-- Pure functions (testable without vim runtime in most cases)
--------------------------------------------------------------------------------

local function trim(str)
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

-- Slugify a title into a filename-safe string
M.slugify = function(text)
    local slug = (text or ""):lower()
    slug = slug:gsub("[_%s]+", "-")
    slug = slug:gsub("[^%w%-]", "-")
    slug = slug:gsub("%-+", "-")
    slug = slug:gsub("^%-+", "")
    slug = slug:gsub("%-+$", "")
    return slug
end

-- Parse a YAML-style deps value: "[]", "[0001, 0002]", or "0001, 0002"
M.parse_deps_value = function(value)
    if not value or value == "" then
        return {}
    end
    local inner = value:match("^%[(.*)%]$")
    if inner then
        value = inner
    end
    if trim(value) == "" then
        return {}
    end
    local deps = {}
    for dep in value:gmatch("[^,]+") do
        local d = trim(dep)
        if d ~= "" then
            table.insert(deps, d)
        end
    end
    return deps
end

-- Parse YAML frontmatter from issue file lines.
-- Returns {status, deps, created, updated, header_end} or nil if no frontmatter.
M.parse_frontmatter = function(lines)
    local header_end = chat_parser.find_header_end(lines)
    if not header_end then
        return nil
    end

    local result = {
        id = nil,
        status = "open",
        deps = {},
        created = "",
        updated = "",
        github_issue = nil,
        header_end = header_end,
    }

    -- Parse lines between opening --- (line 1) and closing --- (header_end)
    for i = 2, header_end - 1 do
        local line = lines[i]
        if line then
            local key, val = line:match("^([%w_]+):%s*(.*)$")
            if key then
                key = key:lower()
                val = trim(val)
                if key == "id" then
                    result.id = val:match('^"(.*)"$') or val
                elseif key == "status" then
                    result.status = val
                elseif key == "deps" then
                    result.deps = M.parse_deps_value(val)
                elseif key == "created" then
                    result.created = val
                elseif key == "updated" then
                    result.updated = val
                elseif key == "github_issue" then
                    result.github_issue = val
                end
            end
        end
    end

    return result
end

-- Extract the issue title from lines (first # heading after frontmatter)
M.extract_title = function(lines, header_end)
    local start = (header_end or 0) + 1
    for i = start, #lines do
        local title = lines[i]:match("^#%s+(.+)$")
        if title then
            return trim(title)
        end
    end
    return ""
end

-- Cycle status: open → working → blocked → done → wontfix → open
M.cycle_status_value = function(current)
    local next_status = {
        open = "working",
        working = "blocked",
        blocked = "done",
        done = "wontfix",
        wontfix = "open",
    }
    return next_status[current] or "open"
end

-- Find the next runnable issue: oldest open issue whose deps are all done.
-- issues: list of {id, status, deps, ...}
-- current_id: optional, if provided skips to the issue after this one (cycles)
-- Returns the issue table or nil.
M.next_runnable = function(issues, current_id)
    local done_set = {}
    for _, issue in ipairs(issues) do
        if issue.status == "done" then
            done_set[issue.id] = true
        end
    end

    -- Collect all runnable issues sorted by ID ascending
    local sorted = {}
    for _, issue in ipairs(issues) do
        table.insert(sorted, issue)
    end
    table.sort(sorted, function(a, b) return a.id < b.id end)

    local runnable = {}
    for _, issue in ipairs(sorted) do
        if issue.status == "open" then
            local all_deps_done = true
            for _, dep in ipairs(issue.deps) do
                if not done_set[dep] then
                    all_deps_done = false
                    break
                end
            end
            if all_deps_done then
                table.insert(runnable, issue)
            end
        end
    end

    if #runnable == 0 then
        return nil
    end

    -- If no current_id, return the first runnable
    if not current_id then
        return runnable[1]
    end

    -- Find the issue after current_id, cycling back to start
    for _, issue in ipairs(runnable) do
        if issue.id > current_id then
            return issue
        end
    end
    -- Cycle back to the first runnable
    return runnable[1]
end

-- Sort issues for display: open, working, blocked, done, wontfix (by ID within each group)
M.topo_sort = function(issues)
    local sorted = {}
    for _, issue in ipairs(issues) do
        table.insert(sorted, issue)
    end
    local status_priority = { open = 1, working = 2, blocked = 3, done = 4, wontfix = 5 }
    table.sort(sorted, function(a, b)
        local pa = status_priority[a.status] or 4
        local pb = status_priority[b.status] or 4
        if pa ~= pb then
            return pa < pb
        end
        return a.id < b.id
    end)
    return sorted
end

-- Find a markdown link [text](url) whose span contains the 1-indexed cursor column.
-- Returns { text, url, start_col, end_col } or nil. Pure function (no vim deps).
M.parse_md_link_at_cursor = function(line, col)
    if not line or not col then
        return nil
    end
    local init = 1
    while true do
        local s, e, text, url = line:find("%[([^%]]*)%]%(([^)]+)%)", init)
        if not s then
            return nil
        end
        if col >= s and col <= e then
            return { text = text, url = url, start_col = s, end_col = e }
        end
        init = e + 1
    end
end

-- Resolve a markdown link (as returned by parse_md_link_at_cursor) to an
-- absolute path, given the directory of the file the link lives in. Returns
-- the resolved path string, or nil if the link's url is not a .md file.
-- Pure function (no vim deps); the caller is responsible for normalization
-- (e.g. vim.fn.simplify) and existence checks (e.g. filereadable).
M.resolve_link_target = function(link, cur_dir)
    if not link or not link.url or not link.url:match("%.md$") then
        return nil
    end
    local url = link.url
    if url:sub(1, 1) == "/" then
        return url
    end
    return (cur_dir or "") .. "/" .. url
end

-- Find the parent of an issue: the first issue whose deps contains child_id.
-- Returns the parent issue table or nil. Pure function.
M.find_parent = function(issues, child_id)
    if not child_id or not issues then
        return nil
    end
    for _, issue in ipairs(issues) do
        for _, dep in ipairs(issue.deps or {}) do
            if dep == child_id then
                return issue
            end
        end
    end
    return nil
end

-- Format deps list back to YAML string
M.format_deps = function(deps)
    if not deps or #deps == 0 then
        return "[]"
    end
    return "[" .. table.concat(deps, ", ") .. "]"
end

--------------------------------------------------------------------------------
-- IO functions (require vim/parley runtime)
--------------------------------------------------------------------------------

-- Resolve issues_dir: relative path against git repo root
M.get_issues_dir = function()
    local issues_dir = _parley.config.issues_dir
    if not issues_dir or issues_dir == "" then
        return nil
    end

    -- If already absolute, use as-is
    if issues_dir:sub(1, 1) == "/" then
        return issues_dir
    end

    -- Resolve relative to git root
    local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
    if git_root == "" then
        -- Fallback to cwd if not in a git repo
        git_root = vim.fn.getcwd()
    end

    return git_root .. "/" .. issues_dir
end

-- Resolve the history directory (repo-local, relative to git root)
M.get_history_dir = function()
    local history_dir = _parley.config.history_dir or "history"
    if history_dir:sub(1, 1) == "/" then
        return history_dir
    end

    local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
    if git_root == "" then
        git_root = vim.fn.getcwd()
    end
    return git_root .. "/" .. history_dir
end

-- Scan a directory for max issue ID (4-digit prefix pattern)
local function scan_max_id(dir)
    local max_id = 0
    local handle = vim.loop.fs_scandir(dir)
    if handle then
        local name, kind
        repeat
            name, kind = vim.loop.fs_scandir_next(handle)
            if name and (kind == "file") and name:match("%.md$") then
                local id_str = name:match("^(%d+)%-")
                if id_str then
                    local id = tonumber(id_str)
                    if id and id > max_id then
                        max_id = id
                    end
                end
            end
        until not name
    end
    return max_id
end

-- Find the next issue ID by scanning both issues/ and history/ directories
M.next_issue_id = function(issues_dir)
    local max_id = scan_max_id(issues_dir)
    -- Also check history/ to avoid ID collisions with archived issues
    local history_dir = M.get_history_dir()
    if history_dir then
        local history_max = scan_max_id(history_dir)
        if history_max > max_id then
            max_id = history_max
        end
    end
    return string.format("%06d", max_id + 1)
end

-- Scan a single directory for issue files, appending to the issues table.
-- Uses _file_cache to skip re-reading unchanged files.
local function scan_dir_issues(dir, issues, is_archived)
    local handle = vim.loop.fs_scandir(dir)
    if not handle then
        return
    end

    local name, kind
    repeat
        name, kind = vim.loop.fs_scandir_next(handle)
        if name and (kind == "file") and name:match("%.md$") then
            local id_str = name:match("^(%d+)%-")
            if id_str then
                local path = dir .. "/" .. name
                local stat = vim.loop.fs_stat(path)
                if not stat then
                    goto continue
                end

                local cached = _file_cache[path]
                if cached and cached.mtime == stat.mtime.sec then
                    -- Use cached data, just update archived flag
                    local issue = vim.deepcopy(cached.issue_data)
                    issue.archived = is_archived or false
                    table.insert(issues, issue)
                else
                    local lines = vim.fn.readfile(path)
                    local fm = M.parse_frontmatter(lines)
                    local slug = name:match("^%d+%-(.+)%.md$") or ""
                    local title = M.extract_title(lines, fm and fm.header_end or 0)
                    local issue_data = {
                        id = id_str,
                        slug = slug,
                        title = title,
                        status = fm and fm.status or "open",
                        deps = fm and fm.deps or {},
                        created = fm and fm.created or "",
                        updated = fm and fm.updated or "",
                        github_issue = fm and fm.github_issue or nil,
                        path = path,
                    }
                    _file_cache[path] = { mtime = stat.mtime.sec, issue_data = issue_data }
                    local issue = vim.deepcopy(issue_data)
                    issue.archived = is_archived or false
                    table.insert(issues, issue)
                end
            end
        end
        ::continue::
    until not name
end

-- Scan all issue files and return parsed list
-- opts.include_history: if true, also scan history/ for archived issues
M.scan_issues = function(issues_dir, opts)
    if not issues_dir then
        return {}
    end

    opts = opts or {}
    local issues = {}
    scan_dir_issues(issues_dir, issues, false)

    if opts.include_history then
        local history_dir = M.get_history_dir()
        if history_dir then
            scan_dir_issues(history_dir, issues, true)
        end
    end

    -- Sort by ID ascending
    table.sort(issues, function(a, b) return a.id < b.id end)
    return issues
end

-- Issue template
local ISSUE_TEMPLATE = [[---
id: {{id}}
status: open
deps: []
created: {{date}}
updated: {{date}}
---

# {{title}}

## Done when

-

## Plan

- [ ]

## Log

### {{date}}
]]

-- Create a new issue file and open it
M.create_issue = function(title)
    local issues_dir = M.get_issues_dir()
    if not issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        return nil
    end

    vim.fn.mkdir(issues_dir, "p")
    local id = M.next_issue_id(issues_dir)
    local slug = M.slugify(title)
    local filename = id .. "-" .. slug .. ".md"
    local filepath = issues_dir .. "/" .. filename

    local date = os.date("%Y-%m-%d")
    local content = ISSUE_TEMPLATE:gsub("{{id}}", id):gsub("{{title}}", title):gsub("{{date}}", date)
    local lines = vim.split(content, "\n", { plain = true })

    vim.fn.writefile(lines, filepath)

    -- Open in current window
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    return filepath
end

-- Update frontmatter status in the current buffer
M.write_status = function(buf, new_status)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local fm = M.parse_frontmatter(lines)
    if not fm then
        return false
    end

    for i = 2, fm.header_end - 1 do
        if lines[i]:match("^status:") then
            vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "status: " .. new_status })
            return true
        end
    end
    return false
end

-- Update frontmatter deps in the current buffer
M.write_deps = function(buf, deps)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local fm = M.parse_frontmatter(lines)
    if not fm then
        return false
    end

    for i = 2, fm.header_end - 1 do
        if lines[i]:match("^deps:") then
            vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "deps: " .. M.format_deps(deps) })
            return true
        end
    end
    return false
end

-- Update the "updated" date in frontmatter
M.write_updated = function(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local fm = M.parse_frontmatter(lines)
    if not fm then
        return false
    end

    local date = os.date("%Y-%m-%d")
    for i = 2, fm.header_end - 1 do
        if lines[i]:match("^updated:") then
            vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "updated: " .. date })
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

M.cmd_issue_new = function()
    vim.ui.input({ prompt = "Issue title: " }, function(title)
        if not title or trim(title) == "" then
            return
        end
        local filepath = M.create_issue(title)
        if filepath then
            _parley.logger.info("Created issue: " .. vim.fn.fnamemodify(filepath, ":t"))
        end
    end)
end

M.cmd_issue_status = function()
    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local fm = M.parse_frontmatter(lines)
    if not fm then
        _parley.logger.warning("No issue frontmatter found in current buffer")
        return
    end

    local new_status = M.cycle_status_value(fm.status)
    M.write_status(buf, new_status)
    M.write_updated(buf)
    _parley.logger.info("Issue status: " .. fm.status .. " → " .. new_status)
end

M.cmd_issue_next = function()
    local issues_dir = M.get_issues_dir()
    if not issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        return
    end

    -- Detect current issue ID from the current buffer filename
    local current_id = nil
    local current_file = vim.fn.expand("%:t")
    if current_file then
        current_id = current_file:match("^(%d+)%-")
    end

    local issues = M.scan_issues(issues_dir)
    local next_issue = M.next_runnable(issues, current_id)
    if not next_issue then
        _parley.logger.info("No runnable issues found")
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(next_issue.path))
    _parley.logger.info("Next issue: " .. next_issue.id .. " " .. next_issue.title)
end

M.cmd_issue_decompose = function()
    local buf = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_nr = cursor[1]
    local line = vim.api.nvim_buf_get_lines(buf, line_nr - 1, line_nr, false)[1]

    if not line then
        return
    end

    -- Extract text from a plan checklist line: "- [ ] Some task" or "- [x] Some task"
    local task_text = line:match("^%s*%-%s*%[.%]%s+(.+)$")
    if not task_text then
        _parley.logger.warning("Cursor is not on a plan checklist line")
        return
    end

    -- Get issues_dir and create child issue
    local issues_dir = M.get_issues_dir()
    if not issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        return
    end

    vim.fn.mkdir(issues_dir, "p")
    local child_id = M.next_issue_id(issues_dir)
    local child_slug = M.slugify(task_text)
    local child_filename = child_id .. "-" .. child_slug .. ".md"
    local child_filepath = issues_dir .. "/" .. child_filename

    -- Get current issue's frontmatter to add child as dependency
    local parent_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local parent_fm = M.parse_frontmatter(parent_lines)
    if parent_fm then
        local new_deps = vim.deepcopy(parent_fm.deps)
        table.insert(new_deps, child_id)
        M.write_deps(buf, new_deps)
        M.write_updated(buf)
    end

    -- Update the parent's plan line: append a markdown link to the child
    local child_link = string.format("[issue %s](./%s)", child_id, child_filename)
    local updated_line = line .. " → " .. child_link
    vim.api.nvim_buf_set_lines(buf, line_nr - 1, line_nr, false, { updated_line })

    -- Save parent buffer before switching
    vim.cmd("write")

    -- Build a Parent: backlink for the child body (markdown link to the parent file)
    local parent_filename = vim.fn.expand("%:t")
    local parent_id = parent_fm and parent_fm.id or (parent_filename:match("^(%d+)%-"))
    local parent_link_line = ""
    if parent_id and parent_filename and parent_filename ~= "" then
        parent_link_line = string.format("\n\nParent: [issue %s](./%s)", parent_id, parent_filename)
    end

    -- Create the child issue
    local date = os.date("%Y-%m-%d")
    local title_replacement = task_text .. parent_link_line
    local content = ISSUE_TEMPLATE
        :gsub("{{id}}", child_id)
        :gsub("{{title}}", function() return title_replacement end)
        :gsub("{{date}}", date)
    local lines = vim.split(content, "\n", { plain = true })
    vim.fn.writefile(lines, child_filepath)

    vim.cmd("edit " .. vim.fn.fnameescape(child_filepath))
    _parley.logger.info("Decomposed into issue " .. child_id .. ": " .. task_text)
end

-- Goto a linked issue. If the cursor is on a markdown link to a .md file,
-- open it (resolved relative to the current buffer's directory). Otherwise,
-- treat the current buffer as a child issue and jump to its parent (the first
-- issue whose deps contains the current issue's id).
M.cmd_issue_goto = function()
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1 -- 1-indexed

    -- 1) Markdown link under cursor
    local link = M.parse_md_link_at_cursor(line, col)
    local target = M.resolve_link_target(link, vim.fn.expand("%:p:h"))
    if target then
        target = vim.fn.simplify(target)
        if vim.fn.filereadable(target) == 1 then
            vim.cmd("edit " .. vim.fn.fnameescape(target))
            return
        end
        _parley.logger.warning("Issue link target not found: " .. target)
        return
    end

    -- 2) Fall back to parent of current issue
    local current_file = vim.fn.expand("%:t")
    local current_id = current_file and current_file:match("^(%d+)%-")
    if not current_id then
        _parley.logger.warning("No issue link under cursor and current buffer is not an issue")
        return
    end

    local issues_dir = M.get_issues_dir()
    if not issues_dir then
        _parley.logger.warning("issues_dir is not configured")
        return
    end

    local issues = M.scan_issues(issues_dir, { include_history = true })
    local parent = M.find_parent(issues, current_id)
    if not parent then
        _parley.logger.warning("No parent issue found for " .. current_id)
        return
    end

    vim.cmd("edit " .. vim.fn.fnameescape(parent.path))
    _parley.logger.info("Parent issue: " .. parent.id .. " " .. (parent.title or ""))
end

return M
