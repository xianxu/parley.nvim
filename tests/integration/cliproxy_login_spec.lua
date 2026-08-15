-- #197 M3: the login flow must be observable. Tonight's failure was a login
-- that died mid-flow — its callback listener went with it, the browser redirect
-- had nowhere to land, and NOTHING reported the death.

local uv = vim.uv or vim.loop
local parley = require("parley")
local cliproxy = require("parley.cliproxy")
local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname())

describe("cliproxy login", function()
    local saved_config, saved_notify, saved_open, saved_path, notices, opened, store

    local function await(fn, timeout)
        local out, got = nil, false
        fn(function(r) out = r; got = true end)
        vim.wait(timeout or 15000, function() return got end, 25)
        return got, out
    end

    before_each(function()
        saved_config = parley.config
        saved_notify = vim.notify
        saved_open = vim.ui.open
        saved_path = vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        notices, opened = {}, {}
        store = vim.fn.tempname()
        vim.fn.mkdir(store, "p")
        vim.notify = function(m, l) notices[#notices + 1] = { msg = tostring(m), level = l } end
        vim.ui.open = function(u) opened[#opened + 1] = u end
        parley.config = { cliproxy = { manage = true, binary_path = FAKE, auth_dir = store } }
        -- login_argv renders the config, which needs an endpoint + the vault
        -- secret; without them the binary starts with a broken config.
        parley.dispatcher = parley.dispatcher or {}
        parley.dispatcher.providers = parley.dispatcher.providers or {}
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = "http://127.0.0.1:8317/v1/chat/completions",
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
    end)

    after_each(function()
        parley.config = saved_config
        vim.notify = saved_notify
        vim.ui.open = saved_open
        vim.env.PATH = saved_path
        vim.env.PARLEY_FAKE_LOGIN_MODE = nil
    end)

    local function all_notices()
        local out = {}
        for _, n in ipairs(notices) do out[#out + 1] = n.msg end
        return table.concat(out, "\n")
    end

    it("surfaces the authorize URL so a failed auto-open is still recoverable", function()
        vim.env.PARLEY_FAKE_LOGIN_MODE = "success"
        local ok = await(function(done)
            cliproxy.run_login("claude", (cliproxy.login_argv("claude")), done)
        end)
        assert.is_true(ok, "login never settled")
        assert.matches("oauth/authorize", all_notices())
        -- parley does NOT open the URL itself any more: the binary keeps its own
        -- browser flow (which differs per provider), and parley adds visibility.
        assert.equals(0, #opened)
    end)

    it("surfaces the login's own output for ANY provider, not just claude", function()
        -- The regression this replaces: parley passed -no-browser and matched
        -- only a claude.ai/oauth/authorize URL, so google/kimi/xai/antigravity
        -- logins showed the operator nothing at all and could not be completed.
        vim.env.PARLEY_FAKE_LOGIN_MODE = "success"
        local settled = await(function(done)
            cliproxy.run_login("claude", (cliproxy.login_argv("claude")), done)
        end)
        assert.is_true(settled)
        -- Whatever the binary printed reaches the operator verbatim.
        assert.matches("Visit the following URL", all_notices())
    end)

    it("reports success with the account once a credential is written", function()
        vim.env.PARLEY_FAKE_LOGIN_MODE = "success"
        local settled, result = await(function(done)
            cliproxy.run_login("claude", (cliproxy.login_argv("claude")), done)
        end)
        assert.is_true(settled)
        assert.is_true(result, "a successful login reported failure")
        assert.matches("login succeeded", all_notices())
    end)

    it("reports a login that dies instead of failing silently", function()
        -- The #197 failure mode exactly.
        vim.env.PARLEY_FAKE_LOGIN_MODE = "dies_early"
        local settled, result = await(function(done)
            cliproxy.run_login("claude", (cliproxy.login_argv("claude")), done)
        end, 20000)
        assert.is_true(settled, "a dead login never settled — the silent hang is back")
        assert.is_false(result)
        assert.matches("exited 3", all_notices())
    end)

    it("an abandoned watcher never speaks after the login already settled", function()
        -- Round 3 fixed the settle COUNT but not the operator-visible half: the
        -- watcher kept polling to its deadline and then told an operator who had
        -- since logged in that their login "did not complete".
        vim.env.PARLEY_FAKE_LOGIN_MODE = "dies_early"
        local settles = 0
        local settled_at
        cliproxy.run_login("claude", (cliproxy.login_argv("claude")), function()
            settles = settles + 1
            settled_at = #notices
        end)
        vim.wait(8000, function() return settles > 0 end, 25)
        assert.equals(1, settles)
        assert.matches("exited 3", all_notices())

        -- Nothing further may be said, however long the abandoned watch runs.
        local after = #notices
        vim.wait(3000, function() return #notices > after end, 100)
        assert.equals(after, #notices, "the abandoned watcher notified after settling")
        assert.is_nil(all_notices():find("did not complete", 1, true))
        assert.is_truthy(settled_at)
    end)

    it("reports a login that hangs, once, with the re-run instruction", function()
        -- The timeout branch: the binary prints its URL and no credential ever
        -- lands (the operator abandons the browser tab). Reachable only because
        -- run_login takes an injectable timeout — it was dead code before.
        vim.env.PARLEY_FAKE_LOGIN_MODE = "hangs"
        local settles = 0
        local result
        cliproxy.run_login("claude", (cliproxy.login_argv("claude")), function(ok)
            settles = settles + 1
            result = ok
        end, 1500)
        vim.wait(12000, function() return settles > 0 end, 25)

        assert.equals(1, settles)
        assert.is_false(result)
        assert.matches("did not complete", all_notices())
        assert.matches("Re%-run", all_notices())

        -- and it stays settled: no second word from the abandoned job
        local after = #notices
        vim.wait(2000, function() return #notices > after end, 100)
        assert.equals(after, #notices)
    end)

    it("settles even when the auth-dir holds an unreadable entry", function()
        -- readfile RAISES on a directory (E17) and on a file that vanished
        -- (E484 — peer proxies rotate credentials every 15 minutes). The watch
        -- runs in an async poll with no outer guard, so a raise there would
        -- strand the login exactly the way #197 §5 describes.
        vim.fn.mkdir(store .. "/trap.json", "p") -- a DIRECTORY named like a credential
        local settles = 0
        local result
        cliproxy.run_login("claude", (cliproxy.login_argv("claude")), function(ok)
            settles = settles + 1
            result = ok
        end, 1500)
        vim.wait(12000, function() return settles > 0 end, 25)
        assert.equals(1, settles, "an unreadable auth-dir entry stranded the login watch")
        assert.is_boolean(result)
    end)

    it("preflights the callback port and names the remedy", function()
        if cliproxy.callback_port_blocked("claude") then
            print("SKIP: :54545 already held on this machine")
            return
        end
        -- Hold the port in-process: a spawned holder would outlive the spec.
        local holder = uv.new_tcp()
        local bound, err = holder:bind("127.0.0.1", 54545)
        if not bound or err then
            pcall(function() holder:close() end)
            print("SKIP: could not bind :54545 here")
            return
        end
        holder:listen(1, function() end)

        local blocked = cliproxy.callback_port_blocked("claude")
        holder:close()

        assert.is_truthy(blocked, "a held callback port was not detected")
        assert.matches("54545", blocked)
        assert.matches("lsof", blocked)                   -- how to find the holder
        assert.matches("oauth%-callback%-port", blocked)  -- the escape hatch
    end)

    it("reports a free callback port as free", function()
        assert.is_nil(cliproxy.callback_port_blocked("claude"))
    end)

    it("has no callback-port opinion about providers it doesn't know", function()
        assert.is_nil(cliproxy.callback_port_blocked("kimi"))
    end)

    it("await_credential times out rather than waiting forever", function()
        local settled, ok = await(function(done)
            cliproxy.await_credential("claude", nil, 1200, done)
        end, 6000)
        assert.is_true(settled)
        assert.is_false(ok)
    end)

    it("await_credential sees a credential that appears after the watch starts", function()
        local settled, ok = await(function(done)
            cliproxy.await_credential("claude", nil, 8000, done)
            vim.defer_fn(function()
                vim.fn.writefile({ vim.json.encode({ type = "claude", email = "late@example.com" }) },
                    store .. "/claude-late@example.com.json")
            end, 300)
        end, 12000)
        assert.is_true(settled)
        assert.is_true(ok)
    end)
end)
