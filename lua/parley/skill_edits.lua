-- parley.skill_edits — the single source of the batch-edit transform.
--
-- PURE: validate + apply a list of {old_string, new_string, explain} edits to a
-- content string. Its one caller is tools/file_transform, which both
-- propose_edits paths (the sync handler and the async builtin) go through (ARCH-DRY).

local M = {}

--- Validate and apply edits to a content string. Atomic: any invalid edit, or
--- two edits whose spans overlap, rejects the whole batch (no partial application).
--- @param content string  file content
--- @param edits table[]  list of {old_string, new_string, explain}
--- @return table  {ok=bool, msg=string, content=string|nil, applied=table[]}
function M.compute_edits(content, edits)
    local positioned = {}
    for idx, edit in ipairs(edits) do
        if type(edit.old_string) ~= "string" or type(edit.new_string) ~= "string" then
            return {
                ok = false,
                msg = "edit #" .. idx .. " missing old_string or new_string: " .. vim.inspect(edit),
                applied = {},
            }
        end
        local pos = content:find(edit.old_string, 1, true)
        if not pos then
            return {
                ok = false,
                msg = "old_string not found: " .. edit.old_string:sub(1, 60),
                applied = {},
            }
        end
        local second = content:find(edit.old_string, pos + 1, true)
        if second then
            return {
                ok = false,
                msg = "old_string not unique: " .. edit.old_string:sub(1, 60),
                applied = {},
            }
        end
        table.insert(positioned, {
            index = idx,
            pos = pos,
            old_string = edit.old_string,
            new_string = edit.new_string,
            explain = edit.explain,
        })
    end

    -- Every position is found in the original content, so two spans that
    -- overlap would splice bytes outside both (#369). An edit must start at or
    -- after the end of the one before it; a shared start (identical spans, or an
    -- empty old_string) has no order and is refused too.
    table.sort(positioned, function(a, b)
        if a.pos ~= b.pos then return a.pos < b.pos end
        return a.index < b.index
    end)
    for i = 2, #positioned do
        local before, edit = positioned[i - 1], positioned[i]
        if edit.pos == before.pos or edit.pos < before.pos + #before.old_string then
            local first, second = before, edit
            if first.index > second.index then first, second = second, first end
            return {
                ok = false,
                msg = ("edits #%d (%s) and #%d (%s) overlap"):format(first.index, first.old_string:sub(1, 60),
                    second.index, second.old_string:sub(1, 60)),
                applied = {},
            }
        end
    end

    table.sort(positioned, function(a, b) return a.pos > b.pos end)

    local applied = {}
    for _, edit in ipairs(positioned) do
        content = content:sub(1, edit.pos - 1)
            .. edit.new_string
            .. content:sub(edit.pos + #edit.old_string)
        table.insert(applied, {
            pos = edit.pos,
            old_string = edit.old_string,
            new_string = edit.new_string,
            explain = edit.explain,
        })
    end

    return {
        ok = true,
        msg = "Applied " .. #applied .. " edit(s)",
        content = content,
        applied = applied,
    }
end

return M
