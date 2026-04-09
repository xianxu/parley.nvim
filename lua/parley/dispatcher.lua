--------------------------------------------------------------------------------
-- Dispatcher handles the communication between the plugin and LLM providers.
--------------------------------------------------------------------------------

local logger = require("parley.logger")
local tasker = require("parley.tasker")
local vault = require("parley.vault")
local helpers = require("parley.helper")

local default_config = require("parley.config")
local providers = require("parley.providers")

local D = {
	config = {},
	providers = {},
	query_dir = vim.fn.stdpath("cache") .. "/parley/query",
}

---@param opts table #	user config
D.setup = function(opts)
	logger.debug("dispatcher setup started\n" .. vim.inspect(opts))

	D.config.curl_params = opts.curl_params or default_config.curl_params

	D.providers = vim.deepcopy(default_config.providers)
	opts.providers = opts.providers or {}
	for k, v in pairs(opts.providers) do
		D.providers[k] = D.providers[k] or {}
		D.providers[k].disable = false
		for pk, pv in pairs(v) do
			D.providers[k][pk] = pv
		end
		if next(v) == nil then
			D.providers[k].disable = true
		end
	end

	-- remove invalid providers
	for name, provider in pairs(D.providers) do
		if type(provider) ~= "table" or provider.disable then
			D.providers[name] = nil
		elseif not provider.endpoint then
			logger.warning("Provider " .. name .. " is missing endpoint")
			D.providers[name] = nil
		end
	end

	for name, provider in pairs(D.providers) do
		vault.add_secret(name, provider.secret)
		provider.secret = nil
	end

	D.query_dir = helpers.prepare_dir(D.query_dir, "query store")

	local files = vim.fn.glob(D.query_dir .. "/*.json", false, true)
	if #files > 200 then
		logger.debug("too many query files, truncating cache")
		table.sort(files, function(a, b)
			return a > b
		end)
		for i = 100, #files do
			helpers.delete_file(files[i])
		end
	end

	logger.debug("dispatcher setup finished\n" .. vim.inspect(D))
end

---@param messages table
---@param model string | table
---@param provider string | nil
--- Build the provider-specific request payload for a chat turn.
---
--- @param messages table[]     # messages array in parley's internal shape
--- @param model string|table   # model name or params table
--- @param provider string      # provider name ("anthropic", "openai", ...)
--- @param agent_tools string[]|nil # optional list of client-side tool names
---   declared by the agent (M1 of issue #81). When non-empty, the dispatcher
---   resolves the names against the registry, encodes them via the provider's
---   tool encoder, and APPENDS the result to payload.tools — never overwriting
---   any server-side tools the adapter may have already emitted (e.g. Anthropic
---   web_search / web_fetch). Nil or empty = no client-side tools; byte-
---   identical to pre-#81 behavior for vanilla agents.
--- @return table payload
D.prepare_payload = function(messages, model, provider, agent_tools)
	if type(model) == "string" then
		return {
			model = model,
			stream = true,
			messages = messages,
		}
	end

	local adapter = providers.get(provider)
	local payload = adapter.format_payload(messages, model, provider)

	-- M1 Task 1.5: append client-side tools to whatever the adapter emitted.
	-- Non-Anthropic providers raise here when agent_tools is non-empty.
	if agent_tools and #agent_tools > 0 then
		local tools_registry = require("parley.tools")
		local defs = tools_registry.select(agent_tools)
		local client_tools
		if provider == "anthropic" then
			client_tools = providers.anthropic_encode_tools(defs)
		elseif provider == "cliproxyapi" then
			client_tools = providers.cliproxyapi_encode_tools(defs, model)
		elseif provider == "openai" then
			client_tools = providers.openai_encode_tools(defs) -- raises
		elseif provider == "googleai" then
			client_tools = providers.googleai_encode_tools(defs) -- raises
		elseif provider == "ollama" then
			client_tools = providers.ollama_encode_tools(defs) -- raises
		else
			error("tools not supported for this provider yet — see #81 follow-up (provider: "
				.. tostring(provider) .. ")")
		end

		-- APPEND, do not CLOBBER: preserves server-side tools (web_search,
		-- web_fetch) that the adapter may have already written into
		-- payload.tools. Task 1.0 baseline capture discovery.
		payload.tools = payload.tools or {}
		for _, t in ipairs(client_tools) do
			table.insert(payload.tools, t)
		end
	end

	logger.debug("payload: " .. vim.inspect(payload))
	return payload
end

-- Extract text content from a single SSE line.
-- This is the pure extraction logic, separated from query/process_lines for testability.
-- Returns extracted content string, or "" if no content found or if line is malformed.
---@param line string # a single SSE line (may have "data: " prefix which will be stripped)
---@param provider string # provider name ("openai", "anthropic", "googleai", etc.)
---@return string # extracted text content, or ""
D._extract_sse_content = function(line, provider)
	local adapter = providers.get(provider)
	return adapter.parse_sse_content(line)
end

-- Extract progress/status metadata from a single SSE line.
-- Returns nil if no progress event is available for the provider/line.
---@param line string
---@param provider string
---@return table | nil
D._extract_sse_progress_event = function(line, provider)
	local adapter = providers.get(provider)
	if type(adapter.parse_sse_progress_event) ~= "function" then
		return nil
	end
	return adapter.parse_sse_progress_event(line)
end

-- LLM query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
---@param on_progress function | nil # optional progress/status handler
local query = function(buf, provider, payload, handler, on_exit, callback, on_progress)
	-- make sure handler is a function
	if type(handler) ~= "function" then
		logger.error(
			string.format("query() expects a handler function, but got %s:\n%s", type(handler), vim.inspect(handler))
		)
		return
	end

    logger.debug("query to send is: " .. vim.json.encode(payload))

	local qid = helpers.uuid()
	tasker.set_query(qid, {
		timestamp = os.time(),
		buf = buf,
		provider = provider,
		payload = payload,
		handler = handler,
		on_exit = on_exit,
		raw_response = "",
		response = "",
		first_line = -1,
		last_line = -1,
		ns_id = nil,
		ex_id = nil,
	})

	local out_reader = function()
		local buffer = ""

		---@param lines_chunk string
		local function process_lines(lines_chunk)
			local qt = tasker.get_query(qid)
			if not qt then
				return
			end

			local lines = vim.split(lines_chunk, "\n")

			-- Check if we're in raw response mode
			local show_raw_response = require("parley").config and
			                          require("parley").config.raw_mode and
			                          require("parley").config.raw_mode.show_raw_response

			-- In raw response mode, we'll accumulate the entire raw response and return it as JSON
			if show_raw_response then
				for _, line in ipairs(lines) do
					if line ~= "" and line ~= nil then
						qt.raw_response = qt.raw_response .. line .. "\n"
					end
				end

				-- First response should include the code block start marker
				if qt.response == "" then
					-- Initial response with opening code fence
					qt.response = '```json {"type": "response"}\n' .. qt.raw_response
					handler(qid, '```json {"type": "response"}\n' .. lines_chunk)
				else
					-- Subsequent responses just add the new content
					qt.response = qt.response .. lines_chunk
					handler(qid, lines_chunk)
				end

				return
			end

			-- Standard response handling (non-raw mode)
			for _, line in ipairs(lines) do
				if line ~= "" and line ~= nil then
					qt.raw_response = qt.raw_response .. line .. "\n"
				end

				-- Skip empty lines
				if line == "" or line == nil then
					goto continue
				end

				local progress_event = D._extract_sse_progress_event(line, qt.provider)
				if progress_event and type(on_progress) == "function" then
					on_progress(qid, progress_event)
				end

				-- Extract content using the provider adapter
				local content = D._extract_sse_content(line, qt.provider)

				if content and type(content) == "string" and content ~= "" then
					qt.response = qt.response .. content
					handler(qid, content)
				end

				::continue::
			end
		end

		-- closure for uv.read_start(stdout, fn)
		return function(err, chunk)
			local qt = tasker.get_query(qid)
			if not qt then
				return
			end

			if err then
				logger.error(qt.provider .. " query stdout error: " .. vim.inspect(err))
			elseif chunk then
				-- add the incoming chunk to the buffer
				buffer = buffer .. chunk
				local last_newline_pos = buffer:find("\n[^\n]*$")
				if last_newline_pos then
					local complete_lines = buffer:sub(1, last_newline_pos - 1)
					-- save the rest of the buffer for the next chunk
					buffer = buffer:sub(last_newline_pos + 1)

					process_lines(complete_lines)
				end
				-- chunk is nil when EOF is reached
			else
				-- if there's remaining data in the buffer, process it
				if #buffer > 0 then
					process_lines(buffer)
				end

				-- Check if this was a raw response that needs a closing marker
				if qt then
					local show_raw_response = require("parley").config and
											  require("parley").config.raw_mode and
											  require("parley").config.raw_mode.show_raw_response

					if show_raw_response and qt.response and not qt.response:match("```%s*$") then
						-- Add closing fence for the JSON code block
						handler(qid, "\n```")
						qt.response = qt.response .. "\n```"
					end
				end
				local raw_response = qt.raw_response
				logger.debug(qt.provider .. " response: \n" .. vim.inspect(qt.raw_response))

				-- Extract usage metrics via the provider adapter
				local adapter = providers.get(qt.provider)
				local metrics = adapter.parse_usage(raw_response)
				tasker.set_cache_metrics(metrics)

				local content = qt.response

				-- Handle content extraction for empty OpenAI-compatible responses
				if content == "" and raw_response:match('choices') and raw_response:match("content") then
						local response
						local ok, decoded = pcall(vim.json.decode, raw_response)
						if ok then
							response = decoded
						else
							local json_str = raw_response:match("{.-choices.-}")
							if json_str then
								local fallback_ok
								fallback_ok, response = pcall(vim.json.decode, json_str)
								if not fallback_ok then
									response = nil
								end
							end
						end

					if response and response.choices and
					   response.choices[1] and response.choices[1].message and
					   response.choices[1].message.content then
						content = response.choices[1].message.content
					end

					if content and type(content) == "string" then
						qt.response = qt.response .. content
						handler(qid, content)
					end
				end

				if qt.response == "" then
					-- Tool-use-only responses (#81 M2): Anthropic streams
					-- content_block_start with type=tool_use plus
					-- input_json_delta chunks, but none of those carry
					-- a `delta.text` field, so qt.response stays empty.
					-- The response is perfectly valid — the tool_loop
					-- driver will extract the tool_use blocks from
					-- qt.raw_response and handle them. Only warn if
					-- raw_response also has no tool_use events.
					local has_tool_use = type(qt.raw_response) == "string"
						and qt.raw_response:find('"type":"tool_use"', 1, true) ~= nil
					if not has_tool_use then
						logger.error(qt.provider .. " response is empty: \n" .. vim.inspect(qt.raw_response))
					end
				end

				-- optional on_exit handler
				if type(on_exit) == "function" then
					on_exit(qid)
					if qt.ns_id and qt.buf then
						vim.schedule(function()
							vim.api.nvim_buf_clear_namespace(qt.buf, qt.ns_id, 0, -1)
						end)
					end
				end

				-- optional callback handler
				if type(callback) == "function" then
					vim.schedule(function()
						callback(qt.response)
					end)
				end
			end
		end
	end

	-- Get endpoint and headers via the provider adapter
	local endpoint = D.providers[provider].endpoint
	local adapter = providers.get(provider)

	local secret_name = providers.get_secret_name(provider)
	local bearer = vault.get_secret(secret_name)
	if not bearer then
		logger.warning(provider .. " bearer token is missing")
		return
	end

	local headers
	headers, endpoint = adapter.format_headers(bearer, payload.model, payload, endpoint)

	local temp_file = D.query_dir ..
		"/" .. logger.now() .. "." .. string.format("%x", math.random(0, 0xFFFFFF)) .. ".json"
	helpers.table_to_file(payload, temp_file)

	local curl_params = vim.deepcopy(D.config.curl_params or {})
	local args = {
		"--no-buffer",
		"-s",
		endpoint,
		"-H",
		"Content-Type: application/json",
		"-d",
		"@" .. temp_file,
	}

	for _, arg in ipairs(args) do
		table.insert(curl_params, arg)
	end

	for _, header in ipairs(headers) do
		table.insert(curl_params, header)
	end

	tasker.run(buf, "curl", curl_params, nil, out_reader(), nil)
end

-- LLM query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
---@param on_progress function | nil # optional progress/status handler
D.query = function(buf, provider, payload, handler, on_exit, callback, on_progress)
	local adapter = providers.get(provider)
	if adapter.pre_query then
		return vault.run_with_secret(provider, function()
			adapter.pre_query(function()
				query(buf, provider, payload, handler, on_exit, callback, on_progress)
			end)
		end)
	end
	vault.run_with_secret(provider, function()
		query(buf, provider, payload, handler, on_exit, callback, on_progress)
	end)
end

-- response handler
---@param buf number | nil # buffer to insert response into
---@param win number | nil # window to insert response into
---@param line number | nil # line to insert response into
---@param first_undojoin boolean | nil # whether to skip first undojoin
---@param prefix string | nil # prefix to insert before each response line
---@param cursor boolean | function # whether to move cursor to the end of the response
D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor)
	buf = buf or vim.api.nvim_get_current_buf()
	prefix = prefix or ""
	local first_line = line or vim.api.nvim_win_get_cursor(win or 0)[1] - 1
	local finished_lines = 0
	local skip_first_undojoin = not first_undojoin

	local hl_handler_group = "ParleyHandlerStandout"
	vim.cmd("highlight default link " .. hl_handler_group .. " CursorLine")

	local ns_id = vim.api.nvim_create_namespace("ParleyHandler_" .. helpers.uuid())

	local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, first_line, 0, {
		strict = false,
		right_gravity = false,
	})

	local has_started = false
	local pending_line = ""

	local function with_prefix(lines)
		if prefix == "" then
			return lines
		end
		local prefixed = {}
		for i, l in ipairs(lines) do
			prefixed[i] = prefix .. l
		end
		return prefixed
	end

	local function split_pending_and_completed(text)
		local lines = vim.split(text, "\n")
		local completed = {}
		for i = 1, #lines - 1 do
			completed[i] = lines[i]
		end
		local pending = lines[#lines] or ""
		return completed, pending
	end

	return vim.schedule_wrap(function(qid, chunk)
		local qt = tasker.get_query(qid)
		if not qt then
			return
		end
		-- if buf is not valid, stop
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		-- undojoin takes previous change into account, so skip it for the first chunk
		if skip_first_undojoin then
			skip_first_undojoin = false
		else
			helpers.undojoin(buf)
		end

		if not qt.ns_id then
			qt.ns_id = ns_id
		end

		if not qt.ex_id then
			qt.ex_id = ex_id
		end

		if type(chunk) ~= "string" then
			return
		end

		first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]

		local previous_pending_index = finished_lines
		local completed, new_pending
		if has_started then
			completed, new_pending = split_pending_and_completed(pending_line .. chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			local start_line = first_line + finished_lines
			vim.api.nvim_buf_set_lines(buf, start_line, start_line + 1, false, replacement)
			finished_lines = finished_lines + (#completed - 1)
		else
			-- Strip leading newlines from the first chunk for consistent spacing across providers
			chunk = chunk:gsub("^\n+", "")
			completed, new_pending = split_pending_and_completed(chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			vim.api.nvim_buf_set_lines(buf, first_line, first_line + 1, false, replacement)
			finished_lines = #completed - 1
			has_started = true
		end
		pending_line = new_pending
		helpers.undojoin(buf)

		for i = previous_pending_index, finished_lines do
			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
		end

		local end_line = first_line + finished_lines + 1
		qt.first_line = first_line
		qt.last_line = end_line - 1

		-- move cursor to the end of the response
		local should_move_cursor
		if type(cursor) == "function" then
			should_move_cursor = cursor()
		else
			should_move_cursor = cursor
		end
		if should_move_cursor then
			helpers.cursor_to_line(end_line, buf, win)
		end
	end)
end

return D
