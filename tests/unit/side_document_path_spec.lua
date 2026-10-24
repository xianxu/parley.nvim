local Path

local function header(parent)
    return { "---", "type: side-doc", "parent: " .. parent, "---" }
end

describe("side-document owning root and actual parent (#419)", function()
    before_each(function()
        local ok, value = pcall(require, "parley.side_document_path")
        assert.is_true(ok, tostring(value))
        Path = value
    end)
    it("normalizes flat and one valid month level under one owning root", function()
        assert.equals("/r/a.side", Path.member("/r/a.side/./old.md"))
        assert.equals("/r/a.side", Path.member("/r/a.side/2026-10/new.md"))
        assert.equals("/r/a.side", Path.root("/r/a.md"))
        assert.equals("/r/a.side", Path.root("/r/a.side/2026-10/new.md"))
        for _, path in ipairs({ "/r/a.side/2026-13/x.md", "/r/a.side/2026-00/x.md",
            "/r/a.side/2026-10/deeper/x.md", "/r/a.side/x.side/y.md", "/r/qa/answer.md" }) do
            assert.is_nil(Path.member(path), path)
        end
        assert.is_nil(Path.root("/r/a.side/x.side/y.md"))
    end)

    it("requires the actual declared parent, including a same-root monthly grandchild", function()
        local a, b, c = "/r/a.md", "/r/a.side/2026-10/b.md", "/r/a.side/2026-11/c.md"
        assert.is_true(Path.relation(b, a, header("../../a.md")))
        assert.is_true(Path.relation(c, b, header("../2026-10/b.md")))
        assert.is_false(Path.relation(c, a, header("../2026-10/b.md")))
        assert.is_false(Path.relation(c, "/elsewhere/b.md", header("/elsewhere/b.md")))
        assert.is_false(Path.relation(c, c, header("c.md")))
        assert.is_false(Path.relation(c, b, header("../../outside.md")))
        assert.is_false(Path.relation(c, b, { "# no parent proof" }))
        assert.is_false(Path.relation(c, b, { "---", "parent: ../2026-10/b.md" }))
    end)

    it("keeps the established headerless flat-child relationship only", function()
        assert.is_true(Path.relation("/r/a.side/old.md", "/r/a.md", { "# Handwritten" }))
        assert.is_false(Path.relation("/r/a.side/old.md", "/r/a.md", header("../other.md")))
        assert.is_false(Path.relation("/r/qa/a.md", "/r/a.md", header("../a.md")))
    end)
end)
