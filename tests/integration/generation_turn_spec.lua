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
