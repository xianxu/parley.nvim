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
	describe("Group E: assets (#231)", function()
		local TS = "2026-09-10.14-20-03.112"

		local function chat_with_image()
			local path = create_chat_file(
				TS .. "_img.md",
				"---\ntopic: Img\nfile: " .. TS .. "_img.md\n---\n💬: see\n\n![](assets/" .. TS .. "/a.png)\n\n🤖: ok\n"
			)
			vim.fn.mkdir(tmpdir .. "/assets/" .. TS, "p")
			assert.is_true(require("parley.assets").default_io.write(tmpdir .. "/assets/" .. TS .. "/a.png", "A"))
			vim.cmd("edit " .. path)
			return path
		end

		it("E1: markdown export copies the assets folder beside the files and keeps the source", function()
			chat_with_image()
			M.cmd.ExportMarkdown()
			assert.equals(1, vim.fn.filereadable(export_markdown_dir .. "/2026-09-10-img.markdown"), "export written")
			assert.equals(1, vim.fn.filereadable(export_markdown_dir .. "/assets/" .. TS .. "/a.png"), "copy present")
			assert.equals(1, vim.fn.filereadable(tmpdir .. "/assets/" .. TS .. "/a.png"), "source kept")
			vim.cmd("bdelete!")
		end)

		it("E2: HTML export renders the image and copies the folder", function()
			chat_with_image()
			M.cmd.ExportHTML()
			local out = export_html_dir .. "/2026-09-10-img.html"
			assert.equals(1, vim.fn.filereadable(out), "export written")
			local html = table.concat(vim.fn.readfile(out), "\n")
			assert.is_not_nil(html:find('<img src="assets/' .. TS .. '/a.png"', 1, true), html)
			assert.is_not_nil(html:find(".asset-image {", 1, true), "css rule present")
			assert.equals(1, vim.fn.filereadable(export_html_dir .. "/assets/" .. TS .. "/a.png"), "copy present")
			vim.cmd("bdelete!")
		end)

		it("E5: a branch token inside an image alt is not substituted across families (BR-9 round 2)", function()
			local child = create_chat_file(
				"2024-03-16-child.md",
				"---\ntopic: Child\nfile: 2024-03-16-child.md\n---\n💬: Hello\n\n🤖: Hi\n"
			)
			local root = create_chat_file(
				"2024-03-16-root.md",
				"---\ntopic: Root Chat\nfile: 2024-03-16-root.md\n---\n💬: see\n\n"
					.. "![XBRANCHX1XBRANCHX](missing.png)\n\n🤖: ok\n\n"
					.. "🌿: 2024-03-16-child.md: Child\n"
			)
			assert.is_not_nil(child)
			vim.cmd("edit " .. root)
			M.cmd.ExportHTML()
			local out = export_html_dir .. "/2024-03-16-root_chat.html"
			assert.equals(1, vim.fn.filereadable(out), "export written")
			local html = table.concat(vim.fn.readfile(out), "\n")
			-- The image keeps the literal token in its alt; no nav div inside any <img>.
			assert.is_not_nil(html:find('alt="XBRANCHX1XBRANCHX"', 1, true), html)
			for tag in html:gmatch("<img[^>]*>") do
				assert.is_nil(tag:find("branch%-nav"), "nav div inside an image tag: " .. tag)
				assert.is_nil(tag:find("<div", 1, true), "html inside an image tag: " .. tag)
			end
			local _, divs = html:gsub('<div class="branch%-nav ', "")
			assert.equals(1, divs, "exactly one nav div, for the real branch")
			vim.cmd("bdelete!")
		end)

		it("E4: token-shaped user text stays literal through the real HTML pipeline (BR-9)", function()
			-- A branch whose topic equals a branch token, and the reviewer's
			-- image input, in one exported chat.
			local child = create_chat_file(
				"2024-03-15-child.md",
				"---\ntopic: XBRANCHX1XBRANCHX\nfile: 2024-03-15-child.md\n---\n💬: Hello\n\n🤖: Hi\n"
			)
			local root = create_chat_file(
				"2024-03-15-root.md",
				"---\ntopic: Root Chat\nfile: 2024-03-15-root.md\n---\n💬: see\n\n"
					.. "![XIMGX2XIMGX](missing.png) ![](onerror=alert`1`//)\n\n🤖: ok\n\n"
					.. "🌿: 2024-03-15-child.md: XBRANCHX1XBRANCHX\n"
			)
			assert.is_not_nil(child)
			vim.cmd("edit " .. root)
			M.cmd.ExportHTML()
			local out = export_html_dir .. "/2024-03-15-root_chat.html"
			assert.equals(1, vim.fn.filereadable(out), "export written")
			local html = table.concat(vim.fn.readfile(out), "\n")

			-- One nav div, its topic literal, no placeholder residue.
			local _, divs = html:gsub('<div class="branch%-nav ', "")
			assert.equals(1, divs, html)
			assert.is_not_nil(html:find("&rarr; XBRANCHX1XBRANCHX</a></div>", 1, true), html)
			assert.is_nil(html:find("<p class='paragraph'>\nXBRANCHX", 1, true), html)

			-- Every <img> is exactly src/alt/class; nothing unquoted rides along.
			local imgs = {}
			for body in html:gmatch("<img([^>]*)>") do
				local attrs = {}
				local residue = body:gsub('%s*([%w%-]+)="([^"]*)"', function(k, v)
					attrs[k] = v
					return ""
				end)
				assert.equals("", residue, "img tag has non-attribute residue in: " .. body)
				imgs[#imgs + 1] = attrs
			end
			assert.equals(2, #imgs, html)
			assert.equals("missing.png", imgs[1].src)
			assert.equals("XIMGX2XIMGX", imgs[1].alt)
			assert.equals("onerror=alert`1`//", imgs[2].src)
			assert.is_nil(imgs[1].onerror)
			assert.is_nil(imgs[2].onerror)
			vim.cmd("bdelete!")
		end)

		it("E3: a failed copy is reported and the export still completes", function()
			-- A plain file where the assets directory must go: every mkdir fails.
			assert.is_true(require("parley.assets").default_io.write(export_html_dir .. "/assets", "not a dir"))
			local warnings = {}
			local original_warning = M.logger.warning
			M.logger.warning = function(message)
				table.insert(warnings, message)
			end
			chat_with_image()
			local ok, err = pcall(M.cmd.ExportHTML)
			M.logger.warning = original_warning
			assert.is_true(ok, tostring(err))
			assert.equals(1, vim.fn.filereadable(export_html_dir .. "/2026-09-10-img.html"), "export still written")
			assert.equals(0, vim.fn.filereadable(export_html_dir .. "/assets/" .. TS .. "/a.png"))
			local reported = false
			for _, w in ipairs(warnings) do
				if w:find("could not create", 1, true) and w:find(TS, 1, true) then
					reported = true
				end
			end
			assert.is_true(reported, "copy failure reported: " .. vim.inspect(warnings))
			vim.cmd("bdelete!")
		end)
	end)
end)
