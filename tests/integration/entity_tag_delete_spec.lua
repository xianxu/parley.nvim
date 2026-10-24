local parley = require("parley")
local Document = require("parley.document")

local root = (os.getenv("TMPDIR") or "/tmp") .. "/parley-tag-delete-" .. os.time()
local seq, configured = 0, false

local function prepped(lines)
    if not configured then
        parley.setup({ chat_dir = root .. "/chat", state_dir = root .. "/state", providers = {}, api_keys = {} })
        configured = true
    end
    seq = seq + 1
    vim.fn.mkdir(parley.config.chat_dir, "p")
    local path = parley.config.chat_dir .. "/tagged-sections-" .. seq .. ".md"
    vim.fn.writefile(lines, path)
    vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
    local buf = vim.api.nvim_get_current_buf()
    parley.prep_chat(buf, path)
    Document.attach(buf, { schedule = false })
    return buf
end

-- #419 BR-4: parity alone cannot detect two surfaces sharing the same wrong
-- endpoint. These ordinary Markdown buffers have no exchange bound, so the
-- tagged section must end before the next sibling's tag, even when its own
-- tag precedes the heading from which the section endpoint is determined.
describe("tagged Markdown delete-to-end", function()
    for _, preceding in ipairs({ false, true }) do
        for _, cursor in ipairs({ "tag", "heading" }) do
            for _, surface in ipairs({ "daE", "ParleyDeleteToEnd" }) do
                it(("%s from %s preserves tagged siblings (%s preceding sibling)")
                    :format(surface, cursor, preceding and "with" or "without"), function()
                    local prefix = preceding and { "@@chat@@", "## Prior", "prior body", "" } or {}
                    local following = { "@@chat@@", "## Next", "next body" }
                    local lines = vim.deepcopy(prefix)
                    local tag_row = #lines + 1
                    vim.list_extend(lines, { "@@chat@@", "## Target", "target body", "" })
                    vim.list_extend(lines, following)
                    local expected = vim.deepcopy(prefix)
                    vim.list_extend(expected, following)
                    local buf = prepped(lines)
                    local path = vim.api.nvim_buf_get_name(buf)
                    vim.wo.foldmethod = "manual"
                    vim.cmd("normal! zE")
                    vim.api.nvim_win_set_cursor(0, { tag_row + (cursor == "heading" and 1 or 0), 0 })
                    if surface == "daE" then
                        vim.cmd("normal daE")
                    else
                        vim.cmd("ParleyDeleteToEnd")
                    end
                    local deleted = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    vim.cmd("silent normal! u")
                    local undone = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    pcall(vim.api.nvim_buf_delete, buf, { force = true })
                    pcall(vim.fn.delete, path)
                    assert.same(expected, deleted, "delete only the target tag, heading and section body")
                    assert.same(lines, undone, "one undo restores the complete tagged document")
                end)
            end
        end
    end
end)
