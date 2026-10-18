-- PURE: canonical section routing and the local adapter's edit permission.
local M = {}
local values = require('parley.skills.review.collaboration_value')
local frontmatter = require('parley.frontmatter')
-- The collaboration modes, in the order the skill lists them. The one source:
-- the resolver's set and frontmatter typeahead (#384) both read it.
M.modes = { 'discussion', 'collaboration', 'chat' }
local known = {}
for _, mode in ipairs(M.modes) do known[mode] = true end
local function trim(s)
    local first, last = 1, #s
    while first <= last and s:sub(first, first):match('%s') do first = first + 1 end
    while last >= first and s:sub(last, last):match('%s') do last = last - 1 end
    return s:sub(first, last)
end
function M.normalize(s)
    s = trim(s):lower():gsub('%s+', ' ')
    -- Find the opening parenthesis of one balanced suffix from the end.
    -- Searching forward for %b() retries every unmatched opening parenthesis.
    if s:sub(-1) == ')' then
        local depth = 1
        for i = #s - 1, 1, -1 do
            local c = s:sub(i, i)
            if c == ')' then depth = depth + 1
            elseif c == '(' then
                depth = depth - 1
                if depth == 0 then return trim(s:sub(1, i - 1)) end
            end
        end
    end
    return s
end
local function bad_mode(name)
    return 'unknown collaboration mode ' .. tostring(name) .. '; choose ' .. table.concat(M.modes, ', ')
end
local function fence(line)
    local indent, run, tail = line:match('^( *)([`~]+)(.*)$')
    if not run or #indent > 3 or #run < 3 then return end
    if not run:match('^`+$') and not run:match('^~+$') then return end
    return run:sub(1, 1), #run, tail
end

local function heading(line)
    local indent, hashes, tail = line:match('^( *)(#+)(.*)$')
    if not hashes or #indent > 3 or #hashes > 6 then return end
    if tail ~= '' and not tail:sub(1, 1):match('%s') then return end
    local title = trim(tail)
    local last = #title
    while last > 0 and title:sub(last, last) == '#' do last = last - 1 end
    if last > 0 and last < #title and title:sub(last, last):match('%s') then
        title = trim(title:sub(1, last))
    end
    return #hashes, title
end

function M.resolve(lines)
    local value, err = values.parse(lines)
    if err then return nil, err end
    local default, assigned, labels = 'discussion', {}, {}
    if type(value) == 'string' then default = value
    elseif value ~= nil then
        if type(value) ~= 'table' then return nil, 'collaboration-mode must be a scalar or mapping' end
        default = value.default or default
        for mode, names in pairs(value) do
            if mode ~= 'default' then
                if not known[mode] then return nil, bad_mode(mode) end
                if type(names) ~= 'table' then return nil, 'collaboration-mode.' .. mode .. ' must be a heading list' end
                for _, name in ipairs(names) do
                    local key = type(name) == 'string' and M.normalize(name)
                    if not key or key == '' then
                        return nil, 'collaboration-mode heading names must be nonempty strings'
                    end
                    if assigned[key] and assigned[key] ~= mode then
                        return nil, 'heading ' .. name .. ' is assigned to both ' .. assigned[key] .. ' and ' .. mode
                    end
                    assigned[key], labels[key] = mode, name
                end
            end
        end
    end
    if not known[default] then return nil, bad_mode(default) end
    local fm = frontmatter.parse(lines)
    local plan = { mode_by_row = {}, chat = {}, warnings = {}, editable = false, discussion = false, protected = {} }
    local stack, matched, chat_seen, offset = {}, {}, {}, 1
    local delimiter, length
    for row, line in ipairs(lines) do
        local mode, label = 'frontmatter', 'document'
        if not fm or row > fm.close then
            local char, count, tail = fence(line)
            if delimiter then
                if char == delimiter and count >= length and trim(tail) == '' then delimiter = nil end
            elseif char and (char == '~' or not tail:find('`', 1, true)) then
                delimiter, length = char, count
            else
                local level, title = heading(line)
                if level then
                    while #stack > 0 and stack[#stack].level >= level do table.remove(stack) end
                    local parent = stack[#stack]
                    local key = M.normalize(title)
                    if assigned[key] then matched[key] = true end
                    stack[#stack + 1] = { level = level, mode = assigned[key] or (parent and parent.mode) or default,
                        label = assigned[key] and title or (parent and parent.label) or title }
                end
            end
            local section = stack[#stack]
            mode, label = section and section.mode or default, section and section.label or label
            plan.mode_by_row[row] = mode
            if line:match('%S') then
                if mode == 'chat' then
                    if not chat_seen[label] then plan.chat[#plan.chat + 1], chat_seen[label] = label, true end
                else
                    plan.editable = true
                    if mode == 'discussion' then plan.discussion = true end
                end
            end
        end
        if mode == 'chat' or mode == 'frontmatter' then
            plan.protected[#plan.protected + 1] = { first = math.max(1, offset - 1), last = offset + #line }
        end
        offset = offset + #line + 1
    end
    local missing = {}
    for key in pairs(assigned) do if not matched[key] then missing[#missing + 1] = key end end
    table.sort(missing)
    for _, key in ipairs(missing) do
        plan.warnings[#plan.warnings + 1] = "collaboration-mode." .. assigned[key] .. " names '" .. labels[key] .. "', which matches no heading"
    end
    return plan
end

function M.eligible(plan, markers)
    local out = {}
    for _, marker in ipairs(markers) do
        local allowed = true
        local last = marker.line + 1 + select(2, (marker.raw or ''):gsub('\n', ''))
        for row = marker.line + 1, last do
            if not plan.mode_by_row[row] or plan.mode_by_row[row] == 'chat' then allowed = false end
        end
        if allowed then
            out[#out + 1] = marker
        end
    end
    return out
end

-- Called with the invocation snapshot, before executing any proposed batch.
function M.validate_edits(snapshot, edits)
    local lines = {}
    for line in (snapshot .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = line end
    local plan, err = M.resolve(lines)
    if not plan then return err end
    if type(edits) ~= 'table' then return 'invalid local review edits' end
    local positioned = {}
    for _, edit in ipairs(edits) do
        local old = type(edit) == 'table' and edit.old_string
        if type(old) == 'string' and old ~= '' then
            local first, last = snapshot:find(old, 1, true)
            if not first or snapshot:find(old, first + 1, true) then
                return 'local review edits must match unique text in the invocation snapshot'
            end
            for _, span in ipairs(plan.protected) do
                if first <= span.last and last >= span.first then
                    return 'local review cannot edit chat sections or collaboration frontmatter; the hub agent answers chat'
                end
            end
            for _, span in ipairs(positioned) do
                if first <= span.last and last >= span.first then return 'local review edits must not overlap' end
            end
            positioned[#positioned + 1] = { first = first, last = last }
        end
    end
end
return M
