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

local function header(lines)
    local parsed, err = declarations.header(lines)
    if not parsed then return nil, err end
    for _, key in ipairs(relevant) do
        if parsed.fields[key] and #parsed.fields[key] > 1 then return nil, 'duplicate ' .. key .. ' field' end
    end
    return parsed
end

local function scalar(parsed, key, legacy)
    local entries = parsed.fields[key]
    if not entries then return nil end
    local value, err = declarations.scalar(entries[1], legacy)
    if err then return nil, key .. ': ' .. err end
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
    local parsed, err = header(lines)
    if not parsed then return 'highlight', { err } end
    local value, warnings, problem = presentation(parsed)
    return value or 'highlight', warnings or { problem }
end

--- Resolve canonical keys independently from their readable legacy components.
function M.resolve(lines, modes)
    local parsed, err = header(lines)
    if not parsed then return nil, err end
    local routing, route_err = collaboration.resolve(lines)
    if not routing then return nil, route_err end
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
    if not resolved then return nil, 'processing-mode: ' .. resolve_err end
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
    return key .. ': ' .. (frontmatter.needs_quote(value) and frontmatter.quote(value) or value)
end

--- Return the unchanged snapshot or one insertion plus its complete postimage.
--- All validation happens before producing any patch; the caller owns editing.
function M.fill(lines, modes)
    local settings, err = M.resolve(lines, modes)
    if not settings then return nil, err end
    if settings.legacy_multi then
        return nil, 'choose one processing-mode and move remaining intent to processing-instruction; nothing changed'
    end
    local parsed, added = settings.header, {}
    if not parsed.fields['collaboration-mode'] then added[#added + 1] = 'collaboration-mode: discussion' end
    if not parsed.fields['presentation-mode'] then added[#added + 1] = line('presentation-mode', settings.presentation) end
    if not parsed.fields['processing-mode'] then added[#added + 1] = line('processing-mode', settings.modes[1].name) end
    if not parsed.fields['processing-instruction'] and settings.instruction ~= '' then
        added[#added + 1] = line('processing-instruction', settings.instruction)
    end
    local result = { changed = #added > 0, lines = {}, settings = settings }
    for _, value in ipairs(lines) do result.lines[#result.lines + 1] = value end
    if #added == 0 then return result end
    local first = parsed.close and parsed.close - 1 or 0
    local insertion = added
    if not parsed.close then
        insertion = { '---' }
        for _, value in ipairs(added) do insertion[#insertion + 1] = value end
        insertion[#insertion + 1], insertion[#insertion + 2] = '---', ''
    end
    result.patch = { first = first, last = first, lines = insertion }
    for index = #insertion, 1, -1 do table.insert(result.lines, first + 1, insertion[index]) end
    return result
end

return M
