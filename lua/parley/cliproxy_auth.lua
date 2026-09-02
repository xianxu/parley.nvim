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
                    modtime = f.modtime,      -- the credential FILE's mtime
                    updated_at = f.updated_at, -- when the proxy last LOADED it
                    path = f.path,
                }
            end
        end
    end
    return best
end

--- Is `a` a healthier reading than `b`? Same ranking classify_auth_files uses to
--- pick within one channel, exposed so a caller spanning SEVERAL channels (one
--- login provider) can apply it too without duplicating the order.
---@param a table
---@param b table
---@return boolean
function M.healthier(a, b)
    return (HEALTH_RANK[(a or {}).state] or -1) > (HEALTH_RANK[(b or {}).state] or -1)
end


-- Which states can be BLAMED for a request that failed, and in what order.
--
-- A separate ordering from HEALTH_RANK, deliberately — the two answer different
-- questions and inverting one does not produce the other:
--   HEALTH_RANK  "is this account usable?"   → healthy is best, missing is worst
--   CULPRIT_RANK "did this credential fail?" → an errored credential is the
--                 likeliest author of a 401; a healthy one is a poor suspect but
--                 still a possible one.
-- States ABSENT here are not candidates at all:
--   missing   no credential exists, so cliproxy never routed through it
--   disabled  the operator turned it off, so it was not serving either
--   unknown   we could not READ its state (six distinct auth_files failures
--             produce this), which is not evidence of guilt — and it ranks
--             below `missing` in HEALTH_RANK, so an inverted-rank reducer
--             picked it over a genuinely expired credential.
local CULPRIT_RANK = { error = 3, unavailable = 2, healthy = 1 }

--- Could this credential have served the request that just failed?
---
--- Eligibility, not ranking. Excluding only `missing` was not enough: `unknown`
--- (rank -1) and `disabled` (rank 1) both outrank a real `error` under an
--- inverted HEALTH_RANK, so the diagnosis named an unreadable or switched-off
--- channel and left the credential that actually failed unnamed — the #197
--- wrong-account failure, one layer in.
---@param health table|nil
---@return boolean
function M.could_have_served(health)
    return CULPRIT_RANK[(health or {}).state] ~= nil
end

--- Which of several channel readings to blame for a failure.
---
--- Eligibility first, then CULPRIT_RANK, then declared order. Pure and separate
--- from the fan-out that gathers the readings, so the policy is unit-testable
--- without any IO (ARCH-PURE) — it had been hardcoded in the IO shell, which is
--- how the first version of this rule shipped untested.
---
--- With no eligible candidate the answer is the honest one — you are logged into
--- none of these, or we could not read any of them — so the first reading in
--- DECLARED order is returned rather than a state-ranked pick over readings that
--- were all disqualified.
---@param readings table[] # { { health = <table>, channel = <string> }, … } in candidate order
---@return table|nil health, string|nil channel
function M.likeliest_culprit(readings)
    readings = readings or {}
    local best
    for _, r in ipairs(readings) do
        if M.could_have_served(r.health) then
            local rank = CULPRIT_RANK[r.health.state]
            -- strictly greater: ties keep the FIRST, i.e. declared candidate
            -- order, so the named account is reproducible run to run
            if best == nil or rank > CULPRIT_RANK[best.health.state] then
                best = r
            end
        end
    end
    if best then
        return best.health, best.channel
    end
    local first = readings[1]
    return first and first.health or nil, first and first.channel or nil
end

--- The healthiest of several readings — "is this account usable at all".
--- Extracted beside its twin: a branch that names a POLICY belongs in the pure
--- module even when its inputs arrive asynchronously.
---@param readings table[]
---@return table|nil health, string|nil channel
function M.healthiest(readings)
    local best
    for _, r in ipairs(readings or {}) do
        if best == nil or M.healthier(r.health, best.health) then
            best = r
        end
    end
    return best and best.health or nil, best and best.channel or nil
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
-- Peer proxies (issue #197 M3)
--------------------------------------------------------------------------------

-- brew installs `cliproxyapi`; the release tarball ships `cli-proxy-api`. A
-- survey of the machine that motivated this issue undercounted the leaked
-- proxies because it grepped only one of the two names.
local PROXY_BINARIES = { ["cliproxyapi"] = true, ["cli-proxy-api"] = true }

--- Parse a `ps lstart` stamp ("Fri Jun 12 10:04:21 2026") to epoch seconds.
---
--- Needed because the field begins with the WEEKDAY, so comparing two of them as
--- strings orders by day name — "Fri …" sorts before "Sun …" regardless of year.
---@param lstart string|nil
---@return number|nil
function M.lstart_sec(lstart)
    if type(lstart) ~= "string" then
        return nil
    end
    local mon, day, h, mi, sec, year = lstart:match(
        "^%a+%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)%s+(%d+)$")
    if not mon then
        return nil
    end
    local months = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
        Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }
    local mm = months[mon]
    if not mm then
        return nil
    end
    return M.rfc3339_sec(("%04d-%02d-%02dT%02d:%02d:%02dZ"):format(
        tonumber(year), mm, tonumber(day), tonumber(h), tonumber(mi), tonumber(sec)))
end

--- Parse `ps -o pid,lstart,command` into the cliproxy processes parley neither
--- spawned nor manages — the ones quietly sharing an auth-dir with it.
---
--- Matching is on the EXECUTABLE (the command's first token), never on a
--- substring: a real `ps` on the machine that motivated #197 contained a `zsh -c`
--- wrapper whose command line quoted the proxy path inside an `eval`, and a
--- substring match would have SIGTERMed the operator's shell.
---@param ps_output string|nil
---@param own_pids number[] # pids parley spawned this session
---@param managed_port_pids number[] # pids holding the managed port
---@return table[] # { pid, started, command }
function M.parse_peers(ps_output, own_pids, managed_port_pids)
    if type(ps_output) ~= "string" then
        return {}
    end
    local exclude = {}
    for _, list in ipairs({ own_pids or {}, managed_port_pids or {} }) do
        for _, pid in ipairs(list) do
            exclude[pid] = true
        end
    end
    local peers = {}
    for line in ps_output:gmatch("[^\n]+") do
        -- pid, lstart (Www Mmm DD HH:MM:SS YYYY), then the command
        local pid, started, command = line:match(
            "^%s*(%d+)%s+(%a+%s+%a+%s+%d+%s+[%d:]+%s+%d+)%s+(.+)$")
        if pid and command then
            local exe = command:match("^(%S+)")
            local base = exe and exe:match("([^/]+)$")
            if base and PROXY_BINARIES[base] and not exclude[tonumber(pid)] then
                peers[#peers + 1] = {
                    pid = tonumber(pid),
                    started = started,
                    command = command,
                }
            end
        end
    end
    return peers
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

--- Parse an RFC3339 timestamp to epoch seconds. Handles the offset and the
--- fractional seconds cliproxy emits (`2026-08-01T00:34:46.994488305-07:00`).
---
--- Exists because a string compare across representations is WRONG, not merely
--- fragile: the same instant is `…T18:35:01Z` on one side and `…T11:35:01-07:00`
--- on the other, and `"1" > "8"` is false while `"Z" > "-"` is true — so the
--- comparison's answer depends on the operator's timezone, not on the files.
---@param ts string|nil
---@return number|nil epoch_seconds
function M.rfc3339_sec(ts)
    if type(ts) ~= "string" then
        return nil
    end
    local y, mo, d, h, mi, sec = ts:match("^(%d+)-(%d+)-(%d+)[Tt](%d+):(%d+):(%d+)")
    if not y then
        return nil
    end
    local yy, mm, dd = tonumber(y), tonumber(mo), tonumber(d)
    -- Total by contract: anything unparseable — including an out-of-range month
    -- — returns nil like every other bad input. This function runs inside an
    -- ASYNC callback, outside the dispatcher's synchronous claim guard, so a
    -- throw here would settle nothing and strand the chat leg.
    if mm < 1 or mm > 12 or dd < 1 or dd > 31 then
        return nil
    end
    -- Leap days STRICTLY BEFORE year yy. Using yy itself counts its own leap day,
    -- which the mm > 2 adjustment below does not cancel — that put every date in
    -- a leap year one day ahead and silently killed the staleness comparison for
    -- all of 2028 onward.
    local prev = yy - 1
    local days = (yy * 365) + math.floor(prev / 4) - math.floor(prev / 100) + math.floor(prev / 400)
    local mdays = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
    local leap = (yy % 4 == 0 and yy % 100 ~= 0) or yy % 400 == 0
    days = days + mdays[mm] + dd - 1 + ((leap and mm > 2) and 1 or 0)
    -- days counted from year 0; subtract the epoch's own count (1970-01-01)
    local epoch_days = (1970 * 365) + math.floor(1969 / 4) - math.floor(1969 / 100)
        + math.floor(1969 / 400)
    local total = (days - epoch_days) * 86400 + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(sec)
    local sign, oh, om = ts:match("([%+%-])(%d%d):?(%d%d)$")
    if sign then
        local offset = tonumber(oh) * 3600 + tonumber(om) * 60
        total = total + (sign == "+" and -offset or offset)
    end
    return total
end

-- Filesystem mtimes and cliproxy's reported modtime have second-or-worse
-- agreement, so require a real gap before calling a file newer.
local STALE_SKEW_SEC = 2

-- The credential FILE is newer than the moment the proxy LOADED it ⇒ its
-- fsnotify watcher missed a write and a restart will pick it up.
--
-- Both quantities come from the same record: `modtime` is the file's mtime,
-- re-stat'd by the proxy per request, and `updated_at` is when the proxy last
-- (re)loaded that credential into memory. They are independent — pinned against
-- the real binary by cliproxy_conformance_spec.
--
-- NB the gap opens only when the proxy's watcher MISSED a write. fsnotify
-- observes attribute changes too, so an ordinary touch usually does trigger a
-- reload and both advance together — correctly yielding "not stale". This rung
-- is for the case where the reload did not happen, which is why the check is
-- `modtime > updated_at + skew` rather than any assumption about what a
-- particular kind of write does.
--
-- The previous three attempts all compared `modtime` against the file's mtime
-- read independently — the SAME quantity — so the comparison was self-referential
-- and this rung was dead code. Fixing the comparison twice (timezone, then
-- calendar) never surfaced it, because the bug was in the operands.
local function auth_file_is_stale(health)
    local on_disk = M.rfc3339_sec(health and health.modtime)
    local loaded = M.rfc3339_sec(health and health.updated_at)
    return on_disk ~= nil and loaded ~= nil and on_disk > loaded + STALE_SKEW_SEC
end

--- What a credential's health alone implies, independent of any request that
--- failed: `prompt_login`, `report`, or nil when the credential is fine.
---
--- Shared by `decide` (the dispatch failure path) and `:ParleyProxy models`, so
--- the two cannot disagree about what "error" means — the models command used to
--- carry its own three-branch copy of this (ARCH-DRY, ARCH-PURPOSE).
---@param health table
---@param login_provider string|nil
---@return string|nil action
function M.credential_action(health, login_provider)
    local state = (health or {}).state
    local function prompt_or_report()
        -- A prompt we cannot act on is just a worse report.
        return login_provider and "prompt_login" or "report"
    end
    if state == "missing" or state == "disabled" or state == "unavailable" then
        return prompt_or_report()
    end
    if state == "error" then
        -- A credential can be in `error` for reasons a login won't fix (DNS,
        -- upstream 5xx); sending someone through OAuth for a network blip is
        -- its own bug.
        if error_is_auth_shaped(health.message) then
            return prompt_or_report()
        end
        return "report"
    end
    if state == "unknown" then
        return "report"
    end
    return nil -- healthy
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

    -- Quota and model-availability are never login problems, whatever the
    -- credential looks like.
    if verdict.kind == "quota" or verdict.kind == "model_unavailable" then
        return { action = "report", message = message }
    end

    if not proxy_state.running and repairs_allowed then
        return { action = "start", message = message }
    end

    local credential = M.credential_action(health, login_provider)
    if credential then
        return { action = credential, message = message, login_provider = login_provider }
    end
    -- credential_action returned nil ⇒ the proxy believes the credential is
    -- good, so the failure was transient. An `expired` verdict here is
    -- contradictory — believe the credential reading rather than prompt for a
    -- login while displaying "looks healthy".
    if repairs_allowed then
        if auth_file_is_stale(health, proxy_state) then
            return { action = "restart", message = message }
        end
        return { action = "retry", message = message }
    end
    return { action = "report", message = message }
end

return M
