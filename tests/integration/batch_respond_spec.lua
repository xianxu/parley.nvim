local D=require('parley.document')
local loaded,R=pcall(require,'parley.batch_response')
local docs,buffers,jobs={},{},{}
local function fixture()
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: one','🤖: old one','','💬: two','🤖: old two'})
    local doc=D.attach(buf,{schedule=false});docs[#docs+1]=doc;D.drain(doc,1000)
    return doc,buf,{D.exchange(doc,0).identity,D.exchange(doc,3).identity}
end
local function create(doc,entities)
    local calls,queue={},{}
    local job,err=R.start(doc,{selection=entities,schedule=function(cb)queue[#queue+1]=cb end,
        start=function(entity,done)
            local call={entity=entity,done=done,cancelled=0};calls[#calls+1]=call
            return {cancel=function()call.cancelled=call.cancelled+1 end}
        end})
    assert.is_not_nil(job,err);jobs[#jobs+1]=job
    local function pump()
        D.drain(doc,1000)
        for _=1,50 do if #queue==0 then return end;table.remove(queue,1)() end
        error('unbounded batch pump')
    end
    pump();return job,calls,pump
end
describe('Document-backed batch response controller',function()
    it('provides captured batch response execution',function()assert.is_true(loaded,tostring(R))end)
    if not loaded then return end
    after_each(function()
        for _,job in ipairs(jobs)do R.dispose(job)end;jobs={}
        for _,doc in ipairs(docs)do D.detach(doc)end;docs={}
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('uses captured identities after focus changes and human inserts another question',function()
        local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
        assert.equals(ids[1],calls[1].entity)
        local other=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=other;vim.api.nvim_set_current_buf(other)
        vim.api.nvim_buf_set_lines(buf,5,5,false,{'','💬: inserted'})
        calls[1].done({outcome='success'});pump()
        assert.equals(2,#calls);assert.equals(ids[2],calls[2].entity)
        calls[2].done({outcome='success'});pump()
        assert.equals('completed',R.snapshot(job).phase);assert.equals(2,R.snapshot(job).completed)
    end)
    it('pauses an edited remaining question and requires explicit adoption on resume',function()
        local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
        vim.api.nvim_buf_set_text(buf,3,8,3,8,{' changed'})
        calls[1].done({outcome='success'});pump()
        assert.equals(1,#calls);assert.equals('paused',R.snapshot(job).phase)
        assert.equals(1,R.snapshot(job).completed)
        assert.is_false(R.resume(job).accepted);pump();assert.equals(1,#calls)
        assert.is_true(R.resume(job,{accept_changes=true}).accepted);pump()
        assert.equals(2,#calls);assert.equals(ids[2],calls[2].entity)
    end)
    it('waits for physical completion after cancel and rejects stale callbacks',function()
        local doc,_,ids=fixture();local job,calls,pump=create(doc,ids)
        R.cancel(job);assert.equals(1,calls[1].cancelled)
        assert.is_false(R.resume(job).accepted)
        calls[1].done({outcome='cancelled'});pump()
        assert.is_true(R.resume(job).accepted);pump();assert.equals(2,#calls)
        calls[1].done({outcome='success'});pump();assert.equals(0,R.snapshot(job).completed)
        assert.equals(ids[1],calls[2].entity)
    end)
    it('does not substitute a deleted member or resume after document detach',function()
        local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
        vim.api.nvim_buf_set_lines(buf,3,5,false,{'💬: replacement','🤖: other'})
        calls[1].done({outcome='success'});pump()
        assert.equals(1,#calls);assert.is_false(R.resume(job,{accept_changes=true}).accepted)
        D.detach(doc);pump();assert.is_false(R.resume(job,{accept_changes=true}).accepted)
    end)
    it('retires detached resources before notifying the host without inventing physical completion',function()
        local doc,_,ids=fixture();local queue,done,job={},nil,nil
        local cancelled,retired,retirement=0,0,nil
        job=R.start(doc,{selection=ids,schedule=function(cb)queue[#queue+1]=cb end,
            start=function(_,cb)done=cb;return {cancel=function()cancelled=cancelled+1 end}end,
            retired=function(reason)
                retired=retired+1;retirement={reason=reason,resume=R.resume(job)}
                R.dispose(job)
            end})
        jobs[#jobs+1]=job;table.remove(queue,1)()
        D.detach(doc)
        assert.equals(1,cancelled);assert.equals(1,retired)
        assert.equals('detach',retirement.reason);assert.equals('disposed',retirement.resume.reason)
        local before=R.snapshot(job);assert.equals('paused',before.phase);assert.is_not_nil(before.active)
        done({outcome='success'});for _,cb in ipairs(queue)do cb()end
        assert.same(before,R.snapshot(job));assert.equals(0,R.snapshot(job).completed)
    end)
    it('retires completed batches once and keeps their final snapshot readable',function()
        local doc,_,ids=fixture();local queue,done,job={},nil,nil
        local retired,retirement=0,nil
        job=R.start(doc,{selection={ids[1]},schedule=function(cb)queue[#queue+1]=cb end,
            start=function(_,cb)done=cb;return {cancel=function()error('completed IO cannot be cancelled')end}end,
            retired=function(reason)retired=retired+1;retirement=reason;R.dispose(job)end})
        jobs[#jobs+1]=job;table.remove(queue,1)();done({outcome='success'});table.remove(queue,1)()
        assert.equals(1,retired);assert.equals('completed',retirement);assert.equals('completed',R.snapshot(job).phase)
        assert.equals(1,R.snapshot(job).completed);D.detach(doc);assert.equals(1,retired)
    end)
    for _,opaque in ipairs({false,true})do
        it('pauses a context edit between positive completion and the next pump '..tostring(opaque),function()
            local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
            if opaque then vim.api.nvim_buf_set_text(buf,1,#'🤖: old one',1,#'🤖: old one',{string.rep('x',70000)})end
            calls[1].done({outcome='success'})
            vim.api.nvim_buf_set_text(buf,1,#'🤖: old one',1,#'🤖: old one',{' human edit'})
            pump()
            assert.equals(1,R.snapshot(job).completed)
            assert.equals('paused',R.snapshot(job).phase);assert.equals(1,#calls)
            assert.is_false(R.resume(job).accepted)
            assert.is_true(R.resume(job,{accept_changes=true}).accepted);pump()
            assert.equals(2,#calls);assert.equals(ids[2],calls[2].entity)
        end)
    end
    it('does not let a presentation callback strand completed progress',function()
        local doc,_,ids=fixture();local queue,calls={},{}
        local job=R.start(doc,{selection=ids,schedule=function(cb)queue[#queue+1]=cb end,
            changed=function()error('presentation failed')end,
            start=function(entity,done)calls[#calls+1]={entity=entity,done=done};return {cancel=function()end}end})
        jobs[#jobs+1]=job
        assert.has_no.errors(function()table.remove(queue,1)()end)
        calls[1].done({outcome='success'})
        assert.has_no.errors(function()table.remove(queue,1)()end)
        assert.equals(1,R.snapshot(job).completed);assert.equals(2,#calls)
    end)
    it('keeps malformed completion evidence unknown and never replays it',function()
        local doc,_,ids=fixture();local job,calls,pump=create(doc,ids)
        calls[1].done({outcome={}});pump()
        assert.equals('paused',R.snapshot(job).phase);assert.is_true(R.snapshot(job).unknown)
        assert.is_false(R.resume(job,{accept_changes=true}).accepted);pump();assert.equals(1,#calls)
    end)
    it('allows semantic repair without an intervening edit to certify successful context',function()
        local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
        vim.api.nvim_buf_set_text(buf,1,#'🤖: old one',1,#'🤖: old one',{string.rep('x',70000)})
        calls[1].done({outcome='success'});pump()
        assert.equals(1,R.snapshot(job).completed);assert.equals(2,#calls)
    end)
    it('contains cancellation adapter errors while keeping physical ownership unresolved',function()
        local doc,_,ids=fixture();local queue={};local cancelled=0
        local job=R.start(doc,{selection=ids,schedule=function(cb)queue[#queue+1]=cb end,
            start=function()return {cancel=function()cancelled=cancelled+1;error('cancel transport failed')end}end})
        jobs[#jobs+1]=job;table.remove(queue,1)()
        assert.has_no.errors(function()R.cancel(job)end)
        assert.equals(1,cancelled);assert.equals('paused',R.snapshot(job).phase)
        assert.is_not_nil(R.snapshot(job).active)
        assert.is_false(R.resume(job,{accept_changes=true}).accepted)
    end)
    it('cancels a handle returned after reentrant detach exactly once',function()
        local doc,_,ids=fixture();local queue={};local cancelled=0
        local job=R.start(doc,{selection=ids,schedule=function(cb)queue[#queue+1]=cb end,
            start=function()D.detach(doc);return {cancel=function()cancelled=cancelled+1 end}end})
        jobs[#jobs+1]=job;table.remove(queue,1)()
        assert.equals(1,cancelled);assert.equals('paused',R.snapshot(job).phase)
        assert.equals(0,R.snapshot(job).completed);assert.equals('disposed',R.resume(job).reason)
    end)
    it('releases a detached document even when its retired batch snapshot is retained',function()
        local weak=setmetatable({},{__mode='v'});local job
        local function scope()
            local doc,_,ids=fixture();weak[1]=doc;local queue={}
            job=R.start(doc,{selection=ids,schedule=function(cb)queue[#queue+1]=cb end,
                start=function()return {cancel=function()end}end})
            jobs[#jobs+1]=job;table.remove(queue,1)();D.detach(doc)
            for _,cb in ipairs(queue)do cb()end
        end
        scope();docs={}
        collectgarbage('collect');collectgarbage('collect');collectgarbage('collect')
        assert.is_nil(weak[1]);assert.equals('paused',R.snapshot(job).phase)
    end)
    it('preserves immediate rejection for a small resume whose proof is unavailable',function()
        local doc,buf,ids=fixture();local job,calls,pump=create(doc,ids)
        R.cancel(job);calls[1].done({outcome='cancelled'});pump()
        vim.api.nvim_buf_set_text(buf,1,#'🤖: old one',1,#'🤖: old one',{string.rep('x',70000)})
        local result=R.resume(job)
        assert.is_false(result.accepted);assert.equals('revision unavailable',result.reason)
        assert.equals('paused',R.snapshot(job).phase)
    end)
end)
