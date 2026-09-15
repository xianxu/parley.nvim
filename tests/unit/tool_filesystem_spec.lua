local FS=require('parley.tools.filesystem')
local Fake=require('tests.helpers.fake_tool_filesystem')
local function fixture(options)
    local runtime,f=Fake.new();f.put('/','', 'directory');f.put('/file','original')
    options=options or {};options.runtime=runtime;options.schedule=f.schedule
    return FS.new(options),f
end
local function read(fs,f,path)
    local result;fs:read(path or '/file',function(r)result=r end);f.drain();assert.equals('known',result.certainty);assert.is_nil(result.error_code)
    return result
end
local function write(fs,revision,done,extra)
    local spec={path='/file',content='replacement',expected=revision,backup_path='/file.parley-backup.1'}
    for k,v in pairs(extra or {})do spec[k]=v end
    return fs:write_checked(spec,done)
end

describe('checked asynchronous tool filesystem',function()
    it('uses callback IO and publishes a checked backup before truncation',function()
        local fs,f=fixture();local prior=read(fs,f);assert.equals('original',prior.data)
        f.short_write=2;local result
        write(fs,prior.revision,function(r)result=r end)
        assert.is_nil(result);assert.equals('original',f.files['/file'].bytes)
        f.drain();assert.equals('applied',result.effect);assert.equals('known',result.certainty)
        assert.equals('replacement',f.files['/file'].bytes);assert.equals('original',f.files['/file.parley-backup.1'].bytes)
        local linked,truncated
        for i,c in ipairs(f.calls)do if c.name=='link'then linked=i elseif c.name=='ftruncate'then truncated=i end end
        assert.is_true(linked<truncated);assert.same({},f.fds)
    end)
    it('refuses oversize files before reading any content including long single lines',function()
        local fs,f=fixture({max_bytes=4});local result;fs:read('/file',function(r)result=r end);f.drain()
        assert.equals('capacity',result.error_code);assert.equals(0,f.count('read'));assert.equals('not_applied',result.effect)
    end)
    it('does not overwrite when backup write, sync, close or publication fails',function()
        for _,fault in ipairs({'write','fsync','close','link'})do
            local fs,f=fixture();local prior=read(fs,f);f.fail(fault,'EIO')
            local result;write(fs,prior.revision,function(r)result=r end);f.drain()
            assert.are_not.equals('applied',result.effect);assert.equals('original',f.files['/file'].bytes)
            assert.equals(0,f.count('ftruncate'));assert.is_not_nil(result.error_code)
        end
    end)
    it('never deletes a preexisting private temporary path on exclusive-open refusal',function()
        local fs,f=fixture();local prior=read(fs,f)
        -- The fake inserts another actor's file immediately before wx executes.
        f.fail('open',false,{before=function(state,args)if args[2]=='wx'then state.put(args[1],'foreign')end end})
        local result;write(fs,prior.revision,function(r)result=r end);f.drain()
        assert.equals('not_applied',result.effect);assert.equals('original',f.files['/file'].bytes)
        local foreign=0;for name,file in pairs(f.files)do if name:find('.tmp.',1,true)then assert.equals('foreign',file.bytes);foreign=foreign+1 end end
        assert.equals(1,foreign)
    end)
    it('revalidates a target replaced after backup publication',function()
        local fs,f=fixture();local prior=read(fs,f)
        f.fail('link',{after=function()f.put('/file','external replacement')end})
        local result;write(fs,prior.revision,function(r)result=r end);f.drain()
        assert.equals('conflict',result.error_code);assert.equals('not_applied',result.effect)
        assert.equals('external replacement',f.files['/file'].bytes);assert.equals(0,f.count('ftruncate'))
    end)
    it('creates an expected-absent file exclusively without needing a backup',function()
        local fs,f=fixture();local result
        fs:write_checked({path='/new',content='new',expected={exists=false}},function(r)result=r end);f.drain()
        assert.equals('applied',result.effect);assert.equals('new',f.files['/new'].bytes);assert.equals(0,f.count('link'))
        local conflict;fs:write_checked({path='/new',content='oops',expected={exists=false}},function(r)conflict=r end);f.drain()
        assert.equals('conflict',conflict.error_code);assert.equals('new',f.files['/new'].bytes)
    end)
    it('keeps cancellation pending until a target write callback and checked close settle',function()
        local fs,f=fixture();local prior=read(fs,f);local result
        local handle=write(fs,prior.revision,function(r)result=r end)
        while f.count('ftruncate')==0 do assert.is_true(f.step())end
        handle:cancel();assert.is_nil(result);f.drain()
        assert.equals('partial',result.effect);assert.equals('known',result.certainty);assert.is_true(result.cancelled)
        assert.same({},f.fds)
    end)
    it('retains failed-close uncertainty until explicit reconciliation succeeds',function()
        local fs,f=fixture();f.fail('close','EIO')
        local result;local handle=fs:read('/file',function(r)result=r end);f.drain()
        assert.equals('unknown',result.certainty);assert.is_false(result.physical_resolved);assert.is_not_nil(next(f.fds))
        local closes=f.count('close')
        handle:reconcile();f.drain();assert.equals('unknown',result.certainty);assert.equals(closes,f.count('close'))
        -- Positive descriptor absence resolves the old handle; no blind reclose.
        for fd in pairs(f.fds)do f.fds[fd]=nil end
        handle:reconcile();f.drain();assert.equals('known',result.certainty);assert.same({},f.fds)
        assert.equals('not_applied',result.effect);assert.is_true(result.physical_resolved)
    end)
    it('does not close a reused descriptor even when its inode matches',function()
        local fs,f=fixture();f.fail('close','EIO')
        local result;local handle=fs:read('/file',function(r)result=r end);f.drain()
        local fd=next(f.fds);local original=f.fds[fd];f.fds[fd]=nil;f.fds[fd]=original
        local count=f.count('close');handle:reconcile();f.drain()
        assert.equals(count,f.count('close'));assert.equals('unknown',result.certainty);assert.equals(original,f.fds[fd])
        original.mtime.sec=0/0;handle:reconcile();f.drain()
        assert.equals('unknown',result.certainty);assert.equals(count,f.count('close'))
        f.fds[fd]=f.put('/foreign','foreign');handle:reconcile();f.drain()
        assert.equals(count,f.count('close'));assert.equals('known',result.certainty);assert.equals('foreign',f.fds[fd].bytes)
    end)
    it('retains a missing callback until positive late delivery and ignores duplicates',function()
        local fs,f=fixture();f.fail('read',{drop=true})
        local result;local handle=fs:read('/file',function(r)result=r end);f.drain()
        assert.is_nil(result);handle:cancel();assert.is_false(handle:reconcile())
        assert.equals('unknown',handle:snapshot().certainty)
        f.lost[1]();f.lost[1]();f.drain()
        assert.equals('known',result.certainty);assert.is_true(result.cancelled);assert.same({},f.fds)
    end)
    it('does not guess that a throwing new-file submission had no effect',function()
        local fs,f=fixture();f.fail('open',{throw=true})
        local results={};fs:write_checked({path='/new',content='new',expected={exists=false}},function(r)results[#results+1]=r end)
        while #results==0 do assert.is_true(f.step())end
        assert.equals('unknown',results[1].certainty);assert.equals('unknown',results[1].effect)
        f.drain();assert.equals('applied',results[#results].effect);assert.equals('new',f.files['/new'].bytes)
    end)
    it('preserves an existing backup and catches replacement during read close',function()
        for _,replace in ipairs({false,true})do
            local fs,f=fixture();local prior=read(fs,f)
            if replace then f.fail('close',{after=function()f.put('/file','new owner')end})
            else f.put('/file.parley-backup.1','previous backup')end
            local result;write(fs,prior.revision,function(r)result=r end);f.drain()
            assert.equals('not_applied',result.effect);assert.equals(0,f.count('ftruncate'))
            if replace then assert.equals('new owner',f.files['/file'].bytes)
            else assert.equals('previous backup',f.files['/file.parley-backup.1'].bytes)end
        end
    end)
    it('rejects malformed revision values without invoking IO',function()
        local fs,f=fixture();local invalid={exists=false};invalid.self=invalid
        local result;fs:write_checked({path='/new',content='new',expected=invalid},function(r)result=r end)
        f.drain();assert.equals('invalid',result.error_code);assert.equals(0,#f.calls)
        local prior=read(fs,f);prior.revision.mtime.self=prior.revision.mtime
        fs:write_checked({path='/file',content='new',expected=prior.revision,backup_path='/backup'},function(r)result=r end)
        f.drain();assert.equals('invalid',result.error_code)
        assert.has_error(function()FS.new({max_steps=false})end)
    end)
    it('matches byte preservation across cancellation at every IO boundary',function()
        for cut=0,55 do
            local fs,f=fixture({chunk_bytes=2});local prior=read(fs,f);f.calls={}
            local result;local handle=write(fs,prior.revision,function(r)result=r end)
            for _=1,1000 do
                if #f.calls>=cut then handle:cancel()end
                if not f.step()then break end
            end
            assert.is_not_nil(result);assert.equals('known',result.certainty);assert.same({},f.fds)
            local bytes=f.files['/file'].bytes
            if result.effect=='applied'then assert.equals('replacement',bytes)
            elseif result.effect=='not_applied'then assert.equals('original',bytes)
            else assert.equals('partial',result.effect);assert.equals(bytes,('replacement'):sub(1,#bytes))end
            if bytes~='original'then assert.equals('original',f.files['/file.parley-backup.1'].bytes)end
            for _,call in ipairs(f.calls)do if call.name=='read' or call.name=='write'then assert.is_true(call.args[2]<=2)end end
        end
    end)
    it('bounds short-write work and stops before overwrite when backup work exhausts admission',function()
        local runtime,f=Fake.new();f.put('/','', 'directory');f.put('/file','original')
        local prior=read(FS.new({runtime=runtime,schedule=f.schedule}),f)
        local fs=FS.new({runtime=runtime,schedule=f.schedule,max_steps=12});f.short_write=1
        local result;write(fs,prior.revision,function(r)result=r end);f.drain()
        assert.equals('capacity',result.error_code);assert.equals('not_applied',result.effect)
        assert.equals('original',f.files['/file'].bytes);assert.is_true(result.evidence.steps<=14)
    end)
    it('retains partial target-write uncertainty and checked evidence after formatting failure',function()
        local fs,f=fixture();local prior=read(fs,f);f.fail('write',false,'EIO')
        local result;local handle=write(fs,prior.revision,function(r)result=r end);f.drain()
        assert.equals('unknown',result.certainty);assert.equals('partial',result.effect)
        assert.equals('',f.files['/file'].bytes);assert.equals('original',f.files['/file.parley-backup.1'].bytes)
        handle:reconcile();f.drain();assert.equals('unknown',handle:snapshot().certainty)
        fs,f=fixture();prior=read(fs,f)
        handle=write(fs,prior.revision,function()error('formatter failed')end);f.drain()
        assert.equals('known',handle:snapshot().certainty);assert.equals('applied',handle:snapshot().effect)
        assert.equals('replacement',f.files['/file'].bytes)
    end)
    it('does not publish twice when a completion callback cancels reentrantly',function()
        local fs,f=fixture();local prior=read(fs,f);local results={};local handle
        handle=write(fs,prior.revision,function(r)results[#results+1]=r;handle:cancel()end);f.drain()
        assert.equals(1,#results);assert.equals('applied',results[1].effect);assert.equals(1,f.count('link'))
    end)
end)
