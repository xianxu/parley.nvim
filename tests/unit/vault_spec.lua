-- Unit tests for vault module in lua/parley/vault.lua
--
-- The vault manages API secrets for LLM providers. Key behaviors:
-- - Alias mapping (e.g., "openai" -> "openai_api_key")
-- - Idempotent add_secret (second add is a no-op)
-- - String secrets resolve immediately; table secrets invoke tasker.run
-- - Obfuscation of resolved secrets (first 3 + last 3 chars visible)
-- - run_with_secret: lazy resolution wrapper
--
-- Strategy: Reset module state between test groups via package.loaded removal.
-- Mock tasker.run to invoke callbacks synchronously.

describe("vault", function()
    local vault
    local tasker
    local helpers

    -- Fresh module load for each test
    before_each(function()
        -- Clear cached modules to reset private state
        package.loaded["parley.vault"] = nil
        package.loaded["parley.tasker"] = nil
        package.loaded["parley.helper"] = nil

        vault = require("parley.vault")
        tasker = require("parley.tasker")
        helpers = require("parley.helper")
    end)

    describe("Group A: add_secret + get_secret", function()
        it("A1: stores a string secret and retrieves it", function()
            vault.add_secret("test_key", "my-secret-value")
            assert.equals("my-secret-value", vault.get_secret("test_key"))
        end)

        it("A2: alias 'openai' resolves to 'openai_api_key'", function()
            vault.add_secret("openai", "sk-test-123")
            -- Should be retrievable via both names
            assert.equals("sk-test-123", vault.get_secret("openai"))
            assert.equals("sk-test-123", vault.get_secret("openai_api_key"))
        end)

        it("A3: second add_secret with same name does not overwrite", function()
            vault.add_secret("test_key", "first-value")
            vault.add_secret("test_key", "second-value")
            assert.equals("first-value", vault.get_secret("test_key"))
        end)

        it("A4: get_secret for non-existent name returns nil", function()
            assert.is_nil(vault.get_secret("nonexistent"))
        end)

        it("A5: get_secret for unresolved table command returns nil", function()
            vault.add_secret("cmd_key", { "echo", "hello" })
            assert.is_nil(vault.get_secret("cmd_key"))
        end)

        it("A6: add_secret with nil secret stores nil, get_secret returns nil", function()
            vault.add_secret("nil_key", nil)
            assert.is_nil(vault.get_secret("nil_key"))
        end)

        it("A7: deep copy prevents external mutation", function()
            local secret_table = { "echo", "hello" }
            vault.add_secret("deep_key", secret_table)
            -- Mutate the original table
            secret_table[1] = "modified"
            -- Internal copy should be unaffected
            assert.is_nil(vault.get_secret("deep_key")) -- still a table, so nil
        end)
    end)

    describe("Group B: resolve_secret", function()
        it("B1: string secret is resolved immediately and callback called", function()
            local called = false
            vault.resolve_secret("str_key", "my-api-key", function()
                called = true
            end)
            assert.is_true(called)
            assert.equals("my-api-key", vault.get_secret("str_key"))
        end)

        it("B2: resolved string secret populates _obfuscated_secrets", function()
            vault.resolve_secret("str_key", "abcdefghijk", function() end)
            assert.is_not_nil(vault._obfuscated_secrets["str_key"])
            -- First 3 chars + stars + last 3 chars
            local obfuscated = vault._obfuscated_secrets["str_key"]
            assert.equals("abc", obfuscated:sub(1, 3))
            assert.equals("ijk", obfuscated:sub(-3))
        end)

        it("B3: string secret is whitespace-trimmed", function()
            vault.resolve_secret("ws_key", "  trimmed-value  ", function() end)
            assert.equals("trimmed-value", vault.get_secret("ws_key"))
        end)

        it("B4: table secret invokes tasker.run and stores result on success", function()
            -- Mock tasker.run to call callback synchronously with success
            local original_run = tasker.run
            tasker.run = function(buf, cmd, args, callback)
                callback(0, 0, "resolved-secret-value", "")
            end

            local called = false
            vault.resolve_secret("cmd_key", { "echo", "hello" }, function()
                called = true
            end)

            assert.is_true(called)
            assert.equals("resolved-secret-value", vault.get_secret("cmd_key"))

            tasker.run = original_run
        end)

        it("B5: table secret on failure (code!=0) does NOT store secret", function()
            local original_run = tasker.run
            tasker.run = function(buf, cmd, args, callback)
                callback(1, 0, "", "error output")
            end

            vault.resolve_secret("fail_key", { "bad", "cmd" }, function() end)
            assert.is_nil(vault.get_secret("fail_key"))

            tasker.run = original_run
        end)

        it("B6: table secret with empty stdout does not store", function()
            local original_run = tasker.run
            tasker.run = function(buf, cmd, args, callback)
                callback(0, 0, "   ", "") -- whitespace-only output
            end

            local called = false
            vault.resolve_secret("empty_key", { "echo", "" }, function()
                called = true
            end)
            -- callback should NOT have been called because post_process is skipped
            assert.is_false(called)
            assert.is_nil(vault.get_secret("empty_key"))

            tasker.run = original_run
        end)

        it("B7: nil secret returns early, callback NOT called", function()
            local called = false
            vault.resolve_secret("nil_key", nil, function()
                called = true
            end)
            assert.is_false(called)
        end)

        it("B8: already-resolved secret calls callback immediately without tasker.run", function()
            -- First resolve
            vault.resolve_secret("pre_key", "already-here", function() end)

            -- Mock tasker.run to detect if it's called
            local run_called = false
            local original_run = tasker.run
            tasker.run = function()
                run_called = true
            end

            local called = false
            vault.resolve_secret("pre_key", "ignored", function()
                called = true
            end)

            assert.is_true(called)
            assert.is_false(run_called)
            -- Original value preserved
            assert.equals("already-here", vault.get_secret("pre_key"))

            tasker.run = original_run
        end)

        it("B9: reports missing and empty resolver results once without success", function()
            local successes = 0
            local errors = {}
            vault.resolve_secret("missing", nil, function() successes = successes + 1 end,
                function(message) table.insert(errors, message) end)
            assert.equals(0, successes)
            assert.equals(1, #errors)

            tasker.run = function(_buf, _cmd, _args, callback)
                callback(0, 0, "   ", "")
            end
            vault.resolve_secret("empty", { "echo" }, function() successes = successes + 1 end,
                function(message) table.insert(errors, message) end)
            assert.equals(0, successes)
            assert.equals(2, #errors)
        end)

        it("B10: reports resolver exit and launch rejection once", function()
            local errors = 0
            tasker.run = function(_buf, _cmd, _args, callback)
                callback(7, 0, "", "bad")
            end
            vault.resolve_secret("exit", { "bad" }, function() error("success") end,
                function() errors = errors + 1 end)
            assert.equals(1, errors)

            tasker.run = function(_buf, _cmd, _args, _callback, _out, _err, on_start_error)
                on_start_error("could not start")
                on_start_error("duplicate")
            end
            vault.resolve_secret("launch", { "bad" }, function() error("success") end,
                function() errors = errors + 1 end)
            assert.equals(2, errors)
        end)

        it("B11: rejects empty string and command inputs without launching or succeeding", function()
            local runs = 0
            local successes = 0
            local errors = 0
            tasker.run = function() runs = runs + 1 end

            for _, secret in ipairs({ "", "   ", {} }) do
                vault.resolve_secret("empty_" .. tostring(errors), secret,
                    function() successes = successes + 1 end,
                    function() errors = errors + 1 end)
            end

            assert.equals(0, runs)
            assert.equals(0, successes)
            assert.equals(3, errors)
        end)

        it("B12: never treats a stored empty string as resolved", function()
            local successes = 0
            local errors = 0
            vault.add_secret("stored_empty", "")
            vault.run_with_secret("stored_empty", function() successes = successes + 1 end,
                function() errors = errors + 1 end)
            vault.add_secret("stored_space", "   ")
            vault.run_with_secret("stored_space", function() successes = successes + 1 end,
                function() errors = errors + 1 end)

            assert.equals(0, successes)
            assert.equals(2, errors)
        end)
    end)

    describe("Group C: run_with_secret", function()
        it("C1: resolved string secret calls callback immediately", function()
            vault.add_secret("resolved_key", "value")
            -- resolve it so it's a string
            vault.resolve_secret("resolved_key", "value", function() end)

            local called = false
            vault.run_with_secret("resolved_key", function()
                called = true
            end)
            assert.is_true(called)
        end)

        it("C2: unresolved table secret triggers resolve_secret then callback", function()
            local original_run = tasker.run
            tasker.run = function(buf, cmd, args, callback)
                callback(0, 0, "resolved-value", "")
            end

            vault.add_secret("cmd_key", { "echo", "secret" })

            local called = false
            vault.run_with_secret("cmd_key", function()
                called = true
            end)

            assert.is_true(called)
            assert.equals("resolved-value", vault.get_secret("cmd_key"))

            tasker.run = original_run
        end)

        it("C3: non-existent secret returns early, callback NOT called", function()
            local called = false
            vault.run_with_secret("missing_key", function()
                called = true
            end)
            assert.is_false(called)
        end)

        it("C4: propagates missing and resolver failures once", function()
            local successes = 0
            local errors = 0
            vault.run_with_secret("missing", function() successes = successes + 1 end,
                function() errors = errors + 1 end)
            assert.equals(0, successes)
            assert.equals(1, errors)

            vault.add_secret("command", { "bad" })
            tasker.run = function(_buf, _cmd, _args, callback)
                callback(1, 0, "", "bad")
            end
            vault.run_with_secret("command", function() successes = successes + 1 end,
                function() errors = errors + 1 end)
            assert.equals(0, successes)
            assert.equals(2, errors)
        end)
    end)

    describe("Group D: setup", function()
        it("D1: sets curl_params from opts", function()
            local _base = (os.getenv("TMPDIR") or "/tmp") .. "/claude"
            local original_prepare = helpers.prepare_dir
            helpers.prepare_dir = function() return _base end

            vault.setup({ curl_params = { "--proxy", "http://proxy" }, state_dir = _base .. "/vault-test" })
            assert.same({ "--proxy", "http://proxy" }, vault.config.curl_params)

            helpers.prepare_dir = original_prepare
        end)

        it("D2: sets state_dir from opts", function()
            local _state_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/vault-state"
            local original_prepare = helpers.prepare_dir
            helpers.prepare_dir = function() return _state_dir end

            vault.setup({ state_dir = _state_dir })
            assert.equals(_state_dir, vault.config.state_dir)

            helpers.prepare_dir = original_prepare
        end)
    end)

    describe("Group E: alias resolution consistency", function()
        it("E1: alias works consistently across add, get, resolve, run_with", function()
            vault.add_secret("openai", "sk-alias-test")
            -- resolve via alias
            vault.resolve_secret("openai", "sk-alias-test", function() end)
            -- get via canonical name
            assert.equals("sk-alias-test", vault.get_secret("openai_api_key"))
            -- run_with via alias
            local called = false
            vault.run_with_secret("openai", function()
                called = true
            end)
            assert.is_true(called)
        end)

        it("E2: non-aliased name passes through unchanged", function()
            vault.add_secret("anthropic", "ant-key")
            assert.equals("ant-key", vault.get_secret("anthropic"))
        end)
    end)
end)

-- #261 M1 review BR-20: one schema types the copilot bearer at both boundaries
-- it crosses. A token response whose expires_at is not a number keeps its token
-- but drops that field, so the next request fetches again instead of raising on
-- the comparison.
describe("vault copilot bearer from the token endpoint", function()
    local Process = require("tests.helpers.fake_process")
    local vault, tasker, runtime, processes, dir
    before_each(function()
        package.loaded["parley.vault"] = nil
        vault = require("parley.vault")
        tasker = require("parley.tasker")
        tasker._reset(); runtime, processes = Process.new(); tasker._uv = runtime
        dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-vault-bearer-" .. string.format("%x", math.random(0, 0xFFFFFF))
        vault.setup({ state_dir = dir })
        vault.add_secret("copilot", "fixture-token")
    end)
    after_each(function()
        tasker._reset(); tasker._uv = nil
        vim.fn.delete(dir, "rf")
    end)
    local function answer(body)
        local pid = next(processes.processes) and math.max(unpack(vim.tbl_keys(processes.processes)))
        local process = processes.processes[pid]
        process:emit("stdout", body)
        process:finish(0)
    end

    -- #261 M4 W6: every failure path reports, so a request waiting on the
    -- bearer (the copilot pre_query) is never left waiting.
    it("V2: every failed refresh calls on_error, and never the success callback", function()
        local errors, successes = {}, 0
        local function refresh() vault.refresh_copilot_bearer(function() successes = successes + 1 end,
            function(message) errors[#errors + 1] = message end) end
        refresh()
        local p = processes.processes[4242]; p:finish(22, 0)
        assert.is_true(vim.wait(1000, function() return #errors == 1 end, 5), "a failed curl never reported")
        refresh()
        answer("<html>proxy error</html>")
        assert.is_true(vim.wait(1000, function() return #errors == 2 end, 5), "an undecodable body never reported")
        -- A vault with no copilot secret resolved returns early: it must report too.
        package.loaded["parley.vault"] = nil
        vault = require("parley.vault"); vault.setup({ state_dir = dir })
        refresh()
        assert.equals(3, #errors, "an unresolved secret never reported")
        assert.equals(0, successes)
    end)
    it("V1: drops a non-numeric expires_at and fetches again on the next request", function()
        local refreshed = 0
        vault.refresh_copilot_bearer(function() refreshed = refreshed + 1 end)
        assert.is_true(vim.wait(1000, function() return processes.spawn_calls == 1 end, 5))
        answer('{"token":"t","expires_at":"soon"}')
        assert.is_true(vim.wait(1000, function() return refreshed == 1 end, 5))
        assert.same({ token = "t" }, vault._state.copilot_bearer)
        local ok, err = pcall(vault.refresh_copilot_bearer, function() refreshed = refreshed + 1 end)
        assert(ok, err)
        assert.is_true(vim.wait(1000, function() return processes.spawn_calls == 2 end, 5),
            "a bearer without a numeric expiry must be fetched again")
    end)
end)
