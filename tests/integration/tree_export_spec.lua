-- Integration tests for tree export (HTML and Markdown)
--
-- Tests verify that exporting a chat file that is part of a tree
-- exports all files in the tree with correct navigation links.

local M = require("parley")

describe("Tree export", function()
	local tmpdir
	local export_html_dir
	local export_markdown_dir
	local original_config

	before_each(function()
		original_config = vim.deepcopy(M.config)

		local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
		tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-tree-export-" .. random_suffix
		export_html_dir = tmpdir .. "/html"
		export_markdown_dir = tmpdir .. "/markdown"

		vim.fn.mkdir(tmpdir, "p")
		vim.fn.mkdir(export_html_dir, "p")
		vim.fn.mkdir(export_markdown_dir, "p")

		M.config.chat_dir = tmpdir
		M.config.export_html_dir = export_html_dir
		M.config.export_markdown_dir = export_markdown_dir
	end)

	after_each(function()
		if tmpdir then
			vim.fn.delete(tmpdir, "rf")
		end
		M.config = original_config
	end)

	local function create_chat_file(filename, content)
		local filepath = tmpdir .. "/" .. filename
		local f = io.open(filepath, "w")
		f:write(content)
		f:close()
		return filepath
	end

	describe("Group A: HTML tree export", function()
		it("A1: exports all files in a tree from child", function()
			create_chat_file("2024-03-15-root.md", [[---
topic: Root Chat
file: 2024-03-15-root.md
---
💬: Hello

🤖: Hi there

🌿: 2024-03-15-child.md: Child Chat
]])
			local child_file = create_chat_file("2024-03-15-child.md", [[---
topic: Child Chat
file: 2024-03-15-child.md
---
🌿: 2024-03-15-root.md: Root Chat

💬: Follow up question

🤖: Follow up answer
]])

			vim.cmd("edit " .. child_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportHTML()

			-- Both files should be exported
			local root_html = export_html_dir .. "/2024-03-15-root_chat.html"
			local child_html = export_html_dir .. "/2024-03-15-child_chat.html"
			assert.is_true(vim.fn.filereadable(root_html) == 1, "Root HTML should exist")
			assert.is_true(vim.fn.filereadable(child_html) == 1, "Child HTML should exist")

			-- Child should have parent link
			local child_content = table.concat(vim.fn.readfile(child_html), "\n")
			assert.is_truthy(child_content:find("parent%-link"), "Child should have parent link")
			assert.is_truthy(child_content:find("root_chat%.html"), "Parent link should point to root")

			-- Root should have child link
			local root_content = table.concat(vim.fn.readfile(root_html), "\n")
			assert.is_truthy(root_content:find("child%-link"), "Root should have child link")
			assert.is_truthy(root_content:find("child_chat%.html"), "Child link should point to child")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)

		it("A2: single file export unchanged when no tree", function()
			local solo_file = create_chat_file("2024-03-15-solo.md", [[---
topic: Solo Chat
file: 2024-03-15-solo.md
---
💬: Just a question

🤖: Just an answer
]])

			vim.cmd("edit " .. solo_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportHTML()

			local html_file = export_html_dir .. "/2024-03-15-solo_chat.html"
			assert.is_true(vim.fn.filereadable(html_file) == 1, "HTML file should exist")

			-- Should be the only file
			local all_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
			assert.equals(1, #all_files, "Should export exactly 1 file")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)

		it("A3: exports 3-level tree from middle node", function()
			create_chat_file("2024-01-01-gp.md", [[---
topic: Grandparent
file: 2024-01-01-gp.md
---
💬: Start

🤖: OK

🌿: 2024-01-02-parent.md: Parent
]])
			create_chat_file("2024-01-02-parent.md", [[---
topic: Parent
file: 2024-01-02-parent.md
---
🌿: 2024-01-01-gp.md: Grandparent

💬: Middle

🤖: OK

🌿: 2024-01-03-child.md: Child
]])
			local child = create_chat_file("2024-01-03-child.md", [[---
topic: Child
file: 2024-01-03-child.md
---
🌿: 2024-01-02-parent.md: Parent

💬: End

🤖: Done
]])

			-- Export from the middle (parent) node
			local parent_file = tmpdir .. "/2024-01-02-parent.md"
			vim.cmd("edit " .. parent_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportHTML()

			-- All 3 files should be exported
			local all_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
			assert.equals(3, #all_files, "Should export all 3 files in tree")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)
	end)

	describe("Group B: Markdown tree export", function()
		it("B1: exports tree with Jekyll post_url links", function()
			create_chat_file("2024-03-15-root.md", [[---
topic: Root Chat
file: 2024-03-15-root.md
tags: test
---
💬: Hello

🤖: Hi there

🌿: 2024-03-15-child.md: Child Chat
]])
			local child_file = create_chat_file("2024-03-15-child.md", [[---
topic: Child Chat
file: 2024-03-15-child.md
tags: test
---
🌿: 2024-03-15-root.md: Root Chat

💬: Follow up

🤖: Response
]])

			vim.cmd("edit " .. child_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportMarkdown()

			-- Both files should be exported
			local root_md = export_markdown_dir .. "/2024-03-15-root_chat.markdown"
			local child_md = export_markdown_dir .. "/2024-03-15-child_chat.markdown"
			assert.is_true(vim.fn.filereadable(root_md) == 1, "Root markdown should exist")
			assert.is_true(vim.fn.filereadable(child_md) == 1, "Child markdown should exist")

			-- Child should have styled parent link with post_url
			local child_content = table.concat(vim.fn.readfile(child_md), "\n")
			assert.is_truthy(child_content:find("parent%-link"), "Child should have parent-link class")
			assert.is_truthy(child_content:find("post_url"), "Back link should use post_url")

			-- Root should have styled child link with post_url
			local root_content = table.concat(vim.fn.readfile(root_md), "\n")
			assert.is_truthy(root_content:find("child%-link"), "Root should have child-link class")
			assert.is_truthy(root_content:find("post_url"), "Branch link should use post_url")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)

		it("B2: markdown branch links use styled HTML divs", function()
			create_chat_file("2024-03-15-root.md", [[---
topic: Root Chat
file: 2024-03-15-root.md
tags: test
---
💬: Hello

🤖: Hi there

🌿: 2024-03-15-child.md: Child Chat
]])
			local child_file = create_chat_file("2024-03-15-child.md", [[---
topic: Child Chat
file: 2024-03-15-child.md
tags: test
---
🌿: 2024-03-15-root.md: Root Chat

💬: Follow up

🤖: Response
]])

			vim.cmd("edit " .. child_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportMarkdown()

			-- Check that branch links use styled HTML divs
			local child_md = export_markdown_dir .. "/2024-03-15-child_chat.markdown"
			local child_content = table.concat(vim.fn.readfile(child_md), "\n")
			assert.is_truthy(child_content:find("branch%-nav"), "Should have branch-nav class")
			assert.is_truthy(child_content:find("parent%-link"), "Should have parent-link class")

			local root_md = export_markdown_dir .. "/2024-03-15-root_chat.markdown"
			local root_content = table.concat(vim.fn.readfile(root_md), "\n")
			assert.is_truthy(root_content:find("child%-link"), "Should have child-link class")

			-- Check that branch-nav CSS is in the style block
			assert.is_truthy(child_content:find("%.branch%-nav"), "Should include branch-nav CSS")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)

		it("B4: refuses export when tree has duplicate topics", function()
			create_chat_file("2024-03-15-root.md", [[---
topic: Same Topic
file: 2024-03-15-root.md
---
💬: Hello

🤖: Hi

🌿: 2024-03-15-child.md: Same Topic
]])
			local child_file = create_chat_file("2024-03-15-child.md", [[---
topic: Same Topic
file: 2024-03-15-child.md
---
🌿: 2024-03-15-root.md: Same Topic

💬: Follow up

🤖: Response
]])

			vim.cmd("edit " .. child_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportMarkdown()

			-- No files should be exported due to collision
			local all_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
			assert.equals(0, #all_files, "Should not export when filenames collide")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)

		it("B5: single file export unchanged when no tree", function()
			local solo_file = create_chat_file("2024-03-15-solo.md", [[---
topic: Solo Chat
file: 2024-03-15-solo.md
tags: test
---
💬: Just a question

🤖: Just an answer
]])

			vim.cmd("edit " .. solo_file)
			local buf = vim.api.nvim_get_current_buf()
			M.cmd.ExportMarkdown()

			local all_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
			assert.equals(1, #all_files, "Should export exactly 1 file")

			-- Content should not contain branch navigation divs (CSS rule in style block is OK)
			local content = table.concat(vim.fn.readfile(all_files[1]), "\n")
			assert.is_falsy(content:find('<div class="branch%-nav'), "Should not have branch-nav divs")

			if vim.api.nvim_buf_is_valid(buf) then
				vim.cmd("bdelete! " .. buf)
			end
		end)
	end)
end)
