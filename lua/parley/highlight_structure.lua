-- Incremental render-state cache over the shared pure lexical grammar.
local lexical = require("parley.document.lexical")
local M = {}
local TOKENS = lexical.tokens()
local STRUCTURAL_TOKENS = lexical.structural_tokens()
local copy_state = lexical.copy_state
M.STRUCTURAL_KINDS = lexical.STRUCTURAL_KINDS
M.patterns = lexical.patterns
M.classify = lexical.classify
M.fingerprint = lexical.fingerprint
M.is_structural_kind = lexical.is_structural_kind
M.advance = lexical.advance
M.is_partition = lexical.is_partition
M.is_fence_delim = lexical.is_fence_delim
M.code_block_memo = lexical.code_block_memo
M.reset_partition = lexical.reset_partition

local function initial_state()
    return copy_state({
        in_question = false, in_code = false, in_reasoning = false,
        reasoning_explicit_end = false, in_tool = false,
    })
end

--- Footer start and draft ranges, accumulated one token at a time so `build`
--- (from classified lines) and `replace` (from a spliced token array) derive
--- them with the same code.
local function new_markers()
    return { footer_start0 = nil, draft_ranges = {}, draft_start = nil }
end

local function add_marker(markers, row0, token)
    if markers.footer_start0 == nil and token == TOKENS.footnote then
        markers.footer_start0 = row0
    end
    if token == TOKENS.draft_open and markers.draft_start == nil then
        markers.draft_start = row0
    elseif token == TOKENS.draft_end and markers.draft_start ~= nil then
        markers.draft_ranges[#markers.draft_ranges + 1] = {
            start_row = markers.draft_start, end_row_exclusive = row0 + 1,
        }
        markers.draft_start = nil
    end
end

local function finish_markers(markers, row_count)
    if markers.draft_start ~= nil then
        markers.draft_ranges[#markers.draft_ranges + 1] = {
            start_row = markers.draft_start, end_row_exclusive = row_count,
        }
    end
    return markers.footer_start0, markers.draft_ranges
end

--- PRE-snapshot half of a row's forward step: what the row resets on entry.
--- The footer ends exchange colouring; a partition clears code state (#218),
--- and must land before the row is recorded — a partition line is not itself
--- inside a code block.
local function enter_row(state, row0, token, footer_start0)
    if footer_start0 and row0 >= footer_start0 then
        state.in_question = false
        state.in_reasoning = false
    end
    M.reset_partition(state, token)
end

--- POST-snapshot half: the row's own transition. `explicit` is the lookahead
--- verdict for a 🧠: row — does its 🧠:[END] arrive before the next marker.
--- Blank rows are the `_` token: `classify` gives it to exactly the lines the
--- old `^%s*$` test matched, so the walk needs no line text.
local function leave_row(state, token, explicit)
    M.advance(state, token)
    -- Reasoning's blank-line terminator is lookahead-dependent, so it stays
    -- here rather than in the shared transition.
    if token == TOKENS.reasoning_end then
        state.in_reasoning = false
        state.reasoning_explicit_end = false
    elseif token == TOKENS.reasoning then
        state.in_reasoning = true
        state.reasoning_explicit_end = explicit or false
    elseif state.in_reasoning and token == TOKENS.blank and not state.reasoning_explicit_end then
        state.in_reasoning = false
    end
end

--- Backward 🧠: lookahead. The markers that end it are STRUCTURAL_TOKENS —
--- the same set chat_parser terminates reasoning on — not a second list.
local function reasoning_explicit_of(fingerprints, work)
    local explicit, end_ahead = {}, false
    for index = #fingerprints, 1, -1 do
        work.rows_visited = work.rows_visited + 1
        local token = fingerprints[index]
        if token == TOKENS.reasoning then
            explicit[index] = end_ahead
        elseif token == TOKENS.reasoning_end then
            end_ahead = true
        elseif STRUCTURAL_TOKENS[token] then
            end_ahead = false
        end
    end
    return explicit
end

--- Everything a structure holds beyond its tokens, derived from them alone.
--- `build` is classify + derive; `replace` derives when an edit leaves no row
--- to reuse, so the two cannot disagree about what a token sequence means.
local function derive(fingerprints, footer_start0, draft_ranges, work)
    local explicit = reasoning_explicit_of(fingerprints, work)
    local state_before = {}
    local state = initial_state()
    for row0 = 0, #fingerprints - 1 do
        work.rows_visited = work.rows_visited + 1
        local token = fingerprints[row0 + 1]
        enter_row(state, row0, token, footer_start0)
        state_before[row0 + 1] = copy_state(state)
        leave_row(state, token, explicit[row0 + 1])
    end
    return {
        fingerprints = fingerprints,
        state_before = state_before,
        footer_start0 = footer_start0,
        draft_ranges = draft_ranges,
    }
end

function M.build(lines, patterns)
    lines = lines or {}
    patterns = patterns or M.patterns()
    local work = { rows_visited = 0, entries_copied = 0 }
    local fingerprints, markers = {}, new_markers()
    for row0 = 0, #lines - 1 do
        work.rows_visited = work.rows_visited + 1
        local token = M.classify(lines[row0 + 1], patterns).token
        fingerprints[row0 + 1] = token
        add_marker(markers, row0, token)
    end
    local footer_start0, draft_ranges = finish_markers(markers, #lines)
    return derive(fingerprints, footer_start0, draft_ranges, work), #lines, work
end

--- Inert tokens never feed the 🧠: lookahead or move the footer, so an edit
--- made only of them can change other rows solely through the forward walk —
--- which `replace` checks directly. Every other token can move state a splice
--- cannot see, above the edit as well as below it.
local function is_inert(token)
    return token == TOKENS.text or token == TOKENS.blank
        or token == TOKENS.draft_open or token == TOKENS.draft_end
        or token:sub(1, 1) == TOKENS.fence
end

local function same_state(a, b)
    return a.in_question == b.in_question and a.in_code == b.in_code
        and a.code_fence_len == b.code_fence_len and a.in_reasoning == b.in_reasoning
        and a.reasoning_explicit_end == b.reasoning_explicit_end and a.in_tool == b.in_tool
end

--- The state LEAVING `row0`. `state_before` holds the state entering each row
--- (after that row's own resets), so a row's exit is recomputed from its entry.
--- A 🧠: row's lookahead verdict rides in the next row's entering state, which
--- `enter_row` never touches; the last row has nothing ahead of it.
local function exit_state(structure, row0)
    local state = copy_state(structure.state_before[row0 + 1])
    local after = structure.state_before[row0 + 2]
    leave_row(state, structure.fingerprints[row0 + 1], after and after.reasoning_explicit_end or false)
    return state
end

--- Apply one buffer edit — rows [first0, old_last0) replaced by `new_lines` —
--- and return a structure ALIGNED with the edited buffer (#227).
---
--- Tokens, footer and draft ranges are always exact. `reason` says whether
--- `state_before` is:
---   nil           exact — identical to build() of the edited buffer, provided
---                 `structure` was itself exact. The verdict is about this edit
---                 only: a splice onto an approximate structure stays
---                 approximate, which is why the cache's `dirty` is sticky.
---   "structural"  some rows may keep pre-edit state: below the edit via the
---                 forward walk, above it via the 🧠: lookahead; rebuild
---   "misaligned"  (no structure) the range does not fit; rebuild
--- Never writes `structure`.
function M.replace(structure, first0, old_last0, new_lines, patterns)
    new_lines = new_lines or {}
    patterns = patterns or M.patterns()
    local old_n = #structure.fingerprints
    local m = #new_lines
    local work = { rows_visited = 0, entries_copied = 0 }
    if first0 < 0 or first0 > old_last0 or old_last0 > old_n then
        return nil, m, "misaligned", work
    end
    local inserted = {}
    for i, line in ipairs(new_lines) do
        work.rows_visited = work.rows_visited + 1
        inserted[i] = M.fingerprint(line, patterns)
    end

    -- Same span, same tokens: every derived value is unchanged, so share it.
    if old_last0 - first0 == m then
        local identical = true
        for i = 1, m do
            if inserted[i] ~= structure.fingerprints[first0 + i] then
                identical = false
                break
            end
        end
        if identical then
            return {
                fingerprints = structure.fingerprints,
                state_before = structure.state_before,
                footer_start0 = structure.footer_start0,
                draft_ranges = structure.draft_ranges,
            }, m, nil, work
        end
    end

    -- Splice the tokens; footer and drafts are re-derived in the same pass.
    local delta = m - (old_last0 - first0)
    local new_n = old_n + delta
    local fingerprints, markers = {}, new_markers()
    for row0 = 0, new_n - 1 do
        local token
        if row0 < first0 then
            token = structure.fingerprints[row0 + 1]
        elseif row0 < first0 + m then
            token = inserted[row0 - first0 + 1]
        else
            token = structure.fingerprints[row0 - delta + 1]
        end
        fingerprints[row0 + 1] = token
        add_marker(markers, row0, token)
    end
    work.entries_copied = work.entries_copied + new_n
    local footer_start0, draft_ranges = finish_markers(markers, new_n)

    -- Nothing above or below survives: derive the whole thing.
    if first0 == 0 and old_last0 == old_n then
        return derive(fingerprints, footer_start0, draft_ranges, work), m, nil, work
    end

    -- Walk the inserted rows forward from the state leaving the row above.
    local state = first0 == 0 and initial_state() or exit_state(structure, first0 - 1)
    local walked = {}
    for i = 1, m do
        work.rows_visited = work.rows_visited + 1
        enter_row(state, first0 + i - 1, inserted[i], footer_start0)
        walked[i] = copy_state(state)
        -- An inserted 🧠: row's verdict is unknown here. It is not inert, so
        -- the result is already approximate and the caller's rebuild settles it.
        leave_row(state, inserted[i], false)
    end

    -- Converged when the first surviving row below is entered exactly as before.
    local converged = true
    if old_last0 < old_n then
        enter_row(state, first0 + m, structure.fingerprints[old_last0 + 1], footer_start0)
        converged = same_state(state, structure.state_before[old_last0 + 1])
    end

    local state_before = {}
    for row0 = 0, new_n - 1 do
        if row0 < first0 then
            state_before[row0 + 1] = structure.state_before[row0 + 1]
        elseif row0 < first0 + m then
            state_before[row0 + 1] = walked[row0 - first0 + 1]
        else
            state_before[row0 + 1] = structure.state_before[row0 - delta + 1]
        end
    end
    work.entries_copied = work.entries_copied + new_n

    local exact = converged
    for i = 1, m do
        if not is_inert(inserted[i]) then exact = false end
    end
    for row = first0 + 1, old_last0 do
        if not is_inert(structure.fingerprints[row]) then exact = false end
    end
    return {
        fingerprints = fingerprints,
        state_before = state_before,
        footer_start0 = footer_start0,
        draft_ranges = draft_ranges,
    }, m, (not exact) and "structural" or nil, work
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
