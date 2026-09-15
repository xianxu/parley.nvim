-- Shared pure lexical grammar. Native full-line predicates stay optimized;
-- the resumable recognizer below handles bounded slices of very long lines.

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
    -- No `patterns or M.patterns()` default. Silently falling back to the
    -- shipped prefixes is exactly BR-2: containment looked fixed and did nothing
    -- for anyone with a custom chat_user_prefix, at two call sites, twice. An
    -- assert makes that state unrepresentable instead of auditable.
    assert(type(patterns) == "table",
        "is_partition requires patterns from the LIVE config — "
        .. "highlight_structure.patterns(config)")
    -- Four anchored prefix matches, not M.classify: this runs per line in
    -- code_block_memo over whole buffers, and the full classifier costs ~10
    -- patterns plus a footnote lookup — measured 6.06ms vs 0.31ms per 5000-line
    -- buffer for the toggles it replaced (BR-22). Equivalent because every
    -- classify branch that precedes these four is anchored at column zero on a
    -- character a turn prefix cannot start with.
    return line:match(patterns.user_pattern) ~= nil
        or line:match(patterns.assistant_pattern) ~= nil
        or line:match(patterns.local_pattern) ~= nil
        or line:match(patterns.branch_pattern) ~= nil
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

local function table_copy(value)
    local out={}; for k,v in pairs(value) do out[k]=v end; return out
end
function M.tokens() return table_copy(TOKENS) end
function M.structural_tokens() return table_copy(STRUCTURAL_TOKENS) end
M.copy_state = copy_state
M.FENCE_MIN = 3

function M.ordinary_open_len(line)
    if type(line) ~= "string" then return nil end
    local ticks, info = line:match("^(`+)([^`]*)$")
    if not ticks or #ticks < M.FENCE_MIN then return nil end
    return #ticks, info
end

--- Whether this line closes a fence of length `n`.
---
--- Exactly `n` backticks and nothing else. A shorter run is body content; a
--- longer one belongs to some other pair, and treating it as a close is how a
--- reader can terminate a body early.
--- @param line string
--- @param n integer
--- @return boolean
function M.ordinary_closes(line, n)
    if type(line) ~= "string" or type(n) ~= "number" then return false end
    return line:match("^(`+)%s*$") ~= nil and #(line:match("^(`+)")) == n
end

local PREFIXES = {'reasoning','user','assistant','local','branch','summary','tool_use','tool_result'}
local function whitespace(c) return c == ' ' or c == '\t' or c == '\r' or c == '\n' or c == '\v' or c == '\f' end

function M.lex_start(patterns)
    patterns = patterns or M.patterns({})
    local cap=16
    for _,k in ipairs(PREFIXES) do cap=math.max(cap,#patterns[k..'_prefix']+8) end
    return {patterns=patterns,cap=cap,bytes=0,raw='',trimmed='',tail='',
        leading=true,trimmed_bytes=0,last_nonspace=0,footnote=0,
        ticks=0,ticks_open=true,ordinary_ticks=0,ordinary_run=true,
        ordinary_valid=true,bare_valid=true,memo_run=true,memo_width=0}
end

local function scan(c,ch)
    c.bytes=c.bytes+1
    c.diagnostic_tail=((c.diagnostic_tail or '')..ch):sub(-20)
    if c.diagnostic_tail:sub(-2)=='[^' then c.diagnostic_reference_candidate=true end
    if #c.diagnostic_tail==20 and c.diagnostic_tail:match('^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$') then
        c.diagnostic_utc_candidate=true
    end
    if #c.raw<c.cap then c.raw=c.raw..ch end
    c.tail=(c.tail..ch):sub(-4)
    if c.ordinary_run and ch=='`' then c.ordinary_ticks=c.ordinary_ticks+1
    else
        c.ordinary_run=false
        if ch=='`' then c.ordinary_valid=false end
        if not whitespace(ch) then c.bare_valid=false end
    end
    if c.leading and whitespace(ch) then return end
    c.leading=false
    c.trimmed_bytes=c.trimmed_bytes+1
    if #c.trimmed<c.cap then c.trimmed=c.trimmed..ch end
    if not whitespace(ch) then
        c.last_nonspace=c.trimmed_bytes
        c.last_tail=c.tail
    end
    if c.ticks_open and ch=='`' then c.ticks=c.ticks+1 else c.ticks_open=false end
    if c.memo_run and (ch=='`' or ch=='~') and (not c.memo_char or c.memo_char==ch) then
        c.memo_char=ch; c.memo_width=c.memo_width+1
    else c.memo_run=false end
    local f=c.footnote
    if f==0 then c.footnote=ch=='[' and 1 or -1
    elseif f==1 then c.footnote=ch=='^' and 2 or -1
    elseif f==2 then c.footnote=ch~=']' and 3 or -1
    elseif f==3 then if ch==']' then c.footnote=4 end
    elseif f==4 then c.footnote=ch==':' and 5 or -1 end
end

local function finish(c)
    local t={bytes=c.bytes,blank=c.leading,divider=c.last_nonspace==3 and c.trimmed:sub(1,3)=='---',
        preface_tag=c.bytes>=5 and c.raw:sub(1,2)=='@@' and c.tail:sub(-2)=='@@',
        footnote=c.footnote==5,diagnostic_utc_candidate=c.diagnostic_utc_candidate,
        diagnostic_reference_candidate=c.diagnostic_reference_candidate}
    -- Outline's existing dialect accepts column-zero levels one through three
    -- followed by a literal space. The retained prefix is enough even for a
    -- multi-megabyte heading; no payload or new unbounded scanner is needed.
    local hashes=c.raw:match('^(#+) ')
    if hashes and #hashes<=3 then t.heading_level=#hashes end
    if c.ticks>=3 then t.render_fence_width=c.ticks end
    if c.memo_width>=3 then t.memo_fence_width=c.memo_width end
    if c.ordinary_ticks>=3 and c.ordinary_valid then t.ordinary_open_width=c.ordinary_ticks end
    if c.ordinary_ticks>=3 and c.bare_valid then t.bare_close_width=c.ordinary_ticks end
    -- Draft grammar is column-zero and permits whitespace in the label.
    local draft=c.raw:sub(1,4)=='=== ' and c.last_tail==' ===' and c.last_nonspace>=9
    local kind='text'
    if t.footnote then kind='footnote'
    elseif draft then
        kind=(c.last_nonspace==11 and c.raw:sub(1,11)=='=== end ===') and 'draft_end' or 'draft_open'
    elseif t.render_fence_width then kind='fence'
    else
        local ending=c.patterns.reasoning_prefix..'[END]'
        if c.last_nonspace==#ending and c.trimmed:sub(1,#ending)==ending then kind='reasoning_end'
        else
            for _,k in ipairs(PREFIXES) do
                local prefix=c.patterns[k..'_prefix']
                if c.raw:sub(1,#prefix)==prefix then kind=k; break end
            end
            if kind=='text' and t.blank then kind='blank' end
        end
    end
    t.kind=kind; t.token=kind=='fence' and ('c'..t.render_fence_width) or TOKENS[kind]
    t.draft_open=kind=='draft_open'; t.draft_end=kind=='draft_end'
    return t
end

-- Snapshot the complete token without consuming the active append cursor.
function M.lex_token(cursor) return finish(cursor) end

-- Consumes at most budget.bytes from this slice. The caller resubmits any
-- unconsumed suffix. eof means this slice ends the line, not the document.
function M.lex_step(cursor, bytes, eof, budget)
    assert(not cursor.finished,'line lexer already finished')
    local limit=math.min(#bytes,(budget or {}).bytes or #bytes)
    assert(limit>=0,'negative byte budget')
    for i=1,limit do scan(cursor,bytes:sub(i,i)) end
    local token
    if eof and limit==#bytes then cursor.finished=true; token=finish(cursor) end
    return cursor,token,{bytes_scanned=limit}
end

function M.lexer_retained_bytes(c) return #c.raw+#c.trimmed+#c.tail+#(c.last_tail or '')+#(c.diagnostic_tail or '') end

return M
