local Fake=require('tests.helpers.fake_recovery_filesystem')
local function sample()
    return {key='exchange-a',bytes='original answer\nannotation',annotations={note='keep'},
        association={timestamp='2026-09-15.12-00-00',path='/chats/a.md',root='/project',
            question='question fingerprint',predecessor='previous fingerprint'},
        replacement={bytes='replacement',revision='revision-1'}}
end

describe('checked answer recovery store',function()
    local R,fs,store
    before_each(function()
        R=require('parley.answer_recovery');fs=Fake.new()
        store=assert(R.open({directory='/recovery',fs=fs}))
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
        assert.is_true(R.reconcile(store).ok)
        assert.equals(0,R.stats(store).pending_closes)
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
