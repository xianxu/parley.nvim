-- Native structure boundary. Policy consumes only the returned snapshot facts.
local M = {}
local values = require("parley.skills.review.collaboration_value")
local LIMIT = 1024 * 1024
local function heading_name(name, atx)
    local first, last = 1, #name
    while first <= last and name:sub(first, first):match("%s") do first = first + 1 end
    while last >= first and name:sub(last, last):match("%s") do last = last - 1 end
    if atx then
        local hashes = last
        while hashes >= first and name:sub(hashes, hashes) == "#" do hashes = hashes - 1 end
        if hashes < last and hashes >= first and name:sub(hashes, hashes):match("%s") then
            last = hashes
            while last >= first and name:sub(last, last):match("%s") do last = last - 1 end
        end
    end
    return name:sub(first, last)
end

function M.snapshot(lines)
    local bytes = math.max(0, #lines - 1)
    for _, line in ipairs(lines) do
        bytes = bytes + #line
        if bytes > LIMIT then return nil, "chat structure exceeds the 1 MiB local snapshot limit" end
    end
    local header = values.header(lines)
    local body_start = header.readable and header.close + 1 or 1
    local legacy_evidence, legacy_error = values.evidence(lines, header)
    -- Closed metadata owns its bytes even when its legacy YAML is unreadable.
    -- Mask it before the Markdown grammar can promote metadata text to structure.
    local structural_start = header.closed and header.close + 1 or 1
    local source = {}
    for row, line in ipairs(lines) do source[row] = row < structural_start and "" or line end
    local text = table.concat(source, "\n")
    local ok, result = pcall(function()
        assert(vim.treesitter.language.add("markdown_inline"), "bundled Markdown inline parser unavailable")
        -- Only inline Markdown participates: fence language labels must never
        -- load another grammar or produce nested document headings.
        local parser = vim.treesitter.get_string_parser(text, "markdown", { injections = {
            markdown = [[((inline) @injection.content (#set! injection.language "markdown_inline"))]],
            markdown_inline = "",
        } })
        local trees = parser:parse(true)
        if not trees or not trees[1] then error("Markdown parser returned no tree") end
        local facts = { headings = {}, code_lines = {}, literal_lines = {}, literal_ranges = {}, body_start = body_start,
            bytes = bytes, work = bytes + #lines, legacy_read = true,
            protected_header_end = header.closed and header.close or nil,
            legacy_evidence = legacy_evidence, legacy_error = legacy_error }
        -- An explicit DFS avoids Lua recursion limits on deeply nested containers.
        local pending = {}
        parser:for_each_tree(function(tree) pending[#pending + 1] = tree:root() end)
        while #pending > 0 do
            local node = table.remove(pending)
            facts.work = facts.work + 1
            local kind = node:type()
            local sr, sc, er, ec = node:range()
            if kind == "fenced_code_block" or kind == "indented_code_block" or kind == "code_span" then
                local last = ec == 0 and er or er + 1
                facts.literal_ranges[#facts.literal_ranges + 1] = {
                    start_line = sr + 1, start_col = sc, end_line = er + 1, end_col = ec,
                }
                for row = sr + 1, last do
                    facts.literal_lines[row] = true
                    if kind ~= "code_span" then facts.code_lines[row] = true end
                    facts.work = facts.work + 1
                end
            elseif kind == "atx_heading" or kind == "setext_heading" then
                local level, name
                for child in node:iter_children() do
                    local child_kind = child:type()
                    level = level or tonumber(child_kind:match("^atx_h(%d)_marker$"))
                    if child_kind == "setext_h1_underline" then level = 1 end
                    if child_kind == "setext_h2_underline" then level = 2 end
                end
                local content = node:field("heading_content")[1]
                name = content and vim.treesitter.get_node_text(content, text) or ""
                name = heading_name(name, kind == "atx_heading")
                facts.headings[#facts.headings + 1] = { line = sr + 1, finish = ec == 0 and er or er + 1,
                    level = level, name = name, kind = kind == "atx_heading" and "atx" or "setext" }
            else
                for index = node:child_count() - 1, 0, -1 do pending[#pending + 1] = node:child(index) end
            end
        end
        return facts
    end)
    if not ok then return nil, "chat structure unavailable: " .. tostring(result) end
    return result
end
return M
