-- Neutral coordinator for buffer convergence and teardown.

local M = {}

local CONVERGENCE_EVENTS = { "InsertLeave", "TextChanged", "BufWritePost", "BufEnter", "WinEnter" }
local TEARDOWN_EVENTS = { "BufUnload", "BufDelete" }

function M._new(deps)
    local lifecycle = {}
    local active = {}
    local registered = false

    function lifecycle.converge(buf, _reason)
        if not active[buf] or not deps.is_valid(buf) then
            return
        end
        deps.diagnostics.refresh(buf)
        local rebuilt, err = deps.structure.rebuild(buf)
        if rebuilt == nil and err then
            if deps.notify then deps.notify(err) end
            error(err, 0)
        end
    end

    function lifecycle.clear(buf)
        if not active[buf] then
            return
        end
        active[buf] = nil
        deps.diagnostics.clear(buf)
        deps.structure.clear(buf)
    end

    local function register_events()
        if registered then
            return
        end
        registered = true
        deps.create_autocmd(CONVERGENCE_EVENTS, function(event)
            lifecycle.converge(event.buf, event.event)
        end)
        deps.create_autocmd(TEARDOWN_EVENTS, function(event)
            lifecycle.clear(event.buf)
        end)
    end

    function lifecycle.setup(buf)
        register_events()
        if active[buf] or not deps.is_valid(buf) then
            return
        end
        active[buf] = true
        lifecycle.converge(buf, "setup")
    end

    function lifecycle.finalize_mutated_api_leg(buf, mutated)
        if mutated then
            lifecycle.converge(buf, "api-leg")
        end
    end

    return lifecycle
end

local group = vim.api.nvim_create_augroup("parley-buffer-lifecycle", { clear = true })
local default = M._new({
    is_valid = vim.api.nvim_buf_is_valid,
    diagnostics = require("parley.diagnostic_refresh"),
    structure = {
        rebuild = function(buf)
            local highlighter = require("parley.highlighter")
            if highlighter.rebuild_structure then
                return highlighter.rebuild_structure(buf)
            end
        end,
        clear = function(buf)
            require("parley.highlighter").clear_structure(buf)
        end,
    },
    create_autocmd = function(events, callback)
        vim.api.nvim_create_autocmd(events, { group = group, callback = callback })
    end,
    notify = function(err) vim.notify("Parley structure rebuild failed: " .. tostring(err), vim.log.levels.ERROR) end,
})

M.setup = default.setup
M.converge = default.converge
M.clear = default.clear
M.finalize_mutated_api_leg = default.finalize_mutated_api_leg

return M
