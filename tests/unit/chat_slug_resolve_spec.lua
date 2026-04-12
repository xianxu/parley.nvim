local parley = require("parley")
local chat_slug = require("parley.chat_slug")

describe("fuzzy chat path resolution", function()
	local base_dir

	before_each(function()
		base_dir = vim.fn.tempname() .. "-parley-slug-resolve"
		vim.fn.mkdir(base_dir, "p")
		parley.setup({
			chat_dir = base_dir,
			providers = {},
			api_keys = {},
		})
	end)

	after_each(function()
		vim.fn.delete(base_dir, "rf")
	end)

	it("resolves exact path as before", function()
		local file = base_dir .. "/2026-04-11.16-38-42.729.md"
		vim.fn.writefile({ "test" }, file)
		local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
		assert.equals(vim.fn.resolve(file), result)
	end)

	it("resolves slugged file when referenced by timestamp-only name", function()
		local slugged = base_dir .. "/2026-04-11.16-38-42.729_debugging-auth.md"
		vim.fn.writefile({ "test" }, slugged)
		local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
		assert.equals(vim.fn.resolve(slugged), result)
	end)

	it("resolves timestamp-only file when referenced by old slug name", function()
		local plain = base_dir .. "/2026-04-11.16-38-42.729.md"
		vim.fn.writefile({ "test" }, plain)
		local result = parley.resolve_chat_path("2026-04-11.16-38-42.729_old-slug.md", base_dir)
		assert.equals(vim.fn.resolve(plain), result)
	end)

	it("returns first candidate when no match found", function()
		local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
		assert.equals(vim.fn.resolve(base_dir .. "/2026-04-11.16-38-42.729.md"), result)
	end)

	it("prefers slugged match over non-match with different timestamp", function()
		-- Two files: one with our timestamp + slug, one with a different timestamp
		local ours = base_dir .. "/2026-04-11.16-38-42.729_my-topic.md"
		local other = base_dir .. "/2026-04-11.16-38-42.730.md"
		vim.fn.writefile({ "test" }, ours)
		vim.fn.writefile({ "test" }, other)
		local result = parley.resolve_chat_path("2026-04-11.16-38-42.729.md", base_dir)
		assert.equals(vim.fn.resolve(ours), result)
	end)
end)
