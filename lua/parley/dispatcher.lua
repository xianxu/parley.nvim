--------------------------------------------------------------------------------
-- Dispatcher handles the communication between the plugin and LLM providers.
--------------------------------------------------------------------------------

local logger = require("parley.logger")
local tasker = require("parley.tasker")
local vault = require("parley.vault")
local render = require("parley.render")
local helpers = require("parley.helper")

local default_config = require("parley.config")
local provider_params = require("parley.provider_params")

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
D.prepare_payload = function(messages, model, provider)
	if type(model) == "string" then
		return {
			model = model,
			stream = true,
			messages = messages,
		}
	end

	if provider == "googleai" then
		for i, message in ipairs(messages) do
			if message.role == "system" then
				messages[i].role = "user"
			end
			if message.role == "assistant" then
				messages[i].role = "model"
			end
			if message.content then
				messages[i].parts = {
					{
						text = message.content,
					},
				}
				messages[i].content = nil
			end
		end
		local i = 1
		while i < #messages do
			if messages[i].role == messages[i + 1].role then
				table.insert(messages[i].parts, {
					text = messages[i + 1].parts[1].text,
				})
				table.remove(messages, i + 1)
			else
				i = i + 1
			end
		end
		local payload = {
			contents = messages,
			safetySettings = {
				{
					category = "HARM_CATEGORY_HARASSMENT",
					threshold = "BLOCK_NONE",
				},
				{
					category = "HARM_CATEGORY_HATE_SPEECH",
					threshold = "BLOCK_NONE",
				},
				{
					category = "HARM_CATEGORY_SEXUALLY_EXPLICIT",
					threshold = "BLOCK_NONE",
				},
				{
					category = "HARM_CATEGORY_DANGEROUS_CONTENT",
					threshold = "BLOCK_NONE",
				},
			},
			generationConfig = provider_params.resolve_params("googleai", model),
			model = model.model,
		}
		return payload
	end

	if provider == "anthropic" then
		-- Create an array for system messages with content and cache_control
		local system_blocks = {}
		
		-- Extract system messages and build the system format Anthropic expects
		local i = 1
		while i <= #messages do
			if messages[i].role == "system" then
				-- Create a system block in Anthropic's expected format
				local block = {
					type = "text",
					text = messages[i].content
				}
				
				-- If this system message has cache_control, include it
				if messages[i].cache_control then
					block.cache_control = messages[i].cache_control
					logger.debug("Added cache_control to system block: " .. vim.inspect(messages[i].cache_control))
				end
				
				-- Add this block to our system blocks array
				table.insert(system_blocks, block)
				
				-- Remove from messages array since we've processed it
				table.remove(messages, i)
			else
				i = i + 1
			end
		end
		
		-- Create the payload with the system array if we have system blocks
		local params = provider_params.resolve_params("anthropic", model)
		local payload = {
			model = model.model,
			stream = true,
			messages = messages,
		}
		for k, v in pairs(params) do
			payload[k] = v
		end
		
		-- Only add the system array if we have system blocks
		if #system_blocks > 0 then
			payload.system = system_blocks
		end
		-- add Claude server-side web_search and web_fetch tools if enabled in chat state
		local parley = require("parley")
		if parley._state and parley._state.claude_web_search then
			payload.tools = {
				{
					type = "web_search_20250305",
					name = "web_search",
					max_uses = 5,
				},
				{
					type = "web_fetch_20250910",
					name = "web_fetch",
					max_uses = 5,
				},
			}
		end
		
		return payload
	end

	if provider == "copilot" and model.model == "gpt-4o" then
		model.model = "gpt-4o-2024-05-13"
	end

	local params = provider_params.resolve_params(provider, model)
	local output = {
		model = model.model,
		stream = true,
		messages = messages,
		stream_options = {
			include_usage = true
		}
	}
	for k, v in pairs(params) do
		output[k] = v
	end

	-- o-series and reasoning models: strip system messages
	if (provider == "openai" or provider == "copilot") and (model.model:sub(1, 1) == "o" or model.model == "gpt-4o-search-preview" or model.model == "gpt-5") then
		for i = #messages, 1, -1 do
			if messages[i].role == "system" then
				table.remove(messages, i)
			end
		end
	end

	logger.debug("payload: " .. vim.inspect(output))
	return output
end

-- Extract text content from a single SSE line.
-- This is the pure extraction logic, separated from query/process_lines for testability.
-- Returns extracted content string, or "" if no content found or if line is malformed.
---@param line string # a single SSE line (may have "data: " prefix which will be stripped)
---@param provider string # provider name ("openai", "anthropic", "googleai", etc.)
---@return string # extracted text content, or ""
D._extract_sse_content = function(line, provider)
	-- Strip "data: " prefix if present
	line = line:gsub("^data: ", "")
	
	-- Skip empty lines and [DONE] markers
	if line == "" or line == "[DONE]" then
		return ""
	end
	
	local content = ""
	local success, decoded_line
	
	-- OpenAI / copilot / azure / ollama format (only for compatible providers)
	local openai_compatible = (provider == "openai" or provider == "copilot" or 
	                           provider == "azure" or provider == "ollama")
	
	if openai_compatible then
		-- Try safe JSON decode first
		success, decoded_line = pcall(function()
			if line:match("^%s*{") and line:match("}%s*$") then
				return vim.json.decode(line)
			end
			return nil
		end)
		
		if success and decoded_line and decoded_line.choices then
			if decoded_line.choices[1] and decoded_line.choices[1].delta 
			   and decoded_line.choices[1].delta.content then
				content = decoded_line.choices[1].delta.content
				-- Handle JSON null (vim.NIL)
				if content == vim.NIL then
					content = ""
				end
			end
		-- Fallback for OpenAI if first parse failed but line looks like OpenAI format
		elseif line:match("choices") and line:match("delta") and line:match("content") then
			success, decoded_line = pcall(vim.json.decode, line)
			if success and decoded_line and decoded_line.choices and 
			   decoded_line.choices[1] and decoded_line.choices[1].delta and 
			   decoded_line.choices[1].delta.content then
				content = decoded_line.choices[1].delta.content
				-- Handle JSON null (vim.NIL)
				if content == vim.NIL then
					content = ""
				end
			end
		end
	end
	
	-- Anthropic format
	if provider == "anthropic" and line:match('"text":') then
		if line:match("content_block_start") or line:match("content_block_delta") then
			success, decoded_line = pcall(vim.json.decode, line)
			if success and decoded_line then
				if decoded_line.delta and decoded_line.delta.text then
					content = decoded_line.delta.text
				end
				if decoded_line.content_block and decoded_line.content_block.text then
					content = decoded_line.content_block.text
				end
			end
		end
	end
	
	-- Google AI format
	if provider == "googleai" and line:match('"text":') then
		success, decoded_line = pcall(vim.json.decode, "{" .. line .. "}")
		if success and decoded_line and decoded_line.text then
			content = decoded_line.text
		end
	end
	
	return content
end

-- gpt query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
local query = function(buf, provider, payload, handler, on_exit, callback)
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
					qt.response = "```json\n" .. qt.raw_response
					handler(qid, "```json\n" .. lines_chunk)
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
				
				-- Extract content using the pure extraction function
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
				local qt = tasker.get_query(qid)
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
				
				-- Check for Anthropic cache usage metrics and store them
				if qt.provider == "anthropic" or qt.provider == "claude" then
					-- Reset metrics for Anthropic at the start of its processing
					tasker.set_cache_metrics({
						input = nil,
						read = nil,
						creation = nil
					})
					
					local success, decoded = false, nil
					
					-- Try multiple strategies to extract usage info
					-- Strategy 1: Look for "message_delta" with usage (appears at end of stream)
					for line in raw_response:gmatch("[^\n]+") do
						if line:match('"type"%s*:%s*"message_delta"') and line:match('"usage"') then
							-- Extract just the JSON from this line (strip any data: prefix)
							local json_str = line:gsub("^data:%s*", "")
							success, decoded = pcall(vim.json.decode, json_str)
							if success and decoded and decoded.usage then
								break
							end
						end
					end
					
					-- Strategy 2: Try to match any complete JSON object with usage
					if not (success and decoded and decoded.usage) then
						local clean_json = raw_response:match("{.-usage.-}")
						if clean_json then
							success, decoded = pcall(vim.json.decode, clean_json)
						end
					end
					
					-- Strategy 3: Extract just the usage object and wrap it
					if not (success and decoded and decoded.usage) then
						local usage_json = raw_response:match('("usage":%s*{[^{}]*})')
						if usage_json then
							usage_json = "{" .. usage_json .. "}"
							success, decoded = pcall(vim.json.decode, usage_json)
						end
					end
					
					-- If we successfully extracted usage info, store the metrics
					if success and decoded and decoded.usage then
						logger.debug("Anthropic JSON decoded successfully: " .. vim.inspect(decoded))
						
						local metrics = {
							input = decoded.usage.input_tokens or 0,
							creation = decoded.usage.cache_creation_input_tokens or 0,
							read = decoded.usage.cache_read_input_tokens or 0
						}
						
						tasker.set_cache_metrics(metrics)
						
						logger.debug("Anthropic metrics extracted: input=" .. metrics.input .. 
							", creation=" .. metrics.creation .. 
							", read=" .. metrics.read)
					else
						logger.debug("Anthropic usage extraction failed - no metrics found")
					end
				end

				local content = qt.response
				
				-- Reset metrics at the start of response processing
				if qt.provider ~= "anthropic" and qt.provider ~= "claude" then
					-- Skip reset for Anthropic as we already process metrics earlier
					tasker.set_cache_metrics({
						input = nil,
						read = nil,
						creation = nil
					})
				end
				
				-- Handle Google AI (Gemini) usage metrics extraction
				if qt.provider == "googleai" then
					local usage_pattern = '"usageMetadata":%s*{[^}]*"promptTokenCount":%s*(%d+)[^}]*"candidatesTokenCount":%s*(%d+)[^}]*"totalTokenCount":%s*(%d+)[^}]*'
					local prompt_tokens, candidates_tokens, total_tokens = raw_response:match(usage_pattern)
					
					if prompt_tokens then
						local metrics = {
							input = tonumber(prompt_tokens) or 0,
							read = 0,  -- Gemini doesn't have a read/cache concept
							creation = 0 -- or could set to candidates_tokens if preferred
						}
						
						tasker.set_cache_metrics(metrics)
						logger.debug("Gemini metrics extracted: input=" .. metrics.input .. 
							", read=" .. metrics.read .. 
							", creation=" .. metrics.creation)
					else
						-- Try with unescaped pattern (some responses might be escaped)
						local escaped_pattern = '\\\"usageMetadata\\\":%s*{[^}]*\\\"promptTokenCount\\\":%s*(%d+)[^}]*\\\"candidatesTokenCount\\\":%s*(%d+)[^}]*\\\"totalTokenCount\\\":%s*(%d+)[^}]*'
						prompt_tokens, candidates_tokens, total_tokens = raw_response:match(escaped_pattern)
						
						if prompt_tokens then
							local metrics = {
								input = tonumber(prompt_tokens) or 0,
								read = 0,
								creation = 0
							}
							
							tasker.set_cache_metrics(metrics)
							logger.debug("Gemini metrics extracted (escaped): input=" .. metrics.input .. 
								", read=" .. metrics.read .. 
								", creation=" .. metrics.creation)
						end
					end
				end
				
				-- Handle OpenAI/Copilot specific processing
				if (qt.provider == 'openai' or qt.provider == 'copilot') then
					
					-- Check for usage information in the response
					if raw_response:match('"usage"') then
						-- Process each line separately to find a complete JSON object with usage info
						local usage_json = nil
						
						-- Split the raw response into lines
						for line in raw_response:gmatch("([^\n]+)") do
							-- Check if this line has a usage field and empty choices
							if line:match('"usage"') and line:match('"choices":%s*%[%s*%]') then
								-- Clean up the line - remove any data: prefix
								local clean_line = line:gsub("^data:%s*", "")
								
								-- Try to ensure the JSON is complete by checking for balanced braces
								local open_count, close_count = 0, 0
								for c in clean_line:gmatch(".") do
									if c == "{" then open_count = open_count + 1 end
									if c == "}" then close_count = close_count + 1 end
								end
								
								-- Only use lines that have balanced braces
								if open_count == close_count then
									usage_json = clean_line
									break
								end
							end
						end
						
						-- If that didn't work, try to extract a JSON object with specific markers
						if not usage_json then
							usage_json = raw_response:match('{"id":"[^"]*","object":"chat%.completion%.chunk"[^}]*"choices":%[%][^}]*"usage":{[^}]*}}')
						end
						
						-- If still nothing, try more aggressively to find any JSON with usage
						if not usage_json then
							for line in raw_response:gmatch("([^\n]+)") do
								if line:match('"usage"') then
									-- Just extract from the start of a JSON object to the end
									local potential_json = line:match('({.-})')
									if potential_json then
										usage_json = potential_json
										break
									end
								end
							end
						end
						
						-- Log the found JSON for debugging
						logger.debug("OpenAI usage JSON found: " .. (usage_json and string.sub(usage_json, 1, 100) .. "..." or "nil"))
						
						if usage_json then
							-- Try to parse the JSON, with fallbacks for potential truncation
							local success, decoded = pcall(vim.json.decode, usage_json)
							
							-- Handle potential parsing issues more directly
							if not success then
								logger.debug("First parse attempt failed: " .. tostring(decoded))
								
								-- Try a crude extraction of the key values we need
								local prompt_tokens = tonumber(usage_json:match('"prompt_tokens":%s*(%d+)'))
								local cached_tokens = tonumber(usage_json:match('"cached_tokens":%s*(%d+)'))
								
								if prompt_tokens then
									logger.debug("Fallback extraction of tokens succeeded")
									
									-- Create metrics from directly extracted values
									local metrics = {
										input = prompt_tokens or 0,
										read = cached_tokens or 0,
										creation = 0
									}
									
									tasker.set_cache_metrics(metrics)
									
									logger.debug("OpenAI metrics extracted via fallback: input=" .. metrics.input .. 
										", read=" .. metrics.read .. 
										", creation=" .. metrics.creation)
								else
									logger.debug("Fallback extraction failed too")
								end
							else
								-- JSON parsing succeeded
								logger.debug("OpenAI JSON parsed successfully")
								
								-- Safely extract the metrics
								if decoded and type(decoded.usage) == "table" then
									-- Create metrics using exactly the fields from the example
									local metrics = {
										input = tonumber(decoded.usage.prompt_tokens) or 0,
										read = 0,
										creation = 0
									}
									
									-- Extract cached_tokens from prompt_tokens_details if available
									if type(decoded.usage.prompt_tokens_details) == "table" then
										metrics.read = tonumber(decoded.usage.prompt_tokens_details.cached_tokens) or 0
									end
								
								tasker.set_cache_metrics(metrics)
								
								logger.debug("OpenAI metrics extracted: input=" .. metrics.input .. 
									", read=" .. metrics.read .. 
									", creation=" .. metrics.creation)
								end
							end
						end
					end
					
					-- Handle content extraction for empty responses
					if content == "" and raw_response:match('choices') and raw_response:match("content") then
						local response
						local success, decoded = pcall(vim.json.decode, raw_response)
						if success then
							response = decoded
						else
							-- Try to parse just what looks like a valid JSON object
							local json_str = raw_response:match("{.-choices.-}")
							if json_str then
								success, response = pcall(vim.json.decode, json_str)
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
				end


				if qt.response == "" then
					logger.error(qt.provider .. " response is empty: \n" .. vim.inspect(qt.raw_response))
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

	---TODO: this could be moved to a separate function returning endpoint and headers
	local endpoint = D.providers[provider].endpoint
	local headers = {}

	local secret = provider
	if provider == "copilot" then
		secret = "copilot_bearer"
	end
	local bearer = vault.get_secret(secret)
	if not bearer then
		logger.warning(provider .. " bearer token is missing")
		return
	end

	if provider == "copilot" then
		headers = {
			"-H",
			"editor-version: vscode/1.85.1",
			"-H",
			"Authorization: Bearer " .. bearer,
		}
	elseif provider == "openai" then
		headers = {
			"-H",
			"Authorization: Bearer " .. bearer,
			-- backwards compatibility
			"-H",
			"api-key: " .. bearer,
		}
	elseif provider == "googleai" then
		headers = {}
		endpoint = render.template_replace(endpoint, "{{secret}}", bearer)
		endpoint = render.template_replace(endpoint, "{{model}}", payload.model)
		payload.model = nil
	elseif provider == "anthropic" then
		-- choose anthropic-beta header based on use of web_fetch tool
		local beta_tag = "messages-2023-12-15"
		if payload and payload.tools then
			for _, tool in ipairs(payload.tools) do
				if tool.name == "web_fetch" then
					beta_tag = "web-fetch-2025-09-10"
					break
				end
			end
		end
		headers = {
			"-H",
			"x-api-key: " .. bearer,
			"-H",
			"anthropic-version: 2023-06-01",
			"-H",
			"anthropic-beta: " .. beta_tag,
		}
	elseif provider == "azure" then
		headers = {
			"-H",
			"api-key: " .. bearer,
		}
		endpoint = render.template_replace(endpoint, "{{model}}", payload.model)
	else -- default to openai compatible headers
		headers = {
			"-H",
			"Authorization: Bearer " .. bearer,
		}
	end

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

-- gpt query
---@param buf number | nil # buffer number
---@param provider string # provider name
---@param payload table # payload for api
---@param handler function # response handler
---@param on_exit function | nil # optional on_exit handler
---@param callback function | nil # optional callback handler
D.query = function(buf, provider, payload, handler, on_exit, callback)
	if provider == "copilot" then
		return vault.run_with_secret(provider, function()
			vault.refresh_copilot_bearer(function()
				query(buf, provider, payload, handler, on_exit, callback)
			end)
		end)
	end
	vault.run_with_secret(provider, function()
		query(buf, provider, payload, handler, on_exit, callback)
	end)
end

-- response handler
---@param buf number | nil # buffer to insert response into
---@param win number | nil # window to insert response into
---@param line number | nil # line to insert response into
---@param first_undojoin boolean | nil # whether to skip first undojoin
---@param prefix string | nil # prefix to insert before each response line
---@param cursor boolean # whether to move cursor to the end of the response
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

	local response = ""
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

		first_line = vim.api.nvim_buf_get_extmark_by_id(buf, ns_id, ex_id, {})[1]

		-- clean previous response
		local line_count = #vim.split(response, "\n")
		vim.api.nvim_buf_set_lines(buf, first_line + finished_lines, first_line + line_count, false, {})

		-- append new response
		response = response .. chunk
		helpers.undojoin(buf)

		-- prepend prefix to each line
		local lines = vim.split(response, "\n")
		for i, l in ipairs(lines) do
			lines[i] = prefix .. l
		end

		local unfinished_lines = {}
		for i = finished_lines + 1, #lines do
			table.insert(unfinished_lines, lines[i])
		end

		vim.api.nvim_buf_set_lines(buf, first_line + finished_lines, first_line + finished_lines, false, unfinished_lines)

		local new_finished_lines = math.max(0, #lines - 1)
		for i = finished_lines, new_finished_lines do
			vim.api.nvim_buf_add_highlight(buf, qt.ns_id, hl_handler_group, first_line + i, 0, -1)
		end
		finished_lines = new_finished_lines

		local end_line = first_line + #vim.split(response, "\n")
		qt.first_line = first_line
		qt.last_line = end_line - 1

		-- move cursor to the end of the response
		if cursor then
			helpers.cursor_to_line(end_line, buf, win)
		end
	end)
end

return D
