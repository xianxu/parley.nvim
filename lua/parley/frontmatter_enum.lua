-- parley.frontmatter_enum — typeahead for frontmatter keys with a fixed set of
-- values (#384). A key joins by one declaration below; its values always come
-- from the module that enforces them, never from a second list here.
-- context/candidates are PURE; attach wires them to omnifunc and nvim-cmp.
local M = {}
local frontmatter = require("parley.frontmatter")

local declared, order = {}, {}

--- Declare `key` with `spec.values()` (its allowed values) and optional
--- `spec.applies(path)` (which files it belongs to). Redeclaring replaces it.
function M.declare(key, spec)
    if not declared[key] then order[#order + 1] = key end
    declared[key] = spec
end

function M.keys()
    return vim.deepcopy(order)
end

M.declare("collaboration-mode", {
    values = function() return require("parley.skills.review.collaboration").modes end,
})
M.declare("status", {
    values = function()
        local model = require("parley.issue_vocabulary").default()
        return model and model:status_values() or {}
    end,
    applies = function(path)
        local ok, dir = pcall(function() return require("parley.issues").get_issues_dir() end)
        return ok and type(dir) == "string" and dir ~= "" and path:sub(1, #dir + 1) == dir .. "/"
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

--- Typeahead on a markdown buffer: in Insert mode, typing a declared key's
--- value pops up the matching values (the popup the issue status: field had,
--- generalized; it needs no completion plugin).
function M.attach(buf)
    if vim.b[buf].parley_frontmatter_enum then return end
    vim.b[buf].parley_frontmatter_enum = true
    vim.api.nvim_create_autocmd("TextChangedI", { buffer = buf, callback = function()
        local ctx = at_cursor()
        if not ctx then return end
        local matches = M.candidates(ctx.key, ctx.partial, vim.api.nvim_buf_get_name(buf))
        -- Nothing to offer once the value is typed out in full.
        if #matches == 0 or (#matches == 1 and matches[1] == ctx.partial) then return end
        require("parley.helper").complete_noselect(ctx.start + 1, matches)
    end })
end

return M
