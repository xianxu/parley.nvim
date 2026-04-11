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

-- Safely get a string value from a field that may be a table (from parser) or nil.
local function str(val)
    if type(val) == "string" then return val end
    return ""
end

-- Return true if a project name is a background project (prefixed with ~).
-- Background projects are kept in mind as waypoints but not actively worked on.
M.is_background = function(name)
    return type(name) == "string" and name:sub(1, 1) == "~"
end

-- Strip trailing ! from a project name and return (clean_name, priority).
-- Also strips a leading ~ background marker for display.
-- "EHR Sync V2!!" → ("EHR Sync V2", 2), "~Foo!" → ("Foo", 1), "Auth" → ("Auth", 0)
M.parse_priority = function(name)
    if not name or name == "" then return name, 0 end
    local stripped = name:match("^~(.*)$") or name
    local base, bangs = stripped:match("^(.-)(!+)%s*$")
    if base then
        return trim(base), #bangs
    end
    return stripped, 0
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
            current["_" .. key .. "_line"] = ln
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
-- Time & Size Parsing
--------------------------------------------------------------------------------

local QUARTER_START_MONTH = { 1, 4, 7, 10 }  -- Q1=1, Q2=4, Q3=7, Q4=10
local TSHIRT_TO_MONTHS = { S = 1, M = 3, L = 6, XL = 12 }
local WEEKS_PER_MONTH = 4.33

-- Parse a time string: "25Q3" → {year=25, q=3}, "25M11" → {year=25, m=11}
-- Returns nil on invalid input.
M.parse_time = function(s)
    if not s or s == "" then return nil end
    s = trim(s)
    local y, q = s:match("^(%d+)Q(%d)$")
    if y and q then
        q = tonumber(q)
        if q >= 1 and q <= 4 then
            return { year = tonumber(y), q = q }
        end
        return nil
    end
    local y2, m = s:match("^(%d+)M(%d+)$")
    if y2 and m then
        m = tonumber(m)
        if m >= 1 and m <= 12 then
            return { year = tonumber(y2), m = m }
        end
        return nil
    end
    return nil
end

-- Convert a parsed time to absolute months for comparison.
-- Quarter → first month of that quarter.
M.time_to_months = function(t)
    if not t then return nil end
    if t.q then
        return t.year * 12 + QUARTER_START_MONTH[t.q]
    elseif t.m then
        return t.year * 12 + t.m
    end
    return nil
end

-- Return the number of quarters between two parsed times (inclusive of both endpoints).
-- Fractional quarters are rounded up.
M.quarters_between = function(t1, t2)
    if not t1 or not t2 then return nil end
    local m1 = M.time_to_months(t1)
    local m2 = M.time_to_months(t2)
    if not m1 or not m2 then return nil end
    if m2 < m1 then return 0 end
    return math.ceil((m2 - m1 + 1) / 3)
end

-- Parse a size string to months. Accepts "3m" or T-shirt sizes.
-- Returns nil on invalid input.
M.parse_size_months = function(s)
    if not s or s == "" then return nil end
    s = trim(s)
    -- T-shirt sizes
    if TSHIRT_TO_MONTHS[s] then
        return TSHIRT_TO_MONTHS[s]
    end
    -- Month format: "3m", "6m", "0.5m"
    local n = s:match("^([%d%.]+)m$")
    if n then
        local num = tonumber(n)
        if num and num > 0 then return num end
    end
    return nil
end

-- Parse a capacity string to weeks. Accepts "11w".
-- Returns nil on invalid input.
M.parse_capacity_weeks = function(s)
    if not s or s == "" then return nil end
    s = trim(s)
    local n = s:match("^([%d%.]+)w$")
    if n then
        local num = tonumber(n)
        if num and num > 0 then return num end
    end
    return nil
end

-- Expose constants for tests and other modules
M.WEEKS_PER_MONTH = WEEKS_PER_MONTH
M.TSHIRT_TO_MONTHS = TSHIRT_TO_MONTHS

--------------------------------------------------------------------------------
-- Quarterly Charge Calculation
--------------------------------------------------------------------------------

-- Calculate how many months of effort a project charges to a given quarter range.
-- project: table with size, completion, start_by, need_by fields
-- range_start, range_end: parsed time tables (from parse_time)
-- Returns months charged (number).
M.quarterly_charge = function(project, range_start, range_end)
    if not project or not range_start or not range_end then return 0 end

    local size = M.parse_size_months(str(project.size))
    if not size then return 0 end

    local completion = tonumber(project.completion) or 0
    local remaining = size * (1 - completion / 100)
    if remaining <= 0 then return 0 end

    local rs = M.time_to_months(range_start)
    local re = M.time_to_months(range_end)

    -- Parse start_by / need_by, defaulting to range boundaries
    local sb = project.start_by and M.parse_time(str(project.start_by)) or range_start
    local nb = project.need_by and M.parse_time(str(project.need_by)) or range_end
    local sb_m = M.time_to_months(sb) or rs
    local nb_m = M.time_to_months(nb) or re

    -- Project hasn't started yet and won't start until after range
    if sb_m > re then return 0 end

    -- Overdue: need_by is before range_start, charge full remaining
    if nb_m < rs then return remaining end

    -- Quarters the project spans
    local total_q = M.quarters_between(sb, nb)
    if not total_q or total_q <= 0 then total_q = 1 end

    -- Quarters of that span that overlap with the range
    local overlap_start = math.max(sb_m, rs)
    local overlap_end = math.min(nb_m, re)
    if overlap_end < overlap_start then return 0 end

    local overlap_q = math.ceil((overlap_end - overlap_start + 1) / 3)
    if overlap_q <= 0 then overlap_q = 1 end

    return remaining * overlap_q / total_q
end

-- Build an allocation summary: per-namespace capacity vs demand.
-- items: list of parsed YAML items (projects + persons)
-- range_start, range_end: parsed time tables
-- Returns table: { [namespace] = { capacity_weeks, persons, projects, demand_weeks } }
M.allocation_summary = function(items, range_start, range_end)
    if not items then return {} end

    local by_ns = {}
    local function ensure_ns(ns)
        if not by_ns[ns] then
            by_ns[ns] = {
                capacity_weeks = 0,
                persons = {},
                projects = {},
                demand_weeks = 0,
            }
        end
    end

    for _, item in ipairs(items) do
        local ns = item._namespace or ""
        if item.person and item.person ~= "" then
            ensure_ns(ns)
            local cap = M.parse_capacity_weeks(str(item.capacity)) or 0
            by_ns[ns].capacity_weeks = by_ns[ns].capacity_weeks + cap
            table.insert(by_ns[ns].persons, {
                name = item.person,
                capacity_weeks = cap,
            })
        elseif item.project and item.project ~= "" then
            ensure_ns(ns)
            local is_bg = M.is_background(item.project)
            local charge_months = M.quarterly_charge(item, range_start, range_end)
            local charge_weeks = charge_months * WEEKS_PER_MONTH
            if not is_bg then
                by_ns[ns].demand_weeks = by_ns[ns].demand_weeks + charge_weeks
            end
            local clean_proj_name = M.parse_priority(item.project)
            table.insert(by_ns[ns].projects, {
                name = clean_proj_name,
                charge_months = charge_months,
                charge_weeks = charge_weeks,
                completion = tonumber(item.completion) or 0,
                size = str(item.size),
                background = is_bg,
            })
        end
    end

    return by_ns
end

--------------------------------------------------------------------------------
-- Capacity-Aware Projection
--------------------------------------------------------------------------------

-- Topological sort of project full IDs within a namespace.
-- adj: full_id → list of full_ids it depends on (from validate_graph)
-- ns_ids: list of full_ids in this namespace
-- Returns sorted list (dependencies first).
local function topo_sort_ns(ns_ids, adj)
    local id_set = {}
    for _, fid in ipairs(ns_ids) do id_set[fid] = true end

    local WHITE, GRAY, BLACK = 0, 1, 2
    local color = {}
    for _, fid in ipairs(ns_ids) do color[fid] = WHITE end

    local sorted = {}
    local function dfs(node)
        color[node] = GRAY
        for _, dep in ipairs(adj[node] or {}) do
            -- Only follow deps within this namespace
            if id_set[dep] and color[dep] == WHITE then
                dfs(dep)
            end
        end
        color[node] = BLACK
        table.insert(sorted, node)  -- append: deps finish first, come first
    end

    for _, fid in ipairs(ns_ids) do
        if color[fid] == WHITE then dfs(fid) end
    end
    return sorted
end

-- Compute projected end-of-quarter completion for each project.
-- items: parsed YAML items (projects + persons)
-- quarter: string like "25Q3"
-- Returns: { [full_id] = { current, achievable, planned } }
-- Requires valid graph (no cycles). Returns empty on validation errors.
M.project_projections = function(items, quarter)
    if not items or not quarter then return {} end

    local range_start = M.parse_time(quarter)
    if not range_start then return {} end

    -- Validate to get adjacency
    local errors, _, adj = M.validate_graph(items)
    if #errors > 0 then return {} end

    -- Build lookup
    local by_id = {}
    for _, item in ipairs(items) do
        if item.project and item.project ~= "" then
            local fid = M.full_id(item._namespace or "", item.project)
            by_id[fid] = item
        end
    end

    -- Group projects by namespace, collect capacity
    local ns_ids = {}      -- namespace → list of fids
    local ns_capacity = {} -- namespace → total weeks
    for _, item in ipairs(items) do
        local ns = item._namespace or ""
        if item.person and item.person ~= "" then
            ns_capacity[ns] = (ns_capacity[ns] or 0) + (M.parse_capacity_weeks(str(item.capacity)) or 0)
        elseif item.project and item.project ~= "" then
            local fid = M.full_id(ns, item.project)
            if not ns_ids[ns] then ns_ids[ns] = {} end
            table.insert(ns_ids[ns], fid)
        end
    end

    local projections = {}

    for ns, ids in pairs(ns_ids) do
        local remaining_capacity = ns_capacity[ns] or 0
        local topo = topo_sort_ns(ids, adj)

        -- Build own priority from project name
        local own_priority = {}
        for _, fid in ipairs(topo) do
            local item = by_id[fid]
            if item then
                local _, prio = M.parse_priority(item.project or "")
                own_priority[fid] = prio
            else
                own_priority[fid] = 0
            end
        end

        -- Propagate priority: if B depends on A, A inherits max(A's priority, B's priority)
        -- Walk in reverse topo order (dependents before their deps)
        local effective_priority = {}
        for _, fid in ipairs(topo) do
            effective_priority[fid] = own_priority[fid]
        end
        for i = #topo, 1, -1 do
            local fid = topo[i]
            for _, dep in ipairs(adj[fid] or {}) do
                if effective_priority[dep] then
                    effective_priority[dep] = math.max(
                        effective_priority[dep], effective_priority[fid])
                end
            end
        end

        -- Sort by: effective priority descending, then topo order within same priority
        -- Assign topo index for stable sort
        local topo_idx = {}
        for i, fid in ipairs(topo) do topo_idx[fid] = i end

        local scheduled = {}
        for _, fid in ipairs(topo) do table.insert(scheduled, fid) end
        table.sort(scheduled, function(a, b)
            local pa, pb = effective_priority[a], effective_priority[b]
            if pa ~= pb then return pa > pb end
            return topo_idx[a] < topo_idx[b]
        end)

        -- Allocate capacity in scheduled order
        for _, fid in ipairs(scheduled) do
            local item = by_id[fid]
            if item then
                local current = tonumber(item.completion) or 0
                local size_months = M.parse_size_months(str(item.size))
                local charge_months = M.quarterly_charge(item, range_start, range_start)
                local charge_weeks = charge_months * WEEKS_PER_MONTH

                -- Planned completion if fully funded
                local planned = current
                if size_months and size_months > 0 and charge_months > 0 then
                    planned = math.min(100, current + (charge_months / size_months) * 100)
                end

                -- How much can we actually fund?
                local achievable = current
                if charge_weeks > 0 and size_months and size_months > 0 then
                    local funded_weeks = math.min(charge_weeks, remaining_capacity)
                    local funded_months = funded_weeks / WEEKS_PER_MONTH
                    achievable = math.min(100, current + (funded_months / size_months) * 100)
                    remaining_capacity = remaining_capacity - funded_weeks
                    if remaining_capacity < 0 then remaining_capacity = 0 end
                end

                projections[fid] = {
                    current = current,
                    achievable = math.floor(achievable + 0.5),
                    planned = math.floor(planned + 0.5),
                }
            end
        end
    end

    return projections
end

-- Format an allocation report for a quarter.
-- items: parsed YAML items, quarter: string like "25Q3"
-- Returns formatted text string.
M.export_allocation_report = function(items, quarter)
    if not items or not quarter then return "" end

    local range_start = M.parse_time(quarter)
    if not range_start then return "" end

    local summary = M.allocation_summary(items, range_start, range_start)
    local proj = M.project_projections(items, quarter)

    local out = {}
    local namespaces = {}
    for ns in pairs(summary) do
        table.insert(namespaces, ns)
    end
    table.sort(namespaces)

    for _, ns in ipairs(namespaces) do
        local data = summary[ns]
        table.insert(out, string.format("## %s — %s", ns, quarter))
        table.insert(out, "")

        -- Team capacity
        table.insert(out, string.format("**Team capacity: %.1fw** (%d persons)", data.capacity_weeks, #data.persons))
        table.insert(out, "")
        if #data.persons > 0 then
            table.insert(out, "| Person | Capacity |")
            table.insert(out, "|--------|----------|")
            for _, p in ipairs(data.persons) do
                table.insert(out, string.format("| %s | %gw |", p.name, p.capacity_weeks))
            end
            table.insert(out, "")
        end

        -- Project demand
        table.insert(out, string.format("**Project demand: %.1fw**", data.demand_weeks))
        table.insert(out, "")
        local has_projects = false
        for _, p in ipairs(data.projects) do
            if p.charge_weeks > 0 and not p.background then has_projects = true; break end
        end
        if has_projects then
            table.insert(out, "| Project | Charged | Projection | Details |")
            table.insert(out, "|---------|---------|------------|---------|")
            for _, p in ipairs(data.projects) do
                if p.charge_weeks > 0 and not p.background then
                    local fid = M.full_id(ns, p.name)
                    local p_proj = proj[fid]
                    local comp = p.completion
                    local size_months = M.parse_size_months(p.size) or 0
                    local planned = comp
                    if size_months > 0 then
                        planned = math.floor(math.min(100, comp + (p.charge_months / size_months) * 100) + 0.5)
                    end
                    local projection_str
                    if p_proj and p_proj.achievable < planned then
                        projection_str = string.format("%d%% → %d%% ⚠", comp, p_proj.achievable)
                    else
                        projection_str = string.format("%d%% → %d%%", comp, planned)
                    end
                    table.insert(out, string.format("| %s | %.1fw | %s | %.1fm charged, %d%% target |",
                        p.name, p.charge_weeks, projection_str, p.charge_months, planned))
                end
            end
            table.insert(out, "")
        end

        -- Background projects (not charged to capacity)
        local bg_projects = {}
        for _, p in ipairs(data.projects) do
            if p.background then table.insert(bg_projects, p) end
        end
        if #bg_projects > 0 then
            table.insert(out, "**Background (not charged):**")
            table.insert(out, "")
            for _, p in ipairs(bg_projects) do
                table.insert(out, string.format("- %s [bg] (%s, %d%% done)", p.name, p.size or "?", p.completion))
            end
            table.insert(out, "")
        end

        -- Balance
        local balance = data.capacity_weeks - data.demand_weeks
        if data.capacity_weeks > 0 then
            local pct = math.abs(balance) / data.capacity_weeks * 100
            if balance >= 0 then
                table.insert(out, string.format("**Balance: +%.1fw** (%.0f%% slack)", balance, pct))
            else
                table.insert(out, string.format("**Balance: %.1fw** ⚠ over-committed (%.0f%%)", balance, pct))
            end
        else
            if data.demand_weeks > 0 then
                table.insert(out, string.format("**Balance: %.1fw** (no capacity assigned)", -data.demand_weeks))
            else
                table.insert(out, "**Balance: 0.0w**")
            end
        end
        table.insert(out, "")
    end

    return table.concat(out, "\n")
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

    -- Build full ID list (skip person entries)
    local all_ids = {}
    local id_set = {}
    for _, item in ipairs(initiatives) do
        if not item.person and not item.setting then
            if not item.project or item.project == "" then
                add_error(string.format(
                    "item at line %d in %s is not a project, person, or setting",
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
    end

    -- Validate person entries
    for _, item in ipairs(initiatives) do
        if item.person then
            if item.person == "" then
                add_error("person entry has no name", item)
            end
            if item.capacity then
                if not M.parse_capacity_weeks(str(item.capacity)) then
                    local cap_item = { _file = item._file, _line = item._capacity_line or item._line }
                    add_error(string.format(
                        'person "%s" has invalid capacity "%s" (expected e.g. "11w")',
                        item.person or "?", str(item.capacity)), cap_item)
                end
            end
        end
    end

    -- Validate project fields
    for _, item in ipairs(initiatives) do
        if item.project and item.project ~= "" then
            -- Helper: error item pointing to a specific field's line
            local function field_item(key)
                return { _file = item._file, _line = item["_" .. key .. "_line"] or item._line }
            end

            -- Validate size
            if item.size and str(item.size) ~= "" then
                if not M.parse_size_months(str(item.size)) then
                    add_error(string.format(
                        '"%s" has invalid size "%s" (expected e.g. "3m" or S/M/L/XL)',
                        item.project, str(item.size)), field_item("size"))
                end
            end

            -- Validate completion
            if item.completion then
                local c = tonumber(item.completion)
                if not c or c < 0 or c > 100 then
                    add_error(string.format(
                        '"%s" has invalid completion "%s" (expected 0-100)',
                        item.project, tostring(item.completion)), field_item("completion"))
                end
            end

            -- Validate start_by / need_by format: must be YYQ[1-4]
            local sb = str(item.start_by)
            local nb = str(item.need_by)
            if sb ~= "" and not sb:match("^%d+Q[1-4]$") then
                add_error(string.format(
                    '"%s" has invalid start_by "%s" (expected YYQ[1-4], e.g. "25Q2")',
                    item.project, sb), field_item("start_by"))
            end
            if nb ~= "" and not nb:match("^%d+Q[1-4]$") then
                add_error(string.format(
                    '"%s" has invalid need_by "%s" (expected YYQ[1-4], e.g. "25Q4")',
                    item.project, nb), field_item("need_by"))
            end

            -- Warn if need_by < start_by (lexical order)
            if sb ~= "" and nb ~= "" and nb < sb then
                add_error(string.format(
                    '"%s" need_by "%s" is before start_by "%s"',
                    item.project, nb, sb), field_item("need_by"))
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
-- Overlay Filesystem
--------------------------------------------------------------------------------

-- Merge two lists of file paths: current overrides base by filename.
-- Pure function — operates on path strings, not filesystem.
-- Returns merged list of paths, sorted by filename.
M.overlay_files = function(base_files, current_files)
    local by_name = {}
    local names = {}
    for _, f in ipairs(base_files or {}) do
        local name = f:match("([^/]+)$")
        if name and not by_name[name] then
            table.insert(names, name)
        end
        by_name[name] = f
    end
    for _, f in ipairs(current_files or {}) do
        local name = f:match("([^/]+)$")
        if name and not by_name[name] then
            table.insert(names, name)
        end
        by_name[name] = f  -- override base
    end
    table.sort(names)
    local result = {}
    for _, name in ipairs(names) do
        table.insert(result, by_name[name])
    end
    return result
end

-- Discover quarter subdirectories in a vision dir.
-- Returns sorted list of quarter folder names (e.g. {"25Q1", "25Q2", "25Q3"}).
-- IO function — reads filesystem.
M.discover_quarters = function(dir)
    local quarters = {}
    local entries = vim.fn.glob(dir .. "/*", false, true)
    for _, entry in ipairs(entries) do
        if vim.fn.isdirectory(entry) == 1 then
            local name = entry:match("([^/]+)$")
            if name and name:match("^%d+Q[1-4]$") then
                table.insert(quarters, name)
            end
        end
    end
    table.sort(quarters)
    return quarters
end

-- Load vision with quarterly overlay.
-- Loads base (previous quarter) and overlays current quarter's files on top.
-- IO function — reads filesystem.
M.load_vision_quarterly = function(dir, quarter, quarters)
    quarters = quarters or M.discover_quarters(dir)

    -- Find previous quarter
    local prev_quarter = nil
    for i, q in ipairs(quarters) do
        if q == quarter and i > 1 then
            prev_quarter = quarters[i - 1]
            break
        end
    end

    local current_dir = dir .. "/" .. quarter
    local current_files = vim.fn.glob(current_dir .. "/*.yaml", false, true)

    local merged_files
    if prev_quarter then
        local base_dir = dir .. "/" .. prev_quarter
        local base_files = vim.fn.glob(base_dir .. "/*.yaml", false, true)
        merged_files = M.overlay_files(base_files, current_files)
    else
        table.sort(current_files)
        merged_files = current_files
    end

    local items = {}
    for _, filepath in ipairs(merged_files) do
        local namespace = vim.fn.fnamemodify(filepath, ":t:r")
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
    table.insert(lines, "namespace,project,size,need_by,depends_on")

    for _, item in ipairs(initiatives) do
        local deps = item.depends_on or {}
        if type(deps) == "string" then deps = { deps } end
        local deps_str = table.concat(deps, "; ")

        table.insert(lines, string.format("%s,%s,%s,%s,%s",
            csv_escape(item._namespace or ""),
            csv_escape(item.project or ""),
            csv_escape(str(item.size)),
            csv_escape(str(item.need_by)),
            csv_escape(deps_str)))
    end

    return table.concat(lines, "\n") .. "\n"
end

--------------------------------------------------------------------------------
-- DOT Graph Export
--------------------------------------------------------------------------------

local BASE_SIZE_MAP = { S = 1.0, M = 1.5, L = 2.2, XL = 3.0 }

-- Universal shortfall color — bright red, unmistakable, distinct from all schemes
local SHORTFALL_COLOR = "#d32f2f"

-- 10 named color schemes: { done, achievable, base }
-- done = completed work, achievable = will complete this quarter, base = remaining
M.COLOR_SCHEMES = {
    color1  = { done = "#5b9bd5", achievable = "#89c4e8", base = "#a0d8ef", bg = "#dff0f8" },  -- blue
    color2  = { done = "#e6a23c", achievable = "#f0c06e", base = "#ffe0b2", bg = "#fff5e6" },  -- orange
    color3  = { done = "#6ab04c", achievable = "#8fd470", base = "#c8e6c9", bg = "#edf7ee" },  -- green
    color4  = { done = "#9b59b6", achievable = "#b87fd4", base = "#e1bee7", bg = "#f5edf8" },  -- purple
    color5  = { done = "#c0392b", achievable = "#e67e73", base = "#ffcdd2", bg = "#ffeef0" },  -- crimson
    color6  = { done = "#1abc9c", achievable = "#5dd4b8", base = "#b2dfdb", bg = "#e8f5f4" },  -- teal
    color7  = { done = "#f39c12", achievable = "#f7bc52", base = "#fff3cd", bg = "#fffae8" },  -- gold
    color8  = { done = "#3498db", achievable = "#6db8ea", base = "#bbdefb", bg = "#e8f4fe" },  -- sky
    color9  = { done = "#e91e63", achievable = "#f06292", base = "#f8bbd0", bg = "#fde8f1" },  -- pink
    color10 = { done = "#607d8b", achievable = "#8fa4ad", base = "#cfd8dc", bg = "#edf1f3" },  -- slate
}
local DEFAULT_SCHEME = M.COLOR_SCHEMES.color1
local CHARS_PER_INCH = 7  -- approx characters per inch for wrapping decisions
local SCALE_CHARS_PER_INCH = 4  -- conservative estimate for Graphviz box sizing

-- Wrap text at word boundaries to fit within max_chars per line.
-- Returns list of lines and the length of the longest line.
local function wrap_text(text, max_chars)
    local lines = {}
    local current = ""
    for word in text:gmatch("%S+") do
        if current == "" then
            current = word
        elseif #current + 1 + #word <= max_chars then
            current = current .. " " .. word
        else
            table.insert(lines, current)
            current = word
        end
    end
    if current ~= "" then table.insert(lines, current) end
    local longest = 0
    for _, l in ipairs(lines) do
        if #l > longest then longest = #l end
    end
    return lines, longest
end

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

-- Compute node width from size: linear month scaling with T-shirt fallback.
-- Returns width in inches.
local function size_to_width(size_str)
    local months = M.parse_size_months(size_str)
    if months then
        return 1.5 + months * 0.4
    end
    return BASE_SIZE_MAP[size_str] or 1.5
end

-- Resolve color scheme for a namespace from items.
-- Looks for a setting entity with color: field in the namespace.
local function resolve_ns_scheme(items)
    local ns_scheme = {}
    for _, item in ipairs(items) do
        if item.setting and item.color then
            local ns = item._namespace or ""
            local scheme = M.COLOR_SCHEMES[str(item.color)]
            if scheme then
                ns_scheme[ns] = scheme
            end
        end
    end
    return ns_scheme
end

-- Build striped fill style for completion visualization.
-- scheme: color scheme table {done, achievable, base}
-- projection: optional {current, achievable, planned} from project_projections
-- Returns style string and fillcolor string for DOT attributes.
local function completion_fill(scheme, completion, projection)
    scheme = scheme or DEFAULT_SCHEME
    completion = tonumber(completion) or 0

    -- 4-segment mode when projection data is available
    if projection and projection.planned > completion then
        local segments = {}
        local cur = completion / 100
        local ach = projection.achievable / 100
        local pln = projection.planned / 100

        if cur > 0 then
            table.insert(segments, string.format("%s;%.2f", scheme.done, cur))
        end
        if ach > cur then
            table.insert(segments, string.format("%s;%.2f", scheme.achievable, ach - cur))
        end
        if pln > ach then
            table.insert(segments, string.format("%s;%.2f", SHORTFALL_COLOR, pln - ach))
        end
        if pln < 1 then
            table.insert(segments, string.format("%s;%.2f", scheme.base, 1 - pln))
        end

        if #segments <= 1 then
            local color = #segments == 1 and segments[1]:match("^([^;]+)") or scheme.base
            return "filled", '"' .. color .. '"'
        end
        return "striped", '"' .. table.concat(segments, ":") .. '"'
    end

    -- Simple 2-segment mode (no projection)
    if completion <= 0 then
        return "filled", '"' .. scheme.base .. '"'
    elseif completion >= 100 then
        return "filled", '"' .. scheme.done .. '"'
    else
        local colors = string.format('"%s;%.2f:%s;%.2f"',
            scheme.done, completion / 100,
            scheme.base, 1 - completion / 100)
        return "striped", colors
    end
end

-- Export initiatives to Graphviz DOT format. Returns the DOT string.
-- opts.root: optional root node ID for subgraph filtering
-- opts.direction: "down" (default), "up", or "both"
-- opts.quarter: optional quarter string for filtering (only non-zero charge projects)
-- opts.range: optional {start, end} parsed time range for charge calculation
M.export_dot = function(initiatives, opts)
    opts = opts or {}

    -- Resolve namespace color schemes
    local ns_scheme = resolve_ns_scheme(initiatives)

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

    -- Quarterly filter and projections
    local charge_filter = nil
    local projections = nil
    if opts.quarter then
        local range_start = opts.range and opts.range[1] or M.parse_time(opts.quarter)
        local range_end = opts.range and opts.range[2] or range_start
        if range_start then
            charge_filter = {}
            for _, fid in ipairs(all_ids) do
                local item = by_id[fid]
                if item then
                    local charge = M.quarterly_charge(item, range_start, range_end)
                    if charge > 0 then
                        charge_filter[fid] = true
                    end
                end
            end
        end
        -- Compute capacity-aware projections
        projections = M.project_projections(initiatives, opts.quarter)
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

    local function is_included(fid)
        if include and not include[fid] then return false end
        if charge_filter and not charge_filter[fid] then return false end
        return true
    end

    -- Pass 1: compute global scale factor so all text fits in its size box
    local scale = 1.0
    for _, fid in ipairs(all_ids) do
        if is_included(fid) then
            local item = by_id[fid]
            if item then
                local base_w = size_to_width(str(item.size))
                local wrap_chars = math.floor(base_w * CHARS_PER_INCH)
                local fit_chars = math.floor(base_w * SCALE_CHARS_PER_INCH)
                local ns_prefix = (item._namespace or ""):upper()
                local clean_name = M.parse_priority(item.project or fid)
                local name = ns_prefix .. ": " .. clean_name
                local _, longest_name = wrap_text(name, wrap_chars)
                local size_months = M.parse_size_months(str(item.size))
                local size_label = size_months and string.format("%gm", size_months) or (item.size or "?")
                local comp = tonumber(item.completion) or 0
                local meta_len = #size_label + #str(item.need_by) + (comp > 0 and 6 or 0) + 4
                local longest = math.max(longest_name, meta_len)
                if longest > fit_chars then
                    local needed = longest / SCALE_CHARS_PER_INCH
                    local item_scale = needed / base_w
                    if item_scale > scale then scale = item_scale end
                end
            end
        end
    end

    -- Build DOT
    local lines = {}
    table.insert(lines, 'digraph vision {')
    table.insert(lines, '    rankdir=TB;')
    table.insert(lines, '    node [shape=box, style="filled", fixedsize=true];')
    table.insert(lines, '')

    -- Pass 2: precompute node data and heights
    local nodes = {}
    for _, fid in ipairs(all_ids) do
        if is_included(fid) then
            local item = by_id[fid]
            if item then
                local base_w = size_to_width(str(item.size))
                local w = base_w * scale
                -- Font grows with scaled width; compensate so wrap threshold stays accurate.
                local base_fontsize = 10 + math.floor(base_w * 3)
                local fontsize = 10 + math.floor(w * 3)
                local max_chars = math.floor(w * CHARS_PER_INCH * base_fontsize / fontsize)
                local ns_prefix = (item._namespace or ""):upper()
                local clean_name = M.parse_priority(item.project or fid)
                local name = ns_prefix .. ": " .. clean_name
                local wrapped, _ = wrap_text(name, max_chars)
                local wrapped_name = table.concat(wrapped, "\\n")

                -- Build label with size in months and completion
                local size_months = M.parse_size_months(str(item.size))
                local size_label = size_months and string.format("%gm", size_months) or (item.size or "?")
                local comp = tonumber(item.completion) or 0
                local proj = projections and projections[fid]
                local label
                if proj and proj.planned > comp then
                    -- [size current%|achievable%|planned%] — collapse middle when no shortfall
                    if proj.achievable < proj.planned then
                        label = string.format("%s\\n[%s %d%%|%d%%|%d%%] %s",
                            wrapped_name, size_label, comp, proj.achievable, proj.planned, str(item.need_by))
                    else
                        label = string.format("%s\\n[%s %d%%|%d%%] %s",
                            wrapped_name, size_label, comp, proj.planned, str(item.need_by))
                    end
                elseif comp > 0 then
                    label = string.format("%s\\n[%s %d%%] %s",
                        wrapped_name, size_label, comp, str(item.need_by))
                else
                    label = string.format("%s\\n[%s] %s",
                        wrapped_name, size_label, str(item.need_by))
                end

                local scheme = ns_scheme[item._namespace or ""] or DEFAULT_SCHEME
                local style, fillcolor = completion_fill(scheme, comp, proj)
                if M.is_background(item.project) then
                    style = "filled,dashed"
                    fillcolor = '"' .. (scheme.bg or scheme.base) .. '"'
                end
                local num_lines = #wrapped + 1
                local h = num_lines * fontsize / 72 + 0.3
                local size_rank = math.floor(base_w * 10)  -- continuous ranking by width

                table.insert(nodes, {
                    fid = fid, label = label, w = w, h = h,
                    style = style, fillcolor = fillcolor,
                    fontsize = fontsize, size_rank = size_rank,
                })
            end
        end
    end

    -- Enforce: larger size rank must have height >= max height of any smaller rank
    local max_h_by_rank = {}
    for _, n in ipairs(nodes) do
        max_h_by_rank[n.size_rank] = math.max(max_h_by_rank[n.size_rank] or 0, n.h)
    end
    -- Collect and sort unique ranks
    local ranks = {}
    for rank in pairs(max_h_by_rank) do
        table.insert(ranks, rank)
    end
    table.sort(ranks)
    local floor_h = 0
    for _, rank in ipairs(ranks) do
        floor_h = math.max(floor_h, max_h_by_rank[rank])
        max_h_by_rank[rank] = floor_h
    end
    for _, n in ipairs(nodes) do
        n.h = math.max(n.h, max_h_by_rank[n.size_rank] or 0)
    end

    -- Emit nodes
    for _, n in ipairs(nodes) do
        table.insert(lines, string.format(
            '    "%s" [label="%s", width=%.1f, height=%.1f, style="%s", fillcolor=%s, fontsize=%d];',
            n.fid, n.label, n.w, n.h, n.style, n.fillcolor, n.fontsize))
    end

    table.insert(lines, '')

    -- Edges
    for _, fid in ipairs(all_ids) do
        if is_included(fid) then
            for _, dep in ipairs(adj[fid] or {}) do
                if is_included(dep) then
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

-- Load all initiatives from vision_dir, or nil + warning if not configured.
-- Auto-detects quarterly mode (subdirs like 25Q3/) vs flat mode (*.yaml files).
-- In quarterly mode, uses the latest quarter folder by default.
local function load_all(quarter_override)
    local dir = M.get_vision_dir()
    if not dir then
        _parley.logger.warning("vision_dir is not configured")
        return nil
    end
    save_vision_buffers(dir)

    -- Check for quarterly mode
    local quarters = M.discover_quarters(dir)
    if #quarters > 0 then
        local quarter = quarter_override or quarters[#quarters]  -- default: latest
        return M.load_vision_quarterly(dir, quarter, quarters), dir, quarter
    end

    -- Flat mode (existing behavior)
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

    -- Parse args: optional output path, --root=node, --quarter=25Q3
    local args = params and params.args or ""
    local root = args:match("%-%-root=(%S+)")
    local quarter = args:match("%-%-quarter=(%S+)")
    local output = args:gsub("%-%-root=%S+", ""):gsub("%-%-quarter=%S+", ""):match("^%s*(%S+)")

    local dot, errors = M.export_dot(items, { root = root, quarter = quarter })
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

-- :ParleyVisionAllocation [--quarter=25Q3] — show allocation report
M.cmd_export_allocation = function(params)
    local args = params and params.args or ""
    local quarter = args:match("%-%-quarter=(%S+)")

    local items, _, detected_quarter = load_all(quarter)
    if not items then return end

    -- Use detected quarter or default
    quarter = quarter or detected_quarter
    if not quarter then
        vim.notify("Vision: no quarter specified and no quarterly folders found", vim.log.levels.WARN)
        return
    end

    local report = M.export_allocation_report(items, quarter)
    if report == "" then
        vim.notify("Vision: could not generate allocation report", vim.log.levels.WARN)
        return
    end

    -- Show in a scratch markdown buffer
    vim.cmd("new")
    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_buf_set_name(buf, "Vision Allocation: " .. quarter)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(report, "\n"))
    vim.bo[buf].modifiable = false
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
-- Typeahead completion for vision YAML fields
--------------------------------------------------------------------------------

-- Determine completion context at cursor.
-- Returns { key = "field_name", partial = "typed text", col = start_col } or nil.
-- key_path is a list from innermost to outermost, e.g. {"depends_on"} for list items.
-- For inline fields like "  type: te", key is "type" and partial is "te".
local function get_completion_context(buf)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]
    local line = vim.api.nvim_get_current_line()

    -- Case 1: indented list item "    - partial" — walk up to find parent key
    local list_partial = line:match("^%s+%-%s(.*)$")
    if list_partial then
        for r = row - 1, math.max(1, row - 10), -1 do
            local prev = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1]
            if not prev then break end
            local key = prev:match("^%s+([%w_]+):%s*$")
            if key then
                local dash_pos = line:find("%-")
                local col = dash_pos + 1
                while line:sub(col + 1, col + 1) == " " do col = col + 1 end
                return { key = key, partial = list_partial, col = col + 1 }
            end
            local stripped = trim(prev)
            if stripped ~= "" and not stripped:match("^#") and not prev:match("^%s+%- ") then
                break
            end
        end
        return nil
    end

    -- Case 2: inline field "  key: partial" (continuation key within an item)
    -- Skip depends_on — it uses list items (case 1), not inline values
    local key, val = line:match("^%s+([%w_]+):%s*(.*)$")
    if key and key ~= "depends_on" then
        local col = line:find(":%s*") + 1
        while line:sub(col + 1, col + 1) == " " do col = col + 1 end
        return { key = key, partial = val or "", col = col + 1 }
    end

    return nil
end

-- Completable fields and their candidate sources.
-- Each returns a list of {word, menu} tables.
local completion_sources = {}

-- size: month sizes + T-shirt sizes
completion_sources.size = function()
    local candidates = {}
    -- Common month sizes
    for _, m in ipairs({ "0.5m", "1m", "2m", "3m", "6m", "9m", "12m" }) do
        table.insert(candidates, { word = m })
    end
    -- T-shirt sizes (backward compat)
    for _, t in ipairs({ "S", "M", "L", "XL" }) do
        table.insert(candidates, { word = t, menu = TSHIRT_TO_MONTHS[t] .. "m" })
    end
    return candidates
end

-- start_by / need_by: shared pool from both fields + quarter folder names
local function quarter_values()
    local seen = {}
    local candidates = {}

    -- Quarter folder names (e.g. "25Q3" from vision/25Q3/)
    local dir = M.get_vision_dir()
    if dir then
        for _, q in ipairs(M.discover_quarters(dir)) do
            if not seen[q] then
                seen[q] = true
                table.insert(candidates, { word = q })
            end
        end
    end

    -- Values from start_by / need_by fields
    local items = load_all()
    if items then
        for _, item in ipairs(items) do
            for _, key in ipairs({ "start_by", "need_by" }) do
                local val = item[key]
                if type(val) == "string" and val ~= "" and not seen[val] then
                    seen[val] = true
                    table.insert(candidates, { word = val })
                end
            end
        end
    end

    table.sort(candidates, function(a, b) return a.word < b.word end)
    return candidates
end

completion_sources.start_by = quarter_values
completion_sources.need_by = quarter_values

-- color: named color schemes
completion_sources.color = function()
    local candidates = {}
    for i = 1, 10 do
        local name = "color" .. i
        local scheme = M.COLOR_SCHEMES[name]
        if scheme then
            table.insert(candidates, { word = name, menu = scheme.done })
        end
    end
    return candidates
end

-- depends_on: project refs with namespace awareness
-- partial is passed so we can switch modes: bare locals vs prefixed locals
completion_sources.depends_on = function(current_ns, partial)
    local items = load_all()
    if not items then return {} end

    -- Detect if user has typed a namespace prefix
    local typed_ns = partial and partial:match("^(%w+):%s*")

    local candidates = {}
    local namespaces = {}  -- track all namespaces seen
    for _, item in ipairs(items) do
        if item.project and item.project ~= "" then
            local ns = item._namespace or ""
            local name_id = M.name_to_id(item.project)
            namespaces[ns] = true
            if typed_ns == ns then
                -- User typed this namespace prefix — show prefixed names
                table.insert(candidates, {
                    word = ns .. ": " .. name_id,
                    menu = item.project,
                })
            elseif not typed_ns then
                if ns == current_ns then
                    -- Default: show bare local names
                    table.insert(candidates, { word = name_id, menu = item.project })
                end
                -- Remote names only shown after typing their prefix
            end
        end
    end
    -- When no prefix typed, show namespace prefixes as candidates
    if not typed_ns then
        for ns, _ in pairs(namespaces) do
            local label = ns == current_ns and "local namespace" or ns .. ".yaml"
            table.insert(candidates, { word = ns .. ": ", menu = label })
        end
    end
    return candidates
end

-- Match a partial input against a candidate word.
-- Supports multi-prefix with "..." and namespace-scoped matching for depends_on.
local function match_candidate(partial, word)
    if partial == "" then return true end

    -- Handle "ns: partial" — for depends_on cross-namespace refs
    local partial_ns, partial_rest = partial:match("^([^:]+):%s*(.*)$")
    if partial_ns then
        local word_ns = word:match("^([^:]+):")
        if not word_ns or word_ns ~= partial_ns then return false end
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
    local norm_partial = partial:lower()
    return word:lower():sub(1, #norm_partial) == norm_partial
end

-- TextChangedI handler for typeahead completion
M.on_text_changed_i = function(buf)
    local ctx = get_completion_context(buf)
    if not ctx then return end

    local source = completion_sources[ctx.key]
    if not source then return end

    -- depends_on needs current namespace
    local candidates
    if ctx.key == "depends_on" then
        local filepath = vim.api.nvim_buf_get_name(buf)
        local current_ns = vim.fn.fnamemodify(filepath, ":t:r")
        candidates = source(current_ns, ctx.partial)
    else
        candidates = source()
    end

    -- Filter candidates
    local filtered = {}
    for _, c in ipairs(candidates) do
        if match_candidate(ctx.partial, c.word) then
            table.insert(filtered, c)
        end
    end

    if #filtered == 0 then return end

    -- Set completeopt for non-blocking typeahead
    local saved_completeopt = vim.o.completeopt
    vim.o.completeopt = "menuone,noinsert,noselect"
    vim.fn.complete(ctx.col, filtered)
    vim.o.completeopt = saved_completeopt
end

return M
