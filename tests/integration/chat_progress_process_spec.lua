local tmp_dir = vim.fn.tempname() .. "-parley-progress-process"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    web_search = false,
    default_agent = "ProcessFixture",
    providers = {
        openai = { endpoint = "http://127.0.0.1:1/v1/chat/completions" },
    },
    api_keys = { openai = "fixture-secret" },
    agents = {
        {
            name = "ProcessFixture",
            provider = "openai",
            model = { model = "fixture-model" },
            system_prompt = "Answer briefly.",
        },
    },
})

local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server"
local uv = vim.uv or vim.loop
local processes = {}

local function start_server(mode)
    local ready_file = tmp_dir .. "/ready-" .. mode .. "-" .. math.random(100000)
    local exited = false
    local handle
    local env = {}
    for name, value in pairs(vim.fn.environ()) do
        table.insert(env, name .. "=" .. value)
    end
    table.insert(env, "PYTHONDONTWRITEBYTECODE=1")
    handle = uv.spawn(fixture, { args = { mode, ready_file }, env = env }, function()
        exited = true
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    assert.is_not_nil(handle)
    table.insert(processes, { handle = handle, exited = function() return exited end })
    assert.is_true(vim.wait(1000, function() return vim.fn.filereadable(ready_file) == 1 end, 10))
    local port = tonumber(vim.fn.readfile(ready_file)[1])
    vim.fn.delete(ready_file)
    return port
end

local function open_chat(mode)
    local path = tmp_dir .. "/2026-07-13-process-" .. mode .. "-" .. math.random(100000) .. ".md"
    vim.fn.writefile({
        "# topic: Fixture",
        "- file: fixture.md",
        "---",
        "",
        "💬: test the process boundary",
    }, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    return vim.api.nvim_get_current_buf()
end

local function text(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return "" end
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function pending_marks(buf)
    local ns = vim.api.nvim_get_namespaces().parley_chat_pending
    if not ns or not vim.api.nvim_buf_is_valid(buf) then return {} end
    return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end

describe("chat progress real curl process", function()
    local original_notify
    local original_pending_start
    local original_get_secret
    local original_is_busy
    local original_spawn
    local notices
    local activity_count

    before_each(function()
        notices = {}
        activity_count = 0
        original_notify = vim.notify
        original_pending_start = require("parley.chat_pending").start
        original_get_secret = parley.vault.get_secret
        original_is_busy = parley.tasker.is_busy
        original_spawn = (vim.uv or vim.loop).spawn
        require("parley.chat_pending").start = function(opts)
            local session = original_pending_start(opts)
            local activity = session.activity
            session.activity = function(self, ...)
                activity_count = activity_count + 1
                return activity(self, ...)
            end
            return session
        end
        vim.notify = function(message, level)
            table.insert(notices, { message = tostring(message), level = level,
                buffer_text = text(vim.api.nvim_get_current_buf()),
                pending_count = #pending_marks(vim.api.nvim_get_current_buf()) })
        end
    end)

    after_each(function()
        vim.notify = original_notify
        require("parley.chat_pending").start = original_pending_start
        parley.vault.get_secret = original_get_secret
        parley.tasker.is_busy = original_is_busy
        uv.spawn = original_spawn
        require("parley.chat_pending").cancel_all("test teardown")
        parley.tasker.stop()
        for _, process in ipairs(processes) do
            if not process.exited() and process.handle and not process.handle:is_closing() then
                pcall(process.handle.kill, process.handle, "sigterm")
            end
        end
        local reaped = vim.wait(500, function()
            for _, process in ipairs(processes) do
                if not process.exited() then return false end
            end
            return true
        end, 10)
        if not reaped then
            for _, process in ipairs(processes) do
                if not process.exited() and process.handle and not process.handle:is_closing() then
                    pcall(process.handle.kill, process.handle, "sigkill")
                end
            end
            reaped = vim.wait(500, function()
                for _, process in ipairs(processes) do
                    if not process.exited() then return false end
                end
                return true
            end, 10)
        end
        assert.is_true(reaped, "fake SSE server must be reaped")
        processes = {}
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
                pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
        end
    end)

    local function run(mode)
        local port = start_server(mode)
        parley.dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local buf = open_chat(mode)
        parley.chat_respond({ range = 0 })
        return buf
    end

    it("stages a delayed SSE answer behind the minimum-visible playful line", function()
        local buf = run("delayed")
        assert.is_true(vim.wait(1050, function() return #pending_marks(buf) == 1 end, 10))
        assert.is_false(text(buf):find("partial answer", 1, true) ~= nil)
        assert.is_true(vim.wait(3000, function()
            return text(buf):find("partial answer", 1, true) ~= nil and #pending_marks(buf) == 0
        end, 10), vim.inspect({ text = text(buf), notices = notices, marks = pending_marks(buf),
            query = parley.tasker.get_active_query_by_buf(buf) }))
        for _, notice in ipairs(notices) do
            assert.is_true(notice.message:find("provider request failed", 1, true) == nil)
        end
        assert.equals(2, activity_count, "only the two stdout SSE records count as activity")
    end)

    for _, case in ipairs({
        { mode = "broken", expected = "exit" },
        { mode = "unauthorized", expected = "HTTP 401" },
        { mode = "http500", expected = "HTTP 500" },
    }) do
        it("orders partial output before the " .. case.mode .. " provider failure", function()
            local buf = run(case.mode)
            local notice
            assert.is_true(vim.wait(2000, function()
                for _, candidate in ipairs(notices) do
                    if candidate.message:find("provider request failed", 1, true) then
                        notice = candidate
                        return true
                    end
                end
                return false
            end, 10), vim.inspect(notices))
            assert.is_true(notice.message:find(case.expected, 1, true) ~= nil, notice.message)
            assert.equals(0, notice.pending_count, "failure notification must observe the extmark already hidden")
            assert.equals(0, #pending_marks(buf))
            if case.mode ~= "unauthorized" then
                assert.is_true(notice.buffer_text:find("partial answer", 1, true) ~= nil,
                    "partial output must be visible before failure notification")
            end
            assert.is_true(notice.buffer_text:find("__PARLEY_HTTP_", 1, true) == nil)
        end)
    end

    local function assert_prestart_cleanup(expected_message)
        local buf = open_chat("prestart")
        parley.chat_respond({ range = 0 }, nil, nil, true)
        local matching = 0
        assert.is_true(vim.wait(1000, function()
            matching = 0
            for _, notice in ipairs(notices) do
                if notice.level == vim.log.levels.WARN
                        and notice.message:find(expected_message, 1, true) then
                    matching = matching + 1
                end
            end
            return matching > 0 and #pending_marks(buf) == 0
        end, 10), vim.inspect(notices))
        assert.equals(1, matching)
        assert.equals(0, #pending_marks(buf))
        assert.is_true(text(buf):find("brewing", 1, true) == nil)
    end

    it("cleans one real chat session when the provider secret is missing", function()
        parley.vault.get_secret = function() return nil end
        assert_prestart_cleanup("bearer token is missing")
    end)

    it("cleans one real chat session when task launch is rejected as busy", function()
        parley.tasker.is_busy = function() return true end
        assert_prestart_cleanup("buffer is busy")
    end)

    it("cleans one real chat session when curl spawn is rejected", function()
        uv.spawn = function() return nil, "fixture spawn rejection" end
        assert_prestart_cleanup("fixture spawn rejection")
    end)
end)
