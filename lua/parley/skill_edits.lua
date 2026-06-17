-- parley.skill_edits — the single source of the batch-edit transform.
--
-- PURE: validate + apply a list of {old_string, new_string, explain} edits to a
-- content string. The single source of the batch-edit transform; the
-- propose_edits tool handler (IO wrapper) is its one caller (ARCH-DRY).

local M = {}

--- Validate and apply edits to a content string. Atomic: any invalid edit
--- rejects the whole batch (no partial application).
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
            pos = pos,
            old_string = edit.old_string,
            new_string = edit.new_string,
            explain = edit.explain,
        })
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
