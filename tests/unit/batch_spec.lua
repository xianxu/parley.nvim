local loaded,B=pcall(require,'parley.batch')
local function spec()
    return {epoch='epoch',batch='batch',selection={{entity='a',revision='qa'},{entity='b',revision='qb'},
        {entity='c',revision='qc'}},contexts={{entity='prior',revision='prior1'}}}
end
local function evidence()
    return {epoch='epoch',questions={a={status='valid',revision='qa'},b={status='valid',revision='qb'},
        c={status='valid',revision='qc'}},contexts={prior={status='valid',revision='prior1'}}}
end
local function send(s,e)
    e.epoch=e.epoch or 'epoch';e.batch=e.batch or 'batch'
    return B.transition(s,e)
end
local function effect(r,kind)
    for _,e in ipairs(r.effects)do if e.type==kind then return e end end
end
local function start(s,proof)
    local next,r=send(s,{type='start',evidence=proof or evidence()})
    return next,effect(r,'start_generation').leg
end

describe('pure fixed-membership batches',function()
    it('provides the batch reducer',function()assert.is_true(loaded,tostring(B))end)
    if not loaded then return end
    it('freezes membership and ignores inserted questions or current selection',function()
        local input=spec();local s=B.new(input);input.selection[1].entity='other'
        local proof=evidence();proof.questions.inserted={status='valid',revision='new'};proof.cursor='c'
        local next,r=send(s,{type='start',evidence=proof})
        assert.equals('a',effect(r,'start_generation').entity)
        effect(r,'start_generation').entity='tampered'
        assert.equals('ready',B.snapshot(s).phase)
        assert.equals('a',B.snapshot(next).active.entity)
        local view=B.snapshot(next);view.selection[1].entity='mutated'
        assert.equals('a',B.snapshot(next).selection[1].entity)
    end)
    it('defers opaque evidence and pauses changed or missing identities',function()
        local s=B.new(spec());local proof=evidence();proof.questions.c.status='opaque'
        assert.equals('deferred',B.validate_next(s,proof).status)
        local same,r=send(s,{type='start',evidence=proof})
        assert.equals(s,same);assert.same({},r.effects)
        proof.questions.c={status='valid',revision='changed'}
        local paused=send(s,{type='start',evidence=proof})
        assert.equals('paused',B.snapshot(paused).phase)
        assert.equals('question changed',B.snapshot(paused).reason)
        proof.questions.c=nil
        assert.equals('missing',B.validate_next(s,proof).status)
        proof.epoch='other';assert.equals('obsolete',B.validate_next(s,proof).status)
    end)
    it('preserves successful progress and validates refreshed context before advancing',function()
        local s,leg=start(B.new(spec()))
        s=send(s,{type='finished',leg=leg,outcome='success',context_revision='a1'})
        assert.equals(1,B.snapshot(s).completed)
        local proof=evidence();proof.contexts.a={status='valid',revision='a1'}
        s,leg=start(s,proof);assert.equals('b',B.snapshot(s).active.entity)
        s=send(s,{type='finished',leg=leg,outcome='provider_failed'})
        assert.equals('paused',B.snapshot(s).phase);assert.equals(1,B.snapshot(s).completed)
        proof.contexts.a.revision='human edit'
        local same,r=send(s,{type='resume',evidence=proof})
        assert.equals(s,same);assert.equals('context changed',r.reason)
        s=send(s,{type='resume',evidence=proof,accept_changes=true})
        s,leg=start(s,proof);assert.equals('b',B.snapshot(s).active.entity)
        assert.equals(1,B.snapshot(s).completed)
    end)
    it('retains cancellation ownership until the active leg positively finishes',function()
        local s,leg=start(B.new(spec()))
        local paused,r=send(s,{type='cancel'})
        assert.equals('paused',B.snapshot(paused).phase)
        assert.equals(leg,effect(r,'cancel_generation').leg)
        local same,retry=send(paused,{type='resume',evidence=evidence(),accept_changes=true})
        assert.equals(paused,same);assert.equals('leg unresolved',retry.reason)
        paused=send(paused,{type='finished',leg=leg,outcome='cancelled'})
        local ready=send(paused,{type='resume',evidence=evidence()})
        assert.equals('ready',B.snapshot(ready).phase)
        assert.equals(0,B.snapshot(ready).completed)
    end)
    it('does not replay an unknown effect through resume',function()
        local s,leg=start(B.new(spec()))
        s=send(s,{type='finished',leg=leg,outcome='unknown'})
        local same,r=send(s,{type='resume',evidence=evidence(),accept_changes=true})
        assert.equals(s,same);assert.equals('unknown effect',r.reason)
        assert.equals(0,B.snapshot(s).completed)
    end)
    it('rejects duplicate and stale leg completions without losing later progress',function()
        local s,leg=start(B.new(spec()))
        s=send(s,{type='finished',leg=leg,outcome='success',context_revision='a1'})
        local proof=evidence();proof.contexts.a={status='valid',revision='a1'}
        local running,newleg=start(s,proof)
        local same,r=send(running,{type='finished',leg=leg,outcome='success',context_revision='forged'})
        assert.equals(running,same);assert.is_false(r.accepted)
        assert.equals(newleg,B.snapshot(same).active.leg)
        same,r=send(running,{type='finished',leg=newleg,outcome='success'})
        assert.equals(running,same);assert.is_false(r.accepted)
    end)
    it('never adopts missing members or changes the captured document epoch on resume',function()
        local s=send(B.new(spec()),{type='cancel'})
        local proof=evidence();proof.questions.b=nil
        local same=send(s,{type='resume',evidence=proof,accept_changes=true})
        assert.equals(s,same)
        proof=evidence();proof.epoch='new epoch'
        same=send(s,{type='resume',evidence=proof,accept_changes=true});assert.equals(s,same)
    end)
    it('completes in captured order and emits no further generation',function()
        local s=B.new(spec());local proof=evidence()
        for _,entity in ipairs({'a','b','c'})do
            local leg;s,leg=start(s,proof)
            assert.equals(entity,B.snapshot(s).active.entity)
            s=send(s,{type='finished',leg=leg,outcome='success',context_revision=entity..'1'})
            proof.contexts[entity]={status='valid',revision=entity..'1'}
        end
        assert.equals('completed',B.snapshot(s).phase)
        assert.equals(3,B.snapshot(s).completed)
        local same,r=send(s,{type='start',evidence=proof});assert.equals(s,same);assert.same({},r.effects)
    end)
    it('rejects invalid membership and wrong-scope events',function()
        local bad=spec();bad.selection[2].entity='a';assert.has_error(function()B.new(bad)end)
        local s=B.new(spec());local same,r=send(s,{type='cancel',epoch='foreign'})
        assert.equals(s,same);assert.is_false(r.accepted)
        same,r=send(s,{type='invented'});assert.equals(s,same);assert.is_false(r.accepted)
        assert.equals('completed',B.snapshot(B.new({epoch='epoch',batch='empty',selection={}})).phase)
    end)
end)
