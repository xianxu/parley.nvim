-- review.lua — Document review tool for markdown files.
--
-- Users annotate documents with ㊷[comments], then an LLM agent addresses
-- the comments by rewriting the document. Two editing levels:
--   <C-g>ve = light edit (copy editing, preserve tone/structure)
--   <C-g>vr = heavy revision (substantive rewriting allowed)
--
-- Marker syntax:  ㊷[user]{agent}[user]{agent}...
--   [] = user turns, {} = agent turns, strictly alternating
--   Odd section count = ready for agent, even = awaiting user response

local M = {}

-- Lazily resolved references to parley internals (set after setup() runs).
local _parley  -- main parley module

--- Find the matching closing bracket for an opening bracket at `start`.
--- Handles nested brackets of the same type.
--- @param text string
--- @param start number  position of the opening bracket character
--- @param open string   opening bracket char, e.g. "[" or "{"
--- @param close string  closing bracket char, e.g. "]" or "}"
--- @return number|nil   position of the matching close bracket, or nil
local function find_matching_bracket(text, start, open, close)
    local depth = 0
    for i = start, #text do
        local ch = text:sub(i, i)
        if ch == open then
            depth = depth + 1
        elseif ch == close then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
    end
    return nil
end

--- Parse a single marker starting at the ㊷ position.
--- Returns the list of sections and the end position in the text.
--- @param text string   the full line (or joined text)
--- @param pos number    byte position of the ㊷ character
--- @return table sections  list of {type="user"|"agent", text=string}
--- @return number end_pos  byte position after the last bracket
local function parse_marker_sections(text, pos)
    local sections = {}
    -- Skip past the ㊷ character (it's a 3-byte UTF-8 sequence: E3 8A B7)
    local cursor = pos + 3

    while cursor <= #text do
        local ch = text:sub(cursor, cursor)
        if ch == "[" then
            local close = find_matching_bracket(text, cursor, "[", "]")
            if not close then break end
            table.insert(sections, {
                type = "user",
                text = text:sub(cursor + 1, close - 1),
            })
            cursor = close + 1
        elseif ch == "{" then
            local close = find_matching_bracket(text, cursor, "{", "}")
            if not close then break end
            table.insert(sections, {
                type = "agent",
                text = text:sub(cursor + 1, close - 1),
            })
            cursor = close + 1
        else
            break
        end
    end

    return sections, cursor
end

--- Check if a line index is inside a fenced code block.
--- @param fence_ranges table  list of {start_line, end_line} pairs (0-indexed)
--- @param line_idx number     0-indexed line number
--- @return boolean
local function in_code_fence(fence_ranges, line_idx)
    for _, range in ipairs(fence_ranges) do
        if line_idx >= range[1] and line_idx <= range[2] then
            return true
        end
    end
    return false
end

--- Compute fenced code block ranges from lines.
--- @param lines string[]
--- @return table  list of {start_line, end_line} pairs (0-indexed)
local function compute_fence_ranges(lines)
    local ranges = {}
    local fence_start = nil
    for i, line in ipairs(lines) do
        if line:match("^```") then
            if fence_start then
                table.insert(ranges, { fence_start, i - 1 })
                fence_start = nil
            else
                fence_start = i - 1  -- 0-indexed
            end
        end
    end
    -- Unclosed fence extends to end of document
    if fence_start then
        table.insert(ranges, { fence_start, #lines - 1 })
    end
    return ranges
end

--- Parse all ㊷ markers in a list of lines.
--- @param lines string[]  buffer lines
--- @return table[]  list of {line=0-indexed, col=0-indexed byte, sections=[], ready=bool}
function M.parse_markers(lines)
    local fence_ranges = compute_fence_ranges(lines)
    local markers = {}

    -- ㊷ is U+32B7, UTF-8 bytes: E3 8A B7
    local marker_char = "㊷"

    for i, line in ipairs(lines) do
        if not in_code_fence(fence_ranges, i - 1) then
            local search_start = 1
            while true do
                local pos = line:find(marker_char, search_start, true)
                if not pos then break end

                local sections, end_pos = parse_marker_sections(line, pos)
                if #sections > 0 then
                    local ready = (#sections % 2) == 1  -- odd = ready
                    table.insert(markers, {
                        line = i - 1,          -- 0-indexed
                        col = pos - 1,         -- 0-indexed byte offset
                        sections = sections,
                        ready = ready,
                        raw = line:sub(pos, end_pos - 1),
                    })
                end
                search_start = end_pos
            end
        end
    end

    return markers
end

--- Apply a list of {old_string, new_string, explain} edits to a file.
--- Edits are applied in reverse document order to prevent position shifts.
--- @param file_path string
--- @param edits table[]  list of {old_string, new_string, explain}
--- @return table  {ok=bool, msg=string, applied=table[]}
function M.apply_edits(file_path, edits)
    local f, err = io.open(file_path, "r")
    if not f then
        return { ok = false, msg = "cannot open: " .. (err or file_path), applied = {} }
    end
    local content = f:read("*a")
    f:close()

    -- Find positions of all old_strings, validate they exist and are unique
    local positioned = {}
    for idx, edit in ipairs(edits) do
        if type(edit.old_string) ~= "string" or type(edit.new_string) ~= "string" then
            return {
                ok = false,
                msg = "edit #" .. idx .. " missing old_string or new_string: " .. vim.inspect(edit),
                applied = {},
            }
        end
        local pos = content:find(edit.old_string, 1, true)
        if not pos then
            return {
                ok = false,
                msg = "old_string not found: " .. edit.old_string:sub(1, 60),
                applied = {},
            }
        end
        -- Check uniqueness
        local second = content:find(edit.old_string, pos + 1, true)
        if second then
            return {
                ok = false,
                msg = "old_string not unique: " .. edit.old_string:sub(1, 60),
                applied = {},
            }
        end
        table.insert(positioned, {
            pos = pos,
            old_string = edit.old_string,
            new_string = edit.new_string,
            explain = edit.explain,
        })
    end

    -- Sort by position descending (reverse document order)
    table.sort(positioned, function(a, b) return a.pos > b.pos end)

    -- Apply edits bottom-to-top
    local applied = {}
    for _, edit in ipairs(positioned) do
        content = content:sub(1, edit.pos - 1)
            .. edit.new_string
            .. content:sub(edit.pos + #edit.old_string)
        table.insert(applied, {
            pos = edit.pos,
            old_string = edit.old_string,
            new_string = edit.new_string,
            explain = edit.explain,
        })
    end

    -- Write back
    local wf, werr = io.open(file_path, "w")
    if not wf then
        return { ok = false, msg = "cannot write: " .. (werr or file_path), applied = {} }
    end
    wf:write(content)
    wf:close()

    return {
        ok = true,
        msg = "Applied " .. #applied .. " edit(s)",
        applied = applied,
    }
end

--------------------------------------------------------------------------------
-- System prompts
--------------------------------------------------------------------------------

local SYSTEM_PREAMBLE = [[You are a collaborative document editor. The user has annotated their markdown document with review comments using ㊷[comment] markers.

Marker syntax — strictly alternating turns:
  ㊷[user comment]{agent question}[user reply]{agent question}...
- [] brackets are always user comments or responses
- {} brackets are always your (agent) questions
- If a marker has a conversation (e.g. ㊷[comment]{question}[answer]), the user has answered your question — now address it using that full context.

IMPORTANT: You MUST use the review_edit tool for ALL responses — both edits AND clarification questions. Never respond with plain text. If you need to ask a clarification question, use review_edit to replace the marker with ㊷[original comment]{your question}. Include all changes in a single review_edit call. The old_string must include the ㊷ marker and enough surrounding context to be unique in the document.]]

local SYSTEM_EDIT_SUFFIX = [[

Editing level: LIGHT EDIT (copy editing)

Rules:
- Fix only what each comment points out. Do not rewrite surrounding text.
- Preserve the author's structure, tone, voice, and wording.
- Make the minimum change that addresses the comment.
- When a comment's intent is ambiguous, ask — don't guess.
  Use review_edit to replace the marker with ㊷[original comment]{your question} and do NOT edit surrounding text.]]

local SYSTEM_REVISE_SUFFIX = [[

Editing level: HEAVY REVISION (substantive editing)

Rules:
- You have license to rewrite paragraphs, restructure sections, and make substantial changes to address each comment.
- Preserve the author's core intent and meaning, but feel free to change wording, tone, structure, and flow.
- Address the spirit of the comment, not just the literal request.
- When a comment's intent is ambiguous, make your best judgment and explain in the edit's explanation field. Only ask via {} for truly unclear cases.]]

--- review_edit tool definition (private — not in global registry)
local REVIEW_EDIT_TOOL = {
    name = "review_edit",
    description = "Edit a document to address review comments. Each edit replaces "
        .. "old_string with new_string and includes an explanation.",
    input_schema = {
        type = "object",
        properties = {
            file_path = { type = "string", description = "Absolute path to the file" },
            edits = {
                type = "array",
                items = {
                    type = "object",
                    properties = {
                        old_string = { type = "string", description = "Exact text to find and replace" },
                        new_string = { type = "string", description = "Replacement text" },
                        explain = { type = "string", description = "Brief explanation of why this change was made" },
                    },
                    required = { "old_string", "new_string", "explain" },
                },
            },
        },
        required = { "file_path", "edits" },
    },
}

--------------------------------------------------------------------------------
-- Diagnostics and highlights
--------------------------------------------------------------------------------

local DIAG_NS = "parley_review"
local HL_NS = "parley_review_hl"

local diag_ns_id  -- lazily created
local hl_ns_id    -- lazily created

local function ensure_namespaces()
    if not diag_ns_id then
        diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
    end
    if not hl_ns_id then
        hl_ns_id = vim.api.nvim_create_namespace(HL_NS)
    end
end

--- Clear previous review diagnostics and highlights from a buffer.
local function clear_review_decorations(buf)
    ensure_namespaces()
    vim.diagnostic.reset(diag_ns_id, buf)
    vim.api.nvim_buf_clear_namespace(buf, hl_ns_id, 0, -1)
end

--- Attach INFO diagnostics from edit explanations.
--- @param buf number
--- @param edits table[]  applied edits with {pos, explain, new_string}
--- @param original_content string  file content before edits (to compute line numbers)
function M.attach_diagnostics(buf, edits, original_content)
    ensure_namespaces()
    local diagnostics = {}
    for _, edit in ipairs(edits) do
        -- Compute line number from byte position in original content
        local line_num = 0
        for _ in original_content:sub(1, edit.pos):gmatch("\n") do
            line_num = line_num + 1
        end
        table.insert(diagnostics, {
            lnum = line_num,
            col = 0,
            message = edit.explain or "edit applied",
            severity = vim.diagnostic.severity.INFO,
            source = "parley-review",
        })
    end
    vim.diagnostic.set(diag_ns_id, buf, diagnostics)
end

--- Highlight edited regions. Persists until next submit or explicit clear.
--- @param buf number
--- @param edits table[]  applied edits with {pos, new_string}
--- @param new_content string  file content after edits (to compute line ranges)
function M.highlight_edits(buf, edits, new_content)
    ensure_namespaces()
    for _, edit in ipairs(edits) do
        local new_pos = new_content:find(edit.new_string, 1, true)
        if new_pos then
            local start_line = 0
            for _ in new_content:sub(1, new_pos):gmatch("\n") do
                start_line = start_line + 1
            end
            local end_line = start_line
            for _ in edit.new_string:gmatch("\n") do
                end_line = end_line + 1
            end
            for line = start_line, end_line do
                vim.api.nvim_buf_add_highlight(buf, hl_ns_id, "DiffChange", line, 0, -1)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Quickfix helpers
--------------------------------------------------------------------------------

--- Populate quickfix with markers that need user attention.
--- @param buf number
--- @param markers table[]  parsed markers
--- @param filter string  "pending" (even section count) or "all"
function M.populate_quickfix(buf, markers, filter)
    local file_name = vim.api.nvim_buf_get_name(buf)
    local items = {}
    for _, marker in ipairs(markers) do
        local include = (filter ~= "pending") or (not marker.ready)
        if include then
            local last_section = marker.sections[#marker.sections]
            local text = last_section and (last_section.type == "agent"
                and "Agent asks: " .. last_section.text
                or "User: " .. last_section.text) or marker.raw
            table.insert(items, {
                filename = file_name,
                lnum = marker.line + 1,  -- quickfix is 1-indexed
                col = marker.col + 1,
                text = text,
            })
        end
    end
    vim.fn.setqflist(items, "r")
    if #items > 0 then
        vim.cmd("copen")
    end
end

--------------------------------------------------------------------------------
-- Agent resolution
--------------------------------------------------------------------------------

--- Resolve which agent to use for review.
--- Priority: config review_agent > last-used agent > first tool-capable agent
--- @return table|nil  agent record, or nil with warning
local function resolve_review_agent()
    _parley = _parley or require("parley")

    -- 1. Configured review agent
    local review_agent_name = _parley.config.review_agent
    if review_agent_name and review_agent_name ~= "" then
        local agent = _parley.get_agent(review_agent_name)
        if agent then return agent end
    end

    -- 2. Last-used agent (current)
    local agent = _parley.get_agent()
    if agent and agent.provider then
        local provider = agent.provider
        if provider == "anthropic" or provider == "cliproxyapi" then
            return agent
        end
    end

    -- 3. First agent with tool-capable provider
    for name, rec in pairs(_parley.agents or {}) do
        if rec.provider == "anthropic" or rec.provider == "cliproxyapi" then
            return _parley.get_agent(name)
        end
    end

    _parley.logger.warning("Review requires an agent with tool-use support (Anthropic provider)")
    return nil
end

--------------------------------------------------------------------------------
-- Submit review
--------------------------------------------------------------------------------

--- Submit the current buffer for review.
--- @param buf number
--- @param level string  "edit" or "revise"
function M.submit_review(buf, level)
    _parley = _parley or require("parley")

    local file_path = vim.api.nvim_buf_get_name(buf)
    if file_path == "" then
        _parley.logger.warning("Review: buffer has no file path")
        return
    end

    -- Save if modified
    if vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("write")
        end)
    end

    -- Read buffer content
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local markers = M.parse_markers(lines)

    if #markers == 0 then
        -- No markers: clear all review state and notify done
        clear_review_decorations(buf)
        vim.fn.setqflist({}, "r")
        pcall(vim.cmd, "cclose")
        _parley.logger.info("Review: complete — highlights cleared")
        return
    end

    -- Check for pending markers (even section count = needs user response)
    local pending = {}
    for _, marker in ipairs(markers) do
        if not marker.ready then
            table.insert(pending, marker)
        end
    end

    if #pending > 0 then
        M.populate_quickfix(buf, pending, "pending")
        _parley.logger.warning("Review: " .. #pending .. " marker(s) need your response")
        return
    end

    -- Resolve agent
    local agent = resolve_review_agent()
    if not agent then return end

    -- Build system prompt
    local system_prompt = SYSTEM_PREAMBLE
    if level == "edit" then
        system_prompt = system_prompt .. SYSTEM_EDIT_SUFFIX
    else
        system_prompt = system_prompt .. SYSTEM_REVISE_SUFFIX
    end

    -- Build messages
    local doc_content = table.concat(lines, "\n")
    local messages = {
        { role = "system", content = system_prompt },
        { role = "user", content = "Please review and edit this document (file: " .. file_path .. "):\n\n" .. doc_content },
    }

    -- Build payload
    local dispatcher = _parley.dispatcher
    local payload = dispatcher.prepare_payload(messages, agent.model, agent.provider)

    -- Add review_edit tool to payload (private, not from registry)
    payload.tools = payload.tools or {}
    table.insert(payload.tools, {
        name = REVIEW_EDIT_TOOL.name,
        description = REVIEW_EDIT_TOOL.description,
        input_schema = REVIEW_EDIT_TOOL.input_schema,
    })

    -- Clear previous decorations
    clear_review_decorations(buf)

    _parley.logger.info("Review: submitting to " .. agent.name .. " (" .. level .. " mode)...")

    -- Read original file content for diagnostic line computation
    local original_content = doc_content

    -- Headless LLM call
    local tasker = require("parley.tasker")
    local providers = require("parley.providers")

    dispatcher.query(
        nil,             -- buf: nil for headless
        agent.provider,
        payload,
        function(_qid, _chunk)
            -- No-op streaming handler (headless)
        end,
        function(qid)
            -- on_exit: access raw_response for tool call extraction
            vim.schedule(function()
                local qt = tasker.get_query(qid)
                if not qt then
                    _parley.logger.error("Review: query not found")
                    return
                end

                local raw_response = qt.raw_response or ""
                local tool_calls = providers.decode_anthropic_tool_calls_from_stream(raw_response)

                -- Log all tool calls for debugging
                for _, call in ipairs(tool_calls) do
                    _parley.logger.debug("Review: tool call: " .. call.name .. " input: " .. vim.inspect(call.input))
                end

                -- Find the review_edit tool call
                local review_call = nil
                for _, call in ipairs(tool_calls) do
                    if call.name == "review_edit" then
                        review_call = call
                        break
                    end
                end

                if not review_call then
                    _parley.logger.warning("Review: agent returned no edits")
                    return
                end

                local input = review_call.input or {}
                _parley.logger.debug("Review: tool input: " .. vim.inspect(input))
                local edits = input.edits or {}

                if #edits == 0 then
                    _parley.logger.warning("Review: agent returned empty edits")
                    return
                end

                -- Log if file_path doesn't match (non-fatal — we always edit the current buffer's file)
                local tool_path = input.file_path or ""
                if tool_path ~= "" and tool_path ~= file_path then
                    _parley.logger.debug("Review: agent returned path " .. tool_path .. ", using " .. file_path)
                end

                -- Apply edits to file
                local result = M.apply_edits(file_path, edits)
                if not result.ok then
                    _parley.logger.error("Review: " .. result.msg)
                    return
                end

                -- Reload buffer
                pcall(vim.cmd, "checktime")

                -- Read new content for highlight computation
                local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local new_content = table.concat(new_lines, "\n")

                -- Highlight edits and attach diagnostics
                M.highlight_edits(buf, result.applied, new_content)
                M.attach_diagnostics(buf, result.applied, original_content)

                _parley.logger.info("Review: applied " .. #result.applied .. " edit(s)")

                -- Re-scan for remaining markers
                local remaining = M.parse_markers(new_lines)
                if #remaining == 0 then
                    _parley.logger.info("Review: all comments addressed")
                    return
                end

                -- Check if remaining markers have agent questions
                local has_questions = false
                for _, marker in ipairs(remaining) do
                    if not marker.ready then
                        has_questions = true
                        break
                    end
                end

                if has_questions then
                    M.populate_quickfix(buf, remaining, "pending")
                    _parley.logger.info("Review: agent has follow-up questions")
                else
                    -- Agent missed some markers — auto-resubmit once
                    _parley.logger.info("Review: " .. #remaining .. " marker(s) remain, resubmitting...")
                    M.submit_review(buf, level)
                end
            end)
        end,
        nil  -- callback: not needed, using on_exit
    )
end

--------------------------------------------------------------------------------
-- Setup (called from init.lua)
--------------------------------------------------------------------------------

--- Register review keybindings on a markdown buffer.
--- @param buf number
function M.setup_keymaps(buf)
    _parley = _parley or require("parley")
    local cfg = _parley.config
    local set_keymap = _parley.helpers.set_keymap

    -- <C-g>vi: insert ㊷[] marker
    local insert_cfg = cfg.review_shortcut_insert
    if insert_cfg then
        for _, mode in ipairs(insert_cfg.modes or {}) do
            if mode == "v" or mode == "x" then
                -- Visual mode: wrap selection
                set_keymap({ buf }, mode, insert_cfg.shortcut, function()
                    -- Get selection, wrap with ㊷[ and ]
                    local start_pos = vim.fn.getpos("'<")
                    local end_pos = vim.fn.getpos("'>")
                    local start_line = start_pos[2]
                    local start_col = start_pos[3]
                    local end_line = end_pos[2]
                    local end_col = end_pos[3]

                    if start_line == end_line then
                        local line = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1]
                        local before = line:sub(1, start_col - 1)
                        local selected = line:sub(start_col, end_col)
                        local after = line:sub(end_col + 1)
                        vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, {
                            before .. "㊷[" .. selected .. "]" .. after,
                        })
                    end
                end, "Parley review: wrap selection with marker")
            else
                -- Normal/insert mode: insert ㊷[] and position cursor
                set_keymap({ buf }, mode, insert_cfg.shortcut, function()
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local row = cursor[1] - 1
                    local col = cursor[2]
                    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
                    local before = line:sub(1, col)
                    local after = line:sub(col + 1)
                    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {
                        before .. "㊷[]" .. after,
                    })
                    -- Position cursor inside [] (after ㊷[ which is 3+1=4 bytes)
                    vim.api.nvim_win_set_cursor(0, { row + 1, col + 4 })
                    -- Enter insert mode
                    vim.cmd("startinsert")
                end, "Parley review: insert marker")
            end
        end
    end

    -- <C-g>ve: light edit
    local edit_cfg = cfg.review_shortcut_edit
    if edit_cfg then
        for _, mode in ipairs(edit_cfg.modes or {}) do
            set_keymap({ buf }, mode, edit_cfg.shortcut, function()
                M.submit_review(buf, "edit")
            end, "Parley review: light edit")
        end
    end

    -- <C-g>vr: heavy revision
    local revise_cfg = cfg.review_shortcut_revise
    if revise_cfg then
        for _, mode in ipairs(revise_cfg.modes or {}) do
            set_keymap({ buf }, mode, revise_cfg.shortcut, function()
                M.submit_review(buf, "revise")
            end, "Parley review: heavy revision")
        end
    end
end

return M
