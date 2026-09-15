local D=require('parley.document')
local R=require('parley.batch_response')
local docs,buffers,jobs={},{},{}
local original_capture,original_validate
local work
local function measure(fn)
    return function(...)
        local result=fn(...);work.queries=work.queries+1
        work.nodes=work.nodes+(result.work and result.work.nodes_visited or 0)
        work.entries=work.entries+(result.work and result.work.entries_visited or 0)
        return result
    end
end
local function reset()work={queries=0,nodes=0,entries=0}end
local function bounded()
    assert.is_true(work.queries<=8,vim.inspect(work))
    assert.is_true(work.nodes<=8192,vim.inspect(work));assert.is_true(work.entries<=16384,vim.inspect(work))
end
local function fixture(opts)
    opts=opts or {};local count=opts.count or 36
    local lines={};for i=1,count do lines[#lines+1]='💬: question '..i;lines[#lines+1]='🤖: answer'end
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    local doc=D.attach(buf,{schedule=false});docs[#docs+1]=doc;assert.equals('idle',D.drain(doc,2000).status)
    local ids={};for i=1,count do ids[i]=D.exchange(doc,(i-1)*2).identity end
    local queued,calls={},{}
    local job=assert(R.start(doc,{selection=ids,changed=opts.changed,schedule=function(cb)queued[#queued+1]=cb end,
        start=function(entity,done)
            calls[#calls+1]={entity=entity,done=done}
            if opts.synchronous then done({outcome='success'})end
            return {cancel=function()done({outcome='cancelled'})end}
        end}))
    jobs[#jobs+1]=job
    local function tick()
        assert.is_true(#queued>0,'no scheduled validation turn');reset();table.remove(queued,1)();bounded()
    end
    local function until_call(n)
        for _=1,40 do if #calls>=n then return end;tick()end
        error('validation did not finish')
    end
    return doc,buf,job,calls,queued,tick,until_call
end
describe('aggregate batch proof work budgets',function()
    before_each(function()
        original_capture,original_validate=D.capture_revision,D.validate_revision;reset()
        D.capture_revision=measure(original_capture);D.validate_revision=measure(original_validate)
    end)
    after_each(function()
        D.capture_revision,D.validate_revision=original_capture,original_validate
        for _,job in ipairs(jobs)do R.dispose(job)end;jobs={}
        for _,doc in ipairs(docs)do D.detach(doc)end;docs={}
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('slices admission and continuation into bounded scheduled proof work',function()
        local _,_,job,calls,_,tick,until_call=fixture()
        tick();assert.equals(0,#calls);until_call(1)
        calls[1].done({outcome='success'});tick();assert.equals(1,#calls);until_call(2)
        assert.equals(1,R.snapshot(job).completed)
    end)
    it('acknowledges queued large resume validation without changing paused phase',function()
        local _,_,job,calls,_,tick,until_call=fixture();until_call(1)
        R.cancel(job);tick();assert.equals('paused',R.snapshot(job).phase)
        reset();local result=R.resume(job);bounded()
        assert.is_true(result.accepted);assert.is_true(result.pending)
        assert.equals('paused',R.snapshot(job).phase)
        until_call(2);assert.equals(calls[1].entity,calls[2].entity)
    end)
    it('never starts from an earlier slice after an edit and pauses repeated interruptions',function()
        local doc,buf,job,calls,queued,tick=fixture()
        tick();assert.equals(0,#calls)
        vim.api.nvim_buf_set_text(buf,1,#'🤖: answer',1,#'🤖: answer',{' first edit'});D.drain(doc,2000)
        tick();assert.equals(0,work.queries,'an interrupted slice must not restart proof work in that callback')
        tick();assert.equals(0,#calls)
        vim.api.nvim_buf_set_text(buf,1,#'🤖: answer',1,#'🤖: answer',{' second edit'});D.drain(doc,2000)
        tick();assert.equals('paused',R.snapshot(job).phase);assert.equals(0,#calls)
        for _=1,5 do if #queued==0 then break end;tick()end
        assert.equals(0,#queued,'interrupted validation must not spin')
    end)
    it('shares the callback budget with synchronous positive completion proof capture',function()
        local _,_,job,_,_,_,until_call=fixture({count=32,synchronous=true})
        until_call(2);assert.equals(1,R.snapshot(job).completed)
    end)
    it('waits for opaque structure to repair without rescheduling itself',function()
        local doc,buf,_,calls,queued,tick,until_call=fixture()
        vim.api.nvim_buf_set_text(buf,1,#'🤖: answer',1,#'🤖: answer',{string.rep('x',70000)})
        tick();assert.equals(0,#calls);assert.equals(0,#queued)
        assert.equals('idle',D.drain(doc,2000).status)
        until_call(1);assert.equals(1,#calls)
    end)
    it('cancels queued validation without ever starting its next generation',function()
        local _,_,job,calls,queued,tick=fixture()
        tick();R.cancel(job)
        while #queued>0 do tick()end
        assert.equals('paused',R.snapshot(job).phase);assert.equals(0,#calls)
    end)
    it('reports a queued resume rejection to the host exactly once',function()
        local results={}
        local doc,buf,job,calls,queued,tick,until_call=fixture({changed=function(_,result)
            if result then results[#results+1]=result end
        end})
        until_call(1);R.cancel(job);tick()
        vim.api.nvim_buf_set_text(buf,0,#'💬: question 1',0,#'💬: question 1',{' changed'});D.drain(doc,2000)
        assert.is_true(R.resume(job).pending)
        for _=1,40 do if #queued==0 then break end;tick()end
        assert.equals(1,#results);assert.is_false(results[1].accepted);assert.equals('question changed',results[1].reason)
        assert.equals('paused',R.snapshot(job).phase);assert.equals(1,#calls)
    end)
end)
