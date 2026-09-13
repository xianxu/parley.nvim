-- Integration tests for the dispatcher's request-transport cache (#231 BR-7).
--
-- dispatcher.query serializes every request body to `D.query_dir/<stamp>.json`
-- and hands curl the path (`-d @file`). Text-only bodies are a debug aid and
-- stay behind (pruned at setup once the store exceeds 200 files). An
-- image-bearing body is ~1000x larger, so it is removed the moment the curl
-- subprocess reaches ANY terminal path — success, provider error, kill, and
-- pre-spawn rejection. These tests drive real curl processes against
-- tests/fixtures/fake_sse_server so the terminal paths are the real ones.

local tmp_dir = vim.fn.tempname() .. "-parley-query-cache"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    web_search = false,
    providers = {
        openai = { endpoint = "http://127.0.0.1:1/v1/chat/completions" },
    },
    api_keys = { openai = "fixture-secret" },
})

local dispatcher = parley.dispatcher
-- A spec-local store: the shared XDG cache would carry files from sibling
-- specs running in parallel, and the assertions below enumerate the store.
local query_dir = tmp_dir .. "/query"
vim.fn.mkdir(query_dir, "p")
dispatcher.query_dir = query_dir

local ready_port = require("tests.helpers.ready_port")
local fixture_process = require("tests.helpers.fixture_process")
local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_sse_server"
local uv = vim.uv or vim.loop
local processes = {}

local function start_server(mode)
    local ready_file = tmp_dir .. "/ready-" .. mode .. "-" .. math.random(100000)
    local handle, exited, spawn_err = fixture_process.spawn(fixture, { mode, ready_file })
    assert.is_not_nil(handle, spawn_err)
    table.insert(processes, { handle = handle, exited = exited })
    local port, err = ready_port.wait_for_port(ready_file, 2000)
    assert.is_not_nil(port, err)
    vim.fn.delete(ready_file)
    return port
end

-- Every transport file whose serialized body contains `marker`.
local function transport_files_containing(marker)
    local hits = {}
    for _, path in ipairs(vim.fn.glob(query_dir .. "/*.json", false, true)) do
        local fh = io.open(path, "r")
        if fh then
            local body = fh:read("*a") or ""
            fh:close()
            if body:find(marker, 1, true) then
                table.insert(hits, path)
            end
        end
    end
    return hits
end

-- Distinctive per-payload markers so a leftover from one case cannot satisfy
-- (or fail) another.
local function unique_marker(label)
    return "br7-" .. label .. "-" .. os.time() .. "-" .. math.random(1000000)
end

local function text_payload(marker)
    return {
        model = "fixture-model",
        stream = true,
        messages = { { role = "user", content = "text only " .. marker } },
    }
end

-- Anthropic-shaped image block; assets.has_image recognises the shape
-- regardless of which provider the body is posted to, and the fixture server
-- discards the body unread.
local function image_payload(marker)
    local base64 = vim.base64.encode(("image bytes " .. marker .. " "):rep(64))
    return {
        model = "fixture-model",
        stream = true,
        messages = {
            {
                role = "user",
                content = {
                    { type = "image", source = { type = "base64", media_type = "image/png", data = base64 } },
                    { type = "text", text = "describe " .. marker },
                },
            },
        },
    }, base64
end

describe("dispatcher request-transport cache", function()
    local original_spawn

    before_each(function()
        original_spawn = uv.spawn
    end)

    after_each(function()
        uv.spawn = original_spawn
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
    end)

    -- Issue a real request. Returns a probe that reports which terminal
    -- surface settled the query (`exit`, `error`, or `abort`).
    local function send(payload)
        local probe = { settled = nil }
        local buf = vim.api.nvim_create_buf(false, true)
        dispatcher.query(buf, "openai", payload,
            function() end, -- handler: streamed content is irrelevant here
            function() probe.settled = probe.settled or "exit" end, -- on_exit
            nil, nil,
            function() probe.settled = probe.settled or "abort" end, -- on_abort
            nil,
            function() probe.settled = probe.settled or "error" end) -- on_error
        return probe
    end

    local function wait_settled(probe)
        assert.is_true(vim.wait(4000, function() return probe.settled ~= nil end, 10),
            "query never reached a terminal path")
        return probe.settled
    end

    it("removes an image-bearing transport file once the request succeeds", function()
        local port = start_server("ok")
        dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local marker = unique_marker("ok")
        local payload, base64 = image_payload(marker)

        local probe = send(payload)
        assert.equals("exit", wait_settled(probe))

        assert.same({}, transport_files_containing(base64),
            "image bytes must not persist in the query store after a successful send")
    end)

    it("keeps a text-only transport file after the request succeeds", function()
        local port = start_server("ok")
        dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local marker = unique_marker("text")

        local probe = send(text_payload(marker))
        assert.equals("exit", wait_settled(probe))

        -- Pre-#231 behaviour, pinned: text bodies remain as a debug aid.
        assert.equals(1, #transport_files_containing(marker))
    end)

    it("removes an image-bearing transport file when the provider answers with an error", function()
        local port = start_server("http500")
        dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local marker = unique_marker("http500")
        local payload, base64 = image_payload(marker)

        local probe = send(payload)
        assert.equals("error", wait_settled(probe))

        assert.same({}, transport_files_containing(base64))
    end)

    it("removes an image-bearing transport file when the request is killed mid-flight", function()
        local port = start_server("delayed")
        dispatcher.providers.openai.endpoint = "http://127.0.0.1:" .. port .. "/v1/chat/completions"
        local marker = unique_marker("killed")
        local payload, base64 = image_payload(marker)

        local probe = send(payload)
        -- The delayed fixture holds the response for >1s; curl is alive and
        -- the body is on disk when the kill lands.
        assert.is_true(vim.wait(1000, function() return #parley.tasker._handles > 0 end, 10),
            "curl never started")
        assert.equals(1, #transport_files_containing(base64), "body must be on disk while curl runs")

        parley.tasker.stop()
        assert.equals("error", wait_settled(probe))

        assert.same({}, transport_files_containing(base64))
    end)

    it("removes an image-bearing transport file when curl cannot be spawned", function()
        local marker = unique_marker("nospawn")
        local payload, base64 = image_payload(marker)
        uv.spawn = function() return nil, "fixture spawn rejection" end

        local probe = send(payload)
        assert.equals("abort", wait_settled(probe))

        assert.same({}, transport_files_containing(base64))
    end)
end)
