-- Most specs retain Plenary's default as a no-completed-case budget.
-- These real 50,000-row corpora keep their larger bootstrap budget.
local M={}
local Deadline = require("tests.helpers.spec_deadline")
local Progress = require("tests.helpers.spec_progress")
local Jobs = require("tests.helpers.spec_jobs")
local Identity = require("tests.helpers.process_identity")
local Processes = require("tests.helpers.test_processes")
local function absolute(path)
    return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))
end
local extended={
    [absolute('tests/integration/document_fold_batches_spec.lua')]=true,
    [absolute('tests/unit/document_semantic_spec.lua')]=true,
}
function M.options(path)
    if extended[absolute(path)] then return {timeout=180000,sequential=true} end
end
-- Every child loads tests/minimal_init.vim, so the harness-only guards there
-- (a per-process query dir, the wordless-refusal watch) cover every spec rather
-- than the ones that remember to ask (#261 M5 review BR-71).
local INIT='tests/minimal_init.vim'
-- Keep the quiet-machine hang budget and bounded load scaling. It applies to
-- completed-case inactivity, the runner's one bound (#446).
local DEFAULT_TIMEOUT=50000 -- plenary.test_harness's own default
M.DEFAULT_TIMEOUT=DEFAULT_TIMEOUT
-- How long a terminated spec's process group gets before SIGKILL. A spinning
-- nvim never returns to its loop, so it never acts on SIGTERM (#402).
M.GRACE_MS=1000
M.load_factor = Deadline.load_factor

-- This headless adapter owns one child and its timer through observed exit.
-- Tests can shorten the base, control load/CPUs and collect output; run() uses the
-- shared defaults and the same child/bootstrap/assertion path.
function M.execute(path, options)
    options = options or {}
    local uv = vim.uv or vim.loop
    local function now() return uv.hrtime() / 1e6 end
    local base = options.base_ms or (M.options(path) or {}).timeout or DEFAULT_TIMEOUT
    local load1 = options.load1 or uv.loadavg()
    local ncpu = options.ncpu or uv.available_parallelism()
    local state = Deadline.new(base, load1, ncpu, now())
    local output = options.output or function(stream, text)
        local target = stream == "stderr" and io.stderr or io.stdout
        target:write(text); target:flush()
    end
    -- The token is private to this invocation; nested runners cannot refresh it.
    local token = "PARLEY_CASE_" .. tostring(uv.hrtime())
    local reader = Progress.new(token, function(text) output("stdout", text) end, function(sequence)
        state = Deadline.transition(state, { kind = "progress", sequence = sequence, now_ms = now() })
    end)
    local command = { vim.v.progpath, "--headless", "--noplugin", "-n", "-i", "NONE", "-u", INIT,
        "-c", ("lua require('tests.helpers.spec_child').run(%q, %q)"):format(absolute(path), token) }
    local result, child, child_start
    local timer = uv.new_timer()
    -- End everything the spec child started (#402). It leads its own process
    -- group, which its vim.system and uv.spawn children inherit; each jobstart
    -- child leads a group of its own and is recorded in `jobs` (spec_jobs).
    local context = vim.env.PARLEY_TEST_PROCESS_DIR
    local jobs, scope_err
    if context then jobs, scope_err = Processes.scope(context)
    else
        jobs = vim.fn.tempname() .. "-spec-jobs"
        vim.fn.mkdir(jobs, "p", 448)
    end
    if not jobs then timer:close(); return { code = 125, reason = scope_err, completed = 0, reaped = false } end
    local ticket, ticket_err = Processes.prepare(jobs)
    if not ticket then timer:close(); return { code = 125, reason = ticket_err, completed = 0, reaped = false } end
    local function log(message) output("stderr", message) end
    -- The spec child's group, under the same identity guard as its jobs.
    local function signal_group(signal)
        if child and child.pid and child_start then
            local ok, reason = Jobs.may_signal(child.pid, child_start, Identity.start_time(child.pid))
            if ok then Jobs.signal_group(child.pid, signal) else log("spec child not signalled: " .. reason .. "\n") end
        end
        Jobs.signal(jobs, signal, log)
    end
    -- TERM, a grace, then KILL for whatever remains (a spinning nvim never acts
    -- on TERM), even when the leader itself exited on TERM. `wait` is the one
    -- difference: uv.sleep in a signal callback, vim.wait on the main loop.
    local function escalate(wait)
        signal_group("sigterm")
        wait(M.GRACE_MS)
        signal_group("sigkill")
    end
    local ok, err = pcall(function()
        child = vim.system(command, {
            detach = true,
            -- The child's own idle budget, load-scaled, so the helpers inside it
            -- can bound their waits below it (tests/helpers/embedded_nvim.lua, #401).
            env = { PARLEY_SPEC_IDLE_MS = tostring(math.floor(Deadline.snapshot(state).idle_ms)), [Jobs.ENV] = jobs },
            stdout = function(_, data) if data then reader.feed(data) end end,
            stderr = function(_, data) if data then output("stderr", data) end end,
        }, function(exited)
            state = Deadline.transition(state, { kind = "exit", now_ms = now() })
            result = exited
        end)
        child_start = Identity.start_time(child.pid)
        local recorded, why = Processes.complete(ticket, child.pid)
        if not recorded then error("spec child birth unconfirmed: " .. tostring(why)) end
    end)
    if not ok then
        timer:close()
        if child then
            child:kill("sigkill")
            local ended = child:wait(3000)
            if ended and ended.code then Processes.abort(ticket) end
        else Processes.abort(ticket) end
        output("stderr", "cannot start spec child: " .. tostring(err) .. "\n")
        return { code = 125, reason = tostring(err), completed = 0, reaped = false }
    end
    -- A runner told to stop takes its spec's group with it; nvim's own
    -- deadly-signal handling then ends the runner.
    local watchers = {}
    for _, name in ipairs({ "sigterm", "sigint" }) do
        local watcher = uv.new_signal()
        watcher:start(name, function() escalate(uv.sleep) end)
        watchers[#watchers + 1] = watcher
    end
    timer:start(0, 25, function()
        if result then return end
        state = Deadline.transition(state, { kind = "tick", now_ms = now() })
        if Deadline.snapshot(state).status ~= "running" then
            timer:stop()
            signal_group("sigterm")
        end
    end)
    -- The tick timer ends a stall, so this wait ends on an event, not a ceiling.
    local function settled() return result ~= nil or Deadline.snapshot(state).status ~= "running" end
    repeat vim.wait(math.ceil(Deadline.snapshot(state).idle_ms), settled, 10) until settled()
    local expiring = Deadline.snapshot(state).status ~= "completed"
    if not result or expiring then
        escalate(function(ms) vim.wait(ms, function() return result ~= nil end, 10) end)
        vim.wait(3000, function() return result ~= nil end, 10) -- drain: the leader's exit after KILL
    end
    for _, watcher in ipairs(watchers) do watcher:stop(); watcher:close() end
    timer:stop(); timer:close()
    local cleanup = Processes.reconcile(jobs)
    for _, message in ipairs(cleanup.messages) do log(message .. "\n") end
    if cleanup.ok then
        local pruned, why = Processes.prune(jobs)
        if not pruned then cleanup.ok = false; log("cannot retire spec scope: " .. tostring(why) .. "\n") end
    end
    reader.finish()
    local snapshot = Deadline.snapshot(state)
    local expired = snapshot.status == "stalled"
    if expired then
        output("stderr", ("DEADLINE: %s stalled after %d completed case(s): none completed within the %.0fms idle budget\n")
            :format(path, snapshot.sequence, snapshot.idle_ms))
    end
    local code = result and result.code or 125
    if (not cleanup.ok or cleanup.leaked) and code == 0 then code = 125 end
    if result and (result.signal or 0) > 0 then code = 128 + result.signal end
    return { code = expired and 124 or code,
        signal = result and result.signal, reason = expired and snapshot.status or nil,
        completed = snapshot.sequence, reaped = result ~= nil and cleanup.ok, pid = child.pid }
end

function M.run(path)
    if vim.env.PARLEY_TEST_JITSTAT=='1' then require('tests.helpers.jit_watch').silence() end
    local result = M.execute(path)
    if not result.reaped then io.stderr:write("spec process cleanup was not confirmed: " .. tostring(result.pid) .. "\n") end
    return vim.cmd(result.code == 0 and "0cq" or "1cq")
end
return M
