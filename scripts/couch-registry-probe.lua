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
    if config.fake then
        for _, mode in ipairs({ 'missing', 'malformed', 'unsupported', 'wrong-path' }) do
            check(request('lookup', { new }, mode).kind == 'unavailable', mode .. ' must retain uncertainty')
        end
    end
    print('PASS: production registry register/lookup/repeat/fs-rename/metadata-rename/replay/conflicts/null'
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
