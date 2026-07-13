-- Synchronous coordinator for buffer-wide diagnostics.

local M = {}

function M._new(deps)
    local refresh = {}

    function refresh.refresh(buf)
        if not deps.is_valid(buf) then
            return
        end
        deps.timezone.refresh_buffer(buf)
        deps.footnotes.refresh_footnote_diagnostics(buf)
    end

    function refresh.clear(buf)
        if not deps.is_valid(buf) then
            return
        end
        deps.timezone.clear(buf)
        deps.footnotes.clear_footnote_diagnostics(buf)
    end

    return refresh
end

local default = M._new({
    is_valid = vim.api.nvim_buf_is_valid,
    timezone = require("parley.timezone_diagnostics"),
    footnotes = require("parley.skill_render"),
})

M.refresh = default.refresh
M.clear = default.clear

return M
