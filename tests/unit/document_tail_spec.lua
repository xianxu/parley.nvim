local S=require('parley.document.state')
local D=require('parley.document')
local Fake=require('tests.helpers.fake_document_editor')
local function setup()
    local d=S.new({epoch=88});local gen=S.transition(d,{kind='register_generation'}).generation
    local p={entity='q',first=10,last=30,revision=1,marker_revision=1,confirmed=true}
    local g=S.transition(d,{kind='acquire',generation=gen,regions={p}}).grants[1]
    local child=S.transition(d,{kind='acquire',generation=gen,parent=g,
        regions={{entity='q',first=20,last=30,revision=1,marker_revision=1,confirmed=true}}}).grants[1]
    return d,gen,g,child
end
local function reclaim(d,gen,g)
    local current=S.snapshot(d).grants[g];current.confirmed=true
    return S.transition(d,{kind='reclaim_tail',epoch=88,generation=gen,grant=g,entity='q',
        revision=current.revision,current=current})
end
describe('parent tail reclaim',function()
    it('requires child retirement and restores only the fresh zero-width tail',function()
        local d,gen,g,c=setup();assert.is_false(reclaim(d,gen,g).ok)
        S.transition(d,{kind='revoke',grant=c})
        assert.is_true(reclaim(d,gen,g).ok)
        local p=S.snapshot(d).grants[g];assert.equals(30,p.first);assert.equals(30,p.last)
        assert.same({{first=30,last=30}},p.slots)
    end)
    it('never follows a human insertion at a delegated tail',function()
        local d,gen,g=setup()
        S.transition(d,{kind='observed_edit',first=30,last=30,new_bytes=5})
        assert.is_false(reclaim(d,gen,g).ok)
    end)
    it('accepts an exact owned child extension before retiring its slot',function()
        local d,gen,g,c=setup()
        S.transition(d,{kind='observed_edit',first=30,last=30,new_bytes=5,owner_grant=c})
        S.transition(d,{kind='revoke',grant=c})
        assert.is_true(reclaim(d,gen,g).ok);assert.equals(35,S.snapshot(d).grants[g].last)
    end)
    it('rejects another generation occupying the retired endpoint',function()
        local d,gen,g,c=setup();S.transition(d,{kind='revoke',grant=c})
        local other=S.transition(d,{kind='register_generation'}).generation
        assert.is_true(S.transition(d,{kind='acquire',generation=other,
            regions={{entity='q',first=30,last=30,revision=1,marker_revision=1,confirmed=true}}}).ok)
        assert.is_false(reclaim(d,gen,g).ok)
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
