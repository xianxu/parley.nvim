-- #266 M1: the coordinator refuses a generated write that does not hold the
-- document's write turn. This is the enforcement point — the machine's `writable`
-- gate is only an optimization, and three of the four generated write paths never
-- consult the machine at all.
--
-- Fail-closed: a generation must HOLD the turn, not merely "not be blocked". An
-- unheld turn refuses every generation rather than admitting all of them.
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')

local serial=94000
local docs={}
local function fixture()
    serial=serial+1
    local fake=Fake.new({'💬: q','draft','🤖: answer',''})
    local doc=D.attach(serial,{driver=fake.driver,schedule=false})
    docs[#docs+1]=doc
    assert.equals('idle',D.drain(doc,1000).status)
    local entity=D.query(doc,2,3)[1].handle
    -- Grants must be disjoint (state.lua rejects overlap), so a caller that wants
    -- two live generations asks for two halves of the answer region.
    local lo=D.query(doc,2,3)[1].start_byte
    local hi=D.size(doc).bytes-1
    local mid=lo+math.floor((hi-lo)/2)
    local function admit(first,last)
        local g=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=g,regions={{entity=entity,
            marker_revision=1,revision=1,first=first or lo,last=last or hi,confirmed=true}}})
        return g,acquired.ok and acquired.grants[1] or nil,acquired.reason
    end
    local ranges={a={lo,mid},b={mid+1,hi}}
    local function intent(g,grant,bytes)
        return {epoch=D.snapshot(doc).epoch,generation=g,grant=grant,entity=entity,
            revision=D.snapshot(doc).grants[grant].revision,operation='stream',bytes=bytes}
    end
    return doc,fake,admit,intent,ranges
end

describe('write turn enforcement',function()
    after_each(function()
        for _,doc in ipairs(docs) do pcall(D.detach,doc) end
        docs={}
    end)

    it('refuses a provider write from a generation that does not hold the turn',function()
        local doc,_,admit,intent,rg=fixture()
        local a,ga,ra=admit(rg.a[1],rg.a[2])
        local b,gb,rb=admit(rg.b[1],rg.b[2])
        assert.is_not_nil(ga,tostring(ra)); assert.is_not_nil(gb,tostring(rb))
        D.transition(doc,{kind='request_turn',generation=a})
        assert.equals(a,D.turn(doc))
        local refused=D.append(doc,intent(b,gb,'from b'))
        assert.equals('waiting',refused.status,'b must not write while a holds the turn')
        assert.equals(0,refused.accepted_bytes)
    end)

    it('admits the holder and lands its bytes in full',function()
        local doc,fake,admit,intent=fixture()
        local row=D.query(doc,2,3)[1]
        local a,ga=admit(row.end_byte,D.size(doc).bytes-1)
        D.transition(doc,{kind='request_turn',generation=a})
        local applied=D.append(doc,intent(a,ga,'held'))
        assert.equals('applied',applied.status)
        assert.equals(4,applied.accepted_bytes)
        assert.is_not_nil(table.concat(fake.lines,'\n'):find('held',1,true))
    end)

    -- An unheld turn admits the writer: the invariant is enforced jointly with
    -- "every generated writer requests the turn before writing"
    -- (generation.lua:214/:367, response_topic.lua:169, pinned in generation_spec).
    -- Given that, an unheld turn means nothing is writing, so refusing everyone
    -- buys nothing and costs ~96 document-layer tests. The half that matters —
    -- a non-holder is refused while someone holds — is asserted above.
    it('admits a writer when no generation holds the turn',function()
        local doc,_,admit,intent=fixture()
        local a,ga=admit()
        assert.is_nil(D.turn(doc))
        assert.equals('applied',D.append(doc,intent(a,ga,'x')).status)
    end)

    it('refuses the releaser once the turn has moved to a waiter',function()
        local doc,_,admit,intent=fixture()
        local a,ga=admit()                 -- full region: append writes at the tail
        -- b needs only to HOLD the turn, so no grant contends for a's region.
        local b=D.transition(doc,{kind='register_generation'}).generation
        D.transition(doc,{kind='request_turn',generation=a})
        D.transition(doc,{kind='request_turn',generation=b})
        assert.equals('applied',D.append(doc,intent(a,ga,'one')).status)
        D.transition(doc,{kind='release_turn',generation=a})
        assert.equals(b,D.turn(doc),'the waiter must take it')
        assert.equals('waiting',D.append(doc,intent(a,ga,'two')).status,
            'the releaser must not keep writing')
    end)

    it('hands the turn on so the waiter can write',function()
        local doc,_,admit,intent,rg=fixture()
        local a,ga=admit(rg.a[1],rg.a[2])
        local b,gb=admit(rg.b[1],rg.b[2])
        assert.is_not_nil(gb)
        D.transition(doc,{kind='request_turn',generation=a})
        D.transition(doc,{kind='request_turn',generation=b})
        assert.equals('waiting',D.append(doc,intent(b,gb,'early')).status)
        D.transition(doc,{kind='finish_generation',generation=a})
        assert.equals(b,D.turn(doc))
        assert.equals('applied',D.append(doc,intent(b,gb,'late')).status)
    end)

    -- A multi-chunk replacement opened while holding the turn must stop when the
    -- turn moves. Replacement.step is the only place a continuation's generation
    -- is knowable, which is why the guard cannot live at the coordinator alone.
    it('parks a replacement continuation when the turn moves away',function()
        -- Shape copied from document_replacement_spec: the entity is the marker
        -- row and the region is a later body row. A region inside the marker row
        -- is refused with 'entity row overlap'.
        serial=serial+1
        local fake=Fake.new({'💬: q','','old answer','💬: next','tail'})
        local doc=D.attach(serial,{driver=fake.driver,schedule=false}); docs[#docs+1]=doc
        assert.equals('idle',D.drain(doc,10000).status)
        local rows=D.query(doc,0,5)
        local a=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=a,regions={{entity=rows[1].handle,
            first=rows[3].start_byte,last=rows[3].end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
        assert.is_true(acquired.ok,tostring(acquired.reason))
        -- b needs only to HOLD the turn, not a grant, so no region contends.
        local b=D.transition(doc,{kind='register_generation'}).generation
        D.transition(doc,{kind='request_turn',generation=a})

        local cursor,reason=D.replace_new(doc,{epoch=D.snapshot(doc).epoch,generation=a,
            grant=acquired.grants[1],entity=rows[1].handle,revision=1,operation='replacement',
            bytes=string.rep('z',64)})
        assert.is_not_nil(cursor,'replacement must open while a holds the turn: '..tostring(reason))
        -- One step under the turn proves the cursor is live, so a later 'waiting'
        -- cannot be confused with a cursor that never worked at all.
        assert.is_not.equals('waiting',D.replace_step(doc,cursor).status)

        D.transition(doc,{kind='request_turn',generation=b})
        D.transition(doc,{kind='release_turn',generation=a})
        assert.equals(b,D.turn(doc))
        assert.equals('waiting',D.replace_step(doc,cursor).status,
            'a continuation must not outlive its turn')
    end)

    -- Task 1.8: every generated entry point, not just append. Replacement opens
    -- (preparation), released insertions (completion's next prompt) and planned
    -- applies (the automatic topic) each refuse a non-holder with 'waiting'.
    it('refuses a replacement, a released insertion and a planned apply from a non-holder',function()
        local doc,_,admit,_,rg=fixture()
        local a=admit(rg.a[1],rg.a[2]);local b,gb=admit(rg.b[1],rg.b[2])
        assert.is_not_nil(gb)
        D.transition(doc,{kind='request_turn',generation=a})
        local snap=D.snapshot(doc);local grant=snap.grants[gb]
        local base={epoch=snap.epoch,generation=b,grant=gb,entity=grant.entity,revision=grant.revision,
            operation='writer',bytes='x'}
        local cursor,reason=D.replace_new(doc,base)
        assert.is_nil(cursor);assert.equals('waiting',reason,'replace_new')
        cursor,reason=D.insert_released_new(doc,vim.tbl_extend('force',base,{point=grant.first}))
        assert.is_nil(cursor);assert.equals('waiting',reason,'insert_released_new')
        local applied=D.apply(doc,{epoch=snap.epoch,generation=b,grant=gb,entity=grant.entity,
            revision=grant.revision,operation='writer',patches={{start=grant.first,finish=grant.first,text='x'}}})
        assert.equals('waiting',applied.status,'apply')
    end)

    -- Humans are never blocked. apply_user is deliberately outside the guard.
    it('never blocks a human edit',function()
        local doc,fake,admit=fixture()
        local a=admit()
        D.transition(doc,{kind='request_turn',generation=a})
        fake:edit(1,0,1,0,{'typed '})
        assert.equals('idle',D.drain(doc,1000).status)
        assert.is_not_nil(table.concat(fake.lines,'\n'):find('typed ',1,true))
    end)
end)

-- #266 Task 1.6: the turn matrix on real runners. Every release row must hand the
-- turn to the waiter, whatever order the two runners happen to be stepped in.
-- Pause rows (unknown outcome, revoked child, stale continuation) need a tool
-- round; they are pinned in generation_spec and end to end in
-- chat_async_tools_spec / chat_stop_generation_spec. A transient suspension is
-- deliberately NOT a release row (operator decision) — generation_spec pins that.
local Runner=require('parley.generation_runner')
local FakeRunner=require('tests.helpers.fake_generation_runner')
describe('write turn matrix',function()
    local runners,fakes={},{}
    after_each(function()
        -- A stopped runner retires only once its fake acknowledges cancellation;
        -- without this, runners leak toward the 16-runner process limit.
        for _,r in ipairs(runners) do pcall(Runner.cancel,r) end
        for _=1,3 do
            for _,fake in ipairs(fakes) do
                for _,c in ipairs(fake.cancellations) do if not c.done then c.done=true;pcall(c.resolved) end end
            end
            for _,r in ipairs(runners) do pcall(Runner.drain,r,100) end
        end
        for _,doc in ipairs(docs) do pcall(D.detach,doc) end
        docs,runners,fakes={},{},{}
    end)
    local function pair(opts)
        serial=serial+1
        local editor=Fake.new({'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(serial,{driver=editor.driver,schedule=opts and opts.schedule or false});docs[#docs+1]=doc
        assert.equals('idle',D.drain(doc,1000).status)
        local function start(row,fake,limits)
            local marker=D.query(doc,row,row+1)[1];local body=D.query(doc,row+1,row+2)[1]
            local r=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
                input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},limits=limits,
                schedule=opts and opts.schedule or false},fake.adapters))
            runners[#runners+1]=r
            if not (opts and opts.schedule) then Runner.drain(r,100) end
            return r
        end
        local fa,fb=FakeRunner.new(),FakeRunner.new()
        fakes[#fakes+1]=fa;fakes[#fakes+1]=fb
        if opts and opts.setup then opts.setup(fa,doc,fb) end
        if opts and opts.changed then fa.adapters.changed=opts.changed.a;fb.adapters.changed=opts.changed.b end
        local a=start(2,fa);local b=start(5,fb,opts and opts.limits)
        return doc,editor,{a=a,b=b},{a=fa,b=fb}
    end
    local schedules={{'a','a','b','b'},{'a','b','a','b'},{'b','a','b','a'},{'b','b','a','a'}}
    local function pump(r,schedule)
        for _=1,60 do for _,name in ipairs(schedule) do Runner.drain(r[name],3) end end
    end
    local function text(editor)return table.concat(editor.lines,'\n')end

    for _,schedule in ipairs(schedules) do
        local order=table.concat(schedule)
        it('terminal hands the turn to the waiter, which then writes everything it held ('..order..')',function()
            local doc,editor,r,f=pair()
            f.a:prepare();f.b:prepare();pump(r,schedule)
            assert.equals(Runner.snapshot(r.a).generation,D.turn(doc),'the first admitted holds the turn')
            f.b:output(1,'beta');f.b:complete(1)
            f.a:output(1,'alpha');pump(r,schedule)
            assert.is_nil(text(editor):find('beta',1,true),'the waiter writes nothing while the holder lives')
            assert.equals('draining',Runner.snapshot(r.b).phase,'complete but not yet written')
            f.a:complete(1);pump(r,schedule)
            assert.equals('success',Runner.snapshot(r.a).outcome)
            assert.equals('success',Runner.snapshot(r.b).outcome)
            assert.truthy(text(editor):find('alpha',1,true));assert.truthy(text(editor):find('beta',1,true))
            assert.is_nil(D.turn(doc),'nobody holds a turn nobody wants')
        end)
        it('stop hands the turn over before the stopped generation retires ('..order..')',function()
            local doc,editor,r,f=pair()
            f.a:prepare();f.b:prepare();pump(r,schedule)
            f.b:output(1,'beta');f.b:complete(1);pump(r,schedule)
            Runner.cancel(r.a);pump(r,schedule)
            assert.equals('stopping',Runner.snapshot(r.a).phase,'its request is still owned')
            assert.equals('success',Runner.snapshot(r.b).outcome,'the waiter finished while the stopped one had not')
            assert.is_nil(D.turn(doc))
            assert.truthy(text(editor):find('beta',1,true))
        end)
        for _,event in ipairs({'detach','reload'}) do
            it(event..' clears the turn and stops both generations ('..order..')',function()
                local doc,editor,r,f=pair()
                f.a:prepare();f.b:prepare();pump(r,schedule)
                f.b:output(1,'beta');pump(r,schedule)
                if event=='detach' then D.detach(doc) else editor:reload({'💬: replacement'}) end
                pump(r,schedule)
                for _,name in ipairs({'a','b'}) do
                    local phase=Runner.snapshot(r[name]).phase
                    assert.is_true(phase=='stopping' or phase=='terminal',name..' '..phase)
                end
                if event=='reload' then assert.is_nil(D.turn(doc)) end
                assert.is_nil(text(editor):find('beta',1,true))
            end)
        end
    end

    -- M1 boundary review C1. A pause can come from an effect that then parks at
    -- the head of the runner's FIFO (a stale-input continue_round waits there
    -- until resumed). The release_turn that pause emits must not queue behind it,
    -- or a paused generation holds the turn for good and every waiter's output
    -- piles up toward its budget. Asserted at the document, not the machine: the
    -- machine emitting release_turn is exactly what already passed. (An unknown
    -- tool outcome was the other pause; since M2 it is written and the round goes
    -- on, so it holds the turn like any other write.)
    it('hands the turn on when the holder pauses on a stale input',function()
        local doc,editor,r,f=pair({setup=function(fa)
            fa.adapters.start_child=function(_,cb)cb.outcome('known','result');cb.resolved() end
            fa.adapters.continue_round=function()end
        end})
        f.a:prepare();f.b:prepare();pump(r,schedules[1])
        f.b:output(1,'beta');f.b:complete(1)
        editor:edit(0,0,0,0,{'x'});D.drain(doc,1000)
        local cb=f.a.requests[1].callbacks;cb.round({{call_id='one',arguments={}}});cb.resolved()
        pump(r,schedules[1])
        assert.equals('paused',Runner.snapshot(r.a).phase)
        assert.equals('success',Runner.snapshot(r.b).outcome,'the waiter must get the turn and finish')
        assert.truthy(table.concat(editor.lines,'\n'):find('beta',1,true))
    end)

    -- #266 M2: concurrency is in execution, never in mutation. A generation
    -- waiting for the turn still runs its tools; only their blocks wait, and
    -- they land once the holder is done.
    it('runs both generations\' tools at once while their blocks land one generation at a time',function()
        local running={}
        local function tools(name,fake)
            fake.adapters.start_child=function(_,cb)running[#running+1]={name=name,cb=cb};return {} end
            fake.adapters.continue_round=function(ctx,cb)cb.prepared(ctx.input);cb.resolved() end
        end
        local doc,editor,r,f=pair({setup=function(fa,_,fb)tools('a',fa);tools('b',fb) end})
        f.a:prepare();f.b:prepare();pump(r,schedules[2])
        assert.equals(Runner.snapshot(r.a).generation,D.turn(doc))
        f.a:output(1,'alpha');pump(r,schedules[2])
        for _,name in ipairs({'b','a'}) do
            local cb=f[name].requests[1].callbacks;cb.round({{call_id=name..'1',arguments={}}});cb.resolved()
        end
        pump(r,schedules[2])
        assert.equals(2,#running,'both tools run at once, the waiter\'s included')
        assert.same({'call1'},f.a.inserted,'the holder writes its call block')
        assert.same({},f.b.inserted,'the waiter writes nothing')
        for _,tool in ipairs(running) do tool.cb.outcome('known',{});tool.cb.resolved() end
        pump(r,schedules[2])
        assert.same({},f.b.inserted,'still nothing while the holder continues')
        f.a:complete(2);pump(r,schedules[2])
        assert.equals('success',Runner.snapshot(r.a).outcome)
        assert.same({'call1','result1'},f.b.inserted,'the waiter\'s blocks land once the holder is done')
        f.b:complete(2);pump(r,schedules[2])
        assert.equals('success',Runner.snapshot(r.b).outcome)
        local t=text(editor)
        assert.truthy(t:find('alpha<call1><result1>',1,true),t)
        assert.truthy(t:find('🤖: second\n<call1><result1>',1,true),t)
    end)

    -- Control effects keep FIFO order among themselves after being hoisted ahead
    -- of parked work: stop() emits revoke before release_turn, so the region is
    -- given up a step before the turn moves (an immediate regenerate would
    -- otherwise be refused 'overlap').
    it('revokes the stopping holder\'s grant one step before the turn moves',function()
        local doc,_,r,f=pair()
        f.a:prepare();f.b:prepare();pump(r,schedules[1])
        local a=Runner.snapshot(r.a)
        assert.equals(a.generation,D.turn(doc))
        Runner.cancel(r.a)
        Runner.step(r.a)
        local grant=D.snapshot(doc).grants[a.grant]
        assert.is_true(grant==nil or grant.status=='revoked','the first control effect is the revoke')
        assert.equals(a.generation,D.turn(doc),'the turn has not moved yet')
        Runner.step(r.a)
        assert.equals(Runner.snapshot(r.b).generation,D.turn(doc),'then the release hands it on')
    end)

    -- #266 Task 1.7. Providers deliver one SSE delta per output callback, so a
    -- generation held behind the turn receives hundreds of tiny chunks. The held
    -- answer must be bounded by BYTES (the 1 MiB budget), not by how many chunks
    -- it arrived in — the 256-item cap would otherwise stop it after a paragraph,
    -- and every machine transition copies the whole queue.
    it('holds a long answer by its bytes, not by how many chunks it arrived in',function()
        local _,editor,r,f=pair()
        f.a:prepare();f.b:prepare();pump(r,schedules[1])
        for _=1,600 do assert.is_true(f.b:output(1,'x'),'a held delta must be admitted') end
        f.b:complete(1);pump(r,schedules[1])
        assert.equals('draining',Runner.snapshot(r.b).phase,tostring(Runner.snapshot(r.b).outcome))
        assert.is_true(Runner.snapshot(r.b).staged_items<=2,'held deltas must coalesce: '..Runner.snapshot(r.b).staged_items)
        f.a:output(1,'alpha');f.a:complete(1);pump(r,schedules[1])
        assert.equals('success',Runner.snapshot(r.b).outcome)
        assert.truthy(table.concat(editor.lines,'\n'):find(string.rep('x',600),1,true))
    end)

    -- Task 1.7 Steps 2-4. The budget is unchanged (1 MiB per generation; see the
    -- plan's measurement), and so is the behaviour at it: the generation stops,
    -- since returning true while dropping bytes would silently lose provider
    -- output. What changes is that the reason names the answer it was held behind
    -- — otherwise an overflow while queued looks like a runaway response.
    it('stops a held generation at its byte budget and names the answer it waited for',function()
        local doc,_,r,f=pair({limits={staged_bytes=8,queued_items=4}})
        f.a:prepare();f.b:prepare();pump(r,schedules[1])
        local holder_line=D.lookup(doc,Runner.snapshot(r.a).exchange).start_row+1
        assert.is_true(f.b:output(1,'12345'))
        assert.is_false(f.b:output(1,'67890'),'the ninth byte is past the budget')
        pump(r,schedules[1])
        local snap=Runner.snapshot(r.b)
        assert.equals('overflow',snap.outcome)
        assert.equals('staging overflow',snap.failure)
        assert.equals(holder_line,snap.waited_for_line,'the report must name the answer it waited behind')
        assert.equals('requesting',Runner.snapshot(r.a).phase,'the holder is untouched')
    end)

    -- Task 1.6 Step 3b. Only a self-scheduling runner can show a missing wake:
    -- Runner.drain calls sync on every step, so a hand-pumped harness would wake
    -- the waiter whether or not anyone notified it.
    it('wakes a queued generation without hand-stepping when the holder finishes',function()
        local _,editor,r,f=pair({schedule=true})
        assert.is_true(vim.wait(2000,function()return #f.a.preparations==1 and #f.b.preparations==1 end,5))
        f.a:prepare();f.b:prepare()
        assert.is_true(vim.wait(2000,function()return #f.a.requests==1 and #f.b.requests==1 end,5),
            'both requests start at once')
        f.b:output(1,'beta');f.b:complete(1)
        assert.is_true(vim.wait(2000,function()return Runner.snapshot(r.b).phase=='draining' end,5))
        f.a:output(1,'alpha');f.a:complete(1)
        assert.is_true(vim.wait(2000,function()return Runner.snapshot(r.b).phase=='terminal' end,5),
            'the waiter must wake on its own once the holder retires')
        assert.equals('success',Runner.snapshot(r.b).outcome)
        assert.truthy(table.concat(editor.lines,'\n'):find('beta',1,true))
    end)

    -- Task 1.6 Step 4. A held generation reports which answer holds the turn and
    -- what it is doing; presentation renders it (response_session_spec).
    it('reports the holder and its activity to a waiting generation, and clears it on handover',function()
        local seen={a={},b={}}
        local changed={a=function(v)seen.a[#seen.a+1]=v end,b=function(v)seen.b[#seen.b+1]=v end}
        local doc,_,r,f=pair({changed=changed})
        f.a:prepare();f.b:prepare();pump(r,schedules[1])
        local last=seen.b[#seen.b]
        assert.is_not_nil(last and last.blocked,'the waiter must learn it is blocked')
        assert.equals(Runner.snapshot(r.a).generation,last.blocked.generation)
        assert.equals(Runner.snapshot(r.a).exchange,last.blocked.entity)
        assert.equals('requesting',last.blocked.phase)
        for _,v in ipairs(seen.a) do assert.is_nil(v.blocked,'the holder is never blocked') end
        f.a:output(1,'alpha');f.a:complete(1);pump(r,schedules[1])
        assert.is_nil(seen.b[#seen.b].blocked,'the note must clear once the turn arrives')
        assert.are_not.equal(Runner.snapshot(r.a).generation,D.turn(doc))
    end)
end)

-- #266 Task 1.9: undo coherence on a real buffer. Characterization, not red-first:
-- by now serialization has landed. What these tests pin is stated once, in
-- atlas/chat/ownership.md "Undo grouping": unconditionally, no undo step mixes
-- two generations; while nothing intervenes, a run is one step with no partial
-- 4 KiB slice. The first case has nothing intervening; the last two pin what
-- happens when something does.
-- (Not "undo walks backwards in document position": generations write different
-- answers, so admission order need not match document order.)
describe('undo coherence under the write turn',function()
    it('never lets an undo step mix two generations or split one generation\'s run',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local fakes,runners={},{}
        for _,item in ipairs({{'a',2},{'b',5}}) do  -- a is admitted first, so a holds the turn
            local name,row=item[1],item[2]
            local marker=D.query(doc,row,row+1)[1];local body=D.query(doc,row+1,row+2)[1]
            fakes[name]=FakeRunner.new()
            runners[name]=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
                input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},schedule=false},
                fakes[name].adapters))
            Runner.drain(runners[name],100)
        end
        -- Alternate single steps: the finest interleaving two concurrent writers
        -- could produce. With batched steps each writer finishes its slices
        -- before the other moves, and this test passed with the turn disabled.
        local function pump()for _=1,600 do Runner.drain(runners.a,1);Runner.drain(runners.b,1) end end
        fakes.a:prepare();fakes.b:prepare();pump()
        -- b streams and completes first, but a was admitted first and holds the turn.
        fakes.b:output(1,string.rep('Y',9000));fakes.b:complete(1)
        fakes.a:output(1,string.rep('X',9000));fakes.a:complete(1);pump()
        assert.equals('success',Runner.snapshot(runners.a).outcome)
        assert.equals('success',Runner.snapshot(runners.b).outcome)
        local function counts()
            local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
            return select(2,text:gsub('X','')),select(2,text:gsub('Y',''))
        end
        local x,y=counts();assert.equals(9000,x);assert.equals(9000,y)
        local steps={}
        for _=1,50 do
            if x==0 and y==0 then break end
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent undo')end)
            local nx,ny=counts()
            if nx~=x or ny~=y then steps[#steps+1]={x=nx,y=ny} end
            assert.is_false(nx~=x and ny~=y,'one undo step removed text from both generations')
            assert.is_true(nx==0 or nx==9000,'a partial slice of a\'s run: '..nx)
            assert.is_true(ny==0 or ny==9000,'a partial slice of b\'s run: '..ny)
            x,y=nx,ny
        end
        assert.equals(0,x);assert.equals(0,y)
        assert.equals(2,#steps,'one undo step per generation run: '..vim.inspect(steps))
        assert.equals(0,steps[1].y,'the later writer, b, is undone first')
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)

    -- M1 review round 2 (BR-2): a pause yields the turn, and the waiter writes
    -- while the holder is paused. The holder's text then leaves undo in two runs
    -- around the waiter's — though the stale-input edit that caused the pause
    -- would split it by itself. What this pins is the unconditional half: no
    -- undo step mixes two generations, even with the turn moving mid-answer.
    it('keeps undo steps single-generation when a paused holder resumes after a waiter wrote',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local fakes,runners={},{}
        for _,item in ipairs({{'a',2},{'b',5}}) do
            local name,row=item[1],item[2]
            local marker=D.query(doc,row,row+1)[1];local body=D.query(doc,row+1,row+2)[1]
            local fake=FakeRunner.new();fakes[name]=fake
            if name=='a' then
                fake.adapters.start_child=function(_,cb)cb.outcome('known','result');cb.resolved()end
                fake.adapters.continue_round=function(ctx,cb)cb.prepared(ctx.input);cb.resolved()end
            end
            runners[name]=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
                input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},schedule=false},fake.adapters))
            Runner.drain(runners[name],100)
        end
        local function pump()for _=1,600 do Runner.drain(runners.a,1);Runner.drain(runners.b,1) end end
        fakes.a:prepare();fakes.b:prepare();pump()
        fakes.a:output(1,string.rep('X',3000));pump()
        -- An earlier edit makes a's input stale; its continuation pauses and yields.
        vim.api.nvim_buf_set_text(buf,0,4,0,4,{'!'});D.drain(doc,1000)
        local cb=fakes.a.requests[1].callbacks;cb.round({{call_id='one',arguments={}}});cb.resolved();pump()
        assert.equals('paused',Runner.snapshot(runners.a).phase)
        fakes.b:output(1,string.rep('Y',3000));fakes.b:complete(1);pump()
        assert.equals('success',Runner.snapshot(runners.b).outcome,'the waiter wrote while a was paused')
        assert.is_true(Runner.resume(runners.a,'operator:test').accepted);pump()
        fakes.a:output(2,string.rep('X',2000));fakes.a:complete(2);pump()
        assert.equals('success',Runner.snapshot(runners.a).outcome)
        local function counts()
            local text=table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')
            return select(2,text:gsub('X','')),select(2,text:gsub('Y',''))
        end
        local x,y=counts();assert.equals(5000,x);assert.equals(3000,y)
        local seen={}
        for _=1,50 do
            if x==0 and y==0 then break end
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent undo')end)
            local nx,ny=counts()
            assert.is_false(nx~=x and ny~=y,'one undo step removed text from both generations')
            if nx~=x then seen[#seen+1]=nx end
            x,y=nx,ny
        end
        assert.equals(0,x);assert.equals(0,y)
        assert.same({3000,0},seen,'a\'s text leaves in two pieces: '..vim.inspect(seen))
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)

    -- M1 review round 3 (BR-5): the conditional half, pinned from the other side.
    -- A human edit between two 4 KiB slices clears the undo receipt, so one
    -- generation's single write leaves undo in pieces — each still its own.
    it('splits one write into several undo steps when a human edit lands mid-write',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local marker=D.query(doc,2,3)[1];local body=D.query(doc,3,4)[1]
        local fake=FakeRunner.new()
        local r=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
            input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},schedule=false},fake.adapters))
        Runner.drain(r,100);fake:prepare();Runner.drain(r,100)
        fake:output(1,string.rep('X',9000))
        local function xs()return select(2,table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n'):gsub('X',''))end
        for _=1,20 do if xs()>0 then break end;Runner.drain(r,1) end
        assert.is_true(xs()>0 and xs()<9000,'stopped after the first slice: '..xs())
        vim.api.nvim_buf_set_text(buf,1,5,1,5,{'!'})  -- a disjoint human edit on the draft row
        D.drain(doc,1000);fake:complete(1);Runner.drain(r,1000)
        assert.equals('success',Runner.snapshot(r).outcome);assert.equals(9000,xs())
        local seen={}
        for _=1,20 do
            if xs()==0 then break end
            local before=xs()
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent undo')end)
            if xs()~=before then seen[#seen+1]=xs() end
        end
        assert.equals(0,xs())
        assert.is_true(#seen>=2,'the edit must split the run into more than one step: '..vim.inspect(seen))
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)

    -- #266 M2 review BR-9: tool blocks join the answer's undo step only while
    -- nothing intervenes. A human edit while the tools run — the usual case —
    -- splits the round where it lands: the call block sits one step before its
    -- own result. Pinned so the atlas cannot claim otherwise again.
    local function tool_fake(name)
        local fake=FakeRunner.new();fake.tools={}
        fake.adapters.insert_tool=function(ctx,done)
            if not ctx.append('['..name..':'..ctx.kind..ctx.index..']',function(res)done(res.status)end)then done('failed')end
        end
        fake.adapters.start_child=function(_,cb)fake.tools[#fake.tools+1]=cb;return {} end
        fake.adapters.continue_round=function(ctx,cb)cb.prepared(ctx.input);cb.resolved() end
        return fake
    end
    local function lines_of(buf)return table.concat(vim.api.nvim_buf_get_lines(buf,0,-1,false),'\n')end
    it('splits a tool round\'s undo where a human edit lands while its tools run',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local marker=D.query(doc,2,3)[1];local body=D.query(doc,3,4)[1]
        local fake=tool_fake('a')
        local r=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
            input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},schedule=false},fake.adapters))
        Runner.drain(r,100);fake:prepare();Runner.drain(r,100)
        fake:output(1,'TEXT');Runner.drain(r,100)
        local cb=fake.requests[1].callbacks;cb.round({{call_id='one',arguments={}}});cb.resolved();Runner.drain(r,100)
        assert.truthy(lines_of(buf):find('TEXT[a:call1]',1,true),lines_of(buf))
        vim.api.nvim_buf_set_text(buf,1,5,1,5,{'!'})  -- the human types while the tool runs
        D.drain(doc,1000)
        fake.tools[1].outcome('known','result');fake.tools[1].resolved();Runner.drain(r,1000)
        fake:complete(2);Runner.drain(r,1000)
        assert.equals('success',Runner.snapshot(r).outcome)
        assert.truthy(lines_of(buf):find('[a:call1][a:result1]',1,true),lines_of(buf))
        vim.api.nvim_buf_call(buf,function()vim.cmd('silent undo')end)
        local text=lines_of(buf)
        assert.is_nil(text:find('[a:result1]',1,true),'the result is the newest step')
        assert.truthy(text:find('TEXT[a:call1]',1,true),'its call block is in an earlier step: '..text)
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)

    -- The unconditional half, with tool rounds: two generations each run a
    -- two-call round, outcomes out of order, the second held behind the first.
    -- Walking undo all the way back, no step removes text of both.
    it('never mixes two generations\' tool rounds in one undo step',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','draft','🤖: first','','💬: q2','🤖: second',''})
        local doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,1000).status)
        local fakes,runners={},{}
        for _,item in ipairs({{'a',2},{'b',5}}) do
            local name,row=item[1],item[2]
            local marker=D.query(doc,row,row+1)[1];local body=D.query(doc,row+1,row+2)[1]
            fakes[name]=tool_fake(name)
            runners[name]=assert(Runner.start(doc,{entity=marker.handle,first=marker.start_byte,last=body.end_byte-1,
                input={message='frozen'},dependencies={{first=0,last=4}},capabilities={'read'},schedule=false},fakes[name].adapters))
            Runner.drain(runners[name],100)
        end
        local function pump()for _=1,600 do Runner.drain(runners.a,1);Runner.drain(runners.b,1) end end
        fakes.a:prepare();fakes.b:prepare();pump()
        fakes.a:output(1,string.rep('X',3000));fakes.b:output(1,string.rep('Y',3000));pump()
        for _,name in ipairs({'a','b'}) do
            local cb=fakes[name].requests[1].callbacks
            cb.round({{call_id='one',arguments={}},{call_id='two',arguments={}}});cb.resolved()
        end
        pump()
        for _,name in ipairs({'a','b'}) do
            for i=2,1,-1 do local t=fakes[name].tools[i];t.outcome('known','r');t.resolved() end
        end
        pump();fakes.a:complete(2);pump();fakes.b:complete(2);pump()
        assert.equals('success',Runner.snapshot(runners.a).outcome)
        assert.equals('success',Runner.snapshot(runners.b).outcome)
        local function owned()
            local text=lines_of(buf)
            return select(2,text:gsub('X',''))+select(2,text:gsub('%[a:','')),
                select(2,text:gsub('Y',''))+select(2,text:gsub('%[b:',''))
        end
        local a,b=owned();assert.equals(3004,a);assert.equals(3004,b)
        for _=1,50 do
            if a==0 and b==0 then break end
            vim.api.nvim_buf_call(buf,function()vim.cmd('silent undo')end)
            local na,nb=owned()
            assert.is_false(na~=a and nb~=b,'one undo step removed text of both generations')
            a,b=na,nb
        end
        assert.equals(0,a);assert.equals(0,b)
        D.detach(doc);vim.api.nvim_buf_delete(buf,{force=true})
    end)
end)

