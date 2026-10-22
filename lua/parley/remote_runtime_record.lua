-- Computational ownership-record codec and cleanup decision. The IO shell
-- supplies lstat/process facts and executes a reclaim plan under its guard.
local M = {}
local MAX_BYTES, MAX_SOCKETS = 32768, 256

local function positive_integer(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end
local function dense_length(value)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return nil end
    local count = #value
    for key in pairs(value) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > count then return nil end
    end
    for index = 1, count do if value[index] == nil then return nil end end
    return count
end
local function nonempty(value)
    return type(value) == 'string' and #value > 0 and not value:find('%z')
end
local function valid(record)
    if type(record) ~= 'table' or record.Version ~= 1
        or type(record.EditorIncarnation) ~= 'string' or #record.EditorIncarnation ~= 32
        or not record.EditorIncarnation:match('^[0-9a-f]+$')
        or not positive_integer(record.PID) or not nonempty(record.Started) then return false end
    local directory = record.Directory
    if type(directory) ~= 'table' or type(directory.Name) ~= 'string'
        or not directory.Name:match('^e%-%w+$')
        or not positive_integer(directory.Device) or not positive_integer(directory.Inode) then return false end
    local count = dense_length(record.Sockets)
    if count == nil or count > MAX_SOCKETS then return false end
    local names = {}
    for _, socket in ipairs(record.Sockets) do
        if type(socket) ~= 'table' or type(socket.Name) ~= 'string'
            or not socket.Name:match('^s[1-9][0-9]*$') or names[socket.Name]
            or (socket.State ~= 'reserved' and socket.State ~= 'listening') then return false end
        names[socket.Name] = true
        if socket.State == 'listening' and (not positive_integer(socket.Device) or not positive_integer(socket.Inode)) then
            return false
        end
        if socket.Device ~= nil and not positive_integer(socket.Device) then return false end
        if socket.Inode ~= nil and not positive_integer(socket.Inode) then return false end
    end
    return true
end

-- Native JSON decoding supplies values, but intentionally accepts duplicate
-- members. Walk the source grammar separately, decoding each object key before
-- comparing it, so escaped spellings cannot overwrite ownership evidence.
local function unique_members(bytes)
    local offset, length = 1, #bytes
    local function whitespace()
        while offset <= length and bytes:sub(offset, offset):match('[ \t\r\n]') do offset = offset + 1 end
    end
    local function string_token()
        if bytes:sub(offset, offset) ~= '"' then error('expected JSON string') end
        local start = offset
        offset = offset + 1
        while offset <= length do
            local char = bytes:sub(offset, offset)
            offset = offset + 1
            if char == '"' then return bytes:sub(start, offset - 1) end
            if char == '\\' then offset = offset + 1 end
        end
        error('unterminated JSON string')
    end
    local function number_token(token)
        local position = 1
        if token:sub(position, position) == '-' then position = position + 1 end
        if token:sub(position, position) == '0' then position = position + 1
        elseif token:sub(position, position):match('[1-9]') then
            repeat position = position + 1 until not token:sub(position, position):match('[0-9]')
        else return false end
        if token:sub(position, position) == '.' then
            position = position + 1
            local start = position
            while token:sub(position, position):match('[0-9]') do position = position + 1 end
            if position == start then return false end
        end
        if token:sub(position, position):match('[eE]') then
            position = position + 1
            if token:sub(position, position):match('[+-]') then position = position + 1 end
            local start = position
            while token:sub(position, position):match('[0-9]') do position = position + 1 end
            if position == start then return false end
        end
        return position == #token + 1
    end
    local value
    value = function()
        whitespace()
        local char = bytes:sub(offset, offset)
        if char == '{' then
            offset = offset + 1
            whitespace()
            local seen = {}
            if bytes:sub(offset, offset) == '}' then offset = offset + 1; return end
            while true do
                whitespace()
                local key = vim.json.decode(string_token())
                if seen[key] then error('duplicate JSON member') end
                seen[key] = true
                whitespace()
                if bytes:sub(offset, offset) ~= ':' then error('expected JSON colon') end
                offset = offset + 1
                value()
                whitespace()
                char = bytes:sub(offset, offset)
                offset = offset + 1
                if char == '}' then return end
                if char ~= ',' then error('expected JSON object delimiter') end
            end
        elseif char == '[' then
            offset = offset + 1
            whitespace()
            if bytes:sub(offset, offset) == ']' then offset = offset + 1; return end
            while true do
                value()
                whitespace()
                char = bytes:sub(offset, offset)
                offset = offset + 1
                if char == ']' then return end
                if char ~= ',' then error('expected JSON array delimiter') end
            end
        elseif char == '"' then
            string_token()
        else
            local start = offset
            while offset <= length and not bytes:sub(offset, offset):match('[ \t\r\n,%]}]') do offset = offset + 1 end
            local token = bytes:sub(start, offset - 1)
            if token ~= 'true' and token ~= 'false' and token ~= 'null' and not number_token(token) then
                error('invalid JSON scalar')
            end
        end
    end
    value()
    whitespace()
    if offset ~= length + 1 then error('trailing JSON input') end
end

-- Returns a fresh validated record or nil,error. Unknown JSON fields survive.
function M.decode(bytes)
    if type(bytes) ~= 'string' or #bytes == 0 or #bytes > MAX_BYTES then return nil, 'invalid marker byte length' end
    local decoded, record = pcall(vim.json.decode, bytes)
    if not decoded then return nil, 'invalid marker JSON' end
    local unique = pcall(unique_members, bytes)
    if not unique then return nil, 'invalid or duplicate marker JSON members' end
    if not valid(record) then return nil, 'invalid marker ownership fields' end
    return record
end

-- Validates without mutating its input; no serialization of unsafe known fields.
function M.encode(record)
    if not valid(record) then return nil, 'invalid marker ownership fields' end
    local encoded, bytes = pcall(vim.json.encode, record)
    if not encoded then return nil, 'invalid marker JSON values' end
    -- Check the same byte and JSON constraints applied to persisted markers.
    local checked, err = M.decode(bytes)
    if not checked then return nil, err end
    return bytes
end

-- facts = {uid, directory={type,uid,mode,dev,ino}, process={kind},
-- entries={leaf,...}, sockets={[leaf]={type,uid,dev,ino}}}. An omitted socket
-- is absent only when the complete entries census also omits its name.
function M.cleanup(record, facts)
    local function retain(reason) return { kind = 'retain', reason = reason } end
    if not valid(record) then return retain('invalid marker') end
    if type(facts) ~= 'table' or type(facts.uid) ~= 'number' or facts.uid < 0 or facts.uid % 1 ~= 0 then
        return retain('unknown uid')
    end
    local directory = facts.directory
    if type(directory) ~= 'table' or directory.type ~= 'directory' or directory.uid ~= facts.uid
        or directory.mode ~= 16832 or directory.dev ~= record.Directory.Device or directory.ino ~= record.Directory.Inode then
        return retain('unproven private directory')
    end
    if type(facts.process) ~= 'table' or facts.process.kind ~= 'dead' then return retain('owner not proven dead') end
    if dense_length(facts.entries) == nil or type(facts.sockets) ~= 'table' then return retain('incomplete entry census') end
    local declared, present = {}, {}
    for _, socket in ipairs(record.Sockets) do declared[socket.Name] = socket end
    for _, name in ipairs(facts.entries) do
        if type(name) ~= 'string' or present[name] or (name ~= 'owner.json' and not declared[name]) then
            return retain('foreign or duplicate entry')
        end
        present[name] = true
    end
    for name in pairs(facts.sockets) do
        if not declared[name] or not present[name] then return retain('inconsistent socket observations') end
    end
    local sockets = {}
    for _, socket in ipairs(record.Sockets) do
        if present[socket.Name] then
            local observed = facts.sockets[socket.Name]
            if type(observed) ~= 'table' or observed.type ~= 'socket' or observed.uid ~= facts.uid
                or not positive_integer(observed.dev) or not positive_integer(observed.ino) then
                return retain('unproven owned socket')
            end
            if socket.State == 'listening' and (observed.dev ~= socket.Device or observed.ino ~= socket.Inode) then
                return retain('replaced socket')
            end
            sockets[#sockets + 1] = socket.Name
        end
    end
    return { kind = 'reclaim', sockets = sockets, marker = 'owner.json', rmdir_empty = true }
end

return M
