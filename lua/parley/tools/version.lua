local M = {}

function M.stable_command_version(line, fallback)
    return (line or ""):match("^(%S+%s+%S+)") or fallback
end

return M
