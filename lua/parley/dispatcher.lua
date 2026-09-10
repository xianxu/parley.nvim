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
	-- How long an adapter that CLAIMED a failure via recover_query has to settle
	-- it (#197). A backstop, not a design element: every recovery path is
	-- expected to call retry()/give_up() itself. Overridable so specs can drive
	-- the timeout without sleeping.
	--
	-- It must exceed the slowest LEGITIMATE recovery, not merely feel short. The
	-- binding case is cliproxy's management-route repair, whose terms are derived
	-- in `cliproxy._repair_budget_sec` from the constants each step uses
	-- (including the extra probe each bounded poll can overrun by) and currently
	-- total 21s. `cliproxy_budget_spec` asserts this stays comfortably larger; if
	-- the backstop fired first it would spend the claim's one-shot and replace a
	-- correct diagnosis with "recovery timed out". A normal failure settles in a
	-- few seconds — this bound is only ever reached by an actual repair.
	recovery_timeout_ms = 30000,
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

	D.query_dir = helpers.prepare_dir(D.query_dir, "query store") or D.query_dir

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

	local wire = require("parley.tools.wire")

	-- #198: translate parley's internal (anthropic-shaped) messages into the
	-- wire's own shape BEFORE the adapter builds its payload.
	--
	-- This has to happen here, not in openai.format_payload: cliproxy's openai
	-- route builds through cliproxy_openai_payload and ollama through its own
	-- format_payload — only copilot and azure delegate to openai's. This is the
	-- single caller of adapter.format_payload, so it is the one point upstream
	-- of every builder.
	--
	-- Unconditional, NOT gated on this request declaring tools: a prior turn's
	-- tool blocks live in history and must translate on every later request.
	-- Identity for the anthropic wire and for string-content messages.
	messages = wire.translate_messages(provider, model, messages)

	local adapter = providers.get(provider)
	local payload = adapter.format_payload(messages, model, provider)

	-- Append client-side tools to whatever the adapter emitted, encoded for
	-- the same wire the messages were just translated for.
	if agent_tools and #agent_tools > 0 then
		local tools_registry = require("parley.tools")
		local defs = tools_registry.select(agent_tools)
		local client_tools = wire.encode(provider, model, defs)

		-- APPEND, do not CLOBBER: preserves server-side tools (web_search,
		-- web_fetch) that the adapter may have already written into
		-- payload.tools. Task 1.0 baseline capture discovery.
		payload.tools = payload.tools or {}
		for _, t in ipairs(client_tools) do
			table.insert(payload.tools, t)
		end
	end

	-- Stamp the wire so the RESPONSE side can decode with the same one. By the
	-- time a stream comes back the model params table is gone, and the payload
	-- carries only a bare model NAME — re-deriving from that would lose an
	-- agent's `anthropic_tools_route` override and pick the wrong decoder.
	-- `query` strips this before the request goes out, exactly as
	-- cliproxyapi.format_headers does with `_parley_route`.
	payload._parley_tool_wire = wire.name_for(provider, model)

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

--- The stop reason a raw body carries, whatever the wire calls it. PURE.
---
--- Three keys, three providers. `finishReason` is Gemini's camelCase spelling
--- and went unmatched entirely, so a Gemini response that hit its cap arrived
--- with no stop reason at all and no diagnosis was possible (#228 BR-1).
--- Extracted rather than inlined so each wire has a test.
---
---@param raw string|nil
---@return string|nil
D._extract_stop_reason = function(raw)
    if type(raw) ~= "string" then
        return nil
    end
    return raw:match('"stop_reason"%s*:%s*"([^"]+)"')      -- anthropic
        or raw:match('"finish_reason"%s*:%s*"([^"]+)"')    -- openai
        or raw:match('"finishReason"%s*:%s*"([^"]+)"')     -- googleai
end

--- Did generation END NORMALLY? PURE.
---
--- Stated as a whitelist on purpose. The first version asked the opposite
--- question — "was it the cap?" — and so stayed silent for every other
--- abnormal ending: a refusal, a content filter, an error event delivered
--- in-band after HTTP 200 (#228 BR-7). Those all leave the same artefact as a
--- cap: an answer that stops mid-sentence and looks finished.
---
--- With a whitelist, an ending nobody has seen before surfaces rather than
--- passing as normal. That is the right default for a diagnosis: a spurious
--- warning is cheap, a silently truncated transcript is not.
---
---@param stop_reason string|nil
---@return boolean
D._is_normal_finish = function(stop_reason)
    if type(stop_reason) ~= "string" then
        -- No reason parsed at all. Treated as normal: every successful
        -- non-streaming shape reaches here, and warning on all of them would
        -- be noise. The empty-response path still reports separately.
        return true
    end
    local r = stop_reason:lower()
    return r == "end_turn" or r == "stop" or r == "tool_use" or r == "end_of_turn"
        or r == "tool_calls" or r == "function_call"
end

--- An error delivered IN-BAND, after the transport already said 200. PURE.
---
--- The gap `_is_normal_finish` cannot close: a mid-stream error event carries
--- no stop reason at all, so it arrives as `nil` — which that predicate treats
--- as normal, correctly, since every ordinary non-streaming shape also has no
--- reason. The body itself is the only evidence (#228 BR-7).
---
--- HTTP said 200 and the terminal closure believes it. Without this the stream
--- simply ends: partial text, no diagnosis, nothing in the log.
---
---@param raw string|nil
---@return string|nil # the provider's message, when the body carries an error
D._inband_error = function(raw)
    if type(raw) ~= "string" then
        return nil
    end
    -- anthropic: `event: error` / {"type":"error","error":{"message":...}}
    -- openai + compatible: a bare {"error":{"message":...}} frame
    local message = raw:match('"error"%s*:%s*{[^}]-"message"%s*:%s*"([^"]+)"')
    if message then
        return message
    end
    if raw:match('"type"%s*:%s*"error"') then
        return "provider sent an error event with no message"
    end
    return nil
end

--- Did generation stop because it hit the OUTPUT-TOKEN CAP? PURE.
---
--- One predicate, because three providers spell it three ways and a diagnosis
--- that knows only one of them mislabels the other two as a normal finish
--- (#228 BR-1 — the first version recognised `max_tokens` alone, which is the
--- spelling the reported failure happened to use).
---
---   anthropic  stop_reason  = "max_tokens"
---   openai     finish_reason = "length"
---   googleai   finishReason  = "MAX_TOKENS"
---
---@param stop_reason string|nil
---@return boolean
D._is_output_cap = function(stop_reason)
    if type(stop_reason) ~= "string" then
        return false
    end
    local r = stop_reason:lower()
    return r == "max_tokens" or r == "length" or r == "maxtokens"
end

--- Say WHY a response carried no assistant text. PURE.
---
--- "response is empty: body_bytes=18152" is self-contradictory, and it has now
--- misled twice for two different causes (#197 credential failures, #228 a
--- token cap). The bytes arrived; what was missing was text. The three cases
--- are distinguishable and only one of them is a transport problem:
---
---   * nothing came back at all — the transport is the story;
---   * bytes arrived and the model stopped at its OUTPUT CAP before emitting
---     any text. On Claude that cap counts THINKING tokens, so a prompt that
---     asks the model to reason first can spend the whole budget on a thinking
---     block and produce no answer. Deterministic per prompt, which is why some
---     chats failed on every retry;
---   * bytes arrived, the model finished normally, and still emitted no text —
---     the genuinely surprising case, and the only one worth a bug report.
---
--- `stop_reason` was already extracted (see finish_stdout) and then thrown
--- away by the old message: parley knew the answer and printed a contradiction.
---
---@param qt table # the query record
---@return string
D._empty_response_reason = function(qt)
    local bytes = #(qt.raw_response or "")
    if bytes == 0 then
        return "returned no response at all (the request produced zero bytes)"
    end
    if D._is_output_cap(qt.stop_reason) then
        -- Wire-independent wording (#228 BR-1): reasoning tokens count toward
        -- this cap on every model that reasons, not only on Claude, and the
        -- old "On Claude…" phrasing told openai and googleai users something
        -- untrue about their own provider.
        return ("stopped at its output-token cap before writing any answer"
            .. " (stop_reason=" .. tostring(qt.stop_reason) .. ", body_bytes=%d)."
            .. " Reasoning/thinking tokens count toward this cap, so a prompt that"
            .. " asks the model to think first can spend the whole budget before"
            .. " the answer starts. Raise max_tokens for this agent."):format(bytes)
    end
    return ("returned no assistant text (body_bytes=%d, stop_reason=%s)")
        :format(bytes, qt.stop_reason or "unknown")
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
	on_activity, on_error, abort_before_start, restart, attempt)
	attempt = attempt or 0
	-- make sure handler is a function
	if type(handler) ~= "function" then
		logger.error(
			string.format("query() expects a handler function, but got %s:\n%s", type(handler), vim.inspect(handler))
		)
		return
	end

	-- Consume the tool-wire stamp prepare_payload left: it travels on the
	-- payload only to reach here, and must not go out over the network.
	-- Stripped BEFORE the debug log and the request body are produced.
	local tool_wire = payload._parley_tool_wire
	payload._parley_tool_wire = nil

    logger.debug("query to send is: " .. vim.json.encode(payload))

	local qid = helpers.uuid()
	tasker.set_query(qid, {
		timestamp = os.time(),
		buf = buf,
		provider = provider,
		tool_wire = tool_wire,
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
		local function invoke_surface(label, fn, ...)
			if type(fn) ~= "function" then return end
			local args = { ... }
			local arg_count = select("#", ...)
			local ok = xpcall(function()
				fn(unpack(args, 1, arg_count))
			end, function() return nil end)
			if not ok then logger.error(provider .. " " .. label .. " failed") end
		end

		local function schedule_surface(label, fn)
			local ok = pcall(vim.schedule, function()
				invoke_surface(label, fn)
			end)
			if not ok then logger.error(provider .. " " .. label .. " scheduling failed") end
		end

		if type(on_exit) == "function" then
			invoke_surface("on_exit", on_exit, query_id)
			if qt.ns_id and qt.buf then
				schedule_surface("namespace cleanup", function()
					vim.api.nvim_buf_clear_namespace(qt.buf, qt.ns_id, 0, -1)
				end)
			end
		end
		if type(callback) == "function" then
			schedule_surface("assembled response callback", function()
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
			-- Three spellings, because three providers. `finishReason` is
			-- Gemini's camelCase key and was not matched at all, so a Gemini
			-- response that hit its cap arrived with stop_reason nil (#228 BR-1).
			qt.stop_reason = D._extract_stop_reason(qt.raw_response)

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

			-- Record, don't report (#197). finish_stdout runs BEFORE the terminal
			-- closure and cannot know whether the request actually succeeded, so
			-- logging here made every credential failure announce the misleading
			-- "response is empty: body_bytes=215" *ahead of* the real diagnosis —
			-- the exact symptom this issue set out to remove. The terminal
			-- closure emits it, and only on a successful request.
			if qt.response == "" then
				-- Per-wire (#198): the anthropic literal was hardcoded here, so
				-- a tool-only turn from an OpenAI-family agent reported an
				-- empty response. qt.tool_wire is the wire prepare_payload
				-- actually built for.
				qt.empty_response = not require("parley.tools.wire")
					.has_tool_calls_by_name(qt.tool_wire, qt.raw_response)
			end

			-- NOTE (#197): auth-failure detection deliberately does NOT live
			-- here. finish_stdout runs on every completed response, successes
			-- included, so classifying here means classifying ordinary
			-- assistant prose — a chat about a 401 would have popped a login
			-- prompt. It now lives in the terminal closure below, which is the
			-- only scope that knows the HTTP status.
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
				-- The request's model: the only path by which a failure body
				-- that names neither provider nor model (cliproxy's expired-token
				-- 401) can still be resolved to a credential channel (#197).
				model = payload and payload.model,
				-- Did any content already reach the buffer? `handler` writes
				-- streamed content as it arrives, so a retry after a partial
				-- stream would duplicate text. Recovery must not claim those.
				streamed = qt.response ~= "",
				attempt = attempt,
			}
			local function deliver(msg)
				if msg then
					failure.message = msg
				end
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
			end

			-- Recovery seam (#197). `on_error` is TERMINAL downstream — it
			-- finishes the pending session and tears down the chat leg — and
			-- recovery is async, so an adapter cannot simply "run first": it
			-- must CLAIM the failure synchronously. A truthy claim withholds
			-- on_error and puts the adapter in debt for exactly one of
			-- retry()/give_up(); a falsy claim (and every adapter without the
			-- hook) leaves today's behavior untouched.
			if type(adapter.recover_query) == "function" and attempt == 0
				and type(restart) == "function" then
				local settle = tasker.once(function(action, msg)
					if action == "retry" then
						restart(attempt + 1)
					else
						deliver(msg)
					end
				end)
				-- Guarded: `recover_query` runs synchronously and touches the
				-- filesystem and vim.system before it returns its claim, so it
				-- CAN raise. An unguarded throw here would skip deliver() AND
				-- the backstop arming below, and tasker's call_safely swallows
				-- terminal errors — stranding the chat leg with no message at
				-- all. A hook that blew up never claimed anything.
				local hook_ok, claimed = pcall(adapter.recover_query, failure, function()
					settle("retry")
				end, function(msg)
					settle("give_up", msg)
				end)
				if not hook_ok then
					logger.error(provider .. ": recover_query raised: " .. tostring(claimed))
					claimed = false
				end
				if claimed then
					-- Backstop against a recovery that never settles: degrade to
					-- today's behavior rather than hold the chat leg open
					-- forever. `settle` is once-only, so this cannot double-fire
					-- with a late retry/give_up.
					vim.defer_fn(function()
						settle("give_up", provider .. ": recovery timed out")
					end, D.recovery_timeout_ms)
					return
				end
			end
			deliver()
		else
			-- Only a request that SUCCEEDED can meaningfully be called empty;
			-- on a failure the diagnosis carries the reason instead (#197).
			if qt.empty_response then
				logger.error(provider .. " " .. D._empty_response_reason(qt))
			elseif D._inband_error(qt.raw_response) then
				-- HTTP 200, and the failure is inside the body. Neither the
				-- status nor the stop reason can see it (#228 BR-7).
				logger.warning(("%s answer is TRUNCATED: the provider sent an"
					.. " error mid-stream after HTTP 200 — %s")
					:format(provider, D._inband_error(qt.raw_response)))
			elseif not D._is_normal_finish(qt.stop_reason) then
				-- The OTHER half of the reported symptom (#228 BR-2), widened to
				-- the class (BR-7): ANY abnormal ending after some text has
				-- streamed. A cap, a refusal, a content filter and an in-band
				-- error all leave the same artefact — an answer that stops
				-- mid-sentence and looks finished — and parley knew the reason
				-- and said nothing.
				local advice = D._is_output_cap(qt.stop_reason)
					and " Raise max_tokens for this agent and re-run to get the rest."
					or ""
				logger.warning(("%s answer is TRUNCATED: generation ended early"
					.. " (stop_reason=%s).%s")
					:format(provider, tostring(qt.stop_reason), advice))
			end
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
	-- `local function` (not `local x = function`) so it can pass ITSELF down as
	-- the restart entry point: `query` is a file-local that cannot reference
	-- itself, and the terminal closure that needs to re-issue the request is
	-- nested inside it (#197).
	local function start_query(attempt)
		-- Per-attempt payload snapshot. format_headers CONSUMES fields from the
		-- payload (cliproxyapi nils `_parley_route`, googleai nils `model`), so
		-- a retry that reused the same table would re-issue a materially
		-- different request — an anthropic-routed claude call would retry against
		-- the OpenAI-shaped endpoint with OpenAI headers.
		query(buf, provider, vim.deepcopy(payload), handler, on_exit, callback, on_progress,
			on_activity, on_error, abort_before_start, start_query, attempt or 0)
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
		local function write()
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
		local end_line = first_line + finished_lines + 1
		qt.first_line = first_line
		qt.last_line = end_line - 1
		if opts.after_write then
			opts.after_write(qid, chunk, delta, end_line - 1)
		end
		pending_line = new_pending
		helpers.undojoin(buf)

		for i = previous_pending_index, finished_lines do
			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
		end

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
		end
		if opts.around_write then
			opts.around_write(qid, chunk, write)
		else
			write()
		end
	end)
end

return D
