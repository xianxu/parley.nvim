-- Typed registry boundary. Absence requires a positive null witness; failures
-- retain uncertainty. The queue and child lifetime are bounded independently.
local M = {}
local couch = require("parley.couch")
local model = require("parley.document_session")
local active, queue, handles = 0, {}, {}
local MAX_ACTIVE, MAX_QUEUE = 4, 64
local pump

--- A positive millisecond setting: the user's config, else the shipped default.
--- One owner for agentic deadlines (#382); agentic_document reads it too.
--- @param key string
--- @return number
function M.config_ms(key)
    local value = (require("parley").config or {})[key]
    if type(value) == "number" and value > 0 then return value end
    return require("parley.config")[key]
end

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
    -- A caller that names no deadline gets the product's (#382). It used to be
    -- a 2.5 s literal: under suite load the couch spawn missed it, and
    -- document_move's journaled renames, which name none, ran on it too.
    item.timer:start(options.timeout_ms or M.config_ms("agentic_submit_timeout_ms"), 0, vim.schedule_wrap(function()
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
