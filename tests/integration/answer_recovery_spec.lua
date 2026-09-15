local Fake=require('tests.helpers.fake_recovery_filesystem')
local function sample()
    return {key='exchange-a',bytes='original answer\nannotation',annotations={note='keep'},
        association={timestamp='2026-09-15.12-00-00',path='/chats/a.md',root='/project',
            question='question fingerprint',predecessor='previous fingerprint'},
        replacement={bytes='replacement',revision='revision-1'}}
end

describe('checked answer recovery store',function()
    local R,fs,store,owners
    before_each(function()
        R=require('parley.answer_recovery');fs=Fake.new();owners={}
        store=assert(R.open({directory='/recovery',fs=fs}))
    end)
    after_each(function()
        fs.faults={}
        for fd in pairs(fs.handles)do fs.close(fd)end
        if store then R.reconcile(store)end
        for _,value in ipairs(owners)do R.reconcile(value)end
    end)
    it('publishes private immutable bytes through short writes and retains original on retry',function()
        fs.short_write=7
        local input=sample();local result=R.publish(store,input);assert.is_true(result.ok)
        input.bytes='partial retry'
        local again=R.publish(store,input);assert.is_true(again.ok);assert.equals(result.id,again.id)
        local record=assert(R.inspect(store,result.id));assert.equals('original answer\nannotation',record.bytes)
        assert.equals(448,fs.files['/recovery'].mode)
        for path,file in pairs(fs.files)do if path~='/recovery'then assert.equals(384,file.mode)end end
    end)
    for _,operation in ipairs({'open','write','fsync','close','rename'})do
        it('refuses replacement after '..operation..' failure',function()
            fs.fail(operation,'injected '..operation)
            local result=R.publish(store,sample());assert.is_false(result.ok)
        end)
    end
    it('resolves only one exact association and replacement without ordinal fallback',function()
        local input=sample();local result=R.publish(store,input)
        local candidate={association=vim.deepcopy(input.association),replacement=vim.deepcopy(input.replacement),target='first'}
        assert.equals('first',R.resolve(store,result.id,{candidate}).target)
        local duplicate=vim.deepcopy(candidate);duplicate.target='duplicate'
        assert.is_false(R.resolve(store,result.id,{candidate,duplicate}).ok)
        candidate.replacement.bytes='human edit'
        assert.is_false(R.resolve(store,result.id,{candidate}).ok)
    end)
    it('retains failed deletion in budget accounting and never expires by age',function()
        local result=R.publish(store,sample());local size=R.stats(store).bytes
        fs.fail('unlink','denied')
        assert.is_false(R.cleanup(store,result.id,{kind='discard'}).ok)
        assert.equals(size,R.stats(store).bytes)
        assert.is_not_nil(R.inspect(store,result.id))
        assert.is_true(R.cleanup(store,result.id,{kind='discard'}).ok)
        assert.equals(0,R.stats(store).bytes)
    end)
    it('quarantines corrupt and unknown-version records after restart',function()
        fs.files['/recovery/broken.json']={bytes='{bad',mode=384}
        fs.files['/recovery/future.json']={bytes='{"version":999}',mode=384}
        store=assert(R.open({directory='/recovery',fs=fs}))
        assert.equals(2,R.stats(store).unavailable)
        assert.is_true(R.stats(store).bytes>0)
        assert.is_nil(R.inspect(store,'broken'))
    end)
    it('requires saved replacement evidence and fresh restore validation',function()
        local input=sample();local result=R.publish(store,input);local applied=false
        assert.is_false(R.cleanup(store,result.id,{kind='saved',replacement={bytes='other'}}).ok)
        local restore=R.restore(store,result.id,{validate=function()return nil,'human edit'end,
            apply=function()applied=true end})
        assert.is_false(restore.ok);assert.is_false(applied)
        assert.is_true(R.cleanup(store,result.id,{kind='saved',replacement=input.replacement}).ok)
    end)
    it('publishes successor evidence before retiring earlier revisions and accounts failed cleanup',function()
        local result=R.publish(store,sample());local old_size=R.stats(store).bytes
        fs.fail('unlink','busy')
        local updated=R.update(store,result.id,{bytes='settled output',revision='r2'})
        assert.is_true(updated.ok);assert.is_not_nil(updated.cleanup_error)
        assert.is_true(R.stats(store).bytes>old_size)
        local restarted=assert(R.open({directory='/recovery',fs=fs}))
        assert.equals('original answer\nannotation',R.inspect(restarted,result.id).bytes)
        assert.equals('settled output',R.inspect(restarted,result.id).replacement.bytes)
        fs.fail('unlink','still busy')
        assert.is_false(R.cleanup(restarted,result.id,{kind='discard'}).ok)
        assert.equals('settled output',R.inspect(restarted,result.id).replacement.bytes)
    end)
    it('does not quarantine readable records for transient IO failures',function()
        local result=R.publish(store,sample())
        fs.fail('read','transient read failure')
        assert.is_nil(R.inspect(store,result.id))
        assert.is_not_nil(R.inspect(store,result.id))
    end)
    it('does not recover an older revision when the latest committed revision is corrupt',function()
        local result=R.publish(store,sample());fs.fail('unlink','busy')
        assert.is_true(R.update(store,result.id,{bytes='settled'}).ok)
        fs.files['/recovery/'..result.id..'.2.json'].bytes='{truncated'
        local restarted=assert(R.open({directory='/recovery',fs=fs}))
        assert.is_nil(R.inspect(restarted,result.id))
        local retry=sample();retry.bytes='partial replacement'
        assert.is_false(R.publish(restarted,retry).ok)
    end)
    it('reconfirms directory durability before allowing a retained retry',function()
        fs.fail('fsync',false,'directory failure')
        assert.is_false(R.publish(store,sample()).ok)
        fs.fail('fsync','still failing')
        assert.is_false(R.publish(store,sample()).ok)
        assert.is_true(R.publish(store,sample()).ok)
    end)
    it('uses conservative serialized and physical capacity limits',function()
        local result=R.publish(store,sample());local size=R.stats(store).bytes
        local limited=assert(R.open({directory='/recovery',fs=fs,max_bytes=size}))
        local second=sample();second.key='another'
        assert.is_false(R.publish(limited,second).ok)
        assert.is_false(R.update(limited,result.id,{bytes='new'}).ok)
        assert.equals('replacement',R.inspect(limited,result.id).replacement.bytes)
        local smallfs=Fake.new();local small=assert(R.open({directory='/small',fs=smallfs,max_record_bytes=100}))
        assert.is_false(R.publish(small,sample()).ok)
    end)
    it('resolves renamed candidates without requiring volatile runtime revision',function()
        local input=sample();local result=R.publish(store,input)
        input.association.path='/chats/renamed.md';input.replacement.revision=nil
        local resolved=R.resolve(store,result.id,{{association=input.association,replacement=input.replacement,target='renamed'}})
        assert.equals('renamed',resolved.target)
    end)
    it('uses native checked private publication in an isolated temporary directory',function()
        local directory=vim.fn.tempname()..'-answer-recovery'
        local real=assert(R.open({directory=directory}))
        local result=R.publish(real,sample());assert.is_true(result.ok,result.reason)
        local reopened=assert(R.open({directory=directory}))
        assert.equals('original answer\nannotation',R.inspect(reopened,result.id).bytes)
        assert.is_true(R.cleanup(reopened,result.id,{kind='discard'}).ok)
        assert.is_true((vim.uv or vim.loop).fs_rmdir(directory))
    end)

    it('lists independent copied association evidence without exposing original bytes',function()
        local result=R.publish(store,sample())
        local records=R.list(store);assert.equals(1,#records);assert.equals(result.id,records[1].id)
        assert.is_nil(records[1].bytes)
        records[1].association.question='mutated'
        assert.equals('question fingerprint',R.inspect(store,result.id).association.question)
    end)
    it('retains a failed-close artifact until positive reconciliation',function()
        fs.fail('close','unknown close')
        assert.is_false(R.publish(store,sample()).ok)
        assert.equals(1,R.stats(store).pending_closes)
        assert.is_true(R.stats(store).bytes>0)
        assert.is_false(R.publish(store,sample()).ok)
        assert.is_false(R.reconcile(store).ok,'a still-open descriptor is unresolved')
        local fd=next(fs.handles);assert.is_true(fs.close(fd),'external owner positively closes the handle')
        local closes=#fs.closed_fds
        assert.is_true(R.reconcile(store).ok)
        assert.equals(closes,#fs.closed_fds,'reconciliation probes absence without another close')
        assert.equals(0,R.stats(store).pending_closes)
    end)
    for _,same_inode in ipairs({false,true})do
        it('never closes a reused descriptor after an ambiguous close '..tostring(same_inode),function()
            fs.close_error_closes=true;fs.fail('close','EIO: close result unknown')
            assert.is_false(R.publish(store,sample()).ok)
            local fd=fs.closed_fds[#fs.closed_fds];local original
            for path in pairs(fs.files)do if path:match('%.tmp$')then original=path end end
            assert.is_not_nil(original)
            local original_inode=fs.stat(original).ino
            local path=same_inode and original or '/unrelated'
            fs.reuse_fd=fd;assert.equals(fd,fs.open(path,same_inode and 'r' or 'wx',384))
            local replacement=fs.handles[fd]
            assert.equals(same_inode,original_inode==fs.fstat(fd).ino)
            local closes=#fs.closed_fds;local before=R.stats(store).bytes
            assert.is_false(R.reconcile(store).ok)
            assert.equals(closes,#fs.closed_fds);assert.equals(replacement,fs.handles[fd])
            local stats=R.stats(store)
            assert.equals(1,stats.pending_closes);assert.equals(before,stats.bytes);assert.is_true(stats.bytes>0)
            assert.is_false(R.publish(store,sample()).ok)
        end)
    end
    it('keeps probe failures unresolved instead of treating them as closure',function()
        fs.fail('close','unknown close');assert.is_false(R.publish(store,sample()).ok)
        fs.fail('fstat','EIO: probe failed')
        local closes=#fs.closed_fds
        assert.is_false(R.reconcile(store).ok);assert.equals(closes,#fs.closed_fds)
        assert.equals(1,R.stats(store).pending_closes)
    end)
    it('distinguishes absent storage from an unresolved owner without creating it',function()
        local value,_,status=R.open({directory='/missing',fs=fs,create=false})
        assert.is_nil(value);assert.equals('absent',status);assert.is_nil(fs.files['/missing'])
        fs.fail('close','unknown close');assert.is_false(R.publish(store,sample()).ok)
        local directory=fs.files['/recovery'];fs.files['/recovery']=nil
        local pending,_,pending_status=R.open({directory='/recovery',fs=fs,create=false})
        assert.is_nil(pending);assert.is_not.equals('absent',pending_status)
        assert.is_nil(fs.files['/recovery']);fs.files['/recovery']=directory
        directory.mode=493;assert.is_nil(R.open({directory='/recovery',fs=fs}));directory.mode=448
        local inode=directory.ino;directory.ino=inode+1
        assert.is_nil(R.open({directory='/recovery',fs=fs}));directory.ino=inode
        assert.equals(store,R.open({directory='/recovery',fs=fs}))
    end)
    it('retains unresolved owners across profile changes and rejects changed capacities',function()
        fs.fail('close','unknown close');assert.is_false(R.publish(store,sample()).ok)
        local held=setmetatable({store},{__mode='v'});store=nil
        assert(R.open({directory='/another-profile',fs=fs}))
        collectgarbage('collect');assert.is_not_nil(held[1])
        store=assert(R.open({directory='/recovery',fs=fs}))
        assert.equals(held[1],store)
        assert.is_nil(R.open({directory='/recovery',fs=fs,max_bytes=100}))
        local other=Fake.new()
        assert.is_not_nil(R.open({directory='/recovery',fs=other}))
    end)
    it('retains an owner when initial record scanning fails to close',function()
        assert.is_true(R.publish(store,sample()).ok)
        fs.fail('close','unknown scan close')
        assert.is_nil(R.open({directory='/recovery',fs=fs}))
        local reopened=assert(R.open({directory='/recovery',fs=fs}))
        owners[#owners+1]=reopened
        assert.is_false(R.reconcile(reopened).ok)
        for fd in pairs(fs.handles)do fs.close(fd)end
        assert.is_true(R.reconcile(reopened).ok)
        owners[#owners]=nil
        local weak=setmetatable({reopened},{__mode='v'});reopened=nil
        collectgarbage('collect');collectgarbage('collect')
        assert.is_nil(weak[1],'resolved owners must be collectible')
    end)
    it('bounds pending handles globally before opening another descriptor',function()
        assert.is_true(R.publish(store,sample()).ok)
        for i=1,32 do
            local directory='/pending-'..i
            local value=assert(R.open({directory=directory,fs=fs}));owners[#owners+1]=value
            fs.fail('close','unknown close');assert.is_false(R.publish(value,sample()).ok)
        end
        local function opens()local n=0;for _,call in ipairs(fs.calls)do if call=='open'then n=n+1 end end;return n end
        local before=opens()
        assert.is_false(R.publish(store,sample()).ok)
        assert.equals(before,opens())
        for fd in pairs(fs.handles)do fs.close(fd)end
        for _,value in ipairs(owners)do assert.is_true(R.reconcile(value).ok)end
        assert.is_true(R.publish(store,sample()).ok)
    end)
    it('refuses invalid nonfinite revision evidence before publication',function()
        local input=sample();input.replacement.revision=0/0
        assert.is_false(R.publish(store,input).ok)
    end)
    it('applies only after fresh validation and retains snapshot until explicit cleanup',function()
        local result=R.publish(store,sample());local proof={revision='fresh'}
        local restored=R.restore(store,result.id,{validate=function(record)
            assert.equals('original answer\nannotation',record.bytes);return proof
        end,apply=function(current,bytes,annotations)
            assert.equals(proof,current);assert.equals('original answer\nannotation',bytes)
            assert.equals('keep',annotations.note);return {ok=true}
        end})
        assert.is_true(restored.ok);assert.is_not_nil(R.inspect(store,result.id))
    end)
    it('refuses unsafe existing directory permissions and checked mkdir failure',function()
        local other=Fake.new();other.files['/unsafe']={type='directory',mode=493}
        assert.is_nil(R.open({directory='/unsafe',fs=other}))
        other.fail('mkdir','denied');assert.is_nil(R.open({directory='/new',fs=other}))
    end)

end)
