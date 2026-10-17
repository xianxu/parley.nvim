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

--- Bind port 0, read back what the OS gave us, release it.
--- Promoted from file-local copies in cliproxy_lifecycle_spec.lua and
--- cliproxy_recovery_e2e_spec.lua; a third consumer (#205's dormancy test) is
--- what made the duplication worth removing (ARCH-DRY).
--- @return number port
function M.free_port()
    local uv = vim.uv or vim.loop
    local s = uv.new_tcp()
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

--- One TCP connect to the port; true when the handshake completed. Not proof
--- of a listener on its own (see is_listening). Replaceable so a spec can
--- stage the false positive without winning a kernel race.
--- @param port number
--- @return boolean
function M._connect(port)
    local uv = vim.uv or vim.loop
    local ok, done = false, false
    local c = uv.new_tcp()
    c:connect("127.0.0.1", port, function(err)
        ok = err == nil
        done = true
        pcall(function() c:close() end)
    end)
    vim.wait(500, function() return done end)
    return ok
end

-- Bound on the confirming lsof: it is slow under suite load, and an answer
-- that never comes is "unconfirmed", never "listening".
local LSOF_TIMEOUT_MS = 2000

--- Does a socket in LISTEN state hold the port? nil when lsof can't say
--- (absent, refused or too slow).
--- @param port number
--- @return boolean|nil
function M._has_listener(port)
    local ok, res = pcall(function()
        return vim.system({ "lsof", "-nP", "-iTCP:" .. port, "-sTCP:LISTEN", "-t" },
            { text = true, timeout = LSOF_TIMEOUT_MS }):wait()
    end)
    if not ok or res.code == 124 then
        return nil
    end
    if res.code == 0 then
        return (res.stdout or ""):match("%d") ~= nil
    end
    -- lsof exits 1 for "no such socket"; anything else is lsof failing.
    return res.code == 1 and false or nil
end

--- Is something accepting connections on this port right now? One attempt, no
--- polling — the negative predicate a dormancy assertion needs.
---
--- A completed connect is not enough (#360): free_port hands the number back to
--- the kernel's shared ephemeral pool, a parallel spec's probe can take it as
--- its SOURCE port, and two probes aimed at each other's freed ports complete a
--- TCP simultaneous open with nothing listening — measured as 6 refused first
--- fetches in 240. So a connect is confirmed by a LISTEN socket on the port.
--- The lsof runs only after a connect succeeds, so polling a port that is
--- still refusing costs nothing extra. Where lsof is absent the connect stands
--- alone, as before.
--- @param port number
--- @return boolean
function M.is_listening(port)
    if not M._connect(port) then
        return false
    end
    local listener = M._has_listener(port)
    if listener == nil then
        return vim.fn.executable("lsof") == 0
    end
    return listener
end

--- Poll until something is listening on `port`, so probes don't race startup.
--- @param port number
--- @param timeout_ms number|nil
--- @return boolean listening
function M.wait_listening(port, timeout_ms)
    return vim.wait(timeout_ms or 5000, function()
        return M.is_listening(port)
    end, 50) or false
end

return M
