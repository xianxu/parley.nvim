--------------------------------------------------------------------------------
-- chat_parser.lua: parses a chat file's lines into a structured representation.
--
-- Extracted from init.lua so it can be required and tested independently,
-- without loading the full parley plugin or calling setup().
--
-- Public API:
--   M.parse_chat(lines, header_end, config) -> parsed_chat
--
-- `config` must contain:
--   config.chat_user_prefix        (string)
--   config.chat_local_prefix       (string)
--   config.chat_assistant_prefix   (string | {string, ...})
--   config.chat_memory             (table | nil)
--     .enable                      (boolean)
--     .summary_prefix              (string)
--     .reasoning_prefix            (string)
--------------------------------------------------------------------------------

local logger = require("parley.logger")

local M = {}

local function trim(str)
	return (str:gsub("^%s*(.-)%s*$", "%1"))
end

---Find the header/trancript separator index.
---Supports:
---1) Legacy format: metadata lines followed by a single `---`.
---2) Front matter format: opening `---`, metadata, closing `---`.
---@param lines table
---@return number|nil
M.find_header_end = function(lines)
	if not lines or #lines == 0 then
		return nil
	end

	if trim(lines[1]) == "---" then
		for i = 2, #lines do
			if trim(lines[i]) == "---" then
				return i
			end
		end
		return nil
	end

	for i, line in ipairs(lines) do
		if trim(line) == "---" then
			return i
		end
	end

	return nil
end

local function parse_header_key_value(line)
	local content = trim(line)
	if content == "" or content == "---" then
		return nil, nil
	end

	local key, value = content:match("^[-#]%s*([%w_%.%+]+):%s*(.*)$")
	if key then
		return key, value
	end

	return content:match("^([%w_%.%+]+):%s*(.*)$")
end

local function parse_header_config_value(value)
	if tonumber(value) ~= nil then
		return tonumber(value)
	elseif value == "true" then
		return true
	elseif value == "false" then
		return false
	end

	return value
end

-- Structure to represent a parsed chat:
-- {
--   headers = { key-value pairs },
--   exchanges = {
--     {
--       question = { line_start = N, line_end = N, content = "text",
--                    file_references = { {line, path, original_line_index}, ... } },
--       answer   = { line_start = N, line_end = N, content = "text" },  -- or nil
--       summary  = { line = N, content = "text" },                      -- optional
--       reasoning = { line = N, content = "text" },                     -- optional
--     },
--     ...
--   },
--   parent_link = { path = "...", topic = "...", line = N } | nil,
--   branches = {
--     { path = "...", topic = "...", line = N, after_exchange = N, inline = bool|nil },
--     ...
--   }
-- }

--- Inline branch link pattern: [🌿:display text](file.md)
--- Pure function: extracts all inline branch links from a line.
--- @param line string
--- @param branch_prefix string e.g. "🌿:"
--- @return table array of { path, topic, col_start, col_end }
M.extract_inline_branch_links = function(line, branch_prefix)
	local results = {}
	local prefix_pattern = "%[" .. vim.pesc(branch_prefix) .. "(.-)%]%((.-)%)"
	local search_start = 1
	while search_start <= #line do
		local s, e, topic, path = line:find(prefix_pattern, search_start)
		if not s then
			break
		end
		topic = trim(topic)
		path = trim(path)
		if path ~= "" then
			table.insert(results, { path = path, topic = topic, col_start = s, col_end = e })
		end
		search_start = e + 1
	end
	return results
end

--- Unpack inline branch links from a line, replacing [🌿:text](file) with just text.
--- Pure function.
--- @param line string
--- @param branch_prefix string
--- @return string the line with inline links replaced by their display text
M.unpack_inline_branch_links = function(line, branch_prefix)
	local prefix_pattern = "%[" .. vim.pesc(branch_prefix) .. "(.-)%]%(.-%)"
	return line:gsub(prefix_pattern, "%1")
end

---@param lines table        # array of strings (all lines of the chat file)
---@param header_end number  # index of the "---" separator line
---@param config table       # parley config table (or a minimal stub for tests)
---@return table             # parsed_chat structure described above
--- Find which exchange (1-indexed) contains the given buffer line.
--- Returns nil if the line is outside any exchange (e.g. in the header).
--- #90 Task 1.2.
function M.find_exchange_at_line(parsed, line_no)
	for i, ex in ipairs(parsed.exchanges or {}) do
		local q_start = ex.question and ex.question.line_start or math.huge
		local a_end = (ex.answer and ex.answer.line_end)
			or (ex.question and ex.question.line_end)
			or 0
		if line_no >= q_start and line_no <= a_end then
			return i
		end
	end
	return nil
end

--- Find the (exchange_idx, section_idx) of the section containing the
--- given buffer line. Returns (exchange_idx, nil) if the line is inside
--- an exchange but not inside any section, or (nil, nil) if outside any
--- exchange. #90 Task 1.2.
function M.find_section_at_line(parsed, line_no)
	local idx = M.find_exchange_at_line(parsed, line_no)
	if not idx then
		return nil, nil
	end
	local secs = parsed.exchanges[idx].answer
		and parsed.exchanges[idx].answer.sections
		or {}
	for s_idx, s in ipairs(secs) do
		if line_no >= s.line_start and line_no <= s.line_end then
			return idx, s_idx
		end
	end
	return idx, nil
end

--- Return the last section of the given exchange's answer, or nil.
--- #90 Task 1.2.
function M.last_section_in_answer(parsed, exchange_idx)
	local ex = parsed.exchanges and parsed.exchanges[exchange_idx]
	if not ex or not ex.answer or not ex.answer.sections then
		return nil
	end
	return ex.answer.sections[#ex.answer.sections]
end

M.parse_chat = function(lines, header_end, config)
	local result = {
		header_end = header_end,
		headers = {},
		exchanges = {},
		parent_link = nil,
		branches = {}
	}

	-- Parse headers
	for i = 1, header_end do
		local line = lines[i]
		local key, value = parse_header_key_value(line)
		if key ~= nil then
			local is_append = key:sub(-1) == "+"
			local base_key = is_append and key:sub(1, -2) or key
			-- Backward-compat alias: role -> system_prompt.
			if base_key == "role" then
				base_key = "system_prompt"
			end
			if base_key == "" then
				goto continue
			end

			if is_append then
				result.headers._append = result.headers._append or {}
				result.headers._append[base_key] = result.headers._append[base_key] or {}

				local append_value = value
				if base_key == "tags" then
					local tags = {}
					for tag in value:gmatch("[^,%s]+") do
						local trimmed_tag = trim(tag)
						if trimmed_tag and trimmed_tag ~= "" then
							table.insert(tags, trimmed_tag)
						end
					end
					append_value = tags
				end
				table.insert(result.headers._append[base_key], append_value)
			elseif base_key == "tags" then
				-- Parse tags into individual items
				local tags = {}
				for tag in value:gmatch("[^,%s]+") do
					local trimmed_tag = trim(tag)
					if trimmed_tag and trimmed_tag ~= "" then
						table.insert(tags, trimmed_tag)
					end
				end
				result.headers[base_key] = tags
			else
				result.headers[base_key] = value
			end

			-- Parse configuration override parameters
			if base_key ~= "file" and base_key ~= "model" and base_key ~= "provider" and base_key ~= "system_prompt" and base_key ~= "topic" and base_key ~= "tags" then
				local config_value = parse_header_config_value(value)
				if is_append then
					result.headers._append = result.headers._append or {}
					local append_config_key = "config_" .. base_key
					result.headers._append[append_config_key] = result.headers._append[append_config_key] or {}
					table.insert(result.headers._append[append_config_key], config_value)
				else
					result.headers["config_" .. base_key] = config_value
				end
			end
		end
		::continue::
	end

	-- Get prefixes
	local memory_enabled = config.chat_memory and config.chat_memory.enable
	local summary_prefix = memory_enabled and config.chat_memory.summary_prefix or "📝:"
	local reasoning_prefix = memory_enabled and config.chat_memory.reasoning_prefix or "🧠:"
	local user_prefix = config.chat_user_prefix
	local local_prefix = config.chat_local_prefix
	local branch_prefix = config.chat_branch_prefix or "🌿:"
	-- M2 Task 2.5 of #81: tool_use / tool_result prefixes for the
	-- content_blocks list on an assistant answer.
	local tool_use_prefix = config.chat_tool_use_prefix or "🔧:"
	local tool_result_prefix = config.chat_tool_result_prefix or "📎:"
	logger.debug("memory config: " .. vim.inspect({memory_enabled, summary_prefix, reasoning_prefix}))

	-- Determine agent prefix
	local agent_prefix = config.chat_assistant_prefix[1]
	if type(config.chat_assistant_prefix) == "string" then
		agent_prefix = config.chat_assistant_prefix
	elseif type(config.chat_assistant_prefix) == "table" then
		agent_prefix = config.chat_assistant_prefix[1]
	end

	-- Track the current exchange and component being built
	local current_exchange = nil
	local current_component = nil
	local line_before_local = nil
	local first_question_seen = false
	-- Use table accumulation instead of string concat for content (avoids O(n²))
	local content_parts = {}

	-- Helper to finalize the current component's content from accumulated parts
	local function finalize_component(end_line)
		if current_exchange and current_component then
			-- Trim trailing blank lines from all components so the
			-- model's margins are the single source of truth for gaps
			-- between blocks/exchanges. Without this, trailing blanks
			-- in the parser's line_end would double-count with the
			-- model's MARGIN constant.
			local trimmed_end = end_line
			while trimmed_end > current_exchange[current_component].line_start
				and (not lines[trimmed_end] or not lines[trimmed_end]:match("%S")) do
				trimmed_end = trimmed_end - 1
			end
			current_exchange[current_component].line_end = trimmed_end
			current_exchange[current_component].content = table.concat(content_parts, "\n"):gsub("^%s*(.-)%s*$", "%1")
			content_parts = {}
		end
	end

	--------------------------------------------------------------------------
	-- M2 Task 2.5 of #81: content_blocks state machine
	--
	-- Parallel to the existing content_parts flow (which builds the flat
	-- answer.content for backward compat), this state machine builds a
	-- structured `answer.content_blocks` list preserving the buffer order
	-- of text / tool_use / tool_result sub-components inside a `🤖:`
	-- answer region. Tool block body decoding is delegated to
	-- lua/parley/tools/serialize.lua so any schema change there
	-- automatically propagates here without re-writing regex.
	--
	-- The machine is only "alive" inside an answer region. It's (re-)
	-- initialized by the `🤖:` branch and finalized + attached to the
	-- answer object by the next `💬:` branch (or at end of file).
	--------------------------------------------------------------------------
	local cb_state = nil -- nil when not inside an answer
	local serialize_ok, serialize = pcall(require, "parley.tools.serialize")

	local function cb_start_block(kind)
		if not cb_state then return end
		cb_state.current_kind = kind
		cb_state.current_lines = {}
		-- line_start is set lazily on the first cb_append_line so that
		-- it reflects the line that actually contains content (not the
		-- pre-content header line where cb_start_block was called).
		cb_state.current_line_start = nil
		-- Fence tracking resets for each new block. Only used inside
		-- tool_use / tool_result blocks to detect the end of the
		-- fenced body so we can auto-transition back to a text block
		-- when subsequent plain text follows.
		cb_state.tool_fence_len = nil
		cb_state.tool_body_complete = false
	end

	-- Finalize the current content block. end_line_no is the 1-indexed
	-- buffer line where this block's last content lives (#90 Task 1.1).
	local function cb_finalize_block(end_line_no)
		if not cb_state or not cb_state.current_kind then return end
		local body = table.concat(cb_state.current_lines, "\n")
		local kind = cb_state.current_kind
		local block
		if kind == "text" then
			local trimmed = body:gsub("^%s*(.-)%s*$", "%1")
			if trimmed ~= "" then
				block = { type = "text", text = trimmed }
			end
		elseif kind == "tool_use" then
			local parsed = serialize_ok and serialize.parse_call(body) or nil
			if parsed then
				block = {
					type = "tool_use",
					id = parsed.id,
					name = parsed.name,
					input = parsed.input,
				}
			end
		elseif kind == "tool_result" then
			local parsed = serialize_ok and serialize.parse_result(body) or nil
			if parsed then
				block = {
					type = "tool_result",
					id = parsed.id,
					name = parsed.name,
					content = parsed.content,
					is_error = parsed.is_error,
				}
			end
		end
		if block then
			-- #90: line spans + `kind` alias for `type` (forward-compat).
			-- Trim leading and trailing blank lines — the model's margins
			-- are the single source of truth for gaps between blocks.
			local trimmed_start = cb_state.current_line_start
			while trimmed_start < end_line_no
				and (not lines[trimmed_start] or not lines[trimmed_start]:match("%S")) do
				trimmed_start = trimmed_start + 1
			end
			local trimmed_end = end_line_no
			while trimmed_end > trimmed_start
				and (not lines[trimmed_end] or not lines[trimmed_end]:match("%S")) do
				trimmed_end = trimmed_end - 1
			end
			block.kind = block.type
			block.line_start = trimmed_start
			block.line_end = trimmed_end
			table.insert(cb_state.blocks, block)
		end
		cb_state.current_kind = nil
		cb_state.current_lines = {}
		cb_state.current_line_start = nil
		cb_state.tool_fence_len = nil
		cb_state.tool_body_complete = false
	end

	-- Append a line to the current content block, auto-transitioning
	-- out of a tool block whose fenced body has already been closed.
	-- Tracks fence open/close state inside tool blocks so the parser
	-- knows when subsequent text should start a new text block vs
	-- belong to the tool block's body.
	-- line_no is the 1-indexed buffer line being appended (#90 Task 1.1).
	local function cb_append_line(line, line_no)
		if not cb_state or not cb_state.current_kind then return end

		-- Auto-transition: if we're in a tool block whose closing
		-- fence was already seen, this line belongs to a NEW text
		-- block, not the tool block. Finalize the tool block first.
		if cb_state.tool_body_complete then
			cb_finalize_block(line_no - 1)
			cb_start_block("text")
		end

		-- Lazy line_start: the first line we see is where the block begins.
		if cb_state.current_line_start == nil then
			cb_state.current_line_start = line_no
		end
		table.insert(cb_state.current_lines, line)

		-- Track fence state inside tool blocks to detect body end.
		-- Opening fence: any run of 3+ backticks optionally followed
		-- by an info string (e.g. "```json"). Closing fence: exactly
		-- the same number of bare backticks with no info string.
		if cb_state.current_kind == "tool_use" or cb_state.current_kind == "tool_result" then
			if not cb_state.tool_fence_len then
				local fence = line:match("^(`+)[%w_%-]*%s*$")
				if fence and #fence >= 3 then
					cb_state.tool_fence_len = #fence
				end
			else
				local expected_close = string.rep("`", cb_state.tool_fence_len)
				if line == expected_close then
					cb_state.tool_body_complete = true
				end
			end
		end
	end

	-- Attach accumulated blocks to the current exchange's answer
	-- component (called on answer → next-question transition and at
	-- end of file). end_line_no is the last buffer line of the answer
	-- region (#90 Task 1.1).
	local function cb_attach_to_current_answer(end_line_no)
		if cb_state and current_exchange and current_exchange.answer then
			cb_finalize_block(end_line_no)
			current_exchange.answer.sections = cb_state.blocks
			-- Backward-compat alias.
			current_exchange.answer.content_blocks = cb_state.blocks
		end
		cb_state = nil
	end

	-- Helper to extract @@ref@@ file references from a line of text.
	-- Canonical form: @@<ref>@@ where ref starts with https://, /, ~/, or ./
	local function extract_file_refs(text)
		local refs = {}
		local seen = {}
		for ref in text:gmatch("@@([^@]+)@@") do
			ref = ref:gsub("^%s*(.-)%s*$", "%1")
			if ref:match("^https?://") or ref:match("^/") or ref:match("^~/") or ref:match("^%./") then
				if not seen[ref] then
					seen[ref] = true
					table.insert(refs, ref)
				end
			end
		end
		return refs
	end

	-- Loop through content lines
	for i = header_end + 1, #lines do
		local line = lines[i]

		-- Check for branch reference (🌿:) — always detected, even between consecutive links.
		-- Before the first question: first 🌿: is parent_link, subsequent ones are children.
		-- After the first question: all 🌿: are child branches.
		if line:sub(1, #branch_prefix) == branch_prefix then
			local rest = line:sub(#branch_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
			if not path then
				path = rest
				topic = ""
			end
			path = path:gsub("^%s*(.-)%s*$", "%1")
			topic = (topic or ""):gsub("^%s*(.-)%s*$", "%1")
			local branch_info = { path = path, topic = topic, line = i, after_exchange = #result.exchanges }
			if not first_question_seen and not result.parent_link then
				result.parent_link = branch_info
			else
				table.insert(result.branches, branch_info)
			end
			line_before_local = i

		-- Check for local section (excluded from LLM context)
		elseif (not line_before_local) and line:sub(1, #local_prefix) == local_prefix then
			line_before_local = i

		-- Check for user message start
		elseif line:sub(1, #user_prefix) == user_prefix then
			first_question_seen = true
			-- Content_blocks for the closing answer (if any) get attached
			-- before we finalize the old component and start a new exchange.
			local current_component_start = line_before_local or i
			cb_attach_to_current_answer(current_component_start - 1)
			-- If we were building a previous exchange, finalize it
			finalize_component(current_component_start - 1)

			-- Extract question content
			local question_content = line:sub(#user_prefix + 1)

			-- Detect inline branch links on the question prefix line
			local q_inline = M.extract_inline_branch_links(question_content, branch_prefix)
			if #q_inline > 0 then
				question_content = M.unpack_inline_branch_links(question_content, branch_prefix)
			end

			-- Start a new exchange
			current_exchange = {
				question = {
					line_start = i,
					line_end = nil,
					content = "",
					file_references = {} -- Will store file references we find (length > 0 means has references)
				},
				answer = nil
			}
			content_parts = { question_content }
			table.insert(result.exchanges, current_exchange)
			current_component = "question"
			line_before_local = nil

			-- Add inline branch links from the question prefix line
			for _, ib in ipairs(q_inline) do
				table.insert(result.branches, {
					path = ib.path,
					topic = ib.topic,
					line = i,
					after_exchange = #result.exchanges,
					inline = true,
				})
			end

			-- Check for inline @@ file references on the user prefix line itself
			local inline_refs = extract_file_refs(question_content)
			for _, ref_path in ipairs(inline_refs) do
				table.insert(current_exchange.question.file_references, {
					line = line,
					path = ref_path,
					original_line_index = i,
				})
				logger.debug("Found inline file reference on user line: " .. ref_path)
			end

		-- Check for assistant message start
		elseif line:sub(1, #agent_prefix) == agent_prefix then
			-- If we were building a previous component, finalize it.
			-- (If the previous component was an answer, its content_blocks
			-- were already attached by the preceding `💬:` branch or by
			-- this branch if there was no question in between — see
			-- the cb_attach below after we start the new block.)
			local current_component_start = line_before_local or i
			finalize_component(current_component_start - 1)

			-- Defensive attach: if we had a previous answer with unflushed
			-- content_blocks (rare — two 🤖: without a 💬: between them),
			-- attach to it now before overwriting current_exchange.answer.
			cb_attach_to_current_answer(current_component_start - 1)

			-- Make sure we have an exchange to add this answer to
			if not current_exchange then
				-- Handle edge case: assistant message without preceding user message
				current_exchange = {
					question = {
						line_start = header_end + 1,
						line_end = current_component_start - 1,
						content = ""
					},
					answer = nil
				}
				table.insert(result.exchanges, current_exchange)
			end

			-- Start the answer component
			current_exchange.answer = {
				line_start = i,
				line_end = nil,
				content = ""
			}
			content_parts = {}
			current_component = "answer"
			line_before_local = nil

			-- Initialize content_blocks state for this answer. Start with
			-- an empty "text" block; content continuation lines will fill
			-- it until a 🔧:/📎: boundary splits it.
			cb_state = { blocks = {}, current_kind = nil, current_lines = {} }
			cb_start_block("text")

		-- Check for tool_use (🔧:) header — only meaningful inside an answer.
		-- This closes the current content_block (text / tool_use /
		-- tool_result) and starts a new tool_use block whose first
		-- accumulated line IS the 🔧: header, so serialize.parse_call
		-- can extract id/name from it later.
		elseif current_component == "answer" and line:sub(1, #tool_use_prefix) == tool_use_prefix then
			cb_finalize_block(i - 1)
			cb_start_block("tool_use")
			cb_append_line(line, i)
			-- Also feed the raw line into content_parts so answer.content
			-- (backward-compat flat text) still reflects the full answer
			-- region exactly as it appears in the buffer.
			table.insert(content_parts, line)

		-- Check for tool_result (📎:) header — same pattern as tool_use.
		elseif current_component == "answer" and line:sub(1, #tool_result_prefix) == tool_result_prefix then
			cb_finalize_block(i - 1)
			cb_start_block("tool_result")
			cb_append_line(line, i)
			table.insert(content_parts, line)

		-- Check for summary line
		elseif current_component == "answer" and line:sub(1, #summary_prefix) == summary_prefix then
			current_exchange.summary = {
				line = i,
				content = line:sub(#summary_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}
			-- Also feed into content_blocks so the model tracks it.
			table.insert(content_parts, line)
			cb_append_line(line, i)

		-- Check for reasoning line
		elseif current_component == "answer" and line:sub(1, #reasoning_prefix) == reasoning_prefix then
			current_exchange.reasoning = {
				line = i,
				content = line:sub(#reasoning_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}
			-- Also feed into content_blocks so the model tracks it as
			-- part of the text section (🧠: is just text content).
			table.insert(content_parts, line)
			cb_append_line(line, i)

		-- Handle content continuation, ignore lines if we are in local_prefix section, aka line_before_local is set
		--   note, in this mode, both plain text and file reference pattern @@ are ignored.
		elseif (not line_before_local) and current_exchange and current_component then
			-- Detect inline branch links [🌿:text](file) and add to branches
			local inline_branches = M.extract_inline_branch_links(line, branch_prefix)
			for _, ib in ipairs(inline_branches) do
				table.insert(result.branches, {
					path = ib.path,
					topic = ib.topic,
					line = i,
					after_exchange = #result.exchanges,
					inline = true,
				})
			end
			-- Unpack inline links to plain text for LLM context
			local content_line = #inline_branches > 0
				and M.unpack_inline_branch_links(line, branch_prefix)
				or line
			table.insert(content_parts, content_line)

			-- Feed the line into the current content_block (M2 Task 2.5).
			-- Only meaningful when we're inside an answer; cb_append_line
			-- is a no-op when cb_state is nil or has no current_kind.
			cb_append_line(content_line, i)

			-- Check for file references in question content
			if current_component == "question" then
				local refs = extract_file_refs(line)
				for _, ref_path in ipairs(refs) do
					table.insert(current_exchange[current_component].file_references, {
						line = line,
						path = ref_path,
						original_line_index = i,
					})
					logger.debug("Found file reference: " .. ref_path)
				end
			end
		end
	end

	-- Finalize the last component. The trimming for questions is
	-- handled inside finalize_component itself.
	finalize_component(#lines)

	-- Finalize and attach content_blocks for the last open answer, if any
	-- (M2 Task 2.5 of #81; #90 Task 1.1 added the end_line_no arg).
	cb_attach_to_current_answer(#lines)

	return result
end

return M
