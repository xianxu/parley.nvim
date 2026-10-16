-- Typed registry boundary. Absence requires a positive null witness; failures
-- retain uncertainty. The queue and child lifetime are bounded independently.
local M = {}
local couch = require("parley.couch")
local model = require("parley.document_session")
local active, queue, handles = 0, {}, {}
local MAX_ACTIVE, MAX_QUEUE = 4, 64
local pump

local function unavailable(message)
    return { kind = "unavailable", error = message }
end

function M.request(operation, args, witness, callback, options)
    options = options or {}
    args = vim.deepcopy(args or {})
    witness = vim.deepcopy(witness or {})
    local item = { callback = callback, done = false, running = false }
    local function finish(result)
        if item.done then return end
        item.done = true
        if item.timer then item.timer:stop(); item.timer:close(); item.timer = nil end
        if item.running then active = active - 1 end
        handles[item] = nil
        result.witness = witness
        vim.schedule(function() callback(result) end)
        pump()
    end
    function item.cancel()
        if item.done then return end
        if item.child then pcall(item.child.kill, item.child, 15) end
        finish(unavailable("request canceled; mutation outcome may be unknown"))
    end
    local shapes = { lookup = 1, register = 2, rename = 2, forget = 1 }
    if not shapes[operation] or #args ~= shapes[operation] then
        finish(unavailable("invalid registry operation")); return item
    end
    for _, arg in ipairs(args) do
        if type(arg) ~= "string" or arg == "" or arg:find("%z") then
            finish(unavailable("invalid registry argument")); return item
        end
    end
    if args[1]:sub(1, 1) ~= "/" or (operation == "rename" and args[2]:sub(1, 1) ~= "/") then
        finish(unavailable("registry path must be absolute")); return item
    end
    local argv = { options.binary or "couch", "--session-sync", operation, args[1] }
    if operation == "register" then vim.list_extend(argv, { "--owner", args[2] }) end
    if operation == "rename" then argv[#argv + 1] = args[2] end
    argv[#argv + 1] = "--json"
    function item.start()
        if item.done then return end
        item.running = true
        active = active + 1
        item.child = couch.run(argv, function(obj)
            if item.done then return end
            local ok, data = pcall(vim.json.decode, obj.stdout or "")
            local result = model.classify_reply(operation, obj.code, ok and data or nil, vim.NIL)
            if result.kind == "registered" then
                local expected = operation == "rename" and args[2] or args[1]
                local canonical = (vim.uv or vim.loop).fs_realpath(expected) or vim.fs.normalize(expected)
                if result.registration.File ~= canonical then result = unavailable("registry path mismatch") end
            end
            finish(result)
        end, options.env and { env = options.env } or nil)
    end
    if #queue >= MAX_QUEUE and active >= MAX_ACTIVE then
        finish(unavailable("registry request queue full")); return item
    end
    handles[item] = true
    item.timer = (vim.uv or vim.loop).new_timer()
    item.timer:start(options.timeout_ms or 2500, 0, vim.schedule_wrap(function()
        if item.child then pcall(item.child.kill, item.child, 15) end
        finish(unavailable("Couch registry deadline exceeded; mutation outcome may be unknown"))
    end))
    queue[#queue + 1] = item
    pump()
    return item
end

pump = function()
    while active < MAX_ACTIVE and #queue > 0 do
        local item = table.remove(queue, 1)
        if not item.done then item.start() end
    end
end

function M.shutdown()
    local pending = {}
    for item in pairs(handles) do pending[#pending + 1] = item end
    for _, item in ipairs(pending) do item.cancel() end
    queue = {}
end

return M
