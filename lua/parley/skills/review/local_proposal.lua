-- Pure, invocation-bound local review admission. Semantic classifications come
-- from the agent; identity, complete coverage and protected bytes are checked here.
local M = {}

local function integer(n)
    return type(n) == 'number' and n >= 0 and n < math.huge and n % 1 == 0
end
local function array(t)
    if type(t) ~= 'table' then return false end
    local count = 0
    for k in pairs(t) do
        if not integer(k) or k < 1 or k > #t then return false end
        count = count + 1
    end
    return count == #t
end
local function identity(m)
    if type(m) ~= 'table' or not integer(m.line) or not integer(m.col)
        or type(m.raw) ~= 'string' or m.raw == '' then return nil end
    return m.line .. ':' .. m.col
end

-- Returns refusal, or nil plus a validated snapshot summary. The caller owns
-- all effects; a question-only summary must finish without dispatching a tool.
function M.validate(snapshot, edits, input, context)
    if type(snapshot) ~= 'string' or #snapshot > 1048576 or not array(edits)
        or #edits > 128 or #snapshot * #edits > 8388608 then
        return 'invalid or oversized local review proposal'
    end
    local asks = type(input) == 'table' and input.review_asks
    if not array(asks) then return 'local review requires review_asks classifications' end
    local starts, offset = {}, 1
    for line in (snapshot .. '\n'):gmatch('(.-)\n') do
        starts[#starts + 1] = {offset = offset, length = #line}
        offset = offset + #line + 1
    end
    local expected, remaining = {}, 0
    for _, marker in ipairs(context.markers or {}) do
        if marker.ready then
            local key = identity(marker)
            local row = key and starts[marker.line + 1]
            local at = row and row.offset + marker.col
            if not at or marker.col > row.length or snapshot:sub(at, at + #marker.raw - 1) ~= marker.raw
                or expected[key] then return 'invalid invocation marker identity' end
            expected[key] = {marker = marker, first = at, last = at + #marker.raw - 1}
            remaining = remaining + 1
        end
    end
    local protected, deferred, commands = {}, 0, 0
    for _, span in ipairs(context.protected or {}) do protected[#protected + 1] = span end
    for _, ask in ipairs(asks) do
        local key = identity(ask)
        local record = key and expected[key]
        if not record or record.marker.raw ~= ask.raw or (ask.kind ~= 'question' and ask.kind ~= 'command') then
            return 'local review classifications must cover exact ready markers once'
        end
        expected[key] = nil
        remaining = remaining - 1
        if ask.kind == 'question' then
            deferred = deferred + 1
            protected[#protected + 1] = record
        else commands = commands + 1 end
    end
    if remaining ~= 0 then return 'local review classifications are incomplete' end
    if #edits == 0 then
        if deferred == 0 or commands > 0 then return 'local review returned no command edits' end
        return nil, {deferred = deferred, noop = true, content = snapshot}
    end
    if commands == 0 then return 'local review cannot edit without a classified command' end
    for _, edit in ipairs(edits) do
        if type(edit) ~= 'table' or type(edit.old_string) ~= 'string' or edit.old_string == ''
            or type(edit.new_string) ~= 'string' or type(edit.explain) ~= 'string' then
            return 'invalid local review edit'
        end
    end
    -- The tool uses this same atomic matching/overlap transform (ARCH-DRY).
    local changed = require('parley.skill_edits').compute_edits(snapshot, edits)
    if not changed.ok then return changed.msg end
    for _, edit in ipairs(changed.applied) do
        local last = edit.pos + #edit.old_string - 1
        for _, span in ipairs(protected) do
            if edit.pos <= span.last and last >= span.first then
                return 'local review cannot edit deferred questions or operator-owned chat structure'
            end
        end
    end
    return nil, {deferred = deferred, noop = changed.content == snapshot, content = changed.content}
end
return M
