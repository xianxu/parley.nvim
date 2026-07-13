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
local query = function(buf, provider, payload, handler, on_exit, callback, on_progress,
	on_activity, on_error, abort_before_start)
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

	local function legacy_complete(query_id, qt)
		if type(on_exit) == "function" then
			on_exit(query_id)
			if qt.ns_id and qt.buf then
				vim.schedule(function()
					vim.api.nvim_buf_clear_namespace(qt.buf, qt.ns_id, 0, -1)
				end)
			end
		end
		if type(callback) == "function" then
			vim.schedule(function()
				callback(qt.response)
			end)
		end
	end

	local out_reader = function()
		local buffer = ""
		local sse_record_active = false
		local stdout_finished = false

		local function emit_activity(query_id)
			if type(on_activity) == "function" then
				on_activity(query_id)
			end
		end

		---@param line string
		local function process_line(line)
			local qt = tasker.get_query(qid)
			if not qt then
				return
			end
			if line == "" then
				sse_record_active = false
				return
			end

			local first = line:match("^%s*(.)")
			if first == "{" or first == "[" then
				emit_activity(qid)
			elseif not sse_record_active then
				emit_activity(qid)
				sse_record_active = true
			end

			local progress_event = D._extract_sse_progress_event(line, qt.provider)
			if progress_event and type(on_progress) == "function" then
				on_progress(qid, progress_event)
			end

			local content = D._extract_sse_content(line, qt.provider)
			if content and type(content) == "string" and content ~= "" then
				qt.response = qt.response .. content
				handler(qid, content)
			end
		end

		local function finish_stdout(qt)
			if stdout_finished then
				return
			end
			stdout_finished = true
			logger.debug(qt.provider .. " response received: body_bytes=" .. #qt.raw_response)

			local adapter = providers.get(qt.provider)
			local metrics = adapter.parse_usage(qt.raw_response)
			tasker.set_cache_metrics(metrics)
			qt.usage = metrics
			qt.stop_reason = qt.raw_response:match('"stop_reason"%s*:%s*"([^"]+)"')
				or qt.raw_response:match('"finish_reason"%s*:%s*"([^"]+)"')

			local content = qt.response
			if content == "" and qt.raw_response:match("choices") and qt.raw_response:match("content") then
				local response
				local ok, decoded = pcall(vim.json.decode, qt.raw_response)
				if ok then
					response = decoded
				else
					local json_str = qt.raw_response:match("{.-choices.-}")
					if json_str then
						local fallback_ok
						fallback_ok, response = pcall(vim.json.decode, json_str)
						if not fallback_ok then response = nil end
					end
				end
				if response and response.choices and response.choices[1]
					and response.choices[1].message and response.choices[1].message.content then
					content = response.choices[1].message.content
				end
				if content and type(content) == "string" then
					qt.response = qt.response .. content
					handler(qid, content)
				end
			end

			if qt.response == "" then
				local has_tool_use = qt.raw_response:find('"type":"tool_use"', 1, true) ~= nil
				if not has_tool_use then
					logger.error(qt.provider .. " response is empty: body_bytes=" .. #qt.raw_response)
				end
			end

			pcall(function()
				require("parley.cliproxy").check_auth_failure(qt.provider, qt.raw_response)
			end)
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
				qt.raw_response = qt.raw_response .. chunk
				buffer = buffer .. chunk
				while true do
					local newline = buffer:find("\n", 1, true)
					if not newline then break end
					process_line(buffer:sub(1, newline - 1):gsub("\r$", ""))
					buffer = buffer:sub(newline + 1)
				end
			else
				if #buffer > 0 then
					process_line(buffer:gsub("\r$", ""))
					buffer = ""
				end
				finish_stdout(qt)
			end
		end
	end

	-- Get endpoint and headers via the provider adapter
	local endpoint = D.providers[provider].endpoint
	local adapter = providers.get(provider)

	local secret_name = providers.get_secret_name(provider)
	local bearer = vault.get_secret(secret_name)
	if not bearer then
		abort_before_start(provider .. " bearer token is missing")
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
		"--write-out",
		"%{stderr}__PARLEY_HTTP_" .. qid .. "__%{http_code}\n",
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

	local terminal = tasker.once(function(code, signal, _stdout_data, stderr_data, io_error)
		local qt = tasker.get_query(qid)
		if not qt then return end
		stderr_data = stderr_data or ""
		local sentinel = "__PARLEY_HTTP_" .. qid .. "__"
		local trailer_size = #sentinel + 4
		local trailer = stderr_data:sub(-trailer_size)
		local status = trailer:sub(#sentinel + 1, #sentinel + 3)
		local trailer_valid = trailer:sub(1, #sentinel) == sentinel
			and status:match("^%d%d%d$") ~= nil and trailer:sub(-1) == "\n"
		local clean_stderr = stderr_data
		if trailer_valid then
			clean_stderr = stderr_data:sub(1, #stderr_data - trailer_size)
		else
			io_error = io_error or "missing or malformed curl HTTP status trailer"
		end
		local http_status = trailer_valid and tonumber(status) or nil
		local failed = io_error ~= nil or code ~= 0
			or (http_status ~= 0 and (http_status < 200 or http_status > 299))
		if failed then
			local failure = {
				code = code,
				signal = signal,
				http_status = http_status,
				body = qt.raw_response,
				stderr = clean_stderr,
				io_error = io_error,
			}
			if type(on_error) == "function" then
				on_error(qid, failure)
			else
				local safe_io_error = tostring(io_error or "none"):gsub("%s+", " "):sub(1, 160)
				logger.error(string.format(
					"%s query failed: code=%s signal=%s http_status=%s io_error=%s body_bytes=%d stderr_bytes=%d",
					provider, tostring(code), tostring(signal), tostring(http_status), safe_io_error,
					#qt.raw_response, #clean_stderr
				))
				legacy_complete(qid, qt)
			end
		else
			legacy_complete(qid, qt)
		end
	end)
	tasker.run(buf, "curl", curl_params, terminal, out_reader(), nil, abort_before_start)
end

-- LLM query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
---@param on_progress function | nil # optional progress/status handler
--- @param on_abort function | nil # optional qid-free pre-start abort handler
---   pre_query reports an error (e.g. the managed cliproxy can't be started),
---   the dispatcher invokes on_abort(msg) INSTEAD of running the query — the
---   caller uses it to tear down qid-free pre-query state (spinner, inserted
---   blocks, in-flight guards) so the request fails fast instead of hanging.
---   Additive + backward compatible: a one-arg pre_query (e.g. copilot) simply
---   ignores the error callback the dispatcher passes it.
D.query = function(buf, provider, payload, handler, on_exit, callback, on_progress, on_abort,
	on_activity, on_error)
	local abort_before_start = tasker.once(function(msg)
		logger.error("query abort before start [" .. tostring(provider) .. "]: " .. tostring(msg))
		if type(on_abort) == "function" then
			on_abort(msg)
		end
	end)
	local function start_query()
		query(buf, provider, payload, handler, on_exit, callback, on_progress,
			on_activity, on_error, abort_before_start)
	end
	local adapter = providers.get(provider)
	if adapter.pre_query then
		return vault.run_with_secret(provider, function()
			adapter.pre_query(function()
				start_query()
			end, function(msg)
				abort_before_start(msg)
			end)
		end, abort_before_start)
	end
	vault.run_with_secret(provider, function()
		start_query()
	end, abort_before_start)
end

-- response handler
---@param buf number | nil # buffer to insert response into
---@param win number | nil # window to insert response into
---@param line number | nil # line to insert response into
---@param first_undojoin boolean | nil # whether to skip first undojoin
---@param prefix string | nil # prefix to insert before each response line
---@param cursor boolean | function # whether to move cursor to the end of the response
D.create_handler = function(buf, win, line, first_undojoin, prefix, cursor, on_lines_changed, opts)
	buf = buf or vim.api.nvim_get_current_buf()
	opts = opts or {}
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
		if not qt.ns_id then
			qt.ns_id = ns_id
		end

		if not qt.ex_id then
			qt.ex_id = ex_id
		end

		if type(chunk) ~= "string" then
			return
		end
		if opts.before_write and not opts.before_write(qid, chunk) then
			return
		end
		-- undojoin takes previous change into account, so skip it for the first chunk
		if skip_first_undojoin then
			skip_first_undojoin = false
		else
			helpers.undojoin(buf)
		end

		first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]

		local buffer_edit = require("parley.buffer_edit")
		local previous_pending_index = finished_lines
		local completed, new_pending
		local delta
		if has_started then
			completed, new_pending = split_pending_and_completed(pending_line .. chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			local start_line = first_line + finished_lines
			buffer_edit.stream_replace_at_line(buf, start_line, replacement)
			delta = #completed - 1
			finished_lines = finished_lines + delta
		else
			-- Strip leading newlines from the first chunk for consistent spacing across providers
			chunk = chunk:gsub("^\n+", "")
			completed, new_pending = split_pending_and_completed(chunk)
			table.insert(completed, new_pending)
			local replacement = with_prefix(completed)
			buffer_edit.stream_replace_at_line(buf, first_line, replacement)
			delta = #completed - 1
			finished_lines = delta
			has_started = true
		end
		if on_lines_changed and delta > 0 then
			on_lines_changed(delta)
		end
		if opts.after_write then
			opts.after_write(qid, chunk, delta)
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
