-- #230 removed the hidden per-provider cap. A config that still sets
-- live_models.per_provider would otherwise be ignored without a word.
describe("live_models.per_provider removal", function()
    local parley = require("parley")
    local logger = require("parley.logger")
    local saved, warnings

    local function setup(live_models)
        parley.setup({ chat_dir = vim.fn.tempname(), state_dir = vim.fn.tempname(), providers = {}, api_keys = {},
            cliproxy = { manage = false, live_models = live_models } })
    end

    before_each(function()
        saved, warnings = logger.warning, {}
        logger.warning = function(message) warnings[#warnings + 1] = message end
        parley._per_provider_noticed = nil
    end)
    after_each(function() logger.warning = saved end)

    it("notices a leftover per_provider once, naming the replacement", function()
        setup({ per_provider = 3 })
        setup({ per_provider = 3 })
        local notices = vim.tbl_filter(function(m) return m:find("per_provider", 1, true) ~= nil end, warnings)
        assert.equals(1, #notices)
        assert.matches("!N", notices[1])
    end)

    it("says nothing when the option is absent", function()
        setup({ providers = { "codex:gpt-5!3" } })
        assert.same({}, vim.tbl_filter(function(m) return m:find("per_provider", 1, true) ~= nil end, warnings))
    end)
end)
