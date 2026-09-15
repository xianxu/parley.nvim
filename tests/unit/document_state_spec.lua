local ok, State = pcall(require, 'parley.document.state')

local function generation(doc, deps)
    local r = State.transition(doc, {kind='register_generation', input_snapshot={text='original'}, dependencies=deps})
    assert.is_true(r.ok); return r.generation
end
local function proof(entity, first, last)
    return {entity=entity, marker_revision=1, revision=1, first=first, last=last, confirmed=true}
end
local function acquire(doc, gen, regions, parent)
    return State.transition(doc, {kind='acquire', generation=gen, regions=regions, parent=parent})
end
local function resolve(doc, gen, grant, p, first, last)
    return State.resolve(doc, {epoch=State.snapshot(doc).epoch, generation=gen, grant=grant,
        entity=p.entity, first=first, last=last}, p)
end

describe('document authority state', function()
    it('provides a pure state machine', function() assert.is_true(ok) end)
    if not ok then return end

    it('copies inputs and snapshots and rejects unknown events', function()
        local d=State.new(); local g=generation(d)
        local p=proof('a',10,20); local r=acquire(d,g,{p}); p.entity='tampered'
        local snapshot=State.snapshot(d); snapshot.grants[r.grants[1]].entity='tampered'
        assert.is_true(resolve(d,g,r.grants[1],proof('a',10,20)).ok)
        assert.is_false(State.transition(d,{kind='unknown'}).ok)
    end)

    it('admits multi-region ownership atomically including insertion slots', function()
        local d=State.new(); local a=generation(d); local b=generation(d)
        assert.is_true(acquire(d,a,{proof('a',10,20)}).ok)
        assert.is_false(acquire(d,b,{proof('b',30,40),proof('c',20,20)}).ok)
        assert.is_true(acquire(d,b,{proof('b',30,40)}).ok)
        assert.is_false(acquire(d,b,{proof('d',50,50),proof('e',50,50)}).ok)
    end)

    it('revokes output and ambiguous boundary edits permanently through undo', function()
        for _,edit in ipairs({{first=15,last=15,new_bytes=1},{first=10,last=10,new_bytes=1},
            {first=20,last=20,new_bytes=1},{first=0,last=30,new_bytes=0}}) do
            local d=State.new(); local g=generation(d); local id=acquire(d,g,{proof('a',10,20)}).grants[1]
            assert.is_true(State.transition(d,{kind='observed_edit',first=edit.first,last=edit.last,new_bytes=edit.new_bytes}).ok)
            State.transition(d,{kind='reconcile',proofs={[id]=proof('a',10,20)}})
            assert.equals('revoked',State.snapshot(d).grants[id].status)
            assert.is_false(resolve(d,g,id,proof('a',10,20)).ok)
        end
    end)

    it('moves disjoint writers and only exempts the matched owner', function()
        local d=State.new(); local g=generation(d)
        local ids=acquire(d,g,{proof('a',10,20),proof('b',30,40)}).grants
        State.transition(d,{kind='observed_edit',first=15,last=15,new_bytes=2,owner_grant=ids[1],revision=2})
        local a=proof('a',10,22); a.revision=2
        assert.is_true(resolve(d,g,ids[1],a).ok)
        assert.is_true(resolve(d,g,ids[2],proof('b',32,42)).ok)
        State.transition(d,{kind='observed_edit',first=35,last=35,new_bytes=1,owner_grant=ids[1]})
        assert.equals('revoked',State.snapshot(d).grants[ids[2]].status)
    end)

    it('suspends uncertain authority and requires unchanged identity to resume', function()
        local d=State.new(); local g=generation(d); local ids=acquire(d,g,{proof('a',10,20),proof('b',30,40)}).grants
        State.transition(d,{kind='uncertain',first=0,last=40})
        assert.is_false(resolve(d,g,ids[1],proof('a',10,20)).ok)
        local changed=proof('b',30,40); changed.marker_revision=2
        State.transition(d,{kind='reconcile',proofs={[ids[1]]=proof('a',10,20),[ids[2]]=changed}})
        assert.is_true(resolve(d,g,ids[1],proof('a',10,20)).ok)
        assert.equals('revoked',State.snapshot(d).grants[ids[2]].status)
    end)

    it('stales captured input without changing the request or stopping output', function()
        local d=State.new(); local g=generation(d,{{first=0,last=5}})
        local id=acquire(d,g,{proof('a',10,20)}).grants[1]
        State.transition(d,{kind='observed_edit',first=2,last=3,new_bytes=1})
        local snapshot=State.snapshot(d)
        assert.is_true(snapshot.generations[g].stale)
        assert.same({text='original'},snapshot.generations[g].input_snapshot)
        assert.is_true(resolve(d,g,id,proof('a',10,20)).ok)
    end)

    it('excludes delegated child text and boundary slots from the parent', function()
        local d=State.new(); local g=generation(d); local parent=acquire(d,g,{proof('a',0,30)}).grants[1]
        local child=acquire(d,g,{proof('child',10,20)},parent).grants[1]
        assert.is_true(resolve(d,g,parent,proof('a',0,30),0,5).ok)
        assert.is_false(resolve(d,g,parent,proof('a',0,30),10,10).ok)
        assert.is_false(resolve(d,g,parent,proof('a',0,30),5,25).ok)
        assert.is_true(resolve(d,g,child,proof('child',10,20),10,10).ok)
        State.transition(d,{kind='revoke',grant=child})
        assert.is_false(resolve(d,g,parent,proof('a',0,30),10,10).ok)
    end)

    it('bounds admission and frees finished registrations without ID resurrection', function()
        local d=State.new(); local gens={}; for i=1,4 do gens[i]=generation(d) end
        assert.is_false(State.transition(d,{kind='register_generation'}).ok)
        local rows={}; for i=1,16 do rows[i]=proof('e'..i,i*10,i*10+1) end
        local ids=acquire(d,gens[1],rows).grants
        assert.is_false(acquire(d,gens[2],{proof('overflow',1000,1001)}).ok)
        State.transition(d,{kind='finish_generation',generation=gens[1]})
        local fresh=generation(d); local id=acquire(d,fresh,{proof('e1',10,11)}).grants[1]
        assert.is_not_equal(ids[1],id)
        assert.is_false(resolve(d,gens[1],ids[1],proof('e1',10,11)).ok)
    end)

    it('keeps child insertion boundaries excluded after authorized growth', function()
        for _,at in ipairs({10,20}) do
            local d=State.new(); local g=generation(d); local parent=acquire(d,g,{proof('a',0,30)}).grants[1]
            local child=acquire(d,g,{proof('child',10,20)},parent).grants[1]
            State.transition(d,{kind='observed_edit',first=at,last=at,new_bytes=2,owner_grant=child})
            for p=10,22 do assert.is_false(resolve(d,g,parent,proof('a',0,32),p,p).ok) end
            local cp=proof('child',10,22); cp.revision=2
            assert.is_true(resolve(d,g,child,cp,10,22).ok)
        end
    end)

    it('rejects oversized or malformed evidence without partial registration', function()
        local d=State.new({max_dependencies=2})
        assert.is_false(State.transition(d,{kind='register_generation',dependencies={{first=0,last=1},
            {first=2,last=3},{first=4,last=5}}}).ok)
        assert.is_false(State.transition(d,{kind='register_generation',input_snapshot=string.rep('x',65537)}).ok)
        local g=generation(d)
        assert.is_false(acquire(d,g,{proof('a',0,1),{first=2,last=3}}).ok)
        assert.same({},State.snapshot(d).grants)
        for _,n in ipairs({-1,0.5,math.huge,0/0}) do
            assert.is_false(State.transition(d,{kind='observed_edit',first=0,last=0,new_bytes=n}).ok)
        end
    end)

    it('emits bounded lifecycle effects and rejects callbacks from old epochs', function()
        local d=State.new({epoch=100}); local g=generation(d,{{first=0,last=5}})
        local id=acquire(d,g,{proof('a',10,20)}).grants[1]
        assert.is_false(State.transition(d,{kind='observed_edit',epoch=99,first=12,last=13,new_bytes=0}).ok)
        assert.is_true(resolve(d,g,id,proof('a',10,20)).ok)
        local stale=State.transition(d,{kind='observed_edit',first=1,last=2,new_bytes=1})
        assert.same({{kind='stale',generation=g,reason='input edit'}},stale.effects)
        local uncertain=State.transition(d,{kind='uncertain',first=0,last=20})
        assert.same({{kind='suspended',grant=id,reason='structural uncertainty'}},uncertain.effects)
        local resumed=State.transition(d,{kind='reconcile',proofs={[id]=proof('a',10,20)}})
        assert.same({{kind='resumed',grant=id,reason='confirmed identity'}},resumed.effects)
        local revoked=State.transition(d,{kind='observed_edit',first=15,last=15,new_bytes=1})
        assert.same({{kind='revoked',grant=id,reason='output edit'}},revoked.effects)
    end)

    it('keeps retiring grant IDs bounded during a long-lived generation', function()
        local d=State.new(); local g=generation(d); local first
        for _=1,100 do
            local r=acquire(d,g,{proof('a',10,20)}); assert.is_true(r.ok)
            first=first or r.grants[1]
            State.transition(d,{kind='revoke',grant=r.grants[1]})
        end
        local n=0; for _ in pairs(State.snapshot(d).grants) do n=n+1 end
        assert.is_true(n<=16)
        assert.is_false(resolve(d,g,first,proof('a',10,20)).ok)
    end)

    it('invalidates reload and detach even when buffer and entity names are reused', function()
        local d=State.new(); local g=generation(d); local id=acquire(d,g,{proof('a',10,20)}).grants[1]
        local epoch=State.snapshot(d).epoch
        State.transition(d,{kind='reload'})
        assert.is_not_equal(epoch,State.snapshot(d).epoch)
        assert.is_false(State.resolve(d,{epoch=epoch,generation=g,grant=id,entity='a'},proof('a',10,20)).ok)
        State.transition(d,{kind='detach'})
        assert.is_false(State.transition(d,{kind='register_generation'}).ok)
        assert.is_false(State.transition(d,{kind='reload'}).ok)
    end)
end)
