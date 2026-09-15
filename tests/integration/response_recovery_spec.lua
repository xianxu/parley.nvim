local D=require('parley.document')
local Store=require('parley.answer_recovery')
local Fake=require('tests.helpers.fake_recovery_filesystem')
local function region(last)return {first={row=1,col=0},last={row=2,col=last or 3}}end
local function association()return {timestamp='2026-09-15',path='/chats/a.md',root='/root',question='q',predecessor=''}end

describe('response recovery document adapter',function()
    local R,buf,doc,fs,store,jobs,ctx
    before_each(function()
        R=require('parley.response_recovery');jobs={};fs=Fake.new();store=assert(Store.open({directory='/recovery',fs=fs}))
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: question','🤖: old','old','','💬: next','draft'})
        doc=D.attach(buf,{schedule=false});assert.equals('idle',D.drain(doc,10000).status)
        local entity=D.exchange(doc,1).identity
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
            first=vim.api.nvim_buf_get_offset(buf,1),last=vim.api.nvim_buf_get_offset(buf,2)+3,
            revision=1,marker_revision=1,confirmed=true}}})
        assert.is_true(acquired.ok)
        ctx={entity=entity,epoch=D.snapshot(doc).epoch,generation=generation,grant=acquired.grants[1],cancelled=function()return false end}
    end)
    after_each(function()
        for _,job in ipairs(jobs)do R.release(job)end
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)
    local function capture()
        local job=assert(R.capture(doc,{buf=buf,store=store,key='q',association=association(),region=region(),annotations={note='original'}}))
        jobs[#jobs+1]=job;return job
    end
    local function generated()
        local grant=D.snapshot(doc).grants[ctx.grant]
        local cursor=assert(D.replace_new(doc,{epoch=ctx.epoch,generation=ctx.generation,grant=ctx.grant,
            entity=ctx.entity,revision=grant.revision,operation='replace answer',bytes='🤖: new\nreplacement'}))
        local result
        for _=1,100 do
            result=D.replace_step(doc,cursor)
            if result.status=='applied'then break end
            D.repair_step(doc)
        end
        assert.equals('applied',result.status);assert.equals('idle',D.drain(doc,10000).status)
    end
    it('publishes before replacement, settles owned bytes and restores beside draft edits',function()
        local job=capture();local published=R.publish(job,ctx);assert.is_true(published.ok)
        assert.equals('🤖: old\nold',Store.inspect(store,published.id).bytes)
        generated();assert.is_true(R.settle(job,ctx,region(11)).ok)
        vim.api.nvim_buf_set_text(buf,5,5,5,5,{' edited'})
        D.transition(doc,{kind='finish_generation',generation=ctx.generation})
        assert.is_true(R.restore(job).ok)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
        assert.equals('draft edited',vim.api.nvim_buf_get_lines(buf,5,6,false)[1])
        assert.is_not_nil(Store.inspect(store,published.id))
    end)
    it('refuses source changes during recovery IO before preparation may write',function()
        local job=capture();local original=fs.write;local edited=false
        fs.write=function(...)
            if not edited then edited=true;vim.api.nvim_buf_set_text(buf,2,0,2,3,{'human'})end
            return original(...)
        end
        assert.is_false(R.publish(job,ctx).ok)
        assert.equals('human',vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
    end)
    it('refuses publication failure without changing the original answer',function()
        local job=capture();fs.fail('write','disk full')
        assert.is_false(R.publish(job,ctx).ok)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
    end)
    it('refuses restore after answer edit and identical-byte ABA',function()
        local job=capture();assert.is_true(R.publish(job,ctx).ok);generated()
        assert.is_true(R.settle(job,ctx,region(11)).ok)
        vim.api.nvim_buf_set_text(buf,2,0,2,11,{'human'})
        vim.api.nvim_buf_set_text(buf,2,0,2,5,{'replacement'})
        assert.is_false(R.restore(job).ok)
    end)
    it('does not bless failed or cancelled generation bytes after grant revocation',function()
        local job=capture();local published=R.publish(job,ctx);assert.is_true(published.ok);generated()
        D.transition(doc,{kind='revoke',grant=ctx.grant})
        assert.is_false(R.settle(job,ctx,region(11)).ok)
        assert.equals('🤖: old\nold',Store.inspect(store,published.id).replacement.bytes)
    end)
    it('requires actual matching save read-back and current settled proof for cleanup',function()
        local job=capture();local published=R.publish(job,ctx);generated();assert.is_true(R.settle(job,ctx,region(11)).ok)
        assert.is_false(R.saved(job,{read=function()return 'wrong file bytes'end}).ok)
        assert.is_not_nil(Store.inspect(store,published.id))
        assert.is_true(R.saved(job,{read=function(path)
            assert.equals('/chats/a.md',path);return '🤖: new\nreplacement'
        end}).ok)
        assert.is_nil(Store.inspect(store,published.id))
    end)
    it('supports explicit fresh-target restore only against exact approved current bytes',function()
        local job=capture();local published=R.publish(job,ctx);generated()
        D.transition(doc,{kind='revoke',grant=ctx.grant})
        vim.api.nvim_buf_set_text(buf,2,0,2,11,{'human'});D.drain(doc,1000)
        local opts={buf=buf,region=region(5),expected_bytes='🤖: new\nreplacement'}
        assert.is_false(R.restore_target(store,published.id,doc,opts).ok)
        opts.expected_bytes='🤖: new\nhuman'
        assert.is_true(R.restore_target(store,published.id,doc,opts).ok)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
    end)
    it('releases captured guards on document detach',function()
        local job=capture();D.detach(doc)
        assert.is_false(R.publish(job,ctx).ok)
    end)
    it('retains original bytes when retry captures partial replacement',function()
        local job=capture();local first=R.publish(job,ctx);generated()
        local retry=assert(R.capture(doc,{buf=buf,store=store,key='q',association=association(),region=region(11)}))
        jobs[#jobs+1]=retry
        local published=R.publish(retry,ctx);assert.is_true(published.ok)
        assert.equals(first.id,published.id);assert.equals('🤖: old\nold',R.inspect(retry).bytes)
    end)
    it('revalidates explicit selection after recovery-file IO reenters the editor',function()
        local job=capture();local published=R.publish(job,ctx);generated()
        local native_read=fs.read;local changed=false
        fs.read=function(...)
            if not changed then changed=true;vim.api.nvim_buf_set_text(buf,2,0,2,11,{'human'})end
            return native_read(...)
        end
        local result=R.restore_target(store,published.id,doc,{buf=buf,region=region(11),expected_bytes='🤖: new\nreplacement'})
        assert.is_false(result.ok)
        assert.equals('human',vim.api.nvim_buf_get_lines(buf,2,3,false)[1])
    end)
    it('rejects save cleanup when read-back reenters and edits the answer',function()
        local job=capture();local published=R.publish(job,ctx);generated();assert.is_true(R.settle(job,ctx,region(11)).ok)
        assert.is_false(R.saved(job,{read=function()
            vim.api.nvim_buf_set_text(buf,2,0,2,11,{'human'});return '🤖: new\nreplacement'
        end}).ok)
        assert.is_not_nil(Store.inspect(store,published.id))
    end)
    it('exposes released settlement as explicit-target recovery without retaining a User slot',function()
        local job=capture();assert.equals('captured',R.snapshot(job).status)
        local published=R.publish(job,ctx);assert.equals('published',R.snapshot(job).status)
        generated();assert.is_true(R.settle(job,ctx,region(11)).ok)
        assert.equals('settled',R.snapshot(job).status)
        R.release(job);assert.equals('released',R.snapshot(job).status)
        assert.equals(published.id,R.snapshot(job).id)
        assert.equals(0,D.user_guard_stats(doc).live)
        assert.is_not_nil(R.inspect(job));assert.is_false(R.restore(job).ok)
    end)

    it('refuses settlement cleanly if recovery publication detaches the document',function()
        local job=capture();assert.is_true(R.publish(job,ctx).ok);generated()
        local write=fs.write;local detached=false
        fs.write=function(...)
            if not detached then detached=true;D.detach(doc)end
            return write(...)
        end
        local ok,result=pcall(R.settle,job,ctx,region(11))
        assert.is_true(ok,tostring(result));assert.is_false(result.ok)
    end)

end)
