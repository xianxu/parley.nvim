-- Enforcement half of the single-source heading dialect (ARCH-DRY).
-- document/lexical.lua keeps its own inline byte-scanner because it is a hot
-- incremental tokenizer; this test is what stops the two copies drifting.
local heading = require("parley.markdown_heading")
local lexical = require("parley.document.lexical")
local config = require("parley.config")

-- Straddles every edge of the dialect: the cap, the required space,
-- indentation, and structural markers that must never read as headings.
local CORPUS = {
	"# One", "## Two", "### Three", "#### Four", "##### Five",
	"#NoSpace", "##", "#", "  # Indented", "\t# Tabbed",
	"", "plain", "💬: q", "🤖: a", "📝: s", "--- ", "@@tag@@",
	"#  double space", "###   spaced", "# trailing hash #",
}

describe("markdown_heading vs document.lexical", function()
	it("agrees on heading_level for every corpus line", function()
		local patterns = lexical.patterns(config.config or {})
		for _, line in ipairs(CORPUS) do
			local cursor = lexical.lex_start(patterns)
			local _, token = lexical.lex_step(cursor, line, true)
			assert.equals(heading.level(line), token.heading_level,
				("dialect drift on %q"):format(line))
		end
	end)
end)
