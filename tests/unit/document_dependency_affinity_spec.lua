local S=require('parley.document.state')
local function setup(dep,grant)
    local doc=S.new();local gen=S.transition(doc,{kind='register_generation',dependencies={dep}}).generation
    local owner=S.transition(doc,{kind='acquire',generation=gen,regions={{first=grant.first,last=grant.last,
        entity='question',marker_revision=1,revision=1,confirmed=true}}}).grants[1]
    return doc,gen,owner
end
local function edit(doc,owner,first,last,bytes)
    return S.transition(doc,{kind='observed_edit',owner_grant=owner,first=first,last=last,new_bytes=bytes})
end
describe('generation input dependency endpoint affinity',function()
    it('keeps the question endpoint fixed across its adjacent owned output insertion',function()
        local doc,gen,owner=setup({first=0,last=10},{first=10,last=10})
        local result=edit(doc,owner,10,10,20)
        assert.is_true(result.ok);assert.same({},result.effects)
        local state=S.snapshot(doc)
        assert.is_false(state.generations[gen].stale)
        assert.same({{first=0,last=10}},state.generations[gen].dependencies)
        edit(doc,owner,30,30,5)
        assert.same({{first=0,last=10}},S.snapshot(doc).generations[gen].dependencies)
    end)
    it('still stales human insertion at that same question endpoint',function()
        local doc,gen=setup({first=0,last=10},{first=10,last=10})
        edit(doc,nil,10,10,20)
        assert.is_true(S.snapshot(doc).generations[gen].stale)
        assert.equals(30,S.snapshot(doc).generations[gen].dependencies[1].last)
    end)
    -- #261/#255 reversed the first half of this case: another generation's
    -- write inside its own live grant used to mark `other` stale. The answer it
    -- replaces stays the valid context until that generation ends (the
    -- prev_answer slot), so it now moves `other`'s range without staling it.
    it('moves another generation\'s input across an owned write without staling it, and keeps interior boundaries strict',function()
        local doc,gen,owner=setup({first=0,last=10},{first=10,last=10})
        local other=S.transition(doc,{kind='register_generation',dependencies={{first=0,last=10}}}).generation
        edit(doc,owner,10,10,1)
        assert.is_false(S.snapshot(doc).generations[gen].stale)
        assert.is_false(S.snapshot(doc).generations[other].stale)
        local d,g,o=setup({first=0,last=10},{first=5,last=20})
        edit(d,o,10,10,1)
        assert.is_true(S.snapshot(d).generations[g].stale)
    end)
    it('does not revive stale input or excuse changed consumed bytes and invalid owners',function()
        local doc,gen,owner=setup({first=0,last=10},{first=10,last=20})
        edit(doc,nil,1,2,1);edit(doc,owner,10,10,1)
        assert.is_true(S.snapshot(doc).generations[gen].stale)
        local d,g,o=setup({first=0,last=10},{first=10,last=20})
        edit(d,o,9,10,1)
        assert.is_true(S.snapshot(d).generations[g].stale)
    end)
    it('records initial stale evidence at registration without changing input or output authority',function()
        local doc=S.new()
        local result=S.transition(doc,{kind='register_generation',input_snapshot={text='frozen'},input_stale=true})
        local gen=S.snapshot(doc).generations[result.generation]
        assert.is_true(gen.stale);assert.same({text='frozen'},gen.input_snapshot)
        assert.is_false(S.transition(doc,{kind='register_generation',input_stale='yes'}).ok)
    end)
end)
