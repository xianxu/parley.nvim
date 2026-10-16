-- Drive one provider request through the REAL path (#242): dispatcher.query ->
-- tasker.run("curl") -> out_reader, against tests/fixtures/fake_provider. Only
-- the provider's configured endpoint and a dummy secret change; the transport
-- is never stubbed.
local uv = vim.uv or vim.loop
local dispatcher = require("parley.dispatcher")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")
local M = {}

M.FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_provider"

--- Start the fake for `dialect` in `mode` (with `split`, and `delay_ms` after
--- each write); returns the port.
function M.start(dialect, mode, split, env, delay_ms)
    local port = ready_port.free_port()
    local handle, _, err = fixture_process.spawn(M.FAKE, { "--dialect", dialect, "--port", tostring(port),
        "--mode", mode or "ok", "--split", split or "none", "--write-delay-ms", tostring(delay_ms or 0) }, env)
    assert(handle, "spawn fake_provider: " .. tostring(err))
    assert(ready_port.wait_listening(port), "fake_provider did not come up on " .. port)
    return port
end

--- One query; blocks until it settles. Returns { response, failure, aborted,
--- errors, warnings, chunks, progress, qt }. opts.on_chunk(n, chunk, qt) sees
--- each handler call while the query is live.
function M.query(provider, port, payload, opts)
    opts = opts or {}
    dispatcher.providers[provider] = dispatcher.providers[provider] or {}
    local saved = dispatcher.providers[provider].endpoint
    dispatcher.providers[provider].endpoint = "http://127.0.0.1:" .. port
        .. require("tests.helpers.provider_scenario_table").PROFILES[provider].route
    require("parley.vault").add_secret(provider, "sk-fake-" .. provider) -- dummy only (PQ-5)
    local logger = require("parley.logger")
    local saved_error, saved_warning = logger.error, logger.warning
    local out = { errors = {}, warnings = {}, chunks = {}, progress = {} }
    logger.error = function(m) out.errors[#out.errors + 1] = tostring(m) end
    logger.warning = function(m) out.warnings[#out.warnings + 1] = tostring(m) end
    local done = false
    local ok, err = pcall(function()
        dispatcher.query(nil, provider, payload, function(query_id, chunk)
            out.chunks[#out.chunks + 1] = chunk
            if opts.on_chunk then opts.on_chunk(#out.chunks, chunk, require("parley.tasker").get_query(query_id)) end
        end, function(query_id)
            -- The query record is dropped once the query settles; keep it here.
            out.qt = require("parley.tasker").get_query(query_id)
        end, function(response)
            out.response = response
            done = true
        end, function(_, event)
            out.progress[#out.progress + 1] = event
        end, function(msg)
            out.aborted = msg -- a pre-start abort (no query ever ran)
            done = true
        end, nil, function(query_id, failure)
            out.qt = out.qt or require("parley.tasker").get_query(query_id)
            out.failure = failure
            done = true
        end, { deadline_ms = require("parley.tasker").deadline.stream }) -- an unowned LLM stream
        assert(vim.wait(opts.timeout_ms or 10000, function() return done end, 10),
            "the query never settled; logged: " .. vim.inspect({ out.errors, out.warnings }))
    end)
    logger.error, logger.warning = saved_error, saved_warning
    dispatcher.providers[provider].endpoint = saved
    assert(ok, err)
    return out
end

--- Run one scenario-table row (tests/helpers/provider_scenario_table.lua) for
--- `profile`; returns the outcome record `mismatches` judges. The only IO
--- driver: the row and the profile are data.
function M.run(row, profile, log_path)
    local mode = row.mode == "disconnect" and ("disconnect_after:" .. profile.disconnect_bytes) or row.mode
    local port = M.start(profile.dialect, mode, row.split, { PARLEY_FAKE_REQUEST_LOG = log_path }, row.delay_ms)
    local tools = row.tool_loop and { "read_file" } or nil
    local messages = { { role = "user", content = "hi" } }
    local function ask(msgs, opts)
        return M.query(profile.provider, port, dispatcher.prepare_payload(msgs, profile.model, profile.provider, tools), opts)
    end
    local raw_at_first_chunk
    local started = vim.uv.now()
    local out = ask(messages, { on_chunk = function(n, _, qt)
        if n == 1 then raw_at_first_chunk = qt and #qt.raw_response end
        if row.throw_at == n then error("consumer invalidated mid-stream") end
    end })
    out.elapsed_ms = vim.uv.now() - started
    if row.tool_loop and not out.failure then
        local calls = profile.decode_calls(out.qt.raw_response)
        out.first_call_id = calls[1] and calls[1].id
        local second = ask(profile.followup(messages, calls))
        second.first_call_id = out.first_call_id
        out = second
    end
    out.raw_at_first_chunk = raw_at_first_chunk
    out.raw_bytes = out.qt and #out.qt.raw_response
    out.partial = out.qt and out.qt.response
    out.ending = out.qt and dispatcher._classify_ending(out.qt).class
    out.requests = M.requests(log_path)
    return out
end

--- The request bodies the fake received, decoded.
function M.requests(log_path)
    local out = {}
    if vim.fn.filereadable(log_path) == 1 then
        for _, line in ipairs(vim.fn.readfile(log_path)) do
            local entry = vim.json.decode(line)
            entry.json = vim.json.decode(entry.body)
            out[#out + 1] = entry
        end
    end
    return out
end

return M
