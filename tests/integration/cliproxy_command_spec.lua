-- Integration test for the :ParleyProxy command registration (issue #131).

local tmp_dir = vim.fn.tempname()
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
    cliproxy = { manage = true },
})

-- Capture vim.notify so we can assert on what the command prints.
local function capture_notify(fn)
    local saved = vim.notify
    local msgs = {}
    vim.notify = function(msg, level)
        msgs[#msgs + 1] = { msg = msg, level = level }
    end
    local ok, err = pcall(fn)
    vim.notify = saved
    assert(ok, err)
    return msgs
end

describe(":ParleyProxy command", function()
    it("is registered after setup", function()
        assert.equals(2, vim.fn.exists(":ParleyProxy"))
    end)

    it("an unknown subcommand prints usage without erroring (no probe)", function()
        local msgs = capture_notify(function()
            vim.cmd("ParleyProxy bogus")
        end)
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.WARN, msgs[1].level)
        assert.is_truthy(msgs[1].msg:find("unknown subcommand 'bogus'"))
    end)

    it("bare invocation prints per-subcommand help including models/providers", function()
        local msgs = capture_notify(function()
            vim.cmd("ParleyProxy")
        end)
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.INFO, msgs[1].level)
        local help = msgs[1].msg
        for _, sub in ipairs({ "status", "start", "stop", "restart", "models", "providers", "login", "update" }) do
            assert.is_truthy(help:find(sub, 1, true), "help missing subcommand: " .. sub)
        end
        assert.is_truthy(help:find("<provider>", 1, true)) -- models/login show their arg
    end)

    it("providers lists the supported provider names", function()
        local msgs = capture_notify(function()
            vim.cmd("ParleyProxy providers")
        end)
        assert.equals(1, #msgs)
        local out = msgs[1].msg
        for _, p in ipairs(require("parley.cliproxy_config").providers()) do
            assert.is_truthy(out:find(p, 1, true), "providers output missing: " .. p)
        end
    end)

    -- #197 Task 12: an empty model list USED to be read as "not authenticated".
    -- That inference is exactly what this issue disproved — /v1/models kept
    -- listing every model while the credential was dead — so the command now
    -- asks the proxy instead of guessing.
    describe("models with an empty list", function()
        local cliproxy = require("parley.cliproxy")
        local saved_list, saved_health, saved_select
        local seen_channels

        before_each(function()
            seen_channels = {}
            saved_list = cliproxy.list_models
            saved_health = cliproxy.credential_health
            saved_select = vim.ui.select
            cliproxy.list_models = function(_p, cb) cb({}, nil) end
        end)

        after_each(function()
            cliproxy.list_models = saved_list
            cliproxy.credential_health = saved_health
            vim.ui.select = saved_select
        end)

        it("does NOT claim 'not authenticated' when the credential is healthy", function()
            cliproxy.credential_health = function(cb, channel)
                seen_channels[#seen_channels + 1] = channel
                cb({ state = "healthy", account = "me@example.com" })
            end
            local prompted = false
            vim.ui.select = function() prompted = true end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy models claude")
                vim.wait(300, function() return false end)
            end)
            assert.is_false(prompted, "prompted a login for an authenticated provider")
            assert.is_truthy(msgs[#msgs].msg:find("is authenticated", 1, true))
        end)

        it("prompts with the proxy's own reason when the credential is dead", function()
            cliproxy.credential_health = function(cb, channel)
                seen_channels[#seen_channels + 1] = channel
                cb({ state = "unavailable", account = "me@example.com",
                     message = "OAuth access token has expired." })
            end
            local prompt
            vim.ui.select = function(_i, opts, cb) prompt = opts.prompt; cb(nil, 2) end
            capture_notify(function()
                vim.cmd("ParleyProxy models claude")
                vim.wait(300, function() return false end)
            end)
            assert.is_truthy(prompt)
            assert.is_truthy(prompt:find("expired", 1, true))
        end)

        it("reads the CHANNEL axis, not the provider name (google → gemini*)", function()
            -- C2: `google` is a model-owning provider; credential health is
            -- keyed by channel. Five of six coincide — google does not, and it
            -- is the one that motivated the M1 channel fix.
            cliproxy.credential_health = function(cb, channel)
                seen_channels[#seen_channels + 1] = channel
                cb(channel == "gemini-cli"
                    and { state = "healthy", account = "g@example.com" }
                    or { state = "missing", message = "no credential for " .. tostring(channel) })
            end
            local prompted = false
            vim.ui.select = function() prompted = true end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy models google")
                vim.wait(300, function() return false end)
            end)
            table.sort(seen_channels)
            assert.same({ "aistudio", "gemini", "gemini-cli" }, seen_channels)
            assert.is_false(prompted, "prompted a login despite a healthy gemini-cli credential")
            assert.is_truthy(msgs[#msgs].msg:find("is authenticated", 1, true))
        end)

        it("says so when credential state cannot be read", function()
            cliproxy.credential_health = function(cb, channel)
                seen_channels[#seen_channels + 1] = channel
                cb({ state = "unknown", reason = "unreachable", message = "proxy unreachable" })
            end
            local prompted = false
            vim.ui.select = function() prompted = true end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy models claude")
                vim.wait(300, function() return false end)
            end)
            assert.is_false(prompted)
            assert.is_truthy(msgs[#msgs].msg:find("could not be read", 1, true))
        end)
    end)

    it("models with no provider prints its usage line", function()
        local msgs = capture_notify(function()
            vim.cmd("ParleyProxy models")
        end)
        assert.equals(1, #msgs)
        assert.equals(vim.log.levels.WARN, msgs[1].level)
        assert.is_truthy(msgs[1].msg:find("models <provider>", 1, true))
    end)

    it("can be registered under a custom prefix", function()
        parley.register_proxy_command("Zed")
        assert.equals(2, vim.fn.exists(":ZedProxy"))
        pcall(vim.api.nvim_del_user_command, "ZedProxy")
    end)
end)
