-- Pure structural model for chat/markdown decoration.

local M = {}

local TOKENS = {
    text = "t", user = "u", assistant = "a", ["local"] = "l",
    branch = "b", summary = "s", reasoning = "r", reasoning_end = "e",
    tool_use = "U", tool_result = "R", fence = "c", draft_open = "d",
    draft_end = "D", footnote = "f", blank = "_",
}

local function escape_pattern(text)
    return (text:gsub("([^%w])", "%%%1"))
end

local function first_prefix(value)
    if type(value) == "table" then return value[1] end
    return value
end

function M.patterns(config)
    config = config or {}
    local memory = config.chat_memory or {}
    local reasoning = memory.enable and memory.reasoning_prefix or "🧠:"
    local summary = memory.enable and memory.summary_prefix or "📝:"
    local user = config.chat_user_prefix or "💬:"
    local assistant = first_prefix(config.chat_assistant_prefix) or "🤖:"
    local local_prefix = config.chat_local_prefix or "🔒:"
    local branch = config.chat_branch_prefix or "🌿:"
    local tool_use = config.chat_tool_use_prefix or "🔧:"
    local tool_result = config.chat_tool_result_prefix or "📎:"
    return {
        reasoning_prefix = reasoning,
        summary_prefix = summary,
        user_prefix = user,
        assistant_prefix = assistant,
        local_prefix = local_prefix,
        branch_prefix = branch,
        tool_use_prefix = tool_use,
        tool_result_prefix = tool_result,
        reasoning_pattern = "^" .. escape_pattern(reasoning),
        reasoning_end_pattern = "^%s*" .. escape_pattern(reasoning) .. "%[END%]%s*$",
        summary_pattern = "^" .. escape_pattern(summary),
        user_pattern = "^" .. escape_pattern(user),
        assistant_pattern = "^" .. escape_pattern(assistant),
        local_pattern = "^" .. escape_pattern(local_prefix),
        branch_pattern = "^" .. escape_pattern(branch),
        tool_use_pattern = "^" .. escape_pattern(tool_use),
        tool_result_pattern = "^" .. escape_pattern(tool_result),
    }
end

function M.classify(line, patterns)
    line = line or ""
    patterns = patterns or M.patterns()
    local kind = "text"
    local label = line:match("^=== (.+) ===%s*$")
    if require("parley.define").is_footnote_line(line) then kind = "footnote"
    elseif label == "end" then kind = "draft_end"
    elseif label then kind = "draft_open"
    elseif line:match("^%s*```") then kind = "fence"
    elseif line:match(patterns.reasoning_end_pattern) then kind = "reasoning_end"
    elseif line:match(patterns.reasoning_pattern) then kind = "reasoning"
    elseif line:match(patterns.user_pattern) then kind = "user"
    elseif line:match(patterns.assistant_pattern) then kind = "assistant"
    elseif line:match(patterns.local_pattern) then kind = "local"
    elseif line:match(patterns.branch_pattern) then kind = "branch"
    elseif line:match(patterns.summary_pattern) then kind = "summary"
    elseif line:match(patterns.tool_use_pattern) then kind = "tool_use"
    elseif line:match(patterns.tool_result_pattern) then kind = "tool_result"
    elseif line:match("^%s*$") then kind = "blank"
    end
    return { kind = kind, token = TOKENS[kind] }
end

function M.fingerprint(line, patterns)
    return M.classify(line, patterns).token
end

local function copy_state(value)
    return {
        in_question = value.in_question,
        in_code = value.in_code,
        in_reasoning = value.in_reasoning,
        reasoning_explicit_end = value.reasoning_explicit_end,
        in_tool = value.in_tool,
    }
end

function M.build(lines, patterns)
    lines = lines or {}
    patterns = patterns or M.patterns()
    local result = {
        fingerprints = {},
        state_before = {},
        footer_start0 = nil,
        draft_ranges = {},
    }
    local work = { rows_visited = 0, entries_copied = 0 }
    for row = 0, #lines - 1 do
        work.rows_visited = work.rows_visited + 1
        local classified = M.classify(lines[row + 1], patterns)
        result.fingerprints[row + 1] = classified.token
        if not result.footer_start0 and classified.kind == "footnote" then
            result.footer_start0 = row
        end
    end

    local reasoning_explicit = {}
    local end_ahead = false
    for index = #result.fingerprints, 1, -1 do
        work.rows_visited = work.rows_visited + 1
        local token = result.fingerprints[index]
        if token == TOKENS.reasoning then
            reasoning_explicit[index] = end_ahead
        elseif token == TOKENS.reasoning_end then
            end_ahead = true
        elseif token == TOKENS.user or token == TOKENS.assistant
            or token == TOKENS["local"] or token == TOKENS.branch
            or token == TOKENS.summary or token == TOKENS.tool_use
            or token == TOKENS.tool_result then
            end_ahead = false
        end
    end

    local state = copy_state({
        in_question = false, in_code = false, in_reasoning = false,
        reasoning_explicit_end = false, in_tool = false,
    })
    local draft_start
    for row = 0, #lines - 1 do
        work.rows_visited = work.rows_visited + 1
        if result.footer_start0 and row >= result.footer_start0 then
            state.in_question = false
            state.in_reasoning = false
        end
        result.state_before[row + 1] = copy_state(state)
        local token = result.fingerprints[row + 1]

        if token == TOKENS.draft_open and draft_start == nil then
            draft_start = row
        elseif token == TOKENS.draft_end and draft_start ~= nil then
            result.draft_ranges[#result.draft_ranges + 1] = {
                start_row = draft_start, end_row_exclusive = row + 1,
            }
            draft_start = nil
        end

        if token == TOKENS.fence then
            state.in_code = not state.in_code
            if not state.in_code and state.in_tool then state.in_tool = false end
        end
        if token == TOKENS.user then
            state.in_question = true
            state.in_reasoning = false
        elseif token == TOKENS.assistant or token == TOKENS["local"] or token == TOKENS.branch then
            state.in_question = false
            state.in_reasoning = false
        elseif token == TOKENS.summary then
            state.in_reasoning = false
        elseif token == TOKENS.tool_use or token == TOKENS.tool_result then
            state.in_reasoning = false
            state.in_tool = true
        elseif token == TOKENS.reasoning_end then
            state.in_reasoning = false
            state.reasoning_explicit_end = false
        elseif token == TOKENS.reasoning then
            state.in_reasoning = true
            state.reasoning_explicit_end = reasoning_explicit[row + 1] or false
        elseif state.in_reasoning and lines[row + 1]:match("^%s*$") and not state.reasoning_explicit_end then
            state.in_reasoning = false
        end
    end
    if draft_start ~= nil then
        result.draft_ranges[#result.draft_ranges + 1] = {
            start_row = draft_start, end_row_exclusive = #lines,
        }
    end
    return result, #lines, work
end

function M.replace(structure, first0, old_last0, new_lines, patterns)
    new_lines = new_lines or {}
    patterns = patterns or M.patterns()
    if old_last0 - first0 ~= #new_lines then
        return nil, #new_lines, "structural", { rows_visited = 0, entries_copied = 0 }
    end
    local work = { rows_visited = #new_lines, entries_copied = 0 }
    local fingerprints = {}
    local identical = true
    for i, line in ipairs(new_lines) do
        fingerprints[i] = M.fingerprint(line, patterns)
        if fingerprints[i] ~= structure.fingerprints[first0 + i] then
            identical = false
        end
    end
    if not identical then return nil, #new_lines, "structural", work end
    local out = {
        fingerprints = structure.fingerprints,
        state_before = structure.state_before,
        footer_start0 = structure.footer_start0,
        draft_ranges = structure.draft_ranges,
    }
    return out, #new_lines, nil, work
end

function M.state_before(structure, row0, opts)
    local stored = structure.state_before[row0 + 1] or {
        in_question = false, in_code = false, in_reasoning = false,
        reasoning_explicit_end = false, in_tool = false,
    }
    local out = copy_state(stored)
    if opts and opts.streaming and out.in_reasoning then out.reasoning_explicit_end = true end
    return out
end

function M.footer_range(structure, line_count)
    if structure.footer_start0 == nil then return nil end
    return { start_row = structure.footer_start0, end_row_exclusive = line_count }
end

function M.draft_blocks_in(structure, first0, last0)
    local out = {}
    for _, range in ipairs(structure.draft_ranges or {}) do
        if range.start_row < last0 and range.end_row_exclusive > first0 then
            out[#out + 1] = { start_row = range.start_row, end_row_exclusive = range.end_row_exclusive }
        end
    end
    return out
end

return M
