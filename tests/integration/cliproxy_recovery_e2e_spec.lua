-- #197 M2: the whole path, end to end — a real HTTP failure from the fake, in
-- through dispatcher.query, out through recover_query, to what the operator
-- reads. Every earlier spec exercised one link; the M1 review's top coverage
-- gap was that nothing joined them.

local uv = vim.uv or vim.loop
local parley = require("parley")
local ready_port = require("tests.helpers.ready_port")
local dispatcher = require("parley.dispatcher")
local cliproxy = require("parley.cliproxy")
local chat_respond = require("parley.chat_respond")
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname())

describe("cliproxy recovery end to end", function()
    local saved_config, saved_providers, saved_path, started

    -- Boot the fake serving `error_mode` on /v1/chat/completions, with a
    -- credential store whose claude channel carries `overlay`.
    local function serve(error_mode, overlay, alias)
        local port = ready_port.free_port()
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
        local handle, pid = uv.spawn(FAKE, {
            args = { "-config", cfg_file },
            env = { "PARLEY_FAKE_ERROR_MODE=" .. error_mode, "PATH=" .. vim.env.PATH,
                    "HOME=" .. vim.env.HOME },
        }, function() end)
        assert(handle, "failed to spawn fake_cliproxy")
        table.insert(started, { handle = handle, pid = pid })
        ready_port.wait_listening(port)

        dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        parley.dispatcher = dispatcher
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        parley.config = {
            cliproxy = {
                manage = true,
                binary_path = FAKE,
                auth_dir = store,
                config = {
                    -- Parameterised so a case can run with an EMPTY block, which
                    -- is what the default config ships after #205 M4. A spec that
                    -- always builds its own pin passes whether or not channel
                    -- resolution still works without one.
                    ["oauth-model-alias"] = alias ~= nil and alias or {
                        claude = { { name = "claude-opus-4-8", alias = "claude-opus-4-8" } },
                    },
                },
            },
        }
        return port
    end

    -- Drive one real query and collect what the operator would be told.
    local function query()
        local out = { notices = {}, done = false }
        dispatcher.query(nil, "cliproxyapi",
            { model = "claude-opus-4-8", messages = {}, stream = false },
            function() end, nil, nil, nil, nil, nil,
            function(_qid, failure)
                out.failure = failure
                out.notice = chat_respond._failure_notice(failure)
                out.done = true
            end)
        vim.wait(20000, function() return out.done end, 25)
        return out
    end

    before_each(function()
        saved_config = parley.config
        saved_providers = vim.deepcopy(dispatcher.providers)
        saved_path = vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- never find a real cliproxyapi
        started = {}
        cliproxy._reset_login_prompt()
        cliproxy._reset_management_restart()
        vim.ui.select = function(_i, _o, cb) cb(nil, 2) end -- always "Not now"
    end)

    after_each(function()
        parley.config = saved_config
        dispatcher.providers = saved_providers
        vim.env.PATH = saved_path
        for _, p in ipairs(started) do
            pcall(function() uv.kill(p.pid, "sigkill") end)
        end
        for _, pid in ipairs(cliproxy.spawned_pids()) do
            pcall(function() uv.kill(pid, "sigkill") end)
        end
        cliproxy._reset_spawned()
    end)

    it("turns the #197 503 into a diagnosis naming the credential and its real state", function()
        serve("no_auth", { unavailable = true, status = "error",
            status_message = "OAuth access token has expired. Re-authenticate to continue." })
        local out = query()

        assert.is_truthy(out.failure, "the query never reported a failure")
        assert.equals(503, out.failure.http_status)
        -- What the operator actually reads. Before #197 this was
        -- "cliproxyapi response is empty: body_bytes=215" plus naked JSON.
        assert.matches("me@example.com", out.notice)
        assert.matches("expired", out.notice)
        assert.is_nil(out.notice:find("body_bytes", 1, true))
    end)

    it("names the claude login for an expired token with NO alias block", function()
        -- The load-bearing case for M4. Every other case here builds its own
        -- oauth-model-alias, so they pass whether or not the block is required —
        -- which is exactly why deleting it from the default config needs a case
        -- that runs WITHOUT one. Channel resolution must come from the catalog.
        local cliproxy = require("parley.cliproxy")
        cliproxy._write_catalog({
            { id = "claude-opus-4-8", owner = "anthropic", display = "Claude Opus 4.8" },
        })
        -- The claude credential must actually BE unhealthy in the store: this
        -- case is "an EXPIRED token names the claude login", and with a healthy
        -- store there is no expired credential to name. Before the eligibility
        -- fix, a `missing` antigravity reading was chosen instead and produced a
        -- plausible-looking "no credential is loaded" message — the test passed
        -- while parley pointed the operator at the wrong channel.
        serve("expired", { unavailable = true, status = "error",
            status_message = "OAuth access token has expired. Re-authenticate to continue." },
            {})   -- empty alias block

        local out = query()

        assert.is_string(out.notice)
        -- NOT `find("claude")`: the MODEL ID contains "claude", so that passes
        -- even when resolution fails completely. What distinguishes the two is
        -- whether a channel resolved at all — with the catalog fallback removed
        -- the diagnosis degrades to "unknown_channel: no cliproxy channel is
        -- configured", which is precisely the M4 regression.
        assert.is_nil(out.notice:find("unknown_channel", 1, true),
            "channel resolution fell back to nothing without an alias block: " .. out.notice)
        assert.is_nil(out.notice:find("no cliproxy channel is configured", 1, true),
            "the catalog should have resolved the channel: " .. out.notice)
        -- Names the CLAUDE account, not merely "a credential": the whole point
        -- is which channel to re-authenticate. antigravity is the other
        -- candidate for anthropic-owned models and holds no credential at all,
        -- so it cannot have served this request.
        -- Only the ACCOUNT discriminates. The channel name reaches only
        -- vim.ui.select (which this spec stubs), so an "antigravity" guard here
        -- can never fail, and "Add it to" is a literal any rewrite clears while
        -- still recommending the key — both were inert and are gone.
        assert.matches("me@example.com", out.notice)
        assert.matches("expired", out.notice)
    end)

    it("repairs and completes a transient failure with no operator interaction", function()
        -- The fake fails the first request and succeeds after, which is exactly
        -- what "transient" means — and avoids racing the retry by swapping
        -- servers mid-flight.
        serve("no_auth_once")
        local prompted = false
        vim.ui.select = function() prompted = true end

        local out = { done = false, content = "" }
        dispatcher.query(nil, "cliproxyapi",
            { model = "claude-opus-4-8", messages = {}, stream = false },
            function(_qid, chunk) out.content = out.content .. chunk end,
            nil,
            function() out.done = true end,
            nil, nil, nil,
            function(_qid, failure) out.failure = failure; out.done = true end)

        vim.wait(20000, function() return out.done end, 25)

        assert.is_false(prompted, "a self-repairable failure prompted the operator")
        -- The Done-when is "repaired AND the query retried", so absence of a
        -- prompt is not enough — the answer has to actually arrive.
        assert.is_nil(out.failure, "the retried query still failed")
        assert.is_true(out.done, "the query never completed")
        assert.matches("ok", out.content)
    end)

    it("does not call a quota failure a login problem", function()
        serve("quota")
        local out = query()
        assert.is_truthy(out.failure)
        assert.matches("quota", out.notice)
        assert.is_nil(out.notice:lower():find("log in"))
    end)

    it("leaves a non-cliproxy provider's failure path untouched", function()
        -- The seam is opt-in per adapter; openai has no recover_query.
        serve("no_auth")
        local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused
        dispatcher.providers.openai = dispatcher.providers.cliproxyapi
        require("parley.vault").add_secret("openai", "testkey")
        local out = { done = false }
        dispatcher.query(nil, "openai", { model = "gpt-4", messages = {}, stream = false },
            function() end, nil, nil, nil, nil, nil,
            function(_qid, failure) out.failure = failure; out.done = true end)
        vim.wait(15000, function() return out.done end, 25)
        assert.is_truthy(out.failure)
        assert.is_nil(out.failure.message) -- no diagnosis: nothing claimed it
        assert.is_truthy(port)
    end)
end)
