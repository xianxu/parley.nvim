--------------------------------------------------------------------------------
-- Tool wire registry (#198).
--
-- Resolves a provider (and its model) to the module that owns that
-- provider family's client-side tool protocol, then forwards the four
-- operations every consumer needs. This is the single seam the dispatcher,
-- the tool loop, and skill invocation consume — before it existed, each of
-- them hardcoded the Anthropic wire at its own call site and the dispatcher
-- carried a five-branch provider chain (ARCH-DRY).
--
-- THE PUBLIC API TAKES A MODEL, NOT A ROUTE.
--
-- cliproxyapi speaks both wires: it proxies anthropic-family models to a
-- real Anthropic endpoint and everything else to an OpenAI-compatible one.
-- Which wire a request uses is therefore a function of the model, and an API
-- that asked callers for a "route" would be an API a caller can forget to
-- pass. A forgotten route resolves to *some* wire and then quietly decodes
-- zero tool calls — indistinguishable, downstream, from a model that simply
-- did not call a tool. Deriving the route in here makes that unrepresentable.
--
-- Adding a wire (googleai's functionDeclarations is the obvious next one)
-- means writing the module and adding one line to BY_PROVIDER.
--
-- PURE: no IO, no Neovim state.
--------------------------------------------------------------------------------

local wire_anthropic = require("parley.tools.wire_anthropic")
local wire_openai = require("parley.tools.wire_openai")

local M = {}

-- googleai is deliberately ABSENT rather than mapped to nil: it needs a
-- genuinely different shape (functionDeclarations), so callers get the
-- documented no-wire behaviour until someone writes it.
local BY_PROVIDER = {
    anthropic = wire_anthropic,
    openai = wire_openai,
    copilot = wire_openai,
    azure = wire_openai,
    ollama = wire_openai,
}

local BY_NAME = {
    anthropic = wire_anthropic,
    openai = wire_openai,
}

--- Look a wire up by the name `name_for` produced.
---
--- Exists for the response side: by the time a stream comes back, the model
--- table is long gone (the dispatcher's query table carries the provider and
--- the serialized payload, not the agent's model params). prepare_payload
--- stamps `name_for`'s answer onto the payload, query strips it onto the query
--- table, and the read paths resolve through here — so request and response
--- are guaranteed to agree on the wire without re-deriving it from partial
--- information. Re-deriving from the payload's bare model NAME would silently
--- lose an agent's `anthropic_tools_route` override.
---@param name string|nil
---@return table|nil
function M.by_name(name)
    return BY_NAME[name]
end

--- The name of the wire this (provider, model) pair speaks.
---@param provider string|nil
---@param model table|string|nil
---@return "anthropic"|"openai"|nil
function M.name_for(provider, model)
    local w = M.resolve(provider, model)
    if w == wire_anthropic then return "anthropic" end
    if w == wire_openai then return "openai" end
    return nil
end

--- Did this response carry a client tool call, given a stamped wire name?
--- Degrades to false for an unknown name, same reasoning as `has_tool_calls`.
---@param name string|nil
---@param raw_response string
---@return boolean
function M.has_tool_calls_by_name(name, raw_response)
    local w = M.by_name(name)
    if not w then
        return false
    end
    return w.has_tool_calls(raw_response)
end

--- Decode tool calls given a stamped wire name. Degrades to an empty list.
---@param name string|nil
---@param raw_response string
---@return ToolCall[]
function M.decode_by_name(name, raw_response)
    local w = M.by_name(name)
    if not w then
        return {}
    end
    return w.decode_tool_calls_from_stream(raw_response)
end

--- Which wire does this (provider, model) pair speak?
---@param provider string|nil
---@param model table|string|nil  model params table, or a bare model name
---@return table|nil wire module, or nil when the provider has no wire
function M.resolve(provider, model)
    if provider == "cliproxyapi" then
        local providers = require("parley.providers")
        local model_name = type(model) == "table" and model.model or model
        local strategy = providers.cliproxy_strategy(type(model) == "table" and model or nil)
        if providers.cliproxy_route(model_name, strategy) == "anthropic" then
            return wire_anthropic
        end
        return wire_openai
    end
    return BY_PROVIDER[provider]
end

--- Encode tool definitions for the wire this request will use.
---
--- RAISES when the provider has no wire. Unlike the read paths below, this
--- runs only when an agent actually declared tools, so a missing wire means
--- a real misconfiguration — and failing at request-build time, naming the
--- provider, beats silently sending no tools (which reads downstream as the
--- model choosing not to call one).
---@param provider string
---@param model table|string|nil
---@param tool_definitions ToolDefinition[]
---@return table[]
function M.encode(provider, model, tool_definitions)
    local w = M.resolve(provider, model)
    if not w then
        error("tools are not supported for provider: " .. tostring(provider))
    end
    return w.encode_tools(tool_definitions)
end

--- Encode a forced tool choice for the wire this request will use.
--- Raises for the same reason `encode` does.
---@param provider string
---@param model table|string|nil
---@param tool_name string
---@return table
function M.encode_tool_choice(provider, model, tool_name)
    local w = M.resolve(provider, model)
    if not w then
        error("tool_choice is not supported for provider: " .. tostring(provider))
    end
    return w.encode_tool_choice(tool_name)
end

--- Extract tool calls from a completed streamed response.
--- Degrades to an empty list for a provider with no wire: this runs on every
--- response, including from agents that declared no tools at all.
---@param provider string|nil
---@param model table|string|nil
---@param raw_response string
---@return ToolCall[]
function M.decode(provider, model, raw_response)
    local w = M.resolve(provider, model)
    if not w then
        return {}
    end
    return w.decode_tool_calls_from_stream(raw_response)
end

--- Did this response carry a client tool call? Degrades to false, same
--- reasoning as `decode`.
---@param provider string|nil
---@param model table|string|nil
---@param raw_response string
---@return boolean
function M.has_tool_calls(provider, model, raw_response)
    local w = M.resolve(provider, model)
    if not w then
        return false
    end
    return w.has_tool_calls(raw_response)
end

--- Translate parley's internal (Anthropic-shaped) messages into the wire's
--- own shape. Identity for wires whose shape already matches — only
--- wire_openai defines `translate_messages`, so this is a capability check
--- rather than a per-provider branch.
---@param provider string|nil
---@param model table|string|nil
---@param messages table[]
---@return table[]
function M.translate_messages(provider, model, messages)
    local w = M.resolve(provider, model)
    if not w or type(w.translate_messages) ~= "function" then
        return messages
    end
    return w.translate_messages(messages)
end

return M
