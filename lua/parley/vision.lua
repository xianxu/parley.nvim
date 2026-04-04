-- parley/vision.lua — company vision tracker
--
-- YAML-based tool for tracking company initiatives with dependencies,
-- sizes, types, and timing. A directory of YAML files is the source
-- of truth, with filenames providing namespaces for initiative IDs.
--
-- Pure functions (no vim deps): parse_vision_yaml, name_to_id,
-- full_id, resolve_ref, validate_graph, export_csv, export_dot
-- IO functions (require vim): load_vision_dir, setup, cmd_*

local M = {}

local _parley = nil

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- Parse an inline YAML list: "[a, b, c]" → {"a", "b", "c"}, "[]" → {}
local function parse_inline_list(value)
    local inner = value:match("^%[(.*)%]$")
    if not inner then
        return nil
    end
    if trim(inner) == "" then
        return {}
    end
    local items = {}
    for item in inner:gmatch("[^,]+") do
        local trimmed = trim(item)
        if trimmed ~= "" then
            table.insert(items, trimmed)
        end
    end
    return items
end

--------------------------------------------------------------------------------
-- YAML Parser
--------------------------------------------------------------------------------

-- Parse a vision YAML file (list of maps with string values and inline lists).
-- Returns a list of tables, each with string keys and string or list values.
-- Comments (lines starting with #) and blank lines are ignored.
--
-- Expected format:
--   - project: Some Initiative
--     type: tech
--     size: XL
--     depends_on: [auth, data]
--
M.parse_vision_yaml = function(text)
    local items = {}
    local current = nil
    local list_key = nil  -- key currently collecting multiline list items

    local function set_key(key, val, ln)
        val = trim(val)
        local list = parse_inline_list(val)
        if list then
            current[key] = list
            -- All inline list items share the same line
            current["_" .. key .. "_lines"] = {}
            for i = 1, #list do
                current["_" .. key .. "_lines"][i] = ln
            end
            list_key = nil
        elseif val == "" then
            -- Key with no value — expect multiline list items below
            current[key] = {}
            current["_" .. key .. "_lines"] = {}
            list_key = key
        else
            current[key] = val
            list_key = nil
        end
    end

    for line_num, line in ipairs(type(text) == "string" and vim.split(text, "\n") or text) do
        -- Skip comments and blank lines
        local stripped = trim(line)
        if stripped == "" or stripped:match("^#") then -- luacheck: ignore 542
            -- blank or comment, skip
        elseif line:match("^%- ") then
            -- New item: "- key: value"
            if current then
                table.insert(items, current)
            end
            current = { _line = line_num }
            list_key = nil
            local key, val = line:match("^%-%s+([%w_]+):%s*(.*)$")
            if key then
                set_key(key, val, line_num)
            end
        elseif current and list_key and stripped:match("^%- ") then
            -- Multiline list item: "    - value"
            local val = stripped:match("^%-%s+(.+)$")
            if val then
                table.insert(current[list_key], trim(val))
                local lines_key = "_" .. list_key .. "_lines"
                current[lines_key][#current[list_key]] = line_num
            end
        elseif current and line:match("^%s+[%w_]+:") then
            -- Continuation key within current item: "  key: value"
            local key, val = line:match("^%s+([%w_]+):%s*(.*)$")
            if key then
                set_key(key, val, line_num)
            end
        end
    end

    if current then
        table.insert(items, current)
    end

    return items
end

--------------------------------------------------------------------------------
-- ID Resolution
--------------------------------------------------------------------------------

-- Convert a human name to a hyphenated ID.
-- "Data Platform" → "data-platform", "Auth Service Rewrite" → "auth-service-rewrite"
-- "Self-Serve Onboarding" → "self-serve-onboarding"
M.name_to_id = function(name)
    if not name or name == "" then return "" end
    local id = name:lower()
    id = id:gsub("[^%w%s%-]", "")  -- strip non-alphanumeric (except spaces and hyphens)
    id = id:gsub("[%s_]+", "-")    -- spaces/underscores to hyphens
    id = id:gsub("%-+", "-")      -- collapse multiple hyphens
    id = id:gsub("^%-+", ""):gsub("%-+$", "")  -- trim leading/trailing
    return id
end

-- Build a fully qualified ID: namespace:hyphenated-name
M.full_id = function(namespace, name)
    return namespace .. ":" .. M.name_to_id(name)
end

-- Multi-prefix match: "scope ... onprem" matches "scope-deletion-in-onprem-within-a-quarter"
-- Each segment (split by ...) must match as a prefix at a hyphen boundary, in order.
local function multi_prefix_match(segments, id)
    local pos = 1
    for i, seg in ipairs(segments) do
        if seg == "" then goto continue end
        -- Find seg as a prefix starting at some hyphen boundary from pos
        local found = false
        local search_from = pos
        while search_from <= #id do
            if id:sub(search_from, search_from + #seg - 1) == seg then
                pos = search_from + #seg
                found = true
                break
            end
            if i == 1 then break end  -- first segment must match at the start
            -- Advance to next hyphen boundary
            local next_hyphen = id:find("-", search_from)
            if not next_hyphen then break end
            search_from = next_hyphen + 1
        end
        if not found then return false end
        ::continue::
    end
    return true
end

-- Resolve a reference prefix against a set of all known full IDs.
-- ref: the user-written reference (e.g. "auth" or "px.mobile")
-- current_ns: the namespace of the file containing the reference
-- all_ids: list of all full IDs (e.g. {"sync.auth_rewrite", "px.mobile_app"})
--
-- Resolution order:
-- 1. If ref contains ".", treat as namespace.prefix and match globally
-- 2. Otherwise, try local namespace first (current_ns.ref as prefix)
-- 3. If no local match, try global prefix match across all IDs
--
-- Returns: resolved_full_id, error_string
M.resolve_ref = function(ref, current_ns, all_ids)
    ref = trim(ref)
    if ref == "" then
        return nil, "empty reference"
    end

    -- Multi-prefix match: "scope ... onprem" splits by "..." into segments
    if ref:find("%.%.%.") then
        -- Split on "..." (literal three dots), not on individual dots
        local parts = {}
        local rest = ref
        while true do
            local s, e = rest:find("%.%.%.")
            if not s then
                table.insert(parts, rest)
                break
            end
            table.insert(parts, rest:sub(1, s - 1))
            rest = rest:sub(e + 1)
        end

        -- Check for namespace prefix: "px:seg1 ... seg2" or "px: seg1 ... seg2"
        local explicit_ns = nil
        local first = trim(parts[1])
        local colon_pos = first:find(":")
        if colon_pos then
            explicit_ns = trim(first:sub(1, colon_pos - 1))
            parts[1] = first:sub(colon_pos + 1)
        end

        local segments = {}
        for _, part in ipairs(parts) do
            local normed = M.name_to_id(trim(part))
            if normed ~= "" then table.insert(segments, normed) end
        end
        if #segments == 0 then
            return nil, "empty multi-prefix reference"
        end

        local matches = {}
        local search_ns = explicit_ns or current_ns
        -- Try target namespace first
        for _, fid in ipairs(all_ids) do
            local ns, name_part = fid:match("^([^:]+):(.+)$")
            if ns == search_ns and name_part and multi_prefix_match(segments, name_part) then
                table.insert(matches, fid)
            end
        end
        -- If no namespace match and no explicit namespace, try global
        if #matches == 0 and not explicit_ns then
            for _, fid in ipairs(all_ids) do
                local name_part = fid:match("^[^:]+:(.+)$")
                if name_part and multi_prefix_match(segments, name_part) then
                    table.insert(matches, fid)
                end
            end
        end

        if #matches == 0 then
            return nil, string.format('"%s" matches no initiatives', ref)
        elseif #matches == 1 then
            return matches[1], nil
        else
            return nil, string.format('"%s" is ambiguous — matches: %s',
                ref, table.concat(matches, ", "))
        end
    end

    -- Normalize ref through name_to_id so hyphens/special chars match
    -- Check for namespace prefix with ":"
    local has_ns = ref:find(":")
    local norm_ref
    if has_ns then
        local ns, name = ref:match("^([^:]+):%s*(.+)$")
        norm_ref = trim(ns) .. ":" .. M.name_to_id(name)
    else
        norm_ref = M.name_to_id(ref)
    end

    local matches = {}

    if has_ns then
        -- Namespaced ref: match as prefix against full IDs
        for _, fid in ipairs(all_ids) do
            if fid:sub(1, #norm_ref) == norm_ref then
                table.insert(matches, fid)
            end
        end
    else
        -- Bare ref: try local namespace first
        local local_prefix = current_ns .. ":" .. norm_ref
        for _, fid in ipairs(all_ids) do
            if fid:sub(1, #local_prefix) == local_prefix then
                table.insert(matches, fid)
            end
        end

        -- If no local match, try global (match against the name part of any ID)
        if #matches == 0 then
            for _, fid in ipairs(all_ids) do
                local name_part = fid:match("^[^:]+:(.+)$")
                if name_part and name_part:sub(1, #norm_ref) == norm_ref then
                    table.insert(matches, fid)
                end
            end
        end
    end

    if #matches == 0 then
        return nil, string.format('"%s" matches no initiatives', ref)
    elseif #matches == 1 then
        return matches[1], nil
    else
        -- Prefer exact match over prefix matches
        local exact = has_ns and norm_ref or (current_ns .. ":" .. norm_ref)
        for _, fid in ipairs(matches) do
            if fid == exact then return fid, nil end
        end
        return nil, string.format('"%s" is ambiguous — matches: %s',
            ref, table.concat(matches, ", "))
    end
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

-- Validate a loaded vision graph. Returns a list of error strings (empty = valid).
-- initiatives: list of {project, namespace, depends_on, ...} tables
M.validate_graph = function(initiatives)
    local errors = {}

    local function add_error(text, item)
        table.insert(errors, {
            text = text,
            filename = item and item._file or nil,
            lnum = item and item._line or nil,
        })
    end

    -- Build full ID list
    local all_ids = {}
    local id_set = {}
    for _, item in ipairs(initiatives) do
        if not item.project or item.project == "" then
            add_error(string.format(
                "item at line %d in %s is not a project",
                item._line or 0, item._namespace or "?"), item)
        else
            local fid = M.full_id(item._namespace or "", item.project)
            if id_set[fid] then
                add_error(string.format(
                    'duplicate ID "%s" (from "%s" in %s)',
                    fid, item.project, item._namespace or "?"), item)
            else
                table.insert(all_ids, fid)
                id_set[fid] = true
            end
        end
    end

    -- Resolve all depends_on refs and build adjacency
    local adj = {}  -- full_id → list of full_ids it depends on
    local dep_lines = {}  -- "source_fid\0target_fid" → line number of the dep
    for _, item in ipairs(initiatives) do
        if item.project and item.project ~= "" then
            local fid = M.full_id(item._namespace or "", item.project)
            adj[fid] = {}
            local deps = item.depends_on or {}
            if type(deps) == "string" then deps = { deps } end
            local lines = item._depends_on_lines or {}
            for idx, ref in ipairs(deps) do
                local resolved, err = M.resolve_ref(ref, item._namespace or "", all_ids)
                if err then
                    local err_item = { _file = item._file, _line = lines[idx] or item._line }
                    add_error(string.format(
                        '%s.%s depends_on: %s',
                        item._namespace or "?", M.name_to_id(item.project), err), err_item)
                else
                    table.insert(adj[fid], resolved)
                    if lines[idx] then
                        dep_lines[fid .. "\0" .. resolved] = lines[idx]
                    end
                end
            end
        end
    end

    -- Build lookup: full_id → initiative item (for error locations)
    local by_id = {}
    for _, item in ipairs(initiatives) do
        if item.project and item.project ~= "" then
            local fid = M.full_id(item._namespace or "", item.project)
            if not by_id[fid] then by_id[fid] = item end
        end
    end

    -- Cycle detection (DFS)
    local WHITE, GRAY, BLACK = 0, 1, 2
    local color = {}
    for _, fid in ipairs(all_ids) do
        color[fid] = WHITE
    end

    local function dfs(node, path)
        color[node] = GRAY
        table.insert(path, node)
        for _, dep in ipairs(adj[node] or {}) do
            if color[dep] == GRAY then
                -- Find the cycle portion of the path
                local cycle_start = 1
                for i, p in ipairs(path) do
                    if p == dep then
                        cycle_start = i
                        break
                    end
                end
                local cycle = {}
                for i = cycle_start, #path do
                    table.insert(cycle, path[i])
                end
                table.insert(cycle, dep)
                local msg = string.format(
                    "circular dependency: %s", table.concat(cycle, " → "))
                for i = cycle_start, #path do
                    local src = path[i]
                    local tgt = path[i + 1] or dep
                    local item = by_id[src]
                    local ln = dep_lines[src .. "\0" .. tgt]
                    local err_item = { _file = item and item._file, _line = ln or (item and item._line) }
                    add_error(msg, err_item)
                end
                return
            elseif color[dep] == WHITE then
                dfs(dep, path)
            end
        end
        table.remove(path)
        color[node] = BLACK
    end

    for _, fid in ipairs(all_ids) do
        if color[fid] == WHITE then
            dfs(fid, {})
        end
    end

    -- need_by ordering: if A depends on B, A's need_by must not be earlier than B's
    for _, fid in ipairs(all_ids) do
        local item = by_id[fid]
        local a_need = item and type(item.need_by) == "string" and item.need_by or ""
        if a_need ~= "" then
            for _, dep_fid in ipairs(adj[fid] or {}) do
                local dep_item = by_id[dep_fid]
                local b_need = dep_item and type(dep_item.need_by) == "string" and dep_item.need_by or ""
                local ln = dep_lines[fid .. "\0" .. dep_fid]
                local err_item = { _file = item._file, _line = ln or item._line }
                if b_need == "" then
                    add_error(string.format(
                        '%s needs by %s but depends on %s which has no need_by',
                        fid, a_need, dep_fid), err_item)
                elseif a_need < b_need then
                    add_error(string.format(
                        '%s needs by %s but depends on %s which needs by %s',
                        fid, a_need, dep_fid, b_need), err_item)
                end
            end
        end
    end

    return errors, all_ids, adj
end

--------------------------------------------------------------------------------
-- Directory Loading
--------------------------------------------------------------------------------

-- Load all vision YAML files from a directory.
-- Returns a flat list of initiatives, each tagged with _namespace (filename stem).
M.load_vision_dir = function(dir)
    local items = {}
    -- Use vim.fn.glob to find YAML files
    local files = vim.fn.glob(dir .. "/*.yaml", false, true)
    table.sort(files)  -- deterministic order

    for _, filepath in ipairs(files) do
        local namespace = vim.fn.fnamemodify(filepath, ":t:r")  -- filename without extension
        local lines = vim.fn.readfile(filepath)
        local parsed = M.parse_vision_yaml(lines)
        for _, item in ipairs(parsed) do
            item._namespace = namespace
            item._file = filepath
            table.insert(items, item)
        end
    end

    return items
end

--------------------------------------------------------------------------------
-- CSV Export
--------------------------------------------------------------------------------

-- Escape a CSV field: wrap in quotes if it contains comma, quote, or newline.
local function csv_escape(value)
    if not value then return "" end
    local s = tostring(value)
    if s:find('[,"\n]') then
        return '"' .. s:gsub('"', '""') .. '"'
    end
    return s
end

-- Export initiatives to CSV format. Returns the CSV string.
M.export_csv = function(initiatives)
    local lines = {}
    table.insert(lines, "namespace,project,type,size,need_by,depends_on")

    for _, item in ipairs(initiatives) do
        local deps = item.depends_on or {}
        if type(deps) == "string" then deps = { deps } end
        local deps_str = table.concat(deps, "; ")

        table.insert(lines, string.format("%s,%s,%s,%s,%s,%s",
            csv_escape(item._namespace or ""),
            csv_escape(item.project or ""),
            csv_escape(item.type or ""),
            csv_escape(item.size or ""),
            csv_escape(item.need_by or ""),
            csv_escape(deps_str)))
    end

    return table.concat(lines, "\n") .. "\n"
end

--------------------------------------------------------------------------------
-- DOT Graph Export
--------------------------------------------------------------------------------

local SIZE_MAP = { S = 1.0, M = 1.5, L = 2.2, XL = 3.0 }
local COLOR_MAP = { tech = "#a0d8ef", business = "#ffe0b2" }

-- Collect reachable nodes from a root in the adjacency graph.
-- direction: "down" (descendants), "up" (ancestors), "both"
local function collect_subgraph(root, adj, all_ids, direction)
    local visited = {}
    local queue = { root }
    visited[root] = true

    -- Build reverse adjacency for "up" traversal
    local rev_adj = {}
    if direction == "up" or direction == "both" then
        for _, fid in ipairs(all_ids) do
            rev_adj[fid] = {}
        end
        for fid, deps in pairs(adj) do
            for _, dep in ipairs(deps) do
                if rev_adj[dep] then
                    table.insert(rev_adj[dep], fid)
                end
            end
        end
    end

    while #queue > 0 do
        local node = table.remove(queue, 1)
        -- Down: follow dependencies
        if direction == "down" or direction == "both" then
            for _, dep in ipairs(adj[node] or {}) do
                if not visited[dep] then
                    visited[dep] = true
                    table.insert(queue, dep)
                end
            end
        end
        -- Up: follow reverse dependencies
        if direction == "up" or direction == "both" then
            for _, parent in ipairs(rev_adj[node] or {}) do
                if not visited[parent] then
                    visited[parent] = true
                    table.insert(queue, parent)
                end
            end
        end
    end

    return visited
end

-- Export initiatives to Graphviz DOT format. Returns the DOT string.
-- opts.root: optional root node ID for subgraph filtering
-- opts.direction: "down" (default), "up", or "both"
M.export_dot = function(initiatives, opts)
    opts = opts or {}

    -- First validate to get resolved adjacency
    local errors, all_ids, adj = M.validate_graph(initiatives)
    if #errors > 0 then
        return nil, errors
    end

    -- Build lookup: full_id → initiative
    local by_id = {}
    for _, item in ipairs(initiatives) do
        if item.project and item.project ~= "" then
            local fid = M.full_id(item._namespace or "", item.project)
            by_id[fid] = item
        end
    end

    -- Determine which nodes to include
    local include
    if opts.root then
        local resolved_root, err = M.resolve_ref(opts.root, "", all_ids)
        if err then
            return nil, { "root: " .. err }
        end
        include = collect_subgraph(resolved_root, adj, all_ids, opts.direction or "both")
    end

    -- Build DOT
    local lines = {}
    table.insert(lines, 'digraph vision {')
    table.insert(lines, '    rankdir=TB;')
    table.insert(lines, '    node [shape=box, style="filled,rounded"];')
    table.insert(lines, '')

    -- Nodes
    for _, fid in ipairs(all_ids) do
        if not include or include[fid] then
            local item = by_id[fid]
            if item then
                local w = SIZE_MAP[item.size] or 1.5
                local color = COLOR_MAP[item.type] or "#eeeeee"
                local label = string.format("%s\\n[%s] %s",
                    item.project or fid,
                    item.size or "?",
                    item.need_by or "")
                local fontsize = tostring(10 + math.floor(w * 3))

                table.insert(lines, string.format(
                    '    "%s" [label="%s", width=%.1f, fillcolor="%s", fontsize=%s];',
                    fid, label, w, color, fontsize))
            end
        end
    end

    table.insert(lines, '')

    -- Edges
    for _, fid in ipairs(all_ids) do
        if not include or include[fid] then
            for _, dep in ipairs(adj[fid] or {}) do
                if not include or include[dep] then
                    table.insert(lines, string.format(
                        '    "%s" -> "%s";', dep, fid))
                end
            end
        end
    end

    table.insert(lines, '}')

    return table.concat(lines, "\n") .. "\n", nil
end

--------------------------------------------------------------------------------
-- IO Commands (require vim + _parley)
--------------------------------------------------------------------------------

-- Resolve vision_dir: relative path against git repo root
M.get_vision_dir = function()
    local vision_dir = _parley.config.vision_dir
    if not vision_dir or vision_dir == "" then
        return nil
    end

    if vision_dir:sub(1, 1) == "/" then
        return vision_dir
    end

    local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
    if git_root == "" then
        git_root = vim.fn.getcwd()
    end

    return git_root .. "/" .. vision_dir
end

-- Save any modified buffers whose files are in the given directory.
local function save_vision_buffers(dir)
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
            local name = vim.api.nvim_buf_get_name(buf)
            if name:sub(1, #dir) == dir and name:match("%.yaml$") then
                vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
            end
        end
    end
end

-- Load all initiatives from vision_dir, or nil + warning if not configured
local function load_all()
    local dir = M.get_vision_dir()
    if not dir then
        _parley.logger.warning("vision_dir is not configured")
        return nil
    end
    save_vision_buffers(dir)
    return M.load_vision_dir(dir), dir
end

-- :ParleyVisionValidate — run validation, show errors
M.cmd_validate = function()
    local items = load_all()
    if not items then return end

    local errors = M.validate_graph(items)
    if #errors == 0 then
        vim.fn.setqflist({}, "r")
        vim.cmd("cclose")
        vim.notify("Vision: all OK (" .. #items .. " initiatives)", vim.log.levels.INFO)
    else
        -- Show errors in quickfix
        local qf = {}
        for _, e in ipairs(errors) do
            table.insert(qf, {
                text = e.text,
                filename = e.filename,
                lnum = e.lnum or 0,
            })
        end
        vim.fn.setqflist(qf, "r")
        vim.cmd("copen")
        vim.notify("Vision: " .. #errors .. " error(s)", vim.log.levels.ERROR)
    end
end

-- :ParleyVisionExportCsv [output_path] — export CSV
M.cmd_export_csv = function(params)
    local items = load_all()
    if not items then return end

    local csv = M.export_csv(items)
    local output = params and params.args and params.args ~= "" and params.args or nil
    if not output then
        local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
        if git_root == "" then git_root = vim.fn.getcwd() end
        output = git_root .. "/roadmap.csv"
    end
    local f = io.open(output, "w")
    if f then
        f:write(csv)
        f:close()
        vim.notify("Vision: CSV exported to " .. output, vim.log.levels.INFO)
    else
        vim.notify("Vision: failed to write " .. output, vim.log.levels.ERROR)
    end
end

-- :ParleyVisionExportDot [output_path] [--root=node] — export DOT
M.cmd_export_dot = function(params)
    local items = load_all()
    if not items then return end

    -- Parse args: optional output path and --root=node
    local args = params and params.args or ""
    local root = args:match("%-%-root=(%S+)")
    local output = args:gsub("%-%-root=%S+", ""):match("^%s*(%S+)")

    local dot, errors = M.export_dot(items, { root = root })
    if errors then
        for _, e in ipairs(errors) do
            vim.notify("Vision: " .. e.text, vim.log.levels.ERROR)
        end
        return
    end

    if not output then
        local git_root = _parley.helpers.find_git_root(vim.fn.getcwd())
        if git_root == "" then git_root = vim.fn.getcwd() end
        output = git_root .. "/roadmap.dot"
    end
    local f = io.open(output, "w")
    if f then
        f:write(dot)
        f:close()
        vim.notify("Vision: DOT exported to " .. output, vim.log.levels.INFO)
    else
        vim.notify("Vision: failed to write " .. output, vim.log.levels.ERROR)
    end
end

-- :ParleyVisionNew — insert a new project template at cursor or end of current file
M.cmd_new = function()
    local dir = M.get_vision_dir()
    if not dir then
        _parley.logger.warning("vision_dir is not configured")
        return
    end

    local template = {
        "",
        "- project: New Project",
        "  type: tech",
        "  size: M",
        "  need_by: ",
        "  depends_on: []",
    }

    local buf = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(buf)
    local norm_dir = vim.fn.resolve(vim.fn.fnamemodify(dir, ":p"))
    local norm_file = vim.fn.resolve(vim.fn.fnamemodify(filepath, ":p"))

    -- Only insert if current file is in vision_dir
    if norm_file:sub(1, #norm_dir) ~= norm_dir then
        vim.notify("Vision: current file is not in vision_dir", vim.log.levels.WARN)
        return
    end

    local line_count = vim.api.nvim_buf_line_count(buf)
    vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, template)
    -- Move cursor to the name field
    vim.api.nvim_win_set_cursor(0, { line_count + 2, 10 })
    vim.cmd("startinsert!")
end

-- :ParleyVisionGoto — jump to the initiative under cursor in depends_on
M.cmd_goto_ref = function()
    local items = load_all()
    if not items then return end

    -- Get current line and extract the ref under cursor
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1  -- 1-indexed

    -- Extract ref: find the word (allowing dots and hyphens) around cursor
    local ref
    -- Try multiline list item: "    - some-ref"
    ref = line:match("^%s+%-%s+(.+)$")
    if ref then
        ref = trim(ref)
    else
        -- Try inline list: find the item at cursor position within [...]
        local bracket_content = line:match("%[(.*)%]")
        if bracket_content then
            local bracket_start = line:find("%[")
            local pos = col - bracket_start  -- position within bracket content
            -- Split by comma and find which item the cursor is in
            local offset = 1
            for item in bracket_content:gmatch("[^,]+") do
                local item_end = offset + #item - 1
                if pos >= offset and pos <= item_end then
                    ref = trim(item)
                    break
                end
                offset = item_end + 2  -- skip comma
            end
        end
    end

    if not ref or ref == "" then
        vim.notify("Vision: no reference under cursor", vim.log.levels.WARN)
        return
    end

    -- Determine current namespace from filename
    local filepath = vim.api.nvim_buf_get_name(0)
    local current_ns = vim.fn.fnamemodify(filepath, ":t:r")

    -- Build all IDs
    local all_ids = {}
    for _, item in ipairs(items) do
        if item.project and item.project ~= "" then
            table.insert(all_ids, M.full_id(item._namespace or "", item.project))
        end
    end

    -- Resolve
    local resolved, err = M.resolve_ref(ref, current_ns, all_ids)
    if err then
        vim.notify("Vision: " .. err, vim.log.levels.WARN)
        return
    end

    -- Find the target item
    for _, item in ipairs(items) do
        if item.project and item.project ~= "" then
            local fid = M.full_id(item._namespace or "", item.project)
            if fid == resolved then
                _parley.open_buf(item._file, true)
                if item._line then
                    vim.api.nvim_win_set_cursor(0, { item._line, 0 })
                end
                return
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Typeahead completion for depends_on fields
--------------------------------------------------------------------------------

-- Check if cursor is on a depends_on list line (multiline item).
-- Returns the partial text after "- " if so, or nil.
local function get_depends_on_partial(buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local line = vim.api.nvim_get_current_line()

    -- Must be an indented list item line: "    - partial"
    local partial = line:match("^%s+%-%s(.*)$")
    if not partial then return nil end

    -- Walk up to find the parent key — must be depends_on
    for r = row - 1, math.max(1, row - 10), -1 do
        local prev = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1]
        if not prev then break end
        local key = prev:match("^%s+([%w_]+):%s*$")
        if key then
            return key == "depends_on" and partial or nil
        end
        -- If we hit a non-list, non-blank, non-comment line that's not indented list item, stop
        local stripped = trim(prev)
        if stripped ~= "" and not stripped:match("^#") and not prev:match("^%s+%- ") then
            break
        end
    end
    return nil
end

-- Build completion candidates for depends_on typeahead.
-- current_ns: namespace of current file
-- Returns list of {word, menu} tables for vim.fn.complete
M.build_completion_candidates = function(current_ns)
    local items = load_all()
    if not items then return {} end

    local candidates = {}
    for _, item in ipairs(items) do
        if item.project and item.project ~= "" then
            local ns = item._namespace or ""
            local name_id = M.name_to_id(item.project)
            if ns == current_ns then
                -- Local: show bare name
                table.insert(candidates, {
                    word = name_id,
                    menu = item.project,
                })
            else
                -- Cross-namespace: show ns: name
                table.insert(candidates, {
                    word = ns .. ": " .. name_id,
                    menu = ns .. ": " .. item.project,
                })
            end
        end
    end
    return candidates
end

-- Match a partial input against a candidate word.
-- Supports multi-prefix with "..." and regular prefix matching.
-- For "ns: partial", matches only against that namespace's portion.
local function match_candidate(partial, word)
    if partial == "" then return true end

    -- Handle "ns: partial" — match against the word which is already "ns: name"
    -- and bare names which won't have ":"
    local partial_ns, partial_rest = partial:match("^([^:]+):%s*(.*)$")
    if partial_ns then
        -- Must be a cross-namespace candidate starting with this ns
        local word_ns = word:match("^([^:]+):")
        if not word_ns or word_ns ~= partial_ns then return false end
        -- Match rest against name portion
        local word_name = word:match("^[^:]+:%s*(.+)$")
        if not word_name then return partial_rest == "" end
        partial = partial_rest
        word = word_name
    end

    -- Multi-prefix: "mob ... v2"
    if partial:find("%.%.%.") then
        local segments = {}
        local rest = partial
        while true do
            local s, e = rest:find("%.%.%.")
            if not s then
                table.insert(segments, rest)
                break
            end
            table.insert(segments, rest:sub(1, s - 1))
            rest = rest:sub(e + 1)
        end
        local norm_segments = {}
        for _, seg in ipairs(segments) do
            local normed = M.name_to_id(trim(seg))
            if normed ~= "" then table.insert(norm_segments, normed) end
        end
        if #norm_segments == 0 then return true end
        return multi_prefix_match(norm_segments, word)
    end

    -- Regular prefix match
    local norm = M.name_to_id(partial)
    if norm == "" then return true end
    return word:sub(1, #norm) == norm
end

-- TextChangedI handler for typeahead completion
M.on_text_changed_i = function(buf)
    local partial = get_depends_on_partial(buf)
    if not partial then return end

    -- Determine current namespace
    local filepath = vim.api.nvim_buf_get_name(buf)
    local current_ns = vim.fn.fnamemodify(filepath, ":t:r")

    local all_candidates = M.build_completion_candidates(current_ns)

    -- Filter candidates
    local filtered = {}
    for _, c in ipairs(all_candidates) do
        if match_candidate(partial, c.word) then
            table.insert(filtered, c)
        end
    end

    if #filtered == 0 then return end

    -- Find the column where the partial starts (after "- ")
    local line = vim.api.nvim_get_current_line()
    local dash_pos = line:find("%-")
    local col = dash_pos + 1  -- after "-"
    while line:sub(col + 1, col + 1) == " " do col = col + 1 end

    -- Set completeopt for non-blocking typeahead
    local saved_completeopt = vim.o.completeopt
    vim.o.completeopt = "menuone,noinsert,noselect"
    vim.fn.complete(col + 1, filtered)
    vim.o.completeopt = saved_completeopt
end

return M
