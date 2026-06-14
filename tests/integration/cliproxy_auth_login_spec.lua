-- M3 (#131): on a cliproxy missing/invalid-credential failure, prompt the right
-- :ParleyProxy login — resolved from parley's oauth-model-alias, not the name.

local parley = require("parley")
local cliproxy = require("parley.cliproxy")
cliproxy._set_data_dir(vim.fn.tempname()) -- never touch the real ~/.local/share/nvim

local MANAGED = {
    cliproxy = {
        manage = true,
        config = {
            ["oauth-model-alias"] = {
                claude = { { name = "claude-opus-4-8", alias = "claude-opus-4-8", fork = true } },
            },
        },
    },
}

describe("cliproxy.check_auth_failure", function()
    local saved_config, saved_select

    before_each(function()
        saved_config = parley.config
        saved_select = vim.ui.select
        cliproxy._reset_login_prompt()
    end)
    after_each(function()
        parley.config = saved_config
        vim.ui.select = saved_select
        cliproxy._reset_login_prompt()
    end)

    it("prompts the matching login on a cliproxy 'unknown provider' failure", function()
        parley.config = vim.deepcopy(MANAGED)
        local prompt
        vim.ui.select = function(_items, opts, cb)
            prompt = opts.prompt
            cb(nil, 2) -- "Not now" — don't actually run the login command in the test
        end
        cliproxy.check_auth_failure("cliproxyapi",
            '{"error":{"message":"unknown provider for model claude-opus-4-8","type":"server_error"}}')
        vim.wait(500, function() return prompt ~= nil end, 10)
        assert.is_truthy(prompt)
        assert.is_truthy(prompt:find("claude")) -- resolved claude channel → claude login
    end)

    it("resolves the alias even when keyed by the canonical channel only", function()
        -- the default ships `claude` as the channel key; a model under it resolves
        parley.config = vim.deepcopy(MANAGED)
        local prompt
        vim.ui.select = function(_items, opts, cb)
            prompt = opts.prompt
            cb(nil, 2)
        end
        cliproxy.check_auth_failure("cliproxyapi",
            '{"error":{"message":"unknown provider for model claude-opus-4-8"}}')
        vim.wait(500, function() return prompt ~= nil end, 10)
        assert.is_truthy(prompt and prompt:find("claude"))
    end)

    it("is a no-op on a normal streamed response", function()
        parley.config = vim.deepcopy(MANAGED)
        local prompted = false
        vim.ui.select = function() prompted = true end
        cliproxy.check_auth_failure("cliproxyapi", 'data: {"choices":[{"delta":{"content":"hi"}}]}')
        vim.wait(150, function() return false end)
        assert.is_false(prompted)
    end)

    it("WARNs (no prompt) when the model isn't in any oauth-model-alias channel", function()
        parley.config = vim.deepcopy(MANAGED) -- alias only has claude-opus-4-8
        local prompted, notified = false, nil
        vim.ui.select = function()
            prompted = true
        end
        local saved_notify = vim.notify
        vim.notify = function(msg, lvl)
            notified = { msg = msg, lvl = lvl }
        end
        cliproxy.check_auth_failure("cliproxyapi",
            '{"error":{"message":"unknown provider for model some-unknown-model"}}')
        vim.wait(300, function() return notified ~= nil end, 10)
        vim.notify = saved_notify
        assert.is_false(prompted) -- couldn't resolve a login → no prompt
        assert.is_truthy(notified)
        assert.equals(vim.log.levels.WARN, notified.lvl)
        assert.is_truthy(notified.msg:find("some%-unknown%-model"))
    end)

    it("is a no-op for a non-cliproxy provider", function()
        parley.config = vim.deepcopy(MANAGED)
        local prompted = false
        vim.ui.select = function() prompted = true end
        cliproxy.check_auth_failure("openai", '{"error":{"message":"unknown provider for model x"}}')
        vim.wait(150, function() return false end)
        assert.is_false(prompted)
    end)
end)
