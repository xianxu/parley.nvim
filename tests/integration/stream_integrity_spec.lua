-- The streamed answer lands whole under interference (#229).
--
-- Real chain, nothing stubbed on the parley side: curl against a process-level
-- fake streaming many separate SSE deltas, the real dispatcher (where
-- `qt.response` accumulates as ground truth), tasker, provider adapter,
-- generation runner and document writes. While it streams, every answer write
-- schedules a human edit ABOVE the answer and a busy main-loop slice, so writes
-- race relocation and a loaded scheduler. The oracle compares the buffer's
-- answer with the response the model sent, byte for byte.

local uv = vim.uv or vim.loop
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local dispatcher = require("parley.dispatcher")
local ready_port = require("tests.helpers.ready_port")
local Session = require("parley.response_session")
local D = require("parley.document")
local Layout = require("parley.response_layout")
local Preparation = require("parley.response_preparation")
local vault = require("parley.vault")
local fixture_process = require("tests.helpers.fixture_process")

-- Mirrors fake_cliproxy's stream_deltas: the fake's text is a pure function of
-- the count, so the expectation is built independently of the client.
local function expected_text(count)
    local parts = {}
    for i = 1, count do
        local word = i % 5 == 0 and ("café-%d"):format(i) or ("w%d"):format(i)
        parts[#parts + 1] = word .. (i % 7 == 0 and "\n" or " ")
    end
    return table.concat(parts)
end

local function start_fake(port, env)
    local handle, _, err = fixture_process.spawn(FAKE, { "--port", tostring(port), "--response-mode", "stream" }, env)
    assert(handle, "spawn fake: " .. tostring(err))
    local up = false
    vim.wait(5000, function()
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(e) up = e == nil; c:close() end)
        vim.wait(50, function() return false end)
        return up
    end, 50)
    assert(up, "fake did not come up on port " .. port)
end

describe("streamed answer integrity under interference (#229)", function()
    local mark, port, saved_endpoint, saved_manage, buf, doc, session

    before_each(function()
        mark = fixture_process.mark()
        buf, doc, session = nil, nil, nil
        port = ready_port.free_port()
        dispatcher.providers.cliproxyapi = dispatcher.providers.cliproxyapi or {}
        saved_endpoint = dispatcher.providers.cliproxyapi.endpoint
        dispatcher.providers.cliproxyapi.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local cliproxy = require("parley.cliproxy")
        saved_manage = cliproxy.is_managed
        cliproxy.is_managed = function() return false end
        vault.add_secret("cliproxyapi", "testkey")
    end)

    after_each(function()
        if session then Session.cancel(session) end
        if doc then D.detach(doc) end
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        fixture_process.reap({ since = mark, signal = "sigterm" })
        dispatcher.providers.cliproxyapi.endpoint = saved_endpoint
        require("parley.cliproxy").is_managed = saved_manage
    end)

    it("writes exactly qt.response while edits above it and a busy loop race every write", function()
        local count = 300
        start_fake(port, { PARLEY_FAKE_STREAM_DELTAS = tostring(count) })
        buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: stream please", "🤖: old", "text" })
        doc = D.attach(buf)
        local plan = Preparation.plan(Layout.prepare({ lines = { "🤖: old", "text" }, first_row = 1, first_byte = 1,
            header_lines = { "🤖: fixture" } }, { chat_branch_prefix = "🌿:", chat_local_prefix = "🔒:" }))
        local model = { model = "gpt-5.6-sol" }
        local messages = { { role = "user", content = "stream please" } }
        local input = { provider = "cliproxyapi", model = model, buf = buf, messages = messages,
            payload = dispatcher.prepare_payload(messages, model, "cliproxyapi", {}) }

        local streaming, edits, response = true, 0, nil
        vim.api.nvim_buf_attach(buf, false, {
            on_lines = function(_, _, _, first)
                if not streaming or first == 0 then return end -- ignore our own edits at the top
                vim.schedule(function()
                    if not streaming or not vim.api.nvim_buf_is_valid(buf) then return end
                    edits = edits + 1
                    vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "human edit " .. edits })
                    local t = uv.hrtime()
                    while uv.hrtime() - t < 3e6 do end -- a busy main-loop slice
                end)
            end,
        })

        session = assert(Session.start(doc, { operation = "respond", schedule = true, input = {}, preparation = plan,
            question = { first = { row = 0, col = 0 }, last = { row = 0, col = #"💬: stream please" } },
            output = { first = { row = 0, col = #"💬: stream please" }, last = { row = 2, col = 4 } } }, {
            buf = buf, pending = false, allowed_tools = {},
            prepare_input = function(_, cb) cb.prepared(input); cb.resolved() end,
            build_input = function(previous) return previous end,
            on_result = function(_, query) response = query.response end,
        }))
        assert.is_true(vim.wait(30000, function() return Session.snapshot(session).status == "terminal" end, 5),
            vim.inspect(Session.snapshot(session)))
        streaming = false
        assert.equals("success", Session.snapshot(session).generation.outcome)

        -- Ground truth first: the transport received the fake's whole text.
        assert.equals(expected_text(count), response)
        assert.is_true(edits >= 10, "interference did not overlap the stream: " .. edits .. " edits")

        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        for i = 1, edits do assert.equals("human edit " .. (edits - i + 1), lines[i]) end
        local text = table.concat(lines, "\n", edits + 1)
        local header = "💬: stream please\n\n🤖: fixture\n"
        assert.equals(header, text:sub(1, #header), text:sub(1, 200))
        local answer = text:sub(#header + 1)
        assert.equals(response, answer)
    end)
end)
