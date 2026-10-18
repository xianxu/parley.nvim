-- parley.frontmatter_enum — typeahead for frontmatter keys with a fixed set of
-- values (#384). A key joins by one declaration below; its values always come
-- from the module that enforces them, never from a second list here.
-- context/candidates are PURE; attach wires them to Vim's popup, or to an
-- nvim-cmp source when cmp is active in the buffer.
local M = {}
local frontmatter = require("parley.frontmatter")

local declared, order = {}, {}

--- Declare `key` with `spec.values()` (its allowed values) and optional
--- `spec.applies(path)` (which files it belongs to). Redeclaring replaces it.
function M.declare(key, spec)
    if not declared[key] then order[#order + 1] = key end
    declared[key] = spec
end

--- Remove a declaration (tests' teardown).
function M.undeclare(key)
    if not declared[key] then return end
    declared[key] = nil
    order = vim.tbl_filter(function(k) return k ~= key end, order)
end

function M.keys()
    return vim.deepcopy(order)
end

-- A path with symlinks resolved, so a workspace reached through a link still
-- matches its own issues directory.
local function real(path)
    return vim.fn.resolve(vim.fn.fnamemodify(path, ":p")):gsub("/$", "")
end

M.declare("collaboration-mode", {
    values = function() return require("parley.skills.review.collaboration").modes end,
})
M.declare("status", {
    values = function() return require("parley.issues").status_values() end,
    applies = function(path)
        local ok, dir = pcall(function() return require("parley.issues").get_issues_dir() end)
        if not ok or type(dir) ~= "string" or dir == "" or path == "" then return false end
        dir = real(dir)
        return real(path):sub(1, #dir + 1) == dir .. "/"
    end,
})

--- Where the cursor stands, if it is on a declared key's value inside the
--- opening frontmatter block: { key, start (0-based byte column of the value),
--- partial (what is typed before the cursor) }, else nil.
--- @param lines string[]  the buffer's lines
--- @param row number  1-based cursor line
--- @param col number  0-based cursor byte column
function M.context(lines, row, col)
    local fm = frontmatter.parse(lines)
    if not fm or row <= 1 or row >= fm.close then return nil end
    local line = lines[row]
    local key, gap = line:match("^([%w_][%w_-]*):(%s*)")
    if not key or not declared[key:lower()] then return nil end
    local start = #key + 1 + #gap
    if col < start then return nil end
    return { key = key:lower(), start = start, partial = line:sub(start + 1, col) }
end

--- The declared values of `key` that start with `partial`, for the file at `path`.
function M.candidates(key, partial, path)
    local spec = declared[key]
    if not spec or (spec.applies and not spec.applies(path)) then return {} end
    local matches = {}
    for _, value in ipairs(spec.values() or {}) do
        if value:sub(1, #partial) == partial then matches[#matches + 1] = value end
    end
    return matches
end

-- Frontmatter longer than this gets no typeahead; reading it bounds each keystroke.
local SCAN_LINES = 500

local function at_cursor()
    local buf = vim.api.nvim_get_current_buf()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if row > SCAN_LINES then return nil end
    return M.context(vim.api.nvim_buf_get_lines(buf, 0, SCAN_LINES, false), row, col)
end

local SOURCE = "parley_frontmatter"
local registered = false

-- nvim-cmp, when it is loaded and enabled for the current buffer, else nil.
-- Two menus fight (#384, measured with the operator's config: Vim's popup
-- and cmp's own menu both open), so with cmp the values go through cmp.
local function active_cmp()
    local cmp = package.loaded["cmp"]
    if type(cmp) ~= "table" or type(cmp.get_config) ~= "function" or type(cmp.register_source) ~= "function" then return nil end
    local enabled = cmp.get_config().enabled
    if type(enabled) == "function" then enabled = enabled() end
    return enabled ~= false and cmp or nil
end

--- The buffer's cmp sources with ours first: its own group, sorted before the
--- rest, so on a frontmatter value cmp shows only the values. Elsewhere our
--- source is unavailable and the buffer's sources work as before.
function M.with_source(sources)
    local lowest = 1
    for _, source in ipairs(sources or {}) do
        if source.name == SOURCE then return sources end
        lowest = math.min(lowest, source.group_index or 0)
    end
    local out = { { name = SOURCE, group_index = lowest - 1 } }
    vim.list_extend(out, vim.deepcopy(sources or {}))
    return out
end

-- Register the source once, and put it in this buffer's sources. Host configs
-- and parley's chat setup reset buffer sources, so this runs on each change.
-- Returns whether the source was just added (cmp then needs a fresh complete).
local function ensure_cmp(cmp)
    if not registered then
        cmp.register_source(SOURCE, {
            is_available = function() return at_cursor() ~= nil end,
            get_keyword_pattern = function() return [[\%(\w\|-\)*]] end,
            complete = function(_, _, callback)
                local ctx = at_cursor()
                local items = {}
                for _, value in ipairs(ctx and M.candidates(ctx.key, ctx.partial, vim.api.nvim_buf_get_name(0)) or {}) do
                    items[#items + 1] = { label = value }
                end
                callback(items)
            end,
        })
        registered = true
    end
    local sources = cmp.get_config().sources
    local with = M.with_source(sources)
    if with == sources then return false end
    cmp.setup.buffer({ sources = with })
    return true
end

--- Typeahead on a markdown buffer: in Insert mode, typing a declared key's
--- value offers the matching values. Without nvim-cmp it is Vim's own popup
--- (the one the issue status: field had, generalized); with cmp active in the
--- buffer, the values are a cmp source instead, so only one menu opens.
function M.attach(buf)
    if vim.b[buf].parley_frontmatter_enum then return end
    vim.b[buf].parley_frontmatter_enum = true
    vim.api.nvim_create_autocmd("TextChangedI", { buffer = buf, callback = function()
        local ctx = at_cursor()
        if not ctx then return end
        local cmp = active_cmp()
        if cmp then
            if ensure_cmp(cmp) and type(cmp.complete) == "function" then cmp.complete() end
            return
        end
        local matches = M.candidates(ctx.key, ctx.partial, vim.api.nvim_buf_get_name(buf))
        -- Nothing to offer once the value is typed out in full.
        if #matches == 0 or (#matches == 1 and matches[1] == ctx.partial) then return end
        require("parley.helper").complete_noselect(ctx.start + 1, matches)
    end })
end

return M
