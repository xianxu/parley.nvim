-- Pure structural model for chat/markdown decoration.

local M = {}

local TOKENS = {
    text = "t", user = "u", assistant = "a", ["local"] = "l",
    branch = "b", summary = "s", reasoning = "r", reasoning_end = "e",
    tool_use = "U", tool_result = "R", fence = "c", draft_open = "d",
    draft_end = "D", footnote = "f", blank = "_",
}

--- The kinds a tool body may not span (#203).
---
--- These are the markers `chat_parser` calls structural: 📝/🔧/📎/💬/🤖/🌿/🔒.
--- `reasoning` is deliberately absent — 🧠: is terminated BY a structural
--- marker, it is not one.
---
--- Named here because this module owns the kind vocabulary (TOKENS above). The
--- three `fence.scan` consumers derive their predicate from this rather than
--- each hand-listing kinds, which is how they diverged before #200.
--- Derived from TOKENS, not a parallel literal: a kind that exists in one table
--- and not the other is the drift this issue is about (#203 BR-18). Membership
--- is stated once, as the token set below.
local STRUCTURAL_TOKENS = { u = true, a = true, s = true, U = true, R = true,
    b = true, l = true }
M.STRUCTURAL_KINDS = {}
for kind, token in pairs(TOKENS) do
    if STRUCTURAL_TOKENS[token] then M.STRUCTURAL_KINDS[kind] = true end
end

--- Whether `kind` is a structural marker a tool body may not span.
function M.is_structural_kind(kind)
    return M.STRUCTURAL_KINDS[kind] == true
end

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
    local fence_len
    patterns = patterns or M.patterns()
    local kind = "text"
    local label = line:match("^=== (.+) ===%s*$")
    if require("parley.define").is_footnote_line(line) then kind = "footnote"
    elseif label == "end" then kind = "draft_end"
    elseif label then kind = "draft_open"
    elseif M.is_fence_delim(line) then
        kind = "fence"
        -- Width matters: a closer shorter than its opener does not close it
        -- (CommonMark). It rides in the TOKEN because M.replace's fast path
        -- keys on fingerprint equality alone — "```" and "````" would
        -- otherwise be indistinguishable and a width edit would reuse stale
        -- state for the rest of the buffer (#218 PQ-2).
        fence_len = #(line:match("^%s*(`+)") or "")
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
    if kind == "fence" then
        return { kind = kind, token = TOKENS.fence .. tostring(fence_len), fence_len = fence_len }
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
        -- length of the OPEN fence, nil when closed. `in_code` stays a boolean
        -- because the exposed contract is asserted as one
        -- (highlight_structure_spec.lua:14,52,54) — this rides alongside it.
        code_fence_len = value.code_fence_len,
        in_reasoning = value.in_reasoning,
        reasoning_explicit_end = value.reasoning_explicit_end,
        in_tool = value.in_tool,
    }
end


--- Apply one row's token to `state`, in place. THE single transition function:
--- the builder below and `highlighter`'s per-window walk both call it, so the
--- two can no longer drift (#218 — they had byte-identical fence toggles).
---
--- PHASE. Two groups, deliberately split:
---   * `M.reset_partition` runs BEFORE the row's snapshot — a 💬:/🤖: line is
---     itself not inside a code block, so `state_before[that row]` must already
---     be clean.
---   * everything here runs AFTER the snapshot, matching the existing
---     convention that `state_before[row]` is the state ENTERING the row.
--- Collapsing the two phases is what made an earlier draft wrong: it would have
--- inverted the fence delimiter's own render and dimmed every tool body's
--- closing fence.
--- @param state table mutated in place
--- @param token string fingerprint token for this row
--- @param fence_len integer|nil width of this row's fence run, when it is one
function M.advance(state, token, fence_len)
    if token and token:sub(1, 1) == TOKENS.fence then
        local n = fence_len or tonumber(token:sub(2)) or 0
        if not state.in_code then
            state.in_code = true
            state.code_fence_len = n
        elseif n >= (state.code_fence_len or 0) then
            -- CommonMark: a closer must be at least as long as its opener, so a
            -- ``` inside a ```` block is content, not a terminator.
            state.in_code = false
            state.code_fence_len = nil
            if state.in_tool then state.in_tool = false end
        end
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
    end
end

--- Is this line a 💬:/🤖: turn partition? Exported so consumers that keep their
--- own lightweight fence walks (outline, the review skill) can apply the same
--- containment rule without a fourth and fifth definition of "partition" (#218).
--- @param line string
--- @param patterns table|nil
--- @return boolean
function M.is_partition(line, patterns)
    local token = M.classify(line, patterns or M.patterns()).token
    return token == TOKENS.user or token == TOKENS.assistant
        or token == TOKENS["local"] or token == TOKENS.branch
end

--- Does this line open or close a fence? Returns the backtick run length, or
--- nil. `tildes` also accepts `~~~` (outline's grammar; the render path does
--- not treat tildes as fences).
---
--- Exists because the fence-open predicate was hand-copied into six places
--- (this file, three in outline, the review skill, copy.lua) and they had
--- already drifted: the review skill matched `^```` with no leading whitespace,
--- so it missed every fence the default prompt now asks models to indent (#218).
--- @param line string
--- @param tildes boolean|nil
--- @return integer|nil
function M.is_fence_delim(line, tildes)
    if type(line) ~= "string" then return nil end
    local ticks = line:match("^%s*(`+)")
    if ticks and #ticks >= 3 then return #ticks end
    if tildes then
        local tl = line:match("^%s*(~+)")
        if tl and #tl >= 3 then return #tl end
    end
    return nil
end

--- Build a 1-indexed "is this line inside a code block" memo, with #218
--- containment: a column-zero turn marker ends any open fence.
---
--- One helper rather than a copy per caller — outline had THREE independent
--- builds of this loop and the close review found the bug still live in the one
--- it had missed. `patterns` MUST come from the live config; defaults would
--- silently disable containment for anyone with a custom chat_user_prefix.
--- @param lines string[]
--- @param patterns table from M.patterns(config)
--- @param tildes boolean|nil treat `~~~` as a fence too
--- @return boolean[] memo
function M.code_block_memo(lines, patterns, tildes)
    local memo = {}
    local in_block = false
    for i, line in ipairs(lines or {}) do
        if M.is_partition(line, patterns) then
            in_block = false
        elseif M.is_fence_delim(line, tildes) then
            in_block = not in_block
        end
        memo[i] = in_block
    end
    return memo
end

--- Clear the state a 💬:/🤖: partition terminates. Runs PRE-snapshot.
---
--- This is the containment rule the whole issue exists for: an unmatched fence
--- in one answer must not render the rest of the document as code. `in_question`
--- and `in_reasoning` were already reset at these boundaries; `in_code` was not.
--- @param state table mutated in place
--- @param token string
--- @return boolean whether this token is a partition
function M.reset_partition(state, token)
    if token ~= TOKENS.user and token ~= TOKENS.assistant
        and token ~= TOKENS["local"] and token ~= TOKENS.branch then
        return false
    end
    state.in_code = false
    state.code_fence_len = nil
    state.in_tool = false
    return true
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
        local token = result.fingerprints[row + 1]

        -- PRE-snapshot: a partition line is not itself inside a code block, so
        -- the containment reset must land before the row is recorded (#218).
        M.reset_partition(state, token)
        result.state_before[row + 1] = copy_state(state)

        if token == TOKENS.draft_open and draft_start == nil then
            draft_start = row
        elseif token == TOKENS.draft_end and draft_start ~= nil then
            result.draft_ranges[#result.draft_ranges + 1] = {
                start_row = draft_start, end_row_exclusive = row + 1,
            }
            draft_start = nil
        end

        M.advance(state, token)

        -- Reasoning's blank-line terminator is lookahead-dependent, so it stays
        -- here rather than in the shared transition.
        if token == TOKENS.reasoning_end then
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
