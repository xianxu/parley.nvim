-- The jobs a spec child started, so its runner can end them (#402). Neovim
-- starts every jobstart child in a process group of its own, out of reach of a
-- signal to the spec child's group. In spec children only (the runner sets
-- PARLEY_SPEC_JOBS_DIR), tests/minimal_init.vim installs a jobstart wrapper that
-- records each job's pid with its start time. The runner later signals a
-- recorded job's group only while both still match: a reused pid is skipped.
-- Only vim.fn.jobstart is wrapped: termopen, Vimscript jobstart() and
-- nvim_call_function("jobstart") bypass it (no spec uses them, 2026-10-19).
-- Everything after install runs in libuv callbacks too, so it uses no vim.fn.
local identity = require("tests.helpers.process_identity")
local uv = vim.uv or vim.loop

local M = {}

M.ENV = "PARLEY_SPEC_JOBS_DIR"

local function ledger(dir) return dir .. "/jobs" end

--- Wrap vim.fn.jobstart in this process when its runner asked for a registry.
function M.install()
    local dir = vim.env[M.ENV]
    if not dir or dir == "" then return end
    local jobstart = vim.fn.jobstart
    vim.fn.jobstart = function(...)
        local channel = jobstart(...)
        if type(channel) == "number" and channel > 0 then
            local pid = vim.fn.jobpid(channel)
            local started = identity.start_time(pid)
            local file = started and io.open(ledger(dir), "a")
            if file then
                file:write(("%d %s\n"):format(pid, started))
                file:close()
            end
        end
        return channel
    end
end

--- The recorded jobs: `pid start` lines. A malformed line is dropped, never
--- guessed at: the ledger crosses a process boundary.
--- @param dir string
--- @return { pid: integer, start: string }[]
function M.read(dir)
    local records = {}
    local file = io.open(ledger(dir), "r")
    if not file then return records end
    for line in file:lines() do
        local pid, start = line:match("^(%d+) (%d+%.?%d*)$")
        if pid then records[#records + 1] = { pid = tonumber(pid), start = start } end
    end
    file:close()
    return records
end

--- Whether a group leader recorded as `pid` started at `start` may still be
--- signalled: it is the same process, or no process holds the pid any more
--- (its group may outlive it, and the kernel reuses no pid while its group
--- exists). Only a pid now naming a different process is refused. Pure.
--- @param pid integer
--- @param start string
--- @param now string|nil the pid's current start time
--- @return boolean ok, string|nil reason
function M.may_signal(pid, start, now)
    if now == nil or now == start then return true end
    return false, ("pid %d reused (started %s, recorded %s)"):format(pid, now, start)
end

--- Which records may be signalled, by M.may_signal. Pure: `start_time` is the
--- identity lookup.
--- @param records { pid: integer, start: string }[]
--- @param start_time fun(pid: integer): string|nil
--- @return integer[] targets, { pid: integer, reason: string }[] skipped
function M.targets(records, start_time)
    local targets, skipped = {}, {}
    for _, record in ipairs(records) do
        local ok, reason = M.may_signal(record.pid, record.start, start_time(record.pid))
        if ok then targets[#targets + 1] = record.pid
        else skipped[#skipped + 1] = { pid = record.pid, reason = reason } end
    end
    return targets, skipped
end

--- Signal a group leader's group, else the process alone (a pid that leads no
--- group). Callers check identity first (M.may_signal).
--- @param pid integer
--- @param signal string
function M.signal_group(pid, signal)
    if not uv.kill(-pid, signal) then uv.kill(pid, signal) end
end

--- Signal each recorded job that may still be signalled; report each skip
--- through `log`.
--- @param dir string
--- @param signal string
--- @param log fun(message: string)|nil
function M.signal(dir, signal, log)
    local targets, skipped = M.targets(M.read(dir), identity.start_time)
    for _, pid in ipairs(targets) do M.signal_group(pid, signal) end
    for _, skip in ipairs(skipped) do
        if log then log(("spec job not signalled: %s\n"):format(skip.reason)) end
    end
end

return M
