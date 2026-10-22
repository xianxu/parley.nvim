-- Retained birth evidence (#416). Only native PID/start equality authorizes
-- exact signals; pending/corrupt evidence survives for independent census.
local uv = vim.uv or vim.loop
local Model = require("tests.helpers.test_process_model")
local Identity = require("tests.helpers.process_identity")
local M = { MAX_RECORDS = 4096, MAX_BYTES = 256, MAX_SCOPES = 64, MAX_RUNS = 256 }
local cursors = {}

local function entries(dir, limit)
    local stat, err, code = uv.fs_lstat(dir)
    if not stat then return code == "ENOENT" and {} or nil, err end
    if stat.type ~= "directory" or stat.uid ~= uv.getuid() or bit.band(stat.mode, 18) ~= 0 then
        return nil, "unowned registry directory: " .. dir
    end
    local scan, why = uv.fs_scandir(dir)
    if not scan then return nil, why end
    local result = {}
    while true do
        local name, kind = uv.fs_scandir_next(scan)
        if not name then return result end
        result[#result + 1] = { name = name, kind = kind, path = dir .. "/" .. name }
        if #result > limit then return nil, "registry entry limit reached: " .. dir end
    end
end

local function read_file(path, limit)
    local stat = uv.fs_lstat(path)
    if not stat or stat.type ~= "file" or stat.uid ~= uv.getuid() or stat.size > limit
        or bit.band(stat.mode, 18) ~= 0 then
        return nil, "invalid or oversized registry file: " .. path
    end
    local fd, err = uv.fs_open(path, "r", 0)
    if not fd then return nil, err end
    local body, why = uv.fs_read(fd, limit + 1, 0)
    uv.fs_close(fd)
    if not body or #body > limit then return nil, why or "registry file grew beyond limit" end
    return body
end

-- JSON's native decoder validates grammar. This token walk additionally rejects
-- duplicate object keys (including escaped aliases) at every nesting depth.
local function decode(body)
    local ok, value = pcall(vim.json.decode, body)
    if not ok or type(value) ~= "table" then return nil, "invalid registry JSON" end
    local stack, i = {}, 1
    while i <= #body do
        local ch = body:sub(i, i)
        if ch == '"' then
            local last = i + 1
            while last <= #body do
                local next_ch = body:sub(last, last)
                if next_ch == "\\" then last = last + 2
                elseif next_ch == '"' then break
                else last = last + 1 end
            end
            if body:sub(last + 1):match("^%s*:") then
                local key = vim.json.decode(body:sub(i, last))
                local keys = stack[#stack]
                if type(keys) ~= "table" or keys[key] then return nil, "duplicate registry JSON key" end
                keys[key] = true
            end
            i = last
        elseif ch == "{" then stack[#stack + 1] = {}
        elseif ch == "[" then stack[#stack + 1] = false
        elseif ch == "}" or ch == "]" then stack[#stack] = nil end
        i = i + 1
    end
    if value.version ~= 1 or (value.state ~= "born" and value.state ~= "pending") then
        return nil, "unsupported registry record"
    end
    if value.state == "born" and Model.classify(value, { kind = "absent" }) ~= "gone" then
        return nil, "invalid birth record"
    end
    return value
end

local function write(fd, body)
    local n, err = uv.fs_write(fd, body, 0)
    if n ~= #body then return nil, err or "short registry write" end
    return uv.fs_fsync(fd)
end

--- A durable reservation exists BEFORE the caller creates any process.
function M.prepare(dir)
    for _ = 1, M.MAX_RECORDS do
        local slot = (cursors[dir] or 0) % M.MAX_RECORDS + 1
        cursors[dir] = slot
        local path = dir .. "/" .. slot .. ".json"
        local fd, err, code = uv.fs_open(path, "wx", 384)
        if fd then
            local ok, why = write(fd, '{"version":1,"state":"pending"}')
            uv.fs_close(fd)
            return ok and path or nil, why -- a failed/partial ticket remains unknown
        end
        if code ~= "EEXIST" then return nil, err end
    end
    return nil, "registry child limit reached"
end

--- Atomic pending -> born. The original ticket remains if publication fails.
function M.complete(ticket, pid, observe)
    local body, err = read_file(ticket, M.MAX_BYTES)
    if not body then return nil, err end
    local value, why = decode(body)
    if not value or value.state ~= "pending" then return nil, why or "ticket is not pending" end
    local observation = (observe or Identity.observe)(pid)
    if not observation or observation.kind ~= "live" then return nil, "child birth identity unavailable" end
    value.state, value.pid, value.start = "born", pid, observation.start
    if Model.classify(value, observation) ~= "live" then return nil, "invalid child birth identity" end
    body = vim.json.encode(value)
    if #body > M.MAX_BYTES then return nil, "birth record exceeds limit" end
    local temporary = ticket .. ".new"
    local fd, open_err = uv.fs_open(temporary, "wx", 384)
    if not fd then return nil, open_err end
    local ok, write_err = write(fd, body)
    uv.fs_close(fd)
    if not ok then return nil, write_err end
    return uv.fs_rename(temporary, ticket)
end

--- Only the still-owning caller with a failed spawn / joined child may abort.
function M.abort(ticket) return uv.fs_unlink(ticket) end

--- Read once; malformed evidence never becomes an empty ledger. Legacy jobs
--- remain immutable until ALL their original incarnations have ended.
function M.read(dir)
    local files, err = entries(dir, M.MAX_RECORDS * 2)
    if not files then return nil, err end
    local records = {}
    for _, file in ipairs(files) do
        local legacy = file.name == "jobs"
        if not legacy and not file.name:match("^%d+%.json$") then
            return nil, "unresolved registry artifact: " .. file.path
        end
        local body, why = read_file(file.path, legacy and 1048576 or M.MAX_BYTES)
        if not body then return nil, why end
        if legacy then
            if body == "" or body:sub(-1) ~= "\n" then return nil, "incomplete legacy registry" end
            for line in body:gmatch("([^\n]*)\n") do
                local pid, start = line:match("^(%d+) (%d+%.?%d*)$")
                local record = { version = 1, state = "born", pid = tonumber(pid), start = start }
                if Model.classify(record, { kind = "absent" }) ~= "gone" then return nil, "malformed legacy registry" end
                records[#records + 1] = { path = file.path, record = record, body = body }
            end
        else
            local value, decode_err = decode(body)
            if not value then return nil, decode_err .. ": " .. file.path end
            records[#records + 1] = { path = file.path, record = value, body = body }
        end
        if #records > M.MAX_RECORDS then return nil, "registry child limit exceeded" end
    end
    return records
end

local function settle(records, options)
    options = options or {}
    local observe = options.observe or Identity.observe
    local signal = options.signal or function(pid, name) return uv.kill(pid, name) end
    local wait = options.wait or function(ms) uv.sleep(ms) end
    local now = options.now or function() return uv.hrtime() / 1e6 end
    local result = { ok = true, leaked = false, unknown = false, messages = {} }
    local function log(message) result.messages[#result.messages + 1] = message end
    local function inspect(entry)
        local record = entry.record
        local status, reason = Model.classify(record, record.pid and observe(record.pid) or nil)
        entry.status = status
        if status == "unknown" then
            result.ok, result.unknown = false, true
            log("unknown: " .. entry.path .. ": " .. tostring(reason))
        end
        return status
    end
    for _, entry in ipairs(records) do
        if inspect(entry) == "live" then
            result.leaked = true
            log("surviving owned child pid=" .. entry.record.pid .. " start=" .. entry.record.start)
        end
    end
    if options.report_only then
        result.ok = result.ok and not result.leaked
        return result
    end
    for _, name in ipairs({ "sigterm", "sigkill" }) do
        local active = false
        for _, entry in ipairs(records) do
            if entry.status == "live" and inspect(entry) == "live" then
                active = true
                local ok, err = signal(entry.record.pid, name)
                if not ok then log("signal refused: " .. tostring(err)) end
            end
        end
        if active then
            local deadline = now() + (name == "sigterm" and (options.grace_ms or 1000) or (options.join_ms or 3000))
            repeat
                active = false
                for _, entry in ipairs(records) do
                    if entry.status == "live" and inspect(entry) == "live" then active = true end
                end
                if not active or now() >= deadline then break end
                wait(math.min(20, deadline - now()))
            until false
        end
    end
    local paths = {}
    for _, entry in ipairs(records) do
        if paths[entry.path] == nil then paths[entry.path] = { gone = true, body = entry.body } end
        if entry.status ~= "gone" then
            paths[entry.path].gone, result.ok = false, false
            if entry.status == "live" then log("still surviving pid=" .. entry.record.pid) end
        end
    end
    for path, state in pairs(paths) do
        if state.gone then
            local current = read_file(path, 1048576)
            local ok, err
            if current == state.body then ok, err = uv.fs_unlink(path)
            else err = "birth evidence changed during observation" end
            if not ok then result.ok, result.unknown = false, true; log("cannot retire " .. path .. ": " .. tostring(err)) end
        end
    end
    return result
end

function M.reconcile(dir, options)
    local records, err = M.read(dir)
    if not records then return { ok = false, unknown = true, messages = { "unknown: " .. tostring(err) } } end
    local result = settle(records, options)
    -- Another recorded child may have started a job during its termination.
    local remaining, why = M.read(dir)
    if not remaining or #remaining > 0 then
        result.ok = false
        if not remaining then result.unknown = true; result.messages[#result.messages + 1] = tostring(why) end
    end
    return result
end

--- Allocate a private scope under the run context, bounded even on failures.
function M.scope(base)
    local scopes, err = entries(base, M.MAX_SCOPES - 1)
    if not scopes then return nil, err end
    return uv.fs_mkdtemp(base .. "/spec-XXXXXX")
end

function M.prune(dir)
    local ok, err = uv.fs_rmdir(dir)
    if ok then cursors[dir] = nil end
    return ok, err
end

--- One snapshot and bounded reconciliation for the entire retained tree.
local function collect(base)
    local runs, err = entries(base, M.MAX_RUNS)
    if not runs then return nil, err end
    local records, scopes = {}, {}
    for _, run in ipairs(runs) do
        local children, why = entries(run.path, M.MAX_SCOPES)
        if not children then return nil, why end
        for _, scope in ipairs(children) do
            local values, read_err = M.read(scope.path)
            if not values then return nil, read_err end
            vim.list_extend(records, values)
            scopes[#scopes + 1] = scope.path
        end
    end
    return records, scopes, runs
end

function M.census(base, current, options)
    local records, err = collect(base)
    if not records then return { ok = false, unknown = true, messages = { tostring(err) } } end
    local result = settle(records, options)
    if options and options.report_only then return result end
    -- Re-read the whole tree: a terminating child may have opened a new scope,
    -- not merely added another record in one of the original directories.
    local left, scopes, runs = collect(base)
    if not left then
        result.ok, result.unknown = false, true
        result.messages[#result.messages + 1] = tostring(scopes)
        return result
    end
    if #left > 0 then result.ok, result.unknown = false, true end
    local occupied = {}
    for _, entry in ipairs(left) do occupied[vim.fs.dirname(entry.path)] = true end
    for _, dir in ipairs(scopes) do
        if not occupied[dir] then
            local ok, why = M.prune(dir)
            if not ok then
                result.ok, result.unknown = false, true
                result.messages[#result.messages + 1] = "cannot prune " .. dir .. ": " .. tostring(why)
            end
        end
    end
    for _, run in ipairs(runs) do if run.path ~= current then uv.fs_rmdir(run.path) end end
    return result
end

return M
