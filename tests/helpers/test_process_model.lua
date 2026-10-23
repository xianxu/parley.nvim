-- Pure evidence policy shared by the runner and retained-process census (#416).
-- A missing observation never proves absence, and start tokens remain opaque.
local M = {}

local function valid_start(start)
    return type(start) == "string" and
        (start:match("^%d+$") ~= nil or start:match("^%d+%.%d+$") ~= nil)
end

--- Classify one retained birth against a native identity observation.
--- Extra fields are ignored; neither input is changed.
--- @param record table
--- @param observation table
--- @return string status live, gone, or unknown
--- @return string|nil reason
function M.classify(record, observation)
    if type(record) ~= "table" or record.version ~= 1 then return "unknown", "invalid record version" end
    if record.state == "pending" then return "unknown", "birth identity pending" end
    if record.state ~= "born" then return "unknown", "invalid record state" end
    local pid = record.pid
    if type(pid) ~= "number" or pid <= 0 or pid >= math.huge or pid % 1 ~= 0 then
        return "unknown", "invalid record pid"
    end
    if not valid_start(record.start) then return "unknown", "invalid record start" end
    if type(observation) ~= "table" then return "unknown", "missing observation" end
    if observation.kind == "absent" then return "gone" end
    if observation.kind == "unknown" then
        return "unknown", type(observation.reason) == "string" and observation.reason or "identity unavailable"
    end
    if observation.kind ~= "live" or not valid_start(observation.start) then
        return "unknown", "invalid observation"
    end
    if observation.start == record.start then return "live" end
    return "gone", "pid reused"
end

return M
