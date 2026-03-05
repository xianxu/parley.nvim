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
--   }
-- }

---@param lines table        # array of strings (all lines of the chat file)
---@param header_end number  # index of the "---" separator line
---@param config table       # parley config table (or a minimal stub for tests)
---@return table             # parsed_chat structure described above
M.parse_chat = function(lines, header_end, config)
	local result = {
		headers = {},
		exchanges = {}
	}

	-- Parse headers
	for i = 1, header_end do
		local line = lines[i]
		local key, value = line:match("^[-#] (%w+): (.*)")
		if key ~= nil then
			if key == "tags" then
				-- Parse tags into individual items
				local tags = {}
				for tag in value:gmatch("%S+") do
					local trimmed_tag = tag:match("^%s*(.-)%s*$")
					if trimmed_tag and trimmed_tag ~= "" then
						table.insert(tags, trimmed_tag)
					end
				end
				result.headers[key] = tags
			else
				result.headers[key] = value
			end
		end

		-- Parse configuration override parameters
		local config_key, config_value = line:match("^%- ([%w_]+): (.*)")
		if config_key ~= nil and config_key ~= "file" and config_key ~= "model" and config_key ~= "provider" and config_key ~= "role" then
			-- Try to convert to number if possible
			if tonumber(config_value) ~= nil then
				config_value = tonumber(config_value)
			end
			result.headers["config_" .. config_key] = config_value
		end
	end

	-- Get prefixes
	local memory_enabled = config.chat_memory and config.chat_memory.enable
	local summary_prefix = memory_enabled and config.chat_memory.summary_prefix or "📝:"
	local reasoning_prefix = memory_enabled and config.chat_memory.reasoning_prefix or "🧠:"
	local user_prefix = config.chat_user_prefix
	local local_prefix = config.chat_local_prefix
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

	-- Helper to extract @@ file references from a line of text.
	-- Supports @@ anywhere in the line for URLs, absolute paths, and relative paths.
	local function extract_file_refs(text)
		local refs = {}
		-- First check: @@ at start of line (original behavior, supports "@@path: topic" syntax)
		local path = text:match("^@@%s*(https?://.+)") or text:match("^@@%s*([^:]+)")
		if path then
			table.insert(refs, (path:gsub("^%s*(.-)%s*$", "%1")))
			return refs
		end
		-- Second check: inline @@ followed by URL or file path
		-- Match @@<path> where path starts with http(s)://, /, ./, or ~/ and ends at whitespace
		local seen = {}
		for ref in text:gmatch("%s@@(https?://[^%s]+)") do
			ref = ref:gsub("^%s*(.-)%s*$", "%1")
			if not seen[ref] then seen[ref] = true; table.insert(refs, ref) end
		end
		for ref in text:gmatch("%s@@([~/%.][^%s]+)") do
			ref = ref:gsub("^%s*(.-)%s*$", "%1")
			if not seen[ref] then seen[ref] = true; table.insert(refs, ref) end
		end
		-- Also match at start of text (no leading whitespace) for inline refs
		local start_ref = text:match("^@@(https?://[^%s]+)") or text:match("^@@([~/%.][^%s]+)")
		if start_ref and not seen[start_ref] then
			table.insert(refs, (start_ref:gsub("^%s*(.-)%s*$", "%1")))
		end
		return refs
	end

	-- Loop through content lines
	for i = header_end + 1, #lines do
		local line = lines[i]

		-- Check for local section (ignore content in local sections)
		if (not line_before_local) and line:sub(1, #local_prefix) == local_prefix then
			-- detect the first local_prefix within one question or answer, this will trigger to ignore all subsequent local line_start
			-- until next user_prefix, or agent_prefix
			line_before_local = i

		-- Check for user message start
		elseif line:sub(1, #user_prefix) == user_prefix then
			-- If we were building a previous exchange, finalize it
			local current_component_start = line_before_local or i
			finalize_component(current_component_start - 1)

			-- Extract question content
			local question_content = line:sub(#user_prefix + 1)

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
			table.insert(content_parts, line)

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
