local parley=require('parley')
local D=require('parley.document')
local root=vim.fn.tempname()..'-chat-recovery'
vim.fn.mkdir(root,'p')
parley.setup({chat_dir=root,state_dir=root..'/state',providers={},api_keys={},
    agents={{name='Choose a model',disable=true},{name='Fixture',provider='openai',model={model='fixture'},system_prompt='fixture'}}})

describe('chat recovery commands and lifecycle',function()
    local C,buf,doc,jobs,select,input,ctx,old_unlink,old_state
    before_each(function()
        C=require('parley.chat_recovery');C.setup(parley);jobs={};select,input=vim.ui.select,vim.ui.input
        buf=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(buf,root..'/2026-09-15.12-00-00.'..string.format('%03d',buf)..'_fixture.md')
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'# topic: Fixture','---','💬: question','🤖: old','old','','💬: next','draft'})
        doc=D.attach(buf,{schedule=false});D.drain(doc,10000)
        local entity=D.exchange(doc,3).identity
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
            first=vim.api.nvim_buf_get_offset(buf,3),last=vim.api.nvim_buf_get_offset(buf,4)+3,
            revision=1,marker_revision=1,confirmed=true}}})
        ctx={entity=entity,generation=generation,epoch=D.snapshot(doc).epoch,grant=acquired.grants[1],cancelled=function()return false end}
    end)
    after_each(function()
        if old_unlink then (vim.uv or vim.loop).fs_unlink=old_unlink;old_unlink=nil end
        if old_state then parley.config.state_dir=old_state;old_state=nil end
        for _,job in ipairs(jobs)do C.release(job)end
        vim.ui.select,vim.ui.input=select,input
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
    end)
    local function start()
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local parsed=parley.parse_chat(lines,2)
        local job=assert(C.start(doc,{buf=buf,path=vim.api.nvim_buf_get_name(buf),root=require('parley.neighborhood').policy_for_buf(buf).write_root,lines=lines,parsed=parsed,index=1,
            region={first={row=2,col=#'💬: question'},last={row=4,col=3}}}))
        jobs[#jobs+1]=job;return job
    end
    local function replace()
        local g=D.snapshot(doc).grants[ctx.grant]
        local cursor=assert(D.replace_new(doc,{epoch=ctx.epoch,generation=ctx.generation,grant=ctx.grant,entity=ctx.entity,
            revision=g.revision,operation='replacement',bytes='🤖: new\nreplacement'}))
        for _=1,100 do local r=D.replace_step(doc,cursor);if r.status=='applied'then break end;D.repair_step(doc)end
        D.drain(doc,10000)
    end
    it('revalidates a replaced or insecure recovery directory on each open',function()
        old_state=parley.config.state_dir;parley.config.state_dir=vim.fn.tempname()..'-cache-state'
        vim.fn.mkdir(parley.config.state_dir,'p')
        assert.same({},C.list(buf))
        local directory=parley.config.state_dir..'/answer-recovery'
        assert.is_true((vim.uv or vim.loop).fs_chmod(directory,493))
        assert.is_nil(C.list(buf),'cached store must not bypass permissions')
        assert.is_true((vim.uv or vim.loop).fs_chmod(directory,448))
        assert.is_true((vim.uv or vim.loop).fs_rmdir(directory))
        assert.same({},C.list(buf),'deleted directory can be freshly recreated for explicit use')
        assert.is_true((vim.uv or vim.loop).fs_rmdir(directory))
        local target=vim.fn.tempname()..'-private-target'
        assert.is_true((vim.uv or vim.loop).fs_mkdir(target,448))
        assert.is_true((vim.uv or vim.loop).fs_symlink(target,directory))
        assert.is_nil(C.list(buf),'symlink replacement is not the private directory')
        vim.fn.delete(directory);vim.fn.delete(target,'d')
    end)
    it('treats absent recovery storage as empty during confirmed chat deletion',function()
        old_state=parley.config.state_dir;parley.config.state_dir=vim.fn.tempname()..'-missing-state'
        assert.is_true(C.deleted(vim.fn.tempname()..'-deleted-chat.md').ok)
        assert.equals(0,vim.fn.isdirectory(parley.config.state_dir))
    end)
    it('tracks original recovery and cleans only after the exact replacement is saved',function()
        local job=start();local published=C.publish(job,ctx);assert.is_true(published.ok)
        replace();assert.is_true(C.settle(job,ctx).ok)
        assert.equals(1,#C.list(buf))
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.equals(0,#C.list(buf))
    end)
    it('keeps the original across a runtime retry',function()
        local job=start();local first=C.publish(job,ctx);replace();C.finish(job,'provider_failed')
        local retry=start();local result=C.publish(retry,ctx)
        assert.equals(first.id,result.id)
        assert.equals('\n🤖: old\nold',C.inspect_record(result.id).bytes)
    end)
    it('captures restore selection before picker and rejects edit-undo ABA',function()
        local job=start();C.publish(job,ctx);replace();C.release(job)
        vim.api.nvim_win_set_cursor(0,{4,0})
        local choices,choose,confirm
        vim.ui.select=function(items,_,callback)choices,choose=items,callback end
        vim.ui.input=function(_,callback)confirm=callback end
        C.restore(buf)
        vim.api.nvim_buf_set_text(buf,4,0,4,11,{'human'})
        vim.api.nvim_buf_set_text(buf,4,0,4,5,{'replacement'})
        choose(choices[1]);if confirm then confirm('yes')end
        assert.equals('replacement',vim.api.nvim_buf_get_lines(buf,4,5,false)[1])
    end)
    it('restores an explicitly confirmed fresh target while preserving other drafts',function()
        local job=start();C.publish(job,ctx);replace();C.release(job)
        vim.api.nvim_win_set_cursor(0,{4,0})
        vim.ui.select=function(items,_,callback)callback(items[1])end
        vim.ui.input=function(_,callback)callback('yes')end
        C.restore(buf)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,4,5,false)[1])
        assert.equals('draft',vim.api.nvim_buf_get_lines(buf,7,8,false)[1])
    end)
    it('opens inspection as scratch and explicit discard removes only selected record',function()
        local job=start();local result=C.publish(job,ctx)
        vim.ui.select=function(items,_,callback)callback(items[1])end
        C.inspect(buf)
        assert.equals('nofile',vim.bo.buftype)
        assert.is_truthy(table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),'\n'):find('🤖: old',1,true))
        local scratch=vim.api.nvim_get_current_buf();vim.api.nvim_set_current_buf(buf)
        vim.ui.input=function(_,callback)callback('yes')end
        C.discard(buf)
        assert.is_nil(C.inspect_record(result.id))
        if vim.api.nvim_buf_is_valid(scratch)then vim.api.nvim_buf_delete(scratch,{force=true})end
    end)
    it('reuses exact retained evidence after restart and chat rename',function()
        local job=start();local first=C.publish(job,ctx);replace();assert.is_true(C.settle(job,ctx).ok);C.release(job)
        local path=vim.api.nvim_buf_get_name(buf):gsub('_fixture.md$','_renamed.md')
        vim.api.nvim_buf_set_name(buf,path)
        local retry=start();local again=C.publish(retry,ctx)
        assert.is_true(again.ok);assert.equals(first.id,again.id)
    end)
    it('refuses unmatched restart evidence rather than replacing the retained original',function()
        local job=start();local result=C.publish(job,ctx);replace();C.release(job)
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local next_job=C.start(doc,{buf=buf,path=vim.api.nvim_buf_get_name(buf),root=require('parley.neighborhood').policy_for_buf(buf).write_root,
            lines=lines,parsed=parley.parse_chat(lines,2),index=1,entity=ctx.entity,ctx=ctx,
            region={first={row=2,col=#'💬: question'},last={row=4,col=11}}})
        assert.is_nil(next_job)
        assert.equals('\n🤖: old\nold',C.inspect_record(result.id).bytes)
    end)
    it('releases picker guards on cancellation and explicit discard through open',function()
        local job=start();local result=C.publish(job,ctx);replace();assert.is_true(C.settle(job,ctx).ok)
        local initial=D.user_guard_stats(doc).live
        vim.ui.select=function(_,_,callback)callback(nil)end
        C.open(buf);assert.equals(initial,D.user_guard_stats(doc).live)
        local step=0
        vim.ui.select=function(items,_,callback)step=step+1;callback(step==1 and items[1] or 'Discard')end
        vim.ui.input=function(_,callback)callback('yes')end
        C.open(buf)
        assert.is_nil(C.inspect_record(result.id));assert.equals(0,D.user_guard_stats(doc).live)
    end)
    it('ignores revoked ctx before fresh source capture',function()
        D.transition(doc,{kind='revoke',grant=ctx.grant})
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        assert.is_nil(C.start(doc,{buf=buf,path=vim.api.nvim_buf_get_name(buf),root=root,lines=lines,
            parsed=parley.parse_chat(lines,2),index=1,entity=ctx.entity,ctx=ctx,
            region={first={row=2,col=#'💬: question'},last={row=4,col=3}}}))
    end)
    it('restores exact restart evidence without asking for conflict confirmation',function()
        local job=start();C.publish(job,ctx);replace();assert.is_true(C.settle(job,ctx).ok);C.release(job)
        local prompts=0
        vim.ui.select=function(items,_,callback)callback(items[1])end
        vim.ui.input=function()prompts=prompts+1 end
        C.restore(buf);assert.equals(0,prompts)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,4,5,false)[1])
    end)

    it('restores one snapshot in a chat with more than64 unrelated exchanges',function()
        local job=start();C.publish(job,ctx);replace();assert.is_true(C.settle(job,ctx).ok);C.release(job)
        local lines={};for index=1,80 do
            lines[#lines+1]='💬: unrelated '..index;lines[#lines+1]='🤖: retained';lines[#lines+1]='answer'
        end
        vim.api.nvim_buf_set_lines(buf,-1,-1,false,lines);D.drain(doc,10000)
        local prompts=0
        vim.ui.select=function(items,_,callback)callback(items[1])end
        vim.ui.input=function()prompts=prompts+1 end
        C.restore(buf)
        assert.equals('old',vim.api.nvim_buf_get_lines(buf,4,5,false)[1]);assert.equals(0,prompts)
        assert.equals(0,D.user_guard_stats(doc).live)
    end)

    it('excludes the trailing definition footer when matching a confirmed save',function()
        vim.api.nvim_buf_set_lines(buf,5,-1,false,{'','---','[^n]: retained definition'})
        D.drain(doc,10000)
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace();assert.is_true(C.settle(job,ctx).ok)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.equals(0,#C.list(buf))
        assert.equals('[^n]: retained definition',vim.api.nvim_buf_get_lines(buf,-2,-1,false)[1])
    end)
    it('retains recovery when saved question and predecessor evidence is ambiguous',function()
        local lines={'# topic: Fixture','---','💬: p','🤖: a','a','💬: q','🤖: b','b',
            '💬: p','🤖: a','a','💬: q','🤖: b','b'}
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines);D.drain(doc,10000)
        local entity=D.exchange(doc,5).identity
        local generation=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=generation,regions={{entity=entity,
            first=vim.api.nvim_buf_get_offset(buf,6),last=vim.api.nvim_buf_get_offset(buf,7)+1,
            revision=1,marker_revision=1,confirmed=true}}})
        local context={entity=entity,generation=generation,epoch=D.snapshot(doc).epoch,grant=acquired.grants[1]}
        local job=assert(C.start(doc,{buf=buf,path=vim.api.nvim_buf_get_name(buf),root=require('parley.neighborhood').policy_for_buf(buf).write_root,
            lines=lines,parsed=parley.parse_chat(lines,2),index=2,entity=entity,ctx=context,
            region={first={row=5,col=#'💬: q'},last={row=7,col=1}}}))
        jobs[#jobs+1]=job;assert.is_true(C.publish(job,context).ok);assert.is_true(C.settle(job,context).ok)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.equals(1,#C.list(buf))
    end)

    it('cleans snapshots only after confirmed chat file deletion',function()
        local job=start();local result=C.publish(job,ctx)
        local path=vim.api.nvim_buf_get_name(buf)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_false(C.deleted(path).ok)
        assert.is_not_nil(C.inspect_record(result.id))
        assert.is_true((vim.uv or vim.loop).fs_unlink(path))
        assert.is_true(C.deleted(path).ok)
        assert.is_nil(C.inspect_record(result.id))
    end)
    it('cleans uniquely associated renamed chat snapshots after deletion',function()
        local job=start();local result=C.publish(job,ctx)
        local old=vim.api.nvim_buf_get_name(buf)
        local renamed=old:gsub('_fixture.md$','_renamed.md')
        vim.api.nvim_buf_set_name(buf,renamed)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_true((vim.uv or vim.loop).fs_unlink(renamed))
        assert.is_true(C.deleted(renamed).ok)
        assert.is_nil(C.inspect_record(result.id))
    end)
    it('retains renamed association if another same-timestamp chat remains',function()
        local job=start();local result=C.publish(job,ctx)
        local old=vim.api.nvim_buf_get_name(buf)
        local renamed=old:gsub('_fixture.md$','_renamed.md')
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_false(C.deleted(renamed).ok)
        assert.is_not_nil(C.inspect_record(result.id))
    end)

    it('surfaces failed snapshot unlink and retains its physical bytes for accounting',function()
        local uv=vim.uv or vim.loop
        old_state=parley.config.state_dir;parley.config.state_dir=root..'/cleanup-failure-'..buf
        vim.fn.mkdir(parley.config.state_dir,'p')
        old_unlink=uv.fs_unlink;local native_unlink=old_unlink;local deny=true
        uv.fs_unlink=function(path)
            if deny and path:match('%.json$')then return nil,'EACCES: recovery retained'end
            return native_unlink(path)
        end
        local job=start();local result=C.publish(job,ctx);assert.is_true(result.ok)
        local snapshot=parley.config.state_dir..'/answer-recovery/'..result.id..'.1.json'
        local size=assert(uv.fs_stat(snapshot)).size
        local path=vim.api.nvim_buf_get_name(buf)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_true(native_unlink(path))
        local removed=C.deleted(path);assert.is_false(removed.ok)
        assert.equals(size,assert(uv.fs_stat(snapshot)).size)
        assert.is_not_nil(C.inspect_record(result.id))
        deny=false;assert.is_true(C.deleted(path).ok)
        assert.is_nil(uv.fs_stat(snapshot))
    end)
    it('review: reports save cleanup IO failures',function()
        local uv=vim.uv or vim.loop
        old_unlink=uv.fs_unlink
        uv.fs_unlink=function(path)
            if path:match('%.json$')then return nil,'EACCES: recovery retained'end
            return old_unlink(path)
        end
        local job=start();assert.is_true(C.publish(job,ctx).ok)
        replace();assert.is_true(C.settle(job,ctx).ok)
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf,0,-1,false),vim.api.nvim_buf_get_name(buf))
        local notices=0;local original_notify=vim.notify
        vim.notify=function()notices=notices+1 end
        C.saved(buf)
        C.saved(buf)
        vim.notify=original_notify
        assert.equals(1,notices,'save cleanup EACCES is surfaced once per job/error')
    end)
    it('review: retires chat registry association on document detach',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok)
        D.detach(doc)
        assert.equals('released',C.snapshot(job).status)
        local registry
        for index=1,20 do
            local name,value=debug.getupvalue(C.release,index)
            if not name then break end
            if name=='entries'then registry=value end
        end
        assert.is_not_nil(registry)
        assert.is_nil(registry[job],'retired recovery must not retain its document in the host registry')
    end)

    for _,event in ipairs({'edit','cancel','detach','reload'})do
        it('retires pending settlement on '..event,function()
            local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
            local result
            local handle=C.settle(job,ctx,function(value)result=value end)
            if event=='edit'then
                vim.api.nvim_buf_set_text(buf,4,0,4,0,{'human '})
            elseif event=='cancel'then handle:cancel()
            elseif event=='detach'then D.detach(doc)
            else
                vim.fn.writefile(vim.api.nvim_buf_get_lines(buf,0,-1,false),vim.api.nvim_buf_get_name(buf))
                vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)
            end
            assert.is_true(vim.wait(2000,function()return result~=nil end,1))
            assert.is_false(result.ok)
            assert.equals(1,#C.list(buf))
        end)
    end
    it('refuses failed-attempt retry association after human edit undo',function()
        local job=start();local original=C.publish(job,ctx);replace();C.finish(job,'provider_failed')
        vim.api.nvim_buf_set_text(buf,4,0,4,0,{'human '})
        vim.api.nvim_buf_set_text(buf,4,0,4,6,{})
        D.drain(doc,10000)
        local lines=vim.api.nvim_buf_get_lines(buf,0,-1,false)
        local retry=C.start(doc,{buf=buf,path=vim.api.nvim_buf_get_name(buf),
            root=require('parley.neighborhood').policy_for_buf(buf).write_root,
            lines=lines,parsed=parley.parse_chat(lines,2),index=1,entity=ctx.entity,
            region={first={row=2,col=#'💬: question'},last={row=4,col=11}}})
        assert.is_nil(retry)
        assert.equals('\n🤖: old\nold',C.inspect_record(original.id).bytes)
    end)

    it('retains failed-attempt association across editing the next draft',function()
        local job=start();local first=C.publish(job,ctx);replace();C.finish(job,'provider_failed')
        vim.api.nvim_buf_set_text(buf,7,0,7,5,{'a new draft'})
        D.drain(doc,10000)
        local retry=start();local result=C.publish(retry,ctx)
        assert.is_true(result.ok);assert.equals(first.id,result.id)
        assert.equals('\n🤖: old\nold',C.inspect_record(result.id).bytes)
    end)

    it('retires host association when successful completion cannot settle edited output',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value;C.finish(job,'success')end)
        vim.api.nvim_buf_set_text(buf,4,0,4,0,{'human '})
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_false(result.ok);assert.equals('released',C.snapshot(job).status)
        assert.equals(1,#C.list(buf))
    end)

    it('settles while a human edits the disjoint next draft',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value end)
        vim.api.nvim_buf_set_text(buf,7,0,7,5,{'a new draft'})
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_true(result.ok)
    end)

    for _,reason in ipairs({'released','invalid-grant','invalid-context'})do
        it('returns cancelable finalization after inline '..reason..' refusal',function()
            local job=start();assert.is_true(C.publish(job,ctx).ok)
            local context=vim.deepcopy(ctx)
            if reason=='released'then C.release(job)
            elseif reason=='invalid-grant'then context.grant='missing'
            else context=nil end
            local calls,acks=0,0
            local handle=C.settle(job,context,function(result)
                calls=calls+1;assert.is_false(result.ok)
            end)
            assert.equals(1,calls)
            handle:cancel(function()acks=acks+1 end)
            handle:cancel(function()acks=acks+1 end)
            assert.equals(1,calls);assert.equals(2,acks)
            assert.equals(0,D.user_guard_stats(doc).live)
        end)
    end
    it('cleans a confirmed save made while completion settlement is queued',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value;C.finish(job,'success')end)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_true(result.ok)
        assert.equals(0,#C.list(buf),'confirmed saved replacement must retire its recovery snapshot')
    end)

    it('reports a failed saved-file stat instead of silently dropping cleanup',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace();assert.is_true(C.settle(job,ctx).ok)
        local uv=vim.uv or vim.loop
        local stat,notify=uv.fs_stat,vim.notify
        local notices={};local path=vim.api.nvim_buf_get_name(buf)
        uv.fs_stat=function(p,...)if p==path then return nil,'EACCES: saved chat probe denied' end;return stat(p,...)end
        vim.notify=function(msg)notices[#notices+1]=msg end
        local ok,err=pcall(C.saved,buf)
        uv.fs_stat,vim.notify=stat,notify
        assert.is_true(ok,tostring(err))
        assert.equals(1,#C.list(buf))
        assert.equals(1,#notices,'saved-file IO failures must be visible')
        assert.matches('EACCES',notices[1])
    end)
    for _,change in ipairs({'edit-undo','cancel','reload','detach'})do
        it('retains saved snapshot if pending settlement is invalidated by '..change,function()
            local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
            local result
            local handle=C.settle(job,ctx,function(value)result=value;C.finish(job,'success')end)
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
            if change=='edit-undo'then
                vim.api.nvim_buf_set_text(buf,4,0,4,0,{'human '})
                vim.api.nvim_buf_set_text(buf,4,0,4,6,{})
            elseif change=='cancel'then handle:cancel()
            elseif change=='reload'then vim.api.nvim_buf_call(buf,function()vim.cmd('edit!')end)
            else D.detach(doc)end
            assert.is_true(vim.wait(2000,function()return result~=nil end,1))
            assert.is_false(result.ok);assert.equals(1,#C.list(buf))
        end)
    end
    it('joins repeated early saves while a disjoint draft changes',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value end)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        vim.api.nvim_buf_set_text(buf,7,0,7,5,{'new draft'})
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_true(result.ok);assert.equals(0,#C.list(buf))
    end)
    it('remembers an early save before settlement is even queued',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        assert.is_true(C.settle(job,ctx).ok);assert.equals(0,#C.list(buf))
    end)
    for _,stage in ipairs({'stat-throw','read','limit'})do
        it('reports '..stage..' save IO failure once and retains recovery',function()
            local job=start();assert.is_true(C.publish(job,ctx).ok);replace();assert.is_true(C.settle(job,ctx).ok)
            local uv=vim.uv or vim.loop
            local stat,readfile,notify=uv.fs_stat,vim.fn.readfile,vim.notify
            local notices={};local path=vim.api.nvim_buf_get_name(buf)
            uv.fs_stat=function(p,...)
                if p==path then
                    if stage=='stat-throw'then error('EACCES stat')end
                    return {size=stage=='limit' and 256*1024*1024+1 or 1}
                end
                return stat(p,...)
            end
            vim.fn.readfile=function(p,...)if p==path then error('EACCES read')end;return readfile(p,...)end
            vim.notify=function(msg)notices[#notices+1]=msg end
            local ok,err=pcall(function()C.saved(buf);C.saved(buf)end)
            uv.fs_stat,vim.fn.readfile,vim.notify=stat,readfile,notify
            assert.is_true(ok,tostring(err));assert.equals(1,#notices)
            assert.equals(1,#C.list(buf))
        end)
    end

    it('uses the captured saved path after a later unsaved buffer rename',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value end)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write')end)
        local path=vim.api.nvim_buf_get_name(buf)
        local renamed=path:gsub('_fixture.md$','_unsaved.md');vim.api.nvim_buf_set_name(buf,renamed)
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_true(result.ok);assert.equals(0,#C.list(buf))
    end)

    it('does not treat an alternate-file write as saving the original chat',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
        local result
        C.settle(job,ctx,function(value)result=value end)
        local original=vim.api.nvim_buf_get_name(buf)
        local alternate=original:gsub('_fixture.md$','_copy.md')
        -- Coincidentally matching disk bytes are not a confirmed save event.
        vim.fn.writefile(vim.api.nvim_buf_get_lines(buf,0,-1,false),original)
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write! '..vim.fn.fnameescape(alternate))end)
        assert.equals(original,vim.api.nvim_buf_get_name(buf))
        assert.is_true(vim.wait(2000,function()return result~=nil end,1))
        assert.is_true(result.ok);assert.equals(1,#C.list(buf))
    end)

    for _,nested in ipairs({false,true})do
        it('joins a confirmed slug rename '..(nested and 'with nested write' or 'without nested write'),function()
            local job=start();assert.is_true(C.publish(job,ctx).ok);replace()
            local old=vim.api.nvim_buf_get_name(buf)
            local renamed=old:gsub('_fixture.md$','_slug.md')
            vim.api.nvim_create_autocmd('BufWritePost',{buffer=buf,once=true,nested=true,callback=function()
                assert.is_true((vim.uv or vim.loop).fs_rename(old,renamed))
                vim.api.nvim_buf_set_name(buf,renamed)
                if nested then
                    vim.api.nvim_buf_set_text(buf,0,9,0,#'# topic: Fixture',{'Renamed'})
                    vim.cmd('silent write!')
                end
            end})
            -- The real slug owner is registered before Recovery too.
            C.setup(parley)
            local result
            C.settle(job,ctx,function(value)result=value end)
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent write!')end)
            assert.is_true(vim.wait(2000,function()return result~=nil end,1))
            assert.is_true(result.ok);assert.equals(0,#C.list(buf))
        end)
    end

    it('admits a real save after bounded unmatched pre-write observations',function()
        local job=start();assert.is_true(C.publish(job,ctx).ok);replace();assert.is_true(C.settle(job,ctx).ok)
        -- Aborted writes need not emit Post. Pre alone never authorizes cleanup.
        for _=1,12 do vim.api.nvim_exec_autocmds('BufWritePre',{buffer=buf})end
        assert.equals(1,#C.list(buf))
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent write!')end)
        assert.equals(0,#C.list(buf))
    end)

end)
