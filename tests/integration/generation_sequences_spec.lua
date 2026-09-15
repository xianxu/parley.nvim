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
        assert.equals(0,Runner.snapshot(r).retained_staged_bytes)
    end)

    it('releases superseded inputs and round payloads across one hundred rounds',function()
        local doc=document();local fake=Fake.new();local child
        fake.adapters.reserve_round=function(ctx,done)
            if not child then
                local parent=D.snapshot(doc).grants[ctx.grant]
                local result=D.transition(doc,{kind='acquire',generation=ctx.generation,parent=ctx.grant,
                    regions={{entity=parent.entity,first=parent.last,last=parent.last,marker_revision=1,
                        revision=1,confirmed=true}}})
                assert.is_true(result.ok,result.reason);child=result.grants[1]
            end
            done({child},{layout='owned'})
        end
        fake.adapters.start_child=function(ctx,cb)cb.outcome('known',{value=ctx.arguments.value});cb.resolved()end
        fake.adapters.continue_round=function(ctx,cb)cb.prepared({message=ctx.results[1].value});cb.resolved()end
        local r=start(doc,fake,2);fake:prepare();Runner.drain(r,100)
        for round=1,100 do
            local cb=fake.requests[round].callbacks
            assert.is_true(cb.round({{call_id='call',arguments={value=round}}}));cb.resolved()
            Runner.drain(r,100)
            assert.equals(round+1,#fake.requests)
            assert.is_true(Runner.snapshot(r).retained_blobs<=6)
        end
        fake:complete(101);Runner.drain(r,100)
        assert.equals('terminal',Runner.snapshot(r).phase)
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
        fake.adapters.reserve_round=function(ctx,done)
            local parent=D.snapshot(doc).grants[ctx.grant]
            local result=D.transition(doc,{kind='acquire',generation=ctx.generation,parent=ctx.grant,
                regions={{entity=parent.entity,first=parent.last,last=parent.last,marker_revision=1,revision=1,confirmed=true}}})
            assert.is_true(result.ok);done(result.grants)
        end
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

end)
