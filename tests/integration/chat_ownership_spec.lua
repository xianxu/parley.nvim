-- Production response lifecycle with a stateful, manually driven transport.
local parley = require("parley")
local pending = require("parley.chat_pending")
local root = vim.fn.tempname() .. "-ownership"
vim.fn.mkdir(root, "p")
parley.setup({
    chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {},
    default_agent = "OwnershipFixture",
    agents = {
        { name = "Choose a model", disable = true },
        { name = "OwnershipFixture", provider = "anthropic",
          model = { model = "fixture" }, system_prompt = "Fixture", tools = {} },
    },
})

local function text(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function settle(predicate)
    assert.is_true(vim.wait(1500, predicate, 5), "scheduled response did not settle")
end

describe("chat ownership containment", function()
    local old_query, old_stop, old_stop_owner, buffers, calls
    local old_runtime, process_state
    local sequence = 0

    before_each(function()
        buffers, calls = {}, {}
        old_runtime, process_state = parley.tasker._uv, nil
        old_query, old_stop, old_stop_owner = parley.dispatcher.query, parley.tasker.stop, parley.tasker.stop_owner
        parley.dispatcher.query = function(buf, _, _, handler, completion, _, _, _, _, _, opts)
            local id = "ownership-" .. tostring(#calls + 1)
            local call = { buf = buf, id = id, owner = opts and opts.generation_id or id,
                handler = handler, complete = completion, running = true }
            calls[#calls + 1] = call
            parley.tasker.set_query(id, { buf = buf, response = "Generated answer" })
        end
        parley.tasker.stop = function()
            for _, call in ipairs(calls) do call.running = false end
        end
        parley.tasker.stop_owner = function(owner)
            for _, call in ipairs(calls) do
                if call.owner == owner then call.running = false end
            end
        end
    end)

    after_each(function()
        pending.cancel_all("fixture cleanup")
        if process_state then
            for _, process in pairs(process_state.processes) do process:finish() end
            settle(function() return #parley.tasker._handles == 0 end)
        end
        parley.tasker._uv = old_runtime
        parley.dispatcher.query, parley.tasker.stop, parley.tasker.stop_owner = old_query, old_stop, old_stop_owner
        for _, buf in ipairs(buffers) do
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end
    end)

    local function start(topic)
        sequence = sequence + 1
        local file = root .. ("/2026-09-14.12-00-%02d.001_fixture.md"):format(sequence)
        vim.fn.writefile({ "# topic: " .. (topic or "Ownership fixture"), "- file: fixture.md", "---", "", "💬: First question", "" }, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        local buf = vim.api.nvim_get_current_buf()
        buffers[#buffers + 1] = buf
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        parley.chat_respond({ range = 0 })
        settle(function() return calls[#calls] and calls[#calls].buf == buf end)
        local call = calls[#calls]
        call.handler(call.id, "Generated answer")
        settle(function() return text(buf):find("Generated answer", 1, true) ~= nil end)
        return buf, call
    end

    it("preserves a question typed ahead through completion without adding a duplicate prompt", function()
        local buf, call = start()
        local tail = { "", "💬: My next question", "still composing" }
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, tail)
        call.complete(call.id)
        settle(function() return pending.identity(buf) == nil end)
        local result = text(buf)
        assert.is_truthy(result:find(table.concat(tail, "\n"), 1, true), result)
        local _, questions = result:gsub("💬:", "")
        assert.equals(2, questions, "completion must not add another prompt after typing ahead")
    end)

    it("preserves non-marker human text appended before completion", function()
        local buf, call = start()
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "unfinished human text" })
        call.complete(call.id)
        settle(function() return pending.identity(buf) == nil end)
        assert.is_truthy(text(buf):find("unfinished human text", 1, true))
    end)

    it("a deleted answer's late chunk cancels its owner without stopping another chat", function()
        local first, a = start()
        local second, b = start()
        for row, line in ipairs(vim.api.nvim_buf_get_lines(first, 0, -1, false)) do
            if line:find("🤖:", 1, true) then
                vim.api.nvim_buf_set_lines(first, row - 1, row, false, {})
                break
            end
        end
        a.handler(a.id, "late")
        settle(function() return pending.identity(first) == nil end)
        assert.is_false(a.running, "deleted answer must cancel its transport owner")
        assert.is_true(b.running, "unrelated chat transport must remain running")
        b.handler(b.id, " survives")
        settle(function() return text(second):find(" survives", 1, true) ~= nil end)
    end)

    for _, invalidation in ipairs({ "answer header", "buffer" }) do
    it("cancels automatic topic after deleting its " .. invalidation .. " and preserves another owner", function()
        local runtime
        runtime, process_state = require("tests.helpers.fake_process").new()
        parley.tasker._uv = runtime
        parley.tasker.stop_owner = old_stop_owner
        parley.dispatcher.query = function(buf, _, _, handler, completion, _, _, _, _, _, opts)
            local id = "topic-ownership-" .. tostring(#calls + 1)
            calls[#calls + 1] = { buf = buf, id = id, handler = handler, complete = completion }
            parley.tasker.set_query(id, { buf = buf, response = "Generated answer" })
            local run_opts = vim.tbl_extend("force", {}, opts or {}, { query_id = id })
            parley.tasker.run(buf, "fixture", {}, function() completion(id) end,
                nil, nil, nil, run_opts)
        end
        local first = start("?")
        local existing_buffers = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do existing_buffers[buf] = true end
        process_state.processes[4242]:finish()
        settle(function() return process_state.spawn_calls == 2 end)
        local topic_buffer
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if not existing_buffers[buf] then
                assert.is_nil(topic_buffer, "one scratch buffer belongs to the topic request")
                topic_buffer = buf
            end
        end
        assert.is_not_nil(topic_buffer)
        local second = start()
        if invalidation == "buffer" then
            vim.api.nvim_buf_delete(first, { force = true })
        else
            for row, line in ipairs(vim.api.nvim_buf_get_lines(first, 0, -1, false)) do
                if line:find("🤖:", 1, true) then
                    vim.api.nvim_buf_set_lines(first, row - 1, row, false, {})
                    break
                end
            end
        end
        -- The topic timer must observe parent lifetime even without a visible
        -- spinner target; no further response chunks are required.
        vim.wait(300, function() return #process_state.signals > 0 end, 5)
        assert.same({ { pid = 4243, signal = 15 } }, process_state.signals)
        assert.is_true(parley.tasker.is_busy(second, true))
        assert.equals(2, #parley.tasker._handles,
            "signaling must retain the topic and unrelated attempt until exit/drain")
        assert.is_true(vim.api.nvim_buf_is_valid(topic_buffer))
        process_state.processes[4243]:finish()
        settle(function() return not vim.api.nvim_buf_is_valid(topic_buffer) end)
        assert.is_true(parley.tasker.is_busy(second, true))
    end)
    end
end)
