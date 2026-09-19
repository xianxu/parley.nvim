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
        parley._remote_reference_cache = nil
        vim.fn.delete(root, "rf")
    end)
end)
