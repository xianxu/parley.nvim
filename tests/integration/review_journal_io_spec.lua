-- Integration tests for the review journal IO seam (append/read/sidecar) and
-- its wiring into a review round. The serialize/parse/diff/drift logic is unit-
-- tested in review_journal_spec; here we touch the filesystem. (#133)

local J = require("parley.skills.review.journal")

describe("review.journal IO", function()
    local doc

    before_each(function()
        doc = vim.fn.tempname() .. ".md"
    end)

    after_each(function()
        vim.fn.delete(doc)
        vim.fn.delete(J.sidecar_path(doc))
    end)

    it("creates the sidecar with base + round 1 on first append", function()
        local ok = J.append(doc, {
            mode = "developmental", side = "agent", ts = "t1", hash = "h1",
            diff = "d1", explains = { "why it changed" },
        }, "BASE CONTENT")
        assert.is_true(ok)
        local p = J.read(doc)
        assert.are.equal("BASE CONTENT", p.base)
        assert.are.equal(1, #p.entries)
        assert.are.equal(1, p.entries[1].round)
        assert.are.equal("developmental", p.entries[1].mode)
    end)

    it("appends round 2 without rewriting the base", function()
        J.append(doc, { mode = "line-editing", side = "agent", ts = "t1", hash = "h1", diff = "d1" }, "BASE")
        J.append(doc, { mode = "proofreading", side = "agent", ts = "t2", hash = "h2", diff = "d2" }, "IGNORED")
        local p = J.read(doc)
        assert.are.equal("BASE", p.base) -- base snapshot unchanged by round 2
        assert.are.equal(2, #p.entries)
        assert.are.equal(2, p.entries[2].round)
        assert.are.equal("proofreading", p.entries[2].mode)
    end)

    it("read returns empty entries when no sidecar exists", function()
        local p = J.read(doc)
        assert.are.same({}, p.entries)
    end)

    it("is_drift detects an external edit since the last recorded round", function()
        J.append(doc, { mode = "m", side = "agent", ts = "t", hash = J.hash("v1 content"), diff = "d" }, "v1 content")
        local last = J.read(doc).entries[1]
        assert.is_false(J.is_drift(last.hash, "v1 content"))
        assert.is_true(J.is_drift(last.hash, "v1 content edited by another tool"))
    end)
end)
