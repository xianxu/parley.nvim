-- Pure, conservative migration projection. The adapter owns canonicalization,
-- complete enumeration, ancestor/symlink checks and preimage CAS before effects.
local M = {}
local frontmatter = require('parley.frontmatter')
local references = require('parley.reference_candidates')

local function canonical(path)
    if type(path) ~= 'string' or #path > 4096 or path:sub(1, 1) ~= '/'
        or path:find('[%z\1-\31\127\\]') or path:find('//', 1, true) or path:sub(-1) == '/' then
        return false
    end
    for component in path:gmatch('[^/]+') do
        if component == '.' or component == '..' then return false end
    end
    return true
end
local function dirname(path) return path:match('^(.*)/[^/]+$') end
local function contained(path, root) return path:sub(1, #root + 1) == root .. '/' end
local function normalize(path)
    local parts = {}
    for component in path:gmatch('[^/]+') do
        if component == '..' then
            if #parts == 0 then return nil end
            table.remove(parts)
        elseif component ~= '.' then parts[#parts + 1] = component end
    end
    return '/' .. table.concat(parts, '/')
end
local function resolve(path, child)
    if path == '' or path:find('[%z\1-\31\127\\]') or path:match('^%a[%w+.-]*:') then return nil end
    return normalize(path:sub(1, 1) == '/' and path or dirname(child) .. '/' .. path)
end
local function relative(target, child)
    local a, b = {}, {}
    for part in dirname(child):gmatch('[^/]+') do a[#a + 1] = part end
    for part in target:gmatch('[^/]+') do b[#b + 1] = part end
    local i = 1
    while a[i] and a[i] == b[i] do i = i + 1 end
    local out = {}
    for _ = i, #a do out[#out + 1] = '..' end
    for j = i, #b do out[#out + 1] = b[j] end
    return table.concat(out, '/')
end
local function paths_valid(paths)
    return type(paths) == 'table' and canonical(paths.old) and canonical(paths.new)
end
local function split(bytes)
    local lines, positions, start = {}, {}, 1
    while start <= #bytes do
        local stop = bytes:find('\n', start, true) or (#bytes + 1)
        lines[#lines + 1] = bytes:sub(start, stop - 1):gsub('\r$', '')
        positions[#positions + 1] = start
        start = stop + 1
    end
    return lines, positions
end
local function escaped(line, pos)
    local count = 0
    while pos > 1 and line:sub(pos - 1, pos - 1) == '\\' do count = count + 1; pos = pos - 1 end
    return count % 2 == 1
end
local function code_mask(line)
    local mask, i = {}, 1
    while i <= #line do
        if line:sub(i, i) == '`' and not escaped(line, i) then
            local run = line:match('^`+', i)
            local ending = line:find(run, i + #run, true)
            if ending then
                for j = i, ending + #run - 1 do mask[j] = true end
                i = ending + #run
            else i = i + #run end
        else i = i + 1 end
    end
    return mask
end

--- Rewrite only existing supported parent scalars and simple Markdown links.
--- Paths are canonical {old,new} pairs; bytes remain exact outside edit spans.
--- Malformed relevant data refuses the entire rewrite, never a partial edit.
function M.rewrite_parent(bytes, child_paths, parent_paths)
    if type(bytes) ~= 'string' or #bytes > 4 * 1024 * 1024
        or not paths_valid(child_paths) or not paths_valid(parent_paths) then
        return nil, 'invalid backlink input'
    end
    local lines, positions = split(bytes)
    local edits = {}
    local replacement = relative(parent_paths.new, child_paths.new)
    local function target(value)
        local path, fragment = value:match('^([^#]*)(.*)$')
        if resolve(path, child_paths.old) == parent_paths.old then return replacement .. fragment end
        return value
    end
    local function add(row, first, last, value)
        edits[#edits + 1] = { first = positions[row] + first - 1, last = positions[row] + last - 1, value = value }
    end
    local fm_end = 0
    if lines[1] == '---' then
        local parsed = frontmatter.parse(lines)
        if not parsed then return nil, 'unclosed frontmatter' end
        fm_end = parsed.close
        local seen = false
        for row = 2, fm_end - 1 do
            local prefix, key, raw = lines[row]:match('^(%s*)([%w_-]+):%s*(.*)$')
            if key and key:lower() == 'parent' then
                if seen or prefix ~= '' then return nil, 'ambiguous parent field' end
                seen = true
                local first = #lines[row] - #raw + 1
                local span, value, quote
                if raw:sub(1, 1) == '"' or raw:sub(1, 1) == "'" then
                    span = frontmatter.quoted_span(raw)
                    if not span then return nil, 'malformed parent scalar' end
                    local tail = raw:sub(#span + 1)
                    if not tail:match('^%s*$') and not tail:match('^%s+#') then return nil, 'ambiguous parent scalar' end
                    value, quote = frontmatter.unquote(span), raw:sub(1, 1)
                else
                    span = raw:gsub('%s+#.*$', ''):gsub('%s+$', '')
                    value = span
                    if value == '' or frontmatter.needs_quote(value) then return nil, 'malformed parent scalar' end
                end
                local changed = target(value)
                if changed ~= value then
                    if quote == '"' then changed = frontmatter.quote(changed)
                    elseif quote == "'" then changed = "'" .. changed:gsub("'", "''") .. "'"
                    elseif frontmatter.needs_quote(changed) then return nil, 'parent needs quoting' end
                    add(row, first, first + #span - 1, changed)
                end
            end
        end
    end
    local fence, width
    for row = fm_end + 1, #lines do
        local line = lines[row]
        local marker = line:match('^%s*(```+)') or line:match('^%s*(~~~+)')
        if marker then
            if not fence then fence, width = marker:sub(1, 1), #marker
            elseif marker:sub(1, 1) == fence and #marker >= width then fence, width = nil, nil end
        elseif not fence then
            local mask, covered = code_mask(line), {}
            for _, link in ipairs(references.markdown_links(line)) do
                local first = link.end_col - #link.url
                for j = first, link.end_col do covered[j] = true end
                if not mask[link.start_col] and not escaped(line, link.start_col) then
                    local candidate = link.url:match('^([^%s]+)') or ''
                    if target(candidate) ~= candidate and candidate ~= link.url then
                        return nil, 'ambiguous Markdown parent destination'
                    end
                    local changed = target(link.url)
                    if changed ~= link.url then
                        if changed:find('[%s()]') then return nil, 'unsupported Markdown parent destination' end
                        add(row, first, link.end_col - 1, changed)
                    end
                end
            end
            local pos = 1
            while true do
                local opening = line:find('](', pos, true)
                if not opening then break end
                local first = opening + 2
                if not covered[first] and not mask[opening] and not escaped(line, opening) then
                    local value = line:sub(first):match('^([^%s)]*)') or ''
                    if target(value) ~= value then return nil, 'malformed Markdown parent link' end
                end
                pos = first
            end
        end
    end
    table.sort(edits, function(a, b) return a.first > b.first end)
    for _, edit in ipairs(edits) do bytes = bytes:sub(1, edit.first - 1) .. edit.value .. bytes:sub(edit.last + 1) end
    return bytes
end

--- observations: id, old_exists/new_exists/new_written, destination_registered,
--- side_exists/target_side_exists booleans; complete dense entries of canonical
--- {path,resolved,type,bytes?}. Only directory/file entries are supported.
--- Effects execute under a lease, with the captured observations revalidated.
function M.project(old, new, observations)
    local o = observations
    if not canonical(old) or not canonical(new) or old == new or not old:match('%.md$') or not new:match('%.md$')
        or type(o) ~= 'table' or type(o.id) ~= 'string' or o.id == '' or #o.id > 256
        or o.id:find('[%z\1-\31\127]') or type(o.entries) ~= 'table' then return nil, 'invalid move input' end
    for _, key in ipairs({ 'old_exists', 'new_exists', 'new_written', 'destination_registered', 'side_exists', 'target_side_exists' }) do
        if type(o[key]) ~= 'boolean' then return nil, 'missing move observation: ' .. key end
    end
    local source, destination = old:gsub('%.md$', '.side'), new:gsub('%.md$', '.side')
    if contained(destination, source) or contained(new, source) then return nil, 'move target inside source side directory' end
    if o.destination_registered or o.target_side_exists then return nil, 'occupied move destination' end
    local count, markdown, seen, entries = 0, 0, {}, {}
    for index, entry in pairs(o.entries) do
        count = count + 1
        if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or count > 4096
            or type(entry) ~= 'table' or not canonical(entry.path) or not contained(entry.path, source)
            or entry.resolved ~= entry.path or (entry.type ~= 'file' and entry.type ~= 'directory')
            or seen[entry.path] then return nil, 'invalid side entry observation' end
        seen[entry.path] = true
        entries[#entries + 1] = entry
        if entry.type == 'file' and entry.path:match('%.md$') then
            markdown = markdown + 1
            if markdown > 512 or type(entry.bytes) ~= 'string' then return nil, 'invalid Markdown entry observation' end
        end
    end
    for i = 1, count do if o.entries[i] == nil then return nil, 'sparse side entries' end end
    if not o.side_exists and count > 0 then return nil, 'entries without source side directory' end
    local result = { old = old, new = new, id = o.id, effects = {} }
    if not o.new_written then
        result.effects[1] = { kind = 'wait_new_write', path = new }
        return result
    end
    if not o.new_exists then return nil, 'new write has no destination file' end
    if o.side_exists then
        result.effects[#result.effects + 1] = { kind = 'move_side', old = source, new = destination }
        table.sort(entries, function(a, b) return a.path < b.path end)
        for _, entry in ipairs(entries) do
            if entry.type == 'file' and entry.path:match('%.md$') then
                local path = destination .. entry.path:sub(#source + 1)
                local after, err = M.rewrite_parent(entry.bytes, { old = entry.path, new = path }, { old = old, new = new })
                if not after then return nil, err end
                if after ~= entry.bytes then
                    result.effects[#result.effects + 1] = { kind = 'rewrite_parent', path = path, before = entry.bytes, after = after }
                end
            end
        end
    end
    result.effects[#result.effects + 1] = { kind = 'rename_metadata', id = o.id, old = old, new = new }
    return result
end
return M
