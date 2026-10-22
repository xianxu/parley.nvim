local uv = vim.uv or vim.loop
local arrival = require('tests.helpers.arrival')
local runtime

describe('private editor RPC runtime ownership', function()
    local root, source, resources, children, saved_io
    local function await_start(options)
        local result
        options = options or {}
        options.parent = options.parent or root .. '/runtime'
        options.incarnation = options.incarnation or string.rep('a', 32)
        if options.source == false then options.source=nil else options.source=options.source or source end
        runtime.acquire(options, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        if result.kind == 'ready' then resources[#resources + 1] = result.runtime end
        return result
    end
    local function listen(resource, name)
        local result
        resource.listen(name, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result
    end
    local function close(resource)
        local done
        resource.close(function() done = true end)
        assert.is_true(vim.wait(arrival.MS, function() return done end, 10))
    end

    before_each(function()
        local scratch_base=uv.fs_stat('/Volumes/TestScratch') and '/Volumes/TestScratch' or (vim.env.TMPDIR or uv.os_tmpdir())
        root = assert(uv.fs_mkdtemp(scratch_base .. '/rr-XXXXXX'))
        resources, children = {}, {}
        saved_io={fsync=uv.fs_fsync,rename=uv.fs_rename,open=uv.fs_open,mkdtemp=uv.fs_mkdtemp,lstat=uv.fs_lstat,serverstart=vim.fn.serverstart}
        source = require('tests.helpers.fake_process_source').new({
            [uv.os_getpid()] = { started = 'Thu Oct 22 05:00:00 2026' },
        })
        local ok, module = pcall(require, 'parley.remote_runtime')
        runtime = ok and module or { acquire = function()
            assert.is_true(false, 'private RPC runtime module is missing')
        end }
    end)
    after_each(function()
        uv.fs_fsync,uv.fs_rename,uv.fs_open,uv.fs_mkdtemp,uv.fs_lstat,vim.fn.serverstart=saved_io.fsync,saved_io.rename,saved_io.open,saved_io.mkdtemp,saved_io.lstat,saved_io.serverstart
        for _, child in ipairs(children) do child:stop() end
        for _, resource in ipairs(resources) do close(resource) end
        vim.fn.delete(root, 'rf')
    end)

    it('creates physical private runtime directories and real per-file sockets', function()
        local acquired = await_start()
        assert.equals('ready', acquired.kind, vim.inspect(acquired))
        local resource = acquired.runtime
        assert.equals(16832, uv.fs_lstat(resource.directory).mode)
        assert.equals(uv.os_get_passwd().uid, uv.fs_lstat(resource.directory).uid)
        local first, second = listen(resource, 's1'), listen(resource, 's2')
        assert.equals('listening', first.kind,vim.inspect(first))
        assert.equals('listening', second.kind)
        assert.is_not.equals(first.path, second.path)
        assert.equals('socket', uv.fs_lstat(first.path).type)
        local channel = vim.fn.sockconnect('pipe', first.path, { rpc = true })
        assert.is_true(channel > 0); vim.fn.chanclose(channel)
        close(resource)
        assert.is_nil(uv.fs_lstat(first.path))
        assert.is_nil(uv.fs_lstat(resource.directory))
    end)

    it('does not stop a pre-existing Neovim server', function()
        local foreign = vim.fn.serverstart(root .. '/other.sock')
        local resource = assert(await_start().runtime)
        assert.equals('listening', listen(resource, 's1').kind)
        close(resource)
        assert.is_true(vim.tbl_contains(vim.fn.serverlist(), foreign))
        vim.fn.serverstop(foreign)
    end)

    it('refuses unsafe listener names and duplicate addresses', function()
        local resource = assert(await_start().runtime)
        for _, name in ipairs({ '../outside', '/absolute', 's1/child', '' }) do
            assert.equals('unavailable', listen(resource, name).kind)
        end
        assert.equals('listening', listen(resource, 's1').kind)
        assert.equals('unavailable', listen(resource, 's1').kind)
        assert.is_nil(uv.fs_stat(root .. '/outside'))
    end)

    it('refuses symlinked or public runtime parents', function()
        assert(uv.fs_mkdir(root .. '/public', 493))
        assert.equals('unavailable', await_start({ parent = root .. '/public' }).kind)
        assert(uv.fs_symlink(root .. '/public', root .. '/alias'))
        assert.equals('unavailable', await_start({ parent = root .. '/alias' }).kind)
    end)

    it('bounds process-directory admission without deleting unknown residue', function()
        local parent = root .. '/runtime'; assert(uv.fs_mkdir(parent, 448))
        for index = 1, 256 do assert(uv.fs_mkdir(parent .. '/e-' .. index, 448)) end
        local result = await_start()
        assert.equals('unavailable', result.kind)
        assert.matches('256', result.error)
        for index = 1, 256 do assert.is_not_nil(uv.fs_lstat(parent .. '/e-' .. index)) end
    end)

    it('does not allocate when native inspection is unknown', function()
        source.set(uv.os_getpid(), { kind = 'unknown', reason = 'permission denied' })
        local result = await_start()
        assert.equals('unavailable', result.kind)
        local parent = root .. '/runtime'
        local scan = uv.fs_scandir(parent)
        if scan then
            while true do
                local name = uv.fs_scandir_next(scan); if not name then break end
                assert.is_nil(name:match('^e%-'), name)
            end
        end
    end)

    it('cancels a held startup and releases the allocation lease', function()
        source.hold = true
        local result
        local operation = runtime.acquire({ parent = root .. '/runtime', incarnation = string.rep('a', 32), source = source },
            function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return #source.reads == 1 end, 10))
        operation.cancel()
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        assert.equals('unavailable', result.kind)
        source.hold = false
        assert.equals('ready', await_start().kind)
        source.release(1)
        assert.equals('unavailable', result.kind)
    end)

    local function seed_owner(parent, name, pid, sockets)
        if not uv.fs_lstat(parent) then assert(uv.fs_mkdir(parent,448)) end
        local path = parent .. '/' .. name
        assert(uv.fs_mkdir(path,448))
        local stat = assert(uv.fs_lstat(path))
        local record = {Version=1,EditorIncarnation=string.rep('b',32),PID=pid,
            Started='Thu Oct 22 05:00:00 2026',Directory={Name=name,Device=stat.dev,Inode=stat.ino},Sockets=sockets or {}}
        vim.fn.writefile({assert(require('parley.remote_runtime_record').encode(record))},path..'/owner.json')
        assert(uv.fs_chmod(path..'/owner.json',384))
        return path
    end
    local function start_child(parent)
        local child = require('tests.helpers.embedded_nvim').start({rtp='prepend'})
        children[#children+1] = child
        child:exec([[local parent=...; require('parley.remote_runtime').acquire({parent=parent,incarnation=string.rep('c',32)},
            function(value) _G.runtime_result=value end)]],parent)
        assert(vim.wait(arrival.MS,function() return type(child:exec('return _G.runtime_result and _G.runtime_result.kind'))=='string' end,10))
        return child
    end
    it('durably reserves a socket name before exposing its listener', function()
        local resource=assert(await_start().runtime)
        local result=listen(resource,'s1')
        assert.equals('listening',result.kind)
        local record=assert(require('parley.remote_runtime_record').decode(table.concat(vim.fn.readfile(resource.directory..'/owner.json'),'\n')))
        assert.same('s1',record.Sockets[1].Name)
        assert.same('listening',record.Sockets[1].State)
        assert.equals(uv.fs_lstat(result.path).ino,record.Sockets[1].Inode)
    end)
    it('retains live reused uncertain malformed and unlisted process residue', function()
        local parent=root..'/runtime'
        local live=seed_owner(parent,'e-live',900001)
        local reused=seed_owner(parent,'e-reused',900002)
        local uncertain=seed_owner(parent,'e-unknown',900003)
        local unlisted=seed_owner(parent,'e-unlisted',900004)
        vim.fn.writefile({'foreign'},unlisted..'/foreign')
        local malformed=seed_owner(parent,'e-malformed',900005)
        vim.fn.writefile({'{'},malformed..'/owner.json')
        source.set(900001,{started='Thu Oct 22 05:00:00 2026'})
        source.set(900002,{started='Fri Oct 23 05:00:00 2026'})
        source.set(900003,{kind='unknown',reason='EPERM'})
        assert.equals('ready',await_start().kind)
        for _, path in ipairs({live,reused,uncertain,unlisted,malformed}) do assert.is_not_nil(uv.fs_lstat(path),path) end
    end)
    for _, count in ipairs({8,16}) do
        it('inspects '..count..' distinct process owners in one batch',function()
            local parent=root..'/runtime'
            for index=1,count-1 do seed_owner(parent,'e-'..index,900000+index) end
            assert.equals('ready',await_start().kind)
            assert.equals(1,#source.reads)
            local distinct,total=0,0
            for _, probes in pairs(source.probes) do distinct=distinct+1;total=total+probes end
            assert.equals(count,distinct)
            assert.is_true(total<=3*count)
            for index=1,count-1 do assert.is_nil(uv.fs_lstat(parent..'/e-'..index)) end
        end)
    end
    it('expires a held inspection without allocating or deleting residue',function()
        local parent=root..'/runtime'
        local dead=seed_owner(parent,'e-dead',900001)
        source.hold=true
        local result=await_start({timeout_ms=30})
        assert.equals('unavailable',result.kind)
        assert.is_not_nil(uv.fs_lstat(dead))
        source.hold=false
        assert.equals('ready',await_start().kind)
    end)
    it('keeps long socket addresses unavailable before serverstart',function()
        local parent=root..'/'..string.rep('long',25)
        local resource=assert(await_start({parent=parent}).runtime)
        local before=vim.fn.serverlist()
        assert.equals('unavailable',listen(resource,'s1').kind)
        assert.same(before,vim.fn.serverlist())
    end)
    it('reclaims an exact native crash directory and its listed socket',function()
        local parent=root..'/runtime'
        local child=start_child(parent)
        assert.equals('ready',child:exec('return _G.runtime_result.kind'))
        local directory=child:exec('return _G.runtime_result.runtime.directory')
        child:exec([[ _G.runtime_result.runtime.listen('s1',function(value) _G.socket_result=value end) ]])
        assert(vim.wait(arrival.MS,function() return type(child:exec('return _G.socket_result and _G.socket_result.kind'))=='string' end,10))
        assert.equals('listening',child:exec('return _G.socket_result.kind'),child:exec('return _G.socket_result.error'))
        local socket=child:exec('return _G.socket_result.path')
        assert(uv.kill(child.pid,'sigkill'))
        assert(vim.wait(arrival.MS,function() return vim.fn.jobwait({child.channel},0)[1]~=-1 end,10))
        assert.is_not_nil(uv.fs_lstat(socket))
        local result=await_start({source=false})
        assert.equals('ready',result.kind,vim.inspect(result))
        assert.is_nil(uv.fs_lstat(socket))
        assert.is_nil(uv.fs_lstat(directory))
    end)

    it('retains a marker replaced after its inspection snapshot',function()
        local parent=root..'/runtime'
        local directory=seed_owner(parent,'e-changing',900001)
        source.hold=true
        local result
        runtime.acquire({parent=parent,incarnation=string.rep('a',32),source=source},function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return #source.reads==1 end,10))
        local marker=directory..'/owner.json'
        local record=assert(require('parley.remote_runtime_record').decode(table.concat(vim.fn.readfile(marker),'\n')))
        record.Future='new ownership witness'
        vim.fn.writefile({assert(require('parley.remote_runtime_record').encode(record))},marker)
        source.release()
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('ready',result.kind,vim.inspect(result));resources[#resources+1]=result.runtime
        assert.is_not_nil(uv.fs_lstat(directory))
        assert.matches('new ownership witness',table.concat(vim.fn.readfile(marker),'\n'))
    end)
    local function held_child(parent)
        local child=require('tests.helpers.embedded_nvim').start({rtp='prepend'})
        children[#children+1]=child
        child:exec([[local parent=...;local uv=vim.uv or vim.loop
            _G.held_source=require('tests.helpers.fake_process_source').new({[uv.os_getpid()]={started='Thu Oct 22 05:00:00 2026'}})
            _G.held_source.hold=true
            require('parley.remote_runtime').acquire({parent=parent,incarnation=string.rep('d',32),source=_G.held_source,timeout_ms=10000},
                function(value) _G.runtime_result=value end)]],parent)
        assert(vim.wait(arrival.MS,function() return child:exec('return #_G.held_source.reads')==1 end,10))
        return child
    end
    local function fill_cap_minus_one(parent)
        assert(uv.fs_mkdir(parent,448))
        for index=1,255 do assert(uv.fs_mkdir(parent..'/e-'..index,448)) end
    end
    it('serializes two editors at capacity minus one across a held inspection',function()
        local parent=root..'/runtime';fill_cap_minus_one(parent)
        local first=held_child(parent)
        local second=start_child(parent)
        assert.equals('unavailable',second:exec('return _G.runtime_result.kind'))
        first:exec('_G.held_source.release(1)')
        assert(vim.wait(arrival.MS,function() return type(first:exec('return _G.runtime_result and _G.runtime_result.kind'))=='string' end,10))
        assert.equals('ready',first:exec('return _G.runtime_result.kind'))
        local scan=assert(uv.fs_scandir(parent));local count=0
        while true do local name=uv.fs_scandir_next(scan);if not name then break end;if name:match('^e%-') then count=count+1 end end
        assert.equals(256,count)
    end)
    it('releases the kernel allocation lease when its holding editor is killed',function()
        local parent=root..'/runtime';fill_cap_minus_one(parent)
        local child=held_child(parent)
        assert(uv.kill(child.pid,'sigkill'))
        assert(vim.wait(arrival.MS,function() return vim.fn.jobwait({child.channel},0)[1]~=-1 end,10))
        local result=await_start()
        assert.equals('ready',result.kind,vim.inspect(result))
    end)

    it('stops one exact owned listener while preserving the other attachment',function()
        local resource=assert(await_start().runtime)
        local first,second=listen(resource,'s1'),listen(resource,'s2')
        assert.equals('function',type(resource.stop))
        local result
        resource.stop('s1',function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('closed',result.kind,vim.inspect(result))
        assert.is_nil(uv.fs_lstat(first.path))
        assert.is_true(vim.tbl_contains(vim.fn.serverlist(),second.path))
        local marker=assert(require('parley.remote_runtime_record').decode(table.concat(vim.fn.readfile(resource.directory..'/owner.json'),'\n')))
        assert.equals(1,#marker.Sockets);assert.equals('s2',marker.Sockets[1].Name)
        result=nil;resource.stop('s1',function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('closed',result.kind)
    end)
    it('preserves a replaced pathname when stopping its original listener',function()
        local resource=assert(await_start().runtime)
        local listener=listen(resource,'s1')
        assert.equals('function',type(resource.stop))
        assert(uv.fs_rename(listener.path,listener.path..'.original'))
        vim.fn.writefile({'foreign replacement'},listener.path)
        local result
        resource.stop('s1',function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('unavailable',result.kind)
        assert.same({'foreign replacement'},vim.fn.readfile(listener.path))
    end)

    it('keeps inspection bounded when all 256 marked directory owners differ from this editor',function()
        local parent=root..'/runtime'
        for index=1,256 do seed_owner(parent,'e-'..index,900000+index) end
        -- This case proves the PID cap; the held-source case proves the deadline.
        local result=await_start({timeout_ms=arrival.MS})
        assert.equals('ready',result.kind,vim.inspect(result))
        local inspected=0
        for _ in pairs(source.probes) do inspected=inspected+1 end
        assert.is_true(inspected<=256)
        local retained=0
        for index=1,256 do if uv.fs_lstat(parent..'/e-'..index) then retained=retained+1 end end
        assert.equals(1,retained)
    end)
    it('retains a directory whose inode changes after inspection begins',function()
        local parent=root..'/runtime'
        local directory=seed_owner(parent,'e-changing',900001)
        source.hold=true
        local result
        runtime.acquire({parent=parent,incarnation=string.rep('a',32),source=source},function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return #source.reads==1 end,10))
        assert(uv.fs_rename(directory,directory..'.original'))
        assert(uv.fs_mkdir(directory,448))
        vim.fn.writefile(vim.fn.readfile(directory..'.original/owner.json'),directory..'/owner.json')
        source.release()
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('ready',result.kind,vim.inspect(result));resources[#resources+1]=result.runtime
        assert.is_not_nil(uv.fs_lstat(directory))
        assert.is_not_nil(uv.fs_lstat(directory..'.original'))
    end)

    local function delayed_acquire()
        source.hold=true
        local result
        runtime.acquire({parent=root..'/runtime',incarnation=string.rep('a',32),source=source},function(value) result=value end)
        assert(vim.wait(arrival.MS,function() return #source.reads==1 end,10))
        vim.defer_fn(function() source.release(1) end,800)
        assert(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('ready',result.kind,vim.inspect(result))
        resources[#resources+1]=result.runtime
        return result.runtime
    end
    for _,stage in ipairs({'reservation','publication'}) do
        it('shares the acquisition deadline through first-listener '..stage..' durability',function()
            local resource=delayed_acquire()
            local own_path=resource.directory..'/s1'
            local foreign=vim.fn.serverstart(root..'/foreign.sock')
            local calls,started,delivered,effects_after_delivery=0,0,false,0
            uv.fs_fsync=function(fd,callback)
                calls=calls+1
                if calls==(stage=='reservation' and 1 or 3) then
                    return saved_io.fsync(fd,function(err,value)
                        vim.defer_fn(function() delivered=true;callback(err,value) end,1500)
                    end)
                end
                return saved_io.fsync(fd,callback)
            end
            uv.fs_rename=function(...)
                if delivered then effects_after_delivery=effects_after_delivery+1 end
                return saved_io.rename(...)
            end
            vim.fn.serverstart=function(path)
                if path==own_path then started=started+1 end
                if delivered then effects_after_delivery=effects_after_delivery+1 end
                return saved_io.serverstart(path)
            end
            local result=listen(resource,'s1')
            -- Restore before teardown even when the assertions below fail.
            uv.fs_fsync,uv.fs_rename,vim.fn.serverstart=saved_io.fsync,saved_io.rename,saved_io.serverstart
            local foreign_preserved=vim.tbl_contains(vim.fn.serverlist(),foreign)
            vim.fn.serverstop(foreign)
            assert.equals('unavailable',result.kind,vim.inspect(result))
            assert.matches('deadline',result.error)
            assert.is_true(delivered,'completion must join the delayed fs request')
            assert.equals(0,effects_after_delivery,'expired publication started another effect')
            assert.equals(stage=='reservation' and 0 or 1,started)
            assert.is_nil(uv.fs_lstat(own_path))
            assert.is_false(vim.tbl_contains(vim.fn.serverlist(),own_path))
            assert.is_true(foreign_preserved)
        end)
    end
    it('gives later listeners a fresh operation budget after the first durable publication',function()
        local resource=delayed_acquire()
        assert.equals('listening',listen(resource,'s1').kind)
        local delayed=false
        uv.fs_fsync=function(fd,callback)
            if not delayed then
                delayed=true
                return saved_io.fsync(fd,function(err,value)
                    vim.defer_fn(function() callback(err,value) end,1500)
                end)
            end
            return saved_io.fsync(fd,callback)
        end
        local result=listen(resource,'s2')
        uv.fs_fsync=saved_io.fsync
        assert.equals('listening',result.kind,vim.inspect(result))
        assert.is_not_nil(uv.fs_lstat(result.path))
    end)

    local function hold_listen_io(resource,stage)
        local release,fsyncs,renames=nil,0,0
        local function held(callback)
            return function(err,value)
                release=function() callback(err,value) end
            end
        end
        uv.fs_open=function(path,flags,mode,callback)
            if stage=='open' and path==resource.directory..'/.owner.tmp' and flags=='wx' then
                return saved_io.open(path,flags,mode,held(callback))
            end
            return saved_io.open(path,flags,mode,callback)
        end
        uv.fs_fsync=function(fd,callback)
            fsyncs=fsyncs+1
            local target=({reservation=1,['publication-before-rename']=3,['publication-directory-fsync']=4})[stage]
            return saved_io.fsync(fd,fsyncs==target and held(callback) or callback)
        end
        uv.fs_rename=function(old,new,callback)
            renames=renames+1
            return saved_io.rename(old,new,stage=='publication-after-rename' and renames==2 and held(callback) or callback)
        end
        local result,calls=nil,0
        local operation=resource.listen('s1',function(value) result=value;calls=calls+1 end)
        assert(vim.wait(arrival.MS,function() return release~=nil end,10))
        return {operation=operation,release=function() release() end,result=function() return result end,
            calls=function() return calls end,restore=function()
                uv.fs_open,uv.fs_fsync,uv.fs_rename=saved_io.open,saved_io.fsync,saved_io.rename
            end}
    end
    for _,stage in ipairs({'open','reservation','publication-before-rename','publication-after-rename','publication-directory-fsync'}) do
        it('finalizes only owned marker writes when canceled during '..stage,function()
            local resource=assert(await_start().runtime)
            local held=hold_listen_io(resource,stage)
            held.operation.cancel();held.operation.cancel()
            assert.is_nil(held.result(),'cancellation must join the held native completion')
            held.restore();held.release()
            vim.schedule(function() held.operation.cancel() end)
            assert(vim.wait(arrival.MS,function() return held.result()~=nil end,10))
            assert.equals('unavailable',held.result().kind,vim.inspect(held.result()))
            assert.equals(1,held.calls())
            assert.is_nil(uv.fs_lstat(resource.directory..'/.owner.tmp'),'owned temporary marker leaked')
            assert.is_nil(uv.fs_lstat(resource.directory..'/s1'),'owned listener leaked')
            local closed
            resource.close(function(value) closed=value end)
            assert(vim.wait(arrival.MS,function() return closed~=nil end,10))
            assert.equals('closed',closed.kind,vim.inspect(closed))
            assert.is_nil(uv.fs_lstat(resource.directory),'exact-owned runtime directory leaked')
            local guard=assert(require('parley.document_lease').acquire('remote-session-runtime','allocation',{root=resource.parent}))
            guard.release()
        end)
    end
    for _,replacement in ipairs({'temporary','committed','committed-identical'}) do
        it('retains a foreign '..replacement..' marker replacement during canceled finalization',function()
            local resource=assert(await_start().runtime)
            local stage=replacement=='temporary' and 'reservation' or 'publication-after-rename'
            local held=hold_listen_io(resource,stage)
            local path=resource.directory..'/'..(replacement=='temporary' and '.owner.tmp' or 'owner.json')
            local foreign_bytes=replacement=='committed-identical' and vim.fn.readfile(path) or {'foreign replacement'}
            assert(uv.fs_rename(path,path..'.owned-away'))
            vim.fn.writefile(foreign_bytes,path,replacement=='committed-identical' and 'b' or '')
            assert(uv.fs_chmod(path,384))
            held.operation.cancel();held.restore();held.release()
            vim.schedule(function() held.operation.cancel() end)
            assert(vim.wait(arrival.MS,function() return held.result()~=nil end,10))
            assert.equals('unavailable',held.result().kind)
            assert.equals(1,held.calls())
            assert.same(foreign_bytes,vim.fn.readfile(path))
            assert.is_nil(uv.fs_lstat(resource.directory..'/s1'))
            if replacement~='temporary' then
                local stopped
                resource.stop('s1',function(value) stopped=value end)
                assert(vim.wait(arrival.MS,function() return stopped~=nil end,10))
                assert.equals('unavailable',stopped.kind,'foreign marker must not become a cleanup witness')
            end
            local closed
            resource.close(function(value) closed=value end)
            assert(vim.wait(arrival.MS,function() return closed~=nil end,10))
            assert.equals('unavailable',closed.kind)
            assert.same(foreign_bytes,vim.fn.readfile(path))
        end)
    end

    for _,stage in ipairs({'mkdir','initial-fsync','initial-rename','foreign-directory'}) do
        it('finalizes unpublished acquisition ownership when canceled during '..stage,function()
            local directory,release,operation,result,calls=nil,nil,nil,nil,0
            uv.fs_mkdtemp=function(template,callback)
                return saved_io.mkdtemp(template,function(err,path)
                    directory=path
                    callback(err,path)
                    if stage=='mkdir' or stage=='foreign-directory' then
                        if stage=='foreign-directory' then
                            assert(saved_io.rename(path,path..'.owned-away'))
                            assert(uv.fs_mkdir(path,448))
                            local fd=assert(uv.fs_open(path..'/foreign','w',384))
                            assert(uv.fs_write(fd,'foreign\n',0));assert(uv.fs_close(fd))
                        end
                        operation.cancel()
                    end
                end)
            end
            uv.fs_fsync=function(fd,callback)
                if stage=='initial-fsync' and not release then
                    return saved_io.fsync(fd,function(err,value) release=function() callback(err,value) end end)
                end
                return saved_io.fsync(fd,callback)
            end
            uv.fs_rename=function(old,new,callback)
                if stage=='initial-rename' and new:match('/owner%.json$') then
                    return saved_io.rename(old,new,function(err,value) release=function() callback(err,value) end end)
                end
                return saved_io.rename(old,new,callback)
            end
            operation=runtime.acquire({parent=root..'/runtime',incarnation=string.rep('a',32),source=source},
                function(value) result=value;calls=calls+1 end)
            if stage=='initial-fsync' or stage=='initial-rename' then
                assert(vim.wait(arrival.MS,function() return release~=nil end,10))
                operation.cancel()
                assert.is_nil(result)
                uv.fs_fsync,uv.fs_rename=saved_io.fsync,saved_io.rename
                release()
            end
            assert(vim.wait(arrival.MS,function() return result~=nil end,10))
            uv.fs_fsync,uv.fs_rename,uv.fs_mkdtemp=saved_io.fsync,saved_io.rename,saved_io.mkdtemp
            assert.equals('unavailable',result.kind,vim.inspect(result));assert.equals(1,calls)
            assert.is_string(directory)
            if stage=='foreign-directory' then
                assert.same({'foreign'},vim.fn.readfile(directory..'/foreign'))
                assert.is_not_nil(uv.fs_lstat(directory..'.owned-away'))
            else assert.is_nil(uv.fs_lstat(directory),'unpublished exact-owned runtime leaked') end
            local guard=assert(require('parley.document_lease').acquire('remote-session-runtime','allocation',{root=root..'/runtime'}))
            guard.release()
        end)
    end

    it('retains evidence but releases the guard when native finalization fails',function()
        local resource=assert(await_start().runtime)
        local held=hold_listen_io(resource,'reservation')
        local temporary=resource.directory..'/.owner.tmp'
        local before=assert(uv.fs_lstat(temporary))
        held.operation.cancel();held.restore()
        local faulted=false
        uv.fs_lstat=function(path,callback)
            if path==resource.directory and type(callback)=='function' and not faulted then
                faulted=true;error('controlled native finalization failure')
            end
            return saved_io.lstat(path,callback)
        end
        held.release()
        assert(vim.wait(arrival.MS,function() return held.result()~=nil end,10))
        uv.fs_lstat=saved_io.lstat
        assert.is_true(faulted)
        assert.equals('unavailable',held.result().kind)
        assert.matches('owned cleanup retained',held.result().error)
        assert.equals(1,held.calls())
        assert.equals(before.ino,assert(uv.fs_lstat(temporary)).ino)
        local guard=assert(require('parley.document_lease').acquire('remote-session-runtime','allocation',{root=resource.parent}))
        guard.release()
    end)
end)
