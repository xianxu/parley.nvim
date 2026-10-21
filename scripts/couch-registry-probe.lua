-- luacheck: globals vim
-- Maintainer-only offline probe. The Python driver supplies fresh owned roots;
-- every registry call goes through production request -> couch.run -> vim.system.
vim.opt.runtimepath:append(assert(vim.env.PARLEY_CONFORMANCE_ROOT))
local registry = require('parley.document_registry')
local config = vim.json.decode(table.concat(vim.fn.readfile(assert(vim.env.PARLEY_REGISTRY_PROBE)), '\n'))
local uv = vim.uv or vim.loop
local function check(condition, message)
    if not condition then error('registry conformance: ' .. message, 0) end
end
local function request(operation, args, mode)
    local done, result = false, nil
    local env = vim.deepcopy(config.env)
    if mode then env.FAKE_COUCH_REGISTRY_MODE = mode end
    registry.request(operation, args, { probe = true }, function(reply)
        result, done = reply, true
    end, { binary = config.binary, env = env, timeout_ms = 2500 })
    check(vim.wait(5000, function() return done end, 10), operation .. ' timed out')
    return result
end
local function registered(reply, path, id, changed)
    check(reply.kind == 'registered', path .. ': expected registered, got ' .. vim.inspect(reply))
    check(reply.registration.File == path, 'canonical path mismatch')
    check(reply.registration.Owner == 'pair:5', 'effective owner mismatch')
    check(reply.registration.RegisteredOwner == 'pair:5', 'registered owner mismatch')
    if id then check(reply.registration.ID == id, 'stable ID changed') end
    if changed ~= nil then check(reply.changed == changed, 'mutation Changed mismatch') end
    return reply.registration.ID
end
local function write(path, text)
    local file = assert(io.open(path, 'wb'))
    assert(file:write(text)); assert(file:close())
end
local function run(argv)
    local result = vim.system(argv, { env = config.env, text = true, clear_env = true }):wait()
    return result
end
-- #408: actual synchronous production admission, with no supervisor running.
-- A retry must retain the exact proof; a foreign token cannot release it.
local function operator_case(path)
    local couch = require('parley.couch')
    local id = registered(request('lookup', { path }), path)
    local identity, token = { ID = id, File = path }, string.rep('a', 32)
    local function operation(verb, turn)
        return couch.operator_lock(verb, identity, turn or token)
    end
    local acquired = operation('acquire')
    check(acquired.kind == 'confirmed', 'operator acquire: ' .. vim.inspect(acquired))
    check(acquired.lock.State == 'acquired', 'initial acquire state')
    local proof = acquired.lock.LockText
    check(proof == table.concat(vim.fn.readfile(path .. '.lock'), '\n') .. '\n', 'published proof differs')
    local retry = operation('acquire')
    check(retry.kind == 'confirmed' and retry.lock.State == 'already-held'
        and retry.lock.LockText == proof, 'same-token retry changed proof')
    check(operation('release', string.rep('b', 32)).kind == 'refused', 'foreign release admitted')
    check(table.concat(vim.fn.readfile(path .. '.lock'), '\n') .. '\n' == proof, 'foreign release mutated proof')
    local released = operation('release')
    check(released.kind == 'confirmed' and released.lock.State == 'released', 'owned release failed')
    check(vim.fn.filereadable(path .. '.lock') == 0, 'released sidecar survived')
    local absent = operation('release')
    check(absent.kind == 'confirmed' and absent.lock.State == 'already-released', 'absent release failed')
end
-- What the supervisor's message service writes in a live store, done here by
-- hand in the isolated one: the marker that it records deliveries, and one
-- delivered `submitted: PATH` row for `slot`, stamped as Couch stamps it
-- (RFC3339Nano with the local offset), `ahead` seconds from now.
local function recording()
    local dir = config.env.COUCH_STORE_DIR .. '/session-sync'
    vim.fn.mkdir(dir, 'p')
    write(dir .. '/recording.json', vim.json.encode({ PID = 1, Started = os.date('!%Y-%m-%dT%H:%M:%SZ') }))
end
local function delivered(slot, path, ahead)
    local t = os.time() + ahead
    local offset = os.date('%z', t):gsub('^([+-]%d%d)(%d%d)$', '%1:%2')
    local row = vim.json.encode({ ID = 'conformance-1', From = 'parley.nvim:1',
        At = os.date('%Y-%m-%dT%H:%M:%S', t) .. '.123456789' .. offset, Head = 'submitted: ' .. path })
    local file = assert(io.open(config.env.COUCH_STORE_DIR .. '/session-sync/' .. slot:gsub(':', '%%3A') .. '.jsonl', 'ab'))
    assert(file:write(row .. '\n')); assert(file:close())
end
-- #383: `round PATH --json` through the production request, real and fake
-- alike: absent before any agent write; after one, a round whose spans and
-- result_hash (parley's hash of the file's lines) are what the write did; after
-- a later submit, cleared.
local function round_case(path)
    if not config.fake then
        local refused = request('round', { path })
        check(refused.kind == 'unavailable' and refused.code == 'not-recording',
            'a store that records nothing must refuse, got ' .. vim.inspect(refused))
        recording()
    end
    check(request('round', { path }).kind == 'absent', 'no write yet must mean no round')
    write(path, '# Round\nold line\n')
    if config.fake then
        local seeded = vim.json.encode({ base_hash = 'x', result_hash = vim.fn.sha256('# Round\nnew line\n'):sub(1, 16),
            at = os.date('!%Y-%m-%dT%H:%M:%SZ'), presentation = 'highlight',
            spans = { { start = { 1, 0 }, ['end'] = { 1, 3 }, old = 'old', new = 'new' } } })
        write(path, '# Round\nnew line\n')
        check(run({ config.binary, '--round', path, seeded }).code == 0, 'fake round seed failed')
    else
        local read = run({ config.binary, '--session-sync', 'read', '--all', path, '--json' })
        local hash = vim.json.decode(read.stdout).Read.Hash
        local body = config.root .. '/round-body.md'
        write(body, '# Round\nnew line\n')
        local wrote = run({ config.binary, '--session-sync', 'write', '--all', body, path, '--if-hash', hash })
        check(wrote.code == 0, 'real write --all failed: ' .. wrote.stdout .. wrote.stderr)
    end
    local reply = request('round', { path })
    check(reply.kind == 'round' and not reply.cleared, 'a write must leave an uncleared round, got ' .. vim.inspect(reply))
    local span = reply.round.spans[1]
    check(#reply.round.spans == 1 and span.old == 'old' and span.new == 'new', 'span text mismatch')
    check(vim.deep_equal(span.start, { 1, 0 }) and vim.deep_equal(span['end'], { 1, 3 }), 'span position mismatch')
    local lines = vim.fn.readfile(path)
    check(reply.round.result_hash == vim.fn.sha256(table.concat(lines, '\n') .. '\n'):sub(1, 16),
        "result_hash must be parley's hash of the file's lines")
    if config.fake then
        check(run({ config.binary, '--owe', 'conformance-1', 'submitted: ' .. path }).code == 0, 'fake owe failed')
    else
        delivered('pair:5', path, 2)
    end
    reply = request('round', { path })
    check(reply.kind == 'round' and reply.cleared, 'a later submit must clear the round, got ' .. vim.inspect(reply))
end
local function main()
    local old, new, target = config.root .. '/note.md', config.root .. '/moved.md', config.root .. '/target.md'
    write(old, '# Isolated registry conformance\n')
    local id = registered(request('register', { old, 'pair:5' }), old, nil, true)
    registered(request('lookup', { old }), old, id)
    registered(request('register', { old, 'pair:5' }), old, id, false)
    check(uv.fs_rename(old, new), 'test-owned filesystem rename failed')
    registered(request('rename', { old, new }), new, id, true)
    check(request('lookup', { old }).kind == 'absent', 'OLD must be positively absent after rename')
    registered(request('lookup', { new }), new, id)
    registered(request('rename', { old, new }), new, id, false)
    check(request('register', { new, 'pair:6' }).kind == 'unavailable', 'owner conflict must refuse')
    registered(request('lookup', { new }), new, id)
    write(target, '# Occupied target\n')
    local target_id = registered(request('register', { target, 'pair:5' }), target, nil, true)
    check(target_id ~= id, 'distinct registrations reused ID')
    check(request('rename', { new, target }).kind == 'unavailable', 'registered target must refuse')
    registered(request('lookup', { new }), new, id)
    registered(request('lookup', { target }), target, target_id)
    check(request('lookup', { config.root .. '/never.md' }).kind == 'absent', 'null lookup must mean absent')
    operator_case(new)
    round_case(target)
    if config.fake then
        for _, mode in ipairs({ 'missing', 'malformed', 'unsupported', 'wrong-path' }) do
            check(request('lookup', { new }, mode).kind == 'unavailable', mode .. ' must retain uncertainty')
        end
    end
    print('PASS: production registry register/lookup/repeat/fs-rename/metadata-rename/replay/conflicts/null/round/operator-acquire/retry/refusal/release'
        .. (config.fake and '/malformed/unsupported' or ''))
end
local ok, err = pcall(main)
registry.shutdown()
if not ok then
    io.stderr:write(tostring(err) .. '\n')
    vim.cmd('cquit 1')
else
    vim.cmd('qa!')
end
