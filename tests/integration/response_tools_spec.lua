local D=require('parley.document')
local Runner=require('parley.generation_runner')
local Editor=require('tests.helpers.fake_document_editor')
local Tools=require('parley.response_tools')
local serial=117000
local docs,runners,fixtures={},{},{}
local function setup(options)
    options=options or {}
    serial=serial+1
    local editor=Editor.new({'💬: question','🤖: answer','text','','💬: next','draft'})
    local doc=D.attach(serial,{driver=editor.driver,schedule=false});docs[#docs+1]=doc;D.drain(doc,1000)
    local producer={started={},cancelled={}}
    function producer.start(call,opts,events)
        local op={call=call,opts=opts,events=events};producer.started[#producer.started+1]=op;return op
    end
    function producer.cancel(op,resolved)producer.cancelled[#producer.cancelled+1]={op=op,resolved=resolved}end
    local requests={}
    local adapter=Tools.new(doc,{producer=not options.actual and producer or nil,root_policy=options.root_policy,
        max_iterations=options.max_iterations,schedule=false,build_input=function(previous,messages)
        previous.messages=messages;previous.payload={model='fixture',messages=messages};return previous
    end})
    local hooks={prepare=function(ctx,cb)cb.prepared(ctx.input);cb.resolved()end,
        request=function(ctx,cb)requests[#requests+1]={ctx=ctx,cb=cb};return {}end,
        finalize=function(_,done)done('applied')end,terminal=adapter.close,
        reserve_round=adapter.reserve_round,start_child=function(ctx,cb)
            if options.on_outcome then
                local outcome=cb.outcome
                cb.outcome=function(kind,value)local accepted=outcome(kind,value);options.on_outcome(kind);return accepted end
            end
            return adapter.start_child(ctx,cb)
        end,continue_round=adapter.continue_round,
        cancel_operation=adapter.cancel_operation,cancel_reservation=adapter.cancel_reservation}
    local marker=D.query(doc,0,1)[1];local body=D.query(doc,2,3)[1]
    local runner=assert(Runner.start(doc,{entity=marker.handle,first=marker.end_byte-1,last=body.end_byte-1,
        input={messages={{role='user',content='question'}},payload={}},schedule=false},hooks));runners[#runners+1]=runner
    local function drain()
        for _=1,2000 do
            D.repair_step(doc);Runner.step(runner);adapter.step()
            if Runner.snapshot(runner).phase=='terminal'then return end
        end
    end
    drain()
    local function round(calls)
        local req=requests[#requests]
        adapter.on_result(req.ctx,{response='tool text'},calls)
        local declared={};for i,c in ipairs(calls)do declared[i]={call_id=c.id,arguments=c}end
        assert.is_true(req.cb.round(declared));req.cb.resolved();drain()
    end
    local fixture={doc=doc,editor=editor,producer=producer,requests=requests,runner=runner,adapter=adapter,drain=drain,round=round}
    fixtures[#fixtures+1]=fixture
    return fixture
end
local calls={{id='a',name='read_file',input={path='a'}},{id='b',name='read_file',input={path='b'}}}
describe('production concurrent tool round composition',function()
    after_each(function()
        for _,r in ipairs(runners)do Runner.cancel(r);Runner.drain(r,100)end
        for _,f in ipairs(fixtures)do
            for _,op in ipairs(f.producer.started)do
                op.events.outcome('cancelled_before_effect',{})
                op.events.resolved()
            end
            for _,cancellation in ipairs(f.producer.cancelled)do cancellation.resolved()end
            for _,request in ipairs(f.requests)do request.cb.resolved()end
            f.drain()
            assert.equals('terminal',Runner.snapshot(f.runner).phase)
        end
        for _,doc in ipairs(docs)do D.detach(doc)end
        docs,runners,fixtures={},{},{}
    end)
    local function projected(f)
        local parsed=require('parley.chat_parser').parse_chat(f.editor.lines,0,{
            chat_user_prefix='💬:',chat_branch_prefix='🌿:',chat_assistant_prefix={'🤖:','[{{agent}}]'},
            chat_tool_use_prefix='🔧:',chat_tool_result_prefix='📎:',chat_memory={enable=false}})
        local blocks=parsed.exchanges[1].answer.content_blocks
        local results={}
        for _,block in ipairs(blocks)do if block.type=='tool_result'then results[block.id]=block end end
        local wire={}
        local messages=require('parley.chat_respond')._emit_content_blocks_as_messages(blocks)
        for _,message in ipairs(messages)do
            for _,block in ipairs(message.content)do
                if block.type=='tool_result'then wire[block.tool_use_id]=block end
            end
        end
        local openai={}
        for _,message in ipairs(require('parley.tools.wire_openai').translate_messages(messages))do
            if message.role=='tool'then openai[message.tool_call_id]=message.content end
        end
        return results,wire,openai
    end
    for _,stop in ipairs({'pending','cancel','reload','unknown','rejected'})do
        it('never publishes completed results from '..stop..' reservations',function()
            local f=setup();f.round(calls)
            assert.equals(2,#f.producer.started,'reservations must admit both producers')
            if stop=='unknown' or stop=='rejected'then
                f.producer.started[1].events.outcome(stop,{content='no confirmed result'})
                f.producer.started[1].events.resolved();f.drain()
            elseif stop=='cancel'then Runner.cancel(f.runner);f.drain()
            elseif stop=='reload'then f.editor:reload(f.editor.lines);f.drain()end
            local results,wire,openai=projected(f)
            assert.same({},results,'only positive tool outcomes may serialize result blocks')
            for _,c in ipairs(calls)do
                assert.is_true(wire[c.id].is_error,'missing results must remain missing on provider projection')
                assert.is_nil(wire[c.id].content:find('(pending)',1,true))
                assert.is_truthy(openai[c.id]:find(wire[c.id].content,1,true))
            end
            assert.equals(1,#f.requests,'reservation alone cannot admit provider continuation')
            if stop=='unknown'then
                f.producer.started[1].events.outcome('known',{content='later confirmation'});f.drain()
            end
        end)
    end
    it('publishes only confirmed sibling outcomes when a live transcript is reparsed',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        second.events.outcome('known',{content='confirmed second'});second.events.resolved();f.drain()
        local results,wire=projected(f)
        assert.is_nil(results.a);assert.equals('confirmed second',results.b.content)
        assert.is_true(wire.a.is_error);assert.is_false(wire.b.is_error)
        first.events.outcome('known',{content='confirmed first'});first.events.resolved();f.drain()
        results,wire=projected(f)
        assert.equals('confirmed first',results.a.content);assert.equals('confirmed second',results.b.content)
        assert.is_false(wire.a.is_error);assert.is_false(wire.b.is_error)
    end)
    it('declares all call blocks and result grants before any producer starts',function()
        local f=setup();f.round(calls)
        assert.equals(2,#f.producer.started)
        local text=table.concat(f.editor.lines,'\n')
        local a=text:find('🔧: read_file id=a',1,true)
        local b=text:find('🔧: read_file id=b',1,true)
        local ra=text:find('(Tool result pending)',1,true)
        local rb=text:find('(Tool result pending)',ra+1,true)
        assert.is_true(a<b and b<ra and ra<rb)
        assert.equals('executing_tools',Runner.snapshot(f.runner).phase)
    end)
    it('joins out-of-order result writes in declared order and preserves a human draft',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        assert.is_not_nil(second)
        second.events.outcome('known',{content='second result'});second.events.resolved()
        f.editor:edit(#f.editor.lines-1,5,#f.editor.lines-1,5,{' edited'})
        f.drain();assert.equals(1,#f.requests)
        first.events.outcome('known',{content='first result',is_error=true});first.events.resolved();f.drain()
        assert.equals(2,#f.requests)
        local messages=f.requests[2].ctx.input.messages
        assert.equals('a',messages[#messages].content[1].tool_use_id)
        assert.equals('b',messages[#messages].content[2].tool_use_id)
        assert.equals('draft edited',f.editor.lines[#f.editor.lines])
        f.requests[2].cb.complete();f.requests[2].cb.resolved();f.drain()
        assert.equals('success',Runner.snapshot(f.runner).outcome)
    end)
    it('refuses insufficient capacity before placeholder writes or tool effects',function()
        local f=setup();local before=table.concat(f.editor.lines,'\n')
        local registered=D.transition(f.doc,{kind='register_generation',input_snapshot={}})
        assert.is_true(registered.ok)
        local reserved=D.reserve_capacity(f.doc,{epoch=D.snapshot(f.doc).epoch,generation=registered.generation,
            operation='competing round',count=14})
        assert.is_true(reserved.ok)
        f.round(calls)
        assert.equals(0,#f.producer.started)
        assert.equals(before,table.concat(f.editor.lines,'\n'))
        assert.equals('reservation_failed',Runner.snapshot(f.runner).outcome)
    end)
    it('retains unknown outcomes until later positive evidence permits an explicit resume',function()
        local f=setup();f.round({calls[1]})
        local op=f.producer.started[1]
        op.events.outcome('unknown',{content='not yet known'});op.events.resolved();f.drain()
        assert.equals('paused',Runner.snapshot(f.runner).phase)
        assert.equals(1,Runner.snapshot(f.runner).outstanding_operations)
        assert.is_true(op.events.outcome('known',{content='confirmed result'}))
        f.drain()
        assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
        assert.is_true(Runner.resume(f.runner,'operator confirmed continuation').accepted)
        f.drain();assert.equals(2,#f.requests)
        f.requests[2].cb.complete();f.requests[2].cb.resolved();f.drain()
        assert.equals('success',Runner.snapshot(f.runner).outcome)
    end)

    it('cancels only the edited child and lets its running sibling finish',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        local row
        for i,line in ipairs(f.editor.lines)do if line:find('(Tool result pending)',1,true)then row=i-1;break end end
        assert.is_not_nil(row)
        f.editor:edit(row,0,row,0,{'human '});f.drain()
        assert.equals(1,#f.producer.cancelled)
        first.events.outcome('cancelled_before_effect',{})
        f.producer.cancelled[1].resolved()
        second.events.outcome('known',{content='sibling result'});second.events.resolved();f.drain()
        local text=table.concat(f.editor.lines,'\n')
        assert.is_not_nil(text:find('human (Tool result pending)',1,true))
        assert.is_not_nil(text:find('sibling result',1,true))
        assert.equals(1,#f.requests)
        assert.is_false(first.events.outcome('known',{content='late output'}))
    end)

    it('enforces the round limit before serializing or starting another tool',function()
        local f=setup({max_iterations=1});f.round({calls[1]})
        local op=f.producer.started[1];op.events.outcome('known',{content='done'});op.events.resolved();f.drain()
        assert.equals(2,#f.requests)
        local before=table.concat(f.editor.lines,'\n')
        local request=f.requests[2]
        assert.has_error(function()f.adapter.on_result(request.ctx,{response='again'},calls)end,'tool iteration limit')
        assert.equals(1,#f.producer.started);assert.equals(before,table.concat(f.editor.lines,'\n'))
    end)
    it('keeps real read errors inside ordered result messages without exposing outside-root data',function()
        require('parley.tools').register_builtins()
        local root=vim.fn.tempname();vim.fn.mkdir(root..'/narrow','p')
        vim.fn.writefile({'DO NOT READ'},root..'/outside.txt')
        local f=setup({actual=true,root_policy={write_root=root..'/narrow',read_roots={root..'/narrow'}}})
        f.round({{id='outside',name='read_file',input={path=root..'/outside.txt'}}})
        assert.equals(2,#f.requests)
        local result=f.requests[2].ctx.input.messages[3].content[1]
        assert.is_true(result.is_error)
        assert.truthy(result.content:find('configured read roots',1,true))
        assert.is_nil(table.concat(f.editor.lines,'\n'):find('DO NOT READ',1,true))
    end)
    it('widens reads while keeping real writes rooted in the captured nested directory',function()
        require('parley.tools').register_builtins()
        local root=vim.fn.tempname();local nested=root..'/data/nested';vim.fn.mkdir(nested,'p')
        vim.fn.writefile({'root content'},root..'/README.md')
        local f=setup({actual=true,root_policy={write_root=nested,read_roots={nested,root}}})
        f.round({{id='read-root',name='read_file',input={path='../../README.md'}},
            {id='bare',name='read_file',input={path='README.md'}}})
        assert.equals(2,#f.requests)
        local results=f.requests[2].ctx.input.messages[3].content
        assert.truthy(results[1].content:find('root content',1,true));assert.is_true(results[2].is_error)
        f.round({{id='write-nested',name='write_file',input={path='README.md',content='nested content'}}})
        assert.equals(3,#f.requests)
        assert.same({'nested content'},vim.fn.readfile(nested..'/README.md'))
        assert.same({'root content'},vim.fn.readfile(root..'/README.md'))
    end)
    it('serializes real backtick-containing tool results without closing their surrounding fence',function()
        require('parley.tools').register_builtins()
        local root=vim.fn.tempname();vim.fn.mkdir(root,'p')
        vim.fn.writefile({'```lua','local x = 1','```'},root..'/code.md')
        local f=setup({actual=true,root_policy={write_root=root,read_roots={root}}})
        f.round({{id='code',name='read_file',input={path='code.md'}}})
        local text=table.concat(f.editor.lines,'\n')
        assert.truthy(text:find('````',1,true));assert.truthy(text:find('```lua',1,true))
        assert.equals(2,#f.requests)
        assert.truthy(f.requests[2].ctx.input.messages[3].content[1].content:find('local x = 1',1,true))
    end)

    local orders={
        {'physical','stop','ack','known'},{'physical','stop','known','ack'},
        {'stop','physical','ack','known'},{'stop','physical','known','ack'},
        {'stop','ack','physical','known'},{'stop','ack','known','physical'},
        {'stop','known','physical','ack'},{'stop','known','ack','physical'},
    }
    for _,mode in ipairs({'cancel','detach'})do for _,order in ipairs(orders)do
        it('joins late outcome and cleanup after '..mode..': '..table.concat(order,','),function()
            local f=setup();f.round({calls[1]});local op=f.producer.started[1]
            op.events.outcome('unknown',{content='awaiting confirmation'});f.drain()
            local before=table.concat(f.editor.lines,'\n')
            for _,event in ipairs(order)do
                if event=='physical'then op.events.resolved();op.events.resolved()
                elseif event=='stop'then
                    if mode=='detach'then D.detach(f.doc)else Runner.cancel(f.runner)end
                elseif event=='ack'then
                    assert.equals(1,#f.producer.cancelled)
                    f.producer.cancelled[1].resolved();f.producer.cancelled[1].resolved()
                else
                    assert.is_true(op.events.outcome('known',{content='confirmed after cancellation'}))
                    assert.is_false(op.events.outcome('known',{content='duplicate'}))
                end
                f.drain()
                if event~='known' and op.events.outcome('unknown',{})then error('duplicate unknown accepted')end
            end
            assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
            assert.equals('terminal',Runner.snapshot(f.runner).phase)
            assert.is_true(f.adapter.close())
            assert.equals(before,table.concat(f.editor.lines,'\n'));assert.equals(1,#f.requests)
        end)
    end end
    it('reserves publication before a reentrant physical-resolution callback',function()
        local f
        f=setup({on_outcome=function(kind)
            if kind=='known'then f.producer.started[1].events.resolved()end
        end})
        f.round({calls[1]});local op=f.producer.started[1]
        assert.is_true(op.events.outcome('known',{content='published before retirement'}));f.drain()
        assert.truthy(table.concat(f.editor.lines,'\n'):find('published before retirement',1,true))
        assert.equals(2,#f.requests)
        f.requests[2].cb.complete();f.requests[2].cb.resolved();f.drain()
        assert.equals('terminal',Runner.snapshot(f.runner).phase)
    end)

    for _,outcome in ipairs({'rejected','cancelled_before_effect'})do
        it('joins early physical cleanup with later '..outcome,function()
            local f=setup();f.round({calls[1]});local op=f.producer.started[1]
            op.events.resolved();op.events.resolved()
            assert.is_true(op.events.outcome(outcome,{content='not executed'}));f.drain()
            assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
            assert.equals(1,#f.requests)
            Runner.cancel(f.runner);f.drain();assert.equals('terminal',Runner.snapshot(f.runner).phase)
        end)
    end
    it('waits for the publication decision when cancellation overtakes a known result',function()
        local f=setup();f.round({calls[1]});local op=f.producer.started[1]
        local before=table.concat(f.editor.lines,'\n')
        op.events.outcome('known',{content='must not publish after cancellation'})
        op.events.resolved();Runner.cancel(f.runner);f.drain()
        for _,cancel in ipairs(f.producer.cancelled)do cancel.resolved()end
        f.drain()
        assert.equals('terminal',Runner.snapshot(f.runner).phase)
        assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
        assert.equals(before,table.concat(f.editor.lines,'\n'));assert.is_true(f.adapter.close())
    end)

end)
