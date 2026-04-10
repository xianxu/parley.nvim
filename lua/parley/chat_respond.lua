-- parley/chat_respond.lua — LLM response pipeline extracted from init.lua
-- Owns: remote reference cache, _build_messages, _resolve_remote_references,
--       chat_respond, chat_respond_all, resubmit_questions_recursively, cmd.Stop/ChatRespond
local M = {}

-- _parley holds the full parley module (set via M.setup()).
-- All _parley.* accesses are intentionally dynamic so state mutations in init.lua
-- (M.config, M._state, M._remote_reference_cache) are visible here by reference.
local _parley = nil

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- Module-level state shared between async callbacks while responding
-- (mirrors the former init.lua locals `original_free_cursor_value` and `last_content_line`)
--------------------------------------------------------------------------------
local original_free_cursor_value = nil
local last_content_line = nil

--------------------------------------------------------------------------------
-- Local helpers copied from init.lua (functions that are too small to expose
-- on M but are needed inside the extracted functions below)
--------------------------------------------------------------------------------

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

local function find_chat_header_end(lines)
    return _parley.chat_parser.find_header_end(lines)
end

-- Pure function: given an ordered ancestor chain (oldest first), build a flat
-- message list of Q+A pairs up to each level's branch point.
--
-- ancestor_chain: array of { exchanges, branch_after } where:
--   exchanges    = parsed_chat.exchanges from that ancestor file
--   branch_after = number of exchanges to include (exchanges[1..branch_after])
--
-- Returns a flat array of {role, content} tables (no system prompt).
M.build_ancestor_messages = function(ancestor_chain)
    local msgs = {}
    for _, level in ipairs(ancestor_chain) do
        for idx, exchange in ipairs(level.exchanges) do
            if idx > level.branch_after then
                break
            end
            if exchange.question then
                local content = (exchange.question.content or ""):gsub("^%s*(.-)%s*$", "%1")
                if content ~= "" then
                    table.insert(msgs, { role = "user", content = content })
                end
            end
            if exchange.answer then
                -- Use summary when available (mirrors memory-aware answer handling)
                local raw = exchange.summary and exchange.summary.content or exchange.answer.content
                local content = (raw or ""):gsub("^%s*(.-)%s*$", "%1")
                if content ~= "" then
                    table.insert(msgs, { role = "assistant", content = content })
                end
            end
        end
    end
    return msgs
end

-- Resolve a path that may be absolute, ~-prefixed, or relative to base_dir.
local function resolve_path(path, base_dir)
    if path:match("^~/") or path == "~" then
        return vim.fn.resolve(vim.fn.expand(path))
    elseif path:sub(1, 1) == "/" then
        return vim.fn.resolve(path)
    else
        return vim.fn.resolve(base_dir .. "/" .. path)
    end
end

-- Walk the ancestor chain via parent_link, building an ordered list of
-- { exchanges, branch_after } records (oldest ancestor first).
-- Returns an empty table when there is no parent or the parent is unreadable.
local function collect_ancestor_chain(current_file, parsed_chat, depth)
    depth = depth or 0
    if depth > 20 then
        _parley.logger.warning("collect_ancestor_chain: max depth reached, stopping")
        return {}
    end

    if not parsed_chat.parent_link then
        return {}
    end

    local current_dir = vim.fn.fnamemodify(current_file, ":h")
    local abs_parent = resolve_path(parsed_chat.parent_link.path, current_dir)

    if vim.fn.filereadable(abs_parent) == 0 then
        _parley.logger.warning("collect_ancestor_chain: parent file not readable: " .. abs_parent)
        return {}
    end

    local parent_lines = vim.fn.readfile(abs_parent)
    local parent_header_end = find_chat_header_end(parent_lines)
    if not parent_header_end then
        return {}
    end

    local parent_parsed = _parley.parse_chat(parent_lines, parent_header_end)

    -- Find which branch in the parent points back to current_file
    local branch_after = 0
    local current_abs = vim.fn.resolve(current_file)
    local parent_dir = vim.fn.fnamemodify(abs_parent, ":h")
    for _, branch in ipairs(parent_parsed.branches) do
        if resolve_path(branch.path, parent_dir) == current_abs then
            branch_after = branch.after_exchange
            break
        end
    end

    -- Recurse upward first so the chain is ordered oldest → newest
    local chain = collect_ancestor_chain(abs_parent, parent_parsed, depth + 1)
    table.insert(chain, { exchanges = parent_parsed.exchanges, branch_after = branch_after })
    return chain
end

local function collect_ancestor_messages(current_file, parsed_chat)
    local chain = collect_ancestor_chain(current_file, parsed_chat)
    return M.build_ancestor_messages(chain)
end

local function set_chat_topic_line(buf, lines, topic)
    local buffer_edit = require("parley.buffer_edit")
    local header_end = find_chat_header_end(lines)
    if not header_end then
        buffer_edit.set_topic_header_line(buf, 0, "# topic: " .. topic)
        return
    end

    if lines[1] and lines[1]:gsub("^%s*(.-)%s*$", "%1") == "---" then
        for i = 2, header_end - 1 do
            if lines[i]:match("^%s*topic:%s*") then
                buffer_edit.set_topic_header_line(buf, i - 1, "topic: " .. topic)
                return
            end
        end
        buffer_edit.insert_topic_line(buf, 0, "topic: " .. topic)
        return
    end

    buffer_edit.set_topic_header_line(buf, 0, "# topic: " .. topic)
end

local function is_follow_cursor_enabled(override_free_cursor)
    if override_free_cursor ~= nil then
        return override_free_cursor
    end
    if _parley._state.follow_cursor ~= nil then
        return _parley._state.follow_cursor
    end
    return not _parley.config.chat_free_cursor
end

local function query_cursor_line(qt)
    if not qt then
        return nil
    end

    if type(qt.last_line) == "number" and qt.last_line >= 0 then
        return qt.last_line + 1
    end
    if type(qt.first_line) == "number" and qt.first_line >= 0 then
        return qt.first_line + 1
    end

    return nil
end

--------------------------------------------------------------------------------
-- Remote reference cache
--------------------------------------------------------------------------------

M.remote_reference_cache_file = function()
    return _parley.config.state_dir .. "/remote_reference_cache.json"
end

---@return table
M.load_remote_reference_cache = function()
    if _parley._remote_reference_cache ~= nil then
        return _parley._remote_reference_cache
    end

    local cache_file = M.remote_reference_cache_file()
    local cache = {}
    if vim.fn.filereadable(cache_file) ~= 0 then
        cache = _parley.helpers.file_to_table(cache_file) or {}
    end

    cache.chats = cache.chats or {}
    _parley._remote_reference_cache = cache
    return _parley._remote_reference_cache
end

M.save_remote_reference_cache = function()
    local cache = M.load_remote_reference_cache()
    _parley.helpers.prepare_dir(_parley.config.state_dir, "state")
    _parley.helpers.table_to_file(cache, M.remote_reference_cache_file())
end

---@param chat_file string|nil
---@return table
M.get_chat_remote_reference_cache = function(chat_file)
    local cache = M.load_remote_reference_cache()
    local chat_key = chat_file or ""
    cache.chats[chat_key] = cache.chats[chat_key] or {}
    return cache.chats[chat_key]
end

---@param url string
---@param err string|nil
---@return string
M.format_remote_reference_error_content = function(url, err)
    return "File: " .. url .. "\n[Error: " .. (err or "Failed to fetch") .. "]\n\n"
end

---@param url string
---@return string
M.format_missing_remote_reference_cache_content = function(url)
    return M.format_remote_reference_error_content(
        url,
        "Remote URL content is not cached. Refresh the question that introduced this URL to fetch it again."
    )
end

--------------------------------------------------------------------------------
-- cmd.Stop
--------------------------------------------------------------------------------

-- stop receiving responses for all processes and clean the handles
---@param signal number | nil # signal to send to the process
M.cmd_stop = function(signal)
    -- If we were in the middle of a batch resubmission, make sure to restore the cursor setting
    if original_free_cursor_value ~= nil then
        _parley.logger.debug(
            "Stop called during resubmission - restoring chat_free_cursor to: " .. tostring(original_free_cursor_value)
        )
        _parley.config.chat_free_cursor = original_free_cursor_value
        original_free_cursor_value = nil
    end

    _parley.tasker.stop(signal)
end

--------------------------------------------------------------------------------
-- _build_messages
--------------------------------------------------------------------------------

--- Convert an answer's content_blocks list into a sequence of
--- Anthropic-shaped messages for the request payload.
---
--- Anthropic requires a specific interleaving when tool_use is
--- involved: the assistant message emits `[text, tool_use]` content
--- blocks, and the IMMEDIATELY FOLLOWING user message carries the
--- `tool_result` content blocks for those tool_uses. That pattern
--- repeats for every round of the tool loop.
---
--- This helper is the DRY consumer of content_blocks — parallel to
--- lua/parley/tools/serialize.lua which is the producer that
--- renders the same blocks back into buffer text. Together they
--- close the loop: buffer text → chat_parser → content_blocks →
--- build_messages → Anthropic API → streaming decoder → content_blocks
--- → serialize → buffer text.
---
--- Empty input or text-only input still produces a single-assistant
--- message wrapping the text blocks, but in practice this helper is
--- only called when at least one tool_use or tool_result block is
--- present (the text-only path stays on the byte-identical flat
--- string emission in build_messages).
---
--- @param content_blocks table[] list from chat_parser
--- @return table[] messages suitable for dispatcher.prepare_payload
M._emit_content_blocks_as_messages = function(content_blocks)
    local messages = {}
    local current_assistant = nil -- accumulating [text, tool_use] for an assistant message
    local current_user = nil      -- accumulating [tool_result] for a user message

    local function flush_assistant()
        if current_assistant and #current_assistant > 0 then
            table.insert(messages, { role = "assistant", content = current_assistant })
            current_assistant = nil
        end
    end
    local function flush_user()
        if current_user and #current_user > 0 then
            table.insert(messages, { role = "user", content = current_user })
            current_user = nil
        end
    end

    for _, block in ipairs(content_blocks or {}) do
        if block.type == "tool_result" then
            -- Flush any open assistant batch so the tool_result
            -- lands in its own user message directly after.
            flush_assistant()
            current_user = current_user or {}
            table.insert(current_user, {
                type = "tool_result",
                tool_use_id = block.id,
                content = block.content or "",
                is_error = block.is_error == true,
            })
        else
            -- text or tool_use — these belong to an assistant message.
            -- Flush any open user batch first.
            flush_user()
            current_assistant = current_assistant or {}
            if block.type == "text" then
                table.insert(current_assistant, { type = "text", text = block.text or "" })
            elseif block.type == "tool_use" then
                table.insert(current_assistant, {
                    type = "tool_use",
                    id = block.id,
                    name = block.name,
                    input = block.input or {},
                })
            end
        end
    end

    -- Flush whichever role was last accumulating.
    flush_assistant()
    flush_user()

    return messages
end

M.build_messages = function(opts)
    local parsed_chat = opts.parsed_chat
    local start_index = opts.start_index
    local end_index = opts.end_index
    local exchange_idx = opts.exchange_idx
    local agent = opts.agent
    local opts_config = opts.config
    local helpers = opts.helpers
    local logger = opts.logger or { debug = function() end, warning = function() end }

    -- Process headers for agent information
    local headers = parsed_chat.headers

    -- Prepare for summary extraction
    local memory_enabled = opts_config.chat_memory and opts_config.chat_memory.enable

    -- Use header-defined max_full_exchanges if available, otherwise use config value
    local max_exchanges = 999999
    if memory_enabled then
        if headers.config_max_full_exchanges then
            max_exchanges = headers.config_max_full_exchanges
            logger.debug("Using header-defined max_full_exchanges: " .. tostring(max_exchanges))
        else
            max_exchanges = opts_config.chat_memory.max_full_exchanges
        end
    end

    local omit_user_text = memory_enabled and opts_config.chat_memory.omit_user_text or "[Previous messages omitted]"

    -- Get combined agent information using the helper function
    local agent_info = _parley.get_agent_info(headers, agent)

    -- Convert parsed_chat to messages for the model using a single-pass approach
    local messages = { { role = "", content = "" } } -- Start with empty message for system prompt

    -- Process each exchange, determining whether to preserve or summarize
    local total_exchanges = #parsed_chat.exchanges

    -- TRACE #90
    logger.warning(string.format(
        "[#90 trace] build_messages opts: start_index=%s end_index=%s exchange_idx=%s n_exchanges=%d",
        tostring(start_index), tostring(end_index), tostring(exchange_idx), total_exchanges
    ))
    for idx_dump, ex_dump in ipairs(parsed_chat.exchanges) do
        local q_start = ex_dump.question and ex_dump.question.line_start
        local q_end = ex_dump.question and ex_dump.question.line_end
        local a_start = ex_dump.answer and ex_dump.answer.line_start
        local a_end = ex_dump.answer and ex_dump.answer.line_end
        local n_blocks = ex_dump.answer and ex_dump.answer.content_blocks and #ex_dump.answer.content_blocks
        logger.warning(string.format(
            "  exchange[%d]: q=[%s..%s] a=[%s..%s] n_blocks=%s",
            idx_dump, tostring(q_start), tostring(q_end), tostring(a_start), tostring(a_end), tostring(n_blocks)
        ))
    end

    -- Single pass through all exchanges
    for idx, exchange in ipairs(parsed_chat.exchanges) do
        if exchange.question and exchange.question.line_start >= start_index and idx <= exchange_idx then
            -- Determine if this exchange should be preserved in full
            local should_preserve = false

            -- Preserve if this is the current question
            if idx == exchange_idx then
                should_preserve = true
                logger.debug("Exchange #" .. idx .. " preserved as current question")
            end
            -- Preserve if it's a recent exchange (within max_full_exchanges from the end)
            if idx > total_exchanges - max_exchanges then
                should_preserve = true
                logger.debug("Exchange #" .. idx .. " preserved as recent exchange")
            end

            -- Preserve if it contains file references
            if #exchange.question.file_references > 0 then
                should_preserve = true
                logger.debug("Exchange #" .. idx .. " preserved due to file references")
            end

                -- Process the question
                if should_preserve then
                    -- Get the question content and process any file loading directives
                    local question_content = exchange.question.content
                    local file_content_parts = {}

                    -- Handle raw request mode - parse JSON from typed code fences
                    -- Look for ```json {"type": "request"} fences; when present, use as raw payload
                    -- regardless of parse_raw_request toggle (the fence metadata is authoritative)
                    do
                        local json_content = question_content:match('```json%s+{"type":%s*"request"}%s*\n(.-)\n```')

                        if json_content then
                            logger.debug("Found typed JSON request block in question, using raw request mode")

                            -- Try to parse the JSON
                            local success, payload = pcall(vim.json.decode, json_content)
                            if success and type(payload) == "table" then
                                -- Store the raw payload for direct use
                                exchange.question.raw_payload = payload
                                logger.debug("Successfully parsed JSON payload: " .. vim.inspect(payload))
                            else
                                logger.warning("Failed to parse JSON in raw request mode: " .. tostring(payload))
                            end
                        end
                    end

                    -- Use the precomputed file references instead of scanning for them again
                    for _, file_ref in ipairs(exchange.question.file_references) do
                        local path = file_ref.path

                        logger.debug("Processing file reference: " .. path)

                        -- Check if this is a pre-resolved remote reference
                        if opts.resolved_remote_content and opts.resolved_remote_content[path] then
                            table.insert(
                                file_content_parts,
                                "[The following content was already fetched from "
                                    .. path
                                    .. ". Do NOT use web_fetch or web_search to access this URL.]\n"
                                    .. opts.resolved_remote_content[path]
                            )
                        elseif helpers.is_remote_url and helpers.is_remote_url(path) then
                            table.insert(file_content_parts, M.format_missing_remote_reference_cache_content(path))
                        -- Check if this is a directory or has directory pattern markers (* or **/)
                        elseif
                            helpers.is_directory(path)
                            or path:match("/%*%*?/?") -- Contains /** or /**/
                            or path:match("/%*%.%w+$")
                        then -- Contains /*.ext pattern
                            table.insert(file_content_parts, helpers.process_directory_pattern(path))
                        else
                            table.insert(file_content_parts, helpers.format_file_content(path))
                        end
                    end

                    -- Handle provider-specific file reference processing for questions with file references
                    if exchange.question.file_references and #exchange.question.file_references > 0 then
                        -- split user question with file inclusion (@@ pattern) into two messages.
                        -- a system message that contains file content. and a user message containing the question.
                        -- the cache-control key is only needed for Anthropic, but since it doesn't cause problem
                        -- with Google or OpenAI, I'll leave it here.
                        table.insert(messages, {
                            role = "system",
                            content = table.concat(file_content_parts, "\n") .. "\n",
                            cache_control = { type = "ephemeral" },
                        })
                        table.insert(messages, { role = "user", content = question_content })
                    else
                        -- No file references, just add the question as user message
                        table.insert(messages, { role = "user", content = question_content })
                    end
                else
                    -- Use the placeholder text for summarized questions
                    table.insert(messages, { role = "user", content = omit_user_text })
                end

            -- Process the answer if it exists and is within our range.
            -- M2 Task 2.6 of #81: if the answer carries tool_use / tool_result
            -- content_blocks (populated by chat_parser when 🔧:/📎: appear in
            -- the buffer), the CURRENT exchange's partial answer ALSO needs
            -- to be emitted so the tool loop recursion can continue the
            -- conversation with Anthropic. Vanilla resubmit still skips the
            -- current exchange's answer (idx < exchange_idx preserved).
            local answer_has_tool_blocks = false
            if exchange.answer and exchange.answer.content_blocks then
                for _, b in ipairs(exchange.answer.content_blocks) do
                    if b.type == "tool_use" or b.type == "tool_result" then
                        answer_has_tool_blocks = true
                        break
                    end
                end
            end
            -- TRACE #90
            logger.warning(string.format(
                "[#90 trace] build_messages exchange %d: has_answer=%s has_content_blocks=%s n_blocks=%s answer_has_tool_blocks=%s exchange_idx=%s",
                idx,
                tostring(exchange.answer ~= nil),
                tostring(exchange.answer and exchange.answer.content_blocks ~= nil),
                tostring(exchange.answer and exchange.answer.content_blocks and #exchange.answer.content_blocks),
                tostring(answer_has_tool_blocks),
                tostring(exchange_idx)
            ))
            if exchange.answer and exchange.answer.content_blocks then
                for bi, b in ipairs(exchange.answer.content_blocks) do
                    logger.warning(string.format("  block[%d] type=%s kind=%s", bi, tostring(b.type), tostring(b.kind)))
                end
            end
            local include_answer = exchange.answer
                and exchange.answer.line_start <= end_index
                and (idx < exchange_idx or answer_has_tool_blocks)

            if include_answer then
                -- when we preserve due to have file inclusion in question, we still summarize the answer
                if should_preserve and not (exchange.question.file_references and #exchange.question.file_references > 0) then
                    -- Emit the answer. Two paths:
                    --   A. Tool blocks present → split into Anthropic
                    --      content-block messages (assistant[text,tool_use],
                    --      user[tool_result], ...).
                    --   B. No tool blocks → single flat-string assistant
                    --      message (byte-identical to pre-#81).
                    if answer_has_tool_blocks then
                        for _, m in ipairs(M._emit_content_blocks_as_messages(exchange.answer.content_blocks)) do
                            table.insert(messages, m)
                        end
                    else
                        table.insert(messages, { role = "assistant", content = exchange.answer.content })
                    end
                else
                    -- Use the summary if available
                    if exchange.summary then
                        table.insert(messages, { role = "assistant", content = exchange.summary.content })
                    else
                        -- If no summary is available, use the full content (fallback)
                        if answer_has_tool_blocks then
                            for _, m in ipairs(M._emit_content_blocks_as_messages(exchange.answer.content_blocks)) do
                                table.insert(messages, m)
                            end
                        else
                            table.insert(messages, { role = "assistant", content = exchange.answer.content })
                        end
                    end
                end
            end
        end
    end

    -- replace first empty message with system prompt (use agent_info which has already resolved this)
    local content = agent_info.system_prompt
    if content and content:match("%S") then
        messages[1] = { role = "system", content = content }

        -- For providers that support cache_control, add ephemeral caching to system prompt
        local prov = require("parley.providers")
        if prov.has_feature(agent_info.provider, "cache_control") then
            messages[1].cache_control = { type = "ephemeral" }
        end
    end

    -- strip whitespace from ends of content. Messages built from
    -- content_blocks carry a table in .content (Anthropic's content-
    -- block shape); those have already been trimmed at the block
    -- level by chat_parser cb_finalize_block so we leave them alone.
    for _, message in ipairs(messages) do
        if type(message.content) == "string" then
            message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
        end
    end

    -- Preserve a trailing newline for appended system prompt lines.
    local has_system_prompt_append = false
    if type(headers) == "table" and type(headers._append) == "table" then
        local canonical = headers._append.system_prompt
        local legacy = headers._append.role
        has_system_prompt_append = (type(canonical) == "table" and #canonical > 0) or (type(legacy) == "table" and #legacy > 0)
    end
    if has_system_prompt_append and messages[1] and messages[1].role == "system" and messages[1].content ~= "" then
        if messages[1].content:sub(-1) ~= "\n" then
            messages[1].content = messages[1].content .. "\n"
        end
    end

    return messages
end

-- Find the 0-indexed line number of the `topic:` header line in a buffer.
-- Returns nil if not found or buffer is invalid.
M.find_topic_line = function(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = find_chat_header_end(lines)
    if not header_end then return nil end
    for i = 1, header_end do
        if lines[i]:match("^%s*topic:%s*") then
            return i - 1  -- 0-indexed
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- generate_topic: ask LLM to produce a short topic from conversation messages
--------------------------------------------------------------------------------

-- Fire an LLM call to generate a topic string from a conversation.
-- @param messages  table    array of {role, content} (the conversation so far)
-- @param provider  string   provider name (e.g. "anthropic", "openai")
-- @param model     string   model name
-- @param callback  function called with (topic_string) on completion
-- @param spinner   table|nil optional {buf, find_line} — buf is the buffer to animate,
--                  find_line() returns 0-indexed line number of the topic line (or nil to skip)
M.generate_topic = function(messages, provider, model, callback, spinner)
    -- Build a clean copy: strip whitespace, drop empty messages and cache_control.
    -- Messages carrying content-block arrays (Anthropic tool-use shape, M2
    -- Task 2.6 of #81) are flattened to a plain-text excerpt for topic
    -- generation — the topic model doesn't care about tool blocks.
    local msgs = {}
    for _, m in ipairs(messages) do
        local content = m.content
        if type(content) == "table" then
            -- Content-block list: concatenate text-typed block bodies.
            -- Non-text blocks (tool_use, tool_result) contribute nothing
            -- useful to a topic string, so we drop them.
            local parts = {}
            for _, block in ipairs(content) do
                if block.type == "text" and type(block.text) == "string" then
                    table.insert(parts, block.text)
                end
            end
            content = table.concat(parts, " ")
        elseif type(content) ~= "string" then
            content = ""
        end
        content = content:gsub("^%s*(.-)%s*$", "%1")
        if content ~= "" then
            table.insert(msgs, { role = m.role, content = content })
        end
    end
    table.insert(msgs, { role = "user", content = _parley.config.chat_topic_gen_prompt })

    -- Start spinner animation on the topic line if requested
    local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
    local spinner_idx = 1
    local spinner_timer = nil
    if spinner and spinner.buf and spinner.find_line then
        spinner_timer = vim.uv.new_timer()
        spinner_timer:start(0, 120, vim.schedule_wrap(function()
            if not vim.api.nvim_buf_is_valid(spinner.buf) then
                stop_and_close_timer(spinner_timer)
                spinner_timer = nil
                return
            end
            local line_nr = spinner.find_line()
            if line_nr then
                local text = "topic: " .. spinner_frames[spinner_idx] .. " generating..."
                require("parley.buffer_edit").replace_line_at(spinner.buf, line_nr, text)
            end
            spinner_idx = spinner_idx % #spinner_frames + 1
        end))
    end

    local topic_buf = vim.api.nvim_create_buf(false, true)
    local topic_handler = _parley.dispatcher.create_handler(topic_buf, nil, 0, false, "", false)

    _parley.dispatcher.query(
        nil,
        provider,
        _parley.dispatcher.prepare_payload(msgs, model, provider),
        topic_handler,
        vim.schedule_wrap(function()
            stop_and_close_timer(spinner_timer)
            spinner_timer = nil
            local topic = vim.api.nvim_buf_get_lines(topic_buf, 0, -1, false)[1] or ""
            vim.api.nvim_buf_delete(topic_buf, { force = true })
            topic = topic:gsub("^%s*(.-)%s*$", "%1")
            topic = topic:gsub("%.$", "")
            if topic ~= "" then
                callback(topic)
            end
        end)
    )
end

--------------------------------------------------------------------------------
-- _resolve_remote_references
--------------------------------------------------------------------------------

-- Resolve all remote (URL-based) file references asynchronously before building messages
-- Calls callback with resolved_remote_content map when all fetches complete
---@param opts table # { parsed_chat, config, chat_file, exchange_idx }
---@param callback function # called with resolved_remote_content table
M.resolve_remote_references = function(opts, callback)
    local helpers = require("parley.helper")
    local oauth = require("parley.oauth")
    local parsed_chat = opts.parsed_chat
    local opts_config = opts.config
    local chat_file = opts.chat_file or ""
    local exchange_idx = opts.exchange_idx or #parsed_chat.exchanges
    local resolved = {}
    local seen_prior = {}
    local seen_current = {}
    local queued_fetches = {}
    local urls_to_fetch = {}
    local chat_cache = M.get_chat_remote_reference_cache(chat_file)

    local function queue_fetch(url)
        if not queued_fetches[url] then
            queued_fetches[url] = true
            table.insert(urls_to_fetch, url)
        end
    end

    for idx, exchange in ipairs(parsed_chat.exchanges) do
        if idx > exchange_idx then
            break
        end

        if exchange.question and exchange.question.file_references then
            for _, file_ref in ipairs(exchange.question.file_references) do
                local url = file_ref.path
                if helpers.is_remote_url(url) then
                    if idx == exchange_idx and not seen_current[url] then
                        seen_current[url] = true
                        queue_fetch(url)
                    elseif idx < exchange_idx and not seen_prior[url] then
                        seen_prior[url] = true
                        if chat_cache[url] then
                            resolved[url] = chat_cache[url]
                        else
                            queue_fetch(url)
                        end
                    end
                end
            end
        end
    end

    if #urls_to_fetch == 0 then
        callback(resolved)
        return
    end

    local pending = #urls_to_fetch

    for _, url in ipairs(urls_to_fetch) do
        -- Delegate remote URL handling to the OAuth fetcher. It owns provider
        -- detection and can fall back to the auth picker for unknown patterns.
        oauth.fetch_content(url, opts_config.oauth or opts_config.google_drive, function(content, err)
            local cached_content = content
            if not cached_content then
                cached_content = M.format_remote_reference_error_content(url, err)
                _parley.logger.warning("Failed to fetch remote content: " .. (err or "unknown error"))
            end

            resolved[url] = cached_content
            chat_cache[url] = cached_content
            M.save_remote_reference_cache()
            pending = pending - 1
            if pending == 0 then
                callback(resolved)
            end
        end)
    end
end

--------------------------------------------------------------------------------
-- chat_respond  (main streaming response handler)
--------------------------------------------------------------------------------

M.respond = function(params, callback, override_free_cursor, force)
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]

    local use_free_cursor = not is_follow_cursor_enabled(override_free_cursor)
    _parley.logger.debug(
        "chat_respond configured cursor behavior - override: "
            .. tostring(override_free_cursor)
            .. ", final follow_cursor: "
            .. tostring(not use_free_cursor)
    )

    -- Check if there's already an active process for this buffer
    if not force and _parley.tasker.is_busy(buf, false) then
        _parley.logger.warning("A Parley process is already running. Use stop to cancel or force to override.")
        return
    end

    -- go to normal mode
    vim.cmd("stopinsert")

    -- get all lines
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- check if file looks like a chat file
    local file_name = vim.api.nvim_buf_get_name(buf)
    local reason = _parley.not_chat(buf, file_name)
    if reason then
        _parley.logger.warning("File " .. vim.inspect(file_name) .. " does not look like a chat file: " .. vim.inspect(reason))
        return
    end

    -- Find header section end
    local header_end = find_chat_header_end(lines)

    if header_end == nil then
        _parley.logger.error("Error while parsing headers: --- not found. Check your chat template.")
        return
    end

    -- Parse chat into structured representation
    local parsed_chat = _parley.parse_chat(lines, header_end)
    _parley.logger.debug("chat_respond: parsed chat: " .. vim.inspect(parsed_chat))

    -- Determine which part of the chat to process based on cursor position
    local end_index = #lines
    local start_index = header_end + 1
    local exchange_idx, component = _parley.find_exchange_at_line(parsed_chat, cursor_line)
    _parley.logger.debug(
        "chat_respond: exchange_idx and component under cursor " .. tostring(exchange_idx) .. " " .. tostring(component)
    )

    -- If range was explicitly provided, respect it
    if params.range == 2 then
        start_index = math.max(start_index, params.line1)
        end_index = math.min(end_index, params.line2)
    else
        -- Check if cursor is in the middle of the document on a question
        if exchange_idx and component == "question" then
            -- Cursor is on a question - process up to the end of this question's answer
            _parley.logger.debug("Resubmitting question at exchange #" .. exchange_idx)

            if parsed_chat.exchanges[exchange_idx].answer then
                end_index = parsed_chat.exchanges[exchange_idx].answer.line_end
            else
                -- If the question has no answer yet, process to the end
                end_index = #lines
            end

            -- Highlight the lines that will be reprocessed
            local ns_id = vim.api.nvim_create_namespace("ParleyResubmit")
            vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

            local highlight_start = parsed_chat.exchanges[exchange_idx].question.line_start
            vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)

            -- Always schedule the highlight to clear after a brief delay
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(buf) then
                    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
                end
            end, 1000)
        end
    end

    -- Get agent to use
    local agent = _parley.get_agent()

    -- Get headers for later use (needed in completion callback)
    local headers = parsed_chat.headers

    -- Resolve remote file references, then build messages and continue
    M.resolve_remote_references({
        parsed_chat = parsed_chat,
        config = _parley.config,
        chat_file = file_name,
        exchange_idx = exchange_idx,
    }, function(resolved_remote_content)
        -- Build messages array using extracted testable function
        local messages = M.build_messages({
            parsed_chat = parsed_chat,
            start_index = start_index,
            end_index = end_index,
            exchange_idx = exchange_idx,
            agent = agent,
            config = _parley.config,
            helpers = _parley.helpers,
            logger = _parley.logger,
            resolved_remote_content = resolved_remote_content,
        })

        -- Inject ancestor context (tree-of-chat): walk parent chain and prepend
        -- ancestor Q+A exchanges after the system prompt (messages[1]).
        local ancestor_msg_count = 0
        if parsed_chat.parent_link then
            local ancestor_msgs = collect_ancestor_messages(file_name, parsed_chat)
            if #ancestor_msgs > 0 then
                ancestor_msg_count = #ancestor_msgs
                _parley.logger.debug("Injecting " .. #ancestor_msgs .. " ancestor messages into context")
                -- Insert after index 1 (system prompt), before current chat messages
                for i = #ancestor_msgs, 1, -1 do
                    table.insert(messages, 2, ancestor_msgs[i])
                end
            end
        end

        -- Get agent info for display and dispatcher
        local agent_info = _parley.get_agent_info(headers, agent)
        local agent_name = agent_info.display_name

        -- Set up agent prefixes
        local agent_prefix = _parley.config.chat_assistant_prefix[1]
        local agent_suffix = _parley.config.chat_assistant_prefix[2]
        if type(_parley.config.chat_assistant_prefix) == "string" then
            agent_prefix = _parley.config.chat_assistant_prefix
        elseif type(_parley.config.chat_assistant_prefix) == "table" then
            agent_prefix = _parley.config.chat_assistant_prefix[1]
            agent_suffix = _parley.config.chat_assistant_prefix[2] or ""
        end
        agent_suffix = _parley.render.template(agent_suffix, { ["{{agent}}"] = agent_name })

        -- Find where to insert assistant response
        local response_line = _parley.helpers.last_content_line(buf)

        -- M2 Task 2.7 of #81: tool loop recursion detection.
        -- If we're mid-tool-loop (iter > 0), we're continuing the same
        -- exchange's answer — the existing 🔧:/📎: blocks are live
        -- state we MUST preserve, not stale content to discard. Append
        -- the next response chunk after the existing answer instead of
        -- replacing it.
        local in_tool_loop_recursion = false
        do
            local ok, tool_loop_mod = pcall(require, "parley.tool_loop")
            if ok and tool_loop_mod.get_iter(buf) > 0 then
                in_tool_loop_recursion = true
            end
        end
        -- TRACE #90 — remove after diagnosing tool-loop recursion issue
        _parley.logger.debug(string.format(
            "[#90 trace] M.respond entry: buf=%d in_tool_loop_recursion=%s buf_line_count=%d cursor_line=%s",
            buf, tostring(in_tool_loop_recursion), vim.api.nvim_buf_line_count(buf), tostring(cursor_line)
        ))
        if in_tool_loop_recursion then
            -- Dump full buffer state to a file so we can see exactly what
            -- the parser is looking at on the recursive call.
            pcall(function()
                local dpath = "/tmp/claude/parley-90-debug/recursion_buffer_" .. _parley.logger.now() .. ".txt"
                local df = io.open(dpath, "w")
                if df then
                    local lns = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                    for i, l in ipairs(lns) do
                        df:write(string.format("[%d] %s\n", i, l))
                    end
                    df:close()
                    _parley.logger.debug("[#90 trace] dumped recursion buffer to " .. dpath)
                end
            end)
        end

        -- ================================================================
        -- Use exchange_model to compute where to insert the response.
        -- This replaces the absolute-line arithmetic that was the root
        -- cause of #90 — all positions are derived from section SIZES,
        -- never stored as absolute line numbers.
        -- ================================================================
        local exchange_model = require("parley.exchange_model")
        local model = exchange_model.from_parsed_chat(parsed_chat)

        -- If cursor is on a question, handle insertion based on question position
        if exchange_idx and (component == "question" or component == "answer") then
            if parsed_chat.exchanges[exchange_idx].answer and not in_tool_loop_recursion then
                -- If question already has an answer, replace it.
                -- Delete the existing answer, keeping one blank line as separator.
                local answer = parsed_chat.exchanges[exchange_idx].answer
                require("parley.buffer_edit").replace_answer(buf, answer.line_start - 1, answer.line_end - 1)
                -- Re-parse after deletion to rebuild the model with correct sizes.
                local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local new_header_end = find_chat_header_end(new_lines) or 0
                parsed_chat = _parley.parse_chat(new_lines, new_header_end)
                model = exchange_model.from_parsed_chat(parsed_chat)
            end
        end

        local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
        local spinner_message = "Submitting..."
        local progress_detail_text = ""
        local progress_detail_key = nil
        local spinner_frame_index = 1
        local spinner_timer = nil
        -- Skip spinner for tool-use agents and recursion — tool rounds are
        -- fast and the spinner's line management conflicts with model-based
        -- positioning (#90).
        local spinner_active = _parley._state.web_search
            and (not (agent_info.tools and #agent_info.tools > 0))
            and (not in_tool_loop_recursion)
            and true or false
        local spinner_running = false
        local initial_progress_text = ""
        if spinner_active then
            initial_progress_text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
        end

        -- Compute where to insert using the exchange model.
        -- The model guarantees the position is INSIDE the active exchange,
        -- never past the placeholder 💬: of the next exchange.
        --
        -- For non-tool agents or when exchange_idx is nil (cursor not on
        -- a question/answer), fall back to the legacy last_content_line
        -- approach — those paths don't need the model because there's no
        -- tool loop to cause the placeholder-overwrite bug.
        local response_start_line
        local has_tools = agent_info.tools and #agent_info.tools > 0
        local use_model_insert = exchange_idx
            and (component == "question" or component == "answer")
            and (has_tools or in_tool_loop_recursion)
        if not use_model_insert then
            -- Legacy: insert at last content line. No model needed.
            local insert_lines
            if spinner_active then
                insert_lines = { "", agent_prefix .. agent_suffix, "", initial_progress_text, "" }
            else
                insert_lines = { "", agent_prefix .. agent_suffix, "", "" }
            end
            require("parley.buffer_edit").insert_lines_at(buf, response_line, insert_lines)
            -- Streaming writes at the LAST line of the insert block.
            response_start_line = response_line + #insert_lines - 1
        elseif in_tool_loop_recursion then
            -- Recursion: append after the existing answer's last section.
            -- The model knows where the answer ends.
            local append_pos = model:answer_append_pos(exchange_idx)
            require("parley.buffer_edit").insert_lines_at(buf, append_pos, { "" })
            model:add_section(exchange_idx, "stream_placeholder", 1)
            response_start_line = append_pos
        else
            -- Fresh answer: create the answer header + a blank line for streaming.
            if not model.exchanges[exchange_idx].answer then
                model:create_answer(exchange_idx)
            end
            local header_pos = model:answer_start(exchange_idx)
            -- Insert: margin(blank) + agent_header + blank_for_streaming
            -- Insert: margin + agent_header + gap + streaming_target (+ spinner if active)
            -- Layout matches the legacy response_block_lines exactly:
            --   { "", "🤖:[A]", "", "" }           (no spinner, 4 lines)
            --   { "", "🤖:[A]", "", spinner, "" }  (with spinner, 5 lines)
            local insert_lines
            if spinner_active then
                insert_lines = { "", agent_prefix .. agent_suffix, "", initial_progress_text, "" }
            else
                insert_lines = { "", agent_prefix .. agent_suffix, "", "" }
            end
            require("parley.buffer_edit").insert_lines_at(buf, header_pos - 1, insert_lines)
            -- Track the streamed-text area as a section in the model.
            model:add_section(exchange_idx, "stream_placeholder", 1)
            -- Streaming writes at the LAST line of the insert block.
            response_start_line = header_pos - 1 + #insert_lines - 1
        end
        -- TRACE #90
        _parley.logger.debug(string.format(
            "[#90 trace] model-based insert: response_start_line=%s buf_line_count=%d exchange_idx=%s",
            tostring(response_start_line), vim.api.nvim_buf_line_count(buf), tostring(exchange_idx)
        ))

        -- Legacy variables kept for compatibility with progress indicator
        -- and raw_request_fence paths. TODO: migrate these to model too.
        local response_line = response_start_line

        _parley.logger.debug("messages to send: " .. vim.inspect(messages))

        -- Check if we're in raw request mode and have a raw payload to use
        local raw_payload = nil
        if
            exchange_idx
            and parsed_chat.exchanges[exchange_idx].question
            and parsed_chat.exchanges[exchange_idx].question.raw_payload
        then
            raw_payload = parsed_chat.exchanges[exchange_idx].question.raw_payload
            _parley.logger.debug("Using raw payload for request: " .. vim.inspect(raw_payload))
        end

        -- Compute payload once for both display and query.
        -- agent_info.tools (from M1 Task 1.4) is passed as the 4th arg so
        -- tool-enabled agents get their client-side tools appended to the
        -- payload. Vanilla agents have agent_info.tools = nil and stay
        -- byte-identical to pre-#81 behavior.
        local final_payload = raw_payload or _parley.dispatcher.prepare_payload(messages, agent_info.model, agent_info.provider, agent_info.tools)

        -- In raw request mode, insert the request payload after the question, before the agent response
        -- Skip if the question already contains a typed request fence (raw_payload was parsed from it)
        local raw_request_offset = 0
        if _parley.config.raw_mode and _parley.config.raw_mode.parse_raw_request and not raw_payload then
            local json_str = vim.json.encode(final_payload)
            -- Pretty-print via python3 json.tool
            local ok, formatted = pcall(function()
                return vim.fn.system({ "python3", "-m", "json.tool" }, json_str)
            end)
            if not ok or vim.v.shell_error ~= 0 then
                formatted = json_str
            end
            local request_lines = { '', '```json {"type": "request"}' }
            for line in formatted:gmatch("[^\n]+") do
                table.insert(request_lines, line)
            end
            table.insert(request_lines, "```")
            -- Insert right before the agent header (at response_line, pushing agent header down)
            require("parley.buffer_edit").insert_raw_request_fence(buf, response_line, request_lines)
            raw_request_offset = #request_lines
        end

        -- progress_line and response_start_line are now computed by the
        -- model-based insert above. The spinner_active flag determines
        -- whether the progress indicator exists. If it does, progress_line
        -- is 2 lines before response_start_line; if not, they're the same.
        local progress_line = spinner_active and (response_start_line - 2) or response_start_line
        -- TRACE #90 — remove after diagnosing
        _parley.logger.debug(string.format(
            "[#90 trace] line targets: progress_line=%s response_start_line=%s buf_line_count=%d max_0idx=%d",
            tostring(progress_line),
            tostring(response_start_line),
            vim.api.nvim_buf_line_count(buf),
            vim.api.nvim_buf_line_count(buf) - 1
        ))

        local function set_progress_indicator_line(text)
            if not spinner_active then
                return
            end
            if vim.in_fast_event() then
                vim.schedule(function()
                    set_progress_indicator_line(text)
                end)
                return
            end
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            local existing = vim.api.nvim_buf_get_lines(buf, progress_line, progress_line + 1, false)[1]
            if existing == nil then
                return
            end
            require("parley.buffer_edit").replace_line_at(buf, progress_line, text)
        end

        local function render_spinner_line()
            if not spinner_active then
                return
            end
            if vim.in_fast_event() then
                vim.schedule(render_spinner_line)
                return
            end
            local text = "🔎 " .. spinner_frames[spinner_frame_index] .. " " .. spinner_message
            set_progress_indicator_line(text)
        end

        local function stop_spinner()
            if not spinner_running then
                return
            end
            spinner_running = false
            stop_and_close_timer(spinner_timer)
            spinner_timer = nil
        end

        local function clear_progress_indicator(qt)
            if not spinner_active then
                return
            end
            if vim.in_fast_event() then
                vim.schedule(function()
                    clear_progress_indicator(qt)
                end)
                return
            end
            stop_spinner()
            spinner_active = false
            if vim.api.nvim_buf_is_valid(buf) then
                local line_count = vim.api.nvim_buf_line_count(buf)
                local delete_end = math.min(progress_line + 2, line_count)
                local existing = vim.api.nvim_buf_get_lines(buf, progress_line, delete_end, false)
                if #existing > 0 then
                    local deleted_line_count = delete_end - progress_line
                    require("parley.buffer_edit").delete_lines_after(buf, progress_line, deleted_line_count)
                    if qt then
                        if type(qt.first_line) == "number" and qt.first_line >= progress_line then
                            qt.first_line = qt.first_line - deleted_line_count
                        end
                        if type(qt.last_line) == "number" and qt.last_line >= progress_line then
                            qt.last_line = qt.last_line - deleted_line_count
                        end
                    end
                end
            end
        end

        local function start_spinner()
            if not spinner_active then
                return
            end
            spinner_running = true
            render_spinner_line()
            spinner_timer = vim.loop.new_timer()
            spinner_timer:start(
                90,
                90,
                vim.schedule_wrap(function()
                    if not spinner_running then
                        return
                    end
                    spinner_frame_index = spinner_frame_index + 1
                    if spinner_frame_index > #spinner_frames then
                        spinner_frame_index = 1
                    end
                    render_spinner_line()
                end)
            )
        end

        start_spinner()

        local base_handler = _parley.dispatcher.create_handler(buf, win, response_start_line, true, "", function()
            return is_follow_cursor_enabled(override_free_cursor)
        end)
        local function request_clear_progress_indicator(qt)
            if vim.in_fast_event() then
                vim.schedule(function()
                    clear_progress_indicator(qt)
                end)
                return
            end
            clear_progress_indicator(qt)
        end
        local response_handler = function(qid, chunk)
            if type(chunk) == "string" and chunk ~= "" then
                stop_spinner()
            end
            base_handler(qid, chunk)
        end

        -- call the model and write response
        _parley.dispatcher.query(
            buf,
            agent_info.provider,
            final_payload,
            response_handler,
            vim.schedule_wrap(function(qid)
                local qt = _parley.tasker.get_query(qid)
                if not qt then
                    return
                end
                request_clear_progress_indicator(qt)

                -- M2 Task 2.7 of #81: tool loop hook. If the streamed
                -- response contained tool_use blocks, write 🔧:/📎:
                -- into the buffer and re-submit the updated chat so
                -- Claude can continue. Finalization (user prompt
                -- append, topic generation, cursor placement) only
                -- runs on the final iteration (when outcome == "done").
                -- TRACE #90 — remove after diagnosing
                _parley.logger.debug(string.format(
                    "[#90 trace] on_exit: qt.response_len=%d qt.raw_response_len=%d has_tools=%s buf_line_count=%d",
                    #(qt.response or ""),
                    #(qt.raw_response or ""),
                    tostring(agent_info and agent_info.tools and #agent_info.tools > 0),
                    vim.api.nvim_buf_line_count(buf)
                ))
                -- TRACE #90 — dump full request payload + raw response to per-call files
                -- so we can compare across rounds and find the "prefill not supported"
                -- pattern. Files land in /tmp/claude/parley-90-debug/.
                do
                    local debug_dir = "/tmp/claude/parley-90-debug"
                    vim.fn.mkdir(debug_dir, "p")
                    local stamp = _parley.logger.now() .. "." .. string.format("%x", math.random(0, 0xFFFFFF))
                    local req_path = debug_dir .. "/" .. stamp .. ".request.json"
                    local resp_path = debug_dir .. "/" .. stamp .. ".response.txt"
                    local meta_path = debug_dir .. "/" .. stamp .. ".meta.txt"
                    -- Write request payload (final_payload is in scope)
                    pcall(function()
                        local rf = io.open(req_path, "w")
                        if rf then rf:write(vim.json.encode(final_payload)); rf:close() end
                    end)
                    pcall(function()
                        local af = io.open(resp_path, "w")
                        if af then af:write(qt.raw_response or ""); af:close() end
                    end)
                    pcall(function()
                        local mf = io.open(meta_path, "w")
                        if mf then
                            mf:write(string.format(
                                "in_tool_loop_recursion=%s\nresponse_len=%d\nraw_response_len=%d\nbuf_line_count=%d\nresponse_text=%s\n",
                                tostring(in_tool_loop_recursion),
                                #(qt.response or ""),
                                #(qt.raw_response or ""),
                                vim.api.nvim_buf_line_count(buf),
                                (qt.response or ""):sub(1, 200)
                            ))
                            mf:close()
                        end
                    end)
                    _parley.logger.debug("[#90 trace] dumped req+resp to " .. stamp)
                end
                if agent_info and agent_info.tools and #agent_info.tools > 0 then
                    local tool_loop = require("parley.tool_loop")
                    -- M2 hardcodes max_tool_iterations = 1 (single round).
                    -- M4 Task 4.1 lifts this cap and uses the
                    -- agent-configured max instead. Even if the agent
                    -- config says 20, M2 stops after one round to keep
                    -- failure modes contained while the loop machinery
                    -- is still being hardened.
                    -- TODO(#90): pass exchange_model writer so tool_loop
                    -- appends inside the active answer, not at buffer end.
                    local outcome = tool_loop.process_response(buf, qt.raw_response or "", {
                        max_tool_iterations = 1,
                        tool_result_max_bytes = agent_info.tool_result_max_bytes or 102400,
                        cwd = vim.fn.getcwd(),
                    })
                    -- TRACE #90 — remove after diagnosing
                    _parley.logger.debug(string.format(
                        "[#90 trace] process_response → outcome=%s tool_loop_iter=%d buf_line_count=%d",
                        tostring(outcome),
                        tool_loop.get_iter(buf),
                        vim.api.nvim_buf_line_count(buf)
                    ))
                    if outcome == "recurse" then
                        -- Re-parse the (now updated) buffer and submit
                        -- again. force=true bypasses the is_busy check
                        -- that would otherwise reject an immediate
                        -- re-submit. The recursive respond() inherits
                        -- the same callback so user-provided
                        -- callbacks still fire on the final iteration.
                        vim.schedule(function()
                            M.respond({}, callback, override_free_cursor, true)
                        end)
                        return
                    end
                end

                local streamed_cursor_line = query_cursor_line(qt)

                -- Only add a new user prompt at the end if we're not in the middle of the document
                _parley.logger.debug("exchange_idx: " .. tostring(exchange_idx) .. " and #parsed_chat: " .. tostring(#parsed_chat))

                if exchange_idx == #parsed_chat.exchanges then
                    local buffer_edit = require("parley.buffer_edit")
                    -- write user prompt at the end
                    last_content_line = _parley.helpers.last_content_line(buf)
                    _parley.helpers.undojoin(buf)
                    buffer_edit.insert_lines_at(buf, last_content_line, { "", _parley.config.chat_user_prefix, "" })

                    -- delete whitespace lines at the end of the file
                    last_content_line = _parley.helpers.last_content_line(buf)
                    _parley.helpers.undojoin(buf)
                    buffer_edit.delete_to_end(buf, last_content_line)
                    -- insert a new line at the end of the file
                    _parley.helpers.undojoin(buf)
                    buffer_edit.append_blank_at_end(buf)
                end

                -- if topic is ?, then generate it
                if headers.topic == "?" then
                    -- For topic generation, use only current file's messages (skip ancestors)
                    -- messages layout: [system_prompt, ...ancestors, ...current_file_msgs]
                    local topic_msgs = {}
                    for i, m in ipairs(messages) do
                        -- skip ancestor messages (indices 2 through ancestor_msg_count + 1)
                        if i == 1 or i > ancestor_msg_count + 1 then
                            table.insert(topic_msgs, vim.deepcopy(m))
                        end
                    end
                    table.insert(topic_msgs, { role = "assistant", content = qt.response })

                    M.generate_topic(topic_msgs, agent_info.provider, agent_info.model, function(topic)
                        _parley.helpers.undojoin(buf)
                        local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                        set_chat_topic_line(buf, all_lines, topic)
                    end, { buf = buf, find_line = function()
                        return M.find_topic_line(buf)
                    end })
                end

                -- Place cursor appropriately
                _parley.logger.debug(
                    "Cursor movement check - use_free_cursor: "
                        .. tostring(use_free_cursor)
                        .. ", config.chat_free_cursor: "
                        .. tostring(_parley.config.chat_free_cursor)
                )

                if is_follow_cursor_enabled(override_free_cursor) then
                    _parley.logger.debug(
                        "Moving cursor - exchange_idx: "
                            .. tostring(exchange_idx)
                            .. ", component: "
                            .. tostring(component)
                            .. ", streamed_cursor_line: "
                            .. tostring(streamed_cursor_line)
                    )

                    local line = streamed_cursor_line
                    if not line then
                        if exchange_idx and component == "question" then
                            line = response_line + 2
                        else
                            line = vim.api.nvim_buf_line_count(buf)
                        end
                    end
                    _parley.logger.debug("Moving cursor to completion position: " .. tostring(line))
                    _parley.helpers.cursor_to_line(line, buf, win)
                else
                    _parley.logger.debug("Not moving cursor due to free_cursor setting")
                end
                -- Refresh interview timestamps (decoration provider handles chat highlights)
                local interview = require("parley.interview")
                interview.highlight_timestamps(buf)

                vim.cmd("doautocmd User ParleyDone")

                -- Call the callback if provided
                if callback then
                    callback()
                end
            end),
            nil,
            vim.schedule_wrap(function(_, progress_event)
                if not progress_event or type(progress_event) ~= "table" then
                    return
                end
                if not spinner_active then
                    return
                end
                local message = progress_event.message
                local detail = progress_event.text
                if type(detail) == "string" and detail ~= "" then
                    local detail_key = table.concat({
                        tostring(progress_event.phase or ""),
                        tostring(progress_event.kind or ""),
                        tostring(progress_event.tool or ""),
                        tostring(progress_event.block_type or ""),
                    }, ":")
                    if progress_detail_key ~= detail_key then
                        progress_detail_key = detail_key
                        progress_detail_text = ""
                    end
                    progress_detail_text = progress_detail_text .. detail
                    local compact = progress_detail_text:gsub("%s+", " "):gsub("^%s+", "")
                    if compact ~= "" then
                        if progress_event.kind == "reasoning" then
                            message = "Reasoning: " .. compact
                        else
                            local base = (type(progress_event.message) == "string" and progress_event.message ~= "")
                                and progress_event.message
                                or "Working..."
                            message = base .. " " .. compact
                        end
                    end
                else
                    progress_detail_text = ""
                    progress_detail_key = nil
                end

                if type(message) == "string" and message ~= "" and message ~= spinner_message then
                    spinner_message = message
                    render_spinner_line()
                end
            end)
        )
    end)
end

--------------------------------------------------------------------------------
-- chat_respond_all
--------------------------------------------------------------------------------

-- Function to resubmit all questions up to the cursor position
M.respond_all = function()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]

    if _parley.tasker.is_busy(buf, false) then
        return
    end

    -- Get all lines and check if this is a chat file
    local file_name = vim.api.nvim_buf_get_name(buf)
    local reason = _parley.not_chat(buf, file_name)
    if reason then
        _parley.logger.warning("File " .. vim.inspect(file_name) .. " does not look like a chat file: " .. vim.inspect(reason))
        return
    end

    -- Get all lines
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Find header section end
    local header_end = find_chat_header_end(lines)

    if header_end == nil then
        _parley.logger.error("Error while parsing headers: --- not found. Check your chat template.")
        return
    end

    -- Parse chat into structured representation
    local parsed_chat = _parley.parse_chat(lines, header_end)

    -- Find which exchange contains the cursor
    local current_exchange_idx, _ = _parley.find_exchange_at_line(parsed_chat, cursor_line)
    if not current_exchange_idx then
        -- If cursor isn't on any exchange, find the last exchange before cursor
        for i = #parsed_chat.exchanges, 1, -1 do
            local exchange = parsed_chat.exchanges[i]
            if exchange.question and exchange.question.line_start < cursor_line then
                current_exchange_idx = i
                break
            end
        end
    end

    if not current_exchange_idx then
        _parley.logger.warning("No questions found before cursor position")
        return
    end

    -- Save the original position for later restoration
    local original_question_line = nil
    if current_exchange_idx and parsed_chat.exchanges[current_exchange_idx] then
        original_question_line = parsed_chat.exchanges[current_exchange_idx].question.line_start
    end

    -- Start recursive resubmission process
    _parley.logger.info("Resubmitting all " .. current_exchange_idx .. " questions...")

    -- Show a notification to the user
    vim.api.nvim_echo({
        { "Parley: ", "Type" },
        { "Resubmitting all " .. current_exchange_idx .. " questions...", "WarningMsg" },
    }, true, {})

    M.resubmit_questions_recursively(parsed_chat, 1, current_exchange_idx, header_end, original_question_line, win)
end

--------------------------------------------------------------------------------
-- resubmit_questions_recursively
--------------------------------------------------------------------------------

M.resubmit_questions_recursively = function(
    parsed_chat,
    current_idx,
    max_idx,
    header_end,
    original_position,
    original_win
)
    -- Save the original value on the first call
    if current_idx == 1 then
        original_free_cursor_value = _parley.config.chat_free_cursor
        _parley.logger.debug(
            "Starting recursive resubmission - saving original chat_free_cursor: " .. tostring(original_free_cursor_value)
        )
    end

    -- Check if we've processed all questions
    if current_idx > max_idx then
        _parley.logger.info("Completed resubmitting all questions")

        -- Always restore original setting at the end
        if original_free_cursor_value ~= nil then
            _parley.config.chat_free_cursor = original_free_cursor_value
            _parley.logger.debug("End of resubmission - restored chat_free_cursor to: " .. tostring(original_free_cursor_value))

            -- Notify user of completion
            vim.api.nvim_echo({
                { "Parley: ", "Type" },
                { "Completed resubmitting all questions", "String" },
            }, true, {})

            -- Reset tracking variable
            original_free_cursor_value = nil
        end

        -- Return cursor to the original position (question under cursor) after everything is done
        local buf = vim.api.nvim_get_current_buf()

        -- If we have an original position saved, restore it
        if original_position and original_win and vim.api.nvim_win_is_valid(original_win) then
            -- Get current lines - the line numbers may have changed during processing
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local parsed_chat_final = _parley.parse_chat(lines, header_end)

            -- Find the original question's new position
            if parsed_chat_final.exchanges[max_idx] and parsed_chat_final.exchanges[max_idx].question then
                local new_position = parsed_chat_final.exchanges[max_idx].question.line_start
                _parley.helpers.cursor_to_line(new_position, buf, original_win)
            else
                -- Fallback if we can't find the original question
                _parley.helpers.cursor_to_line(original_position, buf, original_win)
            end
        end

        return
    end

    -- Create params for the current question
    local params = {}
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    -- Highlight the current question being processed
    local ns_id = vim.api.nvim_create_namespace("ParleyResubmitAll")
    vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

    -- Find the question and position the cursor on it to ensure the correct context
    local question = parsed_chat.exchanges[current_idx].question
    local highlight_start = question.line_start
    vim.api.nvim_buf_add_highlight(buf, ns_id, "DiffAdd", highlight_start - 1, 0, -1)

    -- Set the cursor to this question to ensure proper context processing
    _parley.helpers.cursor_to_line(highlight_start, buf, win)

    -- Schedule highlight to clear after processing is complete
    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
    end, 1000)

    -- This is key: we use a simulated fake params object
    -- but actually we set the cursor on the right question first
    -- so the proper context is used and answer is placed in correct position
    -- We force free_cursor to false to ensure cursor follows during resubmission
    -- The parameter true means "force cursor movement" - it will override chat_free_cursor setting
    _parley.logger.debug("Resubmitting question " .. current_idx .. " of " .. max_idx .. " with forced cursor movement")

    -- Force cursor movement for each individual question
    _parley.config.chat_free_cursor = false -- Will be restored at the end of the resubmission

    _parley.chat_respond(params, function()
        -- After this question is processed, move to the next one
        -- We need to reparse the chat since content has changed
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local parsed_chat_updated = _parley.parse_chat(lines, header_end)

        -- Continue with the next question
        vim.defer_fn(function()
            M.resubmit_questions_recursively(
                parsed_chat_updated,
                current_idx + 1,
                max_idx,
                header_end,
                original_position,
                original_win
            )
        end, 500) -- Small delay to allow UI to update
    end)
end

--------------------------------------------------------------------------------
-- cmd.ChatRespond
--------------------------------------------------------------------------------

M.cmd_respond = function(params)
    local force = false

    -- Check for force flag
    if params.args and params.args:match("!$") then
        force = true
        params.args = params.args:gsub("!$", "")
        _parley.logger.info("Forcing response even if another process is running")
    end

    -- Simply call chat_respond with the current parameters
    _parley.chat_respond(params, nil, nil, force)
end

return M
