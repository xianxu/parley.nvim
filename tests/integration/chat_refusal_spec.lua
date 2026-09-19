-- #261 M5 Task 5.3: every refusal and every non-success ending reaches the user
-- exactly once, in words, with an action. A user's own Stop says nothing.
local parley = require("parley")
local Respond = require("parley.chat_respond")
local Fixture = require("tests.helpers.respond_fixture")
local Stub = require("tests.helpers.stub")
local root = vim.fn.tempname() .. "-refusal"; vim.fn.mkdir(root, "p")
parley.setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {},
    default_agent = "RefusalFixture", agents = { { name = "Choose a model", disable = true },
        { name = "RefusalFixture", provider = "openai", model = { model = "fixture" }, system_prompt = "Fixture", tools = {} } } })

local PREFIXES = vim.tbl_values(require("parley.refusal").PREFIX)
local function wait(fn, what) assert.is_true(vim.wait(3000, fn, 1), what or "did not settle") end

describe("refusals reach the user once, in words", function()
    local buf, calls, restore, warnings, serial = nil, nil, nil, nil, 0
    local function chat(lines)
        serial = serial + 1
        local path = root .. string.format("/2026-09-19.12-00-%02d.%03d_refusal.md", serial % 60, serial)
        vim.fn.writefile(lines, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path)); buf = vim.api.nvim_get_current_buf()
    end
    local function refusals()
        local out = {}
        for _, message in ipairs(warnings) do
            for _, prefix in ipairs(PREFIXES) do
                if message:find(prefix, 1, true) == 1 then out[#out + 1] = message end
            end
        end
        return out
    end
    local function cursor(text)
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line == text then vim.api.nvim_win_set_cursor(0, { i, 0 }); return end
        end
        error("missing line " .. text)
    end
    -- The fixture's query record carries the streamed text, as the transport's does.
    local function output(call, bytes)
        local query = parley.tasker.get_query(call.id); query.response = query.response .. bytes
        call.output(call.id, bytes)
    end
    local function row_of(needle)
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line:find(needle, 1, true) then return i end
        end
    end
    local function terminal(session)
        wait(function() return Respond.response_snapshot(session).status == "terminal" end)
        vim.wait(20) -- the logger shows its message on the next turn
    end
    -- Starts an answer to the first question and waits for its partial text.
    local function streaming()
        cursor("💬: first"); local session = assert(Respond.respond({ range = 0 }))
        wait(function() return #calls == 1 end)
        output(calls[1], "partial reply"); wait(function() return row_of("partial reply") ~= nil end)
        return session
    end
    before_each(function()
        warnings = {}
        calls, restore = Fixture.install(parley)
        chat({ "# topic: Fixture", "- file: fixture.md", "---", "", "💬: first", "🤖: old", "old answer", "",
            "💬: second", "", "💬: third", "", "💬: fourth", "", "💬: fifth", "", "💬: next", "draft" })
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        restore()
        vim.wait(50)
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end)
    -- Record every warning the refusal channel sends, while `body` runs.
    local function capture(body)
        Stub.with_stub(parley.logger, "warning", function(message) warnings[#warnings + 1] = tostring(message) end, body)
    end
    -- The WHOLE message, never a probe: a substring holds either side of a
    -- detail appended, suppressed or composed wrongly (#261 M5 review BR-65/72).
    -- Every case goes through here, including the ones with more than one.
    local function refusals_are(expected)
        assert.same(expected, refusals())
    end
    local function one(expected)
        refusals_are({ expected })
        return expected
    end

    it("says so when the batch selection holds no question", function()
        capture(function() cursor("# topic: Fixture"); Respond.respond_all() end)
        one("Batch not started: no question is in the selection;"
            .. " edit: select the 💬: questions to answer, then submit again")
    end)

    it("says so when the cursor is not on a question", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# topic: Fixture", "- file: fixture.md", "---", "", "just text" })
        capture(function() cursor("just text"); Respond.respond({ range = 0 }) end)
        one("Response not started: the cursor is not on a question;"
            .. " edit: put the cursor on a 💬: question, then submit again")
    end)

    it("says an edit revoked the answer, keeping the partial text", function()
        capture(function()
            local session = streaming()
            local row = row_of("partial reply")
            vim.api.nvim_buf_set_text(buf, row - 1, 0, row - 1, 0, { "human " })
            terminal(session)
        end)
        one("Response stopped: you edited the answer while it was being written;"
            .. " the partial answer is kept; submit again to regenerate")
    end)

    -- `:e!` detaches the document just as closing the chat does (measured: the
    -- document sees `detach`, then a new one attaches after BufReadPost).
    it("says a reload stopped the answer", function()
        capture(function()
            local session = streaming()
            vim.cmd("silent write!"); vim.cmd("edit!")
            terminal(session)
        end)
        one("Response stopped: the chat was reloaded while the answer was being written; submit again")
    end)

    it("says nothing when the chat is closed", function()
        capture(function()
            local session = streaming()
            vim.cmd("silent write!"); vim.cmd("enew"); vim.api.nvim_buf_delete(buf, { unload = true })
            terminal(session)
        end)
        assert.same({}, refusals())
    end)

    it("says nothing when the user stops a batch", function()
        capture(function()
            cursor("💬: first"); local batch = assert(Respond.respond_all())
            wait(function() return #calls == 1 end)
            Respond.cancel_responses(buf)
            wait(function() return not Respond.batch_snapshot(batch).active end)
            vim.wait(20)
        end)
        assert.same({}, refusals())
    end)

    it("says a reload ended the batch", function()
        capture(function()
            cursor("💬: first"); assert(Respond.respond_all())
            wait(function() return #calls == 1 end)
            output(calls[1], "partial reply"); wait(function() return row_of("partial reply") ~= nil end)
            vim.cmd("silent write!"); vim.cmd("edit!")
            vim.wait(50)
        end)
        one("Batch stopped: the chat was reloaded; :ParleyChatRespondAll to start again"
            .. " — 0 of 1 questions answered")
    end)

    -- The response says why it stopped; the batch says only that it paused and
    -- how to continue — once, though its state changes several times paused.
    it("says a batch paused once, without repeating its response's reason", function()
        capture(function()
            cursor("💬: first"); local batch = assert(Respond.respond_all())
            wait(function() return #calls == 1 end)
            calls[1].running = false; calls[1].failure(calls[1].id, { http_status = 503, body = "upstream down" })
            wait(function() return Respond.batch_snapshot(batch).phase == "paused" and not Respond.batch_snapshot(batch).active end)
            vim.wait(50)
            -- Each edit re-checks the paused batch; none of them is a new pause.
            for i = 1, 3 do vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "later edit " .. i }); vim.wait(30) end
        end)
        refusals_are({
            "Response stopped: the model's request failed; submit again"
                .. " — parley: provider request failed (HTTP 503): upstream down",
            "Batch paused: its current response stopped; :ParleyChatResumeBatch to continue"
                .. " — 0 of 1 questions answered",
        })
    end)

    -- A reworded question is a new question: the paused batch cannot resume it,
    -- and gives way to a new batch instead of refusing every later one.
    it("says why a paused batch did not resume, and lets a new batch start", function()
        local batch
        capture(function()
            cursor("💬: first"); batch = assert(Respond.respond_all())
            wait(function() return #calls == 1 end)
            calls[1].running = false; calls[1].failure(calls[1].id, { http_status = 503, body = "upstream down" })
            wait(function() return Respond.batch_snapshot(batch).phase == "paused" and not Respond.batch_snapshot(batch).active end)
            vim.wait(50)
        end)
        warnings = {}
        capture(function()
            local row = assert(row_of("💬: first"))
            vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "💬: first, reworded" })
            vim.wait(50)
            Respond.resume_batch({})
            vim.wait(200)
        end)
        one("Batch not resumed: a question in the batch was replaced;"
            .. " :ParleyChatRespondAll to start a new batch")
        warnings = {}
        capture(function()
            cursor("💬: first, reworded"); assert(Respond.respond_all(), "the paused batch still blocks")
            wait(function() return #calls == 2 end)
        end)
        assert.same({}, refusals())
    end)

    it("says a batch is already active", function()
        capture(function()
            cursor("💬: first"); assert(Respond.respond_all())
            wait(function() return #calls == 1 end)
            Respond.respond_all()
        end)
        one("Batch not started: a batch is already running in this chat;"
            .. " wait for it to finish, or stop it with :ParleyStop")
    end)

    it("says the model's request failed, with the provider's detail", function()
        capture(function()
            cursor("💬: first"); local session = assert(Respond.respond({ range = 0 }))
            wait(function() return #calls == 1 end)
            calls[1].running = false; calls[1].failure(calls[1].id, { http_status = 503, body = "upstream down" })
            terminal(session)
        end)
        -- The whole message, not a probe: a substring holds either side of a
        -- suppression that never ran (#261 M5 review BR-65).
        one("Response stopped: the model's request failed; submit again"
            .. " — parley: provider request failed (HTTP 503): upstream down")
    end)

    it("says the request could not be built, and why", function()
        capture(function()
            Stub.with_stub(Respond, "build_messages", function() error("builder exploded", 0) end, function()
                cursor("💬: first"); terminal(assert(Respond.respond({ range = 0 })))
            end)
        end)
        one("Response not started: the request could not be built (builder exploded); submit again")
    end)

    -- A submission waits behind first-use model setup; closing it is not a
    -- request that "could not be built".
    it("says a model setup is already open", function()
        capture(function()
            Stub.with_stub(require("parley.llm_readiness"), "defer", function(_, _, opts)
                opts.on_cancel("LLM setup is already in progress"); return true
            end, function()
                cursor("💬: first"); terminal(assert(Respond.respond({ range = 0 })))
            end)
        end)
        one("Response not started: a model setup is already open; finish it, then submit again")
    end)

    it("says an overflow stopped the response, without its token", function()
        capture(function()
            cursor("💬: first"); local session = assert(Respond.respond({ range = 0 }))
            wait(function() return #calls == 1 end)
            output(calls[1], string.rep("x", 1048577))
            terminal(session)
        end)
        one("Response stopped: the response was stopped to keep its output from being dropped; submit again"
            .. " — its output passed the staging budget")
    end)

    it("names :ParleyStop when the answer is already being written", function()
        capture(function()
            cursor("💬: first"); assert(Respond.respond({ range = 0 }))
            wait(function() return #calls == 1 end)
            cursor("💬: first"); Respond.respond({ range = 0 })
            vim.wait(50)
        end)
        one("Response not started: another response is already writing this answer;"
            .. " wait for it to finish, or stop it with :ParleyStop, then submit again")
    end)

    it("says nothing when the user stops it", function()
        capture(function()
            cursor("💬: first"); local session = assert(Respond.respond({ range = 0 }))
            wait(function() return #calls == 1 end)
            Respond.cancel_responses(buf)
            terminal(session)
        end)
        assert.same({}, refusals())
    end)

    it("names the pid a stopped process still holds when the chat is full", function()
        capture(function()
            Stub.with_stub(require("parley.tasker"), "held", function() return { { pid = 4242 } } end, function()
                for i, question in ipairs({ "💬: first", "💬: second", "💬: third", "💬: fourth" }) do
                    cursor(question); assert(Respond.respond({ range = 0 }))
                    wait(function() return #calls == i end)
                end
                cursor("💬: fifth"); Respond.respond({ range = 0 })
                vim.wait(50)
            end)
        end)
        one("Response not started: four responses are already running in this chat;"
            .. " wait for one to finish, or stop one with :ParleyStop; still running after Stop: pid 4242")
    end)
end)
