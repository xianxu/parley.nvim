-- Read only exported move-case members; expected bytes have one producer.
local M = {}
local function read(path)
    local f = assert(io.open(path, 'rb'))
    local bytes = f:read('*a'); f:close(); return bytes
end
function M.load()
    local root = vim.fn.getcwd() .. '/lua/parley/skills/review'
    local manifest = vim.json.decode(read(root .. '/export.json'))
    local groups = {}
    for _, member in ipairs(manifest.members) do
        if member.role == 'fixture' and member.name:match('^move%-') then
            local group = groups[member.name] or { name = member.name, before = {}, after = {} }
            groups[member.name] = group
            local prefix = 'examples/' .. member.name .. '/'
            assert(member.path:sub(1, #prefix) == prefix)
            local tail = member.path:sub(#prefix + 1)
            local bytes = read(root .. '/' .. member.path)
            assert.equals(member.bytes, #bytes)
            assert.equals(member.sha256, vim.fn.sha256(bytes))
            if tail == 'case.md' then
                group.old, group.new = bytes:match('\nmove: ([^%s]+) ([^%s]+)\n')
                assert(group.old and group.new, 'missing shared move declaration')
            else
                local side, path = tail:match('^(before)/(.+)$')
                if not side then side, path = tail:match('^(after)/(.+)$') end
                assert(side and path, 'unknown fixture member')
                group[side][path] = bytes
            end
        end
    end
    local out = {}
    for _, group in pairs(groups) do out[#out + 1] = group end
    table.sort(out, function(a, b) return a.name < b.name end)
    assert(#out > 0, 'snapshot has no move fixtures')
    return out
end
return M
