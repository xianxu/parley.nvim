-- Pure occurrence enumeration and picker completion. Destinations stay textual;
-- the editor boundary owns resolution, opening and all buffer/window effects.
local M = {}

-- Preserve issues.lua's existing Markdown dialect and 1-based inclusive spans.
function M.markdown_links(line)
    local links, pos = {}, 1
    while line do
        local s, e, text, url = line:find("%[([^%]%z]*)%]%(([^)%z\n]+)%)", pos)
        if not s then break end
        links[#links + 1] = { text = text, url = url, start_col = s, end_col = e }
        pos = e + 1
    end
    return links
end

-- Join paragraph text once; NUL barriers prevent links crossing excluded rows.
-- Mapping offsets in occurrence order keeps byte coordinates linear in input size.
function M.markdown_spans(lines, range, opts)
    if not range then return {} end
    opts = opts or {}
    local lexical = require("parley.document.lexical")
    local patterns = lexical.patterns(opts.config or {})
    local in_code = opts.in_code or lexical.code_block_memo(lines, patterns, true, opts.transcript)
    local first, last = math.max(1, range.first), math.min(#lines, range.last)
    local chunks, starts, size = {}, {}, 0
    for row = first, last do
        local line = lines[row]
        local heading = require("parley.markdown_heading").level(line)
        local kind = opts.transcript ~= false and lexical.classify(line, patterns).kind
        local structural = lexical.is_structural_kind(kind) or kind == "reasoning" or kind == "reasoning_end"
        local boundary = structural or heading or line:match("^%s*%d+[.)]%s") or line:match("^%s*[-+*]%s")
        local barrier = boundary and "\0" or ""
        local chunk = (in_code[row] or lexical.is_fence_delim(line, true) or line:match("^%s*$"))
            and "\0" or barrier .. line .. (heading and "\0" or "")
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
            for _, ref in ipairs(M.at_references(line)) do
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
