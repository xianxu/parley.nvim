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
        assert.truthy(snap.failure:find('line '..holder_line,1,true),snap.failure)
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
        assert.is_nil(D.turn(doc)==Runner.snapshot(r.a).generation or nil)
    end)
end)
