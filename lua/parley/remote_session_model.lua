-- Pure endpoint protocol and attachment lifetime. No editor or process access.
-- classify_reply returns {kind, code, binding? , results?}; malformed input is
-- unavailable. Objects expose :dispatch(event) -> effects array, :snapshot(),
-- and :endpoint(query). Every outward table is a private copy.
local M = {}
local MAX_ATTACH_ID = '18446744073709551615'

local function copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function attach_id(value)
    return type(value) == 'string' and value:match('^[1-9][0-9]*$') ~= nil
        and (#value < #MAX_ATTACH_ID or (#value == #MAX_ATTACH_ID and value <= MAX_ATTACH_ID))
end

-- Decimal carry deliberately never converts the counter to a Lua number.
function M.next_attach_id(previous)
    if previous == nil then return '1' end
    if not attach_id(previous) then return nil, 'invalid AttachID' end
    if previous == MAX_ATTACH_ID then return nil, 'AttachID exhausted' end
    local digits, carry = {}, true
    for index = #previous, 1, -1 do
        local digit = previous:sub(index, index)
        if carry then
            if digit == '9' then digit = '0'
            else digit = string.char(digit:byte() + 1); carry = false end
        end
        digits[index] = digit
    end
    return (carry and '1' or '') .. table.concat(digits)
end

local function positive_integer(value)
    return type(value) == 'number' and value > 0 and value < math.huge and value % 1 == 0
end
local function hex_id(value)
    return type(value) == 'string' and #value == 32 and value:match('^[0-9a-f]+$') ~= nil
end
local function nonempty(value)
    return type(value) == 'string' and #value > 0 and not value:find('%z')
end
local function absolute(value)
    if not nonempty(value) or value:find('[\r\n]') or value:sub(1, 1) ~= '/' then return false end
    -- Physical paths are supplied by the shell; reject lexical aliases here.
    if value:find('//', 1, true) or value:match('/%.%.?(/?)$') then return false end
    for segment in value:gmatch('[^/]+') do
        if segment == '.' or segment == '..' then return false end
    end
    return value == '/' or value:sub(-1) ~= '/'
end
local validators = {
    Namespace = absolute, DocumentID = hex_id, EditorIncarnation = hex_id,
    AttachID = attach_id, PID = positive_integer, ProcessIdentity = nonempty,
    Socket = absolute, Buffer = positive_integer,
    Mode = function(value) return value == 'desktop' or value == 'headless' end,
    BindingGeneration = hex_id, File = absolute,
}
local function valid_binding(value, expected)
    if type(value) ~= 'table' then return false end
    for field, validate in pairs(validators) do
        if not validate(value[field]) then return false end
        if expected[field] ~= nil and expected[field] ~= value[field] then return false end
    end
    return true
end
local function dense_length(value)
    if type(value) ~= 'table' then return nil end
    local length = #value
    for key in pairs(value) do
        if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > length then return nil end
    end
    for index = 1, length do if value[index] == nil then return nil end end
    return length
end
local request_fields = {
    register = { 'Version', 'Namespace', 'DocumentID', 'EditorIncarnation', 'AttachID',
        'PID', 'Socket', 'Buffer', 'Mode' },
    lookup = { 'Namespace', 'DocumentID' },
    unregister = { 'Version', 'Namespace', 'EditorIncarnation', 'PID', 'Entries' },
}
local entry_fields = { 'DocumentID', 'AttachID', 'BindingGeneration' }

local function request_shape(value, fields, optional)
    if type(value) ~= 'table' or getmetatable(value) ~= nil then return false end
    local allowed = {}
    for _, field in ipairs(fields) do
        allowed[field] = true
        if value[field] == nil then return false end
    end
    if optional then allowed[optional] = true end
    for field in pairs(value) do if not allowed[field] then return false end end
    return true
end

-- Validate and serialize before either async transport or bounded exit IO.
-- This checks canonical spelling only; physical namespace/socket authority is
-- verified by the producer, never inferred through filesystem IO in this model.
function M.prepare_request(operation, payload)
    local fields = request_fields[operation]
    local function invalid(reason) return nil, 'invalid endpoint request: ' .. reason end
    if not fields then return invalid('unknown operation') end
    if not request_shape(payload, fields, operation == 'unregister' and 'ProcessIdentity' or nil) then
        return invalid('unexpected or missing fields')
    end
    for _, field in ipairs(fields) do
        if field == 'Version' then
            if payload[field] ~= 1 then return invalid('Version must be 1') end
        elseif field ~= 'Entries' and not validators[field](payload[field]) then
            return invalid(field)
        end
    end
    if operation == 'unregister' then
        if payload.ProcessIdentity ~= nil and not nonempty(payload.ProcessIdentity) then
            return invalid('ProcessIdentity')
        end
        local length = dense_length(payload.Entries)
        if not length or length < 1 or length > 256 then return invalid('batch size or shape') end
        local seen = {}
        for _, entry in ipairs(payload.Entries) do
            if not request_shape(entry, entry_fields) then return invalid('entry fields') end
            for _, field in ipairs(entry_fields) do
                if not validators[field](entry[field]) then return invalid('entry ' .. field) end
            end
            if seen[entry.DocumentID] then return invalid('duplicate DocumentID') end
            seen[entry.DocumentID] = true
        end
    end
    local args = { '--editor-endpoint', operation }
    local encoded
    if operation == 'lookup' then
        args[#args + 1], args[#args + 2] = '--namespace', payload.Namespace
        args[#args + 1], args[#args + 2] = '--document-id', payload.DocumentID
    else
        local ok
        ok, encoded = pcall(vim.json.encode, payload)
        if not ok then return invalid('JSON encoding') end
        local limit = operation == 'register' and 8192 or 262144
        if #encoded > limit then return invalid('encoded byte limit') end
    end
    args[#args + 1] = '--json'
    return { args = args, stdin = encoded, expected = copy(payload) }
end

local function same_entry(left, right)
    return type(left) == 'table' and type(right) == 'table'
        and hex_id(left.DocumentID) and attach_id(left.AttachID) and hex_id(left.BindingGeneration)
        and left.DocumentID == right.DocumentID and left.AttachID == right.AttachID
        and left.BindingGeneration == right.BindingGeneration
end
local function valid_results(results, expected)
    local count, wanted = dense_length(results), dense_length(expected.Entries)
    if count == nil or wanted == nil or count ~= wanted then return false end
    local matched = {}
    for _, row in ipairs(results) do
        if type(row) ~= 'table' or (row.Status ~= 'removed' and row.Status ~= 'stale' and row.Status ~= 'absent') then
            return false
        end
        local found
        for index, entry in ipairs(expected.Entries) do
            if same_entry(row, entry) then
                if found or matched[index] then return false end
                found = index
            end
        end
        if not found then return false end
        matched[found] = true
    end
    return true
end

-- expected is the supplied known tuple (register/lookup), or {Entries={...}}
-- (unregister). null_sentinel is the JSON decoder's explicit null value.
function M.classify_reply(operation, exit_code, decoded, expected, null_sentinel)
    local unavailable = { kind = 'unavailable' }
    if operation ~= 'register' and operation ~= 'lookup' and operation ~= 'unregister' then return unavailable end
    if type(decoded) ~= 'table' or decoded.Version ~= 1 or type(decoded.Code) ~= 'string'
        or type(decoded.Error) ~= 'string' then return unavailable end
    local code = decoded.Code
    if exit_code ~= 0 then
        local kinds = { [2] = { invalid = 'refused' }, [3] = { unavailable = 'unavailable' },
            [4] = { superseded = 'refused', stale = 'refused', conflict = 'refused',
                ['not-registered'] = 'refused', ['desktop-active'] = 'refused' },
            [5] = { uncertain = 'uncertain' } }
        local kind = kinds[exit_code] and kinds[exit_code][code]
        return kind and { kind = kind, code = code, error = decoded.Error } or unavailable
    end
    if code ~= 'ok' then return unavailable end
    expected = type(expected) == 'table' and expected or {}
    if operation == 'unregister' then
        if not valid_results(decoded.Results, expected) then return unavailable end
        return { kind = 'confirmed', code = code, results = copy(decoded.Results) }
    end
    if operation == 'lookup' and null_sentinel ~= nil and decoded.EditorEndpoint == null_sentinel then
        return { kind = 'absent', code = code }
    end
    if operation == 'register' and type(decoded.Changed) ~= 'boolean' then return unavailable end
    if not valid_binding(decoded.EditorEndpoint, expected) then return unavailable end
    return { kind = 'confirmed', code = code, binding = copy(decoded.EditorEndpoint) }
end

local context_fields = { 'Namespace', 'DocumentID', 'EditorIncarnation', 'AttachID', 'PID', 'Socket', 'Buffer', 'Mode', 'File' }
local pending_fields = {}
for _, field in ipairs(context_fields) do
    if field ~= 'Socket' then pending_fields[#pending_fields + 1] = field end
end
local query_fields = { 'Namespace', 'DocumentID', 'EditorIncarnation', 'AttachID', 'Buffer' }
local notice_fields = { 'Namespace', 'DocumentID', 'EditorIncarnation', 'AttachID', 'BindingGeneration' }
local function exact_fields(value, fields, expected)
    if type(value) ~= 'table' then return false end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    if count ~= #fields then return false end
    for _, field in ipairs(fields) do
        if not validators[field](value[field]) then return false end
        if expected[field] ~= nil and value[field] ~= expected[field] then return false end
    end
    return true
end

-- Validate before allocation with stage='pending' (Socket must be absent),
-- or after allocation with stage='listening'/nil (Socket is required). Both
-- stages use the same tuple field validators, including canonical File.
function M.validate_context(context, stage)
    if stage ~= nil and stage ~= 'pending' and stage ~= 'listening' then
        return nil, 'invalid attachment context stage'
    end
    local fields = stage == 'pending' and pending_fields or context_fields
    if not exact_fields(context, fields, {}) then return nil, 'invalid attachment context' end
    return true
end

-- context is an already allocated listening tuple. Events: publish/retry,
-- reply{witness,result}, superseded{notice}, detach/close. Effects always form
-- an array: register{request,witness}, unregister{request}, stop_listener, notify.
function M.new(context)
    local valid, err = M.validate_context(context)
    if not valid then return nil, err end
    local tuple = copy(context)
    local state = { phase = 'listening', context = tuple }
    local witness = 0
    local issued, completed, cleaned = {}, {}, {}
    local candidate, stopped, notified
    local object = {}

    local function stop(effects)
        if stopped then return end
        stopped = true
        effects[#effects + 1] = { kind = 'stop_listener' }
    end
    local function supersede(effects)
        state.phase = 'superseded'
        stop(effects)
        if not notified then
            notified = true
            effects[#effects + 1] = { kind = 'notify', reason = 'superseded' }
        end
    end
    local function cleanup(effects, binding)
        if cleaned[binding.BindingGeneration] then return end
        cleaned[binding.BindingGeneration] = true
        effects[#effects + 1] = { kind = 'unregister', request = {
            Version = 1, Namespace = binding.Namespace, EditorIncarnation = binding.EditorIncarnation,
            PID = binding.PID, Entries = { { DocumentID = binding.DocumentID,
                AttachID = binding.AttachID, BindingGeneration = binding.BindingGeneration } },
        } }
    end
    function object.snapshot(_) return copy(state) end
    function object.endpoint(_, query)
        if state.phase ~= 'listening' and state.phase ~= 'publishing'
            and state.phase ~= 'active' and state.phase ~= 'unconfirmed' then return nil end
        if not exact_fields(query, query_fields, tuple) then return nil end
        local endpoint = copy(query)
        endpoint.PID, endpoint.Socket, endpoint.File = tuple.PID, tuple.Socket, tuple.File
        return endpoint
    end
    function object.dispatch(_, event)
        local effects = {}
        if type(event) ~= 'table' then return effects end
        if event.type == 'publish' or event.type == 'retry' then
            if state.phase ~= 'listening' and state.phase ~= 'unconfirmed' then return effects end
            witness = witness + 1
            state.witness, state.phase = witness, 'publishing'
            issued[witness] = true
            local request = copy(tuple)
            request.File, request.Version = nil, 1
            effects[1] = { kind = 'register', request = request, witness = witness }
        elseif event.type == 'reply' then
            if not issued[event.witness] or completed[event.witness] then return effects end
            local result = event.result
            if type(result) ~= 'table' then result = { kind = 'unavailable' } end
            local owned = result.kind == 'confirmed' and valid_binding(result.binding, tuple)
            -- Transport validation lacks the pending canonical File. Store the
            -- owner's accepted outcome, never a confirmation it cannot own.
            if result.kind == 'confirmed' and not owned then
                result = { kind = 'uncertain', code = 'uncertain',
                    error = 'confirmed editor binding is malformed or does not match pending attachment' }
            end
            -- A stale request can prove exact ownership for cleanup, never activation.
            if event.witness ~= state.witness then
                if owned and state.phase == 'retired' then cleanup(effects, result.binding) end
                return copy(effects)
            end
            completed[event.witness] = true
            state.result = copy(result)
            if state.phase == 'retired' then
                if owned then cleanup(effects, result.binding) end
            elseif state.phase == 'publishing' then
                if owned then
                    state.binding = copy(result.binding)
                    if candidate == result.binding.BindingGeneration then supersede(effects)
                    else state.phase = 'active' end
                elseif result.kind == 'refused' then
                    if result.code == 'superseded' or result.code == 'stale' then supersede(effects)
                    else state.phase = 'unavailable'; stop(effects) end
                else
                    state.phase = 'unconfirmed'
                end
            end
        elseif event.type == 'superseded' then
            local value = event.notice
            if not exact_fields(value, notice_fields, tuple) then return effects end
            if state.phase == 'active' then
                if value.BindingGeneration == state.binding.BindingGeneration then supersede(effects) end
            elseif state.phase == 'listening' or state.phase == 'publishing' or state.phase == 'unconfirmed' then
                candidate = candidate or value.BindingGeneration
            end
        elseif event.type == 'detach' or event.type == 'close' then
            if state.phase == 'retired' then return effects end
            state.phase = 'retired'
            stop(effects)
            if state.binding then cleanup(effects, state.binding) end
        end
        return copy(effects)
    end
    return object
end

return M
