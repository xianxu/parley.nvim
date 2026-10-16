-- Keep build-time export validation in the standard modes/review test suite.
-- Python's stdlib runner exercises pure mutations, real CLI IO and the package.
describe("review protocol export bundle", function()
    it("validates the generator and standalone packaged snapshot", function()
        local root = vim.fn.getcwd()
        local result = vim.system({ "python3", root .. "/tests/unit/review_protocol_export_test.py" }, {
            text = true,
            cwd = root,
            env = { PYTHONDONTWRITEBYTECODE = "1" },
        }):wait(60000)
        assert.equals(0, result.code, (result.stdout or "") .. (result.stderr or ""))
    end)
end)
