-- #261 M3 Task 3.4: a process outside any generation has nobody to stop it,
-- so it runs to its deadline. When Parley kills it there, the caller reads a
-- failure, and a failure writes no cache and no store. The real tasker runs
-- over the stateful process fake behind its runtime seam; each test fires the
-- deadline timer and lets the fake exit on the signal, as luv reports a kill
-- (code 0, signal 15).
local T = require("parley.tasker")
local Fake = require("tests.helpers.fake_process")

local function wait(fn) assert.is_true(vim.wait(2000, fn, 1)) end

describe("a killed unscoped process is a failure", function()
    local processes, fresh
    before_each(function()
        T._reset()
        T._uv, processes = Fake.new({ finish_on_signal = true })
        fresh = {}
    end)
    after_each(function()
        for _, p in pairs(processes.processes) do p:finish() end
        vim.wait(100, function() return T.stats().active == 0 end, 1)
        T._reset(); T._uv = nil
        for name, module in pairs(fresh) do package.loaded[name] = module end
    end)
    -- A private copy of a module whose state is file-local, restored after.
    local function fresh_module(name)
        fresh[name] = package.loaded[name]
        package.loaded[name] = nil
        return require(name)
    end
    local function fire_deadline(ms)
        for _, timer in ipairs(processes.timers) do
            if timer.delay == ms and timer.callback then timer:fire(); return end
        end
        error("no deadline timer of " .. ms)
    end

    it("a killed keychain read neither caches an empty store nor saves over the keychain", function()
        local oauth = fresh_module("parley.oauth")
        local got
        oauth.load_account_store(function(store) got = store end)
        assert.equals(1, processes.spawn_calls)
        processes.processes[4242]:emit("stdout", '{"version":3,"accounts":[{"account_id":"a"')
        fire_deadline(T.deadline.prompt)
        wait(function() return got ~= nil end)
        assert.same({}, got.accounts)
        local saved = false
        oauth.save_account_store(got, function() saved = true end)
        assert.is_true(saved, "the caller still settles")
        assert.equals(1, processes.spawn_calls, "no keychain write over accounts it could not read")
        oauth.load_account_store(function() end)
        assert.equals(2, processes.spawn_calls, "the unread store was not cached")
    end)

    it("a keychain with no entry still reads as an empty store, cached and saveable", function()
        local oauth = fresh_module("parley.oauth")
        local got
        oauth.load_account_store(function(store) got = store end)
        processes.processes[4242]:finish(44, 0)
        wait(function() return got ~= nil end)
        oauth.load_account_store(function() end)
        assert.equals(1, processes.spawn_calls, "an answered read is cached")
        oauth.save_account_store(got, function() end)
        assert.equals(2, processes.spawn_calls, "and can be saved")
    end)

    it("a killed copilot token fetch reports failure without throwing", function()
        local logger = require("parley.logger")
        local vault = fresh_module("parley.vault")
        local state_dir = vim.fn.tempname(); vim.fn.mkdir(state_dir, "p")
        local errors, error_fn = {}, logger.error
        logger.error = function(message) errors[#errors + 1] = message end
        local ok, err = pcall(function()
            vault.setup({ state_dir = state_dir })
            vault.add_secret("copilot", "fixture-token")
            local called = false
            vault.refresh_copilot_bearer(function() called = true end)
            assert.equals(1, processes.spawn_calls)
            fire_deadline(T.deadline.http)
            wait(function() return #errors > 0 end)
            assert.is_false(called)
        end)
        logger.error = error_fn
        vim.fn.delete(state_dir, "rf")
        assert(ok, err)
        local text = table.concat(errors, "\n")
        assert.truthy(text:find("copilot bearer resolve failed", 1, true), text)
        assert.truthy(text:find("killed: deadline", 1, true), text)
        assert.is_nil(text:find("callback failed", 1, true), text)
    end)

    it("leaving Neovim kills what is left: setup registers one VimLeavePre for tasker.leave", function()
        local root = vim.fn.tempname()
        require("parley").setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {} })
        require("parley").setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {} })
        assert.equals(1, #vim.api.nvim_get_autocmds({ group = "ParleyLeave", event = "VimLeavePre" }),
            "setup twice still registers once")
        T.run(nil, "fixture", {}, nil, nil, nil, nil, { attempt_id = "u", deadline_ms = T.deadline.http })
        -- Only this group's autocmd runs; starter.lua listens on VimLeavePre too.
        vim.api.nvim_exec_autocmds("VimLeavePre", { group = "ParleyLeave" })
        local signal = processes.signals[#processes.signals]
        assert.same({ pid = processes.processes[4241 + processes.spawn_calls].pid, signal = 9 }, signal)
        vim.fn.delete(root, "rf")
    end)

    -- #261 M3 review round 3 (ARCH-SECURE): a process that carries or returns a
    -- secret never has its raw output shown. Each case plants the secret where
    -- that process would put it, and reads every log line and message.
    describe("secret-bearing output stays out of logs", function()
        local logger = require("parley.logger")
        local seen, saved
        before_each(function()
            seen, saved = {}, {}
            for _, level in ipairs({ "error", "warning", "info", "debug" }) do
                saved[level] = logger[level]
                -- A sensitive message follows `log_sensitive` (off by default),
                -- as the logger itself does; everything else is recorded.
                logger[level] = function(message, sensitive)
                    if not sensitive then seen[#seen + 1] = tostring(message) end
                end
            end
        end)
        after_each(function() for level, fn in pairs(saved) do logger[level] = fn end end)
        local function shown(secret)
            for _, line in ipairs(seen) do if line:find(secret, 1, true) then return line end end
        end

        it("the copilot token fetch sends no verbose trace and logs neither output", function()
            local vault = fresh_module("parley.vault")
            local state_dir = vim.fn.tempname(); vim.fn.mkdir(state_dir, "p")
            vault.setup({ state_dir = state_dir })
            vault.add_secret("copilot", "COPILOT_SECRET")
            vault.refresh_copilot_bearer(function() end)
            for _, arg in ipairs(processes.spawn_options[1].args) do
                assert.is_false(arg == "-v" or arg == "--verbose", "a verbose curl writes its headers to stderr")
            end
            local p = processes.processes[4242]
            p:emit("stderr", "> authorization: token COPILOT_SECRET\n")
            p:emit("stdout", '{"token":"BEARER_SECRET"')
            p:finish(22, 0)
            wait(function() return shown("copilot bearer resolve failed") ~= nil end)
            vim.fn.delete(state_dir, "rf")
            assert.is_nil(shown("COPILOT_SECRET"))
            assert.is_nil(shown("BEARER_SECRET"))
        end)

        it("a failed secret command never shows its stdout", function()
            local vault = fresh_module("parley.vault")
            local reported
            vault.resolve_secret("fixture", { "fixture-cmd" }, function() end, function(m) reported = m end)
            local p = processes.processes[4242]
            p:emit("stdout", "PRINTED_SECRET\n"); p:emit("stderr", "gpg: decryption failed\n")
            p:finish(2, 0)
            wait(function() return reported ~= nil end)
            seen[#seen + 1] = reported
            assert.is_nil(shown("PRINTED_SECRET"))
            assert.truthy(shown("gpg: decryption failed"), "its diagnosis is still shown")
            assert.truthy(shown("exit 2"))
        end)

        it("the token exchange shows its OAuth error but never its body", function()
            local oauth = fresh_module("parley.oauth")
            local config = { client_id = "id", client_secret = "cs" }
            -- A kill mid-body: the partial response carries a token.
            local done
            oauth._exchange_auth_code(config, "auth-code", 9, function(v) done = { v } end, "google")
            processes.processes[4242]:emit("stdout", '{"access_token":"ACCESS_SECRET","refr')
            fire_deadline(T.deadline.http)
            wait(function() return done ~= nil end)
            assert.is_nil(shown("ACCESS_SECRET"))
            assert.truthy(shown("killed: deadline"))
            -- A body that parses as an OAuth error shows the error, not the body.
            done = nil
            oauth._exchange_auth_code(config, "auth-code", 9, function(v) done = { v } end, "google")
            local p = processes.processes[4241 + processes.spawn_calls]
            p:emit("stdout", '{"error":"invalid_grant","error_description":"Bad code","id_token":"ID_SECRET"}')
            p:finish(0, 0)
            wait(function() return done ~= nil end)
            assert.truthy(shown("invalid_grant: Bad code"))
            assert.is_nil(shown("ID_SECRET"))
        end)
    end)

    it("a killed content fetch is never content, even when its output looked whole", function()
        local root = vim.fn.tempname()
        local parley = require("parley")
        parley.setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {} })
        parley._remote_reference_cache = nil
        local url = "https://example.com/doc.txt"
        local resolved
        local before = processes.spawn_calls
        parley._resolve_remote_references({
            parsed_chat = { exchanges = { { question = { content = "q", file_references = { { path = url } } } } } },
            config = parley.config, chat_file = root .. "/chat.md", exchange_idx = 1,
        }, function(value) resolved = value end)
        assert.equals(before + 1, processes.spawn_calls)
        local curl = processes.processes[4241 + processes.spawn_calls]
        -- The body and curl's whole write-out trailer, then curl hangs.
        curl:emit("stdout", "PARTIAL BODY\n__PARLEY_REMOTE_FETCH_META__\n"
            .. "HTTP_STATUS:200\nCONTENT_TYPE:text/plain\nEFFECTIVE_URL:" .. url .. "\n")
        fire_deadline(T.deadline.http)
        wait(function() return resolved ~= nil end)
        assert.is_nil(resolved[url]:find("PARTIAL BODY", 1, true), resolved[url])
        assert.truthy(resolved[url]:find("[Error:", 1, true), resolved[url])
        -- The text the transcript shows names why, and what to do (BR-38).
        assert.truthy(resolved[url]:find("killed: deadline", 1, true), resolved[url])
        assert.truthy(resolved[url]:find("Resubmit the question", 1, true), resolved[url])
        assert.is_nil(resolved[url]:find("nil", 1, true), resolved[url])
        parley._remote_reference_cache = nil
        vim.fn.delete(root, "rf")
    end)
end)
