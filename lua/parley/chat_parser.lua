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
M.parse_chat = function(lines, header_end, config)
	local result = {
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
			current_exchange[current_component].line_end = end_line
			current_exchange[current_component].content = table.concat(content_parts, "\n"):gsub("^%s*(.-)%s*$", "%1")
			content_parts = {}
		end
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
			-- If we were building a previous exchange, finalize it
			local current_component_start = line_before_local or i
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
			-- If we were building a previous component, finalize it
			local current_component_start = line_before_local or i
			finalize_component(current_component_start - 1)

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

		-- Check for summary line
		elseif current_component == "answer" and line:sub(1, #summary_prefix) == summary_prefix then
			current_exchange.summary = {
				line = i,
				content = line:sub(#summary_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}

		-- Check for reasoning line
		elseif current_component == "answer" and line:sub(1, #reasoning_prefix) == reasoning_prefix then
			current_exchange.reasoning = {
				line = i,
				content = line:sub(#reasoning_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			}

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

	-- Finalize the last component if needed
	finalize_component(#lines)

	return result
end

return M
