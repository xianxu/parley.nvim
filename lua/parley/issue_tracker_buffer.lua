-- Amber end-of-line annotations on issue details buffers (#308): where the
-- details' card_mirror disagrees with the ariadne#252 tracker card, show the
-- card's value beside the stale line. Buffer bytes are never changed; card
-- fields stay sdlc's to write.

local issue_cards = require("parley.issue_cards")
local issue_tracker = require("parley.issue_tracker")
local issue_vocabulary = require("parley.issue_vocabulary")

local M = {}

M.NS = vim.api.nvim_create_namespace("parley_issue_tracker")

-- (repo root, issue id) when `path` is a details file in its repository's issue
-- home; nil otherwise. Whether the repository is tracked is load's question.
local function details_target(path)
    local id = vim.fn.fnamemodify(path, ":t"):match("^(%d+)%-.+%.md$")
    local home = id and issue_vocabulary.home()
    local root = home and issue_tracker.repo_root(path)
    if not root then
        return nil
    end
    local dir = vim.fn.resolve(vim.fn.fnamemodify(path, ":p:h"))
    if dir ~= vim.fn.resolve(root .. "/" .. home) then
        return nil
    end
    return root, id
end

local function paint(buf, card, names)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, M.NS, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for _, note in ipairs(issue_cards.annotations(lines, card, names)) do
        vim.api.nvim_buf_set_extmark(buf, M.NS, note.row, 0, {
            virt_text = { { "  " .. note.text, issue_cards.HIGHLIGHT } },
            virt_text_pos = "eol",
        })
    end
end

M.attach = function(buf)
    local root, id = details_target(vim.api.nvim_buf_get_name(buf))
    if not root then
        return
    end
    issue_tracker.ensure_highlight()
    local names = issue_tracker.field_names()
    local card
    local function show(cards)
        if cards then
            card = cards[id]
            paint(buf, card, names)
        end
    end
    local function refresh()
        issue_tracker.refresh(root, show)
    end

    local group = vim.api.nvim_create_augroup("ParleyIssueTrackerBuffer" .. buf, { clear = true })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        buffer = buf,
        callback = function()
            paint(buf, card, names)
        end,
    })
    vim.api.nvim_create_autocmd("BufEnter", { group = group, buffer = buf, callback = refresh })
    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        buffer = buf,
        callback = function()
            pcall(vim.api.nvim_del_augroup_by_id, group)
        end,
    })

    issue_tracker.load(root, function(cards)
        show(cards)
        if cards then
            refresh()
        end
    end)
end

M.setup = function()
    local group = vim.api.nvim_create_augroup("ParleyIssueTracker", { clear = true })
    vim.api.nvim_create_autocmd("BufReadPost", {
        group = group,
        pattern = "*.md",
        callback = function(ev)
            M.attach(ev.buf)
        end,
    })
end

return M
