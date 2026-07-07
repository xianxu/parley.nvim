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

return M
