-- Occurrence enumeration and picker completion. Destinations stay textual;
-- callers may supply review tag rows from the operation's native snapshot.
-- the editor boundary owns resolution, opening and all buffer/window effects.
local M = {}

-- Preserve issues.lua's existing Markdown dialect and 1-based inclusive spans.
function M.markdown_links(line)
    local links, pos, url_end = {}, 1, nil
    while line do
        local first = line:find("[", pos, true)
        if not first then break end
        local closing = line:find("[%]%z]", first + 1)
        if not closing then break end
        -- All openings before this barrier share the same first label closing.
        pos = closing + 1
        if line:byte(closing) == 93 and line:byte(closing + 1) == 40 then
            local url_start = closing + 2
            -- Failed destinations may contain another opening whose label wraps
            -- across the failing newline. Search those openings too, retaining
            -- the next URL delimiter so repeated failures never rescan a suffix.
            if not url_end or url_start > url_end then
                url_end = line:find("[)%z\n]", url_start)
            end
            if not url_end then break end
            if line:byte(url_end) == 41 and url_end > url_start then
                links[#links + 1] = {
                    text = line:sub(first + 1, closing - 1),
                    url = line:sub(url_start, url_end - 1),
                    start_col = first, end_col = url_end,
                }
                pos = url_end + 1
            else
                pos = url_start
            end
        end
    end
    return links
end

-- The supported Markdown block dialect, shared by wrapped occurrence scanning
-- and code containment. List starts break before, retaining their continuation;
-- headings/walls isolate their row. Excluded rows carry no inline syntax.
-- opener/indent/content_indent describe navigation ownership without importing
-- the editing heading dialect; only a fence opener has navigation structure.
function M.markdown_blocks(lines, range, opts)
    if not range then return {} end
    opts = opts or {}
    local lexical = require("parley.document.lexical")
    local patterns = lexical.patterns(opts.config or {})
    local in_code = opts.in_code or lexical.code_block_memo(lines, patterns, true, opts.transcript)
    local out = {}
    for row = math.max(1, range.first), math.min(#lines, range.last) do
        local line = lines[row]
        local indent = #(line:match("^%s*") or "")
        local content = line:sub(indent + 1)
        local hashes = content:match("^(#+)%s") or content:match("^(#+)$")
        local heading = hashes and #hashes <= 6
        local compact = content:gsub("%s", "")
        local wall = content:match("^%-+%s*$") or content:match("^=+%s*$")
            or compact:match("^%-%-%-+$") or compact:match("^%*%*%*+$") or compact:match("^___+$")
        local quote = content:match("^>")
        local kind = opts.transcript ~= false and lexical.classify(line, patterns).kind
        local structural = lexical.is_structural_kind(kind) or kind == "reasoning" or kind == "reasoning_end"
        local fence = lexical.is_fence_delim(line, true)
        local opening = fence and in_code[row] and not in_code[row - 1]
        local bullet = content:match("^[-+*]%s+")
        local numbered = content:match("^%d+[.)]%s+")
        -- One block vocabulary serves occurrence barriers and navigation. Walls
        -- win over list markers ("- - -"), and fenced examples have no openers.
        local opener, content_indent
        if opening then
            opener = "fence"
        elseif not in_code[row] and not fence then
            if heading then opener = "heading"
            elseif wall then opener = "wall"
            elseif quote then opener = "quote"
            elseif bullet then opener, content_indent = "bullet", indent + #bullet
            elseif numbered then opener, content_indent = "numbered", indent + #numbered
            elseif kind == "user" or kind == "assistant" then opener = "turn" end
        end
        -- Wrapped-link scanning retains its established up-to-three-space
        -- block dialect; navigation uses the same classes relative to items.
        local inline_wall = indent <= 3 and line:sub(1, indent):match("^ *$")
            and (heading or wall or quote)
        out[row] = {
            before = not not (inline_wall or structural or bullet or numbered),
            after = not not inline_wall,
            excluded = not not (in_code[row] or fence or line:match("^%s*$")),
            opener = opener, indent = indent, content_indent = content_indent,
        }
    end
    return out
end

-- Join paragraph text once; NUL barriers prevent links crossing excluded rows.
-- Mapping offsets in occurrence order keeps byte coordinates linear in input size.
function M.markdown_spans(lines, range, opts)
    if not range then return {} end
    local blocks = M.markdown_blocks(lines, range, opts)
    local first, last = math.max(1, range.first), math.min(#lines, range.last)
    local chunks, starts, size = {}, {}, 0
    for row = first, last do
        local block = blocks[row]
        local barrier = block.before and "\0" or ""
        local chunk = block.excluded and "\0" or barrier .. lines[row] .. (block.after and "\0" or "")
        starts[row], size = size + 1 + #barrier, size + #chunk + 1
        chunks[#chunks + 1] = chunk
    end
    local text, row, out = table.concat(chunks, "\n"), first, {}
    local function point(offset)
        while row < last and starts[row + 1] <= offset do row = row + 1 end
        return row, offset - starts[row]
    end
    for _, link in ipairs(M.markdown_links(text)) do
        local start_row, col = point(link.start_col)
        local fallback_row, fallback_col = point(link.start_col + #link.text + 3)
        local end_row, end_col = point(link.end_col)
        out[#out + 1] = {
            kind = "markdown", row = start_row, col = col, end_row = end_row, end_col = end_col + 1,
            label = link.text:gsub("%s*\n%s*", " "), target = link.url,
            fallback_row = fallback_row, fallback_col = fallback_col,
            span = text:sub(link.start_col, link.end_col),
        }
    end
    return out
end

-- `start` retains the legacy nearest-@@ parser's distance convention.
function M.at_references(line)
    local references, pos = {}, 1
    while line do
        local s, opening_end = line:find("@@", pos, true)
        if not s then break end
        local closing_start, e = line:find("@@", opening_end + 1, true)
        if not closing_start then break end
        local content = line:sub(opening_end + 1, closing_start - 1):gsub("^%s*(.-)%s*$", "%1")
        if content ~= "" then
            references[#references + 1] = { start = s, content = content, start_col = s, end_col = e }
        end
        pos = e + 1
    end
    return references
end

function M.branch_ref(line, prefix)
    if line:sub(1, #prefix) ~= prefix then return nil end
    local rest = line:sub(#prefix + 1):gsub("^%s*(.-)%s*$", "%1")
    local path = rest:match("^([^:]+)") or rest
    path = path:gsub("^%s*(.-)%s*$", "%1")
    if path == "" then return nil end
    local topic = rest:match("^[^:]+:%s*(.+)$") or ""
    topic = topic:gsub("^%s*(.-)%s*$", "%1")
    topic = topic:gsub("%s*⚠️%s*$", "")
    return { path = path, topic = topic }
end

-- Occurrence columns use 0-based start/inclusive, end/exclusive conventions.
-- A per-line byte mask gives Markdown/@@/branch precedence without quadratic
-- pairwise span comparisons; repeated destinations remain separate entries.
function M.collect(lines, range, opts)
    if not range then return {} end
    opts = opts or {}
    local lexical = require("parley.document.lexical")
    local patterns = lexical.patterns(opts.config or {})
    local in_code = opts.in_code or lexical.code_block_memo(lines, patterns, true, opts.transcript)
    local prefix = opts.branch_prefix or patterns.branch_prefix
    local artifact_ref = require("parley.artifact_ref")
    local out = {}
    local reserved, markdown = {}, {}
    local review = opts.review_tags or require("parley.question_tags").review_tags(lines)
    for _, item in ipairs(M.markdown_spans(lines, range, { in_code = in_code, config = opts.config, transcript = opts.transcript })) do
        markdown[item.row] = markdown[item.row] or {}
        markdown[item.row][item.col + 1] = item
        for row = item.row, item.end_row do
            reserved[row] = reserved[row] or {}
            local first = row == item.row and item.col + 1 or 1
            local last = row == item.end_row and item.end_col or #lines[row]
            for col = first, last do reserved[row][col] = true end
        end
    end
    for row = math.max(1, range.first), math.min(#lines, range.last) do
        local line = lines[row]
        if not in_code[row] and not lexical.is_fence_delim(line, true) then
            local occupied, row_items = reserved[row] or {}, markdown[row] or {}
            local function add(kind, s, e, label, target, fallback)
                for i = s, e do
                    if occupied[i] then return end
                end
                for i = s, e do occupied[i] = true end
                row_items[s] = {
                    kind = kind, row = row, col = s - 1, end_col = e,
                    label = label, target = target, fallback_col = fallback - 1,
                }
            end
            for _, ref in ipairs(not review[row] and M.at_references(line) or {}) do
                local destination = line:find(ref.content, ref.start_col + 2, true)
                add("at", ref.start_col, ref.end_col, ref.content, ref.content, destination)
            end
            local branch = M.branch_ref(line, prefix)
            if branch then
                local destination = line:find(branch.path, #prefix + 1, true)
                add("branch", 1, destination + #branch.path - 1,
                    branch.topic ~= "" and branch.topic or branch.path, branch.path, destination)
            end
            for s, ref, e in artifact_ref.iter_refs(line) do
                add("artifact", s, e - 1, ref, ref, s)
            end
            for col = 1, #line do
                if row_items[col] then out[#out + 1] = row_items[col] end
            end
        end
    end
    return out
end

function M.begin_selection(origin, items)
    return {
        tag = "pending",
        origin = { buf = origin.buf, win = origin.win, tick = origin.tick, generation = origin.generation },
        items = items,
    }
end

function M.finish_selection(state, event)
    local none = { kind = "none" }
    if state.tag ~= "pending" then return state, none end
    local settled = { tag = "settled" }
    local current = event and event.current
    if not current then return settled, none end
    for _, key in ipairs({ "buf", "win", "tick", "generation" }) do
        if current[key] == nil or state.origin[key] == nil or current[key] ~= state.origin[key] then
            return settled, none
        end
    end
    local index = event.index
    if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #state.items then
        return settled, none
    end
    return settled, { kind = "open", item = state.items[index] }
end

return M
