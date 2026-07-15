local repo_mode = require("parley.repo_mode")

describe("repo_mode.resolve", function()
    it("selects only exact modes for a canonical repository root", function()
        local modes = {
            ["/workspace/a"] = "super_repo",
            ["/workspace/b"] = "repo",
            ["/workspace/c"] = "SUPER_REPO",
        }

        assert.equals("super_repo", repo_mode.resolve(modes, "/workspace/a"))
        assert.equals("repo", repo_mode.resolve(modes, "/workspace/b"))
        assert.is_nil(repo_mode.resolve(modes, "/workspace/c"))
        assert.is_nil(repo_mode.resolve(modes, "/workspace/missing"))
    end)

    it("treats malformed maps and roots as unsaved", function()
        assert.is_nil(repo_mode.resolve(nil, "/workspace/a"))
        assert.is_nil(repo_mode.resolve("bad", "/workspace/a"))
        assert.is_nil(repo_mode.resolve({}, nil))
        assert.is_nil(repo_mode.resolve({}, ""))
        assert.is_nil(repo_mode.resolve({}, 42))
    end)
end)

describe("repo_mode.updated", function()
    it("returns a fresh sanitized map with only the current root replaced", function()
        local input = {
            ["/workspace/a"] = "repo",
            ["/workspace/b"] = "super_repo",
            ["/workspace/invalid"] = "other",
            [""] = "repo",
            [42] = "repo",
        }
        local before = vim.deepcopy(input)

        local result = repo_mode.updated(input, "/workspace/a", "super_repo")

        assert.same({
            ["/workspace/a"] = "super_repo",
            ["/workspace/b"] = "super_repo",
        }, result)
        assert.same(before, input)
        assert.is_not.equal(input, result)
    end)

    it("starts empty when the input map is malformed", function()
        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated("bad", "/workspace/a", "repo"))
    end)

    it("rejects invalid roots and modes without mutating the input", function()
        local input = { ["/workspace/a"] = "repo" }

        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated(input, "", "super_repo"))
        assert.same({ ["/workspace/a"] = "repo" }, repo_mode.updated(input, "/workspace/a", "other"))
        assert.same({ ["/workspace/a"] = "repo" }, input)
    end)
end)
