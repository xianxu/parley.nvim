-- #204: api_keys given to setup{} reach the vault the way the managed proxy
-- reads them. D1: a partial user table keeps parley's defaults (merged since
-- #307). D2: a re-run setup{} replaces the key; it is not pinned to the first
-- value seen.
local parley = require("parley")
local default_cliproxy_key = require("parley.config").api_keys.cliproxyapi

describe("setup{} api_keys", function()
    local base_dir

    local function setup_with(api_keys)
        parley.setup({
            chat_dir = base_dir .. "/chats",
            state_dir = base_dir .. "/state",
            api_keys = api_keys,
        })
    end

    -- The name the cliproxy renderer looks up, so these read what it reads.
    local function cliproxy_secret()
        return parley.vault.get_secret(require("parley.providers").get_secret_name("cliproxyapi"))
    end

    before_each(function()
        base_dir = vim.fn.tempname() .. "-parley-api-keys"
    end)

    after_each(function()
        vim.fn.delete(base_dir, "rf")
    end)

    it("keeps the cliproxyapi default when the user sets only another key", function()
        setup_with({ openai = "sk-user" })
        assert.equals(default_cliproxy_key, cliproxy_secret())
        assert.equals("sk-user", parley.vault.get_secret("openai"))
    end)

    it("drops a default the user sets to false", function()
        setup_with({ cliproxyapi = false })
        assert.is_nil(cliproxy_secret())
    end)

    it("a second setup{} with an edited key is what the renderer reads", function()
        setup_with({ cliproxyapi = "parley_local" })
        assert.equals("parley_local", cliproxy_secret())
        setup_with({ cliproxyapi = "parley-local" })
        assert.equals("parley-local", cliproxy_secret())
        setup_with({})
        assert.equals(default_cliproxy_key, cliproxy_secret())
    end)
end)
