local ok,Runner=pcall(require,'parley.generation_runner')
local D=require('parley.document')
local FakeEditor=require('tests.helpers.fake_document_editor')
local Fake=require('tests.helpers.fake_generation_runner')
local serial=100000
local docs,runners={},{}
local function document()
    serial=serial+1
    local editor=FakeEditor.new({'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
    local doc=D.attach(serial,{driver=editor.driver,schedule=false});docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,1000).status)
    return doc,editor
end
local function start(doc,fake,row,limits)
    local marker=D.query(doc,row,row+1)[1];local body=D.query(doc,row+1,row+2)[1]
    local runner,reason=Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
        input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},limits=limits,
        schedule=false},fake.adapters)
    assert.is_not_nil(runner,reason);runners[#runners+1]=runner
    Runner.drain(runner,1000)
    return runner
end
describe('generation runner sequences',function()
    after_each(function()
        if ok then for _,r in ipairs(runners) do Runner.cancel(r);Runner.drain(r,100) end end
        for _,doc in ipairs(docs) do D.detach(doc) end
        runners,docs={},{}
    end)
    it('provides the production runner composition',function()assert.is_true(ok)end)
    if not ok then return end
    it('owns preparation before effects and freezes input before async callbacks',function()
        local doc=document();local fake=Fake.new()
        local r=start(doc,fake,2)
        assert.equals(1,#fake.preparations)
        local state=Runner.snapshot(r)
        assert.is_true(D.snapshot(doc).grants[state.grant].status=='valid')
        fake:prepare(1);Runner.drain(r,1000)
        assert.equals('frozen',fake.requests[1].ctx.input.message)
        fake:output(1,'answer');fake:complete(1);Runner.drain(r,1000)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals(6,Runner.snapshot(r).committed_bytes)
    end)
    it('keeps disjoint writers independent and never replays suspended prefixes',function()
        local doc,editor=document();local first,second=Fake.new(),Fake.new()
        local a,b=start(doc,first,2),start(doc,second,5)
        first:prepare();second:prepare();Runner.drain(a,100);Runner.drain(b,100)
        first:output(1,'```\nbody\n```');second:output(1,'independent')
        for _=1,100 do Runner.drain(a,10);Runner.drain(b,10) end
        first:complete(1);second:complete(1);Runner.drain(a,1000);Runner.drain(b,1000)
        assert.equals('success',Runner.snapshot(a).outcome);assert.equals('success',Runner.snapshot(b).outcome)
        assert.equals(12,Runner.snapshot(a).committed_bytes)
        assert.equals(11,Runner.snapshot(b).committed_bytes)
        assert.equals(1,select(2,table.concat(editor.lines,'\n'):gsub('independent','')))
    end)
    it('fences late preparation after reload and waits for owned cleanup',function()
        local doc,editor=document();local fake=Fake.new();local r=start(doc,fake,2)
        editor:reload({'💬: replacement'})
        Runner.drain(r,100)
        assert.equals('stopping',Runner.snapshot(r).phase)
        fake.preparations[1].callbacks.prepared({message='late'})
        assert.equals(0,#fake.requests)
        fake.preparations[1].callbacks.resolved();Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals(0,Runner.snapshot(r).retained_blobs)
        assert.same({'💬: replacement'},editor.lines)
    end)
    it('rejects overflow before retaining the oversized payload',function()
        local doc=document();local fake=Fake.new();local r=start(doc,fake,2,{staged_bytes=8,queued_items=4})
        fake:prepare();Runner.drain(r,100)
        fake:output(1,string.rep('x',100));Runner.drain(r,100)
        assert.equals(0,Runner.snapshot(r).retained_staged_bytes)
        assert.equals('stopping',Runner.snapshot(r).phase)
        fake.requests[1].callbacks.resolved();Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('rejects invalid queue limits before acquiring document ownership',function()
        local doc=document();local fake=Fake.new()
        local marker=D.query(doc,2,3)[1];local body=D.query(doc,3,4)[1]
        local success,r=pcall(Runner.start,doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
            limits={queued_items=math.huge}},fake.adapters)
        assert.is_true(success);assert.is_nil(r)
        assert.same({},D.snapshot(doc).generations)
    end)
    it('runs synchronous preparation writes before starting the provider',function()
        local doc,editor=document();local fake=Fake.new()
        fake.adapters.prepare=function(ctx,cb)
            assert.is_true(ctx.append('shell',function(result)assert.equals('applied',result.status)end))
            cb.prepared(ctx.input);cb.resolved()
        end
        fake.adapters.request=function(ctx,cb)
            assert.equals('shell',editor.lines[4]);cb.output('answer');cb.complete();cb.resolved()
        end
        local r=start(doc,fake,2);Runner.drain(r,1000)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals('shellanswer',editor.lines[4])
    end)
    it('finishes the frozen request when input becomes stale',function()
        local doc,editor=document();local fake=Fake.new();local r=start(doc,fake,2)
        fake:prepare();Runner.drain(r,100)
        editor:edit(0,0,0,0,{'x'});D.drain(doc,1000)
        fake:complete(1);Runner.drain(r,1000)
        assert.is_true(Runner.snapshot(r).stale_input)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('refuses retained finalization contexts after completion',function()
        local doc=document();local fake=Fake.new();local r=start(doc,fake,2)
        fake:prepare();Runner.drain(r,100);fake:complete(1);Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.is_false(fake.finalizations[1].append('late',function()end))
        assert.is_true(fake.finalizations[1].cancelled())
        assert.equals(0,Runner.snapshot(r).retained_staged_bytes)
    end)

    it('releases superseded inputs and round payloads across one hundred rounds',function()
        local doc=document();local fake=Fake.new()
        fake.adapters.start_child=function(ctx,cb)cb.outcome('known',{value=ctx.arguments.value});cb.resolved()end
        fake.adapters.continue_round=function(ctx,cb)
            local n=ctx.results[1].value
            assert.equals(n==1 and 'frozen' or n-1,ctx.previous_input.message)
            ctx.previous_input.message='mutated borrowed prior input'
            cb.prepared({message=n});cb.resolved()
        end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        for round=1,100 do
            local cb=fake.requests[round].callbacks
            assert.is_true(cb.round({{call_id='call',arguments={value=round}}}));cb.resolved()
            Runner.drain(r,100)
            assert.equals(round+1,#fake.requests)
            assert.equals(round,fake.requests[round+1].ctx.input.message)
            assert.is_true(Runner.snapshot(r).retained_blobs<=6)
        end
        fake:complete(101);Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)

    it('releases every blob exactly once when a tool block fails or the round is cancelled',function()
        for _,cancel in ipairs({false,true})do
            local doc=document();local fake=Fake.new();local finish
            fake.adapters.insert_tool=function(_,done)finish=done end
            fake.adapters.start_child=function(ctx,cb)
                assert.same({nested={value='source'}},ctx.arguments)
                cb.outcome('cancelled_before_effect',{});cb.resolved()
            end
            local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
            local cb=fake.requests[1].callbacks
            cb.round({{call_id='one',arguments={nested={value='source'}}}});cb.resolved()
            Runner.drain(r,100);assert.is_function(finish)
            assert.is_true(Runner.snapshot(r).retained_blobs>0)
            if cancel then
                Runner.cancel(r);Runner.drain(r,100)
                assert.equals('stopping',Runner.snapshot(r).phase,'the issued block is still owed an answer')
            end
            finish('failed')
            Runner.drain(r,100)
            assert.equals('terminal',Runner.snapshot(r).phase)
            assert.equals(cancel and 'cancelled' or 'insert_failed',Runner.snapshot(r).outcome)
            assert.equals(0,Runner.snapshot(r).retained_blobs)
            finish('failed');cb.resolved();Runner.drain(r,100)
            assert.equals(0,Runner.snapshot(r).retained_blobs)
        end
    end)

    it('settles a tool block\'s queued write before terminal after cancellation',function()
        local doc=document();local fake=Fake.new();local r;local write_done=false
        fake.adapters.insert_tool=function(ctx,done)
            assert.is_true(ctx.append('pending block',function(result)write_done=true;done(result.status)end))
            Runner.cancel(r)
        end
        fake.adapters.start_child=function(_,cb)cb.outcome('cancelled_before_effect',{});cb.resolved()end
        fake.adapters.terminal=function()assert.is_true(write_done)end
        r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        local cb=fake.requests[1].callbacks
        cb.round({{call_id='one',arguments={}}});cb.resolved();Runner.drain(r,100)
        assert.is_true(write_done);assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals(0,Runner.snapshot(r).retained_blobs)
    end)
    it('does not render a queued tool block after cancellation',function()
        local doc=document();local fake=Fake.new();local called=false
        fake.adapters.insert_tool=function()called=true end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        local cb=fake.requests[1].callbacks
        cb.round({{call_id='one',arguments={}}});cb.resolved();Runner.cancel(r);Runner.drain(r,100)
        assert.is_false(called);assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('keeps a stopping generation until its issued tool block is answered',function()
        local doc=document();local fake=Fake.new();local done
        fake.adapters.insert_tool=function(_,complete)done=complete end
        fake.adapters.start_child=function(_,cb)cb.outcome('cancelled_before_effect',{});cb.resolved()end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        local cb=fake.requests[1].callbacks
        cb.round({{call_id='one',arguments={}}});cb.resolved();Runner.drain(r,100)
        Runner.cancel(r);Runner.drain(r,100)
        assert.equals('stopping',Runner.snapshot(r).phase)
        done('applied');Runner.drain(r,100);assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('stops a generation whose tool adapter throws, without waiting on an answer that cannot come',function()
        local doc=document();local fake=Fake.new()
        fake.adapters.insert_tool=function()error('adapter failed')end
        fake.adapters.start_child=function(_,cb)cb.outcome('cancelled_before_effect',{});cb.resolved()end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        local cb=fake.requests[1].callbacks
        cb.round({{call_id='one',arguments={}}});cb.resolved();Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals('insert_failed',Runner.snapshot(r).outcome)
        assert.truthy(Runner.snapshot(r).failure:find('adapter failed',1,true))
    end)

    it('binds context writes to private authority despite mutated context fields',function()
        local doc,editor=document();local fake=Fake.new()
        fake.adapters.prepare=function(ctx,cb)
            ctx.grant='foreign';ctx.operation='foreign';ctx.entity='foreign';ctx.generation='foreign'
            ctx.append('owned',function(result)assert.equals('applied',result.status)end)
            cb.prepared(ctx.input);cb.resolved()
        end
        local r=start(doc,fake,2)
        assert.equals('owned',editor.lines[4]);assert.equals(1,#fake.requests)
        fake:complete(1);Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('streams a large newline-heavy payload without replaying bounded prefixes',function()
        local doc,editor=document();local fake=Fake.new();local r=start(doc,fake,2)
        fake:prepare();Runner.drain(r,100)
        local payload=string.rep('x',70000)..string.rep('y\n',300)..'end'
        fake:output(1,payload);fake:complete(1);Runner.drain(r,10000)
        assert.equals('terminal',Runner.snapshot(r).phase)
        assert.equals(#payload,Runner.snapshot(r).committed_bytes)
        assert.equals(payload,table.concat(editor.lines,'\n'):match('first\n(.*)\n💬: q2'))
    end)

    it('rejects appends after finalization acknowledgement before terminal effects drain',function()
        local doc=document();local fake=Fake.new();local accepted
        fake.adapters.finalize=function(ctx,done)done('applied');accepted=ctx.append('late',function()end)end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100);fake:complete(1);Runner.drain(r,100)
        assert.is_false(accepted);assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('keeps cleanup unresolved after an adapter cancellation throws',function()
        local doc=document();local fake=Fake.new();fake.adapters.cancel_operation=function()error('cleanup failed')end
        local r=start(doc,fake,2);Runner.cancel(r);Runner.drain(r,100)
        assert.equals('stopping',Runner.snapshot(r).phase)
        assert.matches('cleanup failed',Runner.snapshot(r).failure)
        fake.preparations[1].callbacks.resolved();Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('resumes asynchronous document repair through its live subscription',function()
        local doc=document();local fake=Fake.new()
        local marker=D.query(doc,2,3)[1];local body=D.query(doc,3,4)[1]
        local r=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
            input={message='scheduled'}},fake.adapters));runners[#runners+1]=r
        assert.is_true(vim.wait(1000,function()return #fake.preparations==1 end,1))
        fake:prepare()
        assert.is_true(vim.wait(1000,function()return #fake.requests==1 end,1))
        fake:output(1,'```\nbody\n```');fake:complete(1)
        assert.is_true(vim.wait(2000,function()D.repair_step(doc);return Runner.snapshot(r).phase=='terminal' end,1))
        assert.equals(12,Runner.snapshot(r).committed_bytes)
    end)

    it('pauses stale-input continuation and can cancel the held preparation',function()
        local doc,editor=document();local fake=Fake.new();local continued=false
        fake.adapters.start_child=function(ctx,cb)cb.outcome('known','result');cb.resolved()end
        fake.adapters.continue_round=function()continued=true end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        editor:edit(0,0,0,0,{'x'});D.drain(doc,1000)
        local cb=fake.requests[1].callbacks;cb.round({{call_id='one',arguments={}}});cb.resolved()
        Runner.drain(r,100)
        assert.equals('paused',Runner.snapshot(r).phase);assert.is_false(continued)
        Runner.cancel(r);Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
    end)
    it('stops source edits without replaying queued output after undo-like replacement',function()
        local doc,editor=document();local fake=Fake.new();local r=start(doc,fake,2)
        fake:prepare();Runner.drain(r,100);fake:output(1,'first');Runner.drain(r,100)
        editor:edit(3,0,3,5,{'human'});D.drain(doc,1000)
        assert.is_false(fake:output(1,'late'))
        fake.requests[1].callbacks.resolved();Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase);assert.equals('human',editor.lines[4])
    end)

    it('freezes prepared input immediately while owned shell writes remain pending',function()
        local doc=document();local fake=Fake.new()
        fake.adapters.prepare=function(ctx,cb)
            ctx.append('shell',function()end)
            local input={message='captured'};cb.prepared(input);input.message='mutated';cb.resolved()
        end
        local r=start(doc,fake,2)
        assert.equals('captured',fake.requests[1].ctx.input.message)
        fake:complete(1);Runner.drain(r,100)
    end)

    it('waits for bounded replacement before prepared input is requested',function()
        local doc,editor=document();local fake=Fake.new()
        local question=D.query(doc,0,1)[1];local body=D.query(doc,3,4)[1]
        local totals={accepted=0,removed=0,ids={}}
        fake.adapters.written=function(_,receipt)
            assert.is_nil(totals.ids[receipt.id]);totals.ids[receipt.id]=true
            totals.accepted=totals.accepted+receipt.accepted_bytes;totals.removed=totals.removed+receipt.removed_bytes
        end
        local runner=assert(Runner.start(doc,{entity=question.handle,first=question.end_byte,
            last=body.end_byte-1,input={message='frozen'},schedule=false},fake.adapters))
        runners[#runners+1]=runner;Runner.drain(runner,100)
        local prep=fake.preparations[1];local done
        assert.is_true(prep.ctx.replace('🤖: replaced\n'..string.rep('x',70000),function(r)done=r end))
        prep.callbacks.prepared({message='captured'});prep.callbacks.resolved()
        assert.equals(0,#fake.requests)
        Runner.drain(runner,1000)
        assert.equals('applied',done.status);assert.equals(1,#fake.requests)
        assert.equals(done.accepted_bytes,totals.accepted);assert.equals(done.removed_bytes,totals.removed)
        assert.equals('🤖: replaced',editor.lines[2])
        assert.equals(0,Runner.snapshot(runner).retained_staged_bytes)
    end)
    it('cancels a partial replacement and releases its staged payload',function()
        local doc=document();local fake=Fake.new()
        local q=D.query(doc,0,1)[1];local body=D.query(doc,3,4)[1]
        local r=assert(Runner.start(doc,{entity=q.handle,first=q.end_byte,last=body.end_byte-1,
            input={},schedule=false},fake.adapters));runners[#runners+1]=r;Runner.drain(r,100)
        local prep=fake.preparations[1];local done
        assert.is_true(prep.ctx.replace(string.rep('x',70000),function(result)done=result end))
        Runner.step(r);Runner.cancel(r);prep.callbacks.resolved();Runner.drain(r,1000)
        assert.is_not_nil(done);assert.is_true(done.status~='applied')
        assert.equals(0,Runner.snapshot(r).retained_staged_bytes)
        assert.equals('idle',D.drain(doc,10000).status)
    end)
    it('notifies committed writes once after accounting even if presentation throws',function()
        local doc=document();local fake=Fake.new();local notices={};local r
        fake.adapters.written=function(ctx,receipt)
            notices[#notices+1]={ctx=ctx,receipt=receipt}
            assert.equals(receipt.accepted_bytes,Runner.snapshot(r).committed_bytes)
            assert.equals('busy',Runner.step(r).status)
            error('presentation failed')
        end
        r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        fake:output(1,'accepted');Runner.drain(r,100)
        assert.equals(1,#notices);assert.equals(8,notices[1].receipt.accepted_bytes)
        assert.equals('output',notices[1].receipt.kind);assert.is_nil(notices[1].ctx.append)
        assert.is_nil(notices[1].receipt.payload);assert.is_not_nil(notices[1].receipt.tip)
        fake:complete(1);Runner.drain(r,100)
        assert.equals('success',Runner.snapshot(r).outcome);assert.equals(1,#notices)
    end)
    it('reclaims the parent tail only after the tool resolves',function()
        local doc,editor=document();local fake=Fake.new();local child_cb
        fake.adapters.start_child=function(_,cb)child_cb=cb;cb.outcome('known',{})end
        fake.adapters.continue_round=function(ctx,cb)cb.prepared(ctx.input);cb.resolved()end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        fake.requests[1].callbacks.round({{call_id='one',arguments={}}});fake.requests[1].callbacks.resolved()
        Runner.drain(r,100);assert.equals(1,#fake.requests)
        assert.same({'call1','result1'},fake.inserted,'both blocks land before the tool is cleaned up')
        local gid=Runner.snapshot(r).grant;local before=D.snapshot(doc).grants[gid]
        assert.is_true(before.first<before.last)
        child_cb.resolved();Runner.drain(r,100)
        local after=D.snapshot(doc).grants[gid];assert.equals(after.first,after.last)
        fake:output(2,'after tool');Runner.drain(r,100)
        assert.equals('<call1><result1>after tool',editor.lines[4])
    end)
    for _,mode in ipairs({'cancel','detach'})do
        it('transfers cancelled child cleanup to its supervisor after '..mode,function()
            local doc,editor=document();local fake=Fake.new();local child_cb,ack
            local supervisor={owned=true,cancelled=false}
            fake.adapters.start_child=function(_,cb)child_cb=cb;cb.outcome('unknown',{effect='unknown'})end
            fake.adapters.cancel_operation=function(_,done)
                supervisor.cancelled=true;ack=done
            end
            local runner=start(doc,fake,2);fake:prepare();Runner.drain(runner,100)
            fake.requests[1].callbacks.round({{call_id='one',arguments={}}})
            fake.requests[1].callbacks.resolved();Runner.drain(runner,100)
            -- #266 M2: an unknown outcome is written and the round goes on; only
            -- the tool's own cleanup is still outstanding.
            assert.equals('executing_tools',Runner.snapshot(runner).phase)
            assert.same({'call1','result1'},fake.inserted)
            if mode=='detach'then D.detach(doc)else Runner.cancel(runner)end
            Runner.drain(runner,100);assert.equals('stopping',Runner.snapshot(runner).phase)
            assert.is_true(supervisor.cancelled);assert.is_function(ack)
            assert.is_false(ack(true));assert.is_false(ack({}));assert.is_false(ack({supervised=true,known=true}))
            assert.is_false(ack(setmetatable({supervised=true},{})))
            assert.is_true(ack({supervised=true}));Runner.drain(runner,100)
            local final=Runner.snapshot(runner)
            assert.equals('terminal',final.phase);assert.equals(0,final.retained_blobs)
            assert.equals(1,vim.tbl_count(final.supervised_children))
            for _,child in pairs(final.supervised_children)do assert.equals('unknown',child.outcome)end
            -- Parent retirement does not execute or fabricate the supervisor's cleanup.
            assert.is_true(supervisor.owned)
            local before=table.concat(editor.lines,'\n')
            assert.is_false(ack({supervised=true}));assert.is_false(child_cb.output('late bytes'))
            assert.is_false(child_cb.outcome('known',{effect='applied'}));assert.is_false(child_cb.resolved())
            supervisor.owned=false -- independent positive backend cleanup arrives later
            Runner.drain(runner,100);assert.equals(before,table.concat(editor.lines,'\n'))
            assert.equals(1,#fake.requests)
        end)
    end
end)

describe('atomic preparation grants',function()
    after_each(function()
        for _,r in ipairs(runners)do Runner.cancel(r);Runner.drain(r,100)end
        for _,doc in ipairs(docs)do D.detach(doc)end;runners,docs={},{}
    end)
    it('acquires disjoint cleanup gaps together and blocks prepared until they retire',function()
        local doc=document();local rows=D.query(doc,0,4);local fake=Fake.new()
        local r=assert(Runner.start(doc,{entity=rows[1].handle,first=rows[2].start_byte,last=rows[2].end_byte-1,
            preparation_regions={{first=rows[4].start_byte,last=rows[4].end_byte-1}},input={},schedule=false},fake.adapters))
        runners[#runners+1]=r;Runner.drain(r,100)
        local p=fake.preparations[1];assert.equals(1,#p.ctx.preparation_grants)
        assert.is_not_equal(p.ctx.grant,p.ctx.preparation_grants[1])
        assert.is_false(p.callbacks.prepared({}));assert.equals(0,#fake.requests)
        D.transition(doc,{kind='revoke',grant=p.ctx.preparation_grants[1]})
        assert.is_true(p.callbacks.prepared({}));p.callbacks.resolved();Runner.drain(r,100)
        assert.equals(1,#fake.requests);assert.is_nil(fake.requests[1].ctx.preparation_grants)
    end)
    it('rolls back all admission if an ancillary region overlaps the primary',function()
        local doc=document();local rows=D.query(doc,0,4);local fake=Fake.new()
        local r=Runner.start(doc,{entity=rows[1].handle,first=rows[2].start_byte,last=rows[2].end_byte-1,
            preparation_regions={{first=rows[2].start_byte,last=rows[2].end_byte-1}},input={},schedule=false},fake.adapters)
        assert.is_nil(r);assert.is_nil(next(D.snapshot(doc).generations));assert.is_nil(next(D.snapshot(doc).grants))
    end)
end)

describe('runner terminal retention',function()
    it('collects a terminal runner captured by its own native adapter even when terminal throws',function()
        for _,throws in ipairs({false,true}) do
            local weak=setmetatable({},{__mode='v'})
            local function run()
                local buf=vim.api.nvim_create_buf(false,true)
                vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a',''})
                local doc=D.attach(buf,{schedule=false});D.drain(doc,1000)
                local rows=D.query(doc,0,3);local r
                local adapters={prepare=function(ctx,cb)cb.prepared(ctx.input);cb.resolved()end,
                    request=function(_,cb)cb.complete();cb.resolved()end,
                    finalize=function(_,done)done('applied')end,
                    terminal=function()
                        assert.equals('terminal',Runner.snapshot(r).phase)
                        if throws then error('terminal UI failed') end
                    end}
                r=assert(Runner.start(doc,{entity=rows[2].handle,first=rows[2].start_byte,
                    last=rows[3].end_byte-1,input={},schedule=false},adapters))
                Runner.drain(r,1000);weak[1]=r
                D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
            end
            -- Keep fixture locals off JIT traces while measuring reachability.
            -- The real Deferred.close retention mutation still fails this probe.
            jit.off(run,true)
            run();collectgarbage('collect');collectgarbage('collect')
            assert.is_nil(weak[1])
        end
    end)
end)
