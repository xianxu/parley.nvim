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

--- The deadline a request gets when its caller names none (#382). A rename
--- gets three submit deadlines before its reply counts as lost: the file has
--- already moved, so waiting costs nothing (#359). That holds for the native
--- rename and for document_move's journaled ones alike.
--- @param operation string
--- @return number
function M.default_deadline_ms(operation)
    local submit = M.config_ms("agentic_submit_timeout_ms")
    return operation == "rename" and 3 * submit or submit
end

local function unavailable(message)
    return { kind = "unavailable", error = message }
end

-- A `round --json` reply (#383, pair#661): `round` with Couch's sidecar and
-- whether a submit came after it, `absent` with a positive null, else
-- unavailable. Not a registration, so model.classify_reply doesn't apply.
local function classify_round(data)
    if type(data) ~= "table" or data.Code ~= "ok" then
        local result = unavailable(type(data) == "table" and tostring(data.Error) or "malformed round reply")
        result.code = type(data) == "table" and data.Code or nil
        return result
    end
    if data.Round == vim.NIL then return { kind = "absent" } end
    if type(data.Round) ~= "table" then return unavailable("malformed round reply") end
    return { kind = "round", round = data.Round, cleared = data.Cleared == true }
end

function M.request(operation, args, witness, callback, options)
    options = options or {}
    args = vim.deepcopy(args or {})
    witness = vim.deepcopy(witness or {})
    local uv = vim.uv or vim.loop
    local item = { callback = callback, done = false, running = false, queued_at = uv.hrtime() }
    local function finish(result)
        if item.done then return end
        item.done = true
        if item.timer then item.timer:stop(); item.timer:close(); item.timer = nil end
        if item.running then active = active - 1 end
        handles[item] = nil
        result.witness = witness
        -- #382: how long it queued and ran, so a refusal names its cause.
        local now = uv.hrtime()
        result.queued_ms = math.floor(((item.started_at or now) - item.queued_at) / 1e6)
        if item.started_at then result.ran_ms = math.floor((now - item.started_at) / 1e6) end
        vim.schedule(function() callback(result) end)
        pump()
    end
    function item.cancel()
        if item.done then return end
        if item.child then pcall(item.child.kill, item.child, 15) end
        finish(unavailable("request canceled; mutation outcome may be unknown"))
    end
    local shapes = { lookup = 1, register = 2, rename = 2, forget = 1, round = 1 }
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
    -- The deadline bounds the child's lifetime, from spawn (#382), as the
    -- header says: time spent queued behind MAX_ACTIVE others is not Couch
    -- being slow, and a request that never started has no unknown outcome.
    -- The queue itself is bounded by MAX_QUEUE.
    local deadline_ms = options.timeout_ms or M.default_deadline_ms(operation)
    function item.start()
        if item.done then return end
        item.running = true
        item.started_at = uv.hrtime()
        active = active + 1
        item.child = couch.run(argv, function(obj)
            if item.done then return end
            local ok, data = pcall(vim.json.decode, obj.stdout or "")
            local result = operation == "round" and classify_round(ok and data or nil)
                or model.classify_reply(operation, obj.code, ok and data or nil, vim.NIL)
            if result.kind == "registered" then
                local expected = operation == "rename" and args[2] or args[1]
                local canonical = uv.fs_realpath(expected) or vim.fs.normalize(expected)
                if result.registration.File ~= canonical then result = unavailable("registry path mismatch") end
            end
            if result.kind ~= "registered" and result.kind ~= "absent" and result.kind ~= "round" then
                result.exit, result.stderr = obj.code, (obj.stderr or ""):sub(1, 400)
            end
            finish(result)
        end, { env = options.env, timeout = false })
        if item.done then return end
        item.timer = uv.new_timer()
        require("parley.helper").start_deadline(item.timer, deadline_ms, vim.schedule_wrap(function()
            if item.child then pcall(item.child.kill, item.child, 15) end
            finish(unavailable(("Couch registry deadline exceeded after %d ms; mutation outcome may be unknown")
                :format(deadline_ms)))
        end))
    end
    if #queue >= MAX_QUEUE and active >= MAX_ACTIVE then
        finish(unavailable("registry request queue full")); return item
    end
    handles[item] = true
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
