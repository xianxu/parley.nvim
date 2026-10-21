-- The fake's executable contract matters: parent and child processes must see
-- one persisted owner, including after publication followed by a lost reply.
describe("fake Couch operator protocol", function()
    it("keeps identity, token, refusal and lost-ack behavior across processes", function()
        local result = vim.system({ "python3", "tests/unit/fake_couch_operator_pure.py" }, { text = true }):wait()
        assert.equals(0, result.code, result.stderr)
    end)

    it("routes operator requests through the generated executable without changing queries or sends", function()
        local root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        local ok, err = pcall(function()
            require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
            local file = root .. "/session.md"
            vim.fn.writefile({ "text" }, file)
            local binary = root .. "/bin/couch"
            local acquired = vim.system({ binary, "--session-sync", "operator-acquire", file,
                "--id", "doc-1", "--turn", string.rep("a", 32), "--json" }, { text = true }):wait()
            assert.equals(0, acquired.code, acquired.stderr)
            assert.equals("acquired", vim.json.decode(acquired.stdout).OperatorLock.State)
            local query = vim.system({ binary, "--actors" },
                { text = true, env = { FAKE_COUCH_ACTORS = "actors" } }):wait()
            assert.equals("actors", query.stdout)
            local send = vim.system({ binary, "--send-to", "ops:0", "--message", "hello" },
                { text = true }):wait()
            assert.equals(0, send.code, send.stderr)
            assert.matches("msg%-1 parley.nvim:9 %-> ops:0 queued", send.stdout)
            assert.same({ "ops:0|hello" }, vim.fn.readfile(root .. "/sent"))
        end)
        vim.fn.delete(root, "rf")
        assert.is_true(ok, tostring(err))
    end)
end)
