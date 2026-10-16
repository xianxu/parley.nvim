-- Forward-only migration IO. Every effect is protected by the document lease;
-- recovery accepts only the recorded tuple and exact before/after witnesses.
local M = {}
local uv = vim.uv or vim.loop
local leases = require('parley.document_lease')
local projection = require('parley.document_move_plan')
local helper = require('parley.helper')
local MAX_JOURNAL, MAX_PENDING = 256 * 1024, 32
local MAX_FILE = 4 * 1024 * 1024

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
local function validate(journal, namespace, id, path)
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
        or (journal.old_witness ~= false and not valid_witness(journal.old_witness, 'file'))
        or (journal.side_witness ~= false and not valid_witness(journal.side_witness, 'directory'))
        or (journal.new_witness ~= false and (not valid_witness(journal.new_witness, 'file')
            or not valid_digest(journal.new_witness.hash)))
        or (journal.old_witness and not valid_digest(journal.old_hash)) then return nil, 'invalid migration journal schema' end
    if journal.document_move then
        if not journal.old_witness then return nil, 'owned migration requires an OLD witness' end
        if journal.steps.document_moved then
            if not journal.new_witness or journal.new_witness.hash ~= journal.old_hash
                or not same_inode(journal.new_witness, journal.old_witness) then return nil, 'invalid owned document checkpoint' end
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
    for _, temporary in ipairs(operation.journal.temps) do
        local stat = operation.fs.fs_lstat(temporary)
        if stat then
            if stat.type ~= 'file' then return nil, 'unexpected temporary type' end
            local removed, err = operation.fs.fs_unlink(temporary)
            if not removed then return nil, err end
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
    if options.destination_registered ~= false then return refuse('unavailable', 'destination registration must be confirmed absent') end
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
    local projected, project_err = projection.project(old, new_path, {
        id = registration.ID, old_exists = old_stat ~= nil, new_exists = new_stat ~= nil, new_written = false,
        destination_registered = false, side_exists = source_stat ~= nil, target_side_exists = target_stat ~= nil, entries = entries,
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
    local operation = operation_for(namespace, journal, path, lease, options)
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
    elseif not same_inode(to, journal.old_witness) then
        return nil, 'owned document rename has no matching inode witness'
    end
    -- A crash may have published the rename before the journal checkpoint. Only
    -- OLD absence plus the original inode AND bytes proves that exact effect.
    local bytes, err, opened = read(fs, journal.new)
    if fs.fs_lstat(journal.old) or not bytes or hash(bytes) ~= journal.old_hash
        or not same_inode(opened, journal.old_witness) then
        return nil, err or 'owned document rename result is uncertain'
    end
    journal.new_witness = witness(opened)
    journal.new_witness.hash = hash(bytes)
    journal.steps.document_moved = true
    local saved, save_err = persist(operation)
    if not saved then return nil, save_err end
    if not operation.document_notified then
        local named, name_err = hook(operation, 'document_moved')
        if not named then return nil, name_err or 'owned buffer name handoff is pending' end
        operation.document_notified = true
    end
    return true
end

function M.advance(operation, callback)
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
                id = journal.id, old = journal.old, new = journal.new,
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
