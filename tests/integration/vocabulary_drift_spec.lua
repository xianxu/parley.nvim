local root = vim.fn.getcwd()

describe("vocabulary content drift", function()
    local scratch, artifact, exported, log, exporter
    before_each(function()
        scratch = vim.fn.tempname()
        vim.fn.mkdir(scratch, "p")
        artifact, exported, log = scratch .. "/artifact.json", scratch .. "/export.json", scratch .. "/calls"
        exporter = root .. "/tests/fixtures/fake_vocabulary"
        vim.fn.writefile({ '{"categories":{"open":["open"]},"source_stamp":"unchanged"}' }, artifact)
        vim.fn.writefile(vim.fn.readfile(artifact), exported)
    end)
    after_each(function() vim.fn.delete(scratch, "rf") end)

    local function run(mode)
        local result = vim.system({ "sh", root .. "/scripts/check-vocabulary.sh", "--artifact", artifact,
            "--exporter", exporter }, { text = true, cwd = scratch, env = {
                PARLEY_FAKE_VOCABULARY_DATA = exported, PARLEY_FAKE_VOCABULARY_LOG = log,
                PARLEY_FAKE_VOCABULARY_MODE = mode or "ok",
            } }):wait()
        return result
    end

    it("compares complete semantic content without repairing either input", function()
        assert.equals(0, run().code)
        vim.fn.writefile({ '{"source_stamp":"unchanged", "categories": {"open": ["open"]}}' }, artifact)
        assert.equals(0, run().code)
        local mutant = '{"categories":{"open":["changed"]},"source_stamp":"unchanged"}'
        vim.fn.writefile({ mutant }, artifact)
        assert.is_true(run().code ~= 0)
        assert.equals(mutant, vim.fn.readfile(artifact)[1])
        assert.equals('{"categories":{"open":["open"]},"source_stamp":"unchanged"}', vim.fn.readfile(exported)[1])
        assert.are.same({ "export --noun issue", "export --noun issue", "export --noun issue" }, vim.fn.readfile(log))
    end)

    it("fails on exporter errors and malformed exported or committed JSON", function()
        assert.is_true(run("fail").code ~= 0)
        vim.fn.writefile({ "not json" }, exported)
        assert.is_true(run().code ~= 0)
        vim.fn.writefile({ "NaN" }, exported)
        vim.fn.writefile({ "NaN" }, artifact)
        assert.is_true(run().code ~= 0)
        vim.fn.writefile({ "{}" }, exported)
        vim.fn.writefile({ "not json" }, artifact)
        assert.is_true(run().code ~= 0)
    end)

    it("does not equate JSON booleans with numbers", function()
        vim.fn.writefile({ '{"flag":true}' }, exported)
        vim.fn.writefile({ '{"flag":1}' }, artifact)
        assert.is_true(run().code ~= 0)
    end)

    it("explains missing exporter setup", function()
        local result = vim.system({ "sh", root .. "/scripts/check-vocabulary.sh", "--artifact", artifact,
            "--exporter", scratch .. "/missing" }, { text = true }):wait()
        assert.is_true(result.code ~= 0)
        assert.is_truthy(result.stderr:find("vocabulary", 1, true))
        assert.is_truthy(result.stderr:find("install", 1, true))
    end)
end)
