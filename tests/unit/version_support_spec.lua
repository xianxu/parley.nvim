-- #379: the supported-version rule, pure. setup()'s refusal and make test's
-- compat pass both read this one MINIMUM.
local support = require("parley.version_support")

describe("version_support", function()
    local function v(major, minor, patch) return { major = major, minor = minor, patch = patch } end

    it("supports the minimum and anything newer", function()
        assert.same({ 0, 11, 0 }, support.MINIMUM)
        for _, ok in ipairs({ v(0, 11, 0), v(0, 11, 7), v(0, 12, 5), v(1, 0, 0) }) do
            assert.is_true(support.supported(ok), vim.inspect(ok))
        end
    end)

    it("refuses anything older", function()
        for _, old in ipairs({ v(0, 10, 4), v(0, 9, 99), v(0, 0, 1) }) do
            assert.is_false(support.supported(old), vim.inspect(old))
        end
    end)

    it("names the minimum and the running version in its refusal", function()
        assert.equals("parley needs Neovim 0.11.0 or newer (this is 0.10.4)", support.refusal(v(0, 10, 4)))
    end)

    it("supports the editor running this spec", function()
        assert.is_true(support.supported(vim.version()))
    end)

    it("makes setup() refuse an older editor before installing anything", function()
        local parley = require("parley")
        local real_version, real_notify = vim.version, vim.notify
        local notices = {}
        vim.version = setmetatable({}, { __call = function() return v(0, 10, 4) end, __index = real_version })
        vim.notify = function(msg, level) notices[#notices + 1] = { msg = msg, level = level } end
        parley._setup_called = nil
        local ok, err = pcall(parley.setup, {})
        vim.version, vim.notify = real_version, real_notify
        assert.is_true(ok, tostring(err))
        assert.is_nil(parley._setup_called, "setup ran past the version check")
        assert.same({ { msg = "parley needs Neovim 0.11.0 or newer (this is 0.10.4)", level = vim.log.levels.ERROR } }, notices)
    end)
end)
