-- Pure window composition. Text measurement is supplied by the editor adapter.
local M = {}
local trail_model = require("parley.breadcrumb_model")

local function literal(value)
    return tostring(value or ""):gsub("[\r\n%c]", " ")
end

local function fit(text, budget, ops)
    if budget <= 0 then return "" end
    text = literal(text)
    if ops.width(text) <= budget then return text end
    local suffix = ops.width("…") <= budget and "…" or ""
    local result = ""
    for _, unit in ipairs(ops.units(text)) do
        if ops.width(result .. unit .. suffix) > budget then break end
        result = result .. unit
    end
    return result .. suffix
end

local function escape(text)
    return text:gsub("%%", "%%%%")
end

local labels = { free = "free", operator = "yours", stale = "stale", violated = "stale",
    owed = "agent…", unknown = "unknown", plain = "" }

function M.compose(view, trail, width, ops)
    width = math.max(0, width)
    local highlight = view.hl or "WinBar"
    -- Retain literal overlay handles that carry no lock-state selection.
    if not view.state then
        return { winbar = "%#" .. highlight .. "# " .. escape(fit(view.label, math.max(0, width - 1), ops)) .. "%=",
            winhighlight = "StatusLine:" .. highlight }
    end
    local has_trail = trail_model.visible(trail)
    if view.state == "plain" and not has_trail and not view.feedback then return {} end
    local cell = labels[view.state] or "unknown"
    if view.state == "operator" and view.unsent then cell = cell .. " ●" end
    cell = cell .. string.rep(" ", math.max(0, 9 - ops.width(cell)))
    cell = fit(cell, width, ops)
    local result = "%#" .. highlight .. "#" .. escape(cell)
    local remaining = math.max(0, width - ops.width(cell))
    local feedback = view.feedback
    if not feedback and (view.state == "owed" or view.state == "violated" or view.state == "unknown") then
        feedback = { label = view.label or "", hl = highlight }
    end
    local message = feedback and fit(feedback.label, remaining - 1, ops) or ""
    local trail_budget = remaining - 1 - (message ~= "" and ops.width(message) + 3 or 0)
    local path = has_trail and trail_model.project(trail, math.max(0, trail_budget), ops) or ""
    if path ~= "" then result = result .. " " .. escape(path) end
    if message ~= "" then
        result = result .. (path ~= "" and " · " or " ")
            .. "%#" .. (feedback.hl or highlight) .. "#" .. escape(message)
    end
    return { winbar = result .. "%=", winhighlight = "StatusLine:" .. highlight }
end

return M
