-- Unit tests for tree export helpers in exporter.lua
--
-- Tests cover: sanitize_title, extract_date, find_tree_root, collect_tree,
-- build_link_map, and process_branch_lines.

local M = require("parley")
local exporter = require("parley.exporter")

describe("Exporter tree helpers", function()
	local tmpdir

	before_each(function()
		local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
		tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-tree-" .. random_suffix
		vim.fn.mkdir(tmpdir, "p")
		M.config.chat_dir = tmpdir
	end)

	after_each(function()
		if tmpdir then
			vim.fn.delete(tmpdir, "rf")
		end
	end)

	local function write_file(filename, content)
		local filepath = tmpdir .. "/" .. filename
		local f = io.open(filepath, "w")
		f:write(content)
		f:close()
		return filepath
	end

	describe("Group A: sanitize_title", function()
		it("A1: lowercases and replaces spaces with underscores", function()
			assert.equals("hello_world", exporter._sanitize_title("Hello World"))
		end)

		it("A2: removes special characters", function()
			assert.equals("test_with_chars", exporter._sanitize_title("Test With !@#$% Chars"))
		end)

		it("A3: truncates to 50 characters", function()
			local long_title = string.rep("Very Long Title ", 10)
			local result = exporter._sanitize_title(long_title)
			assert.is_true(#result <= 50)
		end)
	end)

	describe("Group B: extract_date", function()
		it("B1: extracts date from filename with date prefix", function()
			assert.equals("2024-03-15", exporter._extract_date("2024-03-15-some-file.md"))
		end)

		it("B2: returns nil for filename without date", function()
			assert.is_nil(exporter._extract_date("no-date-here.md"))
		end)

		it("B3: handles empty string", function()
			assert.is_nil(exporter._extract_date(""))
		end)

		it("B4: handles nil", function()
			assert.is_nil(exporter._extract_date(nil))
		end)
	end)

	describe("Group C: find_tree_root", function()
		it("C1: returns same file when no parent link", function()
			local root = write_file("root.md", [[---
topic: Root Chat
file: root.md
---
💬: Hello

🤖: Hi there
]])
			local result = exporter._find_tree_root(root)
			assert.equals(vim.fn.resolve(root), result)
		end)

		it("C2: walks up to parent", function()
			write_file("parent.md", [[---
topic: Parent Chat
file: parent.md
---
💬: Hello

🤖: Hi

🌿: child.md: Child Chat
]])
			local child = write_file("child.md", [[---
topic: Child Chat
file: child.md
---
🌿: parent.md: Parent Chat

💬: Follow up

🤖: Response
]])
			local result = exporter._find_tree_root(child)
			assert.equals(vim.fn.resolve(tmpdir .. "/parent.md"), result)
		end)

		it("C3: walks up multiple levels", function()
			write_file("grandparent.md", [[---
topic: Grandparent
file: grandparent.md
---
💬: Start

🤖: OK

🌿: parent.md: Parent
]])
			write_file("parent.md", [[---
topic: Parent
file: parent.md
---
🌿: grandparent.md: Grandparent

💬: Middle

🤖: OK

🌿: child.md: Child
]])
			local child = write_file("child.md", [[---
topic: Child
file: child.md
---
🌿: parent.md: Parent

💬: End

🤖: Done
]])
			local result = exporter._find_tree_root(child)
			assert.equals(vim.fn.resolve(tmpdir .. "/grandparent.md"), result)
		end)
	end)

	describe("Group D: collect_tree", function()
		it("D1: collects single file when no branches", function()
			local root = write_file("solo.md", [[---
topic: Solo Chat
file: solo.md
---
💬: Hello

🤖: Hi
]])
			local result = exporter._collect_tree(root)
			assert.equals(1, #result)
			assert.equals(vim.fn.resolve(root), result[1].abs_path)
			assert.equals("Solo Chat", result[1].title)
		end)

		it("D2: collects root and children", function()
			local root = write_file("root.md", [[---
topic: Root
file: root.md
---
💬: Hello

🤖: Hi

🌿: child1.md: Child 1

💬: More

🤖: OK

🌿: child2.md: Child 2
]])
			write_file("child1.md", [[---
topic: Child 1
file: child1.md
---
🌿: root.md: Root

💬: Branch 1

🤖: OK
]])
			write_file("child2.md", [[---
topic: Child 2
file: child2.md
---
🌿: root.md: Root

💬: Branch 2

🤖: OK
]])
			local result = exporter._collect_tree(root)
			assert.equals(3, #result)
			assert.equals("Root", result[1].title)
		end)

		it("D3: handles missing child files gracefully", function()
			local root = write_file("root.md", [[---
topic: Root
file: root.md
---
💬: Hello

🤖: Hi

🌿: missing.md: Missing Child
]])
			local result = exporter._collect_tree(root)
			-- Should have root only; missing child is skipped
			assert.equals(1, #result)
		end)

		it("D4: handles circular references", function()
			write_file("a.md", [[---
topic: A
file: a.md
---
💬: Hello

🤖: Hi

🌿: b.md: B
]])
			write_file("b.md", [[---
topic: B
file: b.md
---
🌿: a.md: A

💬: Hi

🤖: OK

🌿: a.md: A again
]])
			local result = exporter._collect_tree(tmpdir .. "/a.md")
			-- Should visit each file exactly once
			assert.equals(2, #result)
		end)
	end)

	describe("Group E: build_link_map", function()
		it("E1: maps file paths to export filenames", function()
			write_file("2024-03-15-chat.md", [[---
topic: Test Chat
file: 2024-03-15-chat.md
---
💬: Hello

🤖: Hi
]])
			local tree_infos = exporter._collect_tree(tmpdir .. "/2024-03-15-chat.md")
			local map = exporter._build_link_map(tree_infos, "html")
			local expected_key = vim.fn.resolve(tmpdir .. "/2024-03-15-chat.md")
			assert.equals("2024-03-15-test_chat.html", map[expected_key])
		end)

		it("E2: uses .markdown extension for markdown format", function()
			write_file("2024-03-15-chat.md", [[---
topic: Test Chat
file: 2024-03-15-chat.md
---
💬: Hello

🤖: Hi
]])
			local tree_infos = exporter._collect_tree(tmpdir .. "/2024-03-15-chat.md")
			local map = exporter._build_link_map(tree_infos, "markdown")
			local expected_key = vim.fn.resolve(tmpdir .. "/2024-03-15-chat.md")
			assert.equals("2024-03-15-test_chat.markdown", map[expected_key])
		end)
	end)

	describe("Group F: process_branch_lines for markdown", function()
		it("F1: converts parent link to Jekyll post_url with styled HTML", function()
			write_file("2024-01-10-parent.md", [[---
topic: Parent Topic
file: 2024-01-10-parent.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"🌿: 2024-01-10-parent.md: Parent Topic",
				"",
				"💬: Question",
			}
			local parsed = { parent_link = { path = "2024-01-10-parent.md", topic = "Parent Topic" }, branches = {} }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/2024-01-10-parent.md")] = "2024-01-10-parent_topic.markdown",
			}
			local result = exporter._process_branch_lines(lines, parsed, "markdown", link_map, tmpdir)
			-- blank line, div, blank line inserted for Kramdown compatibility
			assert.equals("", result[1])
			assert.is_truthy(result[2]:find("parent%-link"))
			assert.is_truthy(result[2]:find("post_url 2024%-01%-10%-parent_topic"))
			assert.is_truthy(result[2]:find("← Parent Topic"))
			assert.equals("", result[3])
		end)

		it("F2: converts child branch link to Jekyll post_url with styled HTML", function()
			write_file("2024-01-15-child.md", [[---
topic: Child Topic
file: 2024-01-15-child.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"💬: Question",
				"",
				"🤖: Answer",
				"",
				"🌿: 2024-01-15-child.md: Child Topic",
			}
			local parsed = { parent_link = nil, branches = { { path = "2024-01-15-child.md", topic = "Child Topic" } } }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/2024-01-15-child.md")] = "2024-01-15-child_topic.markdown",
			}
			local result = exporter._process_branch_lines(lines, parsed, "markdown", link_map, tmpdir)
			-- lines 1-4 are the non-branch lines, then blank, div, blank
			assert.equals("", result[5])
			assert.is_truthy(result[6]:find("child%-link"))
			assert.is_truthy(result[6]:find("post_url 2024%-01%-15%-child_topic"))
			assert.is_truthy(result[6]:find("→ Child Topic"))
			assert.equals("", result[7])
		end)

		it("F3: renders styled div without link when target not in link map", function()
			local lines = {
				"🌿: missing.md: Missing Chat",
				"",
				"💬: Question",
			}
			local parsed = { parent_link = { path = "missing.md", topic = "Missing Chat" }, branches = {} }
			local result = exporter._process_branch_lines(lines, parsed, "markdown", {}, tmpdir)
			assert.equals("", result[1])
			assert.is_truthy(result[2]:find("parent%-link"))
			assert.is_truthy(result[2]:find("← Missing Chat"))
			assert.equals("", result[3])
		end)
	end)

	describe("Group G: process_branch_lines for HTML", function()
		it("G1: returns placeholders for HTML format", function()
			write_file("2024-01-10-parent.md", [[---
topic: Parent Topic
file: 2024-01-10-parent.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"🌿: 2024-01-10-parent.md: Parent Topic",
				"",
				"💬: Question",
			}
			local parsed = { parent_link = { path = "2024-01-10-parent.md", topic = "Parent Topic" }, branches = {} }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/2024-01-10-parent.md")] = "2024-01-10-parent_topic.html",
			}
			local result, placeholders = exporter._process_branch_lines(lines, parsed, "html", link_map, tmpdir)
			-- First line should be a placeholder
			assert.is_truthy(result[1]:find("XBRANCHX"))
			-- Placeholder should map to HTML with link
			local key = result[1]
			assert.is_truthy(placeholders[key]:find("parent%-link"))
			assert.is_truthy(placeholders[key]:find("parent_topic%.html"))
		end)

		it("G2: child branch uses child-link class", function()
			write_file("2024-01-15-child.md", [[---
topic: Child
file: 2024-01-15-child.md
---
💬: Hello

🤖: Hi
]])
			local lines = {
				"💬: Question",
				"",
				"🤖: Answer",
				"",
				"🌿: 2024-01-15-child.md: Child",
			}
			local parsed = { parent_link = nil, branches = { { path = "2024-01-15-child.md", topic = "Child" } } }
			local link_map = {
				[vim.fn.resolve(tmpdir .. "/2024-01-15-child.md")] = "2024-01-15-child.html",
			}
			local result, placeholders = exporter._process_branch_lines(lines, parsed, "html", link_map, tmpdir)
			local key = result[5]
			assert.is_truthy(placeholders[key]:find("child%-link"))
		end)
	end)

	describe("Group H: filename collision detection", function()
		it("H1: returns nil when no collisions", function()
			local link_map = {
				["/path/a.md"] = "2024-01-01-alpha.html",
				["/path/b.md"] = "2024-01-01-beta.html",
			}
			assert.is_nil(exporter._check_filename_collisions(link_map))
		end)

		it("H2: detects collisions when two files produce same filename", function()
			local link_map = {
				["/path/a.md"] = "2024-01-01-same_topic.html",
				["/path/b.md"] = "2024-01-01-same_topic.html",
			}
			local collisions = exporter._check_filename_collisions(link_map)
			assert.is_truthy(collisions)
			assert.equals(2, #collisions["2024-01-01-same_topic.html"])
		end)

		it("H3: detects multiple collision groups", function()
			local link_map = {
				["/path/a.md"] = "2024-01-01-dup1.html",
				["/path/b.md"] = "2024-01-01-dup1.html",
				["/path/c.md"] = "2024-01-01-dup2.html",
				["/path/d.md"] = "2024-01-01-dup2.html",
				["/path/e.md"] = "2024-01-01-unique.html",
			}
			local collisions = exporter._check_filename_collisions(link_map)
			assert.is_truthy(collisions)
			assert.equals(2, #collisions["2024-01-01-dup1.html"])
			assert.equals(2, #collisions["2024-01-01-dup2.html"])
			assert.is_nil(collisions["2024-01-01-unique.html"])
		end)
	end)
end)
