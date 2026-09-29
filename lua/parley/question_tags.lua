-- Pure ownership and outline projections for question prefaces.
local M = {}
local structure = require("parley.highlight_structure")

function M.parse_tag(line)
    return type(line) == "string" and line:match("^@@(.+)@@$") or nil
end

-- Classify physical rows before speaker removal or whitespace normalization.
function M.is_local_tag(line)
    return M.parse_tag(line) ~= nil and #require("parley.chat_parser").extract_file_refs(line) == 0
end

-- One fence rule for ownership and context projection (ARCH-DRY). A turn
-- partition ends an unmatched fence; a question may open another after its
-- speaker prefix. Closers are bare runs of the opener's character, at least
-- as wide. Snapshot before the opener so the question can still own a preface.
local function fenced_rows(lines, config)
    local memo, fence_char, fence_width = {}, nil, nil
    local patterns = structure.patterns(config)
    for row, line in ipairs(lines) do
        if structure.is_partition(line, patterns) then fence_char, fence_width = nil, nil end
        memo[row] = fence_char ~= nil
        local fence_line = line
        if line:sub(1, #patterns.user_prefix) == patterns.user_prefix then
            fence_line = line:sub(#patterns.user_prefix + 1)
        end
        local run, tail = fence_line:match("^%s*(`+)(.*)$")
        if not run then run, tail = fence_line:match("^%s*(~+)(.*)$") end
        if run and #run >= 3 then
            local char = run:sub(1, 1)
            if fence_char then
                if char == fence_char and #run >= fence_width and tail:match("^%s*$") then
                    fence_char, fence_width = nil, nil
                end
            elseif char ~= "`" or not tail:find("`", 1, true) then
                fence_char, fence_width = char, #run
            end
        end
    end
    return memo
end

function M.local_rows(lines, config)
    local excluded, memo = {}, fenced_rows(lines, config)
    for row, line in ipairs(lines) do
        if not memo[row] and M.is_local_tag(line) then excluded[row] = true end
    end
    return excluded
end

function M.project(parts, source_rows, excluded)
    local out = {}
    for index, part in ipairs(parts) do
        if not excluded[source_rows and source_rows[index] or index] then out[#out + 1] = part end
    end
    return table.concat(out, "\n")
end

function M.context_text(text, config)
    local lines = vim.split(text or "", "\n", { plain = true })
    return M.project(lines, nil, M.local_rows(lines, config))
end

function M.content(component)
    return component.context_content or component.content
end

function M.associations(lines, config, header_end)
    local patterns = structure.patterns(config)
    local memo = fenced_rows(lines, config)
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
    if preface_content and preface_content ~= "" and not M.is_local_tag(preface_content) then
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

function M.outline_label(label, config)
    return config.chat_user_prefix .. " " .. label
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
                copy.display = (item.display:match("^%s*") or "") .. M.outline_label(preface.label, config)
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
