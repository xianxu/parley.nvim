-- The provider scenario table (#242): PURE data plus the pure judge of one run.
-- The plan's scenario table, row for row. A row says what the fake does and
-- what parley must show for it; a profile says how one provider spells the
-- parts that differ by wire. The IO driver (provider_scenarios.run) turns a row
-- into an outcome record; `mismatches` judges that record. Adding a provider is
-- a profile plus its name in `applies`, never a new hand-written case.
local M = {}

local TEXT = "Hello, world! 👋" -- sse_dialects.FIXTURE_TEXT
local ALL = { anthropic = true, openai = true, googleai = true, cliproxy = true }
local NO_CLIPROXY = { anthropic = true, openai = true, googleai = true }
local TOOLS = { anthropic = true, openai = true, cliproxy = true }
local ANTHROPIC = { anthropic = true }

local function throw_first() return { response = nil, failure = true, exit = "reader", chunks = { "Hello," } } end

M.ROWS = {
    { id = "S1", name = "plain stream: the answer is the fake's text, byte for byte", applies = ALL,
        mode = "ok", expect = { response = TEXT, errors = {} } },
    { id = "S2", name = "two-call tool loop: the second request carries the first call's result", applies = TOOLS,
        mode = "ok", tool_loop = true,
        expect = { response = "Done: the tool result was received.", requests = 2, tool_result_echoed = true } },
    { id = "S3", name = "in-band error mid-stream: the truncation notice names the error (#228)", applies = NO_CLIPROXY,
        mode = "inband_error", expect = { response = "Starting the answer and then ", warning = "in-band — Overloaded" } },
    { id = "S4/429", name = "HTTP 429: a failure carrying the API's message, no retry", applies = NO_CLIPROXY,
        mode = "http_429", expect = { failure = true, http_status = 429, body = "rate limit", requests = 1 } },
    { id = "S4/529", name = "HTTP 529: a failure carrying the API's message, no retry", applies = NO_CLIPROXY,
        mode = "http_529", expect = { failure = true, http_status = 529, body = "Overloaded", requests = 1 } },
    { id = "S4/500", name = "HTTP 500: a failure carrying the API's message, no retry", applies = NO_CLIPROXY,
        mode = "http_500", expect = { failure = true, http_status = 500, body = "Internal server error", requests = 1 } },
    { id = "S5", name = "output cap: the cap notice, the partial answer kept (#228)", applies = NO_CLIPROXY,
        mode = "cap", expect = { response = "The answer was cut off at the cap", cap_notice = true } },
    { id = "S6", name = "every SSE frame split at every byte: same answer, decoded as it arrives",
        -- A 1 ms pause per write keeps the reads apart; unpaced, the socket
        -- sometimes coalesces the whole body into one read (1 run in 5).
        applies = NO_CLIPROXY, mode = "ok", split = "every_byte", delay_ms = 1,
        expect = { response = TEXT, incremental = true, within_ms = 5000 } }, -- PQ-7 envelope
    { id = "S6/frames", name = "one write per frame: same answer", applies = NO_CLIPROXY,
        mode = "ok", split = "frames", expect = { response = TEXT } },
    { id = "S6/random", name = "seeded random slices: same answer", applies = NO_CLIPROXY,
        mode = "ok", split = "random:7", expect = { response = TEXT } },
    { id = "thinking", name = "thinking: reasoning reaches on_progress, only text is the answer", applies = ANTHROPIC,
        mode = "thinking", expect = { response = TEXT, reasoning = { "Let me plan the answer." } } },
    { id = "no_stop", name = "no stop reason: the answer kept, the ending not called clean", applies = NO_CLIPROXY,
        mode = "no_stop", expect = { response = TEXT, ending = "unknown" } },
    { id = "S7a", name = "disconnect after N bytes: a failure, the partial answer kept", applies = ANTHROPIC,
        mode = "disconnect", expect = { failure = true, exit = "", partial = "Hello,", streamed = true } },
    { id = "S7b", name = "the output handler throws: the attempt stops, no later chunk (#229)", applies = ANTHROPIC,
        mode = "ok", split = "every_byte", throw_at = 1, expect = throw_first() },
    -- One frame per read, so the throwing line's read ends at its newline: the
    -- EOF flush used to decode it again, writing the same delta twice (#242).
    { id = "S7b/frames", name = "the output handler throws on a frame-aligned read: no duplicate delta (#242)",
        applies = ANTHROPIC, mode = "ok", split = "frames", delay_ms = 20, throw_at = 1, expect = throw_first() },
}

--- How each provider spells the wire-dependent parts. Functions here are pure
--- transforms of data; the driver never branches on a provider name.
M.PROFILES = {
    anthropic = {
        provider = "anthropic", dialect = "anthropic", route = "/v1/messages",
        model = { model = "claude-sonnet-4-6" },
        cap = "max_tokens",       -- the spelling the cap notice names
        disconnect_bytes = 600,   -- the cut lands after the first text delta
        decode_calls = function(raw) return require("parley.tools.wire_anthropic").decode_tool_calls_from_stream(raw) end,
        --- The follow-up conversation after `calls`, answering each with a result.
        followup = function(messages, calls)
            local out = vim.deepcopy(messages)
            local uses, results = {}, {}
            for _, c in ipairs(calls) do
                uses[#uses + 1] = { type = "tool_use", id = c.id, name = c.name, input = c.input }
                results[#results + 1] = { type = "tool_result", tool_use_id = c.id, content = "README CONTENT" }
            end
            out[#out + 1] = { role = "assistant", content = uses }
            out[#out + 1] = { role = "user", content = results }
            return out
        end,
        --- The tool-result id the request's last message answers, or nil.
        echoed_id = function(request)
            local last = (request.messages or {})[#(request.messages or {})] or {}
            local block = type(last.content) == "table" and last.content[1] or {}
            return block.type == "tool_result" and block.tool_use_id or nil
        end,
    },
}

--- The rows that apply to `provider`, in table order.
function M.rows_for(provider)
    local out = {}
    for _, row in ipairs(M.ROWS) do
        if row.applies[provider] then out[#out + 1] = row end
    end
    return out
end

local function contains(lines, needle)
    for _, l in ipairs(lines or {}) do
        if tostring(l):find(needle, 1, true) then return true end
    end
    return false
end

--- Judge one outcome record against its row. PURE. Returns the list of
--- mismatches; empty means the run matched. The outcome record is:
--- { response, failure, warnings, errors, chunks, progress, ending,
---   raw_at_first_chunk, raw_bytes, elapsed_ms, requests, first_call_id }
function M.mismatches(row, out, profile)
    local e, bad = row.expect, {}
    local function want(ok, what) if not ok then bad[#bad + 1] = what end end
    if e.failure then
        want(type(out.failure) == "table", "expected a failure, the request completed")
    else
        want(out.failure == nil, "unexpected failure: " .. vim.inspect(out.failure))
    end
    if e.response then want(out.response == e.response, ("response %q, want %q"):format(tostring(out.response), e.response)) end
    if e.errors then want(#(out.errors or {}) == #e.errors, "logged errors: " .. vim.inspect(out.errors)) end
    if e.warning then want(contains(out.warnings, e.warning), "no warning naming " .. e.warning .. ": " .. vim.inspect(out.warnings)) end
    if e.cap_notice then
        want(contains(out.warnings, profile.cap) or contains(out.errors, profile.cap),
            "no cap notice naming " .. profile.cap .. ": " .. vim.inspect({ out.warnings, out.errors }))
    end
    local f = type(out.failure) == "table" and out.failure or {}
    if e.http_status then want(f.http_status == e.http_status, "http_status " .. tostring(f.http_status)) end
    if e.body then want(tostring(f.body):find(e.body, 1, true) ~= nil, "failure body lacks " .. e.body) end
    if e.exit then want(f.exit ~= nil and tostring(f.exit):find(e.exit, 1, true) ~= nil, "failure exit " .. tostring(f.exit)) end
    if e.streamed then want(f.streamed == true, "failure not marked streamed") end
    if e.partial then want(out.partial == e.partial, ("partial answer %q, want %q"):format(tostring(out.partial), e.partial)) end
    if e.requests then want(#(out.requests or {}) == e.requests, ("%d requests, want %d"):format(#(out.requests or {}), e.requests)) end
    if e.tool_result_echoed then
        local last = (out.requests or {})[#(out.requests or {})]
        want(last ~= nil and out.first_call_id ~= nil and profile.echoed_id(last.json) == out.first_call_id,
            "the second request does not answer the first call")
    end
    if e.incremental then
        want(type(out.raw_at_first_chunk) == "number" and out.raw_at_first_chunk < (out.raw_bytes or 0),
            ("the stream arrived in one read (%s of %s bytes)"):format(tostring(out.raw_at_first_chunk), tostring(out.raw_bytes)))
    end
    if e.within_ms then want((out.elapsed_ms or math.huge) < e.within_ms, "took " .. tostring(out.elapsed_ms) .. " ms") end
    if e.ending then want(out.ending == e.ending, "ending " .. tostring(out.ending)) end
    if e.chunks then want(vim.deep_equal(out.chunks, e.chunks), "handler chunks " .. vim.inspect(out.chunks)) end
    if e.reasoning then
        local got = {}
        for _, ev in ipairs(out.progress or {}) do
            if ev.kind == "reasoning" then got[#got + 1] = ev.text end
        end
        want(vim.deep_equal(got, e.reasoning), "reasoning " .. vim.inspect(got))
    end
    return bad
end

return M
