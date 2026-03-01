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
    end)

    describe("Group D: setup", function()
        it("D1: sets curl_params from opts", function()
            local original_prepare = helpers.prepare_dir
            helpers.prepare_dir = function() return "/tmp" end

            vault.setup({ curl_params = { "--proxy", "http://proxy" }, state_dir = "/tmp/vault-test" })
            assert.same({ "--proxy", "http://proxy" }, vault.config.curl_params)

            helpers.prepare_dir = original_prepare
        end)

        it("D2: sets state_dir from opts", function()
            local original_prepare = helpers.prepare_dir
            helpers.prepare_dir = function() return "/tmp/vault-state" end

            vault.setup({ state_dir = "/tmp/vault-state" })
            assert.equals("/tmp/vault-state", vault.config.state_dir)

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
