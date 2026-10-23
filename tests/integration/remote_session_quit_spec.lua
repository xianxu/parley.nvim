local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')
local Embedded = require('tests.helpers.embedded_nvim')

describe('private editor endpoint native quit', function()
    local root, child
    before_each(function()
        local base = uv.fs_stat('/Volumes/TestScratch') and '/Volumes/TestScratch' or (vim.env.TMPDIR or uv.os_tmpdir())
        root = assert(uv.fs_mkdtemp(base .. '/rq-XXXXXX'))
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        child = Embedded.start()
    end)
    after_each(function()
        if child then child:stop() end
        if root then vim.fn.delete(root, 'rf') end
    end)

    local function open(tracked)
        local file = root .. '/question.md'
        local lines = { '# Headerless Markdown', 'local document contents' }
        vim.fn.writefile(lines, file)
        local paths = vim.empty_dict()
        if tracked then
            paths[file] = { ID = string.rep('a', 32), Namespace = root, File = file,
                Owner = 'ops:0', RegisteredOwner = 'ops:0', RegisteredAt = '2026-10-22T00:00:00Z' }
        end
        vim.fn.writefile({ vim.json.encode({ paths = paths, moves = vim.empty_dict() }) }, root .. '/registry.json')
        local observed = child:exec([[
            local root, file, tracked, arrival_ms = ...
            vim.env.PATH = root .. '/bin:' .. vim.env.PATH
            vim.env.FAKE_COUCH_REGISTRY = root .. '/registry.json'
            vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_EDITOR_MODE = nil, nil
            vim.env.COUCH_ISOLATED_ROOT, vim.env.COUCH_STORE_DIR = root, nil
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            local source = require('tests.helpers.fake_process_source').new({
                [(vim.uv or vim.loop).os_getpid()] = { started = 'Thu Oct 22 05:00:00 2026' },
            })
            local runtime = require('parley.remote_runtime')
            local acquire = runtime.acquire
            runtime.acquire = function(options, callback)
                return acquire(vim.tbl_extend('force', {}, options, { parent = root .. '/runtime', source = source }), callback)
            end
            -- Observe completion while retaining the real subprocess and reply.
            local registry = require('parley.document_registry')
            local request = registry.request
            local lookup_completed
            registry.request = function(operation, args, witness, callback, options)
                return request(operation, args, witness, function(result)
                    callback(result)
                    if operation == 'lookup' and args[1] == file then lookup_completed = result.kind end
                end, options)
            end
            local parley = require('parley')
            parley.setup({})
            parley.config.state_dir = root .. '/state'
            vim.cmd('edit ' .. vim.fn.fnameescape(file))
            local buf = vim.api.nvim_get_current_buf()
            local remote = require('parley.remote_session')
            local complete = vim.wait(arrival_ms, function()
                local state = remote.snapshot(buf)
                return tracked and state and state.phase == 'active' or not tracked and lookup_completed == 'absent'
            end, 10)
            assert(complete, 'setup-driven document discovery did not complete')
            return { state = remote.snapshot(buf), modified = vim.bo[buf].modified,
                identity = require('parley.session_sync').identity(buf),
                has_exit_hook = #vim.api.nvim_get_autocmds({ group = 'ParleyLeave', event = 'VimLeavePre' }) == 1 }
        ]], root, file, tracked, arrival.MS)
        assert.is_true(observed.has_exit_hook)
        assert.is_false(observed.modified)
        assert.is_nil(observed.identity, 'outside-Couch discovery must not adopt a submit turn')
        return observed, file, lines
    end

    local function quit()
        child:exec([[vim.defer_fn(function() vim.cmd('qa!') end, 10)]])
        assert.same({ 0 }, vim.fn.jobwait({ child.channel }, arrival.MS), 'native setup quit did not exit cleanly')
    end
    local function launches()
        local path = root .. '/registry.json.editor-launches'
        return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
    end
    local function current()
        local state = vim.json.decode(table.concat(vim.fn.readfile(root .. '/registry.json'), '\n'))
        return state.editor_endpoints and state.editor_endpoints.current or {}
    end

    it('runs the actual setup exit hook once, unregisters its binding and retires its real socket', function()
        local observed, file, lines = open(true)
        assert.equals('active', observed.state.phase)
        local socket = observed.state.context.Socket
        assert.equals('socket', assert(uv.fs_lstat(socket)).type)
        assert.is_not_nil(next(current()), 'fixture did not publish a binding before quit')
        quit()
        assert.is_nil(next(current()), 'setup VimLeavePre left a current editor binding')
        assert.same({ 'register', 'unregister' }, launches(), 'quit must issue one unregister CLI batch')
        assert.is_nil(uv.fs_lstat(socket), 'quit left its listener socket')
        assert.same(lines, vim.fn.readfile(file))
        assert.is_nil(uv.fs_stat(root .. '/sent'))
    end)

    it('keeps ordinary Markdown local through setup and quit without endpoint IO', function()
        local observed, file, lines = open(false)
        assert.is_nil(observed.state)
        assert.is_nil(uv.fs_lstat(root .. '/runtime'))
        quit()
        assert.same({}, launches())
        assert.is_nil(next(current()))
        assert.is_nil(uv.fs_lstat(root .. '/runtime'))
        assert.same(lines, vim.fn.readfile(file))
        assert.is_nil(uv.fs_stat(root .. '/sent'))
    end)

    it('withdraws the native endpoint witness as soon as final quit unload begins', function()
        local observed = open(true)
        local trace = root .. '/quit-unload.json'
        child:exec([[
            local context, trace = ...
            local query = { Namespace = context.Namespace, DocumentID = context.DocumentID,
                EditorIncarnation = context.EditorIncarnation, AttachID = context.AttachID, Buffer = context.Buffer }
            vim.api.nvim_create_autocmd('BufUnload', { buffer = context.Buffer, callback = function()
                local remote = require('parley.remote_session')
                local endpoint = remote.endpoint(query)
                local admission
                remote.attach(context.Buffer, { Namespace = context.Namespace, ID = context.DocumentID, File = context.File },
                    function(result) admission = result.kind end)
                vim.fn.writefile({ vim.json.encode({ exiting = vim.v.exiting,
                    endpoint = endpoint or vim.NIL, admission = admission }) }, trace)
            end })
        ]], observed.state.context, trace)
        quit()
        local actual = vim.json.decode(table.concat(vim.fn.readfile(trace), '\n'))
        assert.equals(0, actual.exiting)
        assert.equals(vim.NIL, actual.endpoint, 'a quitting, unloaded buffer still served a publication witness')
        assert.equals('unavailable', actual.admission)
        assert.is_nil(next(current()))
        assert.same({ 'register', 'unregister' }, launches())
    end)
end)
