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
--
-- Decode first: cliproxy wraps Go errors with %q, so its messages routinely
-- CONTAIN escaped quotes — e.g.
--   Post \"https://api.anthropic.com/v1/messages\": dial tcp: …
-- and a `"message"%s*:%s*"(.-)"` pattern stops at the first one, leaving the
-- operator with the fragment `Post \`. Since verdict.message is the entire
-- payload of the healthy/unknown/quota branches, that would recreate exactly
-- the naked-fragment notice this issue set out to remove. The pattern remains
-- as a fallback for bodies that aren't valid JSON.
local function extract_message(body)
    local ok, decoded = pcall(vim.json.decode, body)
    if ok and type(decoded) == "table" then
        local err = decoded.error
        if type(err) == "table" and type(err.message) == "string" then
            return err.message
        end
        if type(err) == "string" then
            return err
        end
        if type(decoded.message) == "string" then
            return decoded.message
        end
    end
    local captured = body:match('"message"%s*:%s*"(.-)"')
    if captured then
        return (captured:gsub("\\\\", "\\"):gsub('\\"', '"'))
    end
    return body
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
    -- 0 is curl's "no HTTP response at all" — same epistemic position as nil, so
    -- it gets the same answer: never classify what you cannot situate.
    if type(http_status) ~= "number" or http_status == 0
        or (http_status >= 200 and http_status <= 299) then
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

--------------------------------------------------------------------------------
-- Credential health, read from /v0/management/auth-files
--------------------------------------------------------------------------------

-- Worst-to-best so "healthiest wins" is a simple max: the proxy routes to any
-- usable credential, so one healthy record makes the channel usable regardless
-- of how many dead ones sit beside it.
local HEALTH_RANK = { missing = 0, disabled = 1, unavailable = 2, error = 3, healthy = 4 }

-- Precedence within one record: an operator-disabled credential is disabled
-- even if the proxy also marked it unavailable, and `status` only speaks when
-- neither flag is set.
local function record_state(f)
    if f.disabled then
        return "disabled"
    elseif f.unavailable then
        return "unavailable"
    elseif f.status ~= nil and f.status ~= "active" then
        return "error"
    end
    return "healthy"
end

--- Reduce the management API's record list to one channel's credential state.
---
--- This is the single interpreter of cliproxy's management schema: a field
--- rename upstream lands here and nowhere else.
---@param files table[]|nil # the `files` array from /v0/management/auth-files
---@param channel string # cliproxy channel, e.g. "claude"
---@return table # { state, message, account?, failed?, modtime? }
function M.classify_auth_files(files, channel)
    local best = { state = "missing", message = "no credential for " .. tostring(channel) }
    for _, f in ipairs(type(files) == "table" and files or {}) do
        if (f.provider or f.type) == channel then
            local state = record_state(f)
            if HEALTH_RANK[state] > HEALTH_RANK[best.state] then
                best = {
                    state = state,
                    message = (type(f.status_message) == "string" and f.status_message ~= "")
                        and f.status_message
                        or ("credential is " .. state),
                    account = f.account or f.email,
                    failed = f.failed,
                    modtime = f.modtime,
                }
            end
        end
    end
    return best
end

--------------------------------------------------------------------------------
-- Diagnosis (the sentence a human reads)
--------------------------------------------------------------------------------

--- Render the human diagnosis for a failure, from the verdict plus what the
--- proxy says about its own credential.
---
--- Pure so the wording is unit-tested rather than eyeballed — message text is
--- part of this repo's API (specs assert on it, see workshop/lessons.md). The
--- point of #197 is that this replaces "cliproxyapi response is empty:
--- body_bytes=215" with something that names the credential, its real state,
--- and the next action.
---@param verdict table # from classify_response
---@param health table|nil # from classify_auth_files / auth_files
---@return string
function M.diagnosis(verdict, health)
    health = health or {}
    local model = verdict.model and (' for "' .. verdict.model .. '"') or ""
    local who = health.account and (" (" .. health.account .. ")") or ""
    local because = health.message and health.message ~= "" and (": " .. health.message) or ""
    local failures = (type(health.failed) == "number" and health.failed > 0)
        and (" after %d failed request(s)"):format(health.failed) or ""

    -- Quota and model-availability are NOT login problems; saying "log in" here
    -- sends the operator down a dead end (and re-running OAuth on a
    -- quota-exhausted account changes nothing).
    if verdict.kind == "quota" then
        return ("cliproxy%s: quota or billing refused the request%s — not a login problem")
            :format(model, because ~= "" and because or (": " .. tostring(verdict.message)))
    end
    if verdict.kind == "model_unavailable" then
        return ("cliproxy%s: the model is unavailable upstream%s"):format(model, because)
    end

    local state = health.state
    if state == "missing" then
        return ("cliproxy%s: no credential is loaded for this channel — log in to create one")
            :format(model)
    elseif state == "disabled" then
        return ("cliproxy%s: the credential%s is disabled%s — re-enable it or log in again")
            :format(model, who, because)
    elseif state == "unavailable" or state == "error" then
        return ("cliproxy%s: the credential%s is %s%s%s — log in again to replace it")
            :format(model, who, state, because, failures)
    elseif state == "healthy" then
        -- The proxy believes the credential is fine, so this failure is most
        -- likely transient — say so instead of sending them to a login they
        -- don't need.
        return ("cliproxy%s: the request failed but the credential%s looks healthy: %s")
            :format(model, who, tostring(verdict.message))
    end
    return ("cliproxy%s: could not read credential state (%s)%s; the request failed with: %s")
        :format(model, tostring(health.reason or "unknown"), because, tostring(verdict.message))
end

--------------------------------------------------------------------------------
-- The recovery policy
--------------------------------------------------------------------------------

-- Does the proxy's own error text describe an auth problem? A credential in
-- `error` state can be there for reasons a login won't fix (DNS, upstream 5xx),
-- and sending someone through OAuth for a network blip is its own bug.
local function error_is_auth_shaped(message)
    if type(message) ~= "string" then
        return false
    end
    for _, row in ipairs(FAILURES) do
        if row.kind == "expired" and message:match(row.pattern) then
            return true
        end
    end
    return message:match("[Uu]nauthorized") ~= nil or message:match("[Ee]xpired") ~= nil
end

-- The auth file on disk is newer than the copy the proxy loaded ⇒ its watcher
-- missed a write and a restart will pick it up. Only when BOTH timestamps are
-- present: RFC3339 strings compare lexicographically, but a missing one tells us
-- nothing and guessing "stale" would restart the proxy under every failure.
local function auth_file_is_stale(health, proxy_state)
    local disk = proxy_state and proxy_state.auth_file_modtime
    local loaded = health and health.modtime
    return type(disk) == "string" and type(loaded) == "string" and disk > loaded
end

--- Decide what to do about a failed cliproxy query. Pure: the IO shell gathers
--- the inputs and executes the returned action, so the whole ladder is testable
--- without mocks and there is exactly one place policy lives.
---
--- `attempt` is the entire anti-loop mechanism: at attempt >= 1 no repair action
--- is ever returned, so a retry can never beget another.
---@param verdict table # from classify_response
---@param health table # from classify_auth_files / auth_files
---@param proxy_state table # { running, auth_file_modtime }
---@param attempt number
---@param login_provider string|nil # resolved channel login, if any
---@return table # { action, message, login_provider? }
function M.decide(verdict, health, proxy_state, attempt, login_provider)
    health = health or {}
    proxy_state = proxy_state or {}
    attempt = attempt or 0
    local message = M.diagnosis(verdict, health)
    local repairs_allowed = attempt < 1

    local function prompt_or_report()
        -- A prompt we cannot act on is just a worse report.
        if login_provider then
            return { action = "prompt_login", message = message, login_provider = login_provider }
        end
        return { action = "report", message = message }
    end

    -- Quota and model-availability are never login problems, whatever the
    -- credential looks like.
    if verdict.kind == "quota" or verdict.kind == "model_unavailable" then
        return { action = "report", message = message }
    end

    if not proxy_state.running and repairs_allowed then
        return { action = "start", message = message }
    end

    local state = health.state
    if state == "missing" or state == "disabled" or state == "unavailable" then
        return prompt_or_report()
    end
    if state == "error" then
        if error_is_auth_shaped(health.message) then
            return prompt_or_report()
        end
        return { action = "report", message = message }
    end
    if state == "healthy" then
        -- The proxy believes the credential is good. An `expired` verdict here
        -- is contradictory — believe the credential reading rather than prompt
        -- for a login while displaying "looks healthy".
        if repairs_allowed then
            if auth_file_is_stale(health, proxy_state) then
                return { action = "restart", message = message }
            end
            return { action = "retry", message = message }
        end
        return { action = "report", message = message }
    end
    -- state == "unknown": we could not read credential state. Report honestly
    -- rather than guess at a login.
    return { action = "report", message = message }
end

return M
