local structure = require("parley.skills.review.chat_structure")
describe("chat structural snapshot", function()
    it("uses CommonMark headings and code with submitted line coordinates", function()
        local facts, err = structure.snapshot({ "---", "title: Example", "---", "@@chat@@", "  ## Notes ##", "", "Setext", "---", "", "```markdown", "# fake", "@@chat@@", "```", "", "    # indented" })
        assert.is_nil(err)
        assert.same({ { line = 5, finish = 5, level = 2, name = "Notes", kind = "atx" }, { line = 7, finish = 8, level = 2, name = "Setext", kind = "setext" } }, facts.headings)
        assert.is_true(facts.code_lines[11])
        assert.is_true(facts.code_lines[15])
        assert.equals(4, facts.body_start)
        assert.is_true(facts.legacy_read)
        assert.is_truthy(facts.legacy_evidence.fields.title)
    end)
    it("refuses oversized snapshots before joining or parsing", function()
        local facts, err = structure.snapshot({ string.rep("x", 1048577) })
        assert.is_nil(facts)
        assert.matches("1 MiB", err, 1, true)
    end)
end)

describe("chat snapshot work", function()
    it("counts bytes, lines and AST work with linear growth", function()
        local function work(count)
            local lines = {}
            for _ = 1, count do
                for _, line in ipairs({ "@@chat@@", "## Notes", "1. ask", "", "```", "# literal", "```", "" }) do lines[#lines + 1] = line end
            end
            local facts = assert(structure.snapshot(lines))
            return facts.work
        end
        assert.is_true(work(128) < work(64) * 2.5 + 100)
    end)
    it("reports missing bundled inline grammar visibly", function()
        local original = vim.treesitter.language.add
        vim.treesitter.language.add = function(language, ...)
            if language == "markdown_inline" then return false end
            return original(language, ...)
        end
        local ok, facts, err = pcall(structure.snapshot, { "# Title" })
        vim.treesitter.language.add = original
        assert.is_true(ok)
        assert.is_nil(facts)
        assert.matches("chat structure unavailable", err, 1, true)
    end)
    it("reports a parser absence visibly", function()
        local original = vim.treesitter.get_string_parser
        vim.treesitter.get_string_parser = function() error("parser absent") end
        local ok, facts, err = pcall(structure.snapshot, { "# Title" })
        vim.treesitter.get_string_parser = original
        assert.is_true(ok)
        assert.is_nil(facts)
        assert.matches("chat structure unavailable", err, 1, true)
    end)
end)

describe("chat native source extraction work", function()
    it("bounds actual copied bytes at N/2N headings", function()
        local function work(count)
            local lines = {}
            for _ = 1, count do
                for _, line in ipairs({ "@@chat@@", "## Heading", "ordinary body words", "ordinary body words" }) do lines[#lines + 1] = line end
            end
            local original_sub, copied = string.sub, 0
            -- Measure actual string results, including runtime helpers. Input
            -- envelopes alone do not prove that a helper copied its input.
            -- luacheck: push ignore 122
            string.sub = function(source, first, last)
                local result = original_sub(source, first, last)
                copied = copied + #result
                return result
            end
            local ok, facts, err = pcall(structure.snapshot, lines)
            string.sub = original_sub
            -- luacheck: pop
            assert.is_true(ok)
            assert.is_nil(err)
            assert.equals(count, #facts.headings)
            assert.is_true(copied < facts.bytes * 40)
            return copied
        end
        local small, large = work(64), work(128)
        assert.is_true(large < small * 2.5 + 100,
            ("copied bytes grew from %d to %d"):format(small, large))
    end)
end)

describe("closed header preservation evidence", function()
    it("retains an inclusive protection boundary independently of readability", function()
        for _, lines in ipairs({
            { "---", "...", "process-instruction: 🤖[literal metadata]", "---", "# Body" },
            { " --- ", "presentation: inline", "---", "# Body" },
            { "---\r", "presentation: inline\r", "---\r", "# Body" },
            { "---", "%YAML 1.2", "presentation: inline", "---", "# Body" },
        }) do
            local facts, err = structure.snapshot(lines)
            assert.is_nil(err)
            assert.equals(#lines - 1, facts.protected_header_end)
            assert.equals(1, facts.body_start)
            assert.is_truthy(facts.legacy_error)
        end
    end)
    it("protects readable closed headers and leaves unclosed thematic text alone", function()
        local facts, err = structure.snapshot({ "---", "title: Example", "---", "# Body" })
        assert.is_nil(err)
        assert.equals(3, facts.protected_header_end)
        assert.equals(4, facts.body_start)
        facts, err = structure.snapshot({ "---", "presentation: prose", "# Body" })
        assert.is_nil(err)
        assert.is_nil(facts.protected_header_end)
        assert.equals(1, facts.body_start)
    end)
end)
