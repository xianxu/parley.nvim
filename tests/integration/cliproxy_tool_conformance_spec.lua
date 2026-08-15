-- #198: live conformance for cliproxyapi's OpenAI tool-call wire.
--
-- lua/parley/tools/wire_openai.lua's decoder is written against captured
-- bytes (tests/fixtures/openai_*.sse). Captures rot. This spec asks a REAL
-- cliproxyapi for a real tool call and asserts the fields the decoder depends
-- on are still there — so upstream wire drift fails here rather than in a
-- user's chat, where the symptom is a silently empty answer.
--
-- SAFETY — read before editing:
--
--   Unlike cliproxy_conformance_spec.lua, which boots its own proxy against a
--   throwaway auth-dir holding a FABRICATED credential, this check needs a
--   completion — and therefore a REAL credential. It must never spawn a
--   second proxy pointed at a live auth-dir: cliproxyapi refreshes OAuth
--   tokens at startup and every 15 minutes, and Claude's refresh tokens
--   ROTATE on use. Two proxies sharing one auth-dir is precisely the race
--   that caused the #197 outage.
--
--   So this spec is READ-ONLY with respect to the proxy: it reuses whatever
--   instance is already listening, spawns nothing, and writes nothing. And it
--   is OFF unless PARLEY_LIVE_CONFORMANCE=1 is set, so a routine `make test`
--   neither burns quota nor depends on the operator's credentials.
--
-- Run it deliberately:
--   PARLEY_LIVE_CONFORMANCE=1 nvim --headless \
--     -c "PlenaryBustedFile tests/integration/cliproxy_tool_conformance_spec.lua" -c "qa!"

local providers = require("parley.providers")
local wire_openai = require("parley.tools.wire_openai")

-- Fields the decoder reads out of a streamed tool call. Losing any one of
-- them upstream breaks assembly, so each is asserted individually rather than
-- inferred from a successful decode.
local REQUIRED_DELTA_FIELDS = { "index", "id", "function.name", "function.arguments" }

local ENABLED = os.getenv("PARLEY_LIVE_CONFORMANCE") == "1"
local MODEL = os.getenv("PARLEY_LIVE_CONFORMANCE_MODEL") or "gpt-5.6-sol"

local function endpoint()
    local cfg = (require("parley").dispatcher or {}).providers or {}
    local cp = cfg.cliproxyapi or {}
    return cp.endpoint or "http://127.0.0.1:8317/v1/chat/completions"
end

local function api_key()
    return os.getenv("CLIPROXYAPI_API_KEY")
        or (require("parley.config").api_keys or {}).cliproxyapi
        or "parley-local"
end

--- Probe the already-running proxy. We only ever reuse one; we never spawn.
--- Returns "ok" | "unauthorized" | "absent", so the skip message can name the
--- real cause. A 401 means a proxy IS there and our key is wrong — reporting
--- that as "nothing listening" is the class of misleading diagnostic #197
--- existed to remove.
---@return "ok"|"unauthorized"|"absent", string http_code
local function probe_proxy()
    local url = endpoint():gsub("/v1/chat/completions$", "/v1/models")
    local res = vim.system({
        "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "3",
        "-H", "Authorization: Bearer " .. api_key(), url,
    }, { text = true }):wait()
    local code = (res.stdout or ""):match("(%d%d%d)") or "000"
    if code:match("^2") then
        return "ok", code
    elseif code == "401" or code == "403" then
        return "unauthorized", code
    end
    return "absent", code
end

local function request_tool_call()
    local body = vim.json.encode({
        model = MODEL,
        stream = true,
        stream_options = { include_usage = true },
        messages = {
            { role = "user", content = "Call get_weather for Paris. Use the tool; do not answer directly." },
        },
        tools = { {
            type = "function",
            ["function"] = {
                name = "get_weather",
                description = "Get the current weather for a city",
                parameters = {
                    type = "object",
                    properties = { city = { type = "string" } },
                    required = { "city" },
                },
            },
        } },
        tool_choice = "auto",
    })
    local res = vim.system({
        "curl", "-s", "--max-time", "90",
        "-H", "Authorization: Bearer " .. api_key(),
        "-H", "content-type: application/json",
        "-X", "POST", endpoint(), "-d", body,
    }, { text = true }):wait()
    return res.stdout or ""
end

describe("cliproxyapi openai tool-wire conformance (live)", function()
    it("still emits the delta fields the decoder reads", function()
        if not ENABLED then
            -- Loud skip: a silent pass would let the contract rot unnoticed.
            print("SKIP: set PARLEY_LIVE_CONFORMANCE=1 to verify the live tool wire")
            return
        end
        local state, code = probe_proxy()
        if state == "unauthorized" then
            print("SKIP: a proxy is listening at " .. endpoint() .. " but rejected our key (" ..
                  code .. ") — set CLIPROXYAPI_API_KEY to the one in the running " ..
                  "instance's config (api-keys), then re-run")
            return
        elseif state ~= "ok" then
            print("SKIP: no cliproxyapi listening at " .. endpoint() ..
                  " (curl code " .. code .. ") — nothing to conform against")
            return
        end

        local raw = request_tool_call()

        -- An expired credential is an environment problem, not wire drift.
        -- Name it rather than failing as a shape mismatch.
        if raw:find("auth_unavailable", 1, true) or raw:find("authentication_error", 1, true) then
            print("SKIP: cliproxy has no usable credential for " .. MODEL ..
                  " — run `:ParleyProxy login codex`. Raw: " .. raw:sub(1, 200))
            return
        end

        assert.is_truthy(raw:find("tool_calls", 1, true),
            "no tool_calls in the response — the model did not call the tool, or the wire changed. Raw: "
            .. raw:sub(1, 400))

        -- Walk the stream and confirm each required field appears somewhere.
        local seen = {}
        for line in raw:gmatch("[^\n]+") do
            if line:sub(1, 6) == "data: " then
                local decoded = require("parley.sse").safe_json_decode(
                    require("parley.sse").strip_data_prefix(line))
                local choice = type(decoded) == "table" and decoded.choices and decoded.choices[1]
                if type(choice) == "table" then
                    if choice.finish_reason then
                        seen.finish_reason = choice.finish_reason
                    end
                    local tcs = type(choice.delta) == "table" and choice.delta.tool_calls
                    for _, tc in ipairs(type(tcs) == "table" and tcs or {}) do
                        if tc.index ~= nil then seen["index"] = true end
                        if tc.id ~= nil then seen["id"] = true end
                        local fn = tc["function"]
                        if type(fn) == "table" then
                            if fn.name ~= nil then seen["function.name"] = true end
                            if fn.arguments ~= nil then seen["function.arguments"] = true end
                        end
                    end
                end
            end
        end

        for _, field in ipairs(REQUIRED_DELTA_FIELDS) do
            assert.is_true(seen[field] == true,
                "cliproxyapi no longer emits delta.tool_calls[]." .. field ..
                " — wire_openai.decode_tool_calls_from_stream depends on it")
        end
        assert.equals("tool_calls", seen.finish_reason,
            "expected finish_reason=tool_calls on a tool turn")

        -- And the decoder itself must still produce a usable ToolCall.
        local calls = wire_openai.decode_tool_calls_from_stream(raw)
        assert.is_true(#calls >= 1, "decoder produced no calls from a live tool response")
        assert.equals("get_weather", calls[1].name)
        assert.equals("string", type(calls[1].id))
        assert.equals("table", type(calls[1].input))
        assert.is_truthy(calls[1].input.city, "expected the model to fill in `city`")
    end)

    it("routes this model to the openai wire (the decoder above is the right one)", function()
        -- Cheap and offline: pins the routing assumption the live check rests
        -- on, so a routing regression is not mistaken for wire drift.
        assert.equals("openai", providers.cliproxy_route(MODEL,
            providers.cliproxy_strategy({ model = MODEL })))
    end)
end)
