-- Open-descriptor watchdog (#399). An editor that leaks descriptors dies at
-- the process limit (256 on macOS) with E903 on every BufEnter, long after the
-- leak began. Once this editor's own count passes the threshold, the watchdog
-- captures `lsof -p` and the live children to a file and warns once, naming
-- it, so the onset diagnoses itself. Decisions are pure; the timer, the
-- capture commands and the files are the thin shell below them.
local M = {}
local uv = vim.uv or vim.loop

M.INTERVAL_MS = 60000
M.KEEP = 5            -- captures kept; older ones are removed at each write
M.DEADLINE_MS = 10000 -- each capture command

-- Fire once per process, on the first count above the threshold (0 disables).
function M.crossed(count, threshold, fired)
    return not fired and threshold > 0 and count ~= nil and count > threshold
end

-- Rows of `ps -o pid=,ppid=,comm= -A` whose parent is `pid`. `comm` is the
-- executable alone: a child's arguments can carry secrets (curl's
-- Authorization and x-api-key headers), so the capture never asks for them.
function M.children(ps_text, pid)
    local rows = {}
    for line in (ps_text or ""):gmatch("[^\n]+") do
        local child, parent, command = line:match("^%s*(%d+)%s+(%d+)%s+(.*)$")
        if parent and tonumber(parent) == pid then rows[#rows + 1] = child .. " " .. command end
    end
    return rows
end

-- The capture file's lines. A command that failed records its exit and stderr.
function M.report(info)
    local function section(title, result)
        local lines = { "", "## " .. title }
        if result.code ~= 0 then lines[#lines + 1] = ("(exit %s) %s"):format(result.code, result.stderr or "") end
        vim.list_extend(lines, vim.split(result.stdout or "", "\n", { trimempty = true }))
        return lines
    end
    local lines = {
        "# parley open-descriptor capture (#399)",
        ("time: %s"):format(info.time),
        ("pid: %d"):format(info.pid),
        ("open descriptors: %d (threshold %d)"):format(info.count, info.threshold),
        "",
        "## children",
    }
    local kids = M.children(info.ps.stdout, info.pid)
    if info.ps.code ~= 0 then lines[#lines + 1] = ("(ps exit %s) %s"):format(info.ps.code, info.ps.stderr or "") end
    vim.list_extend(lines, #kids > 0 and kids or { "(none)" })
    vim.list_extend(lines, section("lsof -p " .. info.pid, info.lsof))
    return lines
end

-- Capture names sort by time (`fd-<stamp>-<pid>.txt`); all but the newest `keep`.
function M.stale(names, keep)
    local captures = {}
    for _, name in ipairs(names) do
        if name:match("^fd%-.+%.txt$") then captures[#captures + 1] = name end
    end
    table.sort(captures)
    local old = {}
    for i = 1, #captures - keep do old[#old + 1] = captures[i] end
    return old
end

local state = { timer = nil, fired = false }

-- This process's open descriptors; nil when even listing them fails.
function M.count()
    local ok, n = pcall(function()
        local total = 0
        for _ in vim.fs.dir("/dev/fd") do total = total + 1 end
        return total
    end)
    return ok and n or nil
end

local function run(argv, done)
    local ok, err = pcall(require("parley.helper").system, argv, { text = true, timeout = M.DEADLINE_MS }, function(result)
        vim.schedule(function() done(result) end)
    end)
    if not ok then done({ code = -1, stderr = tostring(err) }) end
end

local function capture(options, n)
    local pid = vim.fn.getpid()
    run({ options.lsof or "lsof", "-p", tostring(pid) }, function(lsof)
        run({ options.ps or "ps", "-o", "pid=,ppid=,comm=", "-A" }, function(ps)
            local stamp = os.date("%Y%m%d-%H%M%S")
            local made = pcall(require("parley.fs").ensure_dir, options.dir)
            local path = ("%s/fd-%s-%d.txt"):format(options.dir, stamp, pid)
            local lines = M.report({ time = os.date("!%Y-%m-%dT%H:%M:%SZ"), pid = pid, count = n,
                threshold = options.threshold, ps = ps, lsof = lsof })
            local wrote = made and pcall(vim.fn.writefile, lines, path)
            local names = {}
            for name in vim.fs.dir(options.dir) do names[#names + 1] = name end
            for _, name in ipairs(M.stale(names, M.KEEP)) do os.remove(options.dir .. "/" .. name) end
            local notify = options.notify or vim.notify
            notify(("parley: this editor holds %d open files (threshold %d; macOS stops at 256). %s")
                :format(n, options.threshold, wrote and ("Captured lsof and its children to " .. path)
                    or ("Could not write the capture to " .. path)), vim.log.levels.WARN)
        end)
    end)
end

local function tick(options)
    local n = M.count()
    if not M.crossed(n, options.threshold, state.fired) then return end
    -- Once per process: nothing re-arms it, and the timer has no further work.
    state.fired = true
    M.stop()
    capture(options, n)
end

--- Start the watchdog. `options`: threshold, dir, interval_ms, and for specs
--- the `lsof` and `ps` executables and `notify`. Re-running setup restarts the
--- timer; after a capture it stays off for the rest of the process.
function M.setup(options)
    M.stop()
    if state.fired or (options.threshold or 0) <= 0 then return end
    state.timer = uv.new_timer()
    state.timer:start(options.interval_ms or M.INTERVAL_MS, options.interval_ms or M.INTERVAL_MS,
        vim.schedule_wrap(function() tick(options) end))
end

function M.stop()
    if state.timer then
        state.timer:stop()
        if not state.timer:is_closing() then state.timer:close() end
    end
    state.timer = nil
end

-- Specs only: forget a capture this process already made.
function M._rearm()
    M.stop()
    state.fired = false
end

return M
