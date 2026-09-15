-- Stateful libuv seam. Each spawn owns pipes and an exit callback independently.
local M = {}
function M.new(opts)
    opts = opts or {}
    local state = { pipes = {}, processes = {}, spawn_calls = 0, signals = {}, timers = {} }
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
        local pipe = { closing = false, close_calls = 0 }
        function pipe:read_stop() end
        function pipe:is_closing() return self.closing end
        function pipe:close() self.closing = true; self.close_calls = self.close_calls + 1 end
        table.insert(state.pipes, pipe)
        return pipe
    end
    runtime.spawn = function(_cmd, spawn_opts, on_exit)
        state.spawn_calls = state.spawn_calls + 1
        if opts.spawn_throw then error("spawn exploded") end
        if opts.spawn_error then return nil, opts.spawn_error end
        local pid = opts.reuse_pid and 4242 or 4241 + state.spawn_calls
        local handle = { closing = false }
        function handle:is_closing() return self.closing end
        function handle:close() self.closing = true end
        local process = { pid = pid, cwd = spawn_opts.cwd, args = vim.deepcopy(spawn_opts.args), handle = handle, stdout = spawn_opts.stdio[2],
            stderr = spawn_opts.stdio[3], on_exit = on_exit, probe = "alive" }
        process.stdout.stream, process.stderr.stream = "stdout", "stderr"
        function process:exit(code, signal)
            self.probe = "missing"
            self.on_exit(code or 0, signal or 0)
        end
        function process:emit(stream, data, err) self[stream].reader(err, data) end
        function process:finish(code, signal)
            self:exit(code, signal)
            self:emit("stdout", nil)
            self:emit("stderr", nil)
        end
        state.processes[pid] = process
        state.on_exit, state.handle = on_exit, handle -- original single-process fixture API
        if opts.exit_during_spawn then process:exit() end
        return handle, pid
    end
    runtime.read_start = function(pipe, reader)
        local stream = pipe.stream
        if opts[stream .. "_start_throw"] then error(stream .. " start exploded") end
        if opts[stream .. "_start_reject"] then return false, stream .. " start rejected" end
        pipe.reader = reader
        if opts.eof_during_read_start then reader(nil, nil) end
        return 0
    end
    runtime.kill = function(pid, signal)
        local process = state.processes[pid]
        if signal ~= 0 then table.insert(state.signals, { pid = pid, signal = signal }) end
        local observation = "missing"
        if process then observation = signal == 0 and process.probe or (process.signal_result or "alive") end
        if observation == "throw" then error("probe/signal exploded") end
        if observation == "unknown" then return nil, "EPERM", "EPERM" end
        if observation == "missing" then return nil, "ESRCH", "ESRCH" end
        if type(observation) == "number" then return observation end
        if signal ~= 0 and opts.finish_on_signal then process:finish(0, signal) end
        return 0
    end
    return runtime, state
end
return M
