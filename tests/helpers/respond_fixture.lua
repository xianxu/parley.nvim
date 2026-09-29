-- The stateful dispatcher double shared by the chat-respond integration specs.
-- Each query is recorded with its callbacks and stays `running` until the spec
-- completes or aborts it; stop_owner aborts the owner's running calls on the
-- next turn, as the real transport does.
--
--   local calls, restore = Fixture.install(parley)
--   ... calls[i].payload, calls[i].output(id, bytes), calls[i].complete(id) ...
--   restore()  -- aborts what is still running and puts the transport back
local M = {}

--- The one `tasker.stop_owner` double (#261 M4 review I1). Like the real one it
--- returns how many running calls it stopped, which the provider adapter reads
--- (a cancel that stopped nothing resolves at once, W5). This fixture registers
--- calls synchronously, so no chat spec reaches that branch — it is pinned in
--- response_provider_spec; the count keeps the double faithful. The abort
--- arrives on the next turn, as the real transport's does.
---@param calls table # the recorded calls; each has `opts.generation_id`, `running`, `abort`
function M.stop_owner(calls)
    return function(owner)
        local stopped = 0
        for _, call in ipairs(calls) do
            if call.running ~= false and call.opts and call.opts.generation_id == owner then
                call.running = false; stopped = stopped + 1
                vim.schedule(function() call.abort('cancelled') end)
            end
        end
        return stopped
    end
end

function M.install(parley)
    local calls = {}
    local old_query, old_stop = parley.dispatcher.query, parley.tasker.stop_owner
    parley.dispatcher.query = function(b, provider, payload, output, complete, _, _, abort, model, failure, opts)
        local id = 'session-fixture:' .. #calls
        local call = { id = id, buf = b, provider = provider, model = model, payload = payload, output = output,
            complete = complete, abort = abort, failure = failure, opts = opts, running = true }
        calls[#calls + 1] = call
        parley.tasker.set_query(id, { buf = b, response = '', raw_response = '',
            tool_wire = provider == 'openai' and 'openai' or 'anthropic' })
        return id
    end
    parley.tasker.stop_owner = M.stop_owner(calls)
    local function restore()
        for _, call in ipairs(calls) do call.abort('fixture cleanup') end
        parley.dispatcher.query, parley.tasker.stop_owner = old_query, old_stop
    end
    return calls, restore
end

--- An Anthropic SSE body in which the model calls `read_file` on `path` and
--- stops for tool use. `text`, when given, is prose streamed before the call.
--- Set it as the call's `raw_response` before completing the call.
---@param id string # tool_use id
---@param path string
---@param text? string
function M.tool_use_sse(id, path, text)
    local events = { { type = 'message_start', message = { id = 'msg_test', model = 'claude-sonnet-5' } } }
    local index = 0
    if text then
        vim.list_extend(events, {
            { type = 'content_block_start', index = 0, content_block = { type = 'text', text = '' } },
            { type = 'content_block_delta', index = 0, delta = { type = 'text_delta', text = text } },
            { type = 'content_block_stop', index = 0 } })
        index = 1
    end
    vim.list_extend(events, {
        { type = 'content_block_start', index = index, content_block = { type = 'tool_use', id = id, name = 'read_file', input = {} } },
        { type = 'content_block_delta', index = index, delta = { type = 'input_json_delta', partial_json = '{"path":"' .. path .. '"}' } },
        { type = 'content_block_stop', index = index },
        { type = 'message_delta', delta = { stop_reason = 'tool_use' } },
        { type = 'message_stop' },
    })
    local lines = {}
    for _, ev in ipairs(events) do
        lines[#lines + 1] = 'event: ' .. ev.type; lines[#lines + 1] = 'data: ' .. vim.json.encode(ev); lines[#lines + 1] = ''
    end
    return table.concat(lines, '\n')
end

return M
