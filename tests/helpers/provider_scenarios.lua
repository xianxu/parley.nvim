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
M.ROUTE = { anthropic = "/v1/messages" }

--- Start the fake for `dialect` in `mode` (with `split`); returns the port.
function M.start(dialect, mode, split, env)
    local port = ready_port.free_port()
    local handle, _, err = fixture_process.spawn(M.FAKE, { "--dialect", dialect, "--port", tostring(port),
        "--mode", mode or "ok", "--split", split or "none" }, env)
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
    dispatcher.providers[provider].endpoint = "http://127.0.0.1:" .. port .. M.ROUTE[provider]
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
