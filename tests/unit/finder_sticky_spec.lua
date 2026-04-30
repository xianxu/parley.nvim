local sticky = require("parley.finder_sticky")

describe("finder_sticky.extract", function()
    it("returns nil for empty or non-string input", function()
        assert.is_nil(sticky.extract(nil, { "root" }))
        assert.is_nil(sticky.extract("", { "root" }))
        assert.is_nil(sticky.extract("   ", { "root" }))
    end)

    it("preserves a completed {root} fragment", function()
        assert.equals("{charon}", sticky.extract("{charon} hello world", { "root" }))
    end)

    it("preserves an in-progress { fragment as a normalised {root}", function()
        assert.equals("{char}", sticky.extract("hello {char", { "root" }))
    end)

    it("preserves the empty {} fragment when complete only", function()
        assert.equals("{}", sticky.extract("{} foo", { "root" }))
        -- Lone "{" with nothing after produces no fragment
        assert.is_nil(sticky.extract("{ foo", { "root" }))
    end)

    it("preserves [tag] fragments only when 'tag' kind is requested", function()
        assert.equals("[bug]", sticky.extract("[bug] something", { "root", "tag" }))
        -- not requesting "tag" → drop it
        assert.is_nil(sticky.extract("[bug] something", { "root" }))
    end)

    it("preserves an in-progress [tag fragment", function()
        assert.equals("[bu]", sticky.extract("notes [bu", { "tag" }))
    end)

    it("combines multiple fragments in encounter order with single spaces", function()
        assert.equals("[bug] {charon}", sticky.extract("[bug] foo {charon} bar", { "root", "tag" }))
    end)

    it("drops plain words", function()
        assert.is_nil(sticky.extract("just plain text", { "root", "tag" }))
    end)

    it("rejects fragments containing nested same-bracket characters", function()
        assert.is_nil(sticky.extract("{ab{c}", { "root" }))
        assert.is_nil(sticky.extract("[ab[c]", { "tag" }))
    end)

    it("does not trip on a closing-only token", function()
        assert.is_nil(sticky.extract("} foo", { "root" }))
        assert.is_nil(sticky.extract("] foo", { "tag" }))
    end)
end)

describe("finder_sticky.format_initial_query", function()
    it("returns nil for empty input", function()
        assert.is_nil(sticky.format_initial_query(nil))
        assert.is_nil(sticky.format_initial_query(""))
    end)

    it("appends a trailing space", function()
        assert.equals("{charon} ", sticky.format_initial_query("{charon}"))
    end)
end)
