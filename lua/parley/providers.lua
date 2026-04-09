--------------------------------------------------------------------------------
-- Provider adapters and registry.
--
-- Each provider adapter encapsulates all provider-specific behavior:
-- payload formatting, header construction, SSE parsing, and usage extraction.
--
-- Usage:
--   local providers = require("parley.providers")
--   local adapter = providers.get("anthropic")
--   local payload = adapter.format_payload(messages, model, params, state)
--------------------------------------------------------------------------------

local logger = require("parley.logger")
local render = require("parley.render")
local provider_params = require("parley.provider_params")

local M = {}

-- Server tool revisions verified against provider docs on 2026-03-08.
local ANTHROPIC_WEB_SEARCH_TOOL_TYPE = "web_search_20260209"
local ANTHROPIC_WEB_FETCH_TOOL_TYPE = "web_fetch_20260209"
local ANTHROPIC_WEB_FETCH_BETA_TAG = "web-fetch-2025-09-10"

--------------------------------------------------------------------------------
-- Helpers shared across adapters
--------------------------------------------------------------------------------

local function safe_json_decode(str)
    local success, decoded = pcall(vim.json.decode, str)
    if success then
        return decoded
    end
    return nil
end

local function strip_data_prefix(line)
    return line:gsub("^data: ", "")
end

local function tool_progress_message(tool_name)
    if tool_name == "web_search" or tool_name == "web_search_call" then
        return "Searching web..."
    end
    if tool_name == "web_fetch" then
        return "Fetching web page..."
    end
    if type(tool_name) == "string" and tool_name ~= "" then
        return "Running " .. tool_name .. "..."
    end
    return "Running tool..."
end

local function tool_result_message(tool_name)
    if tool_name == "web_search" or tool_name == "web_search_call" then
        return "Search results received..."
    end
    if tool_name == "web_fetch" then
        return "Fetched page content..."
    end
    if type(tool_name) == "string" and tool_name ~= "" then
        return "Completed " .. tool_name .. "..."
    end
    return "Tool result received..."
end

local function reasoning_progress_message()
    return "Reasoning..."
end

local function make_progress_event(event_type, block_type, tool_name, kind, phase, message, text)
    return {
        type = event_type,
        block_type = block_type,
        tool = tool_name,
        kind = kind,
        phase = phase,
        message = message,
        text = text,
    }
end

local function pick_tool_detail_text(value)
    if type(value) ~= "table" then
        return nil
    end
    local candidates = {
        value.query,
        value.url,
        value.search_query,
        value.web_query,
        value.prompt,
        value.path,
    }
    for _, candidate in ipairs(candidates) do
        if type(candidate) == "string" and candidate ~= "" then
            return candidate
        end
    end
    return nil
end

local function get_cliproxy_strategy(model_config)
    if type(model_config) == "table" then
        local model_strategy = model_config.web_search_strategy
        if model_strategy == "openai_search_model" or model_strategy == "openai_tools_route" or model_strategy == "anthropic_tools_route" then
            return model_strategy
        end
    end

    local ok, parley = pcall(require, "parley")
    if not ok or not parley or not parley.dispatcher or not parley.dispatcher.providers then
        return "none"
    end

    local config = parley.dispatcher.providers.cliproxyapi or {}
    local strategy = config.web_search_strategy
    if strategy == "openai_search_model" or strategy == "openai_tools_route" or strategy == "anthropic_tools_route" then
        return strategy
    end
    return "none"
end

local function cliproxy_anthropic_endpoint(endpoint)
    if type(endpoint) ~= "string" then
        return endpoint
    end
    if endpoint:find("/api/provider/anthropic/v1/messages", 1, true) then
        return endpoint
    end

    local swapped = endpoint:gsub("/v1/chat/completions$", "/api/provider/anthropic/v1/messages")
    if swapped ~= endpoint then
        return swapped
    end

    swapped = endpoint:gsub("/v1/responses$", "/api/provider/anthropic/v1/messages")
    if swapped ~= endpoint then
        return swapped
    end

    return endpoint
end

local function is_cliproxy_anthropic_route_model(model_name)
    if type(model_name) ~= "string" then
        return false
    end
    return model_name:find("^claude%-") ~= nil or model_name:find("^code_execution_") ~= nil
end

--------------------------------------------------------------------------------
-- OpenAI adapter (base for copilot, azure, ollama)
--------------------------------------------------------------------------------

local openai = {
    aliases = {},
    features = { web_search = true },
    cache_metrics = { read = true, creation = false },
}

openai.format_payload = function(messages, model, provider_name)
    -- Swap to search_model variant when web_search is enabled
    local model_name = model.model
    local parley = require("parley")
    if parley._state and parley._state.web_search and model.search_model then
        model_name = model.search_model
    end

    -- Resolve params using the actual model name (search models strip temperature/top_p)
    local param_model = vim.tbl_extend("force", model, { model = model_name })
    local params = provider_params.resolve_params(provider_name or "openai", param_model)

    local output = {
        model = model_name,
        stream = true,
        messages = messages,
        stream_options = {
            include_usage = true,
        },
    }
    for k, v in pairs(params) do
        output[k] = v
    end

    return output
end

openai.format_headers = function(secret, _model, _payload, endpoint)
    local headers = {
        "-H",
        "Authorization: Bearer " .. secret,
    }
    return headers, endpoint
end

openai.parse_sse_content = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return ""
    end

    -- Try safe JSON decode
    if line:match("^%s*{") and line:match("}%s*$") then
        local decoded = safe_json_decode(line)
        if decoded and decoded.choices and decoded.choices[1]
            and decoded.choices[1].delta and decoded.choices[1].delta.content then
            local content = decoded.choices[1].delta.content
            if content == vim.NIL then
                return ""
            end
            return content
        end
    end

    -- Fallback: regex-match for OpenAI-like format
    if line:match("choices") and line:match("delta") and line:match("content") then
        local decoded = safe_json_decode(line)
        if decoded and decoded.choices and decoded.choices[1]
            and decoded.choices[1].delta and decoded.choices[1].delta.content then
            local content = decoded.choices[1].delta.content
            if content == vim.NIL then
                return ""
            end
            return content
        end
    end

    return ""
end

openai.parse_sse_progress_event = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return nil
    end

    local decoded = safe_json_decode(line)
    if not decoded or type(decoded) ~= "table" then
        return nil
    end

    -- Chat Completions style: delta.tool_calls
    if type(decoded.choices) == "table" and type(decoded.choices[1]) == "table" then
        local delta = decoded.choices[1].delta
        if type(delta) == "table" and type(delta.reasoning_content) == "string" and delta.reasoning_content ~= "" then
            return make_progress_event(
                "reasoning_delta",
                "reasoning_content",
                nil,
                "reasoning",
                "reasoning",
                reasoning_progress_message(),
                delta.reasoning_content
            )
        end
        if type(delta) == "table" and type(delta.tool_calls) == "table" and type(delta.tool_calls[1]) == "table" then
            local call = delta.tool_calls[1]
            local fn = call["function"]
            local tool_name = nil
            local tool_text = nil
            if type(fn) == "table" and type(fn.name) == "string" and fn.name ~= "" then
                tool_name = fn.name
                if type(fn.arguments) == "string" and fn.arguments ~= "" then
                    tool_text = fn.arguments
                end
            elseif type(call.name) == "string" and call.name ~= "" then
                tool_name = call.name
            elseif call.type == "web_search" then
                tool_name = "web_search"
            end
            return make_progress_event(
                "tool_call_delta",
                "tool_calls_delta",
                tool_name,
                "tool_update",
                "tooling",
                tool_progress_message(tool_name),
                tool_text
            )
        end
    end

    -- Responses API style events (for future-compatible OpenAI streams)
    if type(decoded.type) ~= "string" then
        return nil
    end

    local event_type = decoded.type
    local item = decoded.item
    if type(item) ~= "table" then
        item = decoded.output_item
    end

    if event_type == "response.output_item.added" and type(item) == "table" then
        local item_type = item.type
        if item_type == "web_search_call" then
            local tool_text = pick_tool_detail_text(item)
            return make_progress_event(
                event_type,
                item_type,
                "web_search",
                "tool_start",
                "tooling",
                tool_progress_message("web_search"),
                tool_text
            )
        end
    end

    if event_type == "response.output_item.done" and type(item) == "table" then
        local item_type = item.type
        if item_type == "web_search_call" then
            local tool_text = pick_tool_detail_text(item)
            return make_progress_event(
                event_type,
                item_type,
                "web_search",
                "tool_result",
                "tooling",
                tool_result_message("web_search"),
                tool_text
            )
        end
    end

    return nil
end

openai.parse_usage = function(raw_response)
    local metrics = { input = nil, read = nil, creation = nil }

    if not raw_response:match('"usage"') then
        return metrics
    end

    -- Find the usage chunk: empty choices array with usage data
    local usage_json = nil
    for line in raw_response:gmatch("([^\n]+)") do
        if line:match('"usage"') and line:match('"choices":%s*%[%s*%]') then
            local clean_line = line:gsub("^data:%s*", "")
            -- Check for balanced braces
            local open_count, close_count = 0, 0
            for c in clean_line:gmatch(".") do
                if c == "{" then open_count = open_count + 1 end
                if c == "}" then close_count = close_count + 1 end
            end
            if open_count == close_count then
                usage_json = clean_line
                break
            end
        end
    end

    -- Fallback: match by structure
    if not usage_json then
        usage_json = raw_response:match('{"id":"[^"]*","object":"chat%.completion%.chunk"[^}]*"choices":%[%][^}]*"usage":{[^}]*}}')
    end

    -- Fallback: any line with usage
    if not usage_json then
        for line in raw_response:gmatch("([^\n]+)") do
            if line:match('"usage"') then
                local potential = line:match('({.-})')
                if potential then
                    usage_json = potential
                    break
                end
            end
        end
    end

    if not usage_json then
        return metrics
    end

    local decoded = safe_json_decode(usage_json)
    if decoded and type(decoded.usage) == "table" then
        metrics.input = tonumber(decoded.usage.prompt_tokens) or 0
        metrics.read = 0
        metrics.creation = 0

        if type(decoded.usage.prompt_tokens_details) == "table" then
            metrics.read = tonumber(decoded.usage.prompt_tokens_details.cached_tokens) or 0
        end
    else
        -- Crude extraction fallback
        local prompt_tokens = tonumber(usage_json:match('"prompt_tokens":%s*(%d+)'))
        local cached_tokens = tonumber(usage_json:match('"cached_tokens":%s*(%d+)'))
        if prompt_tokens then
            metrics.input = prompt_tokens
            metrics.read = cached_tokens or 0
            metrics.creation = 0
        end
    end

    return metrics
end

--------------------------------------------------------------------------------
-- Anthropic adapter
--------------------------------------------------------------------------------

local anthropic = {
    aliases = { "claude" },
    features = { web_search = true, cache_control = true },
    cache_metrics = { read = true, creation = true },
}

anthropic.format_payload = function(messages, model, _provider_name)
    -- Extract system messages into top-level system array
    local system_blocks = {}
    local i = 1
    while i <= #messages do
        if messages[i].role == "system" then
            local block = {
                type = "text",
                text = messages[i].content,
            }
            if messages[i].cache_control then
                block.cache_control = messages[i].cache_control
                logger.debug("Added cache_control to system block: " .. vim.inspect(messages[i].cache_control))
            end
            table.insert(system_blocks, block)
            table.remove(messages, i)
        else
            i = i + 1
        end
    end

    local params = provider_params.resolve_params("anthropic", model)
    local payload = {
        model = model.model,
        stream = true,
        messages = messages,
    }
    for k, v in pairs(params) do
        payload[k] = v
    end

    if #system_blocks > 0 then
        payload.system = system_blocks
    end

    -- Add Claude server-side web_search and web_fetch tools if enabled
    local parley = require("parley")
    if parley._state and parley._state.web_search then
        local web_search_overrides = provider_params.resolve_tool_overrides("anthropic", model, "web_search")
        local web_fetch_overrides = provider_params.resolve_tool_overrides("anthropic", model, "web_fetch")
        payload.tools = {
            vim.tbl_extend("force", {
                type = ANTHROPIC_WEB_SEARCH_TOOL_TYPE,
                name = "web_search",
                max_uses = 5,
            }, web_search_overrides),
            vim.tbl_extend("force", {
                type = ANTHROPIC_WEB_FETCH_TOOL_TYPE,
                name = "web_fetch",
                max_uses = 5,
            }, web_fetch_overrides),
        }
    end

    return payload
end

anthropic.format_headers = function(secret, _model, payload, endpoint)
    -- Choose anthropic-beta header based on tools in payload
    local beta_tag = "messages-2023-12-15"
    if payload and payload.tools then
        for _, tool in ipairs(payload.tools) do
            if tool.name == "web_fetch" then
                beta_tag = ANTHROPIC_WEB_FETCH_BETA_TAG
                break
            end
        end
    end
    local headers = {
        "-H",
        "x-api-key: " .. secret,
        "-H",
        "anthropic-version: 2023-06-01",
        "-H",
        "anthropic-beta: " .. beta_tag,
    }
    return headers, endpoint
end

anthropic.parse_sse_content = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return ""
    end

    if not line:match('"text":') then
        return ""
    end

    if line:match("content_block_start") or line:match("content_block_delta") then
        local decoded = safe_json_decode(line)
        if decoded then
            if decoded.delta and decoded.delta.text then
                return decoded.delta.text
            end
            if decoded.content_block and decoded.content_block.text then
                return decoded.content_block.text
            end
        end
    end

    return ""
end

anthropic.parse_sse_progress_event = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return nil
    end

    local decoded = safe_json_decode(line)
    if not decoded or type(decoded) ~= "table" then
        return nil
    end

    if decoded.type == "content_block_delta" and type(decoded.delta) == "table" then
        local delta_type = decoded.delta.type
        if delta_type == "thinking_delta" and type(decoded.delta.thinking) == "string" and decoded.delta.thinking ~= "" then
            return make_progress_event(
                "content_block_delta",
                delta_type,
                nil,
                "reasoning",
                "reasoning",
                reasoning_progress_message(),
                decoded.delta.thinking
            )
        end
        if delta_type == "input_json_delta" and type(decoded.delta.partial_json) == "string" and decoded.delta.partial_json ~= "" then
            return make_progress_event(
                "content_block_delta",
                delta_type,
                nil,
                "tool_update",
                "tooling",
                tool_progress_message(nil),
                decoded.delta.partial_json
            )
        end
    end

    if decoded.type ~= "content_block_start" then
        return nil
    end

    local block = decoded.content_block
    if type(block) ~= "table" then
        return nil
    end

    local block_type = block.type
    if type(block_type) ~= "string" or block_type == "" then
        return nil
    end

    local tool_name = type(block.name) == "string" and block.name or nil
    local progress_text = nil
    local message
    local kind = "tool_update"
    if block_type == "tool_use" or block_type == "server_tool_use" then
        message = tool_progress_message(tool_name)
        kind = "tool_start"
        progress_text = pick_tool_detail_text(block.input)
    elseif block_type == "web_search_tool_result" then
        message = tool_result_message("web_search")
        kind = "tool_result"
    elseif block_type == "web_fetch_tool_result" then
        message = tool_result_message("web_fetch")
        kind = "tool_result"
    elseif block_type == "thinking" then
        message = reasoning_progress_message()
        kind = "reasoning"
        if type(block.thinking) == "string" and block.thinking ~= "" then
            progress_text = block.thinking
        end
    elseif block_type:find("tool", 1, true) then
        message = "Processing " .. block_type .. "..."
    else
        return nil
    end

    return make_progress_event(
        "content_block_start",
        block_type,
        tool_name,
        kind,
        kind == "reasoning" and "reasoning" or "tooling",
        message,
        progress_text
    )
end

anthropic.parse_usage = function(raw_response)
    local metrics = { input = nil, read = nil, creation = nil }

    local success, decoded = false, nil

    -- Strategy 1: Find "message_delta" with usage
    for line in raw_response:gmatch("[^\n]+") do
        if line:match('"type"%s*:%s*"message_delta"') and line:match('"usage"') then
            local json_str = line:gsub("^data:%s*", "")
            decoded = safe_json_decode(json_str)
            if decoded and decoded.usage then
                success = true
                break
            end
        end
    end

    -- Strategy 2: Match any complete JSON object with usage
    if not success then
        local clean_json = raw_response:match("{.-usage.-}")
        if clean_json then
            decoded = safe_json_decode(clean_json)
            if decoded and decoded.usage then
                success = true
            end
        end
    end

    -- Strategy 3: Extract just the usage object
    if not success then
        local usage_json = raw_response:match('("usage":%s*{[^{}]*})')
        if usage_json then
            usage_json = "{" .. usage_json .. "}"
            decoded = safe_json_decode(usage_json)
            if decoded and decoded.usage then
                success = true
            end
        end
    end

    if success and decoded and decoded.usage then
        metrics.input = decoded.usage.input_tokens or 0
        metrics.creation = decoded.usage.cache_creation_input_tokens or 0
        metrics.read = decoded.usage.cache_read_input_tokens or 0
        logger.debug("Anthropic metrics extracted: input=" .. metrics.input ..
            ", creation=" .. metrics.creation ..
            ", read=" .. metrics.read)
    else
        logger.debug("Anthropic usage extraction failed - no metrics found")
    end

    return metrics
end

--------------------------------------------------------------------------------
-- Google AI adapter
--------------------------------------------------------------------------------

local googleai = {
    aliases = {},
    features = { web_search = true },
    cache_metrics = { read = false, creation = false },
}

googleai.format_payload = function(messages, model, _provider_name)
    -- Convert roles and message format
    for i, message in ipairs(messages) do
        if message.role == "system" then
            messages[i].role = "user"
        end
        if message.role == "assistant" then
            messages[i].role = "model"
        end
        if message.content then
            messages[i].parts = {
                { text = message.content },
            }
            messages[i].content = nil
        end
    end

    -- Merge consecutive same-role messages (Google API requirement)
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

    -- Add Google Search grounding tool if enabled
    local parley = require("parley")
    if parley._state and parley._state.web_search then
        payload.tools = { { google_search = vim.empty_dict() } }
    end

    return payload
end

googleai.format_headers = function(secret, _model, payload, endpoint)
    endpoint = render.template_replace(endpoint, "{{secret}}", secret)
    endpoint = render.template_replace(endpoint, "{{model}}", payload.model)
    payload.model = nil
    return {}, endpoint
end

googleai.parse_sse_content = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return ""
    end

    if not line:match('"text":') then
        return ""
    end

    local decoded = safe_json_decode("{" .. line .. "}")
    if decoded and decoded.text then
        return decoded.text
    end

    return ""
end

googleai.parse_sse_progress_event = function(line)
    line = strip_data_prefix(line)
    if line == "" or line == "[DONE]" then
        return nil
    end

    -- Keep progress parsing lightweight and fragment-based only.
    -- Do not decode full payload blobs here to avoid impacting main content flow.
    local query = nil
    local query_array = line:match('"webSearchQueries"%s*:%s*(%b[])')
    if query_array then
        for candidate in query_array:gmatch('"(.-)"') do
            if candidate ~= "" then
                query = candidate
                break
            end
        end
    end
    if not query then
        local escaped_query_array = line:match('\\"webSearchQueries\\"%s*:%s*(%b[])')
        if escaped_query_array then
            for candidate in escaped_query_array:gmatch('\\"(.-)\\"') do
                if candidate ~= "" then
                    query = candidate
                    break
                end
            end
        end
    end
    -- Intentionally surface the first non-empty query as a compact cue.
    if query and query ~= "" then
        return make_progress_event(
            "grounding_metadata",
            "web_search_queries",
            "web_search",
            "tool_update",
            "tooling",
            tool_progress_message("web_search"),
            query
        )
    end

    local uri = line:match('"uri"%s*:%s*"([^"]+)"') or line:match('\\"uri\\"%s*:%s*\\"([^"]+)\\"')
    if uri and uri ~= "" then
        return make_progress_event(
            "grounding_metadata",
            "grounding_uri",
            "web_search",
            "tool_update",
            "tooling",
            tool_result_message("web_search"),
            uri
        )
    end

    if line:match('"groundingMetadata"%s*:') or line:match('"searchEntryPoint"%s*:')
        or line:match('\\"groundingMetadata\\"%s*:') or line:match('\\"searchEntryPoint\\"%s*:') then
        return make_progress_event(
            "grounding_metadata",
            "grounding",
            "web_search",
            "tool_start",
            "tooling",
            tool_progress_message("web_search")
        )
    end

    return nil
end

googleai.parse_usage = function(raw_response)
    local metrics = { input = nil, read = nil, creation = nil }

    local usage_pattern = '"usageMetadata":%s*{[^}]*"promptTokenCount":%s*(%d+)[^}]*"candidatesTokenCount":%s*(%d+)[^}]*"totalTokenCount":%s*(%d+)[^}]*'
    local prompt_tokens, _, _ = raw_response:match(usage_pattern)

    if prompt_tokens then
        metrics.input = tonumber(prompt_tokens) or 0
        metrics.read = 0
        metrics.creation = 0
        logger.debug("Gemini metrics extracted: input=" .. metrics.input)
    else
        -- Try escaped pattern
        local escaped_pattern = '\\\"usageMetadata\\\":%s*{[^}]*\\\"promptTokenCount\\\":%s*(%d+)[^}]*\\\"candidatesTokenCount\\\":%s*(%d+)[^}]*\\\"totalTokenCount\\\":%s*(%d+)[^}]*'
        prompt_tokens, _, _ = raw_response:match(escaped_pattern)
        if prompt_tokens then
            metrics.input = tonumber(prompt_tokens) or 0
            metrics.read = 0
            metrics.creation = 0
        end
    end

    return metrics
end

--------------------------------------------------------------------------------
-- Copilot adapter (extends openai)
--------------------------------------------------------------------------------

local copilot = {
    aliases = {},
    features = {},
    cache_metrics = { read = true, creation = false },
}

copilot.format_payload = function(messages, model, _provider_name)
    -- Rewrite model name for copilot
    if model.model == "gpt-4o" then
        model.model = "gpt-4o-2024-05-13"
    end
    return openai.format_payload(messages, model, "copilot")
end

copilot.format_headers = function(secret, _model, _payload, endpoint)
    local headers = {
        "-H",
        "editor-version: vscode/1.85.1",
        "-H",
        "Authorization: Bearer " .. secret,
    }
    return headers, endpoint
end

copilot.parse_sse_content = openai.parse_sse_content
copilot.parse_sse_progress_event = openai.parse_sse_progress_event
copilot.parse_usage = openai.parse_usage

-- Copilot needs a pre-query step to refresh its bearer token
copilot.pre_query = function(callback)
    local vault = require("parley.vault")
    vault.refresh_copilot_bearer(callback)
end

-- Copilot uses a different secret name
copilot.secret_name = "copilot_bearer"

--------------------------------------------------------------------------------
-- CLIProxyAPI adapter (OpenAI-compatible proxy)
--------------------------------------------------------------------------------

local cliproxyapi = {
    aliases = { "cliproxy" },
    features = {},
    cache_metrics = { read = true, creation = false },
}

local function cliproxy_openai_payload(messages, model, strategy)
    local model_name = model.model
    local parley = require("parley")
    local web_search_enabled = parley._state and parley._state.web_search
    if strategy == "openai_search_model" and web_search_enabled and model.search_model then
        model_name = model.search_model
    end

    local param_model = vim.tbl_extend("force", model, { model = model_name })
    local params = provider_params.resolve_params("cliproxyapi", param_model)

    local output = {
        model = model_name,
        stream = true,
        messages = messages,
        stream_options = {
            include_usage = true,
        },
    }
    for k, v in pairs(params) do
        output[k] = v
    end
    if web_search_enabled and strategy == "openai_tools_route" then
        output.tools = {
            { type = "web_search" },
        }
        output.tool_choice = "auto"
    end

    return output
end

cliproxyapi.format_payload = function(messages, model, _provider_name)
    local strategy = get_cliproxy_strategy(model)
    local model_name = type(model) == "table" and model.model or nil
    local use_anthropic_route = is_cliproxy_anthropic_route_model(model_name)
    local use_code_execution_model = type(model_name) == "string" and model_name:find("^code_execution_") ~= nil

    if strategy == "anthropic_tools_route" and use_anthropic_route then
        local parley = require("parley")
        local payload = anthropic.format_payload(messages, model, "anthropic")
        -- CLIProxy may require direct tool callers for model-invoked web tools.
        -- Set allowed_callers on web tools to keep model-side calls valid.
        if parley._state and parley._state.web_search and payload.tools then
            for _, tool in ipairs(payload.tools) do
                if (tool.name == "web_search" or tool.name == "web_fetch") and tool.allowed_callers == nil then
                    tool.allowed_callers = { "direct" }
                end
            end
            -- For code_execution models, require explicit web_search tool invocation.
            if use_code_execution_model then
                payload.tool_choice = { type = "tool", name = "web_search" }
            end
        end
        payload._parley_route = "anthropic"
        return payload
    end

    return cliproxy_openai_payload(messages, model, strategy)
end

cliproxyapi.format_headers = function(secret, model, payload, endpoint)
    local route = payload and payload._parley_route or "openai"
    if payload then
        payload._parley_route = nil
    end

    if route == "anthropic" then
        return anthropic.format_headers(secret, model, payload, cliproxy_anthropic_endpoint(endpoint))
    end

    return openai.format_headers(secret, model, payload, endpoint)
end

cliproxyapi.parse_sse_content = function(line)
    local content = openai.parse_sse_content(line)
    if content ~= "" then
        return content
    end
    return anthropic.parse_sse_content(line)
end

cliproxyapi.parse_sse_progress_event = function(line)
    -- For anthropic_tools_route, progress events are anthropic SSE messages.
    -- For OpenAI route/search model, progress events are OpenAI-style SSE messages.
    -- Progress parsing is stateless and does not receive model context here;
    -- intentionally use config-level strategy fallback.
    local strategy = get_cliproxy_strategy(nil)
    if strategy == "anthropic_tools_route" then
        return anthropic.parse_sse_progress_event(line)
    end
    local event = openai.parse_sse_progress_event(line)
    if event then
        return event
    end
    return anthropic.parse_sse_progress_event(line)
end

cliproxyapi.parse_usage = function(raw_response)
    local metrics = openai.parse_usage(raw_response)
    if metrics.input ~= nil then
        return metrics
    end
    return anthropic.parse_usage(raw_response)
end

--------------------------------------------------------------------------------
-- Azure adapter (extends openai)
--------------------------------------------------------------------------------

local azure = {
    aliases = {},
    features = {},
    cache_metrics = { read = false, creation = false },
}

azure.format_payload = openai.format_payload

azure.format_headers = function(secret, _model, payload, endpoint)
    local headers = {
        "-H",
        "api-key: " .. secret,
    }
    endpoint = render.template_replace(endpoint, "{{model}}", payload.model)
    return headers, endpoint
end

azure.parse_sse_content = openai.parse_sse_content
azure.parse_sse_progress_event = openai.parse_sse_progress_event
azure.parse_usage = openai.parse_usage

--------------------------------------------------------------------------------
-- Ollama adapter (extends openai, but no stream_options and different usage)
--------------------------------------------------------------------------------

local ollama = {
    aliases = {},
    features = {},
    cache_metrics = { read = false, creation = false },
}

ollama.format_payload = function(messages, model, _provider_name)
    local params = provider_params.resolve_params("ollama", model)
    local output = {
        model = model.model,
        stream = true,
        messages = messages,
        -- Note: Ollama does NOT support stream_options.include_usage
    }
    for k, v in pairs(params) do
        output[k] = v
    end
    return output
end

ollama.format_headers = function(secret, _model, _payload, endpoint)
    local headers = {
        "-H",
        "Authorization: Bearer " .. secret,
    }
    return headers, endpoint
end

ollama.parse_sse_content = openai.parse_sse_content
ollama.parse_sse_progress_event = openai.parse_sse_progress_event

ollama.parse_usage = function(raw_response)
    local metrics = { input = nil, read = nil, creation = nil }

    if not raw_response:match('"usage"') then
        return metrics
    end

    -- Ollama embeds usage in the final chunk (which still has choices, unlike OpenAI)
    for line in raw_response:gmatch("([^\n]+)") do
        if line:match('"usage"') and line:match('"finish_reason"') then
            local clean_line = line:gsub("^data:%s*", "")
            local decoded = safe_json_decode(clean_line)
            if decoded and type(decoded.usage) == "table" then
                metrics.input = tonumber(decoded.usage.prompt_tokens) or 0
                metrics.read = 0
                metrics.creation = 0
                return metrics
            end
        end
    end

    -- Fallback: try same as OpenAI (in case Ollama behavior changes)
    return openai.parse_usage(raw_response)
end

--------------------------------------------------------------------------------
-- Provider registry
--------------------------------------------------------------------------------

local registry = {
    openai = openai,
    anthropic = anthropic,
    googleai = googleai,
    copilot = copilot,
    cliproxyapi = cliproxyapi,
    azure = azure,
    ollama = ollama,
}

-- Build alias lookup
local alias_map = {}
for name, adapter in pairs(registry) do
    if adapter.aliases then
        for _, alias in ipairs(adapter.aliases) do
            alias_map[alias] = name
        end
    end
end

--- Get a provider adapter by name (resolves aliases).
--- Falls back to a default OpenAI-compatible adapter for unknown providers.
---@param name string
---@return table adapter
M.get = function(name)
    local resolved = alias_map[name] or name
    local adapter = registry[resolved]
    if adapter then
        return adapter
    end

    -- Unknown provider: fall back to openai-compatible behavior
    logger.debug("Unknown provider '" .. name .. "', falling back to OpenAI-compatible adapter")
    return openai
end

--- Resolve a provider name through aliases.
---@param name string
---@return string canonical provider name
M.resolve_name = function(name)
    return alias_map[name] or name
end

--- Check if a provider supports a specific feature.
---@param name string provider name
---@param feature string feature name (e.g., "web_search", "cache_control")
---@param model_config table|nil
---@return boolean
M.has_feature = function(name, feature, model_config)
    local resolved = M.resolve_name(name)
    if resolved == "cliproxyapi" and feature == "web_search" then
        local strategy = get_cliproxy_strategy(model_config)
        if strategy == "none" then
            return false
        end
        if strategy == "anthropic_tools_route" then
            local model_name = type(model_config) == "table" and model_config.model or nil
            return is_cliproxy_anthropic_route_model(model_name)
        end
        return true
    end
    local adapter = M.get(name)
    return adapter.features and adapter.features[feature] == true
end

--- Resolve provider/model-specific web search strategy.
---@param name string provider name
---@param model_config table|nil
---@return string|nil
M.get_web_search_strategy = function(name, model_config)
    local resolved = M.resolve_name(name)
    if resolved ~= "cliproxyapi" then
        return nil
    end
    return get_cliproxy_strategy(model_config)
end

--- Get cache metrics display config for a provider.
---@param name string provider name
---@return table {read = bool, creation = bool}
M.get_cache_metrics_config = function(name)
    local adapter = M.get(name)
    return adapter.cache_metrics or { read = false, creation = false }
end

--- Get the secret name for a provider (usually the provider name itself).
---@param name string provider name
---@return string secret name
M.get_secret_name = function(name)
    local adapter = M.get(name)
    return adapter.secret_name or name
end

--------------------------------------------------------------------------------
-- Tool-use encoders (issue #81 M1)
--
-- These are pure table-transformation helpers that convert parley's
-- provider-agnostic internal ToolDefinition shape into the wire format
-- each provider expects in its `tools` request field. Only Anthropic
-- is implemented in v1; OpenAI / Google / Ollama stubs raise a clear
-- "not yet implemented" error so tool-enabled agents fail fast.
--
-- Convention: the dispatcher's prepare_payload APPENDS the result of
-- these encoders onto any existing `payload.tools` (e.g. server-side
-- web_search / web_fetch already populated by existing code paths).
-- See dispatcher.lua for the append logic.
--------------------------------------------------------------------------------

--- Convert a list of parley ToolDefinitions into the Anthropic payload
--- shape for the `tools` array. Each entry contains only the fields
--- Anthropic cares about: name, description, input_schema. Internal
--- fields (handler, kind, needs_backup) are intentionally dropped.
---
--- Pure. Accepts nil or empty list and returns an empty table.
---@param tool_definitions ToolDefinition[]|nil
---@return table[] anthropic_tools
function M.anthropic_encode_tools(tool_definitions)
    local out = {}
    for _, def in ipairs(tool_definitions or {}) do
        table.insert(out, {
            name = def.name,
            description = def.description,
            input_schema = def.input_schema,
        })
    end
    return out
end

--- OpenAI tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.openai_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- Google AI tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.googleai_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- Ollama tool encoder — stub that raises. Deferred to a #81 follow-up.
---@diagnostic disable-next-line: unused-local
function M.ollama_encode_tools(_tool_definitions)
    error("tools not supported for this provider yet — see #81 follow-up")
end

--- CLIProxyAPI tool encoder — delegates to the Anthropic encoder only
--- when the target model name begins with "claude-" (i.e. routed to
--- an Anthropic-family model). Otherwise raises with an
--- anthropic-family-only message so the error is specific and actionable.
---@param tool_definitions ToolDefinition[]
---@param model_name string|table the model name (or table containing .model)
function M.cliproxyapi_encode_tools(tool_definitions, model_name)
    local name = type(model_name) == "table" and model_name.model or model_name
    if type(name) ~= "string" or not name:match("^claude%-") then
        error("tools not supported for this provider yet — cliproxyapi requires an anthropic-family model (see #81 follow-up)")
    end
    return M.anthropic_encode_tools(tool_definitions)
end

return M
