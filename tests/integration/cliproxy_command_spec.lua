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
