-- The event vocabulary each provider's decoders read (#242). ONE list, asserted
-- twice: the fake's unit spec (sse_dialects_spec) checks the fake emits every
-- entry, and the live conformance spec checks the real API still does, so the
-- fake and the service are compared on the same terms.
local M = {}

-- anthropic: providers.lua parse_sse_content/progress/usage and
-- tools/wire_anthropic.lua decode_tool_calls_from_stream.
M.anthropic = {
    text = { '"type":"message_start"', '"type":"content_block_start"', '"type":"content_block_delta"',
        '"type":"text_delta"', '"type":"content_block_stop"', '"type":"message_delta"', '"stop_reason"',
        '"type":"message_stop"' },
    tool_use = { '"type":"tool_use"', '"type":"input_json_delta"', '"partial_json"', '"stop_reason":"tool_use"' },
}

return M
