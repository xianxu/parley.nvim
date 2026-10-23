-- The one way a spec drives a child nvim (#401). Every request is bounded: a
-- child that never answers is killed by pid and the request fails naming its
-- method, before the spec runner's idle kill ends the spec with no cause.
-- tests/arch/embedded_rpc_spec.lua refuses a raw vim.rpcrequest elsewhere.
local uv = vim.uv or vim.loop

local M = {}

-- A spec may set this to shorten the bound; nil derives it (M.request_ms).
M.REQUEST_MS = nil

--- A request's bound: half the spec's idle budget, which spec_runner passes
--- load-scaled as PARLEY_SPEC_IDLE_MS (its DEFAULT_TIMEOUT when absent). Half
--- leaves the rest of the budget for the case's other work, so a wedged child
--- is named before the runner kills the spec.
--- @return integer
function M.request_ms()
    if M.REQUEST_MS then return M.REQUEST_MS end
    local idle = tonumber(vim.env.PARLEY_SPEC_IDLE_MS) or require("tests.helpers.spec_runner").DEFAULT_TIMEOUT
    return math.floor(idle / 2)
end

local Child = {}
Child.__index = Child

--- Bound all following requests by one case deadline; it cannot be restarted.
function Child:begin_case(name, budget_ms)
    assert(not self.case, "the child already has a case deadline")
    assert(type(name) == "string" and name ~= "", "a case needs a name")
    assert(type(budget_ms) == "number" and budget_ms >= 1 and budget_ms < math.huge,
        "a case needs a finite positive millisecond budget")
    local started = uv.hrtime()
    self.case = { name = name, started = started, deadline = started + budget_ms * 1e6, budget_ms = budget_ms }
end

local function case_diagnostic(child, method, ms, now, state)
    local case = child.case
    return ("case=%s; method=%s; elapsed_ms=%d; case_budget_ms=%d; request_budget_ms=%d; "
        .. "editor=%s; current-mode=unknown; pid=%d; channel=%d; last-checkpoint-stderr=%s")
        :format(case.name, method, math.floor((now - case.started) / 1e6), case.budget_ms, ms,
            state, child.pid, child.channel, child.stderr_tail)
end

--- Send one request; raise if the child doesn't answer within M.request_ms().
--- The deadline kills the child from a libuv callback, where jobstop isn't
--- allowed; the pending request then fails on the closed channel.
function Child:request(method, ...)
    local ms, fired, diagnostic = M.request_ms(), false, nil
    if self.case then
        local now = uv.hrtime()
        local remaining = math.ceil((self.case.deadline - now) / 1e6)
        if remaining <= 0 then
            error(case_diagnostic(self, method, 0, now, "request-not-sent"), 2)
        end
        ms = math.min(ms, remaining)
    end
    local timer = uv.new_timer()
    timer:start(ms, 0, function()
        fired = true
        if self.case then
            -- Only fast-safe observations, captured before the exact child kill.
            -- A busy editor cannot supply a current mode; stderr is last-known.
            local now = uv.hrtime()
            local alive, probe_error = uv.kill(self.pid, 0)
            diagnostic = case_diagnostic(self, method, ms, now, "request-pending")
                .. ("; job_alive_before_kill=%s; signal0=%s"):format(
                    alive ~= nil and "true" or "unknown", tostring(probe_error or alive))
        end
        uv.kill(self.pid, "sigkill")
    end)
    local ok, result = pcall(vim.rpcrequest, self.channel, method, ...)
    timer:stop()
    timer:close()
    if fired then
        local message = ("embedded nvim did not answer %s within %d ms; killed pid %d"):format(method, ms, self.pid)
        error(diagnostic and message .. "; " .. diagnostic or message, 2)
    end
    if not ok then error(result, 2) end
    return result
end

--- Run Lua in the child; `...` reaches it as its varargs.
function Child:exec(code, ...)
    return self:request("nvim_exec_lua", code, { ... })
end

--- Type keys into the child.
function Child:input(keys)
    return self:request("nvim_input", keys)
end

--- End the child and reap it.
function Child:stop()
    pcall(vim.fn.jobstop, self.channel)
    vim.fn.jobwait({ self.channel }, 1000)
end

--- Start a clean embedded nvim with this repository on its runtimepath.
--- `options.ui = { width, height }` attaches a UI; `options.rtp = "prepend"`
--- puts the repository first (default: appended).
function M.start(options)
    options = options or {}
    local child = setmetatable({ stderr_tail = "" }, Child)
    local channel = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, {
        rpc = true,
        on_stderr = function(_, data)
            child.stderr_tail = (child.stderr_tail .. table.concat(data, "\n")):sub(-4096)
        end,
    })
    assert(channel > 0, "could not start an embedded nvim")
    child.channel, child.pid = channel, vim.fn.jobpid(channel)
    -- A failed setup still ends the child: the caller never got it to stop.
    local ok, err = pcall(function()
        if options.ui then
            child:request("nvim_ui_attach", options.ui[1], options.ui[2], { rgb = true })
        end
        child:exec(options.rtp == "prepend" and "vim.opt.rtp:prepend(...)" or "vim.opt.rtp:append(...)", vim.fn.getcwd())
    end)
    if not ok then
        child:stop()
        error(err, 2)
    end
    return child
end

return M
