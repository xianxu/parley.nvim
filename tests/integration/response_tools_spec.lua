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
        buf=serial,allowed_tools=options.actual and {'read_file','write_file'} or {},
        max_iterations=options.max_iterations,max_result_bytes=options.max_result_bytes,build_input=function(previous,messages)
        previous.messages=messages;previous.payload={model='fixture',messages=messages};return previous
    end})
    local hooks={prepare=function(ctx,cb)cb.prepared(ctx.input);cb.resolved()end,
        request=function(ctx,cb)requests[#requests+1]={ctx=ctx,cb=cb};return {}end,
        finalize=function(_,done)done('applied')end,terminal=adapter.close,
        insert_tool=adapter.insert_tool,start_child=function(ctx,cb)
            if options.on_outcome then
                local outcome=cb.outcome
                cb.outcome=function(kind,value)local accepted=outcome(kind,value);options.on_outcome(kind);return accepted end
            end
            return adapter.start_child(ctx,cb)
        end,continue_round=adapter.continue_round,
        cancel_operation=adapter.cancel_operation}
    local marker=D.query(doc,0,1)[1];local body=D.query(doc,2,3)[1]
    local runner=assert(Runner.start(doc,{entity=marker.handle,first=marker.end_byte-1,last=body.end_byte-1,
        input={messages={{role='user',content='question'}},payload={}},schedule=false},hooks));runners[#runners+1]=runner
    -- To quiescence, as Runner.drain does: nothing queued in the runner and the
    -- document repaired. A fixed step count burned 2000 steps per call whenever
    -- the runner waited on an external event, which a Stop's flush does.
    local function drain()
        for _=1,2000 do
            local repair=D.repair_step(doc);local step=Runner.step(runner)
            if step.status=='terminal' or step.status=='waiting' and repair.status=='idle' then return end
        end
    end
    -- Bounded: `n` runner steps, so a test can look between the slices of one
    -- multi-chunk write (drain runs to quiescence and cannot).
    local function step(n)for _=1,n do D.repair_step(doc);Runner.step(runner)end end
    drain()
    local function round(calls)
        local req=requests[#requests]
        adapter.on_result(req.ctx,{response='tool text'},calls)
        local declared={};for i,c in ipairs(calls)do declared[i]={call_id=c.id,arguments=c}end
        local expected=#requests+1
        assert.is_true(req.cb.round(declared));req.cb.resolved();drain()
        if options.actual then assert.is_true(vim.wait(5000,function()
            drain();return #requests>=expected
        end,1),'asynchronous real tool round did not settle')end
    end
    local fixture={doc=doc,editor=editor,producer=producer,requests=requests,runner=runner,adapter=adapter,drain=drain,step=step,round=round}
    fixtures[#fixtures+1]=fixture
    return fixture
end
local calls={{id='a',name='read_file',input={path='a'}},{id='b',name='read_file',input={path='b'}}}
describe('production concurrent tool round composition',function()
    it('keeps upstream incompleteness visible in transcript and both provider continuations at tiny caps',function()
        local f=setup({max_result_bytes=8});f.round({calls[1]})
        local op=f.producer.started[1]
        op.events.outcome('known',{content='partial',truncated=true,is_error=false});op.events.resolved();f.drain()
        local messages=f.requests[2].ctx.input.messages
        local block=messages[#messages].content[1]
        assert.equals('[Tool result incomplete]\n',block.content)
        local openai=require('parley.tools.wire_openai').translate_messages(messages)
        assert.equals(block.content,openai[#openai].content)
        local lines=f.editor.lines
        assert.truthy(table.concat(lines,'\n'):find('[Tool result incomplete]',1,true))
    end)
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
    local function text(f)return table.concat(f.editor.lines,'\n')end
    -- Where each tool block starts in the transcript, or nil.
    local function at(f,marker,id)return text(f):find(marker..' read_file id='..id,1,true)end

    for _,stop in ipairs({'pending','reload'})do
        it('writes nothing but the blocks already due when the round is left '..stop,function()
            local f=setup();f.round(calls)
            assert.equals(2,#f.producer.started,'both tools run at once')
            if stop=='reload'then f.editor:reload(f.editor.lines);f.drain()end
            local results,wire,openai=projected(f)
            assert.same({},results,'no result without an outcome')
            assert.is_not_nil(at(f,'🔧:','a'),'the first call block is written before any outcome')
            assert.is_nil(at(f,'🔧:','b'),'the second waits behind the first result')
            assert.is_nil(text(f):find('pending',1,true),'no placeholder is ever written')
            assert.is_true(wire.a.is_error,'an unanswered call stays unanswered on the wire')
            assert.is_truthy(openai.a:find(wire.a.content,1,true))
            assert.equals(1,#f.requests,'no continuation without every result')
        end)
    end

    -- #266 M3 (operator): Stop during a tool round writes the round out — every
    -- running tool cancelled, each pair in order, a finished tool's real result,
    -- the rest "cancelled by the user" — then the answer ends. Nothing dropped.
    it('writes the whole round out when stopped mid-round',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        second.events.outcome('known',{content='second finished'});f.drain()
        Runner.cancel(f.runner);f.drain()
        assert.equals(first,f.producer.cancelled[1].op,'the running tool is cancelled at the Stop')
        assert.is_nil(at(f,'📎:','a'),'its result waits for the cancellation to settle')
        -- As the real producer does for a running tool: hand it to its supervisor.
        f.producer.cancelled[1].resolved({supervised=true});f.drain()
        local results=projected(f)
        assert.is_true(results.a.is_error)
        assert.truthy(results.a.content:find('Cancelled by the user while running',1,true),results.a.content)
        assert.equals('second finished',results.b.content)
        local ca,ra,cb,rb=at(f,'🔧:','a'),at(f,'📎:','a'),at(f,'🔧:','b'),at(f,'📎:','b')
        assert.is_true(ca<ra and ra<cb and cb<rb)
        local before=text(f)
        assert.is_false(first.events.outcome('known',{content='too late'}))
        for _,c in ipairs(f.producer.cancelled)do c.resolved({supervised=true})end
        second.events.resolved();first.events.resolved();f.drain()
        assert.equals(before,text(f),'a cancelled call\'s late result changes nothing')
        assert.equals('terminal',Runner.snapshot(f.runner).phase)
        assert.equals('cancelled',Runner.snapshot(f.runner).outcome)
        assert.equals(1,#f.requests,'no continuation after a Stop')
    end)

    -- #266 M2 (operator, 2026-09-18): a failed call is written as an ordinary
    -- error result the model reads, and the round goes on — no pause.
    for _,failure in ipairs({'unknown','rejected','cancelled_before_effect'})do
        it('writes a '..failure..' outcome as an error result and continues the round',function()
            local f=setup();f.round(calls)
            local first,second=unpack(f.producer.started)
            first.events.outcome(failure,{content='detail from the producer'});first.events.resolved()
            second.events.outcome('known',{content='second result'});second.events.resolved();f.drain()
            assert.equals(2,#f.requests,'the round continued')
            assert.equals('requesting',Runner.snapshot(f.runner).phase)
            local results,wire=projected(f)
            assert.is_true(results.a.is_error)
            assert.truthy(results.a.content:find('detail from the producer',1,true))
            assert.equals('second result',results.b.content)
            local messages=f.requests[2].ctx.input.messages
            local sent=messages[#messages].content[1]
            assert.equals(results.a.content,sent.content,'the model reads exactly what the transcript says')
            assert.is_true(sent.is_error);assert.same(wire.a.content,sent.content)
        end)
    end

    it('holds a result that arrives early until the one before it is written',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        second.events.outcome('known',{content='confirmed second'});second.events.resolved();f.drain()
        local results=projected(f)
        assert.same({},results,'b arrived first but is held behind a')
        assert.is_nil(at(f,'🔧:','b'))
        first.events.outcome('known',{content='confirmed first'});first.events.resolved();f.drain()
        results=projected(f)
        assert.equals('confirmed first',results.a.content);assert.equals('confirmed second',results.b.content)
    end)

    it('writes each call block immediately before its own result',function()
        local f=setup();f.round(calls)
        local round=Runner.snapshot(f.runner).round
        assert.equals(2,#f.producer.started,'execution stays concurrent')
        local first,second=unpack(f.producer.started)
        second.events.outcome('known',{content='second'});second.events.resolved();f.drain()
        first.events.outcome('known',{content='first'});first.events.resolved();f.drain()
        local ca,ra,cb,rb=at(f,'🔧:','a'),at(f,'📎:','a'),at(f,'🔧:','b'),at(f,'📎:','b')
        assert.is_true(ca<ra and ra<cb and cb<rb,'call a, result a, call b, result b')
        assert.is_nil(text(f):find('(Tool result pending)',1,true))
        assert.truthy(text(f):find('\ntext\n\n🔧: read_file id=a',1,true),'a blank line after the answer text')
        assert.truthy(text(f):find('```\n\n📎: read_file id=a',1,true),'a blank line between blocks')
        assert.equals(2,#f.requests)
        -- ARCH-FUNERAL: continuing the round collects its frozen record, so a
        -- block can no longer be rendered from it.
        assert.has_error(function()
            f.adapter.insert_tool({round=round,index=1,kind='call',call_id='a',
                epoch=D.snapshot(f.doc).epoch,generation=Runner.snapshot(f.runner).generation},function()end)
        end,'missing frozen tool response')
    end)

    -- Task 3.2c Step 2: one result larger than a 4 KiB slice is written over
    -- several steps; the next call block must wait for all of it.
    it('never starts the next block while a multi-slice result is still being written',function()
        local f=setup();f.round(calls)
        local first,second=unpack(f.producer.started)
        second.events.outcome('known',{content='second'});second.events.resolved()
        first.events.outcome('known',{content=string.rep('x',10000)});first.events.resolved()
        local saw_partial=false
        for _=1,400 do
            f.step(1)
            local body=select(2,text(f):gsub('x',''))
            if body>0 and body<10000 then
                saw_partial=true
                assert.is_nil(at(f,'🔧:','b'),'call b landed inside result a')
            end
            if at(f,'📎:','b') then break end
        end
        assert.is_true(saw_partial,'the result must actually be written in slices')
        assert.is_true(at(f,'📎:','a')<at(f,'🔧:','b'))
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

    it('treats an unknown outcome as final once written, and does not wait for a confirmation',function()
        local f=setup();f.round({calls[1]})
        local op=f.producer.started[1]
        op.events.outcome('unknown',{content='not yet known'});op.events.resolved();f.drain()
        assert.equals(2,#f.requests,'continued without the operator')
        assert.is_false(op.events.outcome('known',{content='confirmed result'}),'too late to change what was written')
        assert.is_nil(text(f):find('confirmed result',1,true))
        f.requests[2].cb.complete();f.requests[2].cb.resolved();f.drain()
        assert.equals('success',Runner.snapshot(f.runner).outcome)
    end)

    -- A tool's slot no longer exists to be edited on its own: its blocks are the
    -- answer's text. An edit inside the answer while tools run revokes the answer.
    it('stops the whole round when a human edits inside the answer while its tools run',function()
        local f=setup();f.round(calls)
        local row
        for i,line in ipairs(f.editor.lines)do if line:find('🔧: read_file id=a',1,true)then row=i-1;break end end
        assert.is_not_nil(row)
        f.editor:edit(row,0,row,0,{'human '});f.drain()
        assert.equals(2,#f.producer.cancelled,'both running tools are cancelled')
        for _,op in ipairs(f.producer.started)do op.events.outcome('known',{content='late output'})end
        for _,cancellation in ipairs(f.producer.cancelled)do cancellation.resolved()end
        f.drain()
        assert.equals('terminal',Runner.snapshot(f.runner).phase)
        assert.equals('revoked',Runner.snapshot(f.runner).outcome)
        assert.is_nil(text(f):find('late output',1,true),'nothing is written once the answer is revoked')
        assert.truthy(text(f):find('human 🔧:',1,true),'the human edit stands')
        assert.equals(1,#f.requests)
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

    -- An unknown outcome is written at once, so a confirmation can never change
    -- it; what races is the stop against the tool's cleanup. (Cleanup before the
    -- stop simply continues the round — see the unknown case above.)
    local orders={
        {'stop','physical','ack','known'},{'stop','physical','known','ack'},
        {'stop','ack','physical','known'},{'stop','ack','known','physical'},
        {'stop','known','physical','ack'},{'stop','known','ack','physical'},
    }
    for _,mode in ipairs({'cancel','detach'})do for _,order in ipairs(orders)do
        it('joins late outcome and cleanup after '..mode..': '..table.concat(order,','),function()
            local f=setup();f.round({calls[1]});local op=f.producer.started[1]
            op.events.outcome('unknown',{content='awaiting confirmation'});f.drain()
            local before=table.concat(f.editor.lines,'\n')
            assert.truthy(before:find('awaiting confirmation',1,true),'written before anything else happens')
            for _,event in ipairs(order)do
                if event=='physical'then op.events.resolved();op.events.resolved()
                elseif event=='stop'then
                    if mode=='detach'then D.detach(f.doc)else Runner.cancel(f.runner)end
                elseif event=='ack'then
                    assert.equals(1,#f.producer.cancelled)
                    f.producer.cancelled[1].resolved();f.producer.cancelled[1].resolved()
                else
                    assert.is_false(op.events.outcome('known',{content='confirmed after cancellation'}))
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

    -- #266 M2 Task 3.3 Step 1: every interleaving of two outcomes, a stop and
    -- the tools' cleanup. Whatever the order, the transcript only ever holds an
    -- in-order prefix of call a, result a, call b, result b; nothing lands after
    -- the stop; and the round continues exactly when everything came first.
    local function permutations(items)
        if #items<=1 then return {items} end
        local out={}
        for i,item in ipairs(items)do
            local rest={};for j,other in ipairs(items)do if j~=i then rest[#rest+1]=other end end
            for _,tail in ipairs(permutations(rest))do out[#out+1]={item,unpack(tail)}end
        end
        return out
    end
    local blocks={{'🔧:','a'},{'📎:','a'},{'🔧:','b'},{'📎:','b'}}
    local function assert_prefix(f,label)
        local previous,missing=0,false
        for _,b in ipairs(blocks)do
            local position=at(f,b[1],b[2])
            if position then
                assert.is_false(missing,label..': '..b[1]..b[2]..' written after a hole')
                assert.is_true(position>previous,label..': '..b[1]..b[2]..' out of order');previous=position
            else missing=true end
        end
    end
    for _,mode in ipairs({'cancel','detach'})do
        for _,order in ipairs(permutations({'first','second','stop','cleanup'}))do
            local label=mode..': '..table.concat(order,',')
            it('keeps an in-order prefix through '..label,function()
                local f=setup();f.round(calls)
                local first,second=unpack(f.producer.started)
                local frozen
                for _,event in ipairs(order)do
                    if event=='first'then first.events.outcome('known',{content='one'})
                    elseif event=='second'then second.events.outcome('known',{content='two'})
                    elseif event=='stop'then
                        if mode=='detach'then D.detach(f.doc)else Runner.cancel(f.runner)end
                    else
                        -- Cleanup: tools report it; a cancelled running tool is
                        -- handed to its supervisor, as the real producer does.
                        first.events.resolved();second.events.resolved()
                        for _,c in ipairs(f.producer.cancelled)do c.resolved({supervised=true})end
                    end
                    f.drain();assert_prefix(f,label)
                    if mode=='detach' and frozen then assert.equals(frozen,text(f),label..': written after a detach')end
                    if event=='stop'then frozen=text(f)end
                end
                for _,c in ipairs(f.producer.cancelled)do c.resolved({supervised=true})end
                f.drain()
                if mode=='cancel'then
                    -- #266 M3: a Stop writes the whole round out, each result either
                    -- real or cancelled by the user — never an unknown failure.
                    for _,b in ipairs(blocks)do assert.is_not_nil(at(f,b[1],b[2]),label..': '..b[1]..b[2]..' missing')end
                    local results=projected(f)
                    for id,content in pairs({a='one',b='two'})do
                        local c=results[id].content
                        assert.is_true(c==content or c:find('Cancelled by the user',1,true)~=nil,label..': '..id..' '..c)
                    end
                    local before={};for i,event in ipairs(order)do before[event]=i end
                    for id,event in pairs({a='first',b='second'})do
                        if before[event]<before.stop then
                            assert.equals(id=='a' and 'one' or 'two',results[id].content,label..': an outcome before the Stop is written')
                        end
                    end
                end
                for _,request in ipairs(f.requests)do request.cb.resolved()end
                f.drain()
                assert.equals('terminal',Runner.snapshot(f.runner).phase,label)
                assert.equals(0,Runner.snapshot(f.runner).outstanding_operations,label)
                assert.is_true(f.adapter.close(),label)
                assert.equals(order[4]=='stop' and 2 or 1,#f.requests,label..': continuation')
            end)
        end
    end

    it('records the outcome before a reentrant physical-resolution callback',function()
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
            assert.equals(2,#f.requests,'the round continues past a failed call')
            Runner.cancel(f.runner);f.requests[2].cb.resolved();f.drain()
            assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
            assert.equals('terminal',Runner.snapshot(f.runner).phase)
        end)
    end
    -- M3 review BR-15: a tool whose start was still queued when the Stop landed
    -- never ran, and the transcript says so — not an unknown failure.
    it('writes a tool the Stop refused before it ran as cancelled before it ran',function()
        local f=setup()
        local req=f.requests[#f.requests]
        f.adapter.on_result(req.ctx,{response='tool text'},{calls[1]})
        assert.is_true(req.cb.round({{call_id='a',arguments=calls[1]}}));req.cb.resolved()
        Runner.cancel(f.runner);f.drain()
        assert.equals(0,#f.producer.started,'it never started')
        local results=projected(f)
        assert.truthy(results.a.content:find('Cancelled by the user before it ran',1,true),results.a.content)
        assert.equals('cancelled',Runner.snapshot(f.runner).outcome)
    end)

    -- #266 M3: a result that arrived before the Stop is part of the round the
    -- Stop writes out, even when its block had not landed yet.
    it('writes a result that arrived before the Stop, even if its block had not landed',function()
        local f=setup();f.round({calls[1]});local op=f.producer.started[1]
        op.events.outcome('known',{content='arrived before the stop'})
        op.events.resolved();Runner.cancel(f.runner);f.drain()
        for _,cancel in ipairs(f.producer.cancelled)do cancel.resolved()end
        f.drain()
        assert.equals('terminal',Runner.snapshot(f.runner).phase)
        assert.equals(0,Runner.snapshot(f.runner).outstanding_operations)
        assert.truthy(text(f):find('arrived before the stop',1,true));assert.is_true(f.adapter.close())
    end)

end)
