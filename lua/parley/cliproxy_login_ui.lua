-- Login presentation only: the caller owns the process and completion latch.
local M = {}
local names = { codex = 'OpenAI', claude = 'Claude', google = 'Google', qwen = 'Qwen',
    kimi = 'Kimi', xai = 'xAI', antigravity = 'Google Antigravity' }

--- Open a disposable login progress window. Closing it never stops the job.
---@param provider string
---@param cancel function
---@return table
function M.open(provider, cancel)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].bufhidden = 'wipe'
    local width = math.max(1, math.min(68, vim.o.columns - 4))
    local height = math.max(1, math.min(9, vim.o.lines - 4))
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor', style = 'minimal', border = 'rounded',
        width = width, height = height,
        row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
        col = math.max(0, math.floor((vim.o.columns - width) / 2)),
        title = ' Connect ' .. (names[provider] or provider) .. ' ', title_pos = 'center',
    })
    vim.wo[win].wrap = true
    vim.cmd('stopinsert')
    local output, url, code = {}, nil, nil
    local awaiting_code = false
    local details = false
    local message = 'Finish signing in in your browser, then return here.'
    local active = true
    local function close()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    end
    local function render()
        if not vim.api.nvim_buf_is_valid(buf) then return end
        local lines = { '', message, '', 'Waiting for your account to connect…', '',
            'o: open browser   y: copy link   d: show details', 'c: cancel login   Esc: hide (login continues)' }
        if not active then
            lines[4] = 'Try again with :ParleyProxy connect.'
            lines[7] = 'Esc: close   d: show details'
        end
        if code then
            table.insert(lines, 4, code)
            if url then table.insert(lines, 4, url) end
        end
        if details then
            lines = { message, '', 'd: back   Esc: hide', '' }
            vim.list_extend(lines, output)
        end
        vim.bo[buf].modifiable = true
        require('parley.buffer_edit').replace_all_lines(buf, lines)
        vim.bo[buf].modifiable = false
    end
    local function map(key, fn) vim.keymap.set('n', key, fn, { buffer = buf, silent = true }) end
    map('<Esc>', close)
    map('q', close)
    map('d', function() details = not details; render() end)
    map('o', function()
        if url then
            local ok, _, err = pcall(vim.ui.open, url)
            if not ok or err then message = 'Browser could not open. Press y to copy the link.'; render() end
        end
    end)
    map('y', function()
        if url then
            vim.fn.setreg('+', url)
            vim.fn.setreg('"', url)
            message = 'Link copied. Paste it into your browser.'
            render()
        end
    end)
    map('c', function()
        if not active then return end
        active = false
        close()
        cancel()
    end)
    render()
    return {
        close = close,
        append = function(line)
            -- A bounded in-memory transcript; discarded with this login.
            output[#output + 1] = line:sub(1, 8192)
            if #output > 200 then table.remove(output, 1) end
            url = line:match('https?://%S+') or url
            local lower = line:lower()
            if awaiting_code then
                code = (code or 'Code:') .. ' ' .. line
                awaiting_code = false
            elseif not lower:match('https?://') and (lower:match('enter.*code')
                or lower:match('user.?code') or lower:match('verification code')) then
                code = line
                awaiting_code = line:match(':%s*$') ~= nil
            end
            render()
        end,
        finish = function(ok)
            active = false
            if ok then close(); return end
            message = 'Sign-in did not finish.'
            render()
        end,
    }
end

return M
