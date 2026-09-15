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
    local lo = require("parley.question_tags").semantic_start(ex)
    local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
    local slice = {}
    for l = lo, hi do
        slice[#slice + 1] = all_lines[l]
    end
    return table.concat(slice, "\n")
end

--- Canonicalize a generated definition as one semantic paragraph.
--- @param definition string|nil
--- @return string
function M.normalize_definition(definition)
    local normalized = tostring(definition or ""):gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return "(no definition)"
    end
    return normalized
end

--- Compose the semantic diagnostic message ("TERM — definition"). Presentation
--- wrapping belongs to the display surface because its available width can
--- change independently of diagnostic creation.
--- @param term string|nil
--- @param definition string|nil
--- @return string
function M.format_definition(term, definition)
    return tostring(term or "") .. " — " .. M.normalize_definition(definition)
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
    return string.format("[^%s]: %s", id, M.normalize_definition(definition))
end

local function is_divider(line)
    return trim(line) == "---"
end

function M.is_footnote_line(line)
    return trim(line):match("^%[%^[^%]]+%]:") ~= nil
end

local function managed_footer_start(lines)
    for i, line in ipairs(lines or {}) do
        if M.is_footnote_line(line) then
            return i
        end
    end
    return nil
end

--- Locate the final managed definition-footnote footer.
--- @param lines string[]|nil
--- @return table|nil { start_line: integer, end_line: integer } 1-based inclusive
function M.managed_footnote_footer_range(lines)
    lines = lines or {}
    local start = managed_footer_start(lines)
    if not start then
        return nil
    end
    return { start_line = start, end_line = #lines }
end

--- Locate the line where user-authored content should stop before a managed
--- definition-footnote footer. The public footer range starts at the first
--- `[^id]:` line, but old buffers may still have a preceding `---` separator
--- that should be stripped from prompts/messages too.
--- @param lines string[]|nil
--- @return integer|nil 1-based inclusive start line to trim from content
function M.managed_footnote_content_start(lines)
    lines = lines or {}
    local range = M.managed_footnote_footer_range(lines)
    if not range then
        return nil
    end
    local start = range.start_line
    local before = start - 1
    while before > 0 and trim(lines[before]) == "" do
        before = before - 1
    end
    if before > 0 and is_divider(lines[before]) then
        start = before
    end
    return start
end

local function parse_footnote_line(line)
    local id, definition = trim(line):match("^%[%^([^%]]+)%]:%s*(.-)%s*$")
    if not id then
        return nil
    end
    return id, M.normalize_definition(definition)
end

local function parse_structured_definition(definition)
    local term, body = definition:match('^"([^"]+)"%s*%.?%s*(.*)$')
    if not term then
        term, body = definition:match("^`([^`]+)`%s*%.?%s*(.*)$")
    end
    if not term then
        return nil, M.normalize_definition(definition)
    end
    return term, M.normalize_definition(body)
end

local function is_term_byte(ch)
    return ch:match("[%w_-]") ~= nil
end

local function expand_term_start(line, ref_start)
    local start = ref_start
    while start > 1 and is_term_byte(line:sub(start - 1, start - 1)) do
        start = start - 1
    end
    return start
end

local function is_structured_anchor_suffix(text)
    return trim(text):match("^[\"'”’%]%)%}]*$") ~= nil
end

local function anchor_term_span(line, ref_start, term, ignore_case)
    if not term or term == "" then
        return nil, nil, nil
    end
    local haystack = ignore_case and line:lower() or line
    local needle = ignore_case and term:lower() or term
    local best_start, best_end
    local search = 1
    while search < ref_start do
        local start_pos, end_pos = haystack:find(needle, search, true)
        if not start_pos or start_pos >= ref_start then
            break
        end
        if end_pos < ref_start then
            local suffix = line:sub(end_pos + 1, ref_start - 1)
            if is_structured_anchor_suffix(suffix) then
                best_start = start_pos
                best_end = end_pos
            end
        end
        search = start_pos + 1
    end
    if not best_start then
        return nil, nil, nil
    end
    return best_start, best_end, line:sub(best_start, best_end)
end

local function slug_anchor_term(id)
    if not id or not id:find("-", 1, true) then
        return nil
    end
    local term = id:gsub("%-+", " ")
    term = trim(term)
    if term == "" then
        return nil
    end
    return term
end

-- Byte-reader diagnostic grammar. A reader may yield between byte operations;
-- retained text is only derived identifiers/messages, stored in bounded pieces.
local function rope(source)
    local r={parts={},tail={},length=0,hash=0,tick=source.tick or function()end}
    function r.push(ch)
        r.tick();r.length=r.length+1;r.hash=(r.hash*131+ch:byte())%2147483647
        r.tail[#r.tail+1]=ch
        if #r.tail==4096 then r.parts[#r.parts+1]=table.concat(r.tail);r.tail={} end
    end
    function r.byte(pos)
        r.tick()
        if pos<1 or pos>r.length then return '' end
        local part=math.floor((pos-1)/4096)+1;local col=(pos-1)%4096+1
        return r.parts[part] and r.parts[part]:sub(col,col) or r.tail[col]
    end
    return r
end
local function rope_slice(value,first,last)
    return {length=math.max(0,last-first+1),byte=function(pos)
        return pos>=1 and pos<=last-first+1 and value.byte(first+pos-1) or ''
    end,tick=value.tick}
end
local function literal(value,source)
    local r=rope(source);for i=1,#value do r.push(value:sub(i,i)) end;return r
end
local function space(ch)return ch~='' and ch:match('%s')~=nil end
local function normalized(source,first,last)
    local result=rope(source);local pending=false
    for i=first,last do
        local ch=source.byte(i)
        if space(ch) then pending=result.length>0
        else
            if pending then result.push(' ');pending=false end
            result.push(ch)
        end
    end
    if result.length==0 then return literal('(no definition)',source) end
    return result
end
function M.read_diagnostic_definition(source)
    local at=1
    while space(source.byte(at)) do at=at+1 end
    if source.byte(at)~='[' or source.byte(at+1)~='^' then return nil end
    at=at+2;local identifier=rope(source)
    while at<=source.length and source.byte(at)~=']' do identifier.push(source.byte(at));at=at+1 end
    if identifier.length==0 or source.byte(at)~=']' or source.byte(at+1)~=':' then return nil end
    local definition=normalized(source,at+2,source.length)
    local term,body
    local quote=definition.byte(1)
    if quote=='"' or quote=='`' then
        local close=2
        while close<=definition.length and definition.byte(close)~=quote do close=close+1 end
        if close>2 and close<=definition.length then
            term=rope_slice(definition,2,close-1);at=close+1
            while space(definition.byte(at)) do at=at+1 end
            if definition.byte(at)=='.' then at=at+1 end
            body=normalized(definition,at,definition.length)
        end
    end
    return {identifier=identifier,definition=body or definition,term=term}
end
local function equal_identifier(a,b)
    if a.length~=b.length or a.hash~=b.hash then return false end
    for i=1,a.length do if a.byte(i)~=b.byte(i) then return false end end
    return true
end
local function slug(identifier,source)
    local out=rope(source);local pending,has_dash=false,false
    for i=1,identifier.length do
        local ch=identifier.byte(i)
        if ch=='-' then pending=out.length>0;has_dash=true
        else
            if pending then out.push(' ');pending=false end
            out.push(ch)
        end
    end
    if not has_dash then return nil end
    local first,last=1,out.length
    while space(out.byte(first)) do first=first+1 end
    while space(out.byte(last)) do last=last-1 end
    return last>=first and rope_slice(out,first,last) or nil
end
local function anchor(source,ref_start,term,ignore_case)
    if not term or term.length==0 then return nil end
    local phase=0
    for finish=ref_start-1,term.length,-1 do
        local matched=true
        for i=term.length,1,-1 do
            local actual,expected=source.byte(finish-term.length+i),term.byte(i)
            if ignore_case then actual=actual:lower();expected=expected:lower() end
            if actual~=expected then matched=false;break end
        end
        if matched then return finish-term.length+1 end
        local ch=source.byte(finish)
        if space(ch) then if phase==1 then phase=2 end
        elseif ch:match("[\"'”’%]%)%}]") and phase~=2 then phase=1
        else break end
    end
end
function M.read_diagnostic_references(source,definitions,emit)
    local output={};local at=1
    local tick=source.tick or function()end
    while at<=source.length do
        if source.byte(at)=='[' and source.byte(at+1)=='^' then
            local finish=at+2;local identifier=rope(source)
            while finish<=source.length and source.byte(finish)~=']' do
                identifier.push(source.byte(finish));finish=finish+1
            end
            if identifier.length>0 and source.byte(finish)==']' then
                if source.on_match then source.on_match() end
                local definition
                for i=#definitions,1,-1 do
                    tick()
                    if equal_identifier(identifier,definitions[i].identifier) then definition=definitions[i];break end
                end
                if definition then
                    local start=anchor(source,at,definition.term,false)
                    local slug_term
                    if not start then
                        slug_term=slug(identifier,source)
                        start=anchor(source,at,slug_term,true)
                    end
                    if not start then
                        start=at
                        while start>1 and source.byte(start-1):match('[%w_-]') do start=start-1 end
                        slug_term=nil
                    end
                    local term=definition.term or (slug_term and rope_slice(source,start,start+slug_term.length-1))
                    if not term then
                        term=rope(source);for pos=start,at-1 do term.push(source.byte(pos)) end
                    elseif not definition.term then
                        local stable=rope(source);for pos=1,term.length do stable.push(term.byte(pos)) end;term=stable
                    end
                    local record={identifier=identifier,term=term,definition=definition.definition,col=start-1,end_col=finish}
                    if emit then emit(record) else output[#output+1]=record end
                end
                at=finish
            end
        end
        at=at+1
    end
    return output
end
local function materialize(value)
    if not value then return nil end
    -- This is output materialization, called by the publication phase only.
    local parts={};local piece={}
    for i=1,value.length do
        piece[#piece+1]=value.byte(i)
        if #piece==4096 then parts[#parts+1]=table.concat(piece);piece={} end
    end
    parts[#parts+1]=table.concat(piece)
    return table.concat(parts)
end
function M.materialize_diagnostic(record)
    local term=materialize(record.term)
    return {id=materialize(record.identifier),term=term~='' and term or nil,
        definition=materialize(record.definition),col=record.col,end_col=record.end_col}
end

--- Derive persisted definition diagnostics from inline footnote references and
--- the final managed definition footer.
--- @param lines string[]
--- @return table[] diagnostics with 0-based columns
function M.footnote_diagnostics(lines)
    lines = lines or {}
    local footer = managed_footer_start(lines)
    if not footer then
        return {}
    end

    local definitions = {}
    for i = footer, #lines do
        local id, definition = parse_footnote_line(lines[i] or "")
        if id then
            local term, body = parse_structured_definition(definition)
            definitions[id] = {
                definition = body,
                structured_term = term,
            }
        end
    end

    local diagnostics = {}
    for lnum = 1, footer - 1 do
        local line = lines[lnum] or ""
        local search = 1
        while true do
            local ref_start, ref_end, id = line:find("%[%^([^%]]+)%]", search)
            if not ref_start then
                break
            end
            local footnote = definitions[id]
            if footnote then
                local structured_start = anchor_term_span(line, ref_start, footnote.structured_term, false)
                local slug_start, _, slug_term = nil, nil, nil
                if not structured_start then
                    slug_start, _, slug_term = anchor_term_span(line, ref_start, slug_anchor_term(id), true)
                end
                local term_start = structured_start or slug_start or expand_term_start(line, ref_start)
                local term = footnote.structured_term or slug_term or line:sub(term_start, ref_start - 1)
                table.insert(diagnostics, {
                    id = id,
                    term = term ~= "" and term or nil,
                    definition = footnote.definition,
                    lnum = lnum - 1,
                    col = term_start - 1,
                    end_lnum = lnum - 1,
                    end_col = ref_end,
                })
            end
            search = ref_end + 1
        end
    end
    return diagnostics
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
    local start = M.managed_footnote_content_start(lines)
    if not start then
        return text or ""
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
        for i = footer, #out do
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
        if line:sub(ec + 1, ec + #ref) ~= ref then
            out[l1] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
        end
    else
        local line = out[l2] or ""
        local ec = math.min(c2 + 1, #line)
        if line:sub(ec + 1, ec + #ref) ~= ref then
            out[l2] = line:sub(1, ec) .. ref .. line:sub(ec + 1)
        end
    end
    out = replace_or_append_footnote(out, id, definition)
    local normalized_definition = M.normalize_definition(definition)
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
