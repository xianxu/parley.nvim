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

describe(":ParleyProxy command", function()
    it("is registered after setup", function()
        assert.equals(2, vim.fn.exists(":ParleyProxy"))
    end)

    it("an unknown subcommand prints usage without erroring (no probe)", function()
        assert.has_no.errors(function()
            vim.cmd("ParleyProxy bogus")
        end)
    end)

    it("can be registered under a custom prefix", function()
        parley.register_proxy_command("Zed")
        assert.equals(2, vim.fn.exists(":ZedProxy"))
        pcall(vim.api.nvim_del_user_command, "ZedProxy")
    end)
end)
