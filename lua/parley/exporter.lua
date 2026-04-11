local M = {}
local _parley -- reference to the main parley module (M from init.lua)

M.setup = function(parley)
	_parley = parley
end

--------------------------------------------------------------------------------
-- Shared helpers
--------------------------------------------------------------------------------

local function sanitize_title(title)
	local slug = title:gsub("[^%w%s%-_]", ""):gsub("%s+", "_"):lower()
	if #slug > 50 then
		slug = slug:sub(1, 50)
	end
	return slug
end

local function extract_date(name)
	if not name or name == "" then
		return nil
	end
	local basename = name:gsub("%.md$", ""):gsub("%.markdown$", "")
	local year, month, day = basename:match("(%d%d%d%d)-(%d%d)-(%d%d)")
	if year and month and day then
		return year .. "-" .. month .. "-" .. day
	end
	return nil
end

local function resolve_chat_path(path, base_dir)
	if path:match("^~/") or path == "~" then
		return vim.fn.resolve(vim.fn.expand(path))
	elseif path:sub(1, 1) == "/" then
		return vim.fn.resolve(path)
	else
		return vim.fn.resolve(base_dir .. "/" .. path)
	end
end

local function get_parse_config()
	local cfg = _parley.config or {}
	return {
		chat_user_prefix = cfg.chat_user_prefix or "💬:",
		chat_local_prefix = cfg.chat_local_prefix or "🔒:",
		chat_assistant_prefix = cfg.chat_assistant_prefix or { "🤖:" },
		chat_branch_prefix = cfg.chat_branch_prefix or "🌿:",
		chat_memory = cfg.chat_memory or { enable = true, summary_prefix = "📝:", reasoning_prefix = "🧠:" },
	}
end

--- Extract the filename (tail) from a path. Pure string operation.
local function path_basename(path)
	return path:match("[^/]+$") or path
end

--- Extract filename without extension from a path. Pure string operation.
local function path_basename_no_ext(path)
	local base = path_basename(path)
	return base:match("^(.+)%.[^%.]+$") or base
end

--- Build an info table from already-loaded lines and a resolved abs_path.
--- Pure function: all dependencies passed as parameters.
--- @param lines table array of file lines
--- @param abs_path string resolved absolute path
--- @param chat_parser table parser module with find_header_end and parse_chat
--- @param parse_config table config for parse_chat
--- @param fallback_date string|nil fallback date if none found (default: os.date)
local function build_info(lines, abs_path, chat_parser, parse_config, fallback_date)
	if #lines == 0 then
		return nil
	end

	local header_end = chat_parser.find_header_end(lines)
	if not header_end then
		return nil
	end

	local parsed = chat_parser.parse_chat(lines, header_end, parse_config)
	local headers = parsed.headers

	local title = "Untitled"
	if headers and headers.topic and headers.topic ~= "" then
		title = headers.topic
	end

	local post_date = extract_date(headers and headers.file or "")
		or extract_date(path_basename(abs_path))
		or fallback_date
		or os.date("%Y-%m-%d")

	local tags = "[unclassified]"
	if headers and headers.tags then
		if type(headers.tags) == "table" and #headers.tags > 0 then
			tags = "[" .. table.concat(headers.tags, ", ") .. "]"
		elseif type(headers.tags) == "string" and headers.tags ~= "" then
			tags = "[" .. headers.tags .. "]"
		end
	end

	local slug = sanitize_title(title)
	if slug == "" then
		slug = path_basename_no_ext(abs_path)
	end

	return {
		abs_path = abs_path,
		lines = lines,
		header_end = header_end,
		parsed = parsed,
		title = title,
		post_date = post_date,
		tags = tags,
		slug = slug,
	}
end

--- Read and parse a chat file from disk, returning export metadata.
--- IO wrapper: reads file, resolves path, then delegates to pure build_info.
local function read_chat_file(file_path)
	local abs_path = vim.fn.resolve(vim.fn.expand(file_path))
	if vim.fn.filereadable(abs_path) == 0 then
		return nil
	end
	local lines = vim.fn.readfile(abs_path)
	return build_info(lines, abs_path, _parley.chat_parser, get_parse_config())
end

--- Build an info table from buffer lines (for the current buffer, which may have unsaved changes).
--- IO wrapper: resolves path, then delegates to pure build_info.
local function build_info_from_lines(lines, file_path)
	return build_info(lines, vim.fn.resolve(vim.fn.expand(file_path)), _parley.chat_parser, get_parse_config())
end

--------------------------------------------------------------------------------
-- Tree discovery
--------------------------------------------------------------------------------

local function find_tree_root(file_path, depth)
	depth = depth or 0
	if depth > 20 then
		return file_path
	end
	local abs_path = vim.fn.resolve(vim.fn.expand(file_path))
	if vim.fn.filereadable(abs_path) == 0 then
		return abs_path
	end

	local info = read_chat_file(abs_path)
	if not info or not info.parsed.parent_link then
		return abs_path
	end

	local parent_dir = vim.fn.fnamemodify(abs_path, ":h")
	local parent_abs = resolve_chat_path(info.parsed.parent_link.path, parent_dir)
	if vim.fn.filereadable(parent_abs) == 0 then
		return abs_path
	end
	return find_tree_root(parent_abs, depth + 1)
end

--- Collect all files in a chat tree, returning a list of info objects.
--- Each entry is the parsed info table (from build_info/read_chat_file).
--- Files that exist but can't be parsed are skipped.
local function collect_tree(file_path, visited)
	visited = visited or {}
	local abs_path = vim.fn.resolve(vim.fn.expand(file_path))
	if visited[abs_path] then
		return {}
	end
	visited[abs_path] = true
	if vim.fn.filereadable(abs_path) == 0 then
		return {}
	end

	local info = read_chat_file(abs_path)
	if not info then
		return {}
	end

	local result = { info }
	local file_dir = vim.fn.fnamemodify(abs_path, ":h")
	for _, branch in ipairs(info.parsed.branches) do
		local child_abs = resolve_chat_path(branch.path, file_dir)
		local child_infos = collect_tree(child_abs, visited)
		for _, child_info in ipairs(child_infos) do
			table.insert(result, child_info)
		end
	end
	return result
end

--- Build a map from abs_path -> export_filename from a list of info objects.
local function build_link_map(tree_infos, extension)
	local map = {}
	for _, info in ipairs(tree_infos) do
		map[info.abs_path] = info.post_date .. "-" .. info.slug .. "." .. extension
	end
	return map
end

--- Check for duplicate export filenames in the link map.
--- Returns a table of { filename = { path1, path2, ... } } for collisions, or nil if none.
local function check_filename_collisions(link_map)
	local by_filename = {}
	for abs_path, filename in pairs(link_map) do
		by_filename[filename] = by_filename[filename] or {}
		table.insert(by_filename[filename], abs_path)
	end
	local collisions = {}
	for filename, paths in pairs(by_filename) do
		if #paths > 1 then
			collisions[filename] = paths
		end
	end
	if next(collisions) then
		return collisions
	end
	return nil
end

--------------------------------------------------------------------------------
-- Branch line processing
--------------------------------------------------------------------------------

--- Build a branch navigation div (shared by both HTML and markdown formats).
--- @param opts table|nil optional { markdown_safe = true } to add markdown="0" for Kramdown
local function make_branch_div(class, arrow, topic, href, opts)
	local md_attr = (opts and opts.markdown_safe) and ' markdown="0"' or ""
	if href then
		return '<div class="branch-nav '
			.. class
			.. '"'
			.. md_attr
			.. '><a href="'
			.. href
			.. '">'
			.. arrow
			.. " "
			.. topic
			.. "</a></div>"
	end
	return '<div class="branch-nav ' .. class .. '"' .. md_attr .. ">" .. arrow .. " " .. topic .. "</div>"
end

--- Process lines, replacing 🌿: branch lines with navigation links.
--- Pure function: all dependencies passed as parameters.
--- For HTML format, returns placeholders that must be swapped after markdown-to-HTML conversion.
--- For markdown format, returns the final styled HTML divs (Jekyll renders inline HTML).
--- @param lines table array of all lines in the file
--- @param parsed table parsed chat structure
--- @param format string "html" or "markdown"
--- @param link_map table|nil map from abs_path -> export filename
--- @param file_dir string directory containing this chat file
--- @param branch_prefix string the prefix for branch lines (e.g. "🌿:")
--- @param resolve_fn function(path, base_dir) -> abs_path resolver
--- @return table processed_lines, table placeholders (html only; key->html)
local function process_branch_lines(lines, parsed, format, link_map, file_dir, branch_prefix, resolve_fn)
	branch_prefix = branch_prefix or "🌿:"
	resolve_fn = resolve_fn or resolve_chat_path
	local processed = {}
	local placeholders = {}
	local placeholder_count = 0
	local first_branch_seen = false

	for _, line in ipairs(lines) do
		if line:sub(1, #branch_prefix) == branch_prefix then
			local rest = line:sub(#branch_prefix + 1):gsub("^%s*(.-)%s*$", "%1")
			local path, topic = rest:match("^%s*([^:]+)%s*:%s*(.-)%s*$")
			if not path then
				path = rest
				topic = ""
			end
			path = path:gsub("^%s*(.-)%s*$", "%1")
			topic = (topic or ""):gsub("^%s*(.-)%s*$", "%1")
			if topic == "" then
				topic = path
			end

			local abs_target = resolve_fn(path, file_dir)
			local target_filename = link_map and link_map[abs_target]
			local is_parent = not first_branch_seen and parsed.parent_link ~= nil
			first_branch_seen = true

			local class = is_parent and "parent-link" or "child-link"
			local arrow_text = is_parent and "←" or "→"
			local arrow_html = is_parent and "&larr;" or "&rarr;"

			if format == "html" then
				placeholder_count = placeholder_count + 1
				local key = "XBRANCHX" .. placeholder_count .. "XBRANCHX"
				placeholders[key] = make_branch_div(class, arrow_html, topic, target_filename)
				table.insert(processed, key)
			elseif format == "markdown" then
				local href = nil
				if target_filename then
					local slug = target_filename:gsub("%.markdown$", "")
					href = "{% post_url " .. slug .. " %}"
				end
				-- Blank lines + markdown="0" so Kramdown doesn't mangle block HTML
				table.insert(processed, "")
				table.insert(processed, make_branch_div(class, arrow_text, topic, href, { markdown_safe = true }))
				table.insert(processed, "")
			end
		else
			-- Replace inline branch links [🌿:text](file) with <a> tags
			local chat_parser = require("parley.chat_parser")
			local inline_links = chat_parser.extract_inline_branch_links(line, branch_prefix)
			if #inline_links > 0 then
				-- Replace from right to left so positions stay valid
				local replaced = line
				for idx = #inline_links, 1, -1 do
					local link = inline_links[idx]
					local abs_target = resolve_fn(link.path, file_dir)
					local target_filename = link_map and link_map[abs_target]
					local replacement
					if not target_filename then
						replacement = link.topic
					elseif format == "html" then
						placeholder_count = placeholder_count + 1
						local key = "XBRANCHX" .. placeholder_count .. "XBRANCHX"
						placeholders[key] = '<a href="' .. target_filename .. '" class="branch-inline">' .. link.topic .. "</a>"
						replacement = key
					elseif format == "markdown" then
						local slug = target_filename:gsub("%.markdown$", "")
						replacement = '<a href="{% post_url ' .. slug .. ' %}" class="branch-inline">' .. link.topic .. "</a>"
					else
						replacement = link.topic
					end
					replaced = replaced:sub(1, link.col_start - 1) .. replacement .. replaced:sub(link.col_end + 1)
				end
				table.insert(processed, replaced)
			else
				table.insert(processed, line)
			end
		end
	end

	return processed, placeholders
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
		return '\n<div class="code-block"><pre><code'
			.. class_attr
			.. ">"
			.. code
			.. "</code></pre></div>\n"
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

--------------------------------------------------------------------------------
-- HTML CSS template (branch-nav styles added)
--------------------------------------------------------------------------------

local html_css = [[
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

        /* Branch navigation links */
        .branch-nav {
            margin: 1rem 0;
            padding: 0.6rem 1rem;
            border-radius: 8px;
            font-size: 0.95em;
        }

        .branch-nav a {
            text-decoration: none;
            font-weight: 500;
        }

        .branch-nav a:hover {
            text-decoration: underline;
        }

        .branch-nav.parent-link {
            background: linear-gradient(135deg, #fefcbf 0%, #faf089 100%);
            border-left: 4px solid #d69e2e;
            color: #744210;
        }

        .branch-nav.parent-link a {
            color: #975a16;
        }

        .branch-nav.child-link {
            background: linear-gradient(135deg, #c6f6d5 0%, #9ae6b4 100%);
            border-left: 4px solid #38a169;
            color: #22543d;
        }

        .branch-nav.child-link a {
            color: #276749;
        }

        /* Inline branch links (footnote-style) */
        .branch-inline {
            color: #2b6cb0;
            text-decoration: none;
            border-bottom: 1px dashed #90cdf4;
            font-weight: 500;
        }

        .branch-inline:hover {
            color: #1a365d;
            border-bottom-style: solid;
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
    </style>]]

--------------------------------------------------------------------------------
-- Single-file export core logic
--------------------------------------------------------------------------------

local function write_html_file(info, export_dir, link_map)
	local file_dir = vim.fn.fnamemodify(info.abs_path, ":h")
	local branch_prefix = (_parley.config and _parley.config.chat_branch_prefix) or "🌿:"
	local processed_lines, placeholders =
		process_branch_lines(info.lines, info.parsed, "html", link_map, file_dir, branch_prefix, resolve_chat_path)

	local content = table.concat(processed_lines, "\n")
	content = content:gsub("💬:", "## Question\n\n")

	local output_file = info.post_date .. "-" .. info.slug .. ".html"
	local full_output_path = export_dir .. "/" .. output_file

	local body_html = M.simple_markdown_to_html(content)

	-- Replace branch placeholders (they may be wrapped in <p> tags)
	for key, replacement in pairs(placeholders) do
		body_html = body_html:gsub("<p[^>]*>%s*" .. key .. "%s*</p>", replacement)
		body_html = body_html:gsub(key, replacement)
	end

	local html_template = [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>]] .. info.title .. [[</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/github.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
]] .. html_css .. [[

</head>
<body>
]] .. body_html .. [[

</body>
</html>]]

	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		_parley.logger.error("Failed to create output file: " .. full_output_path)
		return nil
	end

	file_handle:write(html_template)
	file_handle:close()
	return full_output_path
end

local function write_markdown_file(info, export_dir, link_map)
	local file_dir = vim.fn.fnamemodify(info.abs_path, ":h")

	-- Process body lines only (after header)
	local body_lines = {}
	for i = info.header_end + 1, #info.lines do
		table.insert(body_lines, info.lines[i])
	end

	local branch_prefix = (_parley.config and _parley.config.chat_branch_prefix) or "🌿:"
	local processed_lines = process_branch_lines(body_lines, info.parsed, "markdown", link_map, file_dir, branch_prefix, resolve_chat_path)
	local content = table.concat(processed_lines, "\n")
	content = content:gsub("💬:", "## Question\n\n")

	-- Use single quotes for title to avoid breaking YAML when topic contains double quotes
	local headers = info.parsed and info.parsed.headers or {}
	local hidden_line = ""
	if headers.hidden and headers.hidden ~= "" then
		hidden_line = "\nhidden: " .. headers.hidden
	end
	local jekyll_header = "---\nlayout: post\ntitle:  '"
		.. info.title:gsub("'", "''")
		.. "'\ndate:   "
		.. info.post_date
		.. "\ntags: "
		.. info.tags
		.. "\ncomments: true"
		.. hidden_line
		.. "\n---\n\n"

	local style_block = [[<style>
h1 { color: #1a365d; border-bottom: 3px solid #4299e1; padding-bottom: 0.3rem; }
h2 { color: #2b6cb0; border-bottom: 2px solid #bee3f8; padding-bottom: 0.3rem; }
h3 { color: #3182ce; border-left: 4px solid #90cdf4; padding-left: 0.8rem; }
.branch-nav { margin: 1rem 0; padding: 0.6rem 1rem; border-radius: 8px; font-size: 0.95em; }
.branch-nav a { text-decoration: none; font-weight: 500; }
.branch-nav a:hover { text-decoration: underline; }
.branch-nav.parent-link { background: linear-gradient(135deg, #fefcbf 0%, #faf089 100%); border-left: 4px solid #d69e2e; color: #744210; }
.branch-nav.parent-link a { color: #975a16; }
.branch-nav.child-link { background: linear-gradient(135deg, #c6f6d5 0%, #9ae6b4 100%); border-left: 4px solid #38a169; color: #22543d; }
.branch-nav.child-link a { color: #276749; }
.branch-inline { color: #2b6cb0; text-decoration: none; border-bottom: 1px dashed #90cdf4; font-weight: 500; }
.branch-inline:hover { color: #1a365d; border-bottom-style: solid; }
</style>

]]

	local watermark = "This transcript is generated by [parley.nvim](https://github.com/xianxu/parley.nvim).\n\n"
	content = jekyll_header .. style_block .. watermark .. content

	local output_file = info.post_date .. "-" .. info.slug .. ".markdown"
	local full_output_path = export_dir .. "/" .. output_file

	local file_handle = io.open(full_output_path, "w")
	if not file_handle then
		_parley.logger.error("Failed to create output file: " .. full_output_path)
		return nil
	end

	file_handle:write(content)
	file_handle:close()
	return full_output_path
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Shared export orchestration for both HTML and Markdown formats.
local function export_tree(params, format, write_fn, config_dir_key, extension)
	local buf = vim.api.nvim_get_current_buf()
	local file_name = vim.api.nvim_buf_get_name(buf)

	local validation_error = _parley.not_chat(buf, file_name)
	if validation_error then
		_parley.logger.error("Cannot export: " .. validation_error)
		print("Error: Cannot export - " .. validation_error)
		return
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	if #lines == 0 then
		_parley.logger.error("Buffer is empty")
		print("Error: Buffer is empty")
		return
	end

	local export_dir = params and params.args and params.args ~= "" and params.args or _parley.config[config_dir_key]

	-- Build info for the current buffer
	local current_info = build_info_from_lines(lines, file_name)
	if not current_info then
		_parley.logger.error("Cannot export: invalid chat header format")
		print("Error: Cannot export - invalid chat header format")
		return
	end

	-- Discover tree (collect_tree returns info objects, avoiding redundant reads)
	local root_path = find_tree_root(file_name)
	local tree_infos = collect_tree(root_path)
	local link_map = build_link_map(tree_infos, extension)

	-- Check for filename collisions
	local collisions = check_filename_collisions(link_map)
	if collisions then
		_parley.logger.error("Cannot export: duplicate export filenames detected")
		print("Error: Cannot export - multiple chat files would produce the same filename:")
		for filename, paths in pairs(collisions) do
			print("  " .. filename .. ":")
			for _, path in ipairs(paths) do
				print("    - " .. path)
			end
		end
		print("Fix by giving these chats distinct topics.")
		return
	end

	-- Export all files in the tree
	local exported = {}
	local skipped = {}
	for _, info in ipairs(tree_infos) do
		-- Use buffer lines for the current file (may have unsaved changes)
		local export_info = info
		if info.abs_path == current_info.abs_path then
			export_info = current_info
		end

		local output_path = write_fn(export_info, export_dir, link_map)
		if output_path then
			table.insert(exported, output_path)
		else
			table.insert(skipped, info.abs_path)
		end
	end

	-- Copy the current file's export path to clipboard
	local current_export = export_dir .. "/" .. current_info.post_date .. "-" .. current_info.slug .. "." .. extension
	vim.fn.setreg("+", current_export)

	local format_label = format == "html" and "HTML" or "Markdown"
	if #exported == 1 then
		_parley.logger.info("Exported chat to " .. format_label .. ": " .. exported[1])
		print("✅ Exported chat to: " .. exported[1] .. " (path copied to clipboard)")
	else
		_parley.logger.info("Exported " .. #exported .. " chat files to " .. format_label .. " in " .. export_dir)
		print(
			"✅ Exported "
				.. #exported
				.. " chat files to: "
				.. export_dir
				.. " (current file path copied to clipboard)"
		)
	end

	if #skipped > 0 then
		print("⚠️  Skipped " .. #skipped .. " files (missing or invalid)")
		for _, path in ipairs(skipped) do
			_parley.logger.warning("Skipped: " .. path)
		end
	end
end

M.export_html = function(params)
	export_tree(params, "html", write_html_file, "export_html_dir", "html")
end

M.export_markdown = function(params)
	export_tree(params, "markdown", write_markdown_file, "export_markdown_dir", "markdown")
end

-- Expose helpers for testing
--------------------------------------------------------------------------------
-- Pandoc export for non-chat markdown files
--------------------------------------------------------------------------------

--- Export current markdown buffer to a self-contained HTML file via pandoc.
--- Output goes next to the source file with .html extension.
M.pandoc_export_html = function()
	-- Check pandoc is available
	if vim.fn.executable("pandoc") ~= 1 then
		_parley.logger.error("pandoc not found. Install with: brew install pandoc")
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(buf)
	if file_path == "" then
		_parley.logger.error("Buffer has no file name — save it first")
		return
	end

	-- Save buffer if modified
	if vim.bo[buf].modified then
		vim.cmd("silent! write")
	end

	local output_path = file_path:gsub("%.md$", ""):gsub("%.markdown$", "") .. ".html"

	local cmd = {
		"pandoc",
		file_path,
		"-s",
		"--self-contained",
		"-o",
		output_path,
	}

	vim.fn.jobstart(cmd, {
		on_exit = function(_, code)
			vim.schedule(function()
				if code == 0 then
					vim.fn.setreg("+", output_path)
					_parley.logger.info("Exported HTML (path copied): " .. output_path)
					vim.fn.jobstart({ "open", "-R", output_path })
				else
					_parley.logger.error("pandoc failed (exit " .. code .. "). Try: pandoc " .. file_path .. " -s -o " .. output_path)
				end
			end)
		end,
	})
end

-- Pure functions (no _parley, no vim.fn, no IO — fully unit-testable)
M._sanitize_title = sanitize_title
M._extract_date = extract_date
M._build_info = build_info
M._build_link_map = build_link_map
M._check_filename_collisions = check_filename_collisions
M._make_branch_div = make_branch_div
M._process_branch_lines = process_branch_lines
-- IO wrappers (need parley setup and filesystem)
M._read_chat_file = read_chat_file
M._find_tree_root = find_tree_root
M._collect_tree = collect_tree

return M
