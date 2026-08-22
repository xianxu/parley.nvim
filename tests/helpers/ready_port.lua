-- Wait for a spawned fixture to publish the TCP port it bound.
--
-- A fixture that binds port 0 has to tell the test which port it got, and the
-- usual channel is a file the test polls for. Polling for *existence* is the
-- bug this helper exists to prevent (#202): a writer that opens the path and
-- then writes the digits leaves a window where the file is readable and empty,
-- so the reader gets no port and the caller crashes concatenating nil into a
-- URL. Waiting for a *parseable* port instead makes an incomplete signal a
-- named timeout rather than a nil dereference.
--
-- The publisher side matters too, and is the actual fix: a signal must be
-- published atomically (write to a sibling path, rename onto the ready path),
-- because a reader cannot tell partial digits from complete ones. This helper
-- defends the consumer; it does not make a torn writer safe.

local M = {}

local DEFAULT_TIMEOUT_MS = 1000
local POLL_MS = 5
local MAX_PORT = 65535

--- Read a published signal, or nil while the file is absent or still empty.
--- @param path string
--- @return string|nil content, boolean saw_path
local function read_signal(path)
    local fh = io.open(path, "r")
    if not fh then
        return nil, false
    end
    local content = fh:read("*a") or ""
    fh:close()
    content = content:gsub("%s+$", "")
    if content == "" then
        return nil, true
    end
    return content, true
end

--- Wait until `path` publishes a usable TCP port.
--- @param path string file the fixture publishes its port into
--- @param timeout_ms number|nil how long to wait (default 1000)
--- @return number|nil port, string|nil err
function M.wait_for_port(path, timeout_ms)
    timeout_ms = timeout_ms or DEFAULT_TIMEOUT_MS
    local signal, saw_path
    vim.wait(timeout_ms, function()
        local content, seen = read_signal(path)
        signal = content
        saw_path = saw_path or seen
        return content ~= nil
    end, POLL_MS)

    if signal == nil then
        local why = saw_path and "it appeared but never published a port"
            or "it never appeared"
        return nil, ("timed out after %dms waiting on %s: %s"):format(timeout_ms, path, why)
    end

    local port = tonumber(signal)
    if not port or port ~= math.floor(port) or port < 1 or port > MAX_PORT then
        return nil, ("%s published %q, which is not a TCP port"):format(path, signal)
    end
    return port
end

return M
