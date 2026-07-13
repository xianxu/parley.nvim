-- parley.selection_spinner — immediate read-only progress at a selection edge.

local M = {}

local uv = vim.uv or vim.loop
local namespace = vim.api.nvim_create_namespace("parley_selection_spinner")

--- Start a canonical inline spinner at the exclusive end of a selection.
--- @param buf number
--- @param row number 0-based row
--- @param col number 0-based byte column
--- @return function stop idempotent teardown
function M.start(buf, row, col)
    local stopped = false
    local timer
    local extmark
    local tick = 1 -- progress.frame(1) is the approved initial frame: ⠙.

    local function stop()
        if stopped then return end
        stopped = true
        if timer then
            pcall(function() timer:stop() end)
            pcall(function() timer:close() end)
            timer = nil
        end
        if extmark and vim.api.nvim_buf_is_valid(buf) then
            pcall(vim.api.nvim_buf_del_extmark, buf, namespace, extmark)
        end
        extmark = nil
    end

    local function render()
        if stopped then return end
        if not vim.api.nvim_buf_is_valid(buf) then
            stop()
            return
        end
        local current_row = row
        local current_col = col
        if extmark then
            local position = vim.api.nvim_buf_get_extmark_by_id(
                buf, namespace, extmark, { details = true })
            if #position < 2 or (position[3] and position[3].invalid) then
                stop()
                return
            end
            current_row = position[1]
            current_col = position[2]
        end
        local ok, mark = pcall(vim.api.nvim_buf_set_extmark, buf, namespace,
            current_row, current_col, {
            id = extmark,
            virt_text = { { " " .. require("parley.progress").frame(tick) } },
            virt_text_pos = "inline",
            invalidate = true,
        })
        if not ok then
            stop()
            return
        end
        extmark = mark
    end

    if not vim.api.nvim_buf_is_valid(buf) then
        stopped = true
        return stop
    end
    render()
    if stopped then return stop end

    timer = uv.new_timer()
    if not timer then
        stop()
        return stop
    end
    timer:start(90, 90, vim.schedule_wrap(function()
        if stopped then return end
        if not vim.api.nvim_buf_is_valid(buf) then
            stop()
            return
        end
        tick = tick + 1
        render()
    end))
    return stop
end

return M
