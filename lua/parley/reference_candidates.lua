-- Pure occurrence enumeration and picker completion. Destinations stay textual;
-- the editor boundary owns resolution, opening and all buffer/window effects.
local M = {}

-- Preserve issues.lua's existing Markdown dialect and 1-based inclusive spans.
function M.markdown_links(line)
    local links, pos = {}, 1
    while line do
        local s, e, text, url = line:find("%[([^%]]*)%]%(([^)]+)%)", pos)
        if not s then break end
        links[#links + 1] = { text = text, url = url, start_col = s, end_col = e }
        pos = e + 1
    end
    return links
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
    local in_code = opts.in_code or lexical.code_block_memo(lines, patterns, true)
    local prefix = opts.branch_prefix or patterns.branch_prefix
    local artifact_ref = require("parley.artifact_ref")
    local out = {}
    for row = math.max(1, range.first), math.min(#lines, range.last) do
        local line = lines[row]
        if not in_code[row] and not lexical.is_fence_delim(line, true) then
            local occupied, row_items = {}, {}
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
            for _, link in ipairs(M.markdown_links(line)) do
                add("markdown", link.start_col, link.end_col, link.text, link.url,
                    link.start_col + #link.text + 3)
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
