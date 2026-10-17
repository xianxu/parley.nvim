-- Forward-only migration IO. Every effect is protected by the document lease;
-- recovery accepts only the recorded tuple and exact before/after witnesses.
local M = {}
local uv = vim.uv or vim.loop
local leases = require('parley.document_lease')
local projection = require('parley.document_move_plan')
local model = require('parley.document_move_state')
local helper = require('parley.helper')
local MAX_JOURNAL, MAX_PENDING = 256 * 1024, 32
local MAX_FILE = 4 * 1024 * 1024
local validate

local function failure(kind, message)
    return nil, { kind = kind, error = tostring(message), message = tostring(message) }
end
local function hash(bytes) return vim.fn.sha256(bytes) end
local function dirname(path) return vim.fn.fnamemodify(path, ':h') end
local side = projection.side_path
local function root_of(options)
    local configured = package.loaded.parley and package.loaded.parley.config
    return options.root or (configured and configured.state_dir) or require('parley.config').state_dir
end
local function paths(root, namespace, id)
    local directory = root:gsub('/$', '') .. '/document-moves/' .. hash(namespace)
    return directory, directory .. '/' .. hash(id) .. '.json'
end
local function plain_path(path)
    if type(path) ~= 'string' or path:sub(1, 1) ~= '/' or #path > 4096
        or path:find('[%z\1-\31\127\\]') or path:find('//', 1, true) then return false end
    for part in path:gmatch('[^/]+') do if part == '.' or part == '..' then return false end end
    return path:sub(-1) ~= '/'
end
local function canonical(fs, path)
    if not plain_path(path) then return false end
    local resolved = fs.fs_realpath(path)
    if resolved then return resolved == path end
    return fs.fs_realpath(dirname(path)) == dirname(path)
end
local function mkdir(fs, path)
    local info = fs.fs_stat(path)
    if info then return info.type == 'directory' end
    local parent = dirname(path)
    if parent == path or not mkdir(fs, parent) then return false end
    return fs.fs_mkdir(path, 448) or (fs.fs_stat(path) or {}).type == 'directory'
end
local function read(fs, path, limit)
    local entry = fs.fs_lstat(path)
    if not entry or entry.type ~= 'file' or entry.size > (limit or MAX_FILE) then return nil, 'invalid or oversized file: ' .. path end
    local fd, err = fs.fs_open(path, 'r', 0)
    if not fd then return nil, err end
    local opened = fs.fs_fstat(fd)
    if not opened or opened.dev ~= entry.dev or opened.ino ~= entry.ino then
        fs.fs_close(fd); return nil, 'file changed during open'
    end
    local bytes, read_err = fs.fs_read(fd, opened.size, 0)
    local after = fs.fs_fstat(fd)
    local closed, close_err = fs.fs_close(fd)
    if not bytes or #bytes ~= opened.size or not closed or not after or after.size ~= opened.size
        or after.mtime.sec ~= opened.mtime.sec or after.mtime.nsec ~= opened.mtime.nsec then
        return nil, read_err or close_err or 'file changed during read'
    end
    return bytes, nil, opened
end
-- A preflight existence check cannot make POSIX rename safe: another writer
-- can create NEW between that check and the syscall. Both supported kernels
-- provide atomic no-replace rename; unavailable symbols/filesystems fail closed.
local exclusive_rename, exclusive_error
local function rename_noreplace(fs, old, new)
    if fs.fs_rename_noreplace then return fs.fs_rename_noreplace(old, new) end
    if not exclusive_rename then
        if exclusive_error then return nil, exclusive_error end
        local ok, backend = pcall(function()
            local ffi = require('ffi')
            local rename, call
            if ffi.os == 'OSX' then
                ffi.cdef('int renamex_np(const char *oldpath, const char *newpath, unsigned int flags);')
                rename = ffi.C.renamex_np
                call = function(from, to) return rename(from, to, 4) end -- RENAME_EXCL
            elseif ffi.os == 'Linux' then
                ffi.cdef('int renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);')
                rename = ffi.C.renameat2
                call = function(from, to) return rename(-100, from, -100, to, 1) end -- AT_FDCWD, RENAME_NOREPLACE
            else error('unsupported exclusive rename platform') end
            return function(from, to)
                if call(from, to) == 0 then return true end
                return nil, 'exclusive migration rename failed: errno ' .. ffi.errno()
            end
        end)
        if not ok then
            exclusive_error = 'exclusive migration rename unavailable: ' .. tostring(backend)
            return nil, exclusive_error
        end
        exclusive_rename = backend
    end
    return exclusive_rename(old, new)
end

local function witness(stat)
    return { dev = stat.dev, ino = stat.ino, size = stat.size,
        mtime = { sec = stat.mtime.sec, nsec = stat.mtime.nsec }, type = stat.type }
end
local function same_inode(stat, expected)
    return stat and type(expected) == 'table' and stat.dev == expected.dev and stat.ino == expected.ino
end
local function same_file(stat, expected)
    return same_inode(stat, expected) and stat.type == expected.type and stat.size == expected.size
        and stat.mtime.sec == expected.mtime.sec and stat.mtime.nsec == expected.mtime.nsec
end
local function scan_tree(fs, base, ignore)
    local entries, markdown = {}, 0
    local function walk(directory)
        local scan, err = fs.fs_scandir(directory)
        if not scan then return nil, err end
        while true do
            local name = fs.fs_scandir_next(scan)
            if not name then break end
            local path = directory .. '/' .. name
            if not (ignore and ignore[path]) then
                local stat = fs.fs_lstat(path)
                if not stat or (stat.type ~= 'file' and stat.type ~= 'directory') or fs.fs_realpath(path) ~= path then
                    return nil, 'symlink or changed side entry: ' .. path
                end
                entries[#entries + 1] = { path = path, resolved = path, type = stat.type, witness = witness(stat) }
                if #entries > 4096 then return nil, 'side entry limit exceeded' end
                if stat.type == 'file' and projection.is_markdown_path(path) then
                    markdown = markdown + 1
                    if markdown > 512 then return nil, 'Markdown backlink limit exceeded' end
                    local bytes, read_err = read(fs, path)
                    if not bytes then return nil, read_err end
                    entries[#entries].bytes = bytes
                elseif stat.type == 'directory' then
                    local ok, walk_err = walk(path)
                    if not ok then return nil, walk_err end
                end
            end
        end
        return true
    end
    local ok, err = walk(base)
    if not ok then return nil, err end
    table.sort(entries, function(a, b) return a.path < b.path end)
    return entries
end

-- Adapt descriptors to the canonical checked writer, including exclusive temps.
-- Bootstrap writes its exclusive journal directly: interruption leaves a visible
-- invalid intent, never a temporary without an already-persisted manifest.
local function writer(operation, temporary, bootstrap, expected_hash)
    local fs, created = operation.fs, false
    return {
        temp_path = function() return temporary end,
        realpath = function(path)
            if bootstrap then return nil end
            return path -- migration targets must remain canonical, never follow symlinks
        end,
        stat = fs.fs_stat,
        chmod = fs.fs_chmod,
        open = function(path)
            local fd, err = fs.fs_open(path, 'wx', 384)
            if not fd then return nil, err end
            created = true
            return {
                write = function(_, bytes)
                    local written, write_err = fs.fs_write(fd, bytes, 0)
                    if written ~= #bytes then return nil, write_err or 'short write' end
                    return true
                end,
                close = function() return fs.fs_close(fd) end,
            }
        end,
        rename = function(from, to)
            if bootstrap and from == to then return true end
            if expected_hash then
                if not canonical(fs, to) then return nil, 'atomic target path changed' end
                local bytes, err = read(fs, to)
                if not bytes or hash(bytes) ~= expected_hash then return nil, err or 'atomic target preimage changed' end
            end
            return fs.fs_rename(from, to)
        end,
        remove = function(path)
            if created then return fs.fs_unlink(path) end
            return true
        end,
    }
end
local function encode(journal)
    local ok, bytes = pcall(vim.json.encode, journal)
    if not ok or #bytes > MAX_JOURNAL then return nil, 'journal exceeds 256KiB or cannot be encoded' end
    return bytes
end
local function persist(operation, bootstrap)
    local bytes, err = encode(operation.journal)
    if not bytes then return nil, err end
    local temporary = bootstrap and operation.journal_path or operation.journal.temps[1]
    if not bootstrap and operation.journal.version == 2 and operation.fs.fs_lstat(temporary) then
        -- Reconstruct the prospective checkpoint from fresh witnesses, rather
        -- than accepting arbitrary valid JSON at an operation-shaped path.
        local residue, residue_err, stat = read(operation.fs, temporary, MAX_JOURNAL)
        if not residue then return nil, residue_err end
        local decoded, candidate = pcall(vim.json.decode, residue, { luanil = { object = true, array = true } })
        local valid = decoded and validate(candidate, operation.namespace, operation.id, operation.journal_path)
        if not valid or not vim.deep_equal(candidate, operation.journal) then
            return nil, 'unpublished journal temporary does not match the reobserved checkpoint'
        end
        local current, current_err, current_stat = read(operation.fs, operation.journal_path, MAX_JOURNAL)
        if not current or hash(current) ~= operation.disk_hash or not canonical(operation.fs, operation.journal_path)
            or not canonical(operation.fs, temporary) then return nil, current_err or 'journal preimage changed' end
        local again, again_err, again_stat = read(operation.fs, temporary, MAX_JOURNAL)
        if not again or hash(again) ~= hash(residue) or not same_file(again_stat, stat)
            or not same_file(operation.fs.fs_lstat(temporary), stat)
            or not same_file(operation.fs.fs_lstat(operation.journal_path), current_stat) then
            return nil, again_err or 'unpublished journal temporary changed'
        end
        local removed, remove_err = operation.fs.fs_unlink(temporary)
        if not removed then return nil, remove_err end
    end
    local saved, save_err = helper.write_file_atomic(bytes, operation.journal_path,
        writer(operation, temporary, bootstrap, operation.disk_hash))
    if saved then operation.disk_hash = hash(bytes) end
    return saved, save_err
end
local function operation_for(namespace, journal, path, lease, options)
    local operation = {
        namespace = namespace, id = journal.id, old = journal.old, new = journal.new,
        registration = vim.deepcopy(journal.registration), journal = journal, journal_path = path,
        lease = lease, fs = options.fs or options.adapter or uv, options = options,
        old_lock = journal.protection.old_lock, new_lock = journal.protection.new_lock,
        baseline = journal.protection.baseline, document_move = journal.document_move == true,
        released = false, running = false,
    }
    function operation.release()
        if operation.released then return true end
        operation.released = true
        return lease.release()
    end
    return operation
end
local function hook(operation, name, ...)
    local callback = operation.options[name]
    if not callback then return true end
    local called, ok, err = pcall(callback, operation, ...)
    if not called then return nil, ok end
    return ok, err
end
local function acquire(namespace, id, root, options)
    if options.lease then
        local supplied, fs = options.lease, options.fs or options.adapter or uv
        local expected = root:gsub('/$', '') .. '/document-leases/' .. hash(namespace) .. '/' .. hash(id) .. '.lock'
        if supplied.path ~= expected or type(supplied.fd) ~= 'number' or type(supplied.release) ~= 'function'
            or not same_inode(fs.fs_fstat(supplied.fd), fs.fs_stat(expected)) then
            return failure('unavailable', 'invalid pre-acquired document lease')
        end
        return supplied
    end
    return leases.acquire(namespace, id, { root = root, fs = options.fs or options.adapter })
end
local function new_temp(path, token)
    return dirname(path) .. '/.' .. vim.fn.fnamemodify(path, ':t') .. '.parley-move-' .. token .. '.tmp'
end
local function valid_digest(value) return type(value) == 'string' and #value == 64 and value:match('^[a-f0-9]+$') end

local function valid_witness(value, kind)
    return type(value) == 'table' and value.type == kind and type(value.dev) == 'number'
        and type(value.ino) == 'number' and type(value.size) == 'number' and value.size >= 0
        and type(value.mtime) == 'table' and type(value.mtime.sec) == 'number' and type(value.mtime.nsec) == 'number'
end

-- Validate all persisted authority before looking at temporary paths or effects.
local function validate_v1(journal, namespace, id, path)
    if type(journal) ~= 'table' or journal.version ~= 1 or journal.namespace ~= namespace or journal.id ~= id
        or not plain_path(journal.old) or not plain_path(journal.new) or journal.old == journal.new
        or type(journal.registration) ~= 'table' or journal.registration.ID ~= id
        or journal.registration.File ~= journal.old or type(journal.registration.Owner) ~= 'string'
        or not valid_digest(journal.token) or type(journal.entries) ~= 'table' or #journal.entries > 4096
        or type(journal.temps) ~= 'table' or type(journal.steps) ~= 'table'
        or type(journal.steps.rewritten) ~= 'table' or type(journal.steps.side_moved) ~= 'boolean'
        or type(journal.protection) ~= 'table' or type(journal.steps.metadata) ~= 'boolean'
        or (journal.document_move ~= nil and type(journal.document_move) ~= 'boolean')
        or (journal.steps.document_moved ~= nil and type(journal.steps.document_moved) ~= 'boolean')
        or (journal.steps.saved_after_move ~= nil and type(journal.steps.saved_after_move) ~= 'boolean')
        or (journal.old_witness ~= false and not valid_witness(journal.old_witness, 'file'))
        or (journal.side_witness ~= false and not valid_witness(journal.side_witness, 'directory'))
        or (journal.new_witness ~= false and (not valid_witness(journal.new_witness, 'file')
            or not valid_digest(journal.new_witness.hash)))
        or (journal.old_witness and not valid_digest(journal.old_hash)) then return nil, 'invalid migration journal schema' end
    if journal.document_move then
        if not journal.old_witness then return nil, 'owned migration requires an OLD witness' end
        if journal.steps.document_moved then
            -- The moved bytes, unless the operator saved since (#359): then the
            -- recorded save is the witness.
            if not journal.new_witness or (not journal.steps.saved_after_move
                and (journal.new_witness.hash ~= journal.old_hash
                    or not same_inode(journal.new_witness, journal.old_witness))) then
                return nil, 'invalid owned document checkpoint'
            end
        elseif journal.new_witness or journal.steps.side_moved or journal.steps.metadata then
            return nil, 'owned effects precede document checkpoint'
        end
    elseif journal.steps.document_moved then return nil, 'document checkpoint without owned intent' end
    local expected_temps = { new_temp(path, journal.token) }
    local seen, markdown = {}, 0
    for index, entry in pairs(journal.entries) do
        if type(index) ~= 'number' or index < 1 or index % 1 ~= 0 or index > #journal.entries
            or type(entry) ~= 'table' or type(entry.relative) ~= 'string'
            or not plain_path(side(journal.old) .. '/' .. entry.relative)
            or entry.relative:sub(1, 1) == '/' or seen[entry.relative]
            or (entry.type ~= 'file' and entry.type ~= 'directory') or not valid_witness(entry.witness, entry.type) then
            return nil, 'invalid migration entry'
        end
        seen[entry.relative] = true
        if entry.before then
            markdown = markdown + 1
            if entry.type ~= 'file' or not projection.is_markdown_path(entry.relative) or not valid_digest(entry.before)
                or not valid_digest(entry.after) or markdown > 512 then return nil, 'invalid backlink witness' end
            if entry.before ~= entry.after then expected_temps[#expected_temps + 1] = new_temp(side(journal.new) .. '/' .. entry.relative, journal.token) end
        elseif projection.is_markdown_path(entry.relative) and entry.type == 'file' then return nil, 'missing backlink witness' end
    end
    if #journal.temps ~= #expected_temps then return nil, 'invalid temporary manifest' end
    for index, temporary in pairs(journal.temps) do
        if temporary ~= expected_temps[index] then return nil, 'unowned temporary manifest path' end
    end
    for relative, done in pairs(journal.steps.rewritten) do
        if not seen[relative] or done ~= true then return nil, 'invalid rewrite checkpoint' end
    end
    return true
end
validate = function(journal, namespace, id, path)
    if type(journal) ~= 'table' or journal.version ~= 2 then return validate_v1(journal, namespace, id, path) end
    local state, err = model.restore(journal.state)
    if not state then return nil, err end
    if journal.steps ~= nil or state.op_id ~= journal.token or state.id ~= id or state.new ~= journal.new
        or state.generation ~= 1 or type(journal.parent) ~= 'table'
        or not valid_digest(journal.parent.before) or not valid_digest(journal.parent.after)
        or type(journal.entries) ~= 'table' or type(journal.temps) ~= 'table'
        or type(journal.editor_captured) ~= 'boolean'
        or not journal.editor_captured and (state.phase ~= 'prepared' or journal.parent.editor_before_hash ~= false)
        or journal.document_move and (not journal.captured or journal.parent.before ~= journal.old_hash)
        or (journal.parent.editor_before_hash ~= false and not valid_digest(journal.parent.editor_before_hash))
        or type(journal.captured) ~= 'boolean' or not journal.captured and state.phase ~= 'prepared' then return nil, 'invalid v2 migration authority' end
    if state.document.before ~= journal.parent.before or state.document.after ~= journal.parent.before
        or not vim.deep_equal(state.parent, { before = journal.parent.before, after = journal.parent.after }) then
        return nil, 'parent state disagrees with captured hashes'
    end
    local shadow = vim.deepcopy(journal)
    shadow.version, shadow.state = 1, nil
    shadow.steps = { document_moved = false, side_moved = false, rewritten = {}, metadata = false }
    shadow.new_witness = false
    if shadow.document_move then
        -- v1 common validation checks intent only; v2 progress belongs to state.
        shadow.parent = nil
    end
    table.remove(shadow.temps)
    local valid, common_err = validate_v1(shadow, namespace, id, path)
    if not valid then return nil, common_err end
    local orphan = journal.orphan
    if orphan ~= false then
        if type(orphan) ~= 'table' or not valid_witness(orphan.witness, 'directory')
            or type(orphan.suffix) ~= 'number' or orphan.suffix < 1 or orphan.suffix > 4096 or orphan.suffix % 1 ~= 0
            or orphan.path ~= side(journal.new):sub(1, -6) .. '_' .. orphan.suffix .. '.side'
            or side(journal.old) == side(journal.new)
            or not vim.deep_equal(state.orphan, { before = orphan.witness, after = orphan.witness }) then
            return nil, 'invalid orphan authority'
        end
    elseif state.orphan ~= false then return nil, 'unexpected orphan state' end
    local expected_side = journal.side_witness and { before = journal.side_witness, after = journal.side_witness } or false
    if not vim.deep_equal(state.side, expected_side) then return nil, 'invalid side state' end
    local expected_children = {}
    for _, entry in ipairs(journal.entries or {}) do
        if entry.before and entry.before ~= entry.after then
            expected_children[#expected_children + 1] = { id = entry.relative, before = entry.before, after = entry.after }
        end
    end
    if not vim.deep_equal(state.children, expected_children) then return nil, 'invalid child state' end
    if journal.temps[#journal.temps] ~= new_temp(journal.new, journal.token) then return nil, 'invalid parent temporary' end
    if journal.new_witness ~= false and (not valid_witness(journal.new_witness, 'file')
        or not valid_digest(journal.new_witness.hash) or journal.new_witness.hash ~= state.document_witness) then
        return nil, 'invalid current parent witness'
    end
    if state.phase == 'complete' or state.phase == 'retired' then
        local confirmed = journal.confirmation
        local registration = type(confirmed) == 'table' and confirmed.registration
        if type(confirmed) ~= 'table' or confirmed.kind ~= 'registered' or type(registration) ~= 'table'
            or registration.ID ~= journal.id or registration.File ~= journal.new
            or type(registration.Owner) ~= 'string' or registration.Owner == '' then
            return nil, 'missing confirmed registration authority'
        end
    elseif journal.confirmation ~= false then return nil, 'confirmation precedes metadata acknowledgement' end
    if state.phase ~= 'prepared' and state.phase ~= 'orphan' and state.phase ~= 'document' and not journal.new_witness then
        return nil, 'missing current document witness'
    end
    return true
end
local function load(fs, path, namespace, id)
    local bytes, err = read(fs, path, MAX_JOURNAL)
    if not bytes then return nil, err end
    local ok, journal = pcall(vim.json.decode, bytes, { luanil = { object = true, array = true } })
    if not ok then return nil, 'invalid migration journal JSON' end
    id = id or (type(journal) == 'table' and journal.id)
    if type(id) ~= 'string' or id == '' or #id > 256
        or vim.fn.fnamemodify(path, ':t') ~= hash(id) .. '.json' then return nil, 'migration journal identity/path mismatch' end
    local valid, validation_err = validate(journal, namespace, id, path)
    if not valid then return nil, validation_err end
    return journal, nil, hash(bytes)
end
local function cleanup(operation)
    local journal, fs = operation.journal, operation.fs
    local phase = journal.version == 2 and journal.state.phase
    local children_ready = phase == 'children' or phase == 'parent' or phase == 'editor'
        or phase == 'metadata' or phase == 'complete' or phase == 'retired'
    local parent_ready = phase == 'parent' or phase == 'editor' or phase == 'metadata'
        or phase == 'complete' or phase == 'retired'
    for index, temporary in ipairs(journal.temps) do
        local eligible = journal.version ~= 2 or index ~= 1
            and (index == #journal.temps and parent_ready or index < #journal.temps and children_ready)
        -- An unpublished journal candidate is consumed only by persist when it
        -- exactly matches a dispatcher checkpoint reconstructed from witnesses.
        -- Future tree temps may still name files inside the captured orphan.
        if eligible then
            local stat = fs.fs_lstat(temporary)
            if stat then
                if stat.type ~= 'file' then return nil, 'unexpected temporary type' end
                if journal.version == 2 then
                    local expected = index == #journal.temps and journal.parent.after or nil
                    if not expected then
                        for _, entry in ipairs(journal.entries) do
                            if entry.before and entry.before ~= entry.after
                                and temporary == new_temp(side(journal.new) .. '/' .. entry.relative, journal.token) then
                                expected = entry.after; break
                            end
                        end
                    end
                    local bytes, err, opened = read(fs, temporary)
                    if not bytes or not expected or hash(bytes) ~= expected or not canonical(fs, temporary)
                        or not same_file(fs.fs_lstat(temporary), opened) then
                        return nil, err or 'temporary bytes are not a proven migration publication'
                    end
                end
                local removed, err = fs.fs_unlink(temporary)
                if not removed then return nil, err end
            end
        end
    end
    return true
end

function M.begin(namespace, registration, new_path, options)
    options = options or {}
    if type(namespace) ~= 'string' or namespace == '' or type(registration) ~= 'table'
        or type(registration.ID) ~= 'string' or registration.ID == '' or #registration.ID > 256
        or type(registration.Owner) ~= 'string' or registration.Owner == '' then
        return failure('unavailable', 'confirmed registration is required')
    end
    if options.move_document ~= nil and type(options.move_document) ~= 'boolean' then
        return failure('unavailable', 'move_document must be a boolean')
    end
    local fs, root = options.fs or options.adapter or uv, root_of(options)
    if type(root) ~= 'string' or root == '' then return failure('unavailable', 'state directory is missing') end
    local lease, lease_err = acquire(namespace, registration.ID, root, options)
    if not lease then return nil, lease_err end
    local function refuse(kind, message) lease.release(); return failure(kind, message) end
    local directory, path = paths(root, namespace, registration.ID)
    if fs.fs_lstat(path) then
        local existing, existing_err = load(fs, path, namespace, registration.ID)
        if not existing then return refuse('pending', existing_err) end
        return refuse('pending', 'recover the existing exact migration tuple first')
    end
    -- #359: false is confirmed absent; 'authority' leaves it to Couch's rename,
    -- which refuses an occupied destination after the file moved (the journal
    -- then stays pending, and recovery replays the rename).
    local destination = options.destination_registered
    if destination ~= false and destination ~= 'authority' then
        return refuse('unavailable', 'destination registration must be confirmed absent or left to Couch')
    end
    local old = registration.File
    if not canonical(fs, old) or not canonical(fs, new_path) then return refuse('unavailable', 'migration paths are not canonical') end
    local old_stat, new_stat = fs.fs_lstat(old), fs.fs_lstat(new_path)
    if options.move_document and (not old_stat or new_stat) then
        return refuse('unavailable', 'owned document move requires existing OLD and absent NEW')
    end
    if old_stat and old_stat.type ~= 'file' or new_stat and new_stat.type ~= 'file' then return refuse('unavailable', 'invalid document file type') end
    local source, target = side(old), side(new_path)
    local source_stat, target_stat = fs.fs_lstat(source), fs.fs_lstat(target)
    if source_stat and (source_stat.type ~= 'directory' or fs.fs_realpath(source) ~= source) then return refuse('unavailable', 'invalid source side directory') end
    local entries, scan_err = {}, nil
    if source_stat then entries, scan_err = scan_tree(fs, source) end
    if not entries then return refuse('unavailable', scan_err) end
    local parent_bytes, parent_err = options.parent_bytes, nil
    if parent_bytes == nil then parent_bytes, parent_err = read(fs, old) end
    if type(parent_bytes) ~= 'string' or #parent_bytes > MAX_FILE then return refuse('unavailable', parent_err or 'invalid parent bytes') end
    if options.move_document and options.parent_bytes ~= nil then
        local syntax, syntax_err = projection.rewrite_side_references(parent_bytes, old, new_path)
        if not syntax then return refuse('unavailable', syntax_err) end
        parent_bytes, parent_err = read(fs, old)
        if not parent_bytes then return refuse('unavailable', parent_err) end
    end
    local parent_after, parent_rewrite_err = projection.rewrite_side_references(parent_bytes, old, new_path)
    if not parent_after then return refuse('unavailable', parent_rewrite_err) end
    local orphan_candidates = {}
    if source ~= target and target_stat then
        if new_stat or target_stat.type ~= 'directory' or fs.fs_realpath(target) ~= target then
            return refuse('unavailable', 'occupied move destination is not an admitted orphan')
        end
        for suffix = 1, 4096 do
            local occupied = fs.fs_lstat(target:sub(1, -6) .. '_' .. suffix .. '.side') ~= nil
            orphan_candidates[#orphan_candidates + 1] = occupied
            if not occupied then break end
        end
    end
    local projected, project_err = projection.project(old, new_path, {
        id = registration.ID, old_exists = old_stat ~= nil, new_exists = new_stat ~= nil, new_written = false,
        destination_registered = destination, side_exists = source_stat ~= nil, target_side_exists = target_stat ~= nil, entries = entries,
        parent_bytes = parent_bytes, new_absent_at_admission = new_stat == nil, orphan_candidates = orphan_candidates,
    })
    if not projected then return refuse('unavailable', project_err) end
    local token = hash(tostring(uv.hrtime()) .. ':' .. tostring(vim.fn.getpid()) .. ':' .. registration.ID)
    local journal = {
        version = 1, namespace = namespace, id = registration.ID, old = old, new = new_path,
        registration = vim.deepcopy(registration), token = token,
        old_witness = old_stat and witness(old_stat) or false,
        side_witness = source_stat and witness(source_stat) or false,
        new_witness = false, document_move = options.move_document == true, entries = {}, temps = { new_temp(path, token) },
        steps = { document_moved = false, side_moved = false, rewritten = {}, metadata = false },
        protection = { old_lock = options.old_lock, new_lock = options.new_lock, baseline = options.baseline },
    }
    if old_stat then
        local bytes, err = read(fs, old)
        if not bytes then return refuse('unavailable', err) end
        journal.old_hash = hash(bytes)
    end
    for _, entry in ipairs(entries) do
        local relative = entry.path:sub(#source + 2)
        local recorded = { relative = relative, type = entry.type, witness = entry.witness }
        if entry.bytes then
            local after, err = projection.rewrite_parent(entry.bytes,
                { old = entry.path, new = target .. '/' .. relative }, { old = old, new = new_path })
            if not after then return refuse('unavailable', err) end
            recorded.before, recorded.after = hash(entry.bytes), hash(after)
            if recorded.before ~= recorded.after then journal.temps[#journal.temps + 1] = new_temp(target .. '/' .. relative, token) end
        end
        journal.entries[#journal.entries + 1] = recorded
    end
    journal.version, journal.steps = 2, nil
    journal.parent = { before = hash(parent_bytes), after = hash(parent_after), editor_before_hash = false }
    journal.editor_captured, journal.confirmation = false, false
    journal.captured = options.move_document == true
    journal.orphan = projected.orphan_destination and { path = projected.orphan_destination,
        suffix = #orphan_candidates, witness = witness(target_stat) } or false
    journal.temps[#journal.temps + 1] = new_temp(new_path, token)
    local children = {}
    for _, entry in ipairs(journal.entries) do
        if entry.before and entry.before ~= entry.after then
            children[#children + 1] = { id = entry.relative, before = entry.before, after = entry.after }
        end
    end
    local initial_state, initial_err = model.initial({ op_id = token, id = journal.id, new = new_path,
        generation = 1, document_generation = 1,
        document = { before = journal.parent.before, after = journal.parent.before },
        parent = { before = journal.parent.before, after = journal.parent.after },
        orphan = journal.orphan and { before = journal.orphan.witness, after = journal.orphan.witness } or false,
        side = journal.side_witness and { before = journal.side_witness, after = journal.side_witness } or false,
        children = children })
    if not initial_state then return refuse('limit', initial_err) end
    journal.state = initial_state
    local operation = operation_for(namespace, journal, path, lease, options)
    operation.orphan_destination = journal.orphan and journal.orphan.path or nil
    local encoded, encode_err = encode(journal)
    if not encoded then return refuse('limit', encode_err) end
    local budget, budget_err = leases.acquire(namespace .. '\0migration-journal-budget', 'allocation', { root = root })
    if not budget then lease.release(); return nil, budget_err end
    local function budget_refuse(kind, message) budget.release(); return refuse(kind, message) end
    if not mkdir(fs, directory) then return budget_refuse('unavailable', 'cannot create journal directory') end
    local scan, list_err = fs.fs_scandir(directory)
    if not scan then return budget_refuse('unavailable', list_err) end
    local count = 0
    while true do
        local name = fs.fs_scandir_next(scan)
        if not name then break end
        if name:match('%.json$') then count = count + 1 end
        if count >= MAX_PENDING then return budget_refuse('limit', 'pending journal limit reached (32)') end
    end
    local saved, save_err = persist(operation, true)
    budget.release()
    if not saved then return refuse('unavailable', save_err) end
    local installed, install_err = hook(operation, 'install_new')
    if not installed then operation.release(); return failure('pending', install_err or 'NEW protection was not installed') end
    return operation
end

local function verify_tree(operation, base, after_move)
    local fs, journal = operation.fs, operation.journal
    local actual, err = scan_tree(fs, base)
    if not actual then return nil, err end
    if #actual ~= #journal.entries then return nil, 'side contents changed' end
    local mapped = {}
    for _, entry in ipairs(actual) do mapped[entry.path:sub(#base + 2)] = entry end
    for _, expected in ipairs(journal.entries) do
        local entry = mapped[expected.relative]
        if not entry or entry.type ~= expected.type then return nil, 'side entry changed' end
        if expected.before then
            local digest = hash(entry.bytes)
            if digest ~= expected.before and (not after_move or digest ~= expected.after) then return nil, 'backlink preimage changed' end
        elseif expected.type == 'file' then
            if not same_file(entry.witness, expected.witness) then return nil, 'side file changed' end
        elseif not same_inode(entry.witness, expected.witness) then return nil, 'side directory changed' end
    end
    return true
end

local function advance_document(operation)
    local fs, journal = operation.fs, operation.journal
    local from, to = fs.fs_lstat(journal.old), fs.fs_lstat(journal.new)
    -- #359: once the document moved, the operator may save it before Couch
    -- confirms; record_write keeps the latest of those writes as the witness.
    local moved_before = journal.steps.document_moved and journal.new_witness
    if from then
        if journal.steps.document_moved or to or not same_inode(from, journal.old_witness) then
            return nil, 'owned document rename cannot be proven'
        end
        local bytes, err, opened = read(fs, journal.old)
        if not bytes or hash(bytes) ~= journal.old_hash or not same_inode(opened, journal.old_witness) then
            return nil, err or 'captured OLD changed before owned rename'
        end
        if not canonical(fs, journal.old) or not canonical(fs, journal.new)
            or not same_inode(fs.fs_lstat(journal.old), journal.old_witness) or fs.fs_lstat(journal.new) then
            return nil, 'owned document paths changed before rename'
        end
        local renamed, rename_err = rename_noreplace(fs, journal.old, journal.new)
        if not renamed then return nil, rename_err end
    elseif not moved_before and not same_inode(to, journal.old_witness) then
        return nil, 'owned document rename has no matching inode witness'
    end
    local bytes, err, opened = read(fs, journal.new)
    if moved_before then
        if fs.fs_lstat(journal.old) or not bytes or hash(bytes) ~= journal.new_witness.hash then
            return nil, err or 'NEW changed since its last recorded write'
        end
    else
        -- A crash may have published the rename before the journal checkpoint. Only
        -- OLD absence plus the original inode AND bytes proves that exact effect.
        if fs.fs_lstat(journal.old) or not bytes or hash(bytes) ~= journal.old_hash
            or not same_inode(opened, journal.old_witness) then
            return nil, err or 'owned document rename result is uncertain'
        end
        journal.new_witness = witness(opened)
        journal.new_witness.hash = hash(bytes)
        journal.steps.document_moved = true
        local saved, save_err = persist(operation)
        if not saved then return nil, save_err end
    end
    if not operation.document_notified then
        local named, name_err = hook(operation, 'document_moved')
        if not named then return nil, name_err or 'owned buffer name handoff is pending' end
        operation.document_notified = true
    end
    return true
end

--- The operator saved the moved document while its metadata rename was still
--- out (#359): make that write the journal's witness for NEW, so a recovery
--- after a refused or lost rename proves the move against the bytes they saved.
--- Only for an owned move whose document already moved.
local function record_write_v1(operation)
    local journal = operation and operation.journal
    if not journal or not journal.document_move or not journal.steps.document_moved or operation.released then
        return nil, 'no moved document to record'
    end
    local bytes, err, opened = read(operation.fs, journal.new)
    if not bytes then return nil, err end
    journal.new_witness = witness(opened)
    journal.new_witness.hash = hash(bytes)
    journal.steps.saved_after_move = true
    return persist(operation)
end

local function advance_v1(operation, callback)
    local function pending(message)
        operation.running = false
        callback({ kind = 'pending', error = tostring(message), operation = operation })
    end
    if operation.released then pending('migration lease has been released'); return end
    if operation.running then callback({ kind = 'pending', error = 'migration already running' }); return end
    operation.running = true
    local fs, journal = operation.fs, operation.journal
    local valid, valid_err = validate(journal, operation.namespace, operation.id, operation.journal_path)
    if not valid then pending(valid_err); return end
    local reconciled, reconcile_err = hook(operation, 'reconcile')
    if not reconciled then pending(reconcile_err or 'OLD reconciliation is pending'); return end
    if journal.document_move then
        local moved, move_err = advance_document(operation)
        if not moved then pending(move_err); return end
    else
        if fs.fs_lstat(journal.old) and journal.old_hash then
            local bytes, err = read(fs, journal.old)
            if not bytes or hash(bytes) ~= journal.old_hash then pending(err or 'OLD changed before migration'); return end
        end
        local new_bytes, new_err, new_stat = read(fs, journal.new)
        if not new_bytes then pending(new_err or 'NEW successful write is required'); return end
        if journal.new_witness and journal.new_witness.hash ~= hash(new_bytes) then pending('NEW changed since successful write'); return end
        if not journal.new_witness then
            journal.new_witness = witness(new_stat)
            journal.new_witness.hash = hash(new_bytes)
            local saved, err = persist(operation)
            if not saved then pending(err); return end
        end
    end
    local clean, clean_err = cleanup(operation)
    if not clean then pending(clean_err); return end
    local source, target = side(journal.old), side(journal.new)
    if journal.side_witness then
        local from, to = fs.fs_lstat(source), fs.fs_lstat(target)
        if source == target then
            -- An extension-only rename keeps the same directory. The inode
            -- witness still owns it; recovery may observe mixed before/after
            -- backlinks, checked below, without performing a directory rename.
            if not same_inode(to, journal.side_witness) then pending('shared side directory changed'); return end
        else
            local moved = not from and same_inode(to, journal.side_witness)
            if not moved then
                if journal.steps.side_moved or to or not same_inode(from, journal.side_witness) then pending('side rename cannot be proven'); return end
                local unchanged, err = verify_tree(operation, source, false)
                if not unchanged then pending(err); return end
                local renamed, rename_err = rename_noreplace(fs, source, target)
                if not renamed then pending(rename_err); return end
            end
        end
        local proven, proof_err = verify_tree(operation, target, true)
        if not proven then pending(proof_err); return end
        journal.steps.side_moved = true
        local saved, save_err = persist(operation)
        if not saved then pending(save_err); return end
        for _, entry in ipairs(journal.entries) do
            if entry.before and entry.before ~= entry.after then
                local path = target .. '/' .. entry.relative
                local bytes, err = read(fs, path)
                if not bytes then pending(err); return end
                local digest = hash(bytes)
                if digest ~= entry.after then
                    if digest ~= entry.before then pending('backlink changed before rewrite'); return end
                    local after, rewrite_err = projection.rewrite_parent(bytes,
                        { old = source .. '/' .. entry.relative, new = path }, { old = journal.old, new = journal.new })
                    if not after or hash(after) ~= entry.after then pending(rewrite_err or 'backlink projection changed'); return end
                    local written, write_err = helper.write_file_atomic(after, path, writer(operation, new_temp(path, journal.token), false, entry.before))
                    if not written then pending(write_err); return end
                end
                journal.steps.rewritten[entry.relative] = true
                local checkpoint, checkpoint_err = persist(operation)
                if not checkpoint then pending(checkpoint_err); return end
            end
        end
    elseif fs.fs_lstat(target) then pending('unexpected destination side directory'); return end

    local consumed = false
    local function metadata_done(result)
        if consumed or operation.released then return end
        consumed = true
        local registration = type(result) == 'table' and result.registration
        if type(result) ~= 'table' or result.kind ~= 'registered' or type(registration) ~= 'table'
            or registration.ID ~= journal.id or registration.File ~= journal.new
            or type(registration.Owner) ~= 'string' or registration.Owner == '' then
            pending(type(result) == 'table' and result.error or 'metadata confirmation is uncertain'); return
        end
        journal.steps.metadata = true
        local saved, save_err = persist(operation)
        if not saved then pending(save_err); return end
        local finished, finish_err = hook(operation, 'finish', result)
        if not finished then pending(finish_err or 'local handoff is pending'); return end
        local removed, remove_err = fs.fs_unlink(operation.journal_path)
        if not removed then pending(remove_err); return end
        operation.running = false
        operation.release()
        callback(result)
    end
    local metadata = operation.options.metadata
    if metadata then
        local ok, err = pcall(metadata, operation, metadata_done)
        if not ok and not consumed then consumed = true; pending(err) end
    else
        local registry = operation.options.registry or require('parley.document_registry')
        operation.request = registry.request('rename', { journal.old, journal.new },
            { id = journal.id, old = journal.old, new = journal.new }, metadata_done, operation.options.registry_options)
    end
end

-- The sole v2 checkpoint owner. Disk observations authorize reducer events;
-- publication is never inferred from a checkpoint alone.
local function dispatch(operation, callback, saved_write)
    local fs, j = operation.fs, operation.journal
    local function checkpoint(event, change)
        event.op_id, event.generation = j.state.op_id, j.state.generation
        local next_state, outcome = model.step(j.state, event)
        if not next_state or outcome.kind == 'pending' or outcome.kind == 'ignored' then
            return nil, outcome.reason or 'migration transition refused'
        end
        local previous = vim.deepcopy(j)
        if change then change() end
        j.state = next_state
        local ok, err = persist(operation)
        if not ok then operation.journal = previous; j = previous; return nil, err end
        return true
    end
    local function observed(proof, value, child)
        return checkpoint({ kind = 'observed', phase = j.state.phase, proof = proof, witness = value, child_id = child })
    end
    local function authorize(value, child)
        if j.state.phase ~= 'editor' and j.state.phase ~= 'metadata' and fs.fs_lstat(j.temps[1]) then
            local saved, save_err = persist(operation)
            if not saved then return nil, save_err end
        end
        local _, outcome = model.step(j.state, { kind = 'observed', op_id = j.state.op_id,
            generation = j.state.generation, phase = j.state.phase, proof = 'before', witness = value, child_id = child })
        return outcome.kind == 'effect', outcome.reason or 'migration effect not authorized'
    end
    if saved_write then
        if j.state.phase ~= 'metadata' or operation.released then return nil, 'editor synchronization required before save' end
        local bytes, err, stat = read(fs, j.new)
        if not bytes then return nil, err end
        local current = witness(stat); current.hash = hash(bytes)
        return checkpoint({ kind = 'saved', document_generation = j.state.document_generation + 1,
            witness = current.hash }, function() j.new_witness = current end)
    end
    local function pending(reason)
        operation.running = false
        callback({ kind = 'pending', error = tostring(reason), operation = operation,
            orphan_destination = j.orphan and j.state.phase ~= 'prepared' and j.state.phase ~= 'orphan'
                and operation.orphan_destination or nil })
    end
    if operation.released then pending('migration lease has been released'); return end
    if operation.running then callback({ kind = 'pending', error = 'migration already running', operation = operation }); return end
    operation.running = true
    local valid, err = validate(j, operation.namespace, operation.id, operation.journal_path)
    if not valid then pending(err); return end
    local reconciled, reconcile_err = hook(operation, 'reconcile')
    if not reconciled then pending(reconcile_err or 'OLD reconciliation is pending'); return end
    local function document_bytes()
        local bytes, read_err, stat = read(fs, j.new)
        if not bytes then return nil, read_err end
        if not canonical(fs, j.new) or j.document_move and fs.fs_lstat(j.old) then return nil, 'document paths changed' end
        if j.new_witness and (hash(bytes) ~= j.new_witness.hash or not same_file(stat, j.new_witness)) then return nil, 'NEW changed since its last recorded write' end
        return bytes, nil, stat
    end
    local function notify_document()
        if not j.document_move or operation.document_notified then return true end
        local named, name_err = hook(operation, 'document_moved')
        if not named then return nil, name_err or 'buffer name handoff is pending' end
        operation.document_notified = true
        return true
    end
    -- Prove raw NEW before a recovered name handoff can read it into an
    -- editor. Parent publication gaps use the existing parent before/after
    -- proof below, then hand off at editor with the updated raw witness.
    if (operation.recovering or j.document_move and not operation.document_notified)
        and j.state.phase ~= 'prepared' and j.state.phase ~= 'orphan'
        and j.state.phase ~= 'document' and j.state.phase ~= 'parent' then
        local bytes, read_err = document_bytes()
        if not bytes then pending(read_err); return end
        local named, name_err = notify_document()
        if not named then pending(name_err); return end
        if operation.recovering and (j.state.phase == 'metadata' or j.state.phase == 'complete') then
            local synced, sync_err = hook(operation, 'parent_rewritten', {
                path = j.new, before_hash = j.parent.before, after_hash = j.parent.after,
                current_hash = hash(bytes), document_generation = j.state.document_generation, recovering = true,
                before_editor_hash = j.parent.editor_before_hash })
            if not synced then pending(sync_err or 'editor synchronization is pending'); return end
            local current, current_err = document_bytes()
            if not current then pending(current_err); return end
        end
    end
    local clean, clean_err = cleanup(operation)
    if not clean then pending(clean_err); return end
    if j.side_witness and j.state.phase ~= 'prepared' and j.state.phase ~= 'orphan'
        and j.state.phase ~= 'document' and j.state.phase ~= 'side' then
        local proven, proof_err = verify_tree(operation, side(j.new), true)
        if not proven or not same_inode(fs.fs_lstat(side(j.new)), j.side_witness) then
            pending(proof_err or 'side directory changed'); return
        end
        for _, id in ipairs(j.state.completed) do
            local bytes, read_err = read(fs, side(j.new) .. '/' .. id)
            local after
            for _, child in ipairs(j.state.children) do if child.id == id then after = child.after; break end end
            if not bytes or hash(bytes) ~= after then pending(read_err or 'completed backlink changed'); return end
        end
    end
    for _ = 1, 1100 do
        local phase, ok, phase_err = j.state.phase
        if phase == 'prepared' then
            if not j.captured then
                local bytes, read_err, stat = read(fs, j.new)
                if not bytes then pending(read_err or 'NEW successful write is required'); return end
                if fs.fs_lstat(j.old) and j.old_hash then
                    local old_bytes = read(fs, j.old)
                    if not old_bytes or hash(old_bytes) ~= j.old_hash then pending('OLD changed before migration'); return end
                end
                local after, rewrite_err = projection.rewrite_side_references(bytes, j.old, j.new)
                if not after then pending(rewrite_err); return end
                local intent = { op_id = j.token, id = j.id, new = j.new, generation = 1,
                    document_generation = 1, document = { before = hash(bytes), after = hash(bytes) },
                    parent = { before = hash(bytes), after = hash(after) },
                    orphan = j.state.orphan, side = j.state.side, children = j.state.children }
                -- Intent completion precedes any effect and still belongs to this dispatcher.
                local previous = vim.deepcopy(j)
                local initial_state, initial_err = model.initial(intent)
                if not initial_state then pending(initial_err); return end
                j.parent, j.captured, j.state = vim.deepcopy(intent.parent), true, initial_state
                j.parent.editor_before_hash = false
                j.new_witness = witness(stat); j.new_witness.hash = hash(bytes)
                ok, phase_err = persist(operation)
                if not ok then operation.journal = previous; pending(phase_err); return end
            end
            if not j.editor_captured then
                local editor_hash = false
                if operation.options.editor_snapshot then
                    local snapshot, snapshot_err = hook(operation, 'editor_snapshot')
                    if not valid_digest(snapshot) then pending(snapshot_err or 'invalid editor snapshot'); return end
                    editor_hash = snapshot
                end
                local previous = vim.deepcopy(j)
                j.parent.editor_before_hash, j.editor_captured = editor_hash, true
                ok, phase_err = persist(operation)
                if not ok then operation.journal = previous; pending(phase_err); return end
            end
            ok, phase_err = checkpoint({ kind = 'journal_saved' })
        elseif phase == 'orphan' then
            if not j.orphan then ok, phase_err = observed('after', false)
            else
                local target, displaced = fs.fs_lstat(side(j.new)), fs.fs_lstat(j.orphan.path)
                if not target and same_inode(displaced, j.orphan.witness) and canonical(fs, j.orphan.path) then
                    ok, phase_err = observed('after', j.orphan.witness)
                elseif not displaced and same_inode(target, j.orphan.witness) and canonical(fs, side(j.new)) then
                    ok, phase_err = authorize(j.orphan.witness)
                    if not ok then pending(phase_err); return end
                    ok, phase_err = rename_noreplace(fs, side(j.new), j.orphan.path)
                    if ok then ok, phase_err = observed('after', j.orphan.witness) end
                else phase_err = 'captured orphan or reserved suffix changed' end
            end
        elseif phase == 'document' then
            if j.document_move then
                local from, to = fs.fs_lstat(j.old), fs.fs_lstat(j.new)
                if from then
                    local bytes, read_err, stat = read(fs, j.old)
                    if to or not bytes or hash(bytes) ~= j.old_hash or not same_inode(stat, j.old_witness)
                        or not canonical(fs, j.old) or not canonical(fs, j.new) then
                        pending(read_err or 'captured OLD changed before owned rename'); return
                    end
                    ok, phase_err = authorize(j.parent.before)
                    if not ok then pending(phase_err); return end
                    ok, phase_err = rename_noreplace(fs, j.old, j.new)
                    if not ok then pending(phase_err); return end
                end
                if fs.fs_lstat(j.old) or not same_inode(fs.fs_lstat(j.new), j.old_witness) then
                    pending('owned document rename has no matching inode witness'); return
                end
            end
            local bytes, read_err, stat = read(fs, j.new)
            if not bytes or hash(bytes) ~= j.parent.before then pending(read_err or 'NEW changed before migration'); return end
            local current = witness(stat); current.hash = hash(bytes)
            ok, phase_err = checkpoint({ kind = 'observed', phase = phase, proof = 'after', witness = j.parent.before },
                function() j.new_witness = current end)
            if ok then
                local named, name_err = notify_document()
                if not named then pending(name_err); return end
            end
        elseif phase == 'side' then
            local source, target = side(j.old), side(j.new)
            if not j.side_witness then
                if fs.fs_lstat(target) then pending('unexpected destination side directory'); return end
                ok, phase_err = observed('after', false)
            else
                local from, to = fs.fs_lstat(source), fs.fs_lstat(target)
                if source ~= target and not (not from and same_inode(to, j.side_witness)) then
                    if to or not same_inode(from, j.side_witness) then pending('side rename cannot be proven'); return end
                    local unchanged, tree_err = verify_tree(operation, source, false)
                    if not unchanged then pending(tree_err); return end
                    ok, phase_err = authorize(j.side_witness)
                    if not ok then pending(phase_err); return end
                    ok, phase_err = rename_noreplace(fs, source, target)
                    if not ok then pending(phase_err); return end
                elseif not same_inode(to, j.side_witness) then pending('shared side directory changed'); return end
                local unchanged, tree_err = verify_tree(operation, target, true)
                if not unchanged then pending(tree_err); return end
                ok, phase_err = observed('after', j.side_witness)
            end
        elseif phase == 'children' then
            local complete = {}; for _, id in ipairs(j.state.completed) do complete[id] = true end
            local next_child
            for _, child in ipairs(j.state.children) do if not complete[child.id] then next_child = child; break end end
            if not next_child then ok, phase_err = observed('after', false)
            else
                local path = side(j.new) .. '/' .. next_child.id
                local bytes, read_err = read(fs, path)
                if not bytes then pending(read_err); return end
                if hash(bytes) ~= next_child.after then
                    if hash(bytes) ~= next_child.before then pending('backlink changed before rewrite'); return end
                    local after, rewrite_err = projection.rewrite_parent(bytes,
                        { old = side(j.old) .. '/' .. next_child.id, new = path }, { old = j.old, new = j.new })
                    if not after or hash(after) ~= next_child.after then pending(rewrite_err or 'backlink projection changed'); return end
                    ok, phase_err = authorize(next_child.before, next_child.id)
                    if not ok then pending(phase_err); return end
                    ok, phase_err = helper.write_file_atomic(after, path,
                        writer(operation, new_temp(path, j.token), false, next_child.before))
                    if not ok then pending(phase_err); return end
                end
                ok, phase_err = observed('after', next_child.after, next_child.id)
            end
        elseif phase == 'parent' then
            local bytes, read_err, stat = read(fs, j.new)
            if not bytes then pending(read_err); return end
            if (hash(bytes) ~= j.parent.after or j.parent.before == j.parent.after)
                and not same_file(stat, j.new_witness) then pending('current parent inode changed before rewrite'); return end
            if hash(bytes) ~= j.parent.after then
                if hash(bytes) ~= j.parent.before then pending('parent changed before rewrite'); return end
                local after, rewrite_err = projection.rewrite_side_references(bytes, j.old, j.new)
                if not after or hash(after) ~= j.parent.after then pending(rewrite_err or 'parent projection changed'); return end
                ok, phase_err = authorize(j.parent.before)
                if not ok then pending(phase_err); return end
                ok, phase_err = helper.write_file_atomic(after, j.new,
                    writer(operation, new_temp(j.new, j.token), false, j.parent.before))
                if not ok then pending(phase_err); return end
                bytes, read_err, stat = read(fs, j.new)
                if not bytes or hash(bytes) ~= j.parent.after then pending(read_err or 'parent publication changed'); return end
            end
            local current = witness(stat); current.hash = hash(bytes)
            ok, phase_err = checkpoint({ kind = 'observed', phase = phase, proof = 'after', witness = j.parent.after },
                function() j.new_witness = current end)
        elseif phase == 'editor' then
            local bytes, read_err = document_bytes()
            if not bytes then pending(read_err); return end
            local named, name_err = notify_document()
            if not named then pending(name_err); return end
            ok, phase_err = authorize(j.state.document_witness)
            if not ok then pending(phase_err); return end
            local synced, protection = hook(operation, 'parent_rewritten', { path = j.new, before_hash = j.parent.before,
                after_hash = j.parent.after, current_hash = hash(bytes), document_generation = j.state.document_generation,
                recovering = operation.recovering == true, before_editor_hash = j.parent.editor_before_hash })
            if not synced then pending(protection or 'editor synchronization is pending'); return end
            local current, current_err = document_bytes()
            if not current then pending(current_err); return end
            if protection ~= nil and (type(protection) ~= 'table' or protection.old_lock ~= j.protection.old_lock
                or protection.new_lock ~= j.protection.new_lock
                or protection.baseline ~= nil and type(protection.baseline) ~= 'string') then
                pending('invalid editor protection acknowledgement'); return
            end
            ok, phase_err = checkpoint({ kind = 'editor_synced', document_generation = j.state.document_generation }, function()
                if protection then j.protection = vim.deepcopy(protection) end
            end)
            if ok and protection then operation.baseline = protection.baseline end
        elseif phase == 'metadata' then
            local bytes, read_err = document_bytes()
            if not bytes then pending(read_err); return end
            ok, phase_err = authorize(j.state.document_witness)
            if not ok then pending(phase_err); return end
            local consumed = false
            local function done(result)
                if consumed or operation.released then return end
                consumed = true
                j = operation.journal
                local reg = type(result) == 'table' and result.registration
                if type(result) ~= 'table' or result.kind ~= 'registered' or type(reg) ~= 'table'
                    or reg.ID ~= j.id or reg.File ~= j.new or type(reg.Owner) ~= 'string' or reg.Owner == '' then
                    pending(type(result) == 'table' and result.error or 'metadata confirmation is uncertain'); return
                end
                local saved, save_err = checkpoint({ kind = 'metadata_reply', ok = true, id = reg.ID, new = reg.File }, function()
                    j.confirmation = { kind = 'registered', registration = vim.deepcopy(reg), changed = result.changed == true }
                end)
                if not saved then pending(save_err); return end
                operation.running = false
                operation.metadata_result = result
                dispatch(operation, callback)
            end
            if operation.options.metadata then
                local called, request_err = pcall(operation.options.metadata, operation, done)
                if not called and not consumed then consumed = true; pending(request_err) end
            else
                local registry = operation.options.registry or require('parley.document_registry')
                operation.request = registry.request('rename', { j.old, j.new }, { id = j.id, old = j.old, new = j.new },
                    done, operation.options.registry_options)
            end
            return
        elseif phase == 'complete' then
            ok, phase_err = authorize(j.state.document_witness)
            if not ok then pending(phase_err); return end
            local current, current_err = document_bytes()
            if not current then pending(current_err); return end
            local result = operation.metadata_result or vim.deepcopy(j.confirmation)
            local finished, finish_err = hook(operation, 'finish', result)
            if not finished then pending(finish_err or 'local handoff is pending'); return end
            local removed, remove_err = fs.fs_unlink(operation.journal_path)
            if not removed then pending(remove_err); return end
            result.orphan_destination = operation.orphan_destination
            local retired = assert(model.step(j.state, { kind = 'cleanup_done', op_id = j.state.op_id, generation = j.state.generation }))
            j.state = retired
            operation.running = false; operation.release(); callback(result); return
        else pending('invalid migration phase'); return end
        if not ok then pending(phase_err or 'migration proof unavailable'); return end
    end
    pending('migration transition limit exceeded')
end

function M.document_ready(operation)
    local journal = operation and operation.journal
    if not journal then return false end
    if journal.version == 1 then return journal.steps.document_moved == true end
    return journal.state.phase == 'metadata' or journal.state.phase == 'complete' or journal.state.phase == 'retired'
end
function M.record_write(operation)
    if operation and operation.journal.version == 2 then return dispatch(operation, nil, true) end
    return record_write_v1(operation)
end
function M.advance(operation, callback)
    if operation.journal.version == 2 then return dispatch(operation, callback) end
    return advance_v1(operation, callback)
end

-- Observation only: listings do not authorize recovery or acquire leases. A
-- caller must acquire again through recover before interpreting any progress.
function M.pending(namespace, options)
    options = options or {}
    if type(namespace) ~= 'string' or namespace == '' then return failure('pending', 'invalid namespace') end
    local fs, root = options.fs or options.adapter or uv, root_of(options)
    if type(root) ~= 'string' or root == '' then return failure('pending', 'state directory is missing') end
    local directory = paths(root, namespace, '')
    local info, stat_err, stat_code = fs.fs_lstat(directory)
    if not info then
        if stat_code == 'ENOENT' then return {} end
        return failure('pending', stat_err or 'cannot inspect migration journals')
    end
    if info.type ~= 'directory' then return failure('pending', 'invalid migration journal directory') end
    local scan, scan_err = fs.fs_scandir(directory)
    if not scan then return failure('pending', scan_err) end
    local summaries = {}
    while true do
        local name = fs.fs_scandir_next(scan)
        if not name then break end
        if name:match('%.json$') then
            if #summaries >= MAX_PENDING then return failure('limit', 'pending journal limit exceeded (32)') end
            local path = directory .. '/' .. name
            local journal, err = load(fs, path, namespace)
            if not journal then return failure('pending', err) end
            summaries[#summaries + 1] = {
                id = journal.id, old = journal.old, new = journal.new, version = journal.version,
                registration = vim.deepcopy(journal.registration), protection = vim.deepcopy(journal.protection),
                new_witness = vim.deepcopy(journal.new_witness), document_move = journal.document_move == true, journal_path = path,
            }
        end
    end
    table.sort(summaries, function(a, b) return a.id < b.id end)
    return summaries
end

function M.recover(namespace, id, options, callback)
    options = options or {}
    if type(namespace) ~= 'string' or namespace == '' or type(id) ~= 'string' or id == '' then return failure('pending', 'invalid recovery identity') end
    local fs, root = options.fs or options.adapter or uv, root_of(options)
    local lease, lease_err = acquire(namespace, id, root, options)
    if not lease then return nil, lease_err end
    local _, path = paths(root, namespace, id)
    local journal, err, disk_hash = load(fs, path, namespace, id)
    if not journal then lease.release(); return failure('pending', err) end
    if options.old_path and options.old_path ~= journal.old or options.new_path and options.new_path ~= journal.new then
        lease.release(); return failure('pending', 'recovery tuple mismatch')
    end
    if not canonical(fs, journal.old) or not canonical(fs, journal.new) then lease.release(); return failure('pending', 'recovery paths changed') end
    local operation = operation_for(namespace, journal, path, lease, options)
    operation.disk_hash = disk_hash
    operation.recovering = true
    operation.orphan_destination = journal.orphan and journal.orphan.path or nil
    if not journal.document_move and not journal.new_witness and (options.new_written ~= true
        or options.old_path ~= journal.old or options.new_path ~= journal.new) then
        operation.release(); return failure('pending', 'successful NEW write and exact tuple have not been witnessed')
    end
    local clean, clean_err = cleanup(operation)
    if not clean then operation.release(); return failure('pending', clean_err) end
    M.advance(operation, callback)
    return operation
end

return M
