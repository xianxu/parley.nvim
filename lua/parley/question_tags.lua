-- Pure ownership and outline projections for question prefaces.
local M = {}
local structure = require("parley.highlight_structure")

function M.parse_tag(line)
    return type(line) == "string" and line:match("^@@(.+)@@$") or nil
end

function M.associations(lines, config, header_end)
    local patterns = structure.patterns(config)
    local memo = structure.code_block_memo(lines, patterns, true)
    local result = {}
    local prefix = patterns.user_prefix
    for row = (header_end or 0) + 2, #lines do
        local label = M.parse_tag(lines[row - 1])
        if label and not memo[row - 1] and not memo[row]
            and lines[row]:sub(1, #prefix) == prefix then
            result[row] = { line_start = row - 1, line_end = row - 1,
                content = lines[row - 1], label = label }
        end
    end
    return result
end

function M.compose_question(preface_content, question_content)
    if preface_content and preface_content ~= "" then
        return preface_content .. "\n" .. (question_content or "")
    end
    return question_content or ""
end

--- First physical row owned by a parsed exchange, including its preface.
--- The literal question anchor remains question.line_start.
function M.semantic_start(exchange)
    return (exchange.preface and exchange.preface.line_start) or exchange.question.line_start
end

local function copy_item(item)
    local out = {}
    for key, value in pairs(item) do out[key] = value end
    out.value = {}
    for key, value in pairs(item.value) do out.value[key] = value end
    return out
end

function M.apply_outline(items, lines, config, header_end)
    local attached = M.associations(lines, config, header_end)
    local used_tags = {}
    for _, item in ipairs(items) do
        local preface = item.type == "question" and attached[item.value.lnum]
        if preface then used_tags[preface.line_start] = true end
    end
    local result = {}
    for _, item in ipairs(items) do
        local label = item.type == "annotation" and M.parse_tag(lines[item.value.lnum])
        local preface = item.type == "question" and attached[item.value.lnum]
        local hidden_tag = label and (label == "_" or used_tags[item.value.lnum])
        if not hidden_tag and not (preface and preface.label == "_") then
            local copy = copy_item(item)
            if preface then
                copy.display = (item.display:match("^%s*") or "") .. preface.label
                copy.value.tag_lnum = preface.line_start
            end
            result[#result + 1] = copy
        end
    end
    return result
end

function M.initial_index(items, file, row)
    local nearest, distance = 1, 6
    for index, item in ipairs(items) do
        local value = item.value
        if not value.file or value.file == file then
            if value.tag_lnum == row or value.lnum == row then return index end
            local delta = math.abs(value.lnum - row)
            if delta < distance then nearest, distance = index, delta end
        end
    end
    return nearest
end

return M
