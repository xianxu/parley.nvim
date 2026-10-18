-- Pure, conservative migration projection. The adapter owns canonicalization,
-- complete enumeration, ancestor/symlink checks and preimage CAS before effects.
local M = {}
local frontmatter = require('parley.frontmatter')
local references = require('parley.reference_candidates')
local structure = require('parley.highlight_structure')
local assets = require('parley.assets')

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
--- Filename classification shares the existing asset namespace's Markdown set.
--- Registered parent admission is supplied by the caller, including filetype-
--- Markdown files with no extension; this predicate classifies scanned children.
function M.is_markdown_path(path)
    return type(path) == 'string' and assets.key_for(path) ~= nil
end

--- A side directory uses the final filename stem. A leading dot alone is not
--- an extension, and dots in parent directory names never affect the result.
function M.side_path(path)
    if type(path) ~= 'string' or path == '' then return nil end
    local directory, basename = path:match('^(.*[/])([^/]+)$')
    directory, basename = directory or '', basename or path
    local stem = basename:match('^(.*)%.[^.]*$')
    if not stem or stem == '' then stem = basename end
    return directory .. stem .. '.side'
end

local function dirname(path) return path:match('^(.*)/[^/]+$') end
local function contained(path, root) return path:sub(1, #root + 1) == root .. '/' end
-- Every declared side root remains independent, including an absent source.
-- A shared S==T is the existing extension-only case, not an orphan move.
function M.validate_geometry(old, new, orphan)
    local function refuse(reason) return nil, reason .. '; move to another name first' end
    if not canonical(old) or not canonical(new) or old == new then return refuse('invalid document move paths') end
    local source, target = M.side_path(old), M.side_path(new)
    if not canonical(source) or not canonical(target) then return refuse('invalid side folder paths') end
    local roots = { source }
    if source ~= target then roots[#roots + 1] = target end
    if orphan ~= nil then
        if source == target then return refuse('a shared side folder cannot also be displaced') end
        if not canonical(orphan) then return refuse('invalid displaced folder path') end
        local prefix = target:sub(1, -6) .. '_'
        local suffix = orphan:sub(1, #prefix) == prefix and orphan:sub(#prefix + 1):match('^(%d+)%.side$')
        local number = suffix and tonumber(suffix)
        if not number or number < 1 or number > 4096 or tostring(number) ~= suffix then
            return refuse('invalid displaced folder name')
        end
        roots[#roots + 1] = orphan
    end
    for index, root in ipairs(roots) do
        if old == root or new == root or contained(old, root) or contained(new, root) then
            return refuse('a document is inside a side folder involved in the move')
        end
        for other = index + 1, #roots do
            if root == roots[other] or contained(root, roots[other]) or contained(roots[other], root) then
                return refuse('the side folders involved in the move overlap')
            end
        end
    end
    return true
end
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
-- Backtick spans may cross soft line breaks, but not a paragraph/fence boundary.
-- Index the next exact-width run once; unmatched runs never rescan a suffix.
local function code_masks(lines, blocks, first_row)
    local masks, tokens = {}, {}
    local function finish_paragraph()
        local next_run, following = {}, {}
        for i = #tokens, 1, -1 do
            local token = tokens[i]
            following[i] = next_run[token.width]
            next_run[token.width] = i
        end
        local i = 1
        while i <= #tokens do
            local opening, closing = tokens[i], tokens[following[i]]
            if closing and not escaped(lines[opening.row], opening.first) then
                for row = opening.row, closing.row do
                    local first = row == opening.row and opening.first or 1
                    local last = row == closing.row and closing.last or #lines[row]
                    for column = first, last do masks[row][column] = true end
                end
                i = following[i] + 1
            else i = i + 1 end
        end
        tokens = {}
    end
    for row = first_row, #lines do
        local line = lines[row]
        masks[row] = {}
        local block = blocks[row]
        if block.before or block.excluded then finish_paragraph() end
        if not block.excluded then
            local pos = 1
            while true do
                local first, last = line:find('`+', pos)
                if not first then break end
                tokens[#tokens + 1] = { row = row, first = first, last = last, width = last - first + 1 }
                pos = last + 1
            end
        end
        if block.after then finish_paragraph() end
    end
    finish_paragraph()
    return masks
end

-- Apply disjoint byte spans in one assembly rather than copying a large
-- document once per link. Offsets refer to the original preimage.
local function apply_edits(bytes, edits)
    table.sort(edits, function(a, b) return a.first < b.first end)
    local chunks, next_byte = {}, 1
    for _, edit in ipairs(edits) do
        if edit.first < next_byte then return nil, 'overlapping reference edits' end
        chunks[#chunks + 1] = bytes:sub(next_byte, edit.first - 1)
        chunks[#chunks + 1] = edit.value
        next_byte = edit.last + 1
    end
    chunks[#chunks + 1] = bytes:sub(next_byte)
    return table.concat(chunks)
end

-- Pair quotes literal brackets inside its one-line insertion proposal. Keep
-- raw offsets/escaping; only authorize the link's existing destination span.
local function pending_openers(line)
    local openers = {}
    for first, body in line:gmatch('()🤖{([^{}]*)}') do
        if not escaped(line, first) then
            local left, label, right = body:match([=[^%s*→%s*(\+)%[([%a]+)(\+)%]%([^%s()]+%)%s*$]=])
            if left == right and (label == 'proposal' or label == 'discussion') then
                openers[first + #'🤖{' + body:find('[', 1, true) - 1] = true
            end
        end
    end
    return openers
end

local function rewrite_links(lines, positions, fm_end, target, edits, pending)
    local in_code, fence, width, covered, proposals = {}, nil, nil, {}, {}
    for row = fm_end + 1, #lines do
        local line = lines[row]
        local marker_width = structure.is_fence_delim(line, true)
        in_code[row] = fence ~= nil or marker_width ~= nil
        if marker_width then
            local kind = structure.is_fence_delim(line) and '`' or '~'
            if not fence then fence, width = kind, marker_width
            elseif kind == fence and marker_width >= width then fence, width = nil, nil end
        end
        covered[row] = {}
        proposals[row] = pending and not in_code[row] and pending_openers(line) or {}
    end
    local blocks = references.markdown_blocks(lines, { first = fm_end + 1, last = #lines },
        { in_code = in_code, transcript = false })
    local masks = code_masks(lines, blocks, fm_end + 1)
    for _, link in ipairs(references.markdown_spans(lines, { first = fm_end + 1, last = #lines },
        { in_code = in_code, transcript = false })) do
        local row, first = link.fallback_row, link.fallback_col + 1
        covered[row][first] = true
        if not masks[link.row][link.col + 1]
            and (not escaped(lines[link.row], link.col + 1) or proposals[link.row][link.col + 1]) then
            local candidate = link.target:match('^([^%s]+)') or ''
            if target(candidate) ~= candidate and candidate ~= link.target then
                return nil, 'ambiguous Markdown parent destination'
            end
            local changed = target(link.target)
            if changed ~= link.target then
                if changed:find('[%s()]') then return nil, 'unsupported Markdown parent destination' end
                edits[#edits + 1] = { first = positions[row] + first - 1,
                    last = positions[link.end_row] + link.end_col - 2, value = changed }
            end
        end
    end
    for row = fm_end + 1, #lines do
        if not in_code[row] then
            local line, pos = lines[row], 1
            while true do
                local opening = line:find('](', pos, true)
                if not opening then break end
                local first = opening + 2
                if not covered[row][first] and not masks[row][opening] and not escaped(line, opening) then
                    -- An opening parenthesis also ends an unsupported destination.
                    -- Token spans are disjoint, so malformed openers cannot copy
                    -- and resolve the entire remaining line repeatedly.
                    local stop = line:find('[%s()]', first) or (#line + 1)
                    local value = line:sub(first, stop - 1)
                    if target(value) ~= value then return nil, 'malformed Markdown parent link' end
                end
                pos = first
            end
        end
    end
    return true
end

local function scalar_span(raw)
    local quote = raw:sub(1, 1)
    if quote == '"' or quote == "'" then
        local span = frontmatter.quoted_span(raw)
        if not span then return nil, 'malformed reference scalar' end
        local tail = raw:sub(#span + 1)
        if not tail:match('^%s*$') and not tail:match('^%s+#') then return nil, 'ambiguous reference scalar' end
        -- The shared flat reader handles only literal quote/backslash escapes;
        -- refuse other YAML escapes rather than resolving a different path.
        if quote == '"' and span:gsub('\\[\\"]', ''):find('\\', 1, true) then
            return nil, 'unsupported reference scalar escape'
        end
        return span, frontmatter.unquote(span), quote
    end
    local comment = raw:find('%s#')
    local last = comment and comment - 1 or #raw
    while last > 0 and raw:sub(last, last):match('%s') do last = last - 1 end
    local span = raw:sub(1, last)
    if span == '' or frontmatter.needs_quote(span) then return nil, 'malformed reference scalar' end
    return span, span
end

local function quoted_replacement(value, quote)
    if quote == '"' then return frontmatter.quote(value) end
    if quote == "'" then return "'" .. value:gsub("'", "''") .. "'" end
    if frontmatter.needs_quote(value) then return nil, 'reference scalar needs quoting' end
    return value
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
                local span, value, quote = scalar_span(raw)
                if not span then return nil, value end
                local changed = target(value)
                if changed ~= value then
                    local rendered, err = quoted_replacement(changed, quote)
                    if not rendered then return nil, err end
                    changed = rendered
                    add(row, first, first + #span - 1, changed)
                end
            end
        end
    end
    local ok, err = rewrite_links(lines, positions, fm_end, target, edits)
    if not ok then return nil, err end
    return apply_edits(bytes, edits)
end

--- Rewrite a moving document's own side-folder links and block index.
--- Only scalar byte spans change; ambiguous YAML never authorizes a partial edit.
function M.rewrite_side_references(bytes, old, new)
    if type(bytes) ~= 'string' or #bytes > 4 * 1024 * 1024 or not canonical(old) or not canonical(new) then
        return nil, 'invalid parent reference input'
    end
    local source, destination = M.side_path(old), M.side_path(new)
    if source == destination then return bytes end
    local function target(value)
        local path, fragment = value:match('^([^#]*)(.*)$')
        local resolved = resolve(path, old)
        if not resolved or not contained(resolved, source) then return value end
        local changed = destination .. resolved:sub(#source + 1)
        if path:sub(1, 1) ~= '/' then
            changed = relative(changed, new)
            if path:sub(1, 2) == './' then changed = './' .. changed end
        end
        return changed .. fragment
    end
    local lines, positions = split(bytes)
    local edits, fm_end = {}, 0
    if lines[1] == '---' then
        local fm = frontmatter.parse(lines)
        if not fm then return nil, 'unclosed frontmatter' end
        fm_end = fm.close
        local root_indent = 0
        for row = 2, fm_end - 1 do
            if lines[row]:match('%S') and not lines[row]:match('^%s*#') then
                root_indent = #lines[row]:match('^ *'); break
            end
        end
        local active, seen = false, false
        for row = 2, fm_end - 1 do
            local original = lines[row]
            if original:match('%S') and not original:match('^%s*#')
                and #original:match('^ *') < root_indent then return nil, 'inconsistent frontmatter indentation' end
            local line = original:sub(root_indent + 1)
            local root_key, root_raw = line:match('^([%w_-]+):%s*(.*)$')
            if root_key then
                active = root_key == 'discussions'
                if active then
                    if seen then return nil, 'duplicate discussions field' end
                    seen = true
                    if root_raw ~= '' and not root_raw:match('^#') and not root_raw:match('^%[%]%s*$') and not root_raw:match('^%[%]%s+#') then
                        return nil, 'unsupported discussions structure'
                    end
                    if root_raw:match('^%[%]') then active = false end
                end
            elseif line:match('^%S') and not line:match('^#') then
                return nil, 'ambiguous frontmatter key'
            elseif active and line:match('%S') and not line:match('^%s*#') then
                local head, raw = line:match('^( +%- +doc: *)(.*)$')
                if not head or #head - #head:gsub('^ +', '') ~= 2 then
                    return nil, 'unsupported discussions entry'
                end
                local span, value, quote = scalar_span(raw)
                if not span then return nil, value end
                local changed = target(value)
                if changed ~= value then
                    local rendered, err = quoted_replacement(changed, quote)
                    if not rendered then return nil, err end
                    changed = rendered
                    edits[#edits + 1] = { first = positions[row] + root_indent + #head,
                        last = positions[row] + root_indent + #head + #span - 1, value = changed }
                end
            end
        end
    end
    local ok, err = rewrite_links(lines, positions, fm_end, target, edits, true)
    if not ok then return nil, err end
    return apply_edits(bytes, edits)
end

--- observations: id, old_exists/new_exists/new_written, side_exists/
--- target_side_exists booleans; destination_registered false (confirmed absent)
--- or 'authority' (Couch's rename decides, #359); complete dense entries of canonical
--- {path,resolved,type,bytes?}. Only directory/file entries are supported.
--- Effects execute under a lease, with the captured observations revalidated.
function M.project(old, new, observations)
    local o = observations
    if not canonical(old) or not canonical(new) or old == new
        or type(o) ~= 'table' or type(o.id) ~= 'string' or o.id == '' or #o.id > 256
        or o.id:find('[%z\1-\31\127]') or type(o.entries) ~= 'table' then return nil, 'invalid move input' end
    for _, key in ipairs({ 'old_exists', 'new_exists', 'new_written', 'destination_registered', 'side_exists', 'target_side_exists' }) do
        if type(o[key]) ~= 'boolean' and not (key == 'destination_registered' and o[key] == 'authority') then
            return nil, 'missing move observation: ' .. key
        end
    end
    local geometry, geometry_err = M.validate_geometry(old, new)
    if not geometry then return nil, geometry_err end
    local source, destination = M.side_path(old), M.side_path(new)
    if source == destination and o.side_exists ~= o.target_side_exists then return nil, 'inconsistent shared side observation' end
    if o.destination_registered == true then return nil, 'occupied move destination' end
    local orphan
    if source ~= destination and o.target_side_exists then
        if o.new_absent_at_admission ~= true or type(o.orphan_candidates) ~= 'table' then
            return nil, 'occupied move destination'
        end
        local count = #o.orphan_candidates
        if count == 0 or count > 4096 then return nil, 'orphan suffix search limit' end
        local observed = 0
        for index, occupied in pairs(o.orphan_candidates) do
            if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > count
                or type(occupied) ~= 'boolean' then return nil, 'invalid orphan suffix observations' end
            observed = observed + 1
        end
        if observed ~= count then return nil, 'sparse orphan suffix observations' end
        for index, occupied in ipairs(o.orphan_candidates) do
            if type(occupied) ~= 'boolean' then return nil, 'unknown orphan suffix observation' end
            if not occupied then
                if index ~= count then return nil, 'observations after free orphan suffix' end
                orphan = destination:sub(1, -6) .. '_' .. index .. '.side'
                break
            end
        end
        if not orphan then return nil, 'orphan suffix search has no free destination' end
    end
    geometry, geometry_err = M.validate_geometry(old, new, orphan)
    if not geometry then return nil, geometry_err end
    local count, markdown, seen, entries = 0, 0, {}, {}
    for index, entry in pairs(o.entries) do
        count = count + 1
        if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or count > 4096
            or type(entry) ~= 'table' or not canonical(entry.path) or not contained(entry.path, source)
            or entry.resolved ~= entry.path or (entry.type ~= 'file' and entry.type ~= 'directory')
            or seen[entry.path] then return nil, 'invalid side entry observation' end
        seen[entry.path] = true
        entries[#entries + 1] = entry
        if entry.type == 'file' and M.is_markdown_path(entry.path) then
            markdown = markdown + 1
            if markdown > 512 or type(entry.bytes) ~= 'string' then return nil, 'invalid Markdown entry observation' end
        end
    end
    for i = 1, count do if o.entries[i] == nil then return nil, 'sparse side entries' end end
    if not o.side_exists and count > 0 then return nil, 'entries without source side directory' end
    local parent_after
    if o.parent_bytes ~= nil then
        local err
        parent_after, err = M.rewrite_side_references(o.parent_bytes, old, new)
        if not parent_after then return nil, err end
    end
    local result = { old = old, new = new, id = o.id, effects = {}, orphan_destination = orphan }
    if not o.new_written then
        result.effects[1] = { kind = 'wait_new_write', path = new }
        return result
    end
    if not o.new_exists then return nil, 'new write has no destination file' end
    if orphan then
        result.orphan_destination = orphan
        result.effects[#result.effects + 1] = { kind = 'move_orphan', old = destination, new = orphan }
    end
    if o.side_exists then
        if source ~= destination then
            result.effects[#result.effects + 1] = { kind = 'move_side', old = source, new = destination }
        end
        table.sort(entries, function(a, b) return a.path < b.path end)
        for _, entry in ipairs(entries) do
            if entry.type == 'file' and M.is_markdown_path(entry.path) then
                local path = destination .. entry.path:sub(#source + 1)
                local after, err = M.rewrite_parent(entry.bytes, { old = entry.path, new = path }, { old = old, new = new })
                if not after then return nil, err end
                if after ~= entry.bytes then
                    result.effects[#result.effects + 1] = { kind = 'rewrite_parent', path = path, before = entry.bytes, after = after }
                end
            end
        end
    end
    if o.parent_bytes ~= nil then
        if parent_after ~= o.parent_bytes then
            result.effects[#result.effects + 1] = { kind = 'rewrite_document', path = new, before = o.parent_bytes, after = parent_after }
        end
    end
    result.effects[#result.effects + 1] = { kind = 'rename_metadata', id = o.id, old = old, new = new }
    return result
end

-- #359: a move asks Couch nothing before it happens, except an overwrite of an
-- existing file. Couch's own rename refuses an occupied destination, and the
-- no-replace file rename guards NEW's bytes, so what parley already knows
-- decides. The operator sees one of five actions: nothing, run again, reopen,
-- forget and reopen, rename back.
M.MOVE_TEXT = {
    identity = "move not confirmed: Couch hasn't confirmed this document yet; nothing moved. Run the move again",
    legacy = 'move not confirmed: registering this document first; nothing moved. Run the move again',
    confirming = 'moving: confirming with Couch',
    background = 'move not confirmed: finishing in the background',
    pending = 'move pending: reopen to recover',
}

--- What a move may do without waiting. known: identity (a registration,
--- 'plain' when positively absent, or 'unknown'), legacy (a session-sync owner
--- or nil), new_exists, overwrite (`:saveas!`). PURE.
function M.move_preflight(known)
    local identity = known.identity
    if type(identity) == 'table' then
        if known.new_exists and known.overwrite then return { wait_destination = true } end
        return { proceed = true }
    end
    if known.legacy then return { refuse = 'legacy', register = true, message = M.MOVE_TEXT.legacy } end
    if identity == 'plain' then return { plain = true } end
    return { refuse = 'identity', lookup = true, message = M.MOVE_TEXT.identity }
end

-- A path the shell reads back as itself, so the printed command pastes as is.
local function shell_word(path)
    if path:match('^[%w%./_%-~+,:@]+$') then return path end
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

--- The operator's view of a move once it began. outcome: moved (the journal's
--- document_moved step), new_path, overdue (past the submit deadline), result
--- (the metadata rename's reply, nil while out). PURE.
function M.move_outcome(outcome)
    local result = outcome.result
    if result and result.kind == 'registered' then return { state = 'done', band = '', action = 'none' } end
    if outcome.forward_only then
        if outcome.moved and not result then
            return { state = 'moving', band = M.MOVE_TEXT.confirming, action = 'wait' }
        end
        local reason = result and (result.error or result.code)
        if type(reason) ~= 'string' or reason == '' then reason = 'move could not be confirmed' end
        return { state = 'interrupted', action = 'reopen', warning = true,
            band = 'move interrupted: reopen to finish; ' .. reason }
    end
    if outcome.moved and not result then
        if outcome.overdue then
            return { state = 'background', band = M.MOVE_TEXT.background, action = 'none', warning = true }
        end
        return { state = 'confirming', band = M.MOVE_TEXT.confirming, action = 'none' }
    end
    if outcome.moved and result.code == 'target-conflict' then
        -- NEW is named once, in the command, so the line stays short enough
        -- for the band; the notification carries it uncut.
        return { state = 'conflict', action = 'forget', band = ('move not confirmed: the destination is registered to'
            .. ' another document. Run: couch --session-sync forget %s, then reopen'):format(shell_word(outcome.new_path)) }
    end
    return { state = 'pending', band = M.MOVE_TEXT.pending, action = 'reopen' }
end
return M
