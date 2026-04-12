local chat_slug = require("parley.chat_slug")

describe("chat_slug", function()
	describe("slugify", function()
		it("returns nil for question mark topic", function()
			assert.is_nil(chat_slug.slugify("?"))
		end)

		it("returns nil for empty string", function()
			assert.is_nil(chat_slug.slugify(""))
		end)

		it("returns nil for nil", function()
			assert.is_nil(chat_slug.slugify(nil))
		end)

		it("strips stop words and kebab-cases", function()
			assert.equals("debugging-authentication-flow", chat_slug.slugify("Debugging the authentication flow"))
		end)

		it("caps at 5 words", function()
			assert.equals("one-two-three-four-five", chat_slug.slugify("one two three four five six seven"))
		end)

		it("caps at 40 chars breaking at word boundary", function()
			local result = chat_slug.slugify("longword longword longword longword longword")
			assert.is_true(#result <= 40)
			-- "longword-longword-longword-longword" = 35 chars, fits
			-- "longword-longword-longword-longword-longword" = 44 chars, too long
			assert.equals("longword-longword-longword-longword", result)
		end)

		it("replaces underscores with hyphens", function()
			assert.equals("some-var-name", chat_slug.slugify("some_var_name"))
		end)

		it("strips non-ASCII characters", function()
			-- UTF-8 multi-byte chars are stripped (no transliteration)
			assert.equals("hllo-wrld", chat_slug.slugify("héllo wörld"))
		end)

		it("handles pure ASCII topic with non-ASCII mixed in", function()
			assert.equals("setup-google-drive-integration", chat_slug.slugify("Setup Google Drive — integration"))
		end)

		it("collapses multiple hyphens", function()
			assert.equals("hello-world", chat_slug.slugify("hello---world"))
		end)

		it("lowercases everything", function()
			assert.equals("hello-world", chat_slug.slugify("Hello World"))
		end)

		it("strips leading/trailing hyphens", function()
			assert.equals("hello", chat_slug.slugify("  hello  "))
		end)

		it("returns nil when topic has only stop words", function()
			assert.is_nil(chat_slug.slugify("the and of"))
		end)
	end)

	describe("parse_filename", function()
		it("parses timestamp-only filename", function()
			local ts, slug = chat_slug.parse_filename("2026-04-11.16-38-42.729.md")
			assert.equals("2026-04-11.16-38-42.729", ts)
			assert.is_nil(slug)
		end)

		it("parses filename with slug", function()
			local ts, slug = chat_slug.parse_filename("2026-04-11.16-38-42.729_debugging-auth.md")
			assert.equals("2026-04-11.16-38-42.729", ts)
			assert.equals("debugging-auth", slug)
		end)

		it("returns nil for non-timestamp filename", function()
			local ts, slug = chat_slug.parse_filename("readme.md")
			assert.is_nil(ts)
			assert.is_nil(slug)
		end)
	end)

	describe("make_filename", function()
		it("creates timestamp-only when no slug", function()
			assert.equals("2026-04-11.16-38-42.729.md", chat_slug.make_filename("2026-04-11.16-38-42.729", nil))
		end)

		it("creates filename with slug", function()
			assert.equals("2026-04-11.16-38-42.729_debugging-auth.md", chat_slug.make_filename("2026-04-11.16-38-42.729", "debugging-auth"))
		end)
	end)

	describe("glob_pattern", function()
		it("returns wildcard pattern for timestamp", function()
			assert.equals("2026-04-11.16-38-42.729*.md", chat_slug.glob_pattern("2026-04-11.16-38-42.729"))
		end)
	end)

	describe("filename validation compatibility", function()
		it("slugged filename matches existing timestamp pattern", function()
			local basename = "2026-04-11.16-38-42.729_debugging-auth.md"
			assert.is_truthy(basename:match("^%d%d%d%d%-%d%d%-%d%d"))
		end)
	end)
end)
