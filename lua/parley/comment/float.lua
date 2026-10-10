-- comment/float.lua — the 🤖 comment thread float (#312).
--
-- `<CR>` on a marker opens its chain in a plain scratch buffer that reads like
-- a parley chat (thread.to_lines): `💬: ` human turns, `🤖: ` robot turns, on
-- their own backgrounds, the cursor in insert mode on the trailing `💬: ` reply
-- slot. It is a
-- focused nvim buffer: everything is editable; "reply on the last line" is a
-- convention, not a rule. `:w` (or `:x` / `q`) writes the thread back as ONE
-- line (thread.from_lines) over the marker's original bytes; `:q!` discards.
--
-- Creates nothing durable: the buffer is wiped on close and the tracking
-- extmark is deleted when the window goes.
local view = require("parley.comment.view")
local thread = require("parley.comment.thread")

local M = {}

local NS = vim.api.nvim_create_namespace("parley_comment_thread")

local function notify(msg)
    vim.notify("Parley comment: " .. msg, vim.log.levels.WARN)
end

local function float_text(fbuf)
    return table.concat(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false), "\n")
end

-- Write the float's thread back over the marker. Returns ok, err.
local function write_back(st)
    if not vim.api.nvim_buf_is_valid(st.src) then return false, "source buffer is gone" end
    local pos = vim.api.nvim_buf_get_extmark_by_id(st.src, NS, st.mark, {})
    local row, col = pos[1], pos[2]
    local line = row and vim.api.nvim_buf_get_lines(st.src, row, row + 1, false)[1]
    if not line or line:sub(col + 1, col + #st.raw) ~= st.raw then
        vim.fn.setreg('"', float_text(st.float_buf))
        return false, 'the marker changed underneath — thread text kept in register "'
    end
    local raw, err = thread.from_lines(st.prefix, vim.api.nvim_buf_get_lines(st.float_buf, 0, -1, false),
        st.appended)
    if not raw then return false, err end
    if raw ~= st.raw then
        local new = line:sub(1, col) .. raw .. line:sub(col + #st.raw + 1)
        require("parley.buffer_edit").replace_user_lines(st.src, row, row + 1, false, { new })
        st.raw = raw
        -- Rewriting the row drops the tracking extmark's column; re-anchor it
        -- at the marker's start so the next :w finds the bytes it wrote.
        pcall(vim.api.nvim_buf_del_extmark, st.src, NS, st.mark)
        st.mark = vim.api.nvim_buf_set_extmark(st.src, NS, row, col, {})
    end
    return true
end

local function size_for(lines, title)
    local width = vim.fn.strdisplaywidth(title) + 4
    for _, l in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(l) + 2) end
    width = math.max(30, math.min(width, math.floor(vim.o.columns * 0.8)))
    local height = 0
    for _, l in ipairs(lines) do
        height = height + math.max(1, math.ceil(vim.fn.strdisplaywidth(l) / width))
    end
    height = math.max(3, math.min(height, math.floor(vim.o.lines * 0.8)))
    return width, height
end

-- Re-derived from the current text so lines added while editing are painted
-- too: a continuation line belongs to the turn above it.
local function paint_roles(fbuf)
    vim.api.nvim_buf_clear_namespace(fbuf, NS, 0, -1)
    for i, role in ipairs(thread.roles(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false))) do
        vim.api.nvim_buf_set_extmark(fbuf, NS, i - 1, 0, {
            line_hl_group = role == "agent" and "ParleyCommentAgent" or "ParleyCommentUser",
        })
    end
end

--- Open the thread of the marker under the cursor in `buf`.
--- @return boolean opened  false when the cursor is not on a rendered marker
function M.open_thread(buf)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    local m = line:find("🤖", 1, true) and view.marker_at(view.layout(line), col)
    if not m then return false end

    local raw = line:sub(m.start + 1, m.stop)
    local marker = require("parley.drill_in").parse(raw)[1]
    if not marker then return false end
    local first = marker.sections[1]
    local st = {
        src = buf,
        raw = raw,
        prefix = raw:sub(1, (first and first.byte_start or #raw + 1) - 1),
        mark = vim.api.nvim_buf_set_extmark(buf, NS, row - 1, m.start, {}),
    }
    local lines, _, appended = thread.to_lines(marker)
    st.appended = appended
    local anchor = marker.quoted or marker.strike
    local title = " 🤖 comment "
    if anchor and anchor.text ~= "" then
        local quote = anchor.text
        if vim.fn.strdisplaywidth(quote) > 50 then quote = vim.fn.strcharpart(quote, 0, 49) .. "…" end
        title = (' 🤖 on "%s" '):format(quote)
    end
    local footer = " :w save · q save & close · :q! discard "

    local fbuf = vim.api.nvim_create_buf(false, true)
    st.float_buf = fbuf
    vim.api.nvim_buf_set_name(fbuf, ("parley-comment://%d/%d"):format(buf, fbuf))
    vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
    vim.bo[fbuf].buftype = "acwrite"
    vim.bo[fbuf].bufhidden = "wipe"
    vim.bo[fbuf].swapfile = false
    vim.bo[fbuf].syntax = "markdown" -- not filetype: parley would claim a markdown buffer
    vim.bo[fbuf].modified = false

    local width, height = size_for(lines, title .. footer)
    local fwin = vim.api.nvim_open_win(fbuf, true, {
        relative = "editor", style = "minimal", border = "rounded",
        width = width, height = height,
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        title = title, title_pos = "center",
        footer = footer, footer_pos = "center",
    })
    vim.wo[fwin].wrap = true
    vim.wo[fwin].linebreak = true
    paint_roles(fbuf)
    -- Ready to reply: insert mode at the end of the trailing `💬: ` line.
    vim.api.nvim_win_set_cursor(fwin, { #lines, #lines[#lines] })
    vim.cmd("startinsert!")

    local group = vim.api.nvim_create_augroup("ParleyCommentThread" .. fbuf, { clear = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group, buffer = fbuf, callback = function() paint_roles(fbuf) end,
    })
    vim.api.nvim_create_autocmd("BufWriteCmd", {
        group = group, buffer = fbuf,
        callback = function()
            local ok, err = write_back(st)
            if ok then vim.bo[fbuf].modified = false else notify(err) end
        end,
    })
    -- Standard nvim semantics: `:w` writes back, `:x` / `q` write and close,
    -- `:q!` discards. A window closed some other way with unsaved edits keeps
    -- its text in the unnamed register rather than losing it silently.
    vim.api.nvim_create_autocmd("WinClosed", {
        group = group, pattern = tostring(fwin),
        callback = function()
            if vim.api.nvim_buf_is_valid(fbuf) and vim.bo[fbuf].modified then
                vim.fn.setreg('"', float_text(fbuf))
                notify('thread closed without :w — its text is in register "')
            end
            if vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_del_extmark, buf, NS, st.mark) end
            pcall(vim.api.nvim_del_augroup_by_id, group)
        end,
    })
    vim.keymap.set("n", "q", "<Cmd>x<CR>", { buffer = fbuf, desc = "Parley: save and close comment thread" })
    return true
end

return M
