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
local owned=setmetatable({},{__mode='k'})

local function join_and_cleanup(child)
    local state=owned[child]
    -- Conformance borrows request() for a socket channel. That channel is not
    -- the native child job: only the original Child may join and clean it.
    if not state then return nil,'unowned RPC channel; original Child owner must join and clean its fixture' end
    local status=vim.fn.jobwait({child.channel},1000)[1]
    -- -3 can follow an already-delivered native on_exit. Without that proof,
    -- an invalid/unknown job is no permission to remove its runtime files.
    if type(status)=='number' and status>=0 then state.exited=true end
    if not state.exited then
        return nil,'embedded child exit unconfirmed; retained fixture '..(state.parent or '(bootstrap incomplete)')
    end
    if state.cleanup then return state.cleanup() end
    return true
end

--- Send one request; raise if the child doesn't answer within M.request_ms().
--- The deadline kills the child from a libuv callback, where jobstop isn't
--- allowed; the pending request then fails on the closed channel.
function Child:request(method, ...)
    local ms, fired = M.request_ms(), false
    local timer = uv.new_timer()
    timer:start(ms, 0, function()
        fired = true
        uv.kill(self.pid, "sigkill")
    end)
    local ok, result = pcall(vim.rpcrequest, self.channel, method, ...)
    timer:stop()
    timer:close()
    if fired then
        local joined,err=join_and_cleanup(self)
        error(("embedded nvim did not answer %s within %d ms; killed pid %d"):format(method, ms, self.pid)
            ..(not joined and '; '..tostring(err) or ''), 2)
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

--- Send an RPC notification: there is no reply to wait for. Retained ownership
--- still requires the caller/runner to join the child, including detached probes.
function Child:notify(method, ...)
    return vim.rpcnotify(self.channel, method, ...)
end

--- End the child and reap it.
function Child:stop()
    pcall(vim.fn.jobstop, self.channel)
    return join_and_cleanup(self)
end

--- Start a clean embedded nvim with this repository on its runtimepath.
--- `options.ui = { width, height }` attaches a UI; `options.rtp = "prepend"`
--- puts the repository first (default: appended).
function M.start(options)
    options = options or {}
    local state={exited=false}
    local channel = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" },
        { rpc = true, detach = options.detach, on_exit=function() state.exited=true end })
    assert(channel > 0, "could not start an embedded nvim")
    local child = setmetatable({ channel = channel, pid = vim.fn.jobpid(channel) }, Child)
    owned[child]=state
    -- A failed setup still ends the child: the caller never got it to stop.
    local ok, err = pcall(function()
        if options.ui then
            child:request("nvim_ui_attach", options.ui[1], options.ui[2], { rgb = true })
        end
        child:exec(options.rtp == "prepend" and "vim.opt.rtp:prepend(...)" or "vim.opt.rtp:append(...)", vim.fn.getcwd())
        child:exec([[local root = ...; package.path = root .. '/?.lua;' .. package.path
            require('tests.helpers.spec_jobs').install()]], vim.fn.getcwd())
        local snapshot=child:exec([[local fixture=require('tests.helpers.remote_runtime_fixture').install()
            require('tests.helpers.discovery_registry_fixture').install(fixture.parent..'/discovery')
            require('tests.helpers.exit_with_parent').install(nil,function() assert(fixture.cleanup()) end)
            return {parent=fixture.parent,witness=fixture.witness()}]])
        local parent,witness=snapshot.parent,vim.deepcopy(snapshot.witness)
        state.parent=parent
        state.cleanup=function() return require('tests.helpers.remote_runtime_fixture').cleanup(parent,witness) end
    end)
    if not ok then
        child:stop()
        error(err, 2)
    end
    return child
end

return M
