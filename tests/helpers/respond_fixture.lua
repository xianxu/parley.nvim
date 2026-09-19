-- The stateful dispatcher double shared by the chat-respond integration specs.
-- Each query is recorded with its callbacks and stays `running` until the spec
-- completes or aborts it; stop_owner aborts the owner's running calls on the
-- next turn, as the real transport does.
--
--   local calls, restore = Fixture.install(parley)
--   ... calls[i].payload, calls[i].output(id, bytes), calls[i].complete(id) ...
--   restore()  -- aborts what is still running and puts the transport back
local M = {}

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
    parley.tasker.stop_owner = function(owner)
        for _, call in ipairs(calls) do
            if call.running and call.opts.generation_id == owner then
                call.running = false; vim.schedule(function() call.abort('cancelled') end)
            end
        end
    end
    local function restore()
        for _, call in ipairs(calls) do call.abort('fixture cleanup') end
        parley.dispatcher.query, parley.tasker.stop_owner = old_query, old_stop
    end
    return calls, restore
end

return M
