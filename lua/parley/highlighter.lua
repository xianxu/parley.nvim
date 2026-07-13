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
local structure_caches = {}

local function resolve_path(path, base_dir)
    return _parley.resolve_chat_path(path, base_dir)
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
-- Structural state comes from the buffer cache; only the requested rows are read.
local function compute_chat_highlights(buf, start_line, end_line, reader, structure, lines)
    reader = reader or require("parley.line_reader").for_buffer(buf)
    local result = {}
    local highlight_structure = require("parley.highlight_structure")
    local patterns = highlight_structure.patterns(_parley.config)
    lines = lines or reader:lines(start_line - 1, end_line, false)
    local footer_range = highlight_structure.footer_range(structure, vim.api.nvim_buf_line_count(buf))
    -- While a stream is in flight for this buffer, the model has not
    -- yet emitted 🧠:[END]. Assume explicit-end mode so blank-line
    -- paragraph breaks inside the in-progress thinking region keep
    -- their dim highlight instead of prematurely terminating the
    -- block. After the stream completes (is_busy → false), the
    -- lookahead-decided mode takes over and a real [END] / structural
    -- marker controls termination.
    local streaming = require("parley.tasker").is_busy(buf, true)
    local initial = highlight_structure.state_before(structure, start_line - 1, { streaming = streaming })
    local in_block = initial.in_question
    local in_code_block = initial.in_code
    local in_reasoning_block = initial.in_reasoning
    local in_reasoning_explicit_end = initial.reasoning_explicit_end
    local in_tool_block = initial.in_tool

    for offset, line in ipairs(lines) do
        local line_nr = start_line + offset - 1
        local line_kind = highlight_structure.classify(line, patterns).kind
        if line_kind == "fence" then
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

        local is_footer = footer_range and row >= footer_range.start_row
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
            local classification = highlight_structure.classify(line, patterns)
            local kind = classification.kind
            local is_user = kind == "user"
            local is_assistant = kind == "assistant"
            local is_branch = kind == "branch"
            local is_local = kind == "local"
            local is_summary = kind == "summary"
            local is_tool_use = kind == "tool_use"
            local is_tool_result = kind == "tool_result"
            if is_user or is_assistant or is_branch or is_local
                or is_summary or is_tool_use or is_tool_result then
                in_reasoning_block = false
            end

            if kind == "reasoning_end" then
                -- 🧠:[END] explicit terminator. Highlight the marker line
                -- itself as ParleyThinking (it's the closing delimiter of
                -- the thinking region), then close the block. Must be
                -- checked before reasoning_pattern since the END marker
                -- also starts with the reasoning prefix.
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                in_reasoning_block = false
            elseif kind == "reasoning" then
                table.insert(result[row], { hl_group = "ParleyThinking", col_start = 0, col_end = -1 })
                in_reasoning_block = true
                -- The structure owns terminator lookahead. Streaming is only
                -- a redraw-time overlay for an unfinished reasoning block.
                local after = highlight_structure.state_before(structure, row + 1, { streaming = streaming })
                in_reasoning_explicit_end = after.reasoning_explicit_end
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
        result[row].line_length = #line
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
    local structure = require("parley.highlight_structure").build(lines)
    local blocks = {}
    for _, range in ipairs(structure.draft_ranges) do
        blocks[#blocks + 1] = {
            open_row = range.start_row,
            close_row = range.end_row_exclusive - 1,
        }
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
local function compute_markdown_highlights(buf, start_line, end_line, reader, structure, lines)
    reader = reader or require("parley.line_reader").for_buffer(buf)
    local result = {}
    local branch_prefix = _parley.config.chat_branch_prefix or "🌿:"
    lines = lines or reader:lines(start_line - 1, end_line, false)
    local footer_range = require("parley.highlight_structure").footer_range(
        structure, vim.api.nvim_buf_line_count(buf))
    for offset, line in ipairs(lines) do
        local row = start_line + offset - 2
        push_artifact_refs(result, row, line) -- #160: navigable artifact refs
        if footer_range and row >= footer_range.start_row then
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

    -- Draft-block backgrounds come from the buffer-owned structure, so an
    -- opener above the viewport paints visible body lines without another read.
    local blocks = {}
    for _, range in ipairs(require("parley.highlight_structure").draft_blocks_in(
        structure, start_line - 1, end_line)) do
        blocks[#blocks + 1] = {
            open_row = range.start_row,
            close_row = range.end_row_exclusive - 1,
        }
    end
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

    for row, highlights in pairs(result) do
        local line = lines[row - (start_line - 1) + 1] or ""
        highlights.line_length = #line
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

        local lines = require("parley.line_reader").for_buffer(buf):lines(range.start_line - 1, range.end_line, false)
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
        local lines = require("parley.line_reader").for_buffer(buf):lines(range.start_line - 1, range.end_line, false)
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
                local latest_lines = require("parley.line_reader").for_buffer(buf):lines(range.start_line - 1, range.end_line, false)
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
    local cache = structure_caches[buf]
    if not cache or cache.dirty then
        local rebuilt, err = M.rebuild_structure(buf)
        assert(rebuilt, err)
        cache = structure_caches[buf]
    end
    local ns = M.setup_highlights()
    local ranges = get_visible_line_ranges(buf)

    for _, range in ipairs(ranges) do
        vim.api.nvim_buf_clear_namespace(buf, ns, range.start_line - 1, range.end_line)
    end

    for _, range in ipairs(ranges) do
        local reader = require("parley.line_reader").for_buffer(buf)
        local row_map = compute_chat_highlights(buf, range.start_line, range.end_line, reader, cache.structure)
        for row, hls in pairs(row_map) do
            for _, hl in ipairs(hls) do
                vim.api.nvim_buf_add_highlight(buf, ns, hl.hl_group, row, hl.col_start, hl.col_end)
            end
        end
    end
end

-- Production compute seam shared by the decoration provider and isolated
-- performance runners. Scan breadth intentionally remains unchanged.
local function compute_window_decorations(_winid, buf, toprow, botrow, reader, structure)
    reader = reader or require("parley.line_reader").for_buffer(buf)
    local buf_type = _parley._parley_bufs[buf]
    if not structure then return nil end
    local start_line = toprow + 1
    local line_count = vim.api.nvim_buf_line_count(buf)
    local end_line = math.min(botrow + 1 + HIGHLIGHT_VIEWPORT_MARGIN, line_count)
    local lines = reader:lines(toprow, end_line, false)
    if buf_type == "chat" then
        return compute_chat_highlights(buf, start_line, end_line, reader, structure, lines)
    elseif buf_type == "markdown" then
        return compute_markdown_highlights(buf, start_line, end_line, reader, structure, lines)
    end
    return {}
end

M._compute_window_decorations = compute_window_decorations

local function build_structure(buf)
    local reader = require("parley.line_reader").for_buffer(buf)
    local lines = reader:lines(0, -1, false)
    local structure, rows, work = require("parley.highlight_structure").build(
        lines, require("parley.highlight_structure").patterns(_parley.config))
    require("parley.line_reader").record_work(buf, {
        operation = "structure_build",
        structure_rows_processed = work and work.rows_visited or rows,
    })
    return structure
end

function M.rebuild_structure(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return nil, "invalid buffer" end
    local existing = structure_caches[buf]
    if existing and existing.renderable and not existing.dirty then
        return existing.structure
    end
    local ok, candidate = pcall(build_structure, buf)
    if not ok then
        local cache = structure_caches[buf]
        if cache then cache.dirty = true; cache.renderable = false end
        return nil, candidate
    end
    local cache = structure_caches[buf] or {}
    cache.structure = candidate
    cache.dirty = false
    cache.renderable = true
    structure_caches[buf] = cache
    if not cache.attached then
        local generation = {}
        cache.generation = generation
        cache.on_lines = function(_, changed_buf, _, firstline, lastline, new_lastline)
            local current = structure_caches[changed_buf]
            if not current or current.generation ~= generation or not vim.api.nvim_buf_is_valid(changed_buf) then
                return true
            end
            local reader = require("parley.line_reader").for_buffer(changed_buf)
            local new_lines = reader:lines(firstline, new_lastline, false)
            local replaced, rows, reason = require("parley.highlight_structure").replace(
                current.structure, firstline, lastline, new_lines,
                require("parley.highlight_structure").patterns(_parley.config))
            require("parley.line_reader").record_work(changed_buf, {
                operation = "structure_replace", structure_rows_processed = rows,
            })
            if reason then
                current.dirty = true
                current.renderable = false
            else
                current.structure = replaced
            end
        end
        cache.on_detach = function(_, detached_buf)
            if structure_caches[detached_buf] and structure_caches[detached_buf].generation == generation then
                structure_caches[detached_buf] = nil
            end
        end
        local attached = vim.api.nvim_buf_attach(buf, false, {
            on_lines = cache.on_lines,
            on_detach = function(_, detached_buf)
                cache.on_detach(nil, detached_buf)
            end,
        })
        if not attached then
            structure_caches[buf] = nil
            return nil, "failed to attach structure cache"
        end
        cache.attached = true
    end
    return candidate
end

function M.clear_structure(buf)
    structure_caches[buf] = nil
    require("parley.line_reader").clear_buffer(buf)
end

M._structure_cache = function(buf) return structure_caches[buf] end

M.setup_buf_handler = function()
    local interview = require("parley.interview")
    local buffer_lifecycle = require("parley.buffer_lifecycle")
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
            local structure_cache = structure_caches[bufnr]
            if not structure_cache or structure_cache.dirty or not structure_cache.renderable then
                return false
            end
            local line_reader = require("parley.line_reader")
            local reader = line_reader.for_buffer(bufnr)
            local row_map = line_reader.with_phase(bufnr, "decoration_redraw", function()
                return compute_window_decorations(
                    winid, bufnr, toprow, botrow, reader, structure_cache.structure)
            end)

            _decor_cache[winid] = {
                bufnr = bufnr,
                rows = row_map or {},
            }
        end,
        on_line = function(_, winid, bufnr, row)
            local cache = _decor_cache[winid]
            if not cache or cache.bufnr ~= bufnr then return end
            local highlights = cache.rows[row]

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
                            end_col = highlights.line_length
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
            buffer_lifecycle.setup(buf)
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
            buffer_lifecycle.setup(buf)
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
        -- Handle non-chat markdown files
        elseif _parley.is_markdown(buf, file_name) then
            interview.highlight_timestamps(buf)
        end
    end, gid)

    -- LineReader state must be invalidated synchronously: the generic helper
    -- schedules callbacks, leaving a window where Neovim could reuse the
    -- numeric buffer handle and expose the prior buffer's observer.
    vim.api.nvim_create_autocmd({ "BufDelete", "BufUnload" }, {
        group = gid,
        callback = function(event)
            M.clear_structure(event.buf)
        end,
    })

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
        if _parley._branch_topic_timers and _parley._branch_topic_timers[buf] then
            stop_and_close_timer(_parley._branch_topic_timers[buf])
            _parley._branch_topic_timers[buf] = nil
        end
    end, gid)
end

return M
