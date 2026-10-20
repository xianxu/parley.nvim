-- The one way a spec drives a child nvim (#401). Every request is bounded: a
-- child that never answers is killed by pid and the request fails naming its
-- method, well before the harness's idle kill (180 s) ends the spec with no
-- cause. tests/arch/embedded_rpc_spec.lua refuses a raw vim.rpcrequest elsewhere.
local arrival = require("tests.helpers.arrival")
local uv = vim.uv or vim.loop

local M = {}

-- A legitimate request stretched by the harness's load factor (at most 4)
-- still fits; a wedged child is named long before the idle kill.
M.REQUEST_MS = 4 * arrival.MS

local Child = {}
Child.__index = Child

--- Send one request; raise if the child doesn't answer within M.REQUEST_MS.
--- The deadline kills the child from a libuv callback, where jobstop isn't
--- allowed; the pending request then fails on the closed channel.
function Child:request(method, ...)
    local ms, fired = M.REQUEST_MS, false
    local timer = uv.new_timer()
    timer:start(ms, 0, function()
        fired = true
        uv.kill(self.pid, "sigkill")
    end)
    local ok, result = pcall(vim.rpcrequest, self.channel, method, ...)
    timer:stop()
    timer:close()
    if fired then
        error(("embedded nvim did not answer %s within %d ms; killed pid %d"):format(method, ms, self.pid), 2)
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
    local channel = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, { rpc = true })
    assert(channel > 0, "could not start an embedded nvim")
    local child = setmetatable({ channel = channel, pid = vim.fn.jobpid(channel) }, Child)
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
