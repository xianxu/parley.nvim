-- parley/chat_respond.lua — LLM response pipeline extracted from init.lua
-- Owns: remote reference cache, _build_messages, _resolve_remote_references,
--       chat_respond, chat_respond_all, resubmit_questions_recursively, cmd.Stop/ChatRespond
local M = {}

--- Build the user-facing notice for a failed provider request.
---
--- Pure (ARCH-PURE) and exposed so the last mile of #197 is testable: this is
--- what actually puts the diagnosis in front of the operator. A recovery seam
--- that gave up supplies `failure.message`; prefer it over `failure.body`, the
--- raw provider JSON that produced the useless naked-error notices this
--- replaced. `body` stays on the failure table for the log.
---@param failure table|nil
---@return string
function M._failure_notice(failure)
    local status = failure and failure.http_status
    local detail = (failure and failure.message) or (failure and failure.body)
    local message = "parley: provider request failed"
    if status and (status < 200 or status > 299) then
        message = message .. " (HTTP " .. tostring(status) .. ")"
    elseif failure and failure.code then
        message = message .. " (exit " .. tostring(failure.code) .. ")"
    end
    if type(detail) == "string" and detail:match("%S") then
        message = message .. ": " .. detail:sub(1, 500)
    end
    return message
end

-- _parley holds the full parley module (set via M.setup()).
-- All _parley.* accesses are intentionally dynamic so state mutations in init.lua
-- (M.config, M._state, M._remote_reference_cache) are visible here by reference.
local _parley = nil

local function append_neighborhood_context(agent_info, policy)
    if not agent_info or type(agent_info.tools) ~= "table" or #agent_info.tools == 0 then
        return
    end
    local line = require("parley.neighborhood").format_tool_context(policy)
    if not line then
        return
    end
    if type(agent_info.system_prompt) ~= "string" or agent_info.system_prompt == "" then
        agent_info.system_prompt = line
        return
    end
    if agent_info.system_prompt:find(line, 1, true) then
        return
    end
    if agent_info.system_prompt:sub(-1) ~= "\n" then
        agent_info.system_prompt = agent_info.system_prompt .. "\n"
    end
    agent_info.system_prompt = agent_info.system_prompt .. line
end

M.setup = function(parley)
    _parley = parley
end

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

local function trim(str)
    return (str or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function trailing_footnote_boundary(lines, search_start_0)
    local is_footnote_line = require("parley.define").is_footnote_line
    local search_start = (search_start_0 or 0) + 1
    local footnote_start = nil
    for i = search_start, #lines do
        if is_footnote_line(lines[i]) then
            footnote_start = i
            break
        end
    end
    if not footnote_start then
        return nil
    end

    for i = footnote_start, #lines do
        local line = lines[i] or ""
        if line:match("%S") and not is_footnote_line(line) then
            return nil
        end
    end

    local boundary = footnote_start
    local before = boundary - 1
    while before >= search_start and trim(lines[before]) == "" do
        before = before - 1
    end
    if before >= search_start and trim(lines[before]) == "---" then
        boundary = before
    end
    return boundary - 1
end

M._trailing_footnote_boundary = trailing_footnote_boundary

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
                local content = require("parley.question_tags").compose_question(
                    exchange.preface and exchange.preface.content, exchange.question.content)
                    :gsub("^%s*(.-)%s*$", "%1")
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
    -- THE resolver, called directly (#224). A local wrapper named resolve_path is
    -- what this module had before, and it was exact-match-only: it worked for
    -- every reference whose parent had not been renamed yet.
    local abs_parent = _parley.resolve_chat_path(parsed_chat.parent_link.path, current_dir)

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
        if _parley.resolve_chat_path(branch.path, parent_dir) == current_abs then
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

-- Test seam (#224): the ancestor walk is IO — it reads the parent files off
-- disk and resolves their references — so the defect it carries cannot be
-- reached through `build_ancestor_messages`, which is the pure half.
M._collect_ancestor_messages = function(...) return collect_ancestor_messages(...) end
M._collect_ancestor_chain = function(...) return collect_ancestor_chain(...) end

local function is_follow_cursor_enabled(override_free_cursor)
    if override_free_cursor ~= nil then
        return override_free_cursor
    end
    if _parley._state.follow_cursor ~= nil then
        return _parley._state.follow_cursor
    end
    return not _parley.config.chat_free_cursor
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

-- Stop selects one captured generation; StopDocument explicitly selects all.
-- Child operations retain their positive-resolution barrier after cancellation.
M.cmd_stop = function()
    return M.stop_at_cursor(vim.api.nvim_get_current_buf(), vim.api.nvim_win_get_cursor(0)[1] - 1)
end
M.cmd_stop_document = function()
    return M.cancel_responses(vim.api.nvim_get_current_buf())
end

--------------------------------------------------------------------------------
-- Retention rule and attachment budget (#231) — ONE rule for BOTH builders.
--------------------------------------------------------------------------------

--- The memory window: how many trailing exchanges are sent in full. The chat
--- header's `max_full_exchanges` overrides the config value; memory disabled
--- means everything. Extracted unchanged from build_messages.
--- @param headers table  parsed chat headers
--- @param config table   plugin config
--- @return integer max_exchanges
M.window_size = function(headers, config)
    local memory = config and config.chat_memory
    if not (memory and memory.enable) then
        return 999999
    end
    if headers and headers.config_max_full_exchanges then
        return headers.config_max_full_exchanges
    end
    return memory.max_full_exchanges
end

--- ONE retention rule: an exchange is sent in full when it is the current
--- question, inside the trailing window, or pinned by @@ file references.
--- Attachments do NOT pin (decision 5). Extracted unchanged from build_messages.
--- @param idx integer            this exchange (1-based)
--- @param exchange_idx integer   the exchange being answered
--- @param total integer          exchanges in the chat
--- @param max_exchanges integer  window_size()
--- @param has_file_refs boolean
--- @return boolean
M.preserve_exchange = function(idx, exchange_idx, total, max_exchanges, has_file_refs)
    return idx == exchange_idx or idx > total - max_exchanges or has_file_refs == true
end

--- Size of an asset named by its transcript-relative path, resolved against
--- the chat file's directory; nil + reason when it cannot be stat'ed. Without
--- a chat path every attachment becomes a visible note, never a silent drop.
local function asset_size(chat_path, rel)
    if chat_path == nil or chat_path == "" then
        return nil, "chat_path not supplied to build_messages"
    end
    local dir = chat_path:match("^(.*)/[^/]+$")
    if not dir then
        return nil, "chat path has no directory: " .. tostring(chat_path)
    end
    return require("parley.assets").default_io.stat(dir .. "/" .. rel)
end

--- Resolve one request's deferred question slots against ONE budget
--- (decision 6). A slot is a retained user message still holding its plain
--- question text, plus that question's attachments and exchange order. The
--- budget is charged with the request as it stands — `payload_size(messages)`,
--- the send guard's own unit, which bounds the retained UTF-8 text from above
--- — then each slot becomes question_content: image blocks for the planned
--- attachments first, the text last, a note for every attachment not sent.
--- No slot → nothing changes, so a text-only request stays byte-identical.
---
--- The budget's identity is the OCCURRENCE (BR-1): every attachment gets
--- `id = "<order>:<n>"` (n = its position within the question) here, in the
--- one place both builders share, so the parser's and attachments_in's
--- id-less tables are never handed to plan_budget/question_content, and the
--- same image linked twice is two candidates — each counted and charged.
--- The slot's attachments are copied, not mutated: the parse result is the
--- caller's.
local function attach_question_images(messages, slots, chat_path, logger)
    if #slots == 0 then
        return
    end
    local assets = require("parley.assets")
    local candidates = {}
    for _, slot in ipairs(slots) do
        local keyed = {}
        for n, att in ipairs(slot.attachments) do
            keyed[n] = vim.tbl_extend("force", att, { id = slot.order .. ":" .. n })
            local size, err = asset_size(chat_path, att.path)
            candidates[#candidates + 1] = { id = keyed[n].id, order = slot.order, path = att.path, size = size, err = err }
        end
        slot.attachments = keyed
    end
    local plan = assets.plan_budget(candidates, assets.payload_size(messages), {
        max_bytes = assets.MAX_BYTES,
        max_request_bytes = assets.MAX_REQUEST_BYTES,
        max_images = assets.MAX_REQUEST_IMAGES,
        block_overhead = assets.BLOCK_OVERHEAD,
    })
    if plan.warning then
        logger.warning(plan.warning)
    end
    local function read(rel)
        if chat_path == nil or chat_path == "" then
            return nil, "chat_path not supplied to build_messages"
        end
        return assets.read_bounded(chat_path, rel)
    end
    for _, slot in ipairs(slots) do
        slot.message.content = assets.question_content(slot.message.content, slot.attachments, plan, read)
    end
end

--------------------------------------------------------------------------------
-- build_messages_from_model — reads content directly from buffer using
-- the model's block positions. No re-parsing. Used by recursive tool-loop
-- calls where the live model is the source of truth.
--------------------------------------------------------------------------------

--- Build the Anthropic messages array from the live model + buffer.
--- Reads block content at model-computed positions.
--- @param buf integer  buffer handle
--- @param model Model  live exchange model
--- @param target_idx integer  exchange to include up to (inclusive)
--- @param agent_info table  { system_prompt, ... }
--- @param opts table|nil  { chat_path, max_exchanges } (#231: where attachments
---   resolve, and the caller's window_size(); absent → every attachment is a
---   visible note / everything retained, this path's pre-#231 behaviour)
--- @return table[] messages
M.build_messages_from_model = function(buf, model, target_idx, agent_info, opts)
    opts = opts or {}
    local serialize = require("parley.tools.serialize")
    local system_prompt_msgs = require("parley.system_prompt_msgs")
    local prov = require("parley.providers")
    local define = require("parley.define")
    local assets = require("parley.assets")
    local chat_parser = require("parley.chat_parser")
    local max_exchanges = opts.max_exchanges or 999999
    local total_exchanges = #model.exchanges
    local slots = {}
    append_neighborhood_context(agent_info, agent_info and agent_info.root_policy)
    local messages = system_prompt_msgs.build(agent_info, function(provider)
        return prov.has_feature(provider, "cache_control")
    end)

    local function read_block_text(k, b)
        local start_line = model:block_start(k, b)
        local end_line = model:block_end(k, b)
        if end_line < start_line then return "" end
        local buf_lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line + 1, false)
        return table.concat(buf_lines, "\n")
    end

    for k = 1, target_idx do
        local blocks = model.exchanges[k].blocks
        -- Normalize this exchange's answer blocks into the content_blocks shape
        -- consumed by _emit_content_blocks_as_messages — the single emitter that
        -- also enforces the tool_use→tool_result invariant (#155). This replaces
        -- an inline copy of the interleaving that had diverged from the parse
        -- path (it lacked the dangling-call synthesis; input coercion now lives
        -- in the emitter, one source). IO (buffer reads + serialize.parse_*)
        -- stays here in the thin normalization seam; the emitter stays pure.
        local answer_blocks = {}
        local function flush_answer()
            if #answer_blocks > 0 then
                for _, m in ipairs(M._emit_content_blocks_as_messages(answer_blocks)) do
                    table.insert(messages, m)
                end
                answer_blocks = {}
            end
        end

        for b = 1, #blocks do
            local blk = blocks[b]
            if blk.size <= 0 then goto continue end

            if blk.kind == "question" then
                local text = read_block_text(k, b)
                -- Prefix matching is literal: configured prefixes may contain Lua pattern characters.
                local user_prefix = (_parley and _parley.config.chat_user_prefix) or "💬:"
                if text:sub(1, #user_prefix) == user_prefix then
                    text = text:sub(#user_prefix + 1)
                end
                text = define.strip_definition_footnote_footer(text:gsub("^%s*(.-)%s*$", "%1"))
                local preface
                if model.exchanges[k].preface then
                    preface = table.concat(vim.api.nvim_buf_get_lines(buf,
                        model:preface_start(k), model:preface_end(k) + 1, false), "\n")
                end
                text = require("parley.question_tags").compose_question(preface, text)
                if text ~= "" then
                    -- Defensive: an answer never precedes its question, but
                    -- flush any accumulated answer blocks to keep ordering stable.
                    flush_answer()
                    -- #231: same grammar, same retention rule, same budget AND
                    -- the same inputs as the parse path (BR-2): the chat's
                    -- total exchange count (not the target — answering 3 of 4
                    -- must not widen the window) and the question's @@ file
                    -- references, read from the block text with the parser's
                    -- own extract_file_refs, which pin it exactly as they pin
                    -- the initial send. Text is re-sent as before — only the
                    -- image bytes are subject to the window and budget.
                    local message = { role = "user", content = text }
                    local attachments = assets.attachments_in(text)
                    if #attachments > 0 then
                        local pinned = #chat_parser.extract_file_refs(text) > 0
                        if M.preserve_exchange(k, target_idx, total_exchanges, max_exchanges, pinned) then
                            slots[#slots + 1] = { message = message, order = k, attachments = attachments }
                        else
                            message.content = assets.omitted_text(text, attachments)
                        end
                    end
                    table.insert(messages, message)
                end

            elseif blk.kind == "agent_header" or blk.kind == "spinner" then
                goto continue  -- not part of messages

            elseif blk.kind == "text" or blk.kind == "stream_placeholder" then
                local text = define.strip_definition_footnote_footer(read_block_text(k, b))
                if text:match("%S") then
                    table.insert(answer_blocks, { type = "text", text = text })
                end

            elseif blk.kind == "tool_use" then
                local text = read_block_text(k, b)
                local parsed = serialize.parse_call(text)
                if parsed then
                    -- Empty-input dict coercion happens in the emitter now.
                    table.insert(answer_blocks, {
                        type = "tool_use",
                        id = parsed.id,
                        name = parsed.name,
                        input = parsed.input,
                    })
                else
                    -- Malformed tool_use — degrade to text so it's not
                    -- silently dropped. Claude sees the raw block text.
                    table.insert(answer_blocks, { type = "text", text = define.strip_definition_footnote_footer(text) })
                end

            elseif blk.kind == "tool_result" then
                local text = read_block_text(k, b)
                local parsed = serialize.parse_result(text)
                if parsed then
                    table.insert(answer_blocks, {
                        type = "tool_result",
                        id = parsed.id,
                        content = parsed.content or "",
                        is_error = parsed.is_error == true,
                    })
                else
                    -- Malformed tool_result — degrade to a user text message,
                    -- preserving user/assistant alternation. Flush accumulated
                    -- answer blocks first so ordering is stable.
                    flush_answer()
                    table.insert(messages, { role = "user", content = define.strip_definition_footnote_footer(text) })
                end
            end

            ::continue::
        end

        flush_answer()
    end

    attach_question_images(messages, slots, opts.chat_path,
        (_parley and _parley.logger) or { warning = function() end })
    return messages
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
-- Reason-agnostic synthetic result for a tool_use that never got a real
-- result. A build-time fallback does NOT know WHY (crash / timeout / manual
-- edit), so the text is neutral — unlike the stop-time buffer repair
-- (tool_loop.repair_unmatched_tool_blocks), which knows the reason and says
-- "(cancelled by user)". #155.
M.DANGLING_TOOL_RESULT_TEXT = "(tool call did not complete — no result recorded)"

M._emit_content_blocks_as_messages = function(content_blocks)
    local messages = {}
    local current_assistant = nil -- accumulating [text, tool_use] for an assistant message
    local current_user = nil      -- accumulating [tool_result] for a user message
    -- Ordered ids of tool_uses in the CURRENT assistant batch that a real
    -- tool_result has not yet resolved. Drained (as synthetic error results)
    -- into the user batch that immediately follows the assistant batch, so the
    -- payload never carries an assistant tool_use without a matching user
    -- tool_result (the HTTP-400 this enforces against). #155.
    local pending = {}

    local function synth_error(id)
        return {
            type = "tool_result",
            tool_use_id = id,
            content = M.DANGLING_TOOL_RESULT_TEXT,
            is_error = true,
        }
    end
    local function drain_pending_into(user)
        for _, id in ipairs(pending) do
            table.insert(user, synth_error(id))
        end
        pending = {}
    end
    -- Remove `id` from pending if present; returns true when it WAS pending (a
    -- matched tool_result), false otherwise — either an ORPHAN (no preceding
    -- tool_use) or a DUPLICATE result whose match was already resolved. The
    -- caller drops the block on false: an unmatched user tool_result is an
    -- Anthropic 400 (the symmetric half of #155's invariant). #156.
    local function resolve_pending(id)
        for i, pid in ipairs(pending) do
            if pid == id then
                table.remove(pending, i)
                return true
            end
        end
        return false
    end

    local function flush_assistant()
        if current_assistant and #current_assistant > 0 then
            table.insert(messages, { role = "assistant", content = current_assistant })
            current_assistant = nil
        end
    end
    -- Only fires when a real tool_result batch is being closed (current_user
    -- non-nil). Any tool_use still pending from the preceding assistant batch
    -- gets a synthetic error result appended to THIS user message before it is
    -- emitted — so partial parallel resolution (some calls answered, some not)
    -- keeps every synthetic in the same immediately-following user message.
    -- Called mid-stream on a text/tool_use block (transition out of a
    -- tool_result run) — a no-op there while still inside an assistant run.
    local function flush_user()
        if current_user then
            drain_pending_into(current_user)
            if #current_user > 0 then
                table.insert(messages, { role = "user", content = current_user })
            end
            current_user = nil
        end
    end

    for _, block in ipairs(content_blocks or {}) do
        if block.type == "tool_result" then
            if resolve_pending(block.id) then
                -- Matched: a still-pending tool_use with this id was emitted in
                -- the preceding assistant batch — this is its result. Flush the
                -- open assistant batch so the tool_result lands in its own user
                -- message directly after.
                flush_assistant()
                current_user = current_user or {}
                table.insert(current_user, {
                    type = "tool_result",
                    tool_use_id = block.id,
                    content = block.content or "",
                    is_error = block.is_error == true,
                })
            end
            -- else: ORPHAN or DUPLICATE tool_result — dropped, and we do NOT
            -- flush the assistant batch here, so text surrounding the orphan
            -- (e.g. [text, orphan, text]) stays in ONE assistant message rather
            -- than splitting into two consecutive assistant turns. Emitting an
            -- unmatched user tool_result would be an Anthropic 400; the 📎: block
            -- stays visible in the buffer, only the wire excludes it. #156.
        else
            -- text or tool_use — these belong to an assistant message.
            -- Flush any open user batch first (draining its pending).
            flush_user()
            current_assistant = current_assistant or {}
            if block.type == "text" then
                table.insert(current_assistant, { type = "text", text = block.text or "" })
            elseif block.type == "tool_use" then
                -- Empty Lua table {} encodes as JSON []; Anthropic requires {}.
                -- Coerced here (single source) so BOTH build paths are correct
                -- — the parse path previously skipped this. #155.
                local input = block.input
                if not input or not next(input) then
                    input = vim.empty_dict()
                end
                table.insert(current_assistant, {
                    type = "tool_use",
                    id = block.id,
                    name = block.name,
                    input = input,
                })
                table.insert(pending, block.id)
            end
        end
    end

    -- Flush whichever role was last accumulating. flush_user() drains pending
    -- into a trailing real tool_result batch if one is open; if not (a dangling
    -- tool_use with NO result batch at all, e.g. [tool_use] or [tool_use,text]),
    -- open a fresh user message for the synthetics.
    flush_assistant()
    flush_user()
    if #pending > 0 then
        local user = {}
        drain_pending_into(user)
        table.insert(messages, { role = "user", content = user })
    end

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
    local define = require("parley.define")
    local function scrub_content_blocks(blocks)
        local out = {}
        for _, block in ipairs(blocks or {}) do
            local copy = vim.deepcopy(block)
            if copy.type == "text" and type(copy.text) == "string" then
                copy.text = define.strip_definition_footnote_footer(copy.text)
            end
            out[#out + 1] = copy
        end
        return out
    end

    -- Process headers for agent information
    local headers = parsed_chat.headers

    -- Prepare for summary extraction
    local memory_enabled = opts_config.chat_memory and opts_config.chat_memory.enable

    -- #231: ONE retention rule, shared with build_messages_from_model.
    local max_exchanges = M.window_size(headers, opts_config)
    logger.debug("Memory window: " .. tostring(max_exchanges) .. " full exchanges")
    local assets = require("parley.assets")
    -- Retained questions with attachments; resolved after the loop against
    -- one budget (attach_question_images).
    local slots = {}

    local omit_user_text = memory_enabled and opts_config.chat_memory.omit_user_text or "[Previous messages omitted]"

    -- Get combined agent information using the helper function
    local agent_info = _parley.get_agent_info(headers, agent)

    -- Normalize the system prompt: trim outer whitespace, then re-add a
    -- trailing newline when system_prompt+ header appends were applied.
    -- Done on agent_info.system_prompt directly (not on messages[1]) so
    -- the normalization is independent of how the leading messages are
    -- shaped (real system message vs. synthetic user/assistant pair).
    if type(agent_info.system_prompt) == "string" then
        agent_info.system_prompt = agent_info.system_prompt:gsub("^%s*(.-)%s*$", "%1")
    end
    local has_system_prompt_append = false
    if type(headers) == "table" and type(headers._append) == "table" then
        local canonical = headers._append.system_prompt
        local legacy = headers._append.role
        has_system_prompt_append = (type(canonical) == "table" and #canonical > 0) or (type(legacy) == "table" and #legacy > 0)
    end
    if has_system_prompt_append
        and type(agent_info.system_prompt) == "string"
        and agent_info.system_prompt ~= ""
        and agent_info.system_prompt:sub(-1) ~= "\n"
    then
        agent_info.system_prompt = agent_info.system_prompt .. "\n"
    end
    append_neighborhood_context(agent_info, opts.root_policy)

    -- Convert parsed_chat to messages for the model using a single-pass approach.
    -- Leading messages (system prompt or synthetic pair) are prepended after the
    -- exchange loop, not seeded as a placeholder.
    local messages = {}

    -- Process each exchange, determining whether to preserve or summarize
    local total_exchanges = #parsed_chat.exchanges

    -- Single pass through all exchanges
    for idx, exchange in ipairs(parsed_chat.exchanges) do
        if exchange.question and exchange.question.line_start >= start_index and idx <= exchange_idx then
            -- Preserve in full: the current question, a recent exchange, or
            -- one pinned by file references (M.preserve_exchange).
            local should_preserve = M.preserve_exchange(
                idx, exchange_idx, total_exchanges, max_exchanges, #exchange.question.file_references > 0)
            logger.debug("Exchange #" .. idx .. (should_preserve and " preserved in full" or " summarized"))

                -- Process the question
                if should_preserve then
                    -- Get the question content and process any file loading directives
                    local question_content = require("parley.question_tags").compose_question(
                        exchange.preface and exchange.preface.content,
                        define.strip_definition_footnote_footer(exchange.question.content))
                    local file_content_parts = {}

                    -- Raw request input feature: detect a `yaml {"type":"request"}`
                    -- fence at the bottom of the question and use it verbatim as
                    -- the API payload. The YAML form lets the user copy a turn
                    -- from the raw log, paste, edit, and re-send.
                    do
                        local yaml_content = question_content:match('```yaml%s+{"type":%s*"request"}%s*\n(.-)\n```')
                        if yaml_content then
                            logger.debug("Found typed YAML request block in question, using raw request mode")
                            local payload, err = require("parley.log_emit").parse_yaml(yaml_content)
                            if payload and type(payload) == "table" then
                                exchange.question.raw_payload = payload
                                logger.debug("Successfully parsed YAML payload: "
                                    .. vim.inspect(assets.elide_image_data(payload)))
                            else
                                logger.warning("Failed to parse YAML in raw request mode: " .. tostring(err))
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

                    -- #231: the question is a SLOT — a plain-text user message
                    -- that attach_question_images turns into image blocks once
                    -- the retained text is known and one budget is planned.
                    local user_message = { role = "user", content = question_content }
                    local attachments = exchange.question.attachments
                    if attachments and #attachments > 0 then
                        slots[#slots + 1] = { message = user_message, order = idx, attachments = attachments }
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
                        table.insert(messages, user_message)
                    else
                        -- No file references, just add the question as user message
                        table.insert(messages, user_message)
                    end
                else
                    -- The placeholder for a summarized question; it says an
                    -- image was there, so the model is not left inferring it.
                    table.insert(messages, {
                        role = "user",
                        content = assets.omitted_text(omit_user_text, exchange.question.attachments),
                    })
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
                        for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
                            table.insert(messages, m)
                        end
                    else
                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
                    end
                else
                    -- Use the summary if available
                    if exchange.summary then
                        table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.summary.content) })
                    else
                        -- If no summary is available, use the full content (fallback)
                        if answer_has_tool_blocks then
                            for _, m in ipairs(M._emit_content_blocks_as_messages(scrub_content_blocks(exchange.answer.content_blocks))) do
                                table.insert(messages, m)
                            end
                        else
                            table.insert(messages, { role = "assistant", content = define.strip_definition_footnote_footer(exchange.answer.content) })
                        end
                    end
                end
            end
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

    -- Prepend the leading system-prompt messages. Either:
    --   * one role="system" message (default), or
    --   * a role="user" message with the system text + a role="assistant"
    --     ack ("Got it. I will follow this.") when the agent has
    --     synthetic_system_prompt = true.
    -- Helper handles cache_control parity and is provider-aware.
    local system_prompt_msgs = require("parley.system_prompt_msgs")
    local prov = require("parley.providers")
    local leading = system_prompt_msgs.build(agent_info, function(provider)
        return prov.has_feature(provider, "cache_control")
    end)
    for i = #leading, 1, -1 do
        table.insert(messages, 1, leading[i])
    end

    -- #231: after trimming and the leading messages, so the budget sees the
    -- request as it will go out and the text blocks carry the trimmed text.
    attach_question_images(messages, slots, opts.chat_path, logger)

    return messages, #leading
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
-- @param callback  function called with (topic_string, nil) on success or
--                  (nil, reason) on terminal failure
-- @param spinner   table|nil optional {buf, find_line} — buf is the buffer to animate,
--                  find_line() returns 0-indexed line number of the topic line (or nil to skip)
-- @param transport_opts table|nil parent generation/admission for automatic topics
--- Pure: drop the first `lead` messages from a built messages array, returning
--- just the current-file conversation turns. `lead` = (# system-prompt messages)
--- + (# ancestor messages). The system prompt is 1 message normally, but 2 for
--- a synthetic system prompt (leading user turn + assistant ack) — so dropping
--- by COUNT is robust to both encodings. Exposed for tests.
---@param messages table[]
---@param lead integer
---@return table[]
function M._conversation_after_lead(messages, lead)
    local out = {}
    for i = (lead or 0) + 1, #messages do
        out[#out + 1] = vim.deepcopy(messages[i])
    end
    return out
end

M.generate_topic = function(messages, provider, model, callback, spinner, transport_opts)
    -- Build a clean copy: strip whitespace, drop empty messages and cache_control.
    -- Messages carrying content-block arrays (Anthropic tool-use shape, M2
    -- Task 2.6 of #81) are flattened to a plain-text excerpt for topic
    -- generation — the topic model doesn't care about tool blocks.
    local msgs = {}
    for _, m in ipairs(messages) do
        -- Drop the persona system prompt for topic generation: it's a utility
        -- call, and the default system prompt mandates a `🧠:` thinking block —
        -- which an obedient model emits, and which then becomes the "topic".
        if m.role ~= "system" then
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
    end
    table.insert(msgs, { role = "user", content = _parley.config.chat_topic_gen_prompt })

    -- Topic progress is decoration, not source text. Resolve the initial target
    -- once; native extmarks relocate it without rescanning the transcript.
    local spinner_frames = require("parley.progress").SPINNER
    local spinner_idx, spinner_timer, spinner_mark = 1, nil, nil
    local spinner_ns = vim.api.nvim_create_namespace("parley_topic_pending")
    local finished, topic_parts, topic_bytes, line_complete, collection_error = false, {}, 0, false, nil
    local function hide_spinner()
        stop_and_close_timer(spinner_timer)
        spinner_timer = nil
        if spinner_mark and spinner and vim.api.nvim_buf_is_valid(spinner.buf) then
            pcall(vim.api.nvim_buf_del_extmark, spinner.buf, spinner_ns, spinner_mark)
        end
        spinner_mark = nil
    end
    if spinner and spinner.buf and spinner.find_line and vim.api.nvim_buf_is_valid(spinner.buf) then
        local row = spinner.find_line()
        if row then
            spinner_mark = vim.api.nvim_buf_set_extmark(spinner.buf, spinner_ns, row, 0,
                { end_row = row + 1, end_col = 0, invalidate = true, undo_restore = false })
        end
        spinner_timer = vim.uv.new_timer()
        spinner_timer:start(0, 120, vim.schedule_wrap(function()
            -- Parent lifetime is checked even when no topic line is drawable.
            if finished or spinner.before_write and not spinner.before_write()
                or not vim.api.nvim_buf_is_valid(spinner.buf) then
                hide_spinner()
                return
            end
            if spinner_mark then
                local mark = vim.api.nvim_buf_get_extmark_by_id(spinner.buf, spinner_ns, spinner_mark, { details = true })
                if #mark < 2 or mark[3].invalid then hide_spinner(); return end
                vim.api.nvim_buf_set_extmark(spinner.buf, spinner_ns, mark[1], mark[2], {
                    id = spinner_mark, end_row = mark[3].end_row, end_col = mark[3].end_col,
                    invalidate = true, undo_restore = false,
                    virt_text = { { "topic: " .. spinner_frames[spinner_idx] .. " generating...", "Comment" } },
                    virt_text_pos = "overlay",
                })
            end
            spinner_idx = spinner_idx % #spinner_frames + 1
        end))
    end

    local topic_handler = _parley.dispatcher.create_output_handler(function(_, chunk)
        if finished then return false end
        if line_complete or collection_error then return true end
        local prefix = chunk:sub(1, 4097 - topic_bytes)
        local newline = prefix:find("\n", 1, true)
        if newline then prefix = prefix:sub(1, newline - 1); line_complete = true end
        if topic_bytes + #prefix > 4096 then
            collection_error = "topic too long"
            topic_parts = {}
            hide_spinner()
            if transport_opts and transport_opts.generation_id then
                _parley.tasker.stop_owner(transport_opts.generation_id)
            end
            return false
        end
        topic_parts[#topic_parts + 1] = prefix
        topic_bytes = topic_bytes + #prefix
        return true
    end)
    local function finish(topic, reason)
        if finished then return end
        finished = true
        hide_spinner()
        topic_parts = {}
        callback(topic, reason)
    end

    -- Abort teardown (#131): stop the topic presentation
    -- if the managed cliproxy can't start, so topic-gen fails quietly (no hang).
    local function on_abort(msg)
        if finished then return end
        finish(nil, "abort")
        vim.notify(msg or "parley: topic generation aborted", vim.log.levels.WARN)
    end

    _parley.dispatcher.query(
        nil,
        provider,
        _parley.dispatcher.prepare_payload(msgs, model, provider),
        topic_handler,
        vim.schedule_wrap(function()
            if finished then return end
            if collection_error then finish(nil, collection_error); return end
            local topic = table.concat(topic_parts)
            topic = topic:gsub("^%s*(.-)%s*$", "%1")
            topic = topic:gsub("%.$", "")
            if topic ~= "" then
                finish(topic, nil)
            else
                finish(nil, "empty")
            end
        end),
        nil,
        nil,
        on_abort,
        nil,
        function(_, failure)
            -- The dispatcher's legacy completion fallback accepts partial text
            -- on failure. A utility topic must never publish that as success.
            finish(nil, M._failure_notice(failure))
        end,
        transport_opts
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

    local operation = {pending = 0, launching = true, cancelled = false, finished = false}
    local on_failure, cancelled = opts.on_failure, opts.cancelled
    local function admission_open()
        if cancelled then
            local ok, value = pcall(cancelled)
            if not ok or value then operation.cancelled = true end
        end
        return not operation.cancelled
    end
    local function finish()
        if operation.finished or operation.launching or operation.pending > 0 then return end
        operation.finished = true
        local done, value, reason = callback, resolved, operation.failure
        if operation.cancelled then reason = reason or 'remote preparation cancelled' end
        callback = nil; on_failure = nil; cancelled = nil; resolved = nil
        -- The callback acknowledges completion of every started child, including
        -- a throwing launch whose retained callback later supplied evidence.
        pcall(done, reason and nil or value, reason)
    end
    local function failed(reason)
        if operation.failure or operation.finished then return end
        operation.failure = tostring(reason)
        if on_failure then pcall(on_failure, operation.failure) end
    end
    function operation:cancel()
        if self.finished or self.cancelled then return false end
        self.cancelled = true
        -- OAuth currently has no cancellation/physical-resolution handle. Its
        -- callback is the positive terminal evidence; a stop request cannot
        -- replace that evidence or decrement pending children.
        finish()
        return true
    end
    for _, url in ipairs(urls_to_fetch) do
        if not admission_open() or operation.failure then break end
        local child = {done = false}
        operation.pending = operation.pending + 1
        local function complete(content, err)
            if child.done then return end
            child.done = true
            if admission_open() and not operation.failure then
                local ok, failure = pcall(function()
                    local cached_content = content
                    if not cached_content then
                        cached_content = M.format_remote_reference_error_content(url, err)
                        _parley.logger.warning('Failed to fetch remote content: ' .. (err or 'unknown error'))
                    end
                    resolved[url] = cached_content
                    chat_cache[url] = cached_content
                    M.save_remote_reference_cache()
                end)
                if not ok then failed(failure) end
            end
            operation.pending = operation.pending - 1
            finish()
        end
        -- Register before invoking IO. A throw may happen after a process or
        -- picker starts; retain this child until complete positively settles it.
        local ok, reason = pcall(function()
            oauth.fetch_content(url, opts_config.oauth or opts_config.google_drive, complete)
        end)
        if not ok then failed(reason) end
    end
    operation.launching = false
    finish()
    return operation
end

--------------------------------------------------------------------------------
-- chat_respond  (main streaming response handler)
--------------------------------------------------------------------------------

-- Active response membership is keyed by the captured buffer. A session owns
-- its document grants and effects; membership is only for explicit Stop/UI.
local responses = {}
local batches = {}
local response_order = 0
function M.response_snapshot(session)
    return require('parley.response_session').snapshot(session)
end
local function cancel_entry(entry)
    if entry.batch then require('parley.batch_response').cancel(entry.batch) end
    if entry.topic then require('parley.response_topic').cancel(entry.topic, 'operator stopped response') end
    if entry.session then
        require('parley.response_session').cancel(entry.session, 'operator stopped response')
        return 1
    end
    return 0
end
function M.cancel_responses(buf)
    if batches[buf] then require('parley.batch_response').cancel(batches[buf]) end
    local group = responses[buf]
    if not group then return 0 end
    local copy = {}; for entry in pairs(group) do copy[#copy + 1] = entry end
    local count = 0
    for _, entry in ipairs(copy) do count = count + cancel_entry(entry) end
    return count
end
function M.stop_at_cursor(buf, row)
    local D = require('parley.document')
    local doc, group = D.get(buf), responses[buf]
    if not doc or not group then return 0 end
    local epoch = D.snapshot(doc).epoch
    local exchange = D.exchange(doc, row)
    local choices = {}
    for entry in pairs(group) do
        if entry.session and entry.doc == doc and entry.epoch == epoch then
            local snapshot = M.response_snapshot(entry.session)
            local generation = snapshot.generation
            if exchange.status == 'ready' and generation and generation.exchange == exchange.identity then
                return cancel_entry(entry)
            end
            choices[#choices + 1] = {entry = entry, label = entry.label,
                generation = generation and generation.generation}
        end
    end
    if #choices == 0 then return 0 end
    table.sort(choices, function(a,b) return a.entry.order < b.entry.order end)
    local admitted = {}; for _, choice in ipairs(choices) do admitted[choice] = true end
    vim.ui.select(choices, {prompt = 'Stop response generation:', format_item = function(choice)
        return choice.label .. ' [generation ' .. tostring(choice.generation or 'preparing') .. ']'
    end}, function(choice)
        if not choice or not admitted[choice] then return end
        if D.get(buf) ~= doc or D.snapshot(doc).epoch ~= epoch
            or responses[buf] ~= group or not group[choice.entry] then return end
        cancel_entry(choice.entry)
    end)
    return 0
end

local function start_scoped_response(frame)
    local D = require('parley.document')
    local Session = require('parley.response_session')
    local Layout = require('parley.response_layout')
    local Preparation = require('parley.response_preparation')
    local buf, config = frame.buf, vim.deepcopy(_parley.config)
    local parsed = vim.deepcopy(frame.parsed)
    local index = frame.exchange_idx or #parsed.exchanges
    local exchange = parsed.exchanges[index]
    if not exchange or not exchange.question then return nil, 'no question selected' end
    local question = exchange.question
    local last = exchange.answer and exchange.answer.line_end or question.line_end
    local footer = trailing_footnote_boundary(frame.lines, question.line_end)
    if footer then last = math.max(question.line_end, math.min(last, footer)) end
    local agent = vim.deepcopy(_parley.get_agent())
    local selected_record = (_parley.agents or {})[agent.name]
    local model_name = type(agent.model) == 'table' and agent.model.model or agent.model
    local needs_agent = selected_record and selected_record.placeholder == true or model_name == 'choose-a-model'
    local info = _parley.get_agent_info(parsed.headers, agent)
    local root_policy = frame.params.root_policy or require('parley.neighborhood').policy_for_buf(buf)
    info.root_policy = root_policy
    local source = {}
    for row = question.line_end + 1, last do source[#source + 1] = frame.lines[row] end
    local first_byte = vim.api.nvim_buf_get_offset(buf, question.line_end)
    local function preparation_plan()
        local prefix = config.chat_assistant_prefix
        local suffix = type(prefix) == 'table' and prefix[2] or ''
        prefix = type(prefix) == 'table' and prefix[1] or prefix
        suffix = _parley.render.template(suffix or '', {['{{agent}}'] = info.display_name})
        local layout = Layout.prepare({lines = source, first_row = question.line_end,
            first_byte = first_byte, header_lines = {prefix .. suffix}}, config)
        return Preparation.plan(layout, {at_eof = last == #frame.lines})
    end
    local plan = preparation_plan()
    local point = {row = question.line_end - 1, col = #frame.lines[question.line_end]}
    local spec = {operation = 'respond', question = {first = {row = question.line_start - 1, col = 0}, last = point},
        output = {first = point, last = {row = last - 1, col = #frame.lines[last]}},
        preparation = plan, input = {selection = index}, input_prefix = true}
    -- The captured request excludes the answer being replaced. Its old bytes
    -- remain in the editor until preparation has acquired every mutable gap.
    exchange.answer = nil
    local doc = D.get(buf) or D.attach(buf, {patterns = require('parley.highlight_structure').patterns(config)})
    local group = responses[buf] or {}; responses[buf] = group
    response_order = response_order + 1
    local entry = {doc = doc, epoch = D.snapshot(doc).epoch, order = response_order, batch = frame.batch,
        label = (frame.lines[question.line_start] or 'Response'):sub(1, 256)}; group[entry] = true
    local latest, messages, final_payload, topic_source, topic_parent, failure_notice
    local message_lead = 0
    local topic_attempted, main_finished, topic_finished = false, false, true
    if parsed.headers.topic == '?' then
        for row = 1, find_chat_header_end(frame.lines) do
            local line = frame.lines[row]
            if line:match('^#%s*topic:%s*%?%s*$') or line:match('^%s*topic:%s*%?%s*$') then
                local col = line:find('?', 1, true) - 1
                topic_source = D.capture_user(doc, {operation = 'topic-header-source', regions = {
                    {first = {row = row - 1, col = col}, last = {row = row - 1, col = col + 1}}}})
                break
            end
        end
    end
    local function release()
        if not main_finished or not topic_finished then return end
        if topic_source then D.cancel_user(doc, topic_source); topic_source = nil end
        if topic_parent then D.cancel_user(doc, topic_parent); topic_parent = nil end
        group[entry] = nil
        if not next(group) and responses[buf] == group then responses[buf] = nil end
    end
    local function payload(previous, next_messages)
        local request = vim.deepcopy(previous)
        request.messages = next_messages
        request.payload = _parley.dispatcher.prepare_payload(next_messages, info.model, info.provider, info.tools)
        messages, final_payload = next_messages, request.payload
        return request
    end
    local function capture_topic_parent(ctx)
        if not topic_source or topic_parent or topic_attempted then return end
        local marker = D.lookup(doc, ctx.entity)
        local grant = D.snapshot(doc).grants[ctx.grant]
        local question_end = grant and D.byte_position(doc, grant.first)
        if not marker or not question_end then return end
        local answer = D.query(doc, question_end.row + 2, question_end.row + 3)[1]
        if not answer or not answer.metadata or not answer.metadata.semantic
            or not answer.metadata.semantic.answer_start then return end
        topic_parent = D.capture_user(doc, {operation = 'topic-parent-source', regions = {
            {first = {row = marker.start_row, col = 0},
                last = {row = marker.start_row, col = marker.end_byte - marker.start_byte - 1}},
            {first = {row = answer.start_row, col = 0},
                last = {row = answer.start_row, col = answer.end_byte - answer.start_byte - 1}},
        }})
    end
    local function start_topic()
        if topic_attempted then return end
        topic_attempted = true
        local header = topic_source and D.resolve_user(doc, topic_source)
        local parents = topic_parent and D.resolve_user(doc, topic_parent)
        if not header or not parents then return end
        local Topic = require('parley.response_topic')
        local conversation = M._conversation_after_lead(messages or {}, message_lead)
        conversation[#conversation + 1] = {role = 'assistant', content = latest and latest.response or ''}
        local input = Topic.input(conversation, info.provider, info.model, config.chat_topic_gen_prompt, _parley.dispatcher)
        input.buf = buf
        topic_finished = false
        entry.topic = Topic.start(doc, {header = header.regions[1], parents = parents.regions, input = input}, {
            buf = buf, dispatcher = _parley.dispatcher, tasker = _parley.tasker,
            terminal = function()
                topic_finished = true; entry.topic = nil
                if vim.api.nvim_buf_is_valid(buf) then
                    require('parley.buffer_lifecycle').finalize_mutated_api_leg(buf, true)
                end
                release()
            end,
        })
        if not entry.topic then topic_finished = true end
        D.cancel_user(doc, topic_source); topic_source = nil
        D.cancel_user(doc, topic_parent); topic_parent = nil
    end
    local function prepare_input(ctx, cb)
        local operation = {cancelled = false, resolved = false}
        local function resolve()
            if operation.resolved then return end
            operation.resolved = true
            local done = operation.cancel_done or cb.resolved
            operation.cancel_done = nil
            done()
        end
        function operation:cancel(done)
            self.cancelled = true
            if self.resolved then done() else self.cancel_done = done end
            if self.remote then self.remote:cancel() end
        end
        local function logical_failure(reason)
            if operation.cancelled or operation.failed then return end
            operation.failed = true
            cb.failed(reason)
            local message = tostring(reason):match('^[^\n]+') or 'unknown preparation failure'
            pcall(vim.notify, 'Response not started: ' .. message, vim.log.levels.WARN)
        end
        local function fail(reason)
            logical_failure(reason)
            resolve()
        end
        local function build(remote, remote_error)
            if operation.cancelled or ctx.cancelled() then resolve(); return end
            if remote_error then fail(remote_error); return end
            local ok, err = xpcall(function()
                messages, message_lead = M.build_messages({parsed_chat = parsed, start_index = frame.start_index,
                    end_index = frame.end_index, exchange_idx = index, agent = agent, config = config,
                    helpers = _parley.helpers, logger = _parley.logger, resolved_remote_content = remote,
                    root_policy = info.root_policy, chat_path = frame.file_name})
                if parsed.parent_link then
                    local ancestors = collect_ancestor_messages(frame.file_name, parsed)
                    for i = #ancestors, 1, -1 do table.insert(messages, message_lead + 1, ancestors[i]) end
                    message_lead = message_lead + #ancestors
                end
                final_payload = question.raw_payload or _parley.dispatcher.prepare_payload(
                    messages, info.model, info.provider, info.tools)
                local assets = require('parley.assets')
                if assets.has_image(final_payload) and assets.payload_size(final_payload) > assets.MAX_REQUEST_BYTES then
                    error(string.format('request refused: image payload exceeds the %d-byte limit',
                        assets.MAX_REQUEST_BYTES), 0)
                end
                cb.prepared({buf = buf, provider = info.provider, model = info.model,
                    messages = messages, payload = final_payload, response_profile = {
                        agent = info.display_name,
                        max_iterations = info.max_tool_iterations or config.max_tool_iterations,
                        max_result_bytes = info.tool_result_max_bytes,
                    }}, plan)
            end, debug.traceback)
            if not ok then fail(err) else resolve() end
        end
        local function ready()
            if operation.cancelled or ctx.cancelled() then resolve(); return end
            if needs_agent then
                local chosen = vim.deepcopy(_parley.get_agent())
                local record = (_parley.agents or {})[chosen.name]
                local model = type(chosen.model) == 'table' and chosen.model.model or chosen.model
                if record and record.placeholder or model == 'choose-a-model' or not model then
                    fail('Choose a model before submitting'); return
                end
                agent = chosen
                info = _parley.get_agent_info(parsed.headers, agent)
                info.root_policy = root_policy
                plan = preparation_plan()
                needs_agent = false
            end
            local ok, remote = pcall(M.resolve_remote_references, {parsed_chat = parsed, config = config,
                chat_file = frame.file_name, exchange_idx = index,
                cancelled = function()return operation.cancelled or ctx.cancelled()end,
                on_failure = logical_failure}, build)
            if not ok then fail(remote)
            else
                operation.remote = remote
                if operation.cancelled and remote then remote:cancel() end
            end
        end
        local deferred = require('parley.llm_readiness').defer(_parley, ready,
            {buf = buf, validate_source = function() return not operation.cancelled and not ctx.cancelled() end,
                on_cancel = fail})
        if not deferred then ready() end
        return operation
    end
    local last_cursor = frame.cursor
    local session, reason = Session.start(doc, spec, {buf = buf, agent = info.display_name,
        dispatcher = _parley.dispatcher, tasker = _parley.tasker,
        root_policy = info.root_policy, max_iterations = info.max_tool_iterations or config.max_tool_iterations,
        max_result_bytes = info.tool_result_max_bytes, prepare_input = prepare_input, build_input = payload,
        requesting = capture_topic_parent,
        on_result = function(_, qt, _, failure)
            latest = {response = qt.response, stop_reason = qt.stop_reason, usage = vim.deepcopy(qt.usage)}
            if failure then failure_notice = M._failure_notice(failure) end
            local rm = config.raw_mode or {}
            if rm.enable then
                local assets, raw_log = require('parley.assets'), require('parley.raw_log')
                if rm.log_exchange then pcall(raw_log.write_exchange_turn, frame.file_name, assets.elide_image_data(messages)) end
                if rm.log_raw then pcall(raw_log.write_raw_turn, frame.file_name, {
                    request = assets.elide_image_data(final_payload), assembled = latest,
                    sse_lines = qt.raw_response and vim.split(qt.raw_response, '\n', {plain = true})}) end
            end
        end,
        written = function(_, receipt)
            if receipt.kind ~= 'output' or not receipt.tip or not is_follow_cursor_enabled(frame.follow) then return end
            if not vim.api.nvim_win_is_valid(frame.win) or vim.api.nvim_get_current_win() ~= frame.win
                or vim.api.nvim_win_get_buf(frame.win) ~= buf or vim.api.nvim_get_mode().mode:match('^[iR]') then return end
            local current = vim.api.nvim_win_get_cursor(frame.win)
            if not vim.deep_equal(current, last_cursor) then return end
            last_cursor = {receipt.tip.row + 1, receipt.tip.col}
            pcall(vim.api.nvim_win_set_cursor, frame.win, last_cursor)
        end,
        finalize = function(ctx, done)
            start_topic()
            return require('parley.response_completion').start(doc, ctx, done, {user_prefix = config.chat_user_prefix})
        end,
        rejected = function(why)
            main_finished = true; release(); _parley.logger.warning('Response not started: ' .. tostring(why))
            if frame.terminal then frame.terminal({outcome = 'start refused'}) end
        end,
        terminal = function(result)
            main_finished = true
            if result.outcome ~= 'success' and entry.topic then
                require('parley.response_topic').cancel(entry.topic, 'origin response stopped')
            end
            release()
            if vim.api.nvim_buf_is_valid(buf) then
                require('parley.buffer_lifecycle').finalize_mutated_api_leg(buf, true)
            end
            if failure_notice then vim.notify(failure_notice, vim.log.levels.WARN); failure_notice = nil end
            if frame.terminal then frame.terminal(result) end
            if result.outcome == 'success' then
                vim.cmd('doautocmd User ParleyDone')
                if frame.callback then frame.callback() end
            end
        end,
    })
    entry.session = session
    if not session then main_finished = true; release() end
    return session, reason
end

M.respond = function(params, callback, override_free_cursor)
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

    -- Drill-in handling, two paths. Either way a ready 🤖...[U] marker (with
    -- or without a `<T>` quoted body — see #123) becomes a quote+question block
    -- and is stripped in place: markers with `<T>` collapse to plain T inline,
    -- markers without it are removed entirely. Re-parse afterwards so the rest
    -- of the pipeline sees the modified state.
    --
    -- (A) Branch path — when the cursor sits inside an existing exchange that
    --     contains ready 🤖...[U] markers, treat each marker as a follow-up
    --     question and *insert a new user turn after the exchange*. The
    --     original exchange's question/answer is preserved (with markers
    --     collapsed); the LLM then answers the inserted new turn. This is
    --     what the user usually wants when they drill into a term in a past
    --     exchange — not a resubmit of the original Q.
    --
    -- (B) End-append path — otherwise, on the new-turn path (cursor at end /
    --     on the unanswered last question), gather every ready drill-in in
    --     the buffer and append the blocks to the next user turn at the end.
    local drill_in = require("parley.drill_in")
    local branch_handled = false

    -- Turn-prefix boundaries for unquoted-marker anchor inference (#127): the
    -- backward prose scan must not cross out of the marker's own agent turn
    -- (into the 💬: question, a 🧠:/📎: block, or a neighboring exchange). The
    -- config→prefix mapping is a tested pure helper; drill_in's core stays pure.
    -- `bracket` encloses each referenced span in `[]` in place so the reader can
    -- see what the gathered comment points at (highlighted via ParleyReference).
    local di_opts = drill_in.chat_gather_opts(_parley.config)

    if params.range ~= 2 and exchange_idx and component then
        local exch = parsed_chat.exchanges[exchange_idx]
        local exch_start = require("parley.question_tags").semantic_start(exch)
        local exch_end = (exch.answer and exch.answer.line_end) or exch.question.line_end
        local exch_lines = {}
        for i = exch_start, exch_end do table.insert(exch_lines, lines[i]) end
        local exchange_text = table.concat(exch_lines, "\n")
        local blocks, transformed = drill_in.gather_edit_plan(exchange_text, di_opts)
        if #blocks > 0 then
            local user_prefix = _parley.config.chat_user_prefix or "💬:"
            local block_lines = drill_in.format_blocks(blocks)
            local buffer_edit = require("parley.buffer_edit")
            local capture, why = buffer_edit.capture_user(buf, 'drill-in-branch', {{
                first = {row = exch_start - 1, col = 0},
                last = {row = exch_end - 1, col = #lines[exch_end]},
            }})
            if not capture then _parley.logger.warning('Drill-in stopped: ' .. tostring(why)); return end
            local after = {}
            for i = 1, exch_start - 1 do after[#after + 1] = lines[i] end
            for _, line in ipairs(vim.split(transformed, '\n', {plain = true})) do after[#after + 1] = line end
            after[#after + 1] = ''
            after[#after + 1] = user_prefix
            for _, line in ipairs(block_lines) do after[#after + 1] = line end
            local new_turn_end = #after
            for i = exch_end + 1, #lines do after[#after + 1] = lines[i] end
            local result = buffer_edit.apply_user_line_hunks(capture, lines, after)
            if result.status ~= 'applied' then
                _parley.logger.warning('Drill-in stopped: ' .. tostring(result.reason or result.status)); return
            end
            _parley.logger.info(string.format(
                "Drill-in branch: %d marker(s) → new turn after exchange #%d",
                #blocks, exchange_idx
            ))

            -- Re-read state and re-target. The newly inserted user turn becomes
            -- a fresh exchange in parsed_chat — this is the exchange the LLM
            -- response should populate (target_idx in the closure below derives
            -- from exchange_idx). end_index is capped at new_turn_end so the
            -- now-stale exchanges below the inserted turn aren't part of the
            -- API context for this turn.
            lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            parsed_chat = _parley.parse_chat(lines, header_end)
            local new_idx = _parley.find_exchange_at_line(parsed_chat, new_turn_end)
            exchange_idx = new_idx
            component = "question"
            end_index = new_turn_end
            -- Move the cursor too so any cursor-driven follow-up logic
            -- (highlights, post-stream cursor moves) lands on the new turn.
            pcall(vim.api.nvim_win_set_cursor, 0, { new_turn_end, 0 })
            branch_handled = true
        end
    end

    -- Resubmit = explicit range, OR cursor on an existing answer, OR cursor on
    -- a past question that already has an answer. Cursor on the last unanswered
    -- question is the *new turn* and should still drive drill-in pre-processing.
    local is_resubmit = (params.range == 2)
    if not branch_handled and not is_resubmit and exchange_idx then
        if component == "answer" then
            is_resubmit = true
        elseif component == "question" and parsed_chat.exchanges[exchange_idx].answer then
            is_resubmit = true
        end
    end
    if not branch_handled and not is_resubmit then
        local source_text = table.concat(lines, "\n")
        local di_blocks, transformed = drill_in.gather_edit_plan(source_text, di_opts)
        if #di_blocks > 0 then
            local buffer_edit = require("parley.buffer_edit")
            local capture, why = buffer_edit.capture_user(buf, 'drill-in-gather', {{
                first = {row = 0, col = 0}, last = {row = #lines - 1, col = #lines[#lines]},
            }})
            if not capture then _parley.logger.warning('Drill-in stopped: ' .. tostring(why)); return end
            local after = vim.split(transformed, '\n', {plain = true})
            while #after > 0 and after[#after] == '' do after[#after] = nil end
            if #after > 0 then after[#after + 1] = '' end
            for _, line in ipairs(drill_in.format_blocks(di_blocks)) do after[#after + 1] = line end
            local result = buffer_edit.apply_user_line_hunks(capture, lines, after)
            if result.status ~= 'applied' then
                _parley.logger.warning('Drill-in stopped: ' .. tostring(result.reason or result.status)); return
            end
            _parley.logger.info(string.format(
                "Drill-in: gathered %d marker(s) into next turn", #di_blocks
            ))
            -- Re-read so the rest of the pipeline sees the rewritten buffer.
            lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            parsed_chat = _parley.parse_chat(lines, header_end)
            end_index = #lines
            cursor_line = vim.api.nvim_win_get_cursor(0)[1]
            exchange_idx, component = _parley.find_exchange_at_line(parsed_chat, cursor_line)
        end
    end

    -- If range was explicitly provided, respect it
    if params.range == 2 then
        start_index = math.max(start_index, params.line1)
        end_index = math.min(end_index, params.line2)
    elseif not branch_handled then
        -- Check if cursor is in the middle of the document on a question.
        -- (Skip when the drill-in branch has already targeted a specific
        -- new-turn exchange and capped end_index there.)
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

    return start_scoped_response({buf = buf, win = win, cursor = vim.api.nvim_win_get_cursor(win),
        params = vim.deepcopy(params), parsed = parsed_chat, lines = lines, file_name = file_name,
        exchange_idx = exchange_idx, start_index = start_index, end_index = end_index,
        follow = override_free_cursor, callback = callback})
end

--------------------------------------------------------------------------------
-- chat_respond_all
--------------------------------------------------------------------------------

-- Explicit batch admission may materialize the chat; rendering never uses this
-- path. Every later leg resolves a captured identity before parsing its input.
function M.batch_snapshot(batch) return require('parley.batch_response').snapshot(batch) end
M.respond_all = function()
    local D, Batch = require('parley.document'), require('parley.batch_response')
    local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(win)
    local file_name = vim.api.nvim_buf_get_name(buf)
    local reason = _parley.not_chat(buf, file_name)
    if reason then _parley.logger.warning('Batch not started: ' .. tostring(reason)); return end
    if batches[buf] and Batch.snapshot(batches[buf]).phase ~= 'completed' then
        _parley.logger.warning('A batch is already active or paused in this chat'); return
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = find_chat_header_end(lines)
    if not header_end then return nil, 'chat header unavailable' end
    local parsed = _parley.parse_chat(lines, header_end)
    local doc = D.get(buf) or D.attach(buf, {patterns = require('parley.highlight_structure').patterns(_parley.config)})
    if D.drain(doc, 10000).status ~= 'idle' then return nil, 'document structure unavailable' end
    local selection = {}
    for _, exchange in ipairs(parsed.exchanges) do
        if exchange.question and exchange.question.line_start <= cursor[1] then
            local found = D.exchange(doc, exchange.question.line_start - 1)
            if found.status ~= 'ready' then return nil, 'question identity unavailable' end
            selection[#selection + 1] = found.identity
        end
    end
    if #selection == 0 then return nil, 'no questions selected' end
    local root_policy = require('parley.neighborhood').policy_for_buf(buf)
    local batch
    batch, reason = Batch.start(doc, {selection = selection,
        start = function(entity, done)
            if not vim.api.nvim_buf_is_valid(buf) or D.get(buf) ~= doc then return nil, 'document changed' end
            local marker = D.lookup(doc, entity)
            if not marker then return nil, 'question missing' end
            local source = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            local header = find_chat_header_end(source)
            if not header then return nil, 'chat header unavailable' end
            local current = _parley.parse_chat(source, header)
            local index
            for i, exchange in ipairs(current.exchanges) do
                if exchange.question and exchange.question.line_start == marker.start_row + 1 then index = i; break end
            end
            if not index then return nil, 'question unavailable' end
            local session, why = start_scoped_response({buf = buf, win = win, cursor = cursor, follow = false,
                file_name = file_name, lines = source, parsed = current, exchange_idx = index,
                start_index = header + 1, end_index = #source, params = {range = 2, root_policy = root_policy},
                batch = batch, terminal = done})
            if not session then return nil, why end
            return {cancel = function()require('parley.response_session').cancel(session, 'batch cancelled')end}
        end,
        changed = function(state)
            if state.phase == 'paused' then
                _parley.logger.warning('Batch paused after ' .. state.completed .. '/' .. #state.selection
                    .. ' questions: ' .. tostring(state.reason))
            end
        end,
    })
    if batch then batches[buf] = batch else _parley.logger.warning('Batch not started: ' .. tostring(reason)) end
    return batch, reason
end
function M.resume_batch(params)
    local batch = batches[vim.api.nvim_get_current_buf()]
    if not batch then return nil, 'no batch in this chat' end
    return require('parley.batch_response').resume(batch, {accept_changes = params and params.bang == true})
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
