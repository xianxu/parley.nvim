-- Read-only scratch view of a tracker card whose details are not in this
-- checkout (#309). It shows what the card holds, where it came from and how
-- fresh it is; it never creates a details file or invents Spec/Plan content.
-- The buffer wipes when hidden, and its tracker subscription drops with it.

local buffer_edit = require("parley.buffer_edit")
local issue_cards = require("parley.issue_cards")
local issue_tracker = require("parley.issue_tracker")

local M = {}

M.NS = vim.api.nvim_create_namespace("parley_issue_card_view")

local function render(buf, root, id, cards)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    local view = issue_cards.view_lines(
        cards and cards[id], id, issue_tracker.status(root) or {}, cards ~= nil, issue_tracker.field_names())
    -- Lift both guards for the render only: writing a `readonly` buffer warns (W10).
    vim.bo[buf].readonly, vim.bo[buf].modifiable = false, true
    buffer_edit.replace_all(buf, view.lines)
    vim.bo[buf].readonly, vim.bo[buf].modifiable = true, false
    vim.bo[buf].modified = false
    vim.api.nvim_buf_clear_namespace(buf, M.NS, 0, -1)
    for _, row in ipairs(view.label_rows) do
        vim.api.nvim_buf_set_extmark(buf, M.NS, row, 0, {
            end_row = row,
            end_col = #view.lines[row + 1],
            hl_group = issue_cards.HIGHLIGHT,
        })
    end
end

local function find(name)
    -- Exact match: bufnr() treats its argument as a file pattern.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_get_name(buf) == name then
            return buf
        end
    end
    return nil
end

-- Show card `id` of the repository at `root` in the current window; returns the
-- buffer. Opening the same card again reuses its buffer.
M.open = function(root, id)
    issue_tracker.ensure_highlight()
    local name = issue_cards.card_ref(root, id)
    local buf = find(name)
    local fresh = buf == nil
    if fresh then
        buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_buf_set_name(buf, name)
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].swapfile = false
        vim.bo[buf].filetype = "markdown"
        vim.bo[buf].modifiable = false
        vim.bo[buf].readonly = true
        vim.b[buf].parley_card_only = { root = root, id = id }
    end
    vim.api.nvim_set_current_buf(buf)

    local cards
    local function show(next_cards)
        cards = next_cards or cards
        render(buf, root, id, cards)
    end
    if fresh then
        issue_tracker.subscribe(root, {
            notify = show,
            alive = function()
                return vim.api.nvim_buf_is_valid(buf)
            end,
        })
    end
    issue_tracker.load(root, function(loaded)
        show(loaded)
        issue_tracker.refresh(root, function()
            show(nil) -- the freshness line, whether or not the tip moved
        end)
        show(nil) -- refresh has set `fetching`: say "refreshing…"
    end)
    return buf
end

return M
