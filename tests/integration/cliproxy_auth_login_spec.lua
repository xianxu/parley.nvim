-- #197: cliproxy.recover is the single owner of "the query failed for
-- credential reasons". It replaces #131 M3's check_auth_failure, which sat on
-- the SUCCESS path and matched one stale message.
--
-- Runs against the process-level fake, not function mocks: recover's whole job
-- is to consult the proxy's management API, so a mock would test nothing.

local uv = vim.uv or vim.loop
local parley = require("parley")
local cliproxy = require("parley.cliproxy")
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname()) -- never touch the real ~/.local/share/nvim

local MANAGED = {
    cliproxy = {
        manage = true,
        binary_path = FAKE,
        config = {
            ["oauth-model-alias"] = {
                claude = { { name = "claude-opus-4-8", alias = "claude-opus-4-8", fork = true } },
                -- A channel whose LOGIN PROVIDER differs from its channel name
                -- (gemini-cli → google). claude is the one case where the two
                -- coincide, which is why a claude-only fixture hid C1.
                ["gemini-cli"] = { { name = "gemini-2.5-pro", alias = "gemini-2.5-pro", fork = true } },
            },
        },
    },
}

-- The exact 503 body from the outage.
local NO_AUTH = '{"type":"error","error":{"type":"api_error","message":"auth_unavailable: '
    .. 'no auth available (providers=claude, model=claude-opus-4-8); check Claude auth/key '
    .. 'session and cooldown state via /v0/management/auth-files"}}'

describe("cliproxy.recover", function()
    local saved_config, saved_select, saved_path, started

    local function free_port()
        local s = uv.new_tcp()
        s:bind("127.0.0.1", 0)
        local port = s:getsockname().port
        s:close()
        return port
    end

    local function wait_listening(port)
        vim.wait(5000, function()
            local ok = false
            local c = uv.new_tcp()
            c:connect("127.0.0.1", port, function(err)
                ok = err == nil
                c:close()
            end)
            vim.wait(100, function() return false end)
            return ok
        end, 50)
    end

    -- Start the fake with a credential store, optionally overlaying a broken
    -- state onto the claude channel, and point parley's endpoint at it.
    local function serve(overlays)
        local port = free_port()
        local store = vim.fn.tempname()
        vim.fn.mkdir(store, "p")
        vim.fn.writefile({ vim.json.encode({ type = "claude", email = "me@example.com" }) },
            store .. "/claude-me@example.com.json")
        vim.fn.writefile({ vim.json.encode({ type = "gemini-cli", email = "g@example.com" }) },
            store .. "/gemini-cli-g@example.com.json")
        if overlays then
            -- Full channel → state map, so a test can break a NON-claude channel.
            vim.fn.writefile({ vim.json.encode(overlays) }, store .. "/state.json")
        end
        local cfg_file = vim.fn.tempname() .. ".json"
        vim.fn.writefile({ vim.json.encode({
            port = port, ["auth-dir"] = store, ["api-keys"] = { "testkey" },
            ["remote-management"] = { ["secret-key"] = cliproxy.management_key() },
        }) }, cfg_file)
        local handle, pid = uv.spawn(FAKE, { args = { "-config", cfg_file } }, function() end)
        assert(handle, "failed to spawn fake_cliproxy")
        table.insert(started, { handle = handle, pid = pid })
        wait_listening(port)
        parley.dispatcher = parley.dispatcher or {}
        parley.dispatcher.providers = parley.dispatcher.providers or {}
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        return store
    end

    -- Drive recover and collect the outcome. Returns
    -- { claimed, settled = "retry"|"give_up", message, prompt }.
    local function run(failure)
        local out = { settled = nil }
        out.claimed = cliproxy.recover(failure,
            function() out.settled = "retry" end,
            function(msg) out.settled = "give_up"; out.message = msg end)
        if out.claimed then
            vim.wait(6000, function() return out.settled ~= nil end, 20)
        end
        return out
    end

    before_each(function()
        saved_config = parley.config
        saved_select = vim.ui.select
        saved_path = vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no real cliproxyapi (#197)
        started = {}
        parley.config = vim.deepcopy(MANAGED)
        cliproxy._reset_login_prompt()
        cliproxy._reset_management_restart()
    end)

    after_each(function()
        parley.config = saved_config
        vim.ui.select = saved_select
        vim.env.PATH = saved_path
        vim.ui.select = saved_select
        for _, p in ipairs(started) do
            pcall(function() uv.kill(p.pid, "sigkill") end)
        end
        for _, pid in ipairs(cliproxy.spawned_pids()) do
            pcall(function() uv.kill(pid, "sigkill") end)
        end
        cliproxy._reset_spawned()
    end)

    ----------------------------------------------------------------------------
    -- What the outage should have produced
    ----------------------------------------------------------------------------

    it("claims the #197 503, prompts the right login, and reports the real reason", function()
        serve({ claude = { unavailable = true, status = "error",
            status_message = "OAuth access token has expired. Re-authenticate to continue." } })
        local prompt
        vim.ui.select = function(_items, opts, cb)
            prompt = opts.prompt
            cb(nil, 2) -- "Not now" — never actually run the login in a test
        end

        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })

        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled)
        assert.is_truthy(prompt)
        -- The diagnosis must carry the account and the proxy's own reason —
        -- this is what replaced "cliproxyapi response is empty: body_bytes=215".
        assert.matches("me@example.com", out.message)
        assert.matches("expired", out.message)
    end)

    it("prompts the claude login resolved from oauth-model-alias, not the model name", function()
        serve({ claude = { unavailable = true, status_message = "dead" } })
        local prompt
        vim.ui.select = function(_items, opts, cb)
            prompt = opts.prompt
            cb(nil, 2)
        end
        run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8", attempt = 0 })
        assert.is_truthy(prompt)
    end)

    ----------------------------------------------------------------------------
    -- What it must NOT do (the PQ-2 regression and friends)
    ----------------------------------------------------------------------------

    it("does not claim a SUCCESSFUL response that merely talks about auth errors", function()
        serve()
        local prompted = false
        vim.ui.select = function() prompted = true end
        -- Assistant prose from a chat about this very issue.
        local out = run({
            http_status = 200,
            body = "The proxy said authentication_error and 401 unauthorized, then "
                .. "auth_unavailable: no auth available (providers=claude, model=claude-opus-4-8).",
            model = "claude-opus-4-8", attempt = 0,
        })
        vim.wait(200, function() return false end)
        assert.is_false(out.claimed)
        assert.is_false(prompted)
    end)

    it("does not claim a non-credential failure", function()
        serve()
        local out = run({ http_status = 500,
            body = '{"error":{"message":"dial tcp: lookup api.anthropic.com: no such host"}}',
            model = "claude-opus-4-8", attempt = 0 })
        assert.is_false(out.claimed)
    end)

    it("does not claim once content has streamed — a retry would duplicate it", function()
        serve({ claude = { unavailable = true } })
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = true, attempt = 0 })
        assert.is_false(out.claimed)
    end)

    it("RETRIES without prompting when the proxy says the credential is healthy", function()
        -- M2: the credential is fine, so the failure was transient — repair
        -- silently rather than sending the operator to a login they don't need.
        serve() -- active credential
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        assert.equals("retry", out.settled)
        assert.is_false(prompted)
    end)

    it("does not retry a second time — attempt 1 reports instead", function()
        serve()
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 1 })
        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled)
        assert.matches("healthy", out.message)
    end)

    it("tells the operator WHY no login was offered when nothing names a channel", function()
        -- Regression for guidance the old check_auth_failure gave. Note the
        -- BODY here carries no `providers=` field (the 401 form), so the only
        -- possible source of a channel is oauth-model-alias — and it's empty.
        serve()
        parley.config.cliproxy.config["oauth-model-alias"] = {}
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 401,
            body = '{"error":{"message":"OAuth access token has expired."}}',
            model = "claude-opus-4-8", streamed = false, attempt = 0 })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        assert.is_false(prompted)
        assert.matches("oauth%-model%-alias", out.message)
        assert.matches("ParleyProxy login", out.message)
    end)

    it("does not prompt on an expired verdict the proxy calls healthy", function()
        -- Prompting "log in" while the message reads "looks healthy" is
        -- self-contradictory; the credential reading wins.
        serve() -- active credential
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 401,
            body = '{"type":"error","error":{"type":"authentication_error","message":'
                .. '"OAuth access token has expired. Re-authenticate to continue."}}',
            model = "claude-opus-4-8", streamed = false, attempt = 0 })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        assert.is_false(prompted)
    end)

    ----------------------------------------------------------------------------
    -- Channel vs login provider (C1) — they only coincide for claude
    ----------------------------------------------------------------------------

    it("reads health on the CHANNEL axis, not the login-provider axis", function()
        -- A healthy gemini-cli credential must not be reported as missing just
        -- because its login provider is called "google".
        serve()
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({
            http_status = 503,
            body = '{"type":"error","error":{"type":"api_error","message":"auth_unavailable: '
                .. 'no auth available (providers=gemini-cli, model=gemini-2.5-pro)"}}',
            model = "gemini-2.5-pro", streamed = false, attempt = 0,
        })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        -- healthy gemini-cli credential ⇒ transient ⇒ retry, no prompt. Before
        -- the channel fix this reported "no credential is loaded" and prompted.
        assert.equals("retry", out.settled)
        assert.is_false(prompted, "prompted a login for a healthy credential")
    end)

    it("prompts the google login for a dead gemini-cli credential", function()
        serve({ ["gemini-cli"] = { unavailable = true, status_message = "token revoked" } })
        local prompt
        vim.ui.select = function(_i, opts, cb)
            prompt = opts.prompt
            cb(nil, 2)
        end
        local out = run({
            http_status = 503,
            body = '{"type":"error","error":{"message":"auth_unavailable: no auth available '
                .. '(providers=gemini-cli, model=gemini-2.5-pro)"}}',
            model = "gemini-2.5-pro", streamed = false, attempt = 0,
        })
        assert.is_true(out.claimed)
        assert.is_truthy(prompt)
        assert.matches("revoked", out.message)
    end)

    it("refuses to guess a channel when none resolves", function()
        -- Guessing "claude" would confidently report ANOTHER account's health
        -- for the failing model.
        serve()
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 401,
            body = '{"error":{"message":"OAuth access token has expired."}}',
            model = "some-unaliased-model", streamed = false, attempt = 0 })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled)
        assert.is_false(prompted)
        assert.matches("oauth%-model%-alias", out.message)
        assert.is_nil(out.message:find("me@example.com", 1, true))
    end)

    it("EXHAUSTIVE: every decide action settles the claim exactly once", function()
        -- Task 10's guard: a future action added to the enum cannot silently
        -- fall through `execute` and hang the chat leg until the backstop.
        local ca = require("parley.cliproxy_auth")
        local saved_decide = ca.decide
        local actions = { "start", "restart", "retry", "prompt_login", "report" }
        serve()
        vim.ui.select = function(_i, _o, cb) cb(nil, 2) end

        for _, action in ipairs(actions) do
            ca.decide = function(_v, _h, _p, _a, login)
                return { action = action, message = "forced " .. action,
                         login_provider = login or "claude" }
            end
            local settles = 0
            local claimed = cliproxy.recover(
                { http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
                  streamed = false, attempt = 0 },
                function() settles = settles + 1 end,
                function() settles = settles + 1 end)
            assert.is_true(claimed, action .. " did not claim")
            vim.wait(9000, function() return settles > 0 end, 25)
            assert.equals(1, settles, ("action %s settled %d times"):format(action, settles))
        end
        ca.decide = saved_decide
    end)

    ----------------------------------------------------------------------------
    -- The retry rung must not secretly be the restart rung
    ----------------------------------------------------------------------------

    it("does NOT stop the proxy when the credential is healthy", function()
        -- Round 1's #1 recommendation, unimplemented until now: the restart rung
        -- also ends in retry(), so every earlier test passed while `restart`
        -- fired on every healthy failure (a timezone-dependent string compare).
        -- One assertion on stop() would have failed the day that landed.
        serve()
        local stops = 0
        local saved_stop = cliproxy.stop
        cliproxy.stop = function(...)
            stops = stops + 1
            return saved_stop(...)
        end
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        cliproxy.stop = saved_stop

        assert.equals("retry", out.settled)
        assert.equals(0, stops, "the healthy path SIGTERMed the proxy — restart rung, not retry")
    end)

    it("takes the restart rung when the proxy's watcher missed a write", function()
        -- Produced the way the system produces it: the proxy loads the
        -- credential, then the file is touched WITHOUT a content change, which
        -- is what a missed fsnotify reload looks like — modtime advances,
        -- updated_at does not. No fabricated timestamps.
        local store = serve()
        local path = store .. "/claude-me@example.com.json"
        -- first read: the proxy records its load time
        local seeded = false
        cliproxy.credential_health(function() seeded = true end, "claude")
        vim.wait(6000, function() return seeded end, 20)
        assert.is_true(seeded, "could not seed the proxy's load time")
        local stops = 0
        local saved_stop = cliproxy.stop
        cliproxy.stop = function(...)
            stops = stops + 1
            return saved_stop(...)
        end
        local later = os.time() + 600
        vim.loop.fs_utime(path, later, later)

        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        cliproxy.stop = saved_stop

        assert.equals("retry", out.settled) -- the restart rung still ends in a retry
        assert.equals(1, stops, "a missed watcher reload did not trigger the restart rung")
    end)

    ----------------------------------------------------------------------------
    -- The claim contract: a claim is a debt
    ----------------------------------------------------------------------------

    it("starts a proxy that is not running, then retries", function()
        -- M2: nothing listening ⇒ the repair is to start the proxy, not to
        -- lecture the operator about credentials.
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(free_port()),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        assert.is_true(out.claimed)
        assert.equals("retry", out.settled)
    end)

    it("settles rather than hanging when the proxy cannot be started", function()
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(free_port()),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        parley.config.cliproxy.binary_path = "/no/such/bin"
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled) -- never left hanging
    end)

    it("settles with the diagnosis even when the login command raises", function()
        -- :ParleyProxy login opens a window and jobstarts a terminal, so a
        -- constrained layout or a user autocmd can throw. Unguarded, that skips
        -- done(), and the dispatcher's backstop later replaces the diagnosis
        -- parley just showed with "recovery timed out".
        serve({ claude = { unavailable = true, status_message = "token revoked" } })
        vim.ui.select = function(_i, _o, cb) cb(nil, 1) end -- "Log in"
        local saved_cmd = vim.cmd
        vim.cmd = function(c)
            if type(c) == "string" and c:find("Proxy login", 1, true) then
                error("E36: Not enough room")
            end
            return saved_cmd(c)
        end
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        vim.cmd = saved_cmd

        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled)
        assert.matches("revoked", out.message) -- the diagnosis, not a timeout
    end)

    it("settles even when the operator dismisses the login prompt", function()
        serve({ claude = { unavailable = true, status_message = "dead" } })
        vim.ui.select = function(_i, _o, cb) cb(nil, 2) end -- "Not now"
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        assert.equals("give_up", out.settled)
    end)
end)
