local neighborhood = require("parley.neighborhood")

local function cfg(overrides)
    return vim.tbl_extend("force", {
        repo_root = "/workspace/repo",
        repo_chat_dir = "workshop/parley",
    }, overrides or {})
end

local roots = {
    { dir = "/workspace/repo/workshop/parley", label = "repo" },
    { dir = "/workspace/sibling/workshop/parley", label = "sibling" },
    { dir = "/Users/me/chats", label = "global" },
}

describe("neighborhood.derive_for_path", function()
    it("returns repo root for repo-moded chat artifacts", function()
        local root = neighborhood.derive_for_path(
            "/workspace/repo/workshop/parley/2026-06-29.topic.md",
            cfg(),
            roots
        )

        assert.equals("/workspace/repo", root)
    end)

    it("returns sibling repo root for super-repo chat roots", function()
        local root = neighborhood.derive_for_path(
            "/workspace/sibling/workshop/parley/2026-06-29.topic.md",
            cfg(),
            roots
        )

        assert.equals("/workspace/sibling", root)
    end)

    it("returns the artifact folder for global chat artifacts", function()
        local root = neighborhood.derive_for_path(
            "/Users/me/chats/2026-06-29.topic.md",
            cfg(),
            roots
        )

        assert.equals("/Users/me/chats", root)
    end)

    it("returns the artifact folder for non-chat content artifacts", function()
        local root = neighborhood.derive_for_path(
            "/Users/me/blog/posts/draft.md",
            cfg(),
            roots
        )

        assert.equals("/Users/me/blog/posts", root)
    end)

    it("rejects blank artifact paths", function()
        local root, err = neighborhood.derive_for_path("", cfg(), roots)

        assert.is_nil(root)
        assert.equals("buffer has no file", err)
    end)
end)
