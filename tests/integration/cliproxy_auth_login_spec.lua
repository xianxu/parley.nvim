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
    local function serve(overlay)
        local port = free_port()
        local store = vim.fn.tempname()
        vim.fn.mkdir(store, "p")
        vim.fn.writefile({ vim.json.encode({ type = "claude", email = "me@example.com" }) },
            store .. "/claude-me@example.com.json")
        if overlay then
            vim.fn.writefile({ vim.json.encode({ claude = overlay }) }, store .. "/state.json")
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
        serve({ unavailable = true, status = "error",
            status_message = "OAuth access token has expired. Re-authenticate to continue." })
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
        serve({ unavailable = true, status_message = "dead" })
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
        serve({ unavailable = true })
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = true, attempt = 0 })
        assert.is_false(out.claimed)
    end)

    it("does not prompt when the proxy says the credential is healthy", function()
        serve() -- active credential
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        vim.wait(200, function() return false end)
        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled)
        assert.is_false(prompted)
        assert.matches("healthy", out.message)
    end)

    it("tells the operator WHY no login was offered when the model has no alias", function()
        -- Regression for guidance the old check_auth_failure gave and #197's
        -- first cut dropped: with no oauth-model-alias entry parley cannot know
        -- which login to run, and saying only "log in" leaves the operator with
        -- no way to act.
        serve({ unavailable = true, status_message = "dead" })
        parley.config.cliproxy.config["oauth-model-alias"] = {} -- model in no channel
        local prompted = false
        vim.ui.select = function() prompted = true end
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
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
    -- The claim contract: a claim is a debt
    ----------------------------------------------------------------------------

    it("always settles a claim, even when credential state cannot be read", function()
        -- Nothing listening: credential_health returns unreachable.
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(free_port()),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        assert.is_true(out.claimed)
        assert.equals("give_up", out.settled) -- never left hanging
        assert.matches("unreachable", out.message)
    end)

    it("settles even when the operator dismisses the login prompt", function()
        serve({ unavailable = true, status_message = "dead" })
        vim.ui.select = function(_i, _o, cb) cb(nil, 2) end -- "Not now"
        local out = run({ http_status = 503, body = NO_AUTH, model = "claude-opus-4-8",
            streamed = false, attempt = 0 })
        assert.equals("give_up", out.settled)
    end)
end)
