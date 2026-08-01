--------------------------------------------------------------------------------
-- Pure auth-failure reasoning for the managed cliproxyapi instance (issue #197).
--
-- No IO, no clock, no vim.* state (ARCH-PURE): every function here is a
-- deterministic transform, unit-tested without mocks. The IO shell
-- (parley/cliproxy.lua) gathers the inputs and executes the action decided here.
--
-- Why this module exists: before #197, parley inferred auth state two ways, and
-- both were wrong on 2026-08-01 — a single response pattern
-- (`unknown provider for model <X>`, which 7.1.71 no longer emits for a dead
-- credential) and the shape of /v1/models (which still lists every model with
-- the credential dead). This module replaces the guessing; the truth comes from
-- the proxy's own /v0/management/auth-files.
--------------------------------------------------------------------------------

local M = {}

-- cliproxyapi's failure vocabulary, most specific first. Verified against the
-- 7.1.71 binary's format strings (`%s (providers=%s, model=%s)`,
-- `unknown provider for model %s`, …). Supporting a new cliproxy error is one
-- row here and nothing else (ARCH-DRY).
--
-- ORDERING CONSTRAINT: the `(providers=…, model=…)` row must precede the bare
-- `auth_unavailable` row, or the captures are silently lost.
local FAILURES = {
    {
        kind = "no_auth",
        pattern = "no auth available %(providers=([%w%-_.]+), model=([%w%-_.]+)%)",
        captures = { "provider", "model" },
    },
    { kind = "no_auth", pattern = "auth_unavailable", captures = {} },
    { kind = "unknown_provider", pattern = "unknown provider for model%s+([%w%-%._]+)", captures = { "model" } },
    { kind = "expired", pattern = "OAuth access token has expired", captures = {} },
    { kind = "expired", pattern = "authentication_error", captures = {} },
    { kind = "expired", pattern = "401 unauthorized", captures = {} },
    { kind = "expired", pattern = "auth_not_found", captures = {} },
    { kind = "quota", pattern = "payment_required", captures = {} },
    { kind = "quota", pattern = "quota%-exceeded", captures = {} },
    { kind = "model_unavailable", pattern = "model unavailable", captures = {} },
}

-- Pull the human sentence out of cliproxy's error envelope (both the
-- OpenAI-shaped and Anthropic-shaped bodies land on the same "message" key).
local function extract_message(body)
    return body:match('"message"%s*:%s*"(.-)"') or body
end

--- Classify a FAILED cliproxy response.
---
--- The status gate is the whole safety story. These patterns are deliberately
--- broad, and the caller sees successful bodies too — a chat *about* this issue
--- quotes `authentication_error`, `401 unauthorized`, and `payment_required` in
--- ordinary assistant prose. A 2xx is never a failure whatever the body says,
--- and a status we cannot place (nil) is not a failure either: never classify
--- what you cannot situate.
---@param http_status number|nil
---@param body string|nil
---@param request_model string|nil # backfills `model` for forms that omit it (the 401)
---@return table|nil # { kind, provider?, model?, message }
function M.classify_response(http_status, body, request_model)
    if type(http_status) ~= "number" or (http_status >= 200 and http_status <= 299) then
        return nil
    end
    if type(body) ~= "string" or body == "" then
        return nil
    end
    for _, row in ipairs(FAILURES) do
        local a, b = body:match(row.pattern)
        if a ~= nil then
            local verdict = { kind = row.kind, message = extract_message(body) }
            local caps = { a, b }
            for i, name in ipairs(row.captures) do
                verdict[name] = caps[i]
            end
            -- The body wins when it names a model; request_model only fills the
            -- gap (the 401 form names neither provider nor model, and without a
            -- model no login channel can be resolved).
            verdict.model = verdict.model or request_model
            return verdict
        end
    end
    return nil
end

return M
