local ok, State = pcall(require, 'parley.document.state')

local function generation(doc, deps)
    local r = State.transition(doc, {kind='register_generation', input_snapshot={text='original'}, dependencies=deps})
    assert.is_true(r.ok); return r.generation
end
local function proof(entity, first, last)
    return {entity=entity, marker_revision=1, revision=1, first=first, last=last, confirmed=true}
end
local function acquire(doc, gen, regions)
    return State.transition(doc, {kind='acquire', generation=gen, regions=regions})
end
local function resolve(doc, gen, grant, p, first, last)
    return State.resolve(doc, {epoch=State.snapshot(doc).epoch, generation=gen, grant=grant,
        entity=p.entity, revision=p.revision, first=first, last=last}, p)
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

    it('rejects stale plan revisions after owned writes or disjoint relocation', function()
        local d=State.new(); local g=generation(d)
        local id=acquire(d,g,{proof('a',10,30)}).grants[1]
        State.transition(d,{kind='observed_edit',first=0,last=0,new_bytes=2})
        local current=State.snapshot(d).grants[id]
        assert.equals(2,current.revision)
        local p=proof('a',12,32);p.revision=2
        assert.equals('revision',State.resolve(d,{epoch=State.snapshot(d).epoch,
            generation=g,grant=id,entity='a',revision=1,first=20,last=21},p).reason)
        assert.is_true(resolve(d,g,id,p,20,21).ok)
        State.transition(d,{kind='observed_edit',first=20,last=21,new_bytes=1,owner_grant=id})
        local newer=proof('a',12,32);newer.revision=3
        assert.equals('revision',State.resolve(d,{epoch=State.snapshot(d).epoch,
            generation=g,grant=id,entity='a',revision=2,first=20,last=21},newer).reason)
        assert.equals('valid',State.snapshot(d).grants[id].status)
    end)

    it('moves disjoint writers and only exempts the matched owner', function()
        local d=State.new(); local g=generation(d)
        local ids=acquire(d,g,{proof('a',10,20),proof('b',30,40)}).grants
        State.transition(d,{kind='observed_edit',first=15,last=15,new_bytes=2,owner_grant=ids[1],revision=2})
        local a=proof('a',10,22); a.revision=2
        assert.is_true(resolve(d,g,ids[1],a).ok)
        local b=proof('b',32,42); b.revision=2
        assert.is_true(resolve(d,g,ids[2],b).ok)
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

    -- #266 M4: a tool round writes through the answer's own grant, so no grant is
    -- ever carved out of another. Naming a `parent` no longer delegates a slot.
    it('never nests grants: a region inside a live grant is refused, even for its own generation', function()
        local d=State.new(); local g=generation(d); local outer=acquire(d,g,{proof('a',0,30)}).grants[1]
        local nested=State.transition(d,{kind='acquire',generation=g,parent=outer,regions={proof('child',10,20)}})
        assert.is_false(nested.ok); assert.equals('overlap',nested.reason)
        assert.is_true(resolve(d,g,outer,proof('a',0,30),5,25).ok)
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

describe('finite replacement authority',function()
    it('binds suspended continuation to one exact armed patch',function()
        local d=State.new({epoch=91});local gen=generation(d)
        local gid=acquire(d,gen,{proof('q',10,30)}).grants[1]
        local request={epoch=91,generation=gen,grant=gid,entity='q',revision=1}
        local witness=assert(State.successor_new(d,request,proof('q',10,30)))
        State.transition(d,{kind='uncertain',first=10,last=30})
        assert.is_true(State.successor_arm(d,witness,{first=20,last=30,new_bytes=0}))
        State.transition(d,{kind='observed_edit',first=20,last=30,new_bytes=0,owner_grant=gid,successor=witness})
        assert.equals('suspended',State.snapshot(d).grants[gid].status)
        assert.equals(20,State.snapshot(d).grants[gid].last)
        State.transition(d,{kind='observed_edit',first=19,last=20,new_bytes=0,owner_grant=gid,successor=witness})
        assert.equals('revoked',State.snapshot(d).grants[gid].status)
    end)

    -- #266 M1: the write turn. One generation may mutate a document at a time;
    -- eligibility order is admission order.
    it('serializes the write turn by admission order and releases it on finish',function()
        local d=State.new()
        local a,b=generation(d),generation(d)
        assert.is_nil(State.snapshot(d).turn)
        local r=State.transition(d,{kind='request_turn',generation=a})
        assert.is_true(r.ok); assert.equals(a,r.turn); assert.equals(a,State.snapshot(d).turn)
        r=State.transition(d,{kind='request_turn',generation=b})
        assert.is_true(r.ok); assert.equals(a,r.turn,'a keeps the turn while eligible')
        r=State.transition(d,{kind='finish_generation',generation=a})
        assert.equals(b,r.turn,'turn passes to the next admitted')
        assert.equals(b,State.snapshot(d).turn)
    end)

    it('releases the turn on request so a blocked holder cannot starve the queue',function()
        local d=State.new()
        local a,b=generation(d),generation(d)
        State.transition(d,{kind='request_turn',generation=a})
        State.transition(d,{kind='request_turn',generation=b})
        local r=State.transition(d,{kind='release_turn',generation=a})
        assert.equals(b,r.turn); assert.equals(b,State.snapshot(d).turn)
    end)

    it('re-queues a released generation behind the current holder',function()
        local d=State.new()
        local a,b=generation(d),generation(d)
        State.transition(d,{kind='request_turn',generation=a})
        State.transition(d,{kind='request_turn',generation=b})
        State.transition(d,{kind='release_turn',generation=a})
        local r=State.transition(d,{kind='request_turn',generation=a})
        assert.equals(b,r.turn,'b keeps the turn it was handed')
    end)

    it('leaves the turn unheld when the only wanter releases',function()
        local d=State.new()
        local a=generation(d)
        State.transition(d,{kind='request_turn',generation=a})
        local r=State.transition(d,{kind='release_turn',generation=a})
        assert.is_nil(r.turn); assert.is_nil(State.snapshot(d).turn)
    end)

    it('clears the turn on reload and on detach',function()
        for _,kind in ipairs({'reload','detach'})do
            local d=State.new()
            local a=generation(d)
            State.transition(d,{kind='request_turn',generation=a})
            assert.equals(a,State.snapshot(d).turn)
            State.transition(d,{kind=kind})
            assert.is_nil(State.snapshot(d).turn,kind..' must clear the turn')
        end
    end)

    it('does not resurrect a want after the generation is gone',function()
        local d=State.new()
        local a,b=generation(d),generation(d)
        State.transition(d,{kind='request_turn',generation=a})
        State.transition(d,{kind='request_turn',generation=b})
        State.transition(d,{kind='finish_generation',generation=b})
        -- b's want must not survive its registration; only a is eligible now.
        local r=State.transition(d,{kind='release_turn',generation=a})
        assert.is_nil(r.turn,'no eligible generation remains')
    end)

    it('rejects a turn request from an unknown generation',function()
        local d=State.new()
        assert.equals('generation',State.transition(d,{kind='request_turn',generation=999}).reason)
        assert.equals('generation',State.transition(d,{kind='release_turn',generation=999}).reason)
    end)

    -- state.lua's copy() asserts getmetatable(v)==nil, so the wanted-set must not
    -- live inside the state table or every snapshot would throw.
    it('keeps snapshots copyable while the turn is held',function()
        local d=State.new()
        local a=generation(d)
        State.transition(d,{kind='request_turn',generation=a})
        assert.has_no.errors(function()State.snapshot(d)end)
    end)

    -- M1 review I5: one O(1) predicate for every generated write entry point.
    -- 'waiting' means "you own this and could write, just not now"; a writer that
    -- does not own the grant must fall through to the ownership checks instead.
    it('waits for the turn only when the writer owns the grant and another holds the turn', function()
        local d=State.new()
        local a,b=generation(d),generation(d)
        local ga=acquire(d,a,{proof('a',10,20)}).grants[1]
        local gb=acquire(d,b,{proof('b',30,40)}).grants[1]
        assert.is_false(State.waits_for_turn(d,b,gb),'nobody holds the turn')
        State.transition(d,{kind='request_turn',generation=a})
        assert.is_false(State.waits_for_turn(d,a,ga),'the holder never waits')
        assert.is_true(State.waits_for_turn(d,b,gb),'an owner behind the holder waits')
        assert.is_false(State.waits_for_turn(d,b,ga),'a non-owner is an ownership failure, not a wait')
        assert.is_false(State.waits_for_turn(d,b,'missing'))
        assert.is_false(State.waits_for_turn(d,nil,gb),'a human write is never subject to the turn')
    end)
end)

