local S=require('parley.document.state')
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local function setup()
    local d=S.new({epoch=88});local gen=S.transition(d,{kind='register_generation'}).generation
    local p={entity='q',first=10,last=30,revision=1,marker_revision=1,confirmed=true}
    local g=S.transition(d,{kind='acquire',generation=gen,regions={p}}).grants[1]
    return d,gen,g
end
local function reclaim(d,gen,g)
    local current=S.snapshot(d).grants[g];current.confirmed=true
    return S.transition(d,{kind='reclaim_tail',epoch=88,generation=gen,grant=g,entity='q',
        revision=current.revision,current=current})
end
-- A continuation narrows its answer's grant to the tail before writing there.
-- Since #266 M4 no grant is carved out of another, so nothing but the grant
-- itself can occupy its tail.
describe('tail reclaim',function()
    it('restores only the fresh zero-width tail',function()
        local d,gen,g=setup()
        assert.is_true(reclaim(d,gen,g).ok)
        local p=S.snapshot(d).grants[g];assert.equals(30,p.first);assert.equals(30,p.last)
    end)
    it('never follows a human insertion at its tail: the edit revokes the grant',function()
        local d,gen,g=setup()
        S.transition(d,{kind='observed_edit',first=30,last=30,new_bytes=5})
        assert.equals('revoked',S.snapshot(d).grants[g].status)
        assert.equals('ownership',reclaim(d,gen,g).reason)
    end)
    it('follows its own insertion at the tail',function()
        local d,gen,g=setup()
        S.transition(d,{kind='observed_edit',first=30,last=30,new_bytes=5,owner_grant=g})
        assert.is_true(reclaim(d,gen,g).ok);assert.equals(35,S.snapshot(d).grants[g].last)
    end)
    it('validates the live document proof and fences reload',function()
        local fake=Fake.new({'💬: q','🤖: a','body'});local doc=D.attach(199901,{driver=fake.driver,schedule=false})
        D.drain(doc,1000);local rows=D.query(doc,0,3)
        local gen=D.transition(doc,{kind='register_generation'}).generation
        local acquired=D.transition(doc,{kind='acquire',generation=gen,regions={{entity=rows[1].handle,
            first=rows[2].start_byte,last=rows[3].end_byte-1,revision=1,marker_revision=1,confirmed=true}}})
        local g=acquired.grants[1];local epoch=D.snapshot(doc).epoch
        assert.is_true(D.reclaim_tail(doc,{epoch=epoch,generation=gen,grant=g,entity=rows[1].handle,revision=1}).ok)
        fake:reload({'💬: replaced'})
        assert.is_false(D.reclaim_tail(doc,{epoch=epoch,generation=gen,grant=g,entity=rows[1].handle,revision=2}).ok)
        D.detach(doc)
    end)
end)
