-- Unit tests for the cliproxyapi managed-proxy pre_query hook (issue #131).

local providers = require("parley.providers")
local cliproxy = require("parley.cliproxy")
local parley = require("parley")

describe("cliproxyapi.pre_query", function()
    local saved_config, saved_ensure

    before_each(function()
        saved_config = parley.config
        saved_ensure = cliproxy.ensure_running
    end)
    after_each(function()
        parley.config = saved_config
        cliproxy.ensure_running = saved_ensure
    end)

    it("is registered on the cliproxyapi adapter", function()
        assert.is_function(providers.get("cliproxyapi").pre_query)
    end)

    it("no-op: calls on_success synchronously when not managed", function()
        parley.config = { cliproxy = { manage = false } }
        local ok, errored = false, false
        providers.get("cliproxyapi").pre_query(function()
            ok = true
        end, function()
            errored = true
        end)
        assert.is_true(ok)
        assert.is_false(errored)
    end)

    it("delegates to ensure_running with BOTH callbacks when managed", function()
        parley.config = { cliproxy = { manage = true } }
        local got
        cliproxy.ensure_running = function(on_success, on_error)
            got = { on_success, on_error }
        end
        local s = function() end
        local e = function() end
        providers.get("cliproxyapi").pre_query(s, e)
        assert.equals(s, got[1])
        assert.equals(e, got[2])
    end)
end)
