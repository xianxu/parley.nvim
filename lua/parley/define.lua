-- Pure core for the inline term-definition feature (#161).
-- No Neovim APIs here — these functions operate on plain tables/strings so they
-- are unit-tested directly (tests/unit/define_spec.lua). The IO shell
-- (define_visual / render_definition) lives in lua/parley/init.lua.

local M = {}

--- Extract the charwise-visual selection [l1,c1]..[l2,c2] from `lines`.
--- l1/l2 are 1-based line numbers; c1/c2 are 0-based byte columns where c2 is
--- the *inclusive* end column (matches getpos("'>") after subtracting 1).
--- Multi-line spans join with "\n"; columns clamp to line length; a reversed
--- span returns "".
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer
--- @param l2 integer
--- @param c2 integer
--- @return string
function M.slice_selection(lines, l1, c1, l2, c2)
    if l1 > l2 or (l1 == l2 and c1 > c2) then
        return ""
    end
    if l1 == l2 then
        local line = lines[l1] or ""
        return line:sub(c1 + 1, math.min(c2 + 1, #line))
    end
    local out = {}
    for l = l1, l2 do
        local line = lines[l] or ""
        if l == l1 then
            out[#out + 1] = line:sub(c1 + 1)
        elseif l == l2 then
            out[#out + 1] = line:sub(1, math.min(c2 + 1, #line))
        else
            out[#out + 1] = line
        end
    end
    return table.concat(out, "\n")
end

--- The bounded context sent to the model: the line range of the enclosing
--- exchange of `sel_line`, else the whole buffer. `find_exchange` is injected
--- (default = require("parley").find_exchange_at_line) so this stays pure and
--- unit-testable with a synthetic parsed_chat + finder.
--- @param parsed_chat table  -- { exchanges = { { question={line_start,line_end}, answer={...}|nil }, ... } }
--- @param sel_line integer   -- 1-based line of the selection
--- @param all_lines string[]
--- @param find_exchange fun(pc:table, line:integer):integer|nil
--- @return string
function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange)
    find_exchange = find_exchange or require("parley").find_exchange_at_line
    local idx = find_exchange(parsed_chat, sel_line)
    local ex = idx and parsed_chat.exchanges and parsed_chat.exchanges[idx]
    if not ex then
        return table.concat(all_lines, "\n") -- whole-buffer fallback
    end
    local lo = ex.question.line_start
    local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
    local slice = {}
    for l = lo, hi do
        slice[#slice + 1] = all_lines[l]
    end
    return table.concat(slice, "\n")
end

--- Compose the diagnostic message ("TERM — definition"), hard-wrapped to width.
--- Delegates wrapping to skill_render.wrap (the same wrap the review path uses).
--- @param term string|nil
--- @param definition string|nil
--- @param width integer|nil
--- @return string
function M.format_definition(term, definition, width)
    definition = definition or ""
    definition = (definition:gsub("%s+$", "")) -- parens → keep only the string
    if definition == "" then
        definition = "(no definition)"
    end
    local head = tostring(term or "") .. " — " .. definition
    return require("parley.skill_render").wrap(head, width or 80)
end

--- Plan the reference-bracket wrap of the selection ([term]) as a set_lines edit
--- (#161 R1). Same arg convention as slice_selection (l1/l2 1-based, c1/c2
--- 0-based byte, c2 inclusive). Returns the affected 0-based line range + the
--- rewritten lines (selection wrapped in `[ ]`) for a single
--- `nvim_buf_set_lines(buf, first0, last, false, lines)` — one undo entry (the
--- anchor). `nvim_buf_set_text` is arch-forbidden outside buffer_edit; set_lines
--- is the same primitive `drill_in_visual` uses to wrap a selection. Pure.
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer
--- @param l2 integer
--- @param c2 integer
--- @return table  { first0, last, lines }
function M.bracket_edit(lines, l1, c1, l2, c2)
    local selected = M.slice_selection(lines, l1, c1, l2, c2)
    local first = lines[l1] or ""
    local last = lines[l2] or ""
    local new_lines = {}
    if l1 == l2 then
        local ec = math.min(c2 + 1, #first)
        new_lines[1] = first:sub(1, c1) .. "[" .. selected .. "]" .. first:sub(ec + 1)
    else
        local ec = math.min(c2 + 1, #last)
        new_lines[1] = first:sub(1, c1) .. "[" .. first:sub(c1 + 1)
        for l = l1 + 1, l2 - 1 do
            new_lines[#new_lines + 1] = lines[l]
        end
        new_lines[#new_lines + 1] = last:sub(1, ec) .. "]" .. last:sub(ec + 1)
    end
    return { first0 = l1 - 1, last = l2, lines = new_lines }
end

--- Convert a visual span from getpos columns to the diagnostic range after
--- bracket_edit inserts "[" before the selection and "]" after it.
--- @param l1 integer 1-based start line
--- @param c1 integer 1-based start column from getpos("'<")
--- @param l2 integer 1-based end line
--- @param c2 integer 1-based inclusive end column from getpos("'>")
--- @return table { lnum: integer, col: integer, end_lnum: integer, end_col: integer }
function M.diagnostic_span_after_bracket(l1, c1, l2, c2)
    return {
        lnum = l1 - 1,
        col = c1,
        end_lnum = l2 - 1,
        end_col = (l1 == l2) and (c2 + 1) or c2,
    }
end

--- @param s string
--- @return string
local function trim(s)
    local out = (s or ""):gsub("^%s*(.-)%s*$", "%1")
    return out
end

--- Convert a term into a stable markdown footnote id.
--- @param term string|nil
--- @return string
function M.footnote_id(term)
    local id = tostring(term or ""):lower()
    id = id:gsub("[^%w]+", "-")
    id = id:gsub("^%-+", ""):gsub("%-+$", "")
    if id == "" then
        id = "definition"
    end
    return id
end

--- @param id string
--- @param definition string|nil
--- @return string
function M.format_footnote_line(id, definition)
    definition = trim(definition)
    if definition == "" then
        definition = "(no definition)"
    end
    return string.format("[^%s]: %s", id, definition)
end

local function is_divider(line)
    return trim(line) == "---"
end

local function is_footnote_line(line)
    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
end

local function managed_footer_start(lines)
    for i = #lines, 1, -1 do
        if is_divider(lines[i]) then
            local has_footnote = false
            for j = i + 1, #lines do
                local line = lines[j] or ""
                if trim(line) ~= "" then
                    if not is_footnote_line(line) then
                        return nil
                    end
                    has_footnote = true
                end
            end
            if has_footnote then
                return i
            end
            return nil
        end
    end
    return nil
end

local function split_text_lines(text)
    text = text or ""
    local lines = {}
    local start = 1
    while true do
        local nl = text:find("\n", start, true)
        if not nl then
            lines[#lines + 1] = text:sub(start)
            break
        end
        lines[#lines + 1] = text:sub(start, nl - 1)
        start = nl + 1
    end
    if #lines > 1 and lines[#lines] == "" then
        table.remove(lines)
    end
    return lines
end

local function copy_lines(lines)
    local out = {}
    for i, line in ipairs(lines or {}) do
        out[i] = line
    end
    return out
end

--- Strip a final managed definition-footnote footer from text.
--- @param text string|nil
--- @return string
function M.strip_definition_footnote_footer(text)
    local lines = split_text_lines(text or "")
    local start = managed_footer_start(lines)
    if not start then
        return text or ""
    end
    while start > 1 and trim(lines[start - 1]) == "" do
        start = start - 1
    end
    local kept = {}
    for i = 1, start - 1 do
        kept[#kept + 1] = lines[i]
    end
    while #kept > 0 and trim(kept[#kept]) == "" do
        table.remove(kept)
    end
    return table.concat(kept, "\n")
end

local function replace_or_append_footnote(lines, id, definition)
    local out = copy_lines(lines)
    local footer = managed_footer_start(out)
    local footnote_line = M.format_footnote_line(id, definition)
    if footer then
        for i = footer + 1, #out do
            local escaped_id = id:gsub("([^%w])", "%%%1")
            if trim(out[i]):match("^%[%^" .. escaped_id .. "%]:") then
                out[i] = footnote_line
                return out
            end
        end
        out[#out + 1] = footnote_line
        return out
    end

    while #out > 0 and trim(out[#out]) == "" do
        table.remove(out)
    end
    out[#out + 1] = ""
    out[#out + 1] = "---"
    out[#out + 1] = ""
    out[#out + 1] = footnote_line
    return out
end

--- Insert a markdown footnote reference after the selected text and store the
--- definition in a managed footer.
--- @param lines string[]
--- @param l1 integer
--- @param c1 integer 0-based byte column
--- @param l2 integer
--- @param c2 integer 0-based inclusive byte column
--- @param term string
--- @param definition string|nil
--- @return table { lines: string[], id: string, definition: string, diagnostic_span: table }
function M.apply_definition_footnote(lines, l1, c1, l2, c2, term, definition)
    local id = M.footnote_id(term)
    local ref = "[^" .. id .. "]"
    local out = copy_lines(lines)
    if l1 == l2 then
        local line = out[l1] or ""
        local ec = math.min(c2 + 1, #line)
        out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
    else
        local line = out[l2] or ""
        local ec = math.min(c2 + 1, #line)
        out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
    end
    out = replace_or_append_footnote(out, id, definition)
    local normalized_definition = trim(definition)
    if normalized_definition == "" then
        normalized_definition = "(no definition)"
    end
    return {
        lines = out,
        id = id,
        definition = normalized_definition,
        diagnostic_span = {
            lnum = l1 - 1,
            col = c1,
            end_lnum = l2 - 1,
            end_col = c2 + 1 + #ref,
        },
    }
end

return M
