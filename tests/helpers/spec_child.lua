-- Preserve Plenary's assertion, fixture and exit behavior. Completion is after
-- its full it() call, including before_each and after_each, rather than stdout.
local M = {}

function M.run(path, token)
    local busted = require("plenary.busted")
    local original, sequence = busted.it, 0
    busted.it = function(...)
        local result = original(...)
        sequence = sequence + 1
        io.stdout:write("\n" .. token .. " " .. sequence .. "\n")
        io.stdout:flush()
        return result
    end
    _G.it = busted.it
    return busted.run(path)
end

return M
