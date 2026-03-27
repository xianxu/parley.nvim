-- Unit tests for inline branch links [🌿:text](file)
--
-- Tests cover: extraction, unpacking, parser integration, and export.

local chat_parser = require("parley.chat_parser")
local M = require("parley")
local exporter = require("parley.exporter")

describe("Inline branch links", function()
	local tmpdir

	before_each(function()
		local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
		tmpdir = "/tmp/parley-test-inline-" .. random_suffix
		vim.fn.mkdir(tmpdir, "p")
		M.config.chat_dir = tmpdir
	end)

	after_each(function()
		if tmpdir then
			vim.fn.delete(tmpdir, "rf")
		end
	end)

	describe("Group A: extract_inline_branch_links", function()
		it("A1: extracts single inline link", function()
			local result = chat_parser.extract_inline_branch_links(
				"Check out [🌿:shader](child.md) for details",
				"🌿:"
			)
			assert.equals(1, #result)
			assert.equals("child.md", result[1].path)
			assert.equals("shader", result[1].topic)
			assert.is_true(result[1].col_start > 0)
			assert.is_true(result[1].col_end > result[1].col_start)
		end)

		it("A2: extracts multiple inline links on one line", function()
			local result = chat_parser.extract_inline_branch_links(
				"See [🌿:alpha](a.md) and [🌿:beta](b.md) here",
				"🌿:"
			)
			assert.equals(2, #result)
			assert.equals("a.md", result[1].path)
			assert.equals("alpha", result[1].topic)
			assert.equals("b.md", result[2].path)
			assert.equals("beta", result[2].topic)
		end)

		it("A3: returns empty for line with no inline links", function()
			local result = chat_parser.extract_inline_branch_links("Just a normal line", "🌿:")
			assert.equals(0, #result)
		end)

		it("A4: does not match full-line branch links", function()
			local result = chat_parser.extract_inline_branch_links("🌿: child.md: Topic", "🌿:")
			assert.equals(0, #result)
		end)

		it("A5: handles empty topic", function()
			local result = chat_parser.extract_inline_branch_links("[🌿:](child.md)", "🌿:")
			assert.equals(1, #result)
			assert.equals("child.md", result[1].path)
			assert.equals("", result[1].topic)
		end)
	end)

	describe("Group B: unpack_inline_branch_links", function()
		it("B1: replaces inline link with display text", function()
			local result = chat_parser.unpack_inline_branch_links(
				"Check out [🌿:shader](child.md) for details",
				"🌿:"
			)
			assert.equals("Check out shader for details", result)
		end)

		it("B2: replaces multiple links", function()
			local result = chat_parser.unpack_inline_branch_links(
				"See [🌿:alpha](a.md) and [🌿:beta](b.md)",
				"🌿:"
			)
			assert.equals("See alpha and beta", result)
		end)

		it("B3: returns line unchanged when no links", function()
			local result = chat_parser.unpack_inline_branch_links("No links here", "🌿:")
			assert.equals("No links here", result)
		end)
	end)

	describe("Group C: parse_chat with inline links", function()
		it("C1: adds inline links to branches", function()
			local lines = {
				"---",
				"topic: Test",
				"file: test.md",
				"---",
				"💬: What is a [🌿:shader](child.md)?",
				"",
				"🤖: A shader is a program.",
			}
			local header_end = chat_parser.find_header_end(lines)
			local config = {
				chat_user_prefix = "💬:",
				chat_local_prefix = "🔒:",
				chat_assistant_prefix = { "🤖:" },
				chat_branch_prefix = "🌿:",
				chat_memory = { enable = true, summary_prefix = "📝:", reasoning_prefix = "🧠:" },
			}
			local parsed = chat_parser.parse_chat(lines, header_end, config)
			assert.equals(1, #parsed.branches)
			assert.equals("child.md", parsed.branches[1].path)
			assert.equals("shader", parsed.branches[1].topic)
			assert.is_true(parsed.branches[1].inline)
		end)

		it("C2: unpacks inline links from content", function()
			local lines = {
				"---",
				"topic: Test",
				"file: test.md",
				"---",
				"💬: What is a [🌿:shader](child.md)?",
				"",
				"🤖: A shader is a program.",
			}
			local header_end = chat_parser.find_header_end(lines)
			local config = {
				chat_user_prefix = "💬:",
				chat_local_prefix = "🔒:",
				chat_assistant_prefix = { "🤖:" },
				chat_branch_prefix = "🌿:",
				chat_memory = { enable = true, summary_prefix = "📝:", reasoning_prefix = "🧠:" },
			}
			local parsed = chat_parser.parse_chat(lines, header_end, config)
			-- Content should have the link unpacked to plain text
			assert.is_truthy(parsed.exchanges[1].question.content:find("shader"))
			assert.is_falsy(parsed.exchanges[1].question.content:find("%[🌿:"))
			assert.is_falsy(parsed.exchanges[1].question.content:find("child%.md"))
		end)

		it("C3: inline links coexist with full-line links", function()
			local lines = {
				"---",
				"topic: Test",
				"file: test.md",
				"---",
				"💬: Question",
				"",
				"🤖:",
				"Answer with [🌿:term](term.md) inline",
				"",
				"🌿: branch.md: Full Branch",
			}
			local header_end = chat_parser.find_header_end(lines)
			local config = {
				chat_user_prefix = "💬:",
				chat_local_prefix = "🔒:",
				chat_assistant_prefix = { "🤖:" },
				chat_branch_prefix = "🌿:",
				chat_memory = { enable = true, summary_prefix = "📝:", reasoning_prefix = "🧠:" },
			}
			local parsed = chat_parser.parse_chat(lines, header_end, config)
			assert.equals(2, #parsed.branches)
			assert.is_true(parsed.branches[1].inline)
			assert.is_nil(parsed.branches[2].inline)
		end)

		it("C4: inline links in answer are unpacked in content", function()
			local lines = {
				"---",
				"topic: Test",
				"file: test.md",
				"---",
				"💬: Question",
				"",
				"🤖:",
				"A [🌿:GPU](gpu.md) renders graphics using [🌿:shaders](shader.md).",
			}
			local header_end = chat_parser.find_header_end(lines)
			local config = {
				chat_user_prefix = "💬:",
				chat_local_prefix = "🔒:",
				chat_assistant_prefix = { "🤖:" },
				chat_branch_prefix = "🌿:",
				chat_memory = { enable = true, summary_prefix = "📝:", reasoning_prefix = "🧠:" },
			}
			local parsed = chat_parser.parse_chat(lines, header_end, config)
			local answer = parsed.exchanges[1].answer.content
			assert.equals("A GPU renders graphics using shaders.", answer)
			assert.equals(2, #parsed.branches)
		end)
	end)

	describe("Group D: export inline links", function()
		local function write_file(filename, content)
			local filepath = tmpdir .. "/" .. filename
			local f = io.open(filepath, "w")
			f:write(content)
			f:close()
			return filepath
		end

		it("D1: HTML export replaces inline links with <a> tags", function()
			write_file("child.md", [[---
topic: Child
file: child.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"🤖: Check out [🌿:shader](child.md) for details",
			}
			local parsed = { parent_link = nil, branches = { { path = "child.md", topic = "shader", inline = true } } }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/child.md")] = "2024-01-01-child.html",
			}
			local result, placeholders = exporter._process_branch_lines(
				lines, parsed, "html", link_map, tmpdir, "🌿:", nil
			)
			-- The line should contain a placeholder for the inline link
			local line = result[1]
			assert.is_truthy(line:find("XBRANCHX"))
			-- The placeholder should resolve to an <a> with branch-inline class
			for key, html in pairs(placeholders) do
				if line:find(key, 1, true) then
					assert.is_truthy(html:find("branch%-inline"))
					assert.is_truthy(html:find("child%.html"))
					assert.is_truthy(html:find("shader"))
				end
			end
		end)

		it("D2: markdown export replaces inline links with <a> tags", function()
			write_file("child.md", [[---
topic: Child
file: child.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"🤖: Check out [🌿:shader](child.md) for details",
			}
			local parsed = { parent_link = nil, branches = { { path = "child.md", topic = "shader", inline = true } } }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/child.md")] = "2024-01-01-child.markdown",
			}
			local result = exporter._process_branch_lines(
				lines, parsed, "markdown", link_map, tmpdir, "🌿:", nil
			)
			local line = result[1]
			assert.is_truthy(line:find("branch%-inline"))
			assert.is_truthy(line:find("post_url"))
			assert.is_truthy(line:find("shader"))
		end)

		it("D3: inline link with missing target falls back to plain text", function()
			local lines = {
				"🤖: See [🌿:missing](missing.md) here",
			}
			local parsed = { parent_link = nil, branches = {} }
			local result = exporter._process_branch_lines(
				lines, parsed, "html", {}, tmpdir, "🌿:", nil
			)
			-- Should fall back to just the display text
			assert.equals("🤖: See missing here", result[1])
		end)
	end)
end)
