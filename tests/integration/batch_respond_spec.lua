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
end)
