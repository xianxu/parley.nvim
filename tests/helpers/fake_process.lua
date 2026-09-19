-- Stateful libuv seam. Each spawn owns pipes and an exit callback independently.
--
-- #261 M3: it models process groups the way the kernel does, so a test can tell
-- a group kill from a pid kill.
--   * `spawn_opts.detached == true` makes the child its own group leader
--     (pgid == pid); otherwise it joins group 0, standing in for Neovim's own.
--   * `kill(-pgid, sig)` signals every live member and records one
--     `{pid, signal, group = true}` entry per member. `state.signals` lists
--     only signals the kernel accepted, on both paths. A group kill honours the
--     leader's scripted `signal_result` ("unknown", "missing", "throw", or a
--     number) exactly as a pid kill honours the process's own, so a scoped
--     record can observe a failed signal too. Unscripted, it delivers the
--     signal as the kernel does; a pid kill delivers only under
--     `finish_on_signal` (the older fixtures' default).
--   * `process.ignores = {[15] = true}` (and `[9]`, a kernel hold) ignores a
--     signal; any other non-zero signal exits the process.
--   * `process:fork()` adds a grandchild in the same group holding the same
--     pipes. With `opts.pipes_follow_holders`, a pipe's EOF arrives only when its
--     last holder exits; without it, `exit()` sends no EOF, as before.
--   * `state.spawn_options` records every spawn's options.
local M = {}
function M.new(opts)
    opts = opts or {}
    local state = { pipes = {}, processes = {}, spawn_calls = 0, signals = {}, timers = {}, spawn_options = {} }
    local runtime = {}
    runtime.new_timer = function()
        local timer={closing=false,starts=0}
        function timer:start(delay,_,callback)self.delay=delay;self.callback=callback;self.starts=self.starts+1 end
        function timer:stop()self.callback=nil end
        function timer:close()self.closing=true;self.callback=nil end
        function timer:is_closing()return self.closing end
        function timer:fire()if self.callback then self.callback()end end
        state.timers[#state.timers+1]=timer;return timer
    end
    runtime.new_pipe = function()
        if opts.pipe_fail_at == #state.pipes + 1 then error("pipe allocation failed") end
        local pipe = { closing = false, close_calls = 0, holders = 0 }
        function pipe:read_stop() end
        function pipe:is_closing() return self.closing end
        function pipe:close() self.closing = true; self.close_calls = self.close_calls + 1 end
        table.insert(state.pipes, pipe)
        return pipe
    end
    local next_pid = 4241
    local function add_process(spawn_opts, on_exit, pgid, stdout, stderr)
        next_pid = next_pid + 1
        local pid = opts.reuse_pid and 4242 or next_pid
        local handle = { closing = false }
        function handle:is_closing() return self.closing end
        function handle:close() self.closing = true end
        local process = { pid = pid, pgid = pgid or 0, cwd = spawn_opts.cwd, args = vim.deepcopy(spawn_opts.args or {}),
            handle = handle, stdout = stdout, stderr = stderr, on_exit = on_exit, probe = "alive", ignores = {} }
        stdout.holders = stdout.holders + 1; stderr.holders = stderr.holders + 1
        local function release(pipe, stream)
            pipe.holders = pipe.holders - 1
            if opts.pipes_follow_holders and pipe.holders == 0 and pipe.reader then pipe.reader(nil, nil) end
        end
        function process:exit(code, signal)
            if self.exited then return end
            self.exited = true
            self.probe = "missing"
            if self.on_exit then self.on_exit(code or 0, signal or 0) end
            release(self.stdout, "stdout"); release(self.stderr, "stderr")
        end
        function process:emit(stream, data, err) self[stream].reader(err, data) end
        function process:finish(code, signal)
            self:exit(code, signal)
            if not opts.pipes_follow_holders then
                self:emit("stdout", nil)
                self:emit("stderr", nil)
            end
        end
        --- A grandchild in this process's group, holding the same pipes.
        function process:fork()
            return add_process({ args = {} }, nil, self.pgid, self.stdout, self.stderr)
        end
        state.processes[pid] = process
        return process, handle
    end
    runtime.spawn = function(_cmd, spawn_opts, on_exit)
        state.spawn_calls = state.spawn_calls + 1
        state.spawn_options[#state.spawn_options + 1] = vim.deepcopy(spawn_opts)
        if opts.spawn_throw then error("spawn exploded") end
        if opts.spawn_error then return nil, opts.spawn_error end
        local stdout, stderr = spawn_opts.stdio[2], spawn_opts.stdio[3]
        stdout.stream, stderr.stream = "stdout", "stderr"
        local process, handle = add_process(spawn_opts, on_exit, nil, stdout, stderr)
        if spawn_opts.detached == true then process.pgid = process.pid end
        state.on_exit, state.handle = on_exit, handle -- original single-process fixture API
        if opts.exit_during_spawn then process:exit() end
        return handle, process.pid
    end
    runtime.read_start = function(pipe, reader)
        local stream = pipe.stream
        if opts[stream .. "_start_throw"] then error(stream .. " start exploded") end
        if opts[stream .. "_start_reject"] then return false, stream .. " start rejected" end
        pipe.reader = reader
        if opts.eof_during_read_start then reader(nil, nil) end
        return 0
    end
    local function deliver(process, signal)
        if signal ~= 0 and not process.exited and not process.ignores[signal] then process:exit(0, signal) end
    end
    -- A scripted observation ("unknown", "missing", "throw", or a number) as
    -- kill's return values; "alive" or nil is not scripted.
    local function scripted(value)
        if value == "throw" then error("probe/signal exploded") end
        if value == "unknown" then return true, nil, "EPERM", "EPERM" end
        if value == "missing" then return true, nil, "ESRCH", "ESRCH" end
        if type(value) == "number" then return true, value end
        return false
    end
    runtime.kill = function(pid, signal)
        -- kill(0) signals the caller's own group, which is Neovim's: never right.
        if pid == 0 then error("signalled Neovim's own process group") end
        if pid < 0 then
            local leader = state.processes[-pid]
            local hit, result, detail, code = scripted(signal ~= 0 and leader and leader.signal_result)
            if hit then return result, detail, code end
            local members = {}
            for _, process in pairs(state.processes) do
                if process.pgid == -pid and not process.exited then members[#members + 1] = process end
            end
            if #members == 0 then return nil, "ESRCH", "ESRCH" end
            if signal == 0 then return 0 end
            table.sort(members, function(a, b) return a.pid < b.pid end)
            for _, process in ipairs(members) do
                table.insert(state.signals, { pid = process.pid, signal = signal, group = true })
            end
            for _, process in ipairs(members) do deliver(process, signal) end
            return 0
        end
        local process = state.processes[pid]
        if not process then return nil, "ESRCH", "ESRCH" end
        local hit, result, detail, code = scripted(signal == 0 and process.probe or process.signal_result)
        if hit then return result, detail, code end
        -- `state.signals` lists the signals the kernel accepted, on both paths.
        if signal ~= 0 then table.insert(state.signals, { pid = pid, signal = signal }) end
        if signal ~= 0 and opts.finish_on_signal and not process.ignores[signal] then process:finish(0, signal) end
        return 0
    end
    return runtime, state
end
return M
