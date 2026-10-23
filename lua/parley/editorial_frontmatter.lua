-- Effective document settings and additive frontmatter projection. PURE.
-- The existing declaration scanner owns YAML boundaries; existing selectors
-- own processing names. No writer reserializes operator metadata.
local declarations = require('parley.skills.review.collaboration_value')
local collaboration = require('parley.skills.review.collaboration')
local instruction = require('parley.skills.review.instruction')
local frontmatter = require('parley.frontmatter')
local M = {}
local presentations = { highlight = true, direct = true, propose = true }
local relevant = { 'collaboration-mode', 'presentation-mode', 'presentation',
    'processing-mode', 'processing-instruction', 'process-instruction' }

local function scan(lines, keys)
    local parsed, err, problem = declarations.header(lines)
    if not parsed then return nil, err, problem end
    for _, key in ipairs(keys or relevant) do
        if parsed.fields[key] and #parsed.fields[key] > 1 then
            local row = parsed.fields[key][2].row
            return nil, 'frontmatter line ' .. row .. ': duplicate ' .. key .. ' field', { kind = 'invalid', row = row }
        end
    end
    return parsed
end

-- Eligibility is deliberately narrower than the existing legacy map parser.
-- Unknown flat metadata stays opaque; no convenience edit depends on proving
-- the contents of a nested/flow/block value.
local function representation(parsed)
    local legacy_map
    for _, entry in ipairs(parsed.entries) do
        local key, value = entry.key:lower(), entry.value
        local problem = { row = entry.row }
        if key == 'collaboration-mode' and (value:sub(1, 1) == '{' or #entry.children > 0) then
            problem.legacy_map = true
            legacy_map = legacy_map or problem
        elseif #entry.children > 0 then return problem
        elseif value:match('^[\'\"]') then
            local _, err = declarations.scalar(entry)
            if err then return problem end
        elseif key ~= 'process-instruction' then
            if value:match('^[%[%]{},&*!|>%%@`]')
                or value:match('^[?:%-]%s') or value:match('^[?:%-]$')
                or value:find(':%s') or value:sub(-1) == ':' then return problem end
        end
    end
    return legacy_map
end

local function unsupported(problem)
    return 'frontmatter line ' .. problem.row .. ': not a simple header; use flat key: value lines'
end

local function header(lines, keys)
    local parsed, err = scan(lines, keys)
    if not parsed then return nil, err end
    local problem = representation(parsed)
    if problem then
        if not problem.legacy_map then return nil, unsupported(problem) end
        local value, map_error = declarations.parse(lines)
        if map_error or type(value) ~= 'table' then
            return nil, 'frontmatter line ' .. problem.row .. ': ' .. tostring(map_error or 'invalid collaboration-mode map')
        end
    end
    return parsed
end

local function scalar(parsed, key, legacy)
    local entries = parsed.fields[key]
    if not entries then return nil end
    local value, err = declarations.scalar(entries[1], legacy)
    if err then return nil, 'frontmatter line ' .. entries[1].row .. ': ' .. key .. ': ' .. err end
    return value
end

local function presentation(parsed)
    local key = parsed.fields['presentation-mode'] and 'presentation-mode' or 'presentation'
    local value, err = scalar(parsed, key)
    if err then return nil, nil, err end
    local warnings = {}
    if parsed.fields.presentation then warnings[#warnings + 1] = 'presentation is deprecated; use presentation-mode' end
    if value ~= nil and value ~= '' and not presentations[value] then
        warnings[#warnings + 1] = key .. ': unknown value ' .. value .. '; using highlight (choose highlight, direct, propose)'
    end
    return presentations[value] and value or 'highlight', warnings
end

--- Presentation can be read on repaint without loading a processing catalog.
function M.presentation_value(lines)
    local parsed, err = header(lines, { 'presentation-mode', 'presentation' })
    if not parsed then return nil, { err } end
    local value, warnings, problem = presentation(parsed)
    if problem then return nil, { problem } end
    return value, warnings
end

--- Resolve canonical keys independently from their readable legacy components.
function M.resolve(lines, modes)
    local parsed, err = header(lines)
    if not parsed then return nil, err end
    local routing, route_err = collaboration.resolve(lines)
    local shown, warnings, shown_err = presentation(parsed)
    if not shown then return nil, shown_err end
    local legacy, legacy_err = scalar(parsed, 'process-instruction', true)
    if legacy_err then return nil, legacy_err end
    local old = instruction.parse(legacy)
    if legacy ~= nil then warnings[#warnings + 1] = 'process-instruction is deprecated; use processing-mode and processing-instruction' end
    local selected, mode_err = scalar(parsed, 'processing-mode')
    if mode_err then return nil, mode_err end
    local text, text_err = scalar(parsed, 'processing-instruction')
    if text_err then return nil, text_err end
    local names = selected ~= nil and { selected } or (#old.names > 0 and old.names or { instruction.DEFAULT_MODE })
    local resolved, resolve_err = instruction.resolve(names, modes)
    if not resolved or not routing then
        local errors = {}
        if resolve_err then errors[#errors + 1] = 'processing-mode: ' .. resolve_err end
        if route_err then errors[#errors + 1] = route_err end
        return nil, table.concat(errors, '; ')
    end
    if #old.names > 1 then
        warnings[#warnings + 1] = 'legacy process-instruction has several modes; all briefs remain readable'
    end
    if parsed.fields['collaboration-mode'] then
        local value = declarations.parse(lines)
        if type(value) == 'table' then warnings[#warnings + 1] = 'collaboration-mode section maps are deprecated; preserved unchanged' end
    end
    return { presentation = shown, modes = resolved, instruction = text ~= nil and text or old.text,
        collaboration = routing, warnings = warnings, legacy_multi = #old.names > 1, header = parsed }
end

local function line(key, value)
    -- Prove a conservative plain spelling round-trips through the reader.
    -- JSON strings are YAML double-quoted scalars and escape native newlines.
    local decoded = declarations.scalar({ value = value, raw = value, children = {} })
    local controls = value:find('[%z\1-\31\127]') or value:find('\194[\128-\159]')
        or value:find('\226\128[\168\169]')
    if value:match('^[%a_]') and not value:match('^[yYnN]$') and not controls
        and not frontmatter.needs_quote(value) and decoded == value then
        return key .. ': ' .. value
    end
    local encoded = vim.json.encode(value):gsub('\127', '\\u007f')
        :gsub('\194([\128-\159])', function(byte) return ('\\u%04x'):format(byte:byte()) end)
        :gsub('\226\128\168', '\\u2028'):gsub('\226\128\169', '\\u2029')
    return key .. ': ' .. encoded
end

--- Return the unchanged snapshot or one insertion plus its complete postimage.
--- All validation happens before producing any patch; the caller owns editing.
function M.fill(lines, modes)
    local parsed, scan_error, scan_problem = scan(lines)
    if not parsed and scan_problem and scan_problem.kind ~= 'unsupported' then return nil, scan_error end
    local problem = parsed and representation(parsed) or scan_problem
    if not parsed or problem then
        local unchanged = {}
        for _, value in ipairs(lines) do unchanged[#unchanged + 1] = value end
        return { changed = false, lines = unchanged,
            skip_reason = 'front matter left unchanged: not a simple header (line ' .. (problem and problem.row or 1) .. ')' }
    end
    local settings, err = M.resolve(lines, modes)
    if not settings then return nil, err end
    if settings.legacy_multi then
        return nil, 'choose one processing-mode and move remaining intent to processing-instruction; nothing changed'
    end
    local added = {}
    if not parsed.fields['collaboration-mode'] then added[#added + 1] = 'collaboration-mode: discussion' end
    if not parsed.fields['presentation-mode'] then added[#added + 1] = line('presentation-mode', settings.presentation) end
    if not parsed.fields['processing-mode'] then added[#added + 1] = line('processing-mode', settings.modes[1].name) end
    if not parsed.fields['processing-instruction'] and settings.instruction ~= '' then
        added[#added + 1] = line('processing-instruction', settings.instruction)
    end
    local result = { changed = #added > 0, lines = {}, settings = settings }
    for _, value in ipairs(lines) do result.lines[#result.lines + 1] = value end
    if #added == 0 then return result end
    if parsed.entries[1] then
        local indent = lines[parsed.entries[1].row]:match('^ *')
        for index, value in ipairs(added) do added[index] = indent .. value end
    end
    local first = parsed.close and parsed.close - 1 or 0
    local insertion = added
    if not parsed.close then
        insertion = { '---' }
        for _, value in ipairs(added) do insertion[#insertion + 1] = value end
        insertion[#insertion + 1], insertion[#insertion + 2] = '---', ''
    end
    result.patch = { first = first, last = first, lines = insertion }
    for index = #insertion, 1, -1 do table.insert(result.lines, first + 1, insertion[index]) end
    local projected, projected_error = declarations.header(result.lines)
    if not projected then return nil, projected_error end
    return result
end

return M
