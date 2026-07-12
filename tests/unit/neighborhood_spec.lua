local neighborhood = require("parley.neighborhood")

local function cfg(overrides)
    return vim.tbl_extend("force", {
        repo_root = "/workspace/repo",
        repo_chat_dir = "workshop/parley",
        repo_note_dir = "workshop/notes",
        issues_dir = "workshop/issues",
        vision_dir = "workshop/vision",
        history_dir = "workshop/history",
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

    it("returns repo root for every repo-local artifact directory", function()
        for _, rel in ipairs({
            "workshop/parley/2026-06-29.topic.md",
            "workshop/notes/design.md",
            "workshop/issues/000147-topic.md",
            "workshop/vision/roadmap.yaml",
            "workshop/history/000001-done.md",
        }) do
            local root = neighborhood.derive_for_path("/workspace/repo/" .. rel, cfg(), roots)

            assert.equals("/workspace/repo", root)
        end
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

describe("neighborhood root policy (#181)", function()
    it("orders neighborhood, repo, and configured roots first-wins", function()
        local policy = neighborhood.policy_for_path(
            "/repo/data/career/note.md",
            cfg({ repo_root = "/repo", tool_read_roots = { "/repo", "../../../sibling" } }),
            {})
        assert.equals("/repo/data/career", policy.write_root)
        assert.same({ "/repo/data/career", "/repo", "/sibling" }, policy.read_roots)
    end)

    it("does not add a repo root outside repo mode", function()
        local config = cfg({ tool_read_roots = {} })
        config.repo_root = nil
        local policy = neighborhood.policy_for_path("/notes/note.md", config, {})
        assert.same({ "/notes" }, policy.read_roots)
    end)

    it("keeps a global chat narrow while repo mode is active", function()
        local policy = neighborhood.policy_for_path("/global/chats/chat.md", cfg({
            tool_read_roots = {},
        }), { "/global/chats" })
        assert.same({ "/global/chats" }, policy.read_roots)
    end)

    it("canonicalizes symlink aliases before de-duplicating roots", function()
        local base = (os.getenv("TMPDIR") or "/tmp") .. "/parley-policy-" .. math.random(1, 999999)
        vim.fn.mkdir(base .. "/real", "p")
        vim.loop.fs_symlink(base .. "/real", base .. "/alias")
        local policy = neighborhood.policy_from_roots(base .. "/real", nil, { base .. "/alias" })
        assert.same({ vim.loop.fs_realpath(base .. "/real") }, policy.read_roots)
        vim.fn.delete(base, "rf")
    end)

    it("formats guidance from the policy", function()
        assert.equals(table.concat({
            "Relative reads search these roots in order (first existing match wins):",
            "- /repo/data",
            "- /repo",
            "Relative writes resolve only from: /repo/data",
        }, "\n"), neighborhood.format_tool_context({
            write_root = "/repo/data",
            read_roots = { "/repo/data", "/repo" },
        }))
    end)

    it("merges string candidates first-root-first without mutating inputs", function()
        local groups = { { "z", "same" }, { "a", "same" } }
        assert.same({ "same", "z", "a" }, neighborhood.merge_completion_candidates(groups))
        assert.same({ { "z", "same" }, { "a", "same" } }, groups)
    end)
end)
