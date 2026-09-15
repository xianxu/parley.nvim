local S=require('parley.document.state')
local function generation(doc)return S.transition(doc,{kind='register_generation'}).generation end
local function region(i)return {entity='e'..i,first=i*10,last=i*10+5,marker_revision=1,revision=1,confirmed=true}end
local function reserve(doc,gen,op,n)return S.transition(doc,{kind='reserve_capacity',generation=gen,operation=op,count=n})end
local function acquire(doc,gen,regions,ticket,operation)
    return S.transition(doc,{kind='acquire',generation=gen,regions=regions,capacity=ticket,operation=operation})
end
local function release(doc,gen,ticket,operation)
    return S.transition(doc,{kind='release_capacity',generation=gen,ticket=ticket,operation=operation})
end
local function usage(doc)
    local snap=S.snapshot(doc);local used,tickets=0,0
    for _,g in pairs(snap.grants)do if g.status~='revoked'then used=used+1 end end
    for _,t in pairs(snap.capacity_tickets)do used=used+t.remaining;tickets=tickets+1 end
    assert.is_true(used<=16);assert.is_true(tickets<=16);return used,tickets
end
describe('bounded document grant capacity tickets',function()
    it('reserves capacity before yielding and prevents another generation consuming it',function()
        local doc=S.new();local a,b=generation(doc),generation(doc)
        assert.is_true(acquire(doc,a,{region(1)}).ok)
        local ticket=reserve(doc,a,'round',15);assert.is_true(ticket.ok)
        assert.equals(16,usage(doc))
        assert.equals('grant limit',acquire(doc,b,{region(30)}).reason)
        assert.equals('grant limit',reserve(doc,b,'other',1).reason)
        local children={};for i=2,16 do children[#children+1]=region(i)end
        assert.is_true(acquire(doc,a,children,ticket.ticket,'round').ok)
        local _,n=usage(doc);assert.equals(0,n)
        assert.is_false(acquire(doc,a,{region(20)},ticket.ticket,'round').ok)
    end)
    it('retains reservation on failed proof or overlap and refuses wrong identities',function()
        local doc=S.new({epoch=9});local a,b=generation(doc),generation(doc)
        local ticket=reserve(doc,a,'round',2).ticket
        assert.is_false(reserve(doc,a,'round',1).ok)
        assert.is_false(acquire(doc,b,{region(1)},ticket,'round').ok)
        assert.is_false(acquire(doc,a,{region(1)},ticket,'other').ok)
        local bad=region(1);bad.confirmed=false
        assert.is_false(acquire(doc,a,{bad},ticket,'round').ok)
        assert.is_false(acquire(doc,a,{region(1),region(1)},ticket,'round').ok)
        assert.equals(2,S.snapshot(doc).capacity_tickets[ticket].remaining)
        assert.is_false(release(doc,b,ticket,'round').ok)
        assert.is_false(S.transition(doc,{kind='release_capacity',epoch=8,generation=a,ticket=ticket,operation='round'}).ok)
        assert.is_true(acquire(doc,a,{region(1)},ticket,'round').ok)
        assert.equals(1,S.snapshot(doc).capacity_tickets[ticket].remaining)
        assert.is_true(release(doc,a,ticket,'round').ok)
        assert.is_false(release(doc,a,ticket,'round').ok)
        assert.equals(1,usage(doc))
    end)
    it('releases unused capacity on cancellation after partial slot writes without inventing grants',function()
        local doc=S.new();local gen=generation(doc)
        local ticket=reserve(doc,gen,'round',4).ticket
        -- Native placeholder delivery has happened, but child proof validation
        -- and acquisition have not. Capacity is bookkeeping, not text authority.
        S.transition(doc,{kind='observed_edit',first=0,last=0,new_bytes=50})
        assert.equals(4,usage(doc));assert.same({},S.snapshot(doc).grants)
        assert.is_true(release(doc,gen,ticket,'round').ok)
        assert.equals(0,usage(doc));assert.same({},S.snapshot(doc).grants)
    end)
    it('cleans up tickets on generation finish, reload and detach',function()
        for _,kind in ipairs({'finish_generation','reload','detach'})do
            local doc=S.new();local gen=generation(doc)
            local ticket=reserve(doc,gen,'round',16).ticket
            assert.is_true(S.transition(doc,{kind=kind,generation=gen}).ok)
            assert.same({},S.snapshot(doc).capacity_tickets)
            assert.is_false(release(doc,gen,ticket,'round').ok)
        end
    end)
    it('keeps ordinary confirmed-region validation in the Document facade',function()
        local D=require('parley.document')
        local fake=require('tests.helpers.fake_document_editor').new({'🤖: answer','body'})
        local doc=D.attach(-98761,{driver=fake.driver,schedule=false})
        local gen=D.transition(doc,{kind='register_generation'}).generation
        local ticket=D.reserve_capacity(doc,{generation=gen,operation='round',count=2}).ticket
        assert.is_number(ticket)
        local bad=D.transition(doc,{kind='acquire',generation=gen,capacity=ticket,operation='round',regions={region(1)}})
        assert.is_false(bad.ok);assert.equals(2,D.snapshot(doc).capacity_tickets[ticket].remaining)
        assert.equals('idle',D.drain(doc,1000).status)
        local span=D.query(doc,0,1)[1]
        local acquired=D.transition(doc,{kind='acquire',generation=gen,capacity=ticket,operation='round',regions={
            {entity=span.handle,first=0,last=span.end_byte-1,marker_revision=1,revision=1,confirmed=true}}})
        assert.is_true(acquired.ok,vim.inspect(acquired))
        assert.equals(1,D.snapshot(doc).capacity_tickets[ticket].remaining)
        assert.is_true(D.release_capacity(doc,{generation=gen,operation='round',ticket=ticket}).ok)
        D.detach(doc)
    end)
    it('keeps the ticket registry bounded across repeated round completion and rejection',function()
        local doc=S.new();local gen=generation(doc)
        for round=1,100 do
            local tickets={}
            for i=1,16 do tickets[i]=assert(reserve(doc,gen,round..':'..i,1).ticket)end
            assert.is_false(reserve(doc,gen,'overflow',1).ok)
            assert.equals(16,usage(doc))
            for i,ticket in ipairs(tickets)do assert.is_true(release(doc,gen,ticket,round..':'..i).ok)end
            assert.equals(0,usage(doc))
        end
    end)
end)
