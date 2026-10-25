-- Exact review details belong to Neovim's message history; the live notice
-- stays short so it cannot interrupt Normal/Insert input with hit-enter.
-- Stateless adapter: no separate history, queue or lifecycle owner.
local M = {}
local text = require("parley.display_text")

local function prefix(value, budget)
    local kept = ""
    for _, unit in ipairs(text.units(value)) do
        if text.width(kept .. unit) > budget then break end
        kept = kept .. unit
    end
    return kept
end

local function caption(summary)
    -- Callers supply a constant summary or a sanitized failure reason, never document text.
    summary = summary:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    local budget = math.max(0, math.min(48, vim.o.columns - 16))
    local hint = ":messages"
    local suffix = " " .. hint
    if text.width(summary .. suffix) <= budget then return summary .. suffix end
    local tail = "..." .. suffix
    if text.width(tail) <= budget then return prefix(summary, budget - text.width(tail)) .. tail end
    return prefix(hint, budget)
end

--- Store exact strings and show one bounded caption with a history hint.
--- Unexpected capture failures propagate: do not claim unavailable history.
function M.show(messages, summary, level)
    for _, message in ipairs(messages) do
        -- unsilent retains history under output capture. JSON carries one string
        -- as data, including physical newlines/quotes/pipes, through Ex safely.
        local encoded = vim.fn.string(vim.json.encode(message))
        vim.api.nvim_exec2("unsilent echomsg json_decode(" .. encoded .. ")", { output = true })
    end
    vim.notify(caption(summary), level or vim.log.levels.INFO)
end

return M
