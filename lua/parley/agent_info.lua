-- Agent info resolution: merges chat file headers with agent defaults
-- to produce the final provider, model, system_prompt, and tool config.

local M = {}

--- Resolve agent info by merging header overrides onto agent defaults.
--- @param headers table|nil  parsed chat file headers
--- @param agent table  agent config (name, provider, model, system_prompt, tools, etc.)
--- @param state table  parley state (system_prompt selection)
--- @param system_prompts table  available system prompts
--- @param memory_prefs table  memory preferences module
--- @param logger table  logger module
--- @return table  resolved agent info
function M.resolve(headers, agent, state, system_prompts, memory_prefs, logger)
	local function parse_prompt_header(value)
		if type(value) ~= "string" then
			return nil
		end
		if not value:match("%S") then
			return nil
		end
		return value:gsub("\\n", "\n")
	end

	local function collect_appended_header_values(key)
		if type(headers) ~= "table" or type(headers._append) ~= "table" then
			return {}
		end
		local values = headers._append[key]
		if type(values) ~= "table" then
			return {}
		end
		return values
	end

	local function append_prompt_line(base, extra)
		if not base or base == "" then
			return extra .. "\n"
		end
		if base:sub(-1) ~= "\n" then
			base = base .. "\n"
		end
		return base .. extra .. "\n"
	end

	-- Get the selected system prompt from state, fallback to agent's system prompt
	local selected_system_prompt = state.system_prompt or "default"
	local system_prompt = system_prompts[selected_system_prompt]
			and system_prompts[selected_system_prompt].system_prompt
		or agent.system_prompt

	local info = {
		name = agent.name,
		provider = agent.provider,
		model = agent.model,
		system_prompt = system_prompt,
		display_name = agent.name,
		tools = agent.tools,
		max_tool_iterations = agent.max_tool_iterations,
		tool_result_max_bytes = agent.tool_result_max_bytes,
	}

	-- Override with header values if they exist
	if headers then
		-- Provider from headers takes precedence
		if headers.provider then
			info.provider = headers.provider
		end

		-- Override model from headers
		if headers.model then
			-- If model is a JSON string, decode it
			if type(headers.model) == "string" and headers.model:match("{.*}") then
				local success, decoded = pcall(vim.json.decode, headers.model)
				if success then
					info.model = decoded
				else
					info.model = headers.model
					logger.warning("Failed to parse model JSON: " .. headers.model)
				end
			else
				info.model = headers.model
			end
		end

		-- Override system prompt from headers.
		-- Canonical key: system_prompt; role is kept as backward-compatible alias.
		local header_system_prompt = parse_prompt_header(headers.system_prompt) or parse_prompt_header(headers.role)
		if header_system_prompt then
			info.system_prompt = header_system_prompt
		end

		-- Append system prompt additions in-order.
		local append_values = collect_appended_header_values("system_prompt")
		if #append_values == 0 then
			append_values = collect_appended_header_values("role")
		end
		for _, prompt_append in ipairs(append_values) do
			local parsed_append = parse_prompt_header(prompt_append)
			if parsed_append then
				info.system_prompt = append_prompt_line(info.system_prompt, parsed_append)
			end
		end

		-- Append memory-based user preferences (based on chat tags)
		local mem_pref = memory_prefs.get_preference(headers.tags)
		if mem_pref then
			info.system_prompt = append_prompt_line(info.system_prompt, mem_pref)
		end

		-- Update display name if model or role is overridden
		if headers.model then
			if type(info.model) == "table" and info.model.model then
				info.display_name = info.model.model
			else
				info.display_name = tostring(info.model)
			end

				if header_system_prompt or #append_values > 0 then
					info.display_name = info.display_name .. " & custom system prompt"
				end
			end

		-- Set a default provider if one is specified in header model but not provider
		if headers.model and not headers.provider then
			info.provider = info.provider or "openai"
		end
	end

	-- Check model validity - if it's not a string or a table, make it a string
	if type(info.model) ~= "string" and type(info.model) ~= "table" then
		info.model = tostring(info.model)
	end

	-- For OpenAI/string models, ensure they're well-formed for dispatcher.prepare_payload
	if type(info.model) == "string" then
		info.model = { model = info.model }
	end

	return info
end

return M
