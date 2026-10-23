-- Keep Python bridge/driver checks in the normal Lua suite and spec mapping.
local arrival = require("tests.helpers.arrival")

describe("supported Couch bridge consumer", function()
    it("qualifies protocol and process ownership through the Python regressions", function()
        local out = vim.system({ "python3", "-B", "-m", "unittest",
            "tests.packaging.test_couch_bridge", "tests.packaging.test_registry_conformance_bridge" },
            { text = true, timeout = arrival.MS }):wait(arrival.MS)
        local output = (out.stdout or "") .. (out.stderr or "")
        assert.equals(0, out.code, output)
        assert.is_true(tonumber(output:match("Ran (%d+) tests")) > 0, output)
    end)
end)
