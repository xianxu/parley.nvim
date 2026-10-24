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

--- How long an effect already under way gets before its reply counts as
--- lost: three submit deadlines (#359). A rename's file has already moved and
--- a send may already be delivered, so waiting costs nothing; killing early
--- only turns a delivered effect into an unknown one (#400).
--- @return number
function M.lost_ms()
    return 3 * M.config_ms("agentic_submit_timeout_ms")
end

--- The deadline a request gets when its caller names none (#382). A rename
--- gets M.lost_ms(), native or journaled through document_move alike.
--- @param operation string
--- @return number
function M.default_deadline_ms(operation)
    return operation == "rename" and M.lost_ms() or M.config_ms("agentic_submit_timeout_ms")
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

local function enqueue(argv, witness, callback, options, classify, invalid, joined)
    options = options or {}
    witness = vim.deepcopy(witness or {})
    local uv = vim.uv or vim.loop
    local absolute_deadline = options.absolute_deadline_ms
    local join_child = joined or absolute_deadline ~= nil
    local item = { callback = callback, done = false, running = false, queued_at = uv.hrtime() }
    local function absolute_expired()
        return absolute_deadline ~= nil and uv.hrtime() / 1e6 >= absolute_deadline
    end
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
        local result = unavailable("request canceled; mutation outcome may be unknown")
        if join_child and item.running then
            item.failure = result
            if item.child then pcall(item.child.kill, item.child, 9) end
        else
            if item.child then pcall(item.child.kill, item.child, 15) end
            finish(result)
        end
    end
    -- Retirement may cancel queued intent, but an admitted publication must
    -- retain its observer so an exact late acknowledgment can be cleaned up.
    function item.cancel_unstarted()
        if item.done or item.running then return false end
        item.cancel()
        return true
    end
    if invalid then finish(unavailable(invalid)); return item end
    if absolute_deadline ~= nil and (type(absolute_deadline) ~= 'number'
        or absolute_deadline ~= absolute_deadline or math.abs(absolute_deadline) == math.huge) then
        finish(unavailable('invalid absolute registry deadline')); return item
    end
    -- An absolute_deadline_ms is a shared uv.hrtime()/1e6 budget, including
    -- queue time. Without it, the deadline bounds lifetime from spawn (#382), as the
    -- header says: time spent queued behind MAX_ACTIVE others is not Couch
    -- being slow, and a request that never started has no unknown outcome.
    -- The queue itself is bounded by MAX_QUEUE.
    local deadline_ms = options.timeout_ms
    local function deadline_result()
        return unavailable(absolute_deadline ~= nil
            and 'Couch registry absolute deadline exceeded; mutation outcome may be unknown'
            or ('Couch registry deadline exceeded after %d ms; mutation outcome may be unknown'):format(deadline_ms))
    end
    local function expire()
        if item.done then return end
        local result = deadline_result()
        if join_child and item.running then
            item.failure = result
            if item.child then pcall(item.child.kill, item.child, 9) end
        else
            if item.child then pcall(item.child.kill, item.child, 15) end
            finish(result)
        end
    end
    local function arm_deadline(ms)
        item.timer = uv.new_timer()
        require('parley.helper').start_deadline(item.timer, ms, vim.schedule_wrap(expire))
    end
    local function arm_absolute_deadline()
        item.timer = uv.new_timer()
        require('parley.helper').start_absolute_deadline(item.timer, absolute_deadline, vim.schedule_wrap(expire))
    end
    function item.start()
        if item.done then return end
        if absolute_expired() then expire(); return end
        item.running = true
        item.started_at = uv.hrtime()
        active = active + 1
        local process_options = { env = options.env, clear_env = options.clear_env, timeout = false, stdin = options.stdin }
        if joined then
            item.output, item.output_size = {}, 0
            local function stream(error, chunk)
                if item.done then return end
                if error then item.failure = unavailable("editor endpoint reply read failed") end
                if chunk then
                    item.output_size = item.output_size + #chunk
                    if item.output_size <= M.EDITOR_REPLY_BYTES then item.output[#item.output + 1] = chunk
                    else item.failure = unavailable("editor endpoint reply exceeds 1 MiB") end
                end
                if item.failure then
                    vim.schedule(function()
                        if not item.done and item.child then pcall(item.child.kill, item.child, 9) end
                    end)
                end
            end
            process_options.stdout = stream
            -- stderr is diagnostic only, but must not be collected unboundedly.
            process_options.stderr = function(error, chunk)
                if error or (chunk and #chunk + (item.stderr_size or 0) > M.EDITOR_REPLY_BYTES) then
                    stream(error or "oversized stderr", nil)
                elseif chunk then item.stderr_size = (item.stderr_size or 0) + #chunk end
            end
        end
        item.child = couch.run(argv, function(obj)
            if item.done then return end
            if absolute_expired() and not item.failure then item.failure = deadline_result() end
            local result = item.failure or classify(obj, item)
            finish(result)
        end, process_options)
        if item.done then return end
        if absolute_deadline == nil then arm_deadline(deadline_ms) end
    end
    if #queue >= MAX_QUEUE and active >= MAX_ACTIVE then
        finish(unavailable("registry request queue full")); return item
    end
    handles[item] = true
    if absolute_deadline ~= nil then
        if absolute_expired() then expire(); return item end
        arm_absolute_deadline()
    end
    queue[#queue + 1] = item
    pump()
    return item
end

function M.request(operation, args, witness, callback, options)
    options = vim.tbl_extend("force", {}, options or {})
    args = vim.deepcopy(args or {})
    local function refuse(reason) return enqueue(nil, witness, callback, options, nil, reason) end
    local shapes = { lookup = 1, register = 2, rename = 2, forget = 1, round = 1 }
    if not shapes[operation] or #args ~= shapes[operation] then return refuse("invalid registry operation") end
    for _, arg in ipairs(args) do
        if type(arg) ~= "string" or arg == "" or arg:find("%z") then return refuse("invalid registry argument") end
    end
    if args[1]:sub(1, 1) ~= "/" or (operation == "rename" and args[2]:sub(1, 1) ~= "/") then
        return refuse("registry path must be absolute")
    end
    local argv = { options.binary or "couch", "--session-sync", operation, args[1] }
    if operation == "register" then vim.list_extend(argv, { "--owner", args[2] }) end
    if operation == "rename" then argv[#argv + 1] = args[2] end
    argv[#argv + 1] = "--json"
    options.timeout_ms = options.timeout_ms or M.default_deadline_ms(operation)
    return enqueue(argv, witness, callback, options, function(obj)
        local ok, data = pcall(vim.json.decode, obj.stdout or "")
        local result = operation == "round" and classify_round(ok and data or nil)
            or model.classify_reply(operation, obj.code, ok and data or nil, vim.NIL)
        if result.kind == "registered" then
            local expected = operation == "rename" and args[2] or args[1]
            local uv = vim.uv or vim.loop
            local canonical = uv.fs_realpath(expected) or vim.fs.normalize(expected)
            if result.registration.File ~= canonical then result = unavailable("registry path mismatch") end
        end
        if result.kind ~= "registered" and result.kind ~= "absent" and result.kind ~= "round" then
            result.exit, result.stderr = obj.code, (obj.stderr or ""):sub(1, 400)
        end
        return result
    end)
end

M.EDITOR_TIMEOUT_MS = 3000
M.EDITOR_REPLY_BYTES = 1024 * 1024

--- Editor discovery/publication uses the same four-child/64-queued boundary.
--- Cancellation and expiry deliver only after the owned child has been reaped.
--- options.absolute_deadline_ms includes queue time and is never reset at spawn.
function M.editor(operation, payload, witness, callback, options)
    options = vim.tbl_extend("force", {}, options or {})
    local protocol = require("parley.remote_session_model")
    local prepared, err = protocol.prepare_request(operation, payload)
    if not prepared then return enqueue(nil, witness, callback, options, nil, err) end
    local argv = { options.binary or "couch" }
    vim.list_extend(argv, prepared.args)
    options.stdin = prepared.stdin
    options.timeout_ms = options.timeout_ms or M.EDITOR_TIMEOUT_MS
    return enqueue(argv, witness, callback, options, function(obj, item)
        local ok, decoded = pcall(vim.json.decode, table.concat(item.output))
        local result = protocol.classify_reply(operation, obj.code, ok and decoded or nil, prepared.expected, vim.NIL)
        if result.kind == "unavailable" and not result.error then result.error = "unconfirmed editor endpoint reply" end
        return result
    end, nil, true)
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
