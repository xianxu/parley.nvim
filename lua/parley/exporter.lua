local M = {}
local _parley -- reference to the main parley module (M from init.lua)

M.setup = function(parley)
	_parley = parley
end

--------------------------------------------------------------------------------
-- Markdown / HTML export helpers
--------------------------------------------------------------------------------

-- Enhanced markdown to HTML converter with glow-like styling
M.simple_markdown_to_html = function(markdown)
	local html = markdown

	-- Escape HTML special characters first
	html = html:gsub("&", "&amp;")
	html = html:gsub("<", "&lt;")
	html = html:gsub(">", "&gt;")

	-- Convert code blocks with language-specific styling
	html = html:gsub("```([^\n]*)\n(.-)\n```", function(lang, code)
		local class_attr = ""
		if lang and lang ~= "" then
			class_attr = ' class="language-' .. lang .. '"'
		end
		return '\n<div class="code-block"><pre><code' .. class_attr .. ">" .. code .. "</code></pre></div>\n"
	end)

	-- Convert inline code
	html = html:gsub("`([^`\n]+)`", '<code class="inline-code">%1</code>')

	-- Convert headers with proper spacing
	html = html:gsub("^# ([^\n]+)", '<h1 class="main-header">%1</h1>')
	html = html:gsub("\n# ([^\n]+)", '\n<h1 class="main-header">%1</h1>')
	html = html:gsub("^## ([^\n]+)", '<h2 class="section-header">%1</h2>')
	html = html:gsub("\n## ([^\n]+)", '\n<h2 class="section-header">%1</h2>')
	html = html:gsub("^### ([^\n]+)", '<h3 class="sub-header">%1</h3>')
	html = html:gsub("\n### ([^\n]+)", '\n<h3 class="sub-header">%1</h3>')

	-- Convert bold and italic text
	html = html:gsub("%*%*([^%*\n]+)%*%*", '<strong class="bold-text">%1</strong>')
	html = html:gsub("__([^_\n]+)__", '<strong class="bold-text">%1</strong>')
	html = html:gsub("%*([^%*\n]+)%*", '<em class="italic-text">%1</em>')
	html = html:gsub("_([^_\n]+)_", '<em class="italic-text">%1</em>')

	-- Convert lists
	html = html:gsub("\n%- ([^\n]+)", '\n<li class="list-item">%1</li>')
	html = html:gsub("(<li[^>]*>.-</li>)", '<ul class="bullet-list">%1</ul>')

	-- Convert blockquotes
	html = html:gsub("\n> ([^\n]+)", '\n<blockquote class="quote">%1</blockquote>')

	-- Handle paragraphs more carefully
	html = html:gsub("\n\n+", "\n</p>\n<p class='paragraph'>\n")
	html = '<p class="paragraph">' .. html .. "</p>"

	-- Clean up and fix paragraph wrapping around block elements
	html = html:gsub("<p[^>]*>%s*<h", "<h")
	html = html:gsub("</h([123])>%s*</p>", "</h%1>")
	html = html:gsub("<p[^>]*>%s*<div", "<div")
	html = html:gsub("</div>%s*</p>", "</div>")
	html = html:gsub("<p[^>]*>%s*<ul", "<ul")
	html = html:gsub("</ul>%s*</p>", "</ul>")
	html = html:gsub("<p[^>]*>%s*<blockquote", "<blockquote")
	html = html:gsub("</blockquote>%s*</p>", "</blockquote>")
	html = html:gsub("<p[^>]*>%s*</p>", "")

	return html
end

-- Export current chat buffer as HTML
M.export_html = function(params)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- Check if this is a valid chat file
	local validation_error = _parley.not_chat(buf, file_name)
	if validation_error then
		_parley.logger.error("Cannot export: " .. validation_error)
		print("Error: Cannot export - " .. validation_error)
		return
	end

	-- Get all buffer lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		_parley.logger.error("Buffer is empty")
		print("Error: Buffer is empty")
		return
	end

	-- Convert content to markdown format suitable for processing
	local content = table.concat(lines, "\n")

	-- Replace 💬: with ## Question (similar to your sed command)
	content = content:gsub("💬:", "## Question\n\n")

	-- Extract title from first line for filename and HTML title
	local title = "Untitled"
	local html_filename

	if lines[1] and lines[1]:match("^# (.+)") then
		title = lines[1]:match("^# (.+)")
		-- Clean title for filename (remove invalid characters and normalize)
		html_filename = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
		-- Limit filename length
		if #html_filename > 50 then
			html_filename = html_filename:sub(1, 50)
		end
	else
		-- Fallback to timestamp-based filename if no title found
		local basename = vim.fn.fnamemodify(file_name, ":t:r")
		html_filename = basename
	end

	local output_file = html_filename .. ".html"

	-- Export directory (configurable, with CLI override)
	local export_dir = params and params.args and params.args ~= "" and params.args or _parley.config.export_html_dir
	local full_output_path = export_dir .. "/" .. output_file

	-- Create HTML content with enhanced glow-like styling
	local html_template = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. title .. [[</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
    <style>
        /* Base styling inspired by glow */
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Noto Sans', Helvetica, Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 40px 20px;
            background: linear-gradient(135deg, #fdfbfb 0%, #ebedee 100%);
            color: #2d3748;
            font-size: 16px;
        }

        /* Headers with glow-like styling */
        .main-header {
            font-size: 2.5rem;
            font-weight: 700;
            color: #1a365d;
            margin: 2rem 0 1.5rem 0;
            padding-bottom: 0.5rem;
            border-bottom: 3px solid #4299e1;
            text-shadow: 0 1px 2px rgba(0,0,0,0.1);
        }

        .section-header {
            font-size: 2rem;
            font-weight: 600;
            color: #2b6cb0;
            margin: 2.5rem 0 1rem 0;
            padding-bottom: 0.3rem;
            border-bottom: 2px solid #bee3f8;
            position: relative;
        }

        .section-header::before {
            content: '📋';
            margin-right: 0.5rem;
            font-size: 1.5rem;
        }

        .sub-header {
            font-size: 1.5rem;
            font-weight: 600;
            color: #3182ce;
            margin: 2rem 0 0.8rem 0;
            padding-left: 1rem;
            border-left: 4px solid #90cdf4;
        }

        /* Enhanced paragraphs */
        .paragraph {
            margin: 1.2rem 0;
            color: #4a5568;
            text-align: justify;
            text-justify: inter-word;
        }

        /* Code blocks with enhanced styling */
        .code-block {
            margin: 1.5rem 0;
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            border: 1px solid #e2e8f0;
        }

        .code-block pre {
            margin: 0;
            padding: 1.5rem;
            background: linear-gradient(135deg, #f7fafc 0%, #edf2f7 100%);
            border: none;
            overflow-x: auto;
            font-size: 0.9rem;
            line-height: 1.5;
        }

        .code-block code {
            font-family: 'Fira Code', 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            background: none;
            padding: 0;
            color: #2d3748;
        }

        /* Inline code with better styling */
        .inline-code {
            background: linear-gradient(135deg, #fed7e2 0%, #fbb6ce 100%);
            color: #97266d;
            padding: 0.2rem 0.4rem;
            border-radius: 6px;
            font-family: 'SF Mono', Monaco, 'Cascadia Code', 'Roboto Mono', Consolas, 'Courier New', monospace;
            font-size: 0.9em;
            font-weight: 500;
            border: 1px solid #f687b3;
        }

        /* Text formatting */
        .bold-text {
            color: #2d3748;
            font-weight: 700;
        }

        .italic-text {
            color: #4a5568;
            font-style: italic;
        }

        /* Lists with better styling */
        .bullet-list {
            margin: 1rem 0;
            padding-left: 0;
            list-style: none;
        }

        .list-item {
            position: relative;
            padding-left: 2rem;
            margin: 0.5rem 0;
            color: #4a5568;
        }

        .list-item::before {
            content: '•';
            color: #4299e1;
            font-weight: bold;
            position: absolute;
            left: 0.5rem;
            font-size: 1.2em;
        }

        /* Enhanced blockquotes */
        .quote {
            background: linear-gradient(135deg, #e6fffa 0%, #b2f5ea 100%);
            border-left: 4px solid #38b2ac;
            margin: 1.5rem 0;
            padding: 1rem 1.5rem;
            border-radius: 0 8px 8px 0;
            color: #234e52;
            font-style: italic;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        /* Special styling for chat elements */
        .chat-question {
            background: linear-gradient(135deg, #ebf8ff 0%, #bee3f8 100%);
            border-left: 4px solid #3182ce;
            border-radius: 0 12px 12px 0;
            padding: 1.5rem;
            margin: 2rem 0;
            position: relative;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }

        .chat-question::before {
            content: '💬';
            position: absolute;
            left: -0.5rem;
            top: 1rem;
            background: white;
            padding: 0.3rem;
            border-radius: 50%;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        /* Responsive design */
        @media (max-width: 768px) {
            body {
                padding: 20px 15px;
                font-size: 15px;
            }
            .main-header {
                font-size: 2rem;
            }
            .section-header {
                font-size: 1.6rem;
            }
            .code-block pre {
                padding: 1rem;
                font-size: 0.8rem;
            }
        }

        /* Syntax highlighting overrides */
        .hljs {
            background: transparent !important;
        }

        .hljs-keyword { color: #d73a49; font-weight: 600; }
        .hljs-string { color: #032f62; }
        .hljs-comment { color: #6a737d; font-style: italic; }
        .hljs-function { color: #6f42c1; }
        .hljs-number { color: #005cc5; }
        .hljs-variable { color: #e36209; }
    </style>
</head>
<body>
]] .. M.simple_markdown_to_html(content) .. [[
</body>
</html>]]

	-- Write HTML file
	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		_parley.logger.error("Failed to create output file: " .. full_output_path)
		print("Error: Failed to create output file: " .. full_output_path)
		return
	end

	file_handle:write(html_template)
	file_handle:close()

	vim.fn.setreg("+", full_output_path)
	_parley.logger.info("Exported chat to HTML: " .. full_output_path)
	print("✅ Exported chat to: " .. full_output_path .. " (path copied to clipboard)")
end

-- Export current chat buffer as Markdown for Jekyll
M.export_markdown = function(params)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	-- Check if this is a valid chat file
	local validation_error = _parley.not_chat(buf, file_name)
	if validation_error then
		_parley.logger.error("Cannot export: " .. validation_error)
		print("Error: Cannot export - " .. validation_error)
		return
	end

	-- Get all buffer lines
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		_parley.logger.error("Buffer is empty")
		print("Error: Buffer is empty")
		return
	end

	local cfg = _parley.config or {}
	local chat_parser = _parley.chat_parser
	local header_end = chat_parser.find_header_end(lines)
	if not header_end then
		_parley.logger.error("Cannot export: invalid chat header format")
		print("Error: Cannot export - invalid chat header format")
		return
	end
	local parse_config = {
		chat_user_prefix = cfg.chat_user_prefix or "💬:",
		chat_local_prefix = cfg.chat_local_prefix or "🔒:",
		chat_assistant_prefix = cfg.chat_assistant_prefix or { "🤖:" },
		chat_memory = cfg.chat_memory or {
			enable = true,
			summary_prefix = "📝:",
			reasoning_prefix = "🧠:",
		},
	}
	local parsed = chat_parser.parse_chat(lines, header_end, parse_config)
	local headers = parsed.headers

	-- Extract Jekyll front matter data from Parley header
	local title = "Untitled"
	local post_date = os.date("%Y-%m-%d")
	local tags = "unclassified"
	local markdown_filename

	-- Extract title from parsed headers
	if headers and headers.topic and headers.topic ~= "" then
		title = headers.topic
	end

	-- Extract date from transcript header filename first, then fallback to current file
	local transcript_filename = headers and headers.file or nil

	-- Try to extract date from transcript header filename first
	if transcript_filename then
		local basename = transcript_filename:gsub("%.md$", ""):gsub("%.markdown$", "")
		local year, month, day = basename:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
		if year and month and day then
			post_date = year .. "-" .. month .. "-" .. day
		end
	end

	-- Fallback: extract date from current filename if not found in header
	if post_date == os.date("%Y-%m-%d") then
		local current_basename = vim.fn.fnamemodify(file_name, ":t:r")
		local year, month, day = current_basename:match("^(%d%d%d%d)-(%d%d)-(%d%d)")
		if year and month and day then
			post_date = year .. "-" .. month .. "-" .. day
		end
	end

	-- Extract tags from parsed headers
	if headers and headers.tags then
		if type(headers.tags) == "table" then
			if #headers.tags > 0 then
				tags = table.concat(headers.tags, ", ")
			end
		elseif type(headers.tags) == "string" and headers.tags ~= "" then
			tags = headers.tags
		end
	end

	-- Clean title for filename (remove invalid characters and normalize)
	markdown_filename = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
	if #markdown_filename > 50 then
		markdown_filename = markdown_filename:sub(1, 50)
	end

	-- Create Jekyll front matter
	local jekyll_header = [[---
layout: post
title:  "]] .. title .. [["
date:   ]] .. post_date .. [[

tags: ]] .. tags .. [[

comments: true
---

]]

	-- Process content: replace 💬: with ## and remove Parley header
	local body_lines = {}
	for i = header_end + 1, #lines do
		table.insert(body_lines, lines[i])
	end
	local content = table.concat(body_lines, "\n")

	-- Replace 💬: with ## Question heading (styled like HTML export)
	content = content:gsub("💬:", "## Question\n\n")

	-- CSS style block matching HTML export color scheme
	local style_block = [[<style>
h1 { color: #1a365d; border-bottom: 3px solid #4299e1; padding-bottom: 0.3rem; }
h2 { color: #2b6cb0; border-bottom: 2px solid #bee3f8; padding-bottom: 0.3rem; }
h3 { color: #3182ce; border-left: 4px solid #90cdf4; padding-left: 0.8rem; }
</style>

]]

	-- Add watermark after Jekyll header
	local watermark = "This transcript is generated by [parley.nvim](https://github.com/xianxu/parley.nvim).\n\n"

	-- Combine Jekyll header with style block, watermark and processed content
	content = jekyll_header .. style_block .. watermark .. content

	-- Use extracted date for Jekyll filename prefix
	local output_file = post_date .. "-" .. markdown_filename .. ".markdown"

	-- Export directory (configurable, with CLI override)
	local export_dir = params and params.args and params.args ~= "" and params.args or _parley.config.export_markdown_dir
	local full_output_path = export_dir .. "/" .. output_file

	-- Write Markdown file
	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		_parley.logger.error("Failed to create output file: " .. full_output_path)
		print("Error: Failed to create output file: " .. full_output_path)
		return
	end

	file_handle:write(content)
	file_handle:close()

	vim.fn.setreg("+", full_output_path)
	_parley.logger.info("Exported chat to Markdown: " .. full_output_path)
	print("✅ Exported chat to: " .. full_output_path .. " (path copied to clipboard)")
end

return M
