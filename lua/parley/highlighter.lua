-- Parley - Highlighter module
-- Buffer decoration provider, highlight group setup, and agent display logic.

local M = {}
local _parley

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- Local helpers
--------------------------------------------------------------------------------

-- push_artifact_refs marks ariadne artifact refs (ariadne#11, #15 M4, pair#84,
-- gh#42) in a line so they read as navigable (#160). Shared by the chat and
-- markdown compute paths so the two can't diverge. Uses artifact_ref.iter_refs —
-- the SAME loose detector the resolve keymap uses; sdlc resolve owns acceptance,
-- so this highlights ref-*shaped* tokens (a jump on an unresolvable one just
-- surfaces sdlc's error). Entry shape matches the module: col_start 0-indexed,
-- col_end exclusive (iter_refs' byte_end is one-past, so col_end = e - 1).
local function push_artifact_refs(result, row, line)
    local artifact_ref = require("parley.artifact_ref")
    for _, span in ipairs(artifact_ref.highlight_spans(line)) do
        result[row] = result[row] or {}
        table.insert(result[row], {
            hl_group = "ParleyArtifactRef",
            col_start = span.col_start,
            col_end = span.col_end,
        })
    end
end

local function stop_and_close_timer(timer)
    if not timer then
        return
    end

    local ok, is_closing = pcall(function()
        return timer:is_closing()
    end)
    if ok and is_closing then
        return
    end

    pcall(function()
        timer:stop()
    end)

    ok, is_closing = pcall(function()
        return timer:is_closing()
    end)
    if ok and is_closing then
        return
    end

    pcall(function()
        timer:close()
    end)
end

local HIGHLIGHT_VIEWPORT_MARGIN = 20
local HIGHLIGHT_CONTEXT_LINES = 200

local function resolve_path(path, base_dir)
    return _parley.resolve_chat_path(path, base_dir)
end


local function get_chat_highlight_prefix_patterns()
    local user_prefix = _parley.config.chat_user_prefix
    local local_prefix = _parley.config.chat_local_prefix
    local memory_enabled = _parley.config.chat_memory and _parley.config.chat_memory.enable
    local reasoning_prefix = memory_enabled and _parley.config.chat_memory.reasoning_prefix or "🧠:"
    local summary_prefix = memory_enabled and _parley.config.chat_memory.summary_prefix or "📝:"

    local assistant_prefix
    if type(_parley.config.chat_assistant_prefix) == "string" then
        assistant_prefix = _parley.config.chat_assistant_prefix
    elseif type(_parley.config.chat_assistant_prefix) == "table" then
        assistant_prefix = _parley.config.chat_assistant_prefix[1]
    end

    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    return {
        reasoning_pattern = "^" .. vim.pesc(reasoning_prefix),
        reasoning_end_pattern = "^%s*" .. vim.pesc(reasoning_prefix) .. "%[END%]%s*$",
        summary_pattern = "^" .. vim.pesc(summary_prefix),
        user_pattern = "^" .. vim.pesc(user_prefix),
        assistant_pattern = "^" .. vim.pesc(assistant_prefix),
        local_pattern = "^" .. vim.pesc(local_prefix),
        branch_pattern = "^" .. vim.pesc(branch_prefix),
    }
end

-- Hard cap on how far forward the buffer-aware lookahead will scan
-- when deciding a reasoning block's termination mode. Reasoning blocks
-- in practice are well under this; the cap exists to bound work on a
-- pathologically long buffer with no terminator.
local REASONING_LOOKAHEAD_MAX = 500

-- Scan forward from a 🧠: opener at 1-indexed `from_line` in the buffer
-- to decide the block's termination mode. Returns true if a 🧠:[END]
-- marker appears before the next structural marker — explicit-end mode
-- (blank lines inside the block stay highlighted as ParleyThinking).
--
-- Reads directly from the buffer rather than a line slice so the result
-- is consistent regardless of the visible viewport. The earlier
-- slice-based lookahead missed [END] markers that fell beyond the
-- prefix_lines / visible window, causing continuation lines to lose
-- their dim highlight whenever the viewport top fell between 🧠: and
-- 🧠:[END]. Mirrors the parser's lookahead in chat_parser.lua.
local function reasoning_block_has_end_marker(buf, from_line, patterns)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local stop = math.min(from_line + REASONING_LOOKAHEAD_MAX, line_count)
    if from_line + 1 > stop then return false end
    local ahead_lines = vim.api.nvim_buf_get_lines(buf, from_line, stop, false)
    for _, ahead in ipairs(ahead_lines) do
        if ahead:match(patterns.reasoning_end_pattern) then
            return true
        end
        if ahead:match(patterns.user_pattern)
            or ahead:match(patterns.assistant_pattern)
            or ahead:match(patterns.local_pattern)
            or ahead:match(patterns.summary_pattern)
            or ahead:match(patterns.branch_pattern)
            or ahead:match("^🔧:")
            or ahead:match("^📎:") then
            return false
        end
    end
    return false
end

local function bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)
    if start_line <= 1 then
        return false, false, false, false
    end

    local scan_start = math.max(1, start_line - HIGHLIGHT_CONTEXT_LINES)
    local bootstrap_start = scan_start
    local bootstrap_in_block = false

    while bootstrap_start > 1 do
        local previous_lines = vim.api.nvim_buf_get_lines(buf, bootstrap_start - 2, bootstrap_start - 1, false)
        local previous_line = previous_lines[1] or ""
        if previous_line:match(patterns.user_pattern) then
            bootstrap_in_block = true
            break
        end
        if previous_line:match(patterns.assistant_pattern) or previous_line:match(patterns.local_pattern) then
            bootstrap_in_block = false
            break
        end
        bootstrap_start = bootstrap_start - 1
    end

    local in_block = bootstrap_in_block
    local in_code_block = false
    local in_reasoning_block = false
    if start_line <= bootstrap_start then
        return in_block, in_code_block, in_reasoning_block, false
    end

    local prefix_lines = vim.api.nvim_buf_get_lines(buf, bootstrap_start - 1, start_line - 1, false)
    local in_reasoning_explicit_end = false
    for idx, line in ipairs(prefix_lines) do
        if line:match("^%s*```") then
            in_code_block = not in_code_block
        end

        if line:match(patterns.user_pattern) then
            in_block = true
            in_reasoning_block = false
        elseif line:match(patterns.assistant_pattern) or line:match(patterns.local_pattern) then
            in_block = false
            in_reasoning_block = false
        elseif line:match(patterns.branch_pattern)
            or line:match(patterns.summary_pattern)
            or line:match("^🔧:")
            or line:match("^📎:") then
            in_reasoning_block = false
        elseif line:match(patterns.reasoning_end_pattern) then
            -- 🧠:[END] explicit terminator. Checked before
            -- reasoning_pattern since the END marker also starts with
            -- the reasoning prefix.
            in_reasoning_block = false
        elseif line:match(patterns.reasoning_pattern) then
            in_reasoning_block = true
            -- prefix_lines starts at bootstrap_start (1-indexed). The
            -- 🧠: opener at array index `idx` corresponds to buffer
            -- line `bootstrap_start + idx - 1`. The buffer-aware
            -- lookahead scans forward from there into the live buffer
            -- so it sees [END] markers that fall outside prefix_lines.
            -- During streaming the [END] marker hasn't been emitted
            -- yet, so optimistically assume explicit-end mode — blank
            -- lines inside the in-progress reasoning stay dimmed
            -- instead of prematurely terminating the block.
            if streaming then
                in_reasoning_explicit_end = true
            else
                local opener_line_nr = bootstrap_start + idx - 1
                in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, opener_line_nr, patterns)
            end
        elseif in_reasoning_block and line:match("^%s*$") and not in_reasoning_explicit_end then
            in_reasoning_block = false
        end
    end

    return in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end
end

local function merge_line_ranges(ranges)
    if #ranges <= 1 then
        return ranges
    end

    table.sort(ranges, function(a, b)
        return a.start_line < b.start_line
    end)

    local merged = {}
    for _, range in ipairs(ranges) do
        local last = merged[#merged]
        if not last or range.start_line > (last.end_line + 1) then
            table.insert(merged, { start_line = range.start_line, end_line = range.end_line })
        else
            last.end_line = math.max(last.end_line, range.end_line)
        end
    end

    return merged
end

local function get_visible_line_ranges(buf, margin)
    margin = margin or HIGHLIGHT_VIEWPORT_MARGIN
    local line_count = vim.api.nvim_buf_line_count(buf)
    local ranges = {}

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == buf then
            local ok, bounds = pcall(vim.api.nvim_win_call, win, function()
                return { top = vim.fn.line("w0"), bottom = vim.fn.line("w$") }
            end)
            if ok and bounds then
                local start_line = math.max(1, (bounds.top or 1) - margin)
                local end_line = math.min(line_count, (bounds.bottom or line_count) + margin)
                if start_line <= end_line then
                    table.insert(ranges, { start_line = start_line, end_line = end_line })
                end
            end
        end
    end

    if #ranges == 0 and line_count > 0 then
        table.insert(ranges, { start_line = 1, end_line = line_count })
    end

    return merge_line_ranges(ranges)
end

-- Compute desired chat highlights for a 1-indexed line range.
-- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
-- Scans HIGHLIGHT_CONTEXT_LINES above start_line for block state context.
local function compute_chat_highlights(buf, start_line, end_line)
    local result = {}
    local patterns = get_chat_highlight_prefix_patterns()
    local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
    -- While a stream is in flight for this buffer, the model has not
    -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
    -- paragraph breaks inside the in-progress thinking region keep
    -- their dim highlight instead of prematurely terminating the
    -- block. After the stream completes (is_busy → false), the
    -- lookahead-decided mode takes over and a real [END] / structural
    -- marker controls termination.
    local streaming = require("parley.tasker").is_busy(buf, true)
    local in_block, in_code_block, in_reasoning_block, in_reasoning_explicit_end =
        bootstrap_chat_highlight_state(buf, start_line, patterns, streaming)

    local in_tool_block = false  -- inside 🔧:/📎: fenced content

    for offset, line in ipairs(lines) do
        local line_nr = start_line + offset - 1
        if line:match("^%s*```") then
            in_code_block = not in_code_block
            -- Exiting a code block while in a tool region ends the tool region
            if not in_code_block and in_tool_block then
                in_tool_block = false
            end
        end

        local highlighted_regions = {}
        local row = line_nr - 1

        result[row] = result[row] or {}

        push_artifact_refs(result, row, line) -- #160: navigable artifact refs

        local is_footer = footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line
        if is_footer then
            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
            in_block = false
        else
            local pos = 1
            while true do
                local tag_start, content_start = line:find("@@", pos)
                if not tag_start then break end
                local content_end, tag_end = line:find("@@", content_start + 1)
                if not content_end then break end
                table.insert(highlighted_regions, { start = tag_start, finish = tag_end })
                table.insert(result[row], { hl_group = "ParleyTag", col_start = tag_start - 1, col_end = tag_end })
                pos = tag_end + 1
            end

            -- Any structural marker terminates an in-progress reasoning
            -- block. This mirrors chat_parser's lenient termination so the
            -- highlight tracks parse boundaries even when the model omits
            -- the canonical blank-line terminator (or in pre-existing
            -- chats authored under the old single-line 🧠: convention).
            local is_user = line:match(patterns.user_pattern)
            local is_assistant = line:match(patterns.assistant_pattern)
            local is_branch = line:match(patterns.branch_pattern)
            local is_local = line:match(patterns.local_pattern)
            local is_summary = line:match(patterns.summary_pattern)
            local is_tool_use = line:match("^🔧:")
            local is_tool_result = line:match("^📎:")
            if is_user or is_assistant or is_branch or is_local
                or is_summary or is_tool_use or is_tool_result then
                in_reasoning_block = false
            end

            if line:match(patterns.reasoning_end_pattern) then
                -- 🧠:[END] explicit terminator. Highlight the marker line
                -- itself as ParleyThinking (it's the closing delimiter of
                -- the thinking region), then close the block. Must be
                -- checked before reasoning_pattern since the END marker
                -- also starts with the reasoning prefix.
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                in_reasoning_block = false
            elseif line:match(patterns.reasoning_pattern) then
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                in_reasoning_block = true
                -- Buffer-aware lookahead: line_nr is the current 1-indexed
                -- buffer line. Scanning the live buffer (rather than the
                -- visible `lines` slice) catches [END] markers that fall
                -- below the viewport bottom, which is the common case
                -- after the cursor has moved up into the thinking region.
                -- While streaming, force explicit-end mode (see comment at
                -- the top of compute_chat_highlights).
                if streaming then
                    in_reasoning_explicit_end = true
                else
                    in_reasoning_explicit_end = reasoning_block_has_end_marker(buf, line_nr, patterns)
                end
            elseif is_summary or line:match("^👂:") then
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
            elseif is_tool_use or is_tool_result then
                -- Tool block headers — dim (plumbing, not prose)
                if line:match("error=true") then
                    table.insert(result[row], { hl_group = "ParleyToolError", col_start = 0, col_end = -1 })
                else
                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                end
                in_tool_block = true
            elseif in_tool_block and not in_block then
                -- Inside tool block fenced content — dim
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
            elseif in_reasoning_block then
                -- Multi-line thinking continuation. In legacy mode (no
                -- 🧠:[END] marker downstream) blank line terminates; in
                -- explicit-end mode blank lines are preserved as part of
                -- the reasoning region and stay dimmed. Non-blank lines
                -- always stay dimmed as ParleyThinking.
                if line:match("^%s*$") and not in_reasoning_explicit_end then
                    in_reasoning_block = false
                else
                    table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                end
            elseif is_user then
                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
                in_block = true
            elseif is_assistant then
                in_block = false
            elseif is_branch then
                table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
                in_block = false
            elseif is_local then
                in_block = false
            elseif in_block and not in_code_block then
                table.insert(result[row], { hl_group = "ParleyQuestion", col_start = 0, col_end = -1 })
                if line:match("^@@") then
                    local is_tag_at_start = false
                    if #highlighted_regions > 0 and highlighted_regions[1].start == 1 then
                        is_tag_at_start = true
                    end
                    if not is_tag_at_start then
                        table.insert(result[row], { hl_group = "ParleyFileReference", col_start = 0, col_end = -1 })
                    end
                end
            end

            for start_idx, _, end_idx in line:gmatch("()@(.-)@()") do
                table.insert(result[row], { hl_group = "ParleyAnnotation", col_start = start_idx - 1, col_end = end_idx - 1 })
            end
        end
    end

    return result
end

-- Pure scanner for draft-block markers.
-- A block opens at any line matching `^=== <label> ===$` where label != "end",
-- and closes at the next `^=== end ===$`. Unmatched closers are ignored; an
-- unmatched opener extends to EOF. No nesting — a second opener while a block
-- is open is ignored.
-- Returns { { open_row, close_row }, ... } in 0-indexed inclusive coords.
local function scan_draft_blocks(lines)
    local blocks = {}
    local open_row = nil
    for i, line in ipairs(lines) do
        local label = line:match("^=== (.+) ===%s*$")
        if label then
            if label == "end" then
                if open_row then
                    table.insert(blocks, { open_row = open_row, close_row = i - 1 })
                    open_row = nil
                end
            elseif not open_row then
                open_row = i - 1
            end
        end
    end
    if open_row then
        table.insert(blocks, { open_row = open_row, close_row = #lines - 1 })
    end
    return blocks
end

M._scan_draft_blocks = scan_draft_blocks

-- Is the bracketed run `[content]` at byte range [s, e) a drill-in
-- referenced-span marker (#127), versus an incidental bracket? Pure predicate
-- — plain `[]` is ambiguous, so this is a heuristic. `line` is the whole line,
-- `s` = byte of `[`, `e` = byte just past `]`. Rejects:
--   * markdown links `](`           — `[text](url)`
--   * footnote refs                 — `[^1]`
--   * 1-char content                — `[ ]`, `[x]`, `[1]`
--   * a *live* 🤖 marker's section   — `[U]` chained after 🤖 / `>` / `~` / a
--                                     prior `]`/`}` close (already highlighted
--                                     ParleyReviewUser; don't double-mark it).
-- A flattened reference span's `[` follows ordinary prose, so it passes.
function M.is_reference_span(line, s, content, e)
    if line:sub(e, e) == "(" then return false end
    if content:sub(1, 1) == "^" then return false end
    if #content < 2 then return false end
    local prev = line:sub(s - 1, s - 1)
    if prev == "]" or prev == "}" or prev == ">" or prev == "~" then return false end
    if s > 4 and line:sub(s - 4, s - 1) == "🤖" then return false end
    return true
end

-- Compute desired markdown highlights for a 1-indexed line range.
-- Returns a table keyed by 0-indexed row: { [row] = { {hl_group, col_start, col_end}, ... } }
local function compute_markdown_highlights(buf, start_line, end_line)
    local result = {}
    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local footer_range = require("parley.define").managed_footnote_footer_range(all_lines)
    for offset, line in ipairs(lines) do
        local row = start_line + offset - 2
        local line_nr = row + 1
        push_artifact_refs(result, row, line) -- #160: navigable artifact refs
        if footer_range and line_nr >= footer_range.start_line and line_nr <= footer_range.end_line then
            result[row] = result[row] or {}
            table.insert(result[row], { hl_group = "ParleyFootnote", col_start = 0, col_end = -1 })
        end
        if line:sub(1, #branch_prefix) == branch_prefix then
            result[row] = result[row] or {}
            table.insert(result[row], { hl_group = "ParleyChatReference", col_start = 0, col_end = -1 })
        end
        -- Highlight 🤖<...>[...]{...} review markers
        local review = require("parley.review")
        local search_start = 1
        while true do
            local pos = line:find("🤖", search_start, true)
            if not pos then break end
            local sections, end_pos, quoted, strike = review._parse_marker_sections(line, pos, 4)
            if quoted then
                -- Highlight the 🤖 + `<…>` together so the whole "this marker
                -- refers to a precise quote" prefix reads as one unit.
                result[row] = result[row] or {}
                table.insert(result[row], {
                    hl_group = "ParleyReviewQuoted",
                    col_start = pos - 1,             -- 0-indexed pos of 🤖
                    col_end = quoted.byte_end,       -- inclusive close `>`
                })
            elseif strike then
                -- Strikethrough for the `~X~` content (custom rendering — we
                -- own this since markdown's strikethrough is disabled
                -- buffer-wide to avoid false positives on `~/path` tildes).
                result[row] = result[row] or {}
                table.insert(result[row], {
                    hl_group = "ParleyReviewStrike",
                    col_start = pos - 1,             -- 0-indexed pos of 🤖
                    col_end = strike.byte_end,       -- inclusive close `~`
                })
            end
            for _, section in ipairs(sections) do
                local hl = section.type == "agent" and "ParleyReviewAgent" or "ParleyReviewUser"
                result[row] = result[row] or {}
                table.insert(result[row], {
                    hl_group = hl,
                    col_start = section.byte_start - 1,  -- 0-indexed
                    col_end = section.byte_end,           -- exclusive end
                })
            end
            search_start = end_pos
        end

        -- #127: highlight drill-in referenced-span markers `[…]` left in the
        -- reply (what each gathered comment points at) via the pure
        -- M.is_reference_span heuristic. Disable via mark_reference_span = false.
        if _parley.config.mark_reference_span ~= false then
            for s, content, e in line:gmatch("()%[([^%[%]]+)%]()") do
                if M.is_reference_span(line, s, content, e) then
                    result[row] = result[row] or {}
                    table.insert(result[row], {
                        hl_group = "ParleyReference",
                        col_start = s - 1, -- 0-indexed `[`
                        col_end = e - 1,   -- exclusive end (through `]`)
                    })
                end
            end
        end
    end

    -- Draft-block backgrounds (=== label === / === end ===). Full-buffer
    -- scan so a block opened far above the viewport still paints visible
    -- body lines. Bg-only highlight; markdown fg shows through.
    local blocks = scan_draft_blocks(all_lines)
    local view_from = start_line - 1
    local view_to = end_line - 1
    for _, block in ipairs(blocks) do
        local from = math.max(block.open_row, view_from)
        local to = math.min(block.close_row, view_to)
        for row = from, to do
            result[row] = result[row] or {}
            -- Multi-line range (row,0 → row+1,0) + hl_eol paints bg past EOL
            -- so short and empty lines inside the block still get the shaded
            -- background. Same trick diff/cursorline use.
            table.insert(result[row], {
                hl_group = "ParleyDraftBlock",
                col_start = 0,
                draft_block = true,
            })
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- Exported functions
--------------------------------------------------------------------------------

--- Returns the bare tool indicator symbol ("🔧") when the agent has a
--- non-empty client-side tools list (M1 Task 1.7 of #81), else "".
--- Callers concatenate this with other indicators (web_search, etc.)
--- and wrap the whole group with a single pair of square brackets.
--- Pure; no _parley state dependency so it can be reused from lualine,
--- highlighter, and the agent picker.
---@param ag_conf table|nil agent config table (from _parley.agents[name])
---@return string
M.agent_tool_badge = function(ag_conf)
    if ag_conf and type(ag_conf.tools) == "table" and #ag_conf.tools > 0 then
        return "🔧"
    end
    return ""
end

--- Returns the bare web-search indicator symbol ("🌎" or "🌎?") based on
--- _parley._state.web_search and the agent's provider/model support.
--- Returns "" when web_search is off. Pure w.r.t. ag_conf but reads
--- _parley._state.web_search.
--- Defensive: returns "" when _parley is not yet injected (e.g. isolated
--- unit tests that load the module without running parley.setup()).
---@param ag_conf table|nil agent config table
---@return string
M.agent_web_search_badge = function(ag_conf)
    if not _parley or not (_parley._state and _parley._state.web_search) then
        return ""
    end

    local prov = require("parley.providers")
    local model_conf = ag_conf and ag_conf.model or nil
    local supported = ag_conf and prov.has_feature(ag_conf.provider, "web_search", model_conf)
    local resolved_provider = ag_conf and prov.resolve_name(ag_conf.provider) or nil
    local requires_search_model = false
    if resolved_provider == "openai" then
        requires_search_model = true
    elseif resolved_provider == "cliproxyapi" then
        local strategy = prov.get_web_search_strategy(ag_conf.provider, model_conf) or "none"
        requires_search_model = strategy == "openai_search_model"
    end

    if supported and requires_search_model then
        if type(model_conf) == "table" and not model_conf.search_model then
            supported = false
        end
    end

    return supported and "🌎" or "🌎?"
end

--- Build the agent display name with a combined `[🔧🌎]`-style indicator
--- group wrapping any enabled badges. Returns just the bare name when
--- no badges apply.
--- Historical name — kept for backward compat with callers that already
--- use it. The behavior changed in M1 Task 1.7: tool + web are now
--- combined into a single bracket group.
M.agent_display_name_with_web_search = function(agent_name, ag_conf)
    local indicators = M.agent_tool_badge(ag_conf) .. M.agent_web_search_badge(ag_conf)
    if indicators == "" then
        return agent_name
    end
    return agent_name .. "[" .. indicators .. "]"
end

M.display_agent = function(buf, file_name)
    if _parley.not_chat(buf, file_name) then
        return
    end

    if buf ~= vim.api.nvim_get_current_buf() then
        return
    end

    -- Stable namespace (not keyed by file_name) so the badge is correctly
    -- replaced when the chat is auto-renamed by topic-slug. Previously the
    -- per-filename namespace meant a renamed buffer kept its old extmark in
    -- the prior namespace and the new badge was rendered alongside it.
    local ns_id = vim.api.nvim_create_namespace("ParleyChatExt")
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    local agent = _parley._state.agent
    local ag_conf = _parley.agents[agent]
    local display_name = M.agent_display_name_with_web_search(agent, ag_conf)
    vim.api.nvim_buf_set_extmark(buf, ns_id, 0, 0, {
        strict = false,
        right_gravity = true,
        virt_text_pos = "right_align",
        virt_text = {
            { "[" .. display_name .. "]", "DiagnosticHint" },
        },
        hl_mode = "combine",
    })
end

-- Define namespace and highlighting colors for questions, annotations, and thinking
M.setup_highlights = function()
    -- Set up namespace
    local ns = vim.api.nvim_create_namespace("parley_question")

    -- Create theme-agnostic highlight groups that work in both light and dark themes
    -- Check for user-defined highlight settings
    local user_highlights = _parley.config.highlight or {}

    -- Questions - Create a highlight that stands out but works in both themes
    -- Link to existing highlights when possible for theme compatibility
    if user_highlights.question then
        -- Use user-defined highlighting if provided
        vim.api.nvim_set_hl(0, "ParleyQuestion", user_highlights.question)
    else
        vim.api.nvim_set_hl(0, "ParleyQuestion", {
            link = "Keyword", -- Keyword is usually a standout color in most themes
        })
    end

    -- File references - Should stand out similar to questions but with special emphasis
    if user_highlights.file_reference then
        vim.api.nvim_set_hl(0, "ParleyFileReference", user_highlights.file_reference)
    else
        vim.api.nvim_set_hl(0, "ParleyFileReference", {
            link = "WarningMsg", -- Use built-in warning colors which work across themes
        })
    end

    -- Thinking/reasoning - Should be dimmed but visible in both themes
    if user_highlights.thinking then
        vim.api.nvim_set_hl(0, "ParleyThinking", user_highlights.thinking)
    else
        vim.api.nvim_set_hl(0, "ParleyThinking", {
            link = "Comment", -- Comments are usually appropriately dimmed in all themes
        })
    end

    -- Tool error results — visually distinct from normal tool blocks
    if user_highlights.tool_error then
        vim.api.nvim_set_hl(0, "ParleyToolError", user_highlights.tool_error)
    else
        vim.api.nvim_set_hl(0, "ParleyToolError", {
            link = "DiagnosticError",
        })
    end

    -- Annotations - Use existing highlight groups that work across themes
    if user_highlights.annotation then
        vim.api.nvim_set_hl(0, "ParleyAnnotation", user_highlights.annotation)
    else
        vim.api.nvim_set_hl(0, "ParleyAnnotation", {
            link = "DiffAdd", -- Usually a green background with appropriate text color
        })
    end

    -- Chat branch/parent links (🌿: lines)
    if user_highlights.chat_reference then
        vim.api.nvim_set_hl(0, "ParleyChatReference", user_highlights.chat_reference)
    else
        vim.api.nvim_set_hl(0, "ParleyChatReference", {
            link = "Special",
        })
    end

    -- Inline branch links [🌿:text](file) — display text as underlined link
    if user_highlights.inline_branch then
        vim.api.nvim_set_hl(0, "ParleyInlineBranch", user_highlights.inline_branch)
    else
        vim.api.nvim_set_hl(0, "ParleyInlineBranch", {
            underline = true,
            link = "Special",
        })
    end

    -- Referenced-span markers `[…]` left in a reply by drill-in (#127): the
    -- text a gathered comment points at. Underline reads as "this span is
    -- marked" without the weight of a full background. Override via
    -- config.highlight.reference.
    if user_highlights.reference then
        vim.api.nvim_set_hl(0, "ParleyReference", user_highlights.reference)
    else
        vim.api.nvim_set_hl(0, "ParleyReference", { underline = true })
    end

    -- Managed definition-footnote footer (from the first `[^id]: ...`). It must be
    -- independent of the surrounding chat exchange color.
    if user_highlights.footnote then
        vim.api.nvim_set_hl(0, "ParleyFootnote", user_highlights.footnote)
    else
        vim.api.nvim_set_hl(0, "ParleyFootnote", { link = "DiagnosticHint" })
    end

    -- Artifact refs (ariadne#11, #15 M4, pair#84) left navigable by #160.
    -- Underline reads as "this is a jumpable ref" without a heavy background.
    -- Override via config.highlight.artifact_ref.
    if user_highlights.artifact_ref then
        vim.api.nvim_set_hl(0, "ParleyArtifactRef", user_highlights.artifact_ref)
    else
        vim.api.nvim_set_hl(0, "ParleyArtifactRef", { underline = true })
    end

    -- Tags - Highlighted tags in @@tag@@ format
    if user_highlights.tag then
        vim.api.nvim_set_hl(0, "ParleyTag", user_highlights.tag)
    else
        vim.api.nvim_set_hl(0, "ParleyTag", {
            link = "Todo", -- Link to Todo highlight group which is highly visible in most themes
        })
    end

    -- Picker typo-tolerance edits - distinct from exact Search highlights
    if user_highlights.approximate_match then
        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", user_highlights.approximate_match)
    else
        vim.api.nvim_set_hl(0, "ParleyPickerApproximateMatch", {
            link = "IncSearch",
        })
    end

    -- Draft block backgrounds — bg-only so markdown fg/syntax shows through.
    -- CursorLine is themed to be visibly-but-subtly shifted from Normal in
    -- every colorscheme, which is exactly what we want. User can override
    -- via config.highlight.draft_block.
    if user_highlights.draft_block then
        vim.api.nvim_set_hl(0, "ParleyDraftBlock", user_highlights.draft_block)
    else
        vim.api.nvim_set_hl(0, "ParleyDraftBlock", { link = "CursorLine" })
    end

    -- Review markers — 🤖[user comment] in markdown files
    vim.api.nvim_set_hl(0, "ParleyReviewUser", { link = "DiagnosticWarn" })
    -- Review markers — {agent question} in 🤖 marker chains
    vim.api.nvim_set_hl(0, "ParleyReviewAgent", { link = "DiagnosticInfo" })
    -- Review markers — <quoted body> identifying the text the chain refers to.
    -- Reverse + bold makes `🤖<…>` pop against any colorscheme so the user
    -- can spot the precise-quote scope at a glance.
    vim.api.nvim_set_hl(0, "ParleyReviewQuoted", { reverse = true, bold = true })
    -- Review markers — ~strike~ proposed-deletion body. Strikethrough is
    -- the visual cue per the review-convention target. Markdown's native
    -- strikethrough is disabled buffer-wide (see disable_strikethrough)
    -- so this is the only place strikethrough renders.
    vim.api.nvim_set_hl(0, "ParleyReviewStrike", { strikethrough = true })
    -- Accept/reject flash animation (<M-a>/<M-r>). The resolver flashes removed
    -- text red and inserted text green. Theme diff groups (DiffDelete/DiffAdd)
    -- are too muted in many colorschemes — often a grey "filler" delete and a
    -- pale add — so we set explicit, loud red/green backgrounds with a white
    -- foreground for contrast. A flash is transient and meant to grab the eye;
    -- subtlety defeats the purpose. Users can override these two groups.
    vim.api.nvim_set_hl(0, "ParleyReviewFlashDelete",
        { bg = "#d13438", fg = "#ffffff", ctermbg = 160, ctermfg = 231 })
    vim.api.nvim_set_hl(0, "ParleyReviewFlashInsert",
        { bg = "#2ea043", fg = "#ffffff", ctermbg = 34, ctermfg = 231 })

    -- Interview timestamps - Highlighted timestamp lines like :15min
    -- Use only background color to allow search highlights to show through
    local diffadd_hl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
    vim.api.nvim_set_hl(0, "InterviewTimestamp", {
        bg = diffadd_hl.bg or diffadd_hl.background,
        -- Explicitly don't set fg to allow other highlights to show through
    })

    -- Interview thoughts - {text} rendered in a distinct color via theme-aware link
    vim.api.nvim_set_hl(0, "InterviewThought", { link = "DiagnosticInfo" })

    return ns
end

--- Disable markdown strikethrough rendering in a buffer.
--- Tilde (~) in file paths like ~/workspace/file.md triggers false strikethrough.
M.disable_strikethrough = function(buf)
	-- Treesitter: clear strikethrough highlight groups
	vim.api.nvim_set_hl(0, "@markup.strikethrough", {})
	vim.api.nvim_set_hl(0, "@markup.strikethrough.markdown_inline", {})
	-- Vim syntax fallback (when treesitter is not active)
	pcall(vim.api.nvim_buf_call, buf, function()
		vim.cmd("silent! syntax clear markdownStrike")
	end)
end


-- Render a single 🌿: branch line, filling in the topic from the referenced file.
-- Returns the updated line, or the original if no change is needed.
M.render_chat_branch_line = function(line, base_dir)
    local parsed = _parley._parse_branch_ref(line)
    if not parsed then
        return line
    end

    local expanded = resolve_path(parsed.path, base_dir)
    local file_exists = vim.fn.filereadable(expanded) == 1

    local topic = file_exists and _parley.get_chat_topic(expanded) or nil
    local warning = file_exists and "" or " ⚠️"
    local display_topic = (topic and topic ~= "") and topic or parsed.topic

    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    local new_line = branch_prefix .. " " .. parsed.path .. ": " .. display_topic .. warning
    if new_line == line then return line end
    return new_line
end

-- Apply extmark-based highlighting for inline branch links [🌿:text](file).
-- Conceals [ and ](path), showing 🌿:text with ParleyInlineBranch style.
local function highlight_inline_branch_links(buf, ranges)
    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    local chat_parser = require("parley.chat_parser")
    local ns = vim.api.nvim_create_namespace("parley_inline_branch")

    for _, range in ipairs(ranges) do
        -- Clear existing extmarks in this range
        vim.api.nvim_buf_clear_namespace(buf, ns, range.start_line - 1, range.end_line)

        local lines = vim.api.nvim_buf_get_lines(buf, range.start_line - 1, range.end_line, false)
        for offset, line in ipairs(lines) do
            local links = chat_parser.extract_inline_branch_links(line, branch_prefix)
            local line_idx = range.start_line + offset - 2 -- 0-indexed

            for _, link in ipairs(links) do
                local col_start_0 = link.col_start - 1

                -- Conceal the opening [ bracket
                vim.api.nvim_buf_set_extmark(buf, ns, line_idx, col_start_0, {
                    end_col = col_start_0 + #"[",
                    conceal = "",
                })

                -- Highlight 🌿:topic
                local text_start = col_start_0 + #"["
                local text_end = col_start_0 + #("[" .. branch_prefix) + #link.topic
                vim.api.nvim_buf_set_extmark(buf, ns, line_idx, text_start, {
                    end_col = text_end,
                    hl_group = "ParleyInlineBranch",
                })

                -- Conceal the ](path) part
                vim.api.nvim_buf_set_extmark(buf, ns, line_idx, text_end, {
                    end_col = link.col_end,
                    conceal = "",
                })
            end
        end
    end
end

-- Refresh topic labels for 🌿: branch references in chat buffers.
-- Debounced topic refresh for 🌿: branch references and inline [🌿:text](file) links.
M.highlight_chat_branch_refs = function(buf)
    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    local chat_parser = require("parley.chat_parser")
    local ranges = get_visible_line_ranges(buf)
    local has_branch_refs = false
    local has_inline_branches = false

    for _, range in ipairs(ranges) do
        local lines = vim.api.nvim_buf_get_lines(buf, range.start_line - 1, range.end_line, false)
        for _, line in ipairs(lines) do
            if line:sub(1, #branch_prefix) == branch_prefix then
                has_branch_refs = true
            end
            if #chat_parser.extract_inline_branch_links(line, branch_prefix) > 0 then
                has_inline_branches = true
            end
            if has_branch_refs and has_inline_branches then break end
        end
        if has_branch_refs and has_inline_branches then break end
    end

    -- Always apply inline branch highlighting if present (no debounce needed)
    if has_inline_branches then
        highlight_inline_branch_links(buf, ranges)
    end

    _parley._branch_topic_timers = _parley._branch_topic_timers or {}
    local existing_timer = _parley._branch_topic_timers[buf]
    if existing_timer then
        stop_and_close_timer(existing_timer)
        _parley._branch_topic_timers[buf] = nil
    end

    if not has_branch_refs then
        return
    end

    local TOPIC_REFRESH_DEBOUNCE_MS = 500
    local timer = vim.uv.new_timer()
    _parley._branch_topic_timers[buf] = timer
    timer:start(
        TOPIC_REFRESH_DEBOUNCE_MS,
        0,
        vim.schedule_wrap(function()
            stop_and_close_timer(timer)
            if _parley._branch_topic_timers[buf] ~= timer then
                return
            end
            _parley._branch_topic_timers[buf] = nil
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end

            local base_dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":h")
            local refresh_ranges = get_visible_line_ranges(buf)
            for _, range in ipairs(refresh_ranges) do
                local latest_lines = vim.api.nvim_buf_get_lines(buf, range.start_line - 1, range.end_line, false)
                for offset, line in ipairs(latest_lines) do
                    local updated_line = M.render_chat_branch_line(line, base_dir)
                    if updated_line ~= line then
                        local line_nr = range.start_line + offset - 1
                        vim.api.nvim_buf_set_lines(buf, line_nr - 1, line_nr, false, { updated_line })
                    end
                end
            end

            vim.cmd("redraw")
        end)
    )
end


-- Apply highlighting to chat blocks in the current buffer.
-- Simple clear-and-apply; used by tests on scratch buffers.
-- Production highlighting is handled by the decoration provider.
M.highlight_question_block = function(buf)
    local ns = M.setup_highlights()
    local ranges = get_visible_line_ranges(buf)

    for _, range in ipairs(ranges) do
        vim.api.nvim_buf_clear_namespace(buf, ns, range.start_line - 1, range.end_line)
    end

    for _, range in ipairs(ranges) do
        local row_map = compute_chat_highlights(buf, range.start_line, range.end_line)
        for row, hls in pairs(row_map) do
            for _, hl in ipairs(hls) do
                vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, row, hl.col_start, hl.col_end)
            end
        end
    end
end

M.setup_buf_handler = function()
    local interview = require("parley.interview")
    local skill_render = require("parley.skill_render")
    local timezone_diagnostics = require("parley.timezone_diagnostics")
    local gid = _parley.helpers.create_augroup("ParleyBufHandler", { clear = true })

    -- Register decoration provider: highlights are computed synchronously
    -- during Neovim's redraw cycle using ephemeral extmarks, just like
    -- built-in syntax highlighting. Zero flicker, always up-to-date.
    local decor_ns = M.setup_highlights()
    local _decor_cache = {} -- winid → { bufnr = number, rows = { [row] = { ... } } }

    vim.api.nvim_set_decoration_provider(decor_ns, {
        on_buf = function(_, bufnr, _)
            if not _parley._parley_bufs[bufnr] then
                return false
            end
        end,
        on_win = function(_, winid, bufnr, toprow, botrow)
            if not _parley._parley_bufs[bufnr] then
                return false
            end
            local buf_type = _parley._parley_bufs[bufnr]
            local start_line = toprow + 1
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            local end_line = math.min(botrow + 1 + HIGHLIGHT_VIEWPORT_MARGIN, line_count)
            local row_map = nil

            if buf_type == "chat" then
                row_map = compute_chat_highlights(bufnr, start_line, end_line)
            elseif buf_type == "markdown" then
                row_map = compute_markdown_highlights(bufnr, start_line, end_line)
            end

            _decor_cache[winid] = {
                bufnr = bufnr,
                rows = row_map or {},
            }
        end,
        on_line = function(_, winid, bufnr, row)
            local cache = _decor_cache[winid]
            if not cache or cache.bufnr ~= bufnr then return end
            local highlights = cache.rows[row]
            local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)
            local line = lines[1] or ""

            if highlights then
                for _, hl in ipairs(highlights) do
                    if hl.draft_block then
                        -- Multi-line range so hl_eol can extend bg past EOL.
                        pcall(vim.api.nvim_buf_set_extmark, bufnr, decor_ns, row, 0, {
                            end_row = row + 1,
                            end_col = 0,
                            hl_group = hl.hl_group,
                            hl_eol = true,
                            ephemeral = true,
                            priority = 100,
                        })
                    else
                        local end_col = hl.col_end
                        if end_col == -1 then
                            end_col = #line
                        end
                        pcall(vim.api.nvim_buf_set_extmark, bufnr, decor_ns, row, hl.col_start, {
                            end_row = row,
                            end_col = end_col,
                            hl_group = hl.hl_group,
                            ephemeral = true,
                            -- 200 > treesitter's default 100, so our marker
                            -- highlights win over markdown syntax (which
                            -- otherwise paints `<Amazon>` as an HTML tag).
                            priority = 200,
                        })
                    end
                end
            end
        end,
    })

    -- Setup functions that only need to run when buffer is first loaded or entered
    _parley.helpers.autocmd({ "BufEnter" }, nil, function(event)
        local buf = event.buf

        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        local file_name = vim.api.nvim_buf_get_name(buf)

        -- Handle chat files
        if _parley.not_chat(buf, file_name) == nil then
            _parley._parley_bufs[buf] = "chat"
            _parley.prep_chat(buf, file_name)
            _parley.display_agent(buf, file_name)
            interview.highlight_timestamps(buf)
            timezone_diagnostics.refresh_buffer(buf)
            skill_render.refresh_footnote_diagnostics(buf)
            _parley.highlight_chat_branch_refs(buf)
            -- Disable markdown strikethrough in chat buffers — tilde (~) in file
            -- paths like ~/workspace/file.md triggers false strikethrough rendering.
            M.disable_strikethrough(buf)
        -- Handle non-chat markdown files
        elseif _parley.is_markdown(buf, file_name) then
            _parley._parley_bufs[buf] = "markdown"
            _parley.prep_md(buf)
            _parley.setup_markdown_keymaps(buf)
            _parley.highlight_chat_branch_refs(buf)
            interview.highlight_timestamps(buf)
            timezone_diagnostics.refresh_buffer(buf)
            skill_render.refresh_footnote_diagnostics(buf)
            -- Disable native markdown strikethrough so only the 🤖-gated
            -- review-deletion strike (🤖~X~, rendered in compute_markdown_highlights)
            -- shows — a bare ~X~ or a `~/path` tilde must not cross out text.
            M.disable_strikethrough(buf)
        end
    end, gid)

    _parley.helpers.autocmd({ "WinEnter" }, nil, function(event)
        local buf = event.buf

        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end

        local file_name = vim.api.nvim_buf_get_name(buf)

        -- Handle chat files
        if _parley.not_chat(buf, file_name) == nil then
            _parley.display_agent(buf, file_name)
            interview.highlight_timestamps(buf)
            timezone_diagnostics.refresh_buffer(buf)
            skill_render.refresh_footnote_diagnostics(buf)
        -- Handle non-chat markdown files
        elseif _parley.is_markdown(buf, file_name) then
            interview.highlight_timestamps(buf)
            timezone_diagnostics.refresh_buffer(buf)
            skill_render.refresh_footnote_diagnostics(buf)
        end
    end, gid)

    _parley.helpers.autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, nil, function(event)
        local buf = event.buf
        if not vim.api.nvim_buf_is_valid(buf) then
            return
        end
        if _parley._parley_bufs[buf] then
            timezone_diagnostics.refresh_buffer(buf)
            skill_render.refresh_footnote_diagnostics(buf)
        end
    end, gid)

    -- Clean up when buffers are deleted
    _parley.helpers.autocmd({ "BufDelete", "BufUnload" }, nil, function(event)
        local buf = event.buf
        _parley._parley_bufs[buf] = nil
        for winid, cache in pairs(_decor_cache) do
            if cache.bufnr == buf then
                _decor_cache[winid] = nil
            end
        end
        interview.clear_match_cache(buf)
        timezone_diagnostics.clear(buf)
        if _parley._branch_topic_timers and _parley._branch_topic_timers[buf] then
            stop_and_close_timer(_parley._branch_topic_timers[buf])
            _parley._branch_topic_timers[buf] = nil
        end
    end, gid)
end

return M
