local Read=require('parley.skill_source_read')
describe('pure skill source-read ownership',function()
    it('admits within a shared cap and only positive cleanup releases a slot',function()
        local pool=Read.pool(1);local state=Read.new();local permissions
        pool,state,permissions=Read.transition(pool,state,{type='admit',now=0})
        assert.is_true(permissions.launch);assert.equals(1,pool.used)
        local other,effects
        pool,other,effects=Read.transition(pool,Read.new(),{type='admit',now=0})
        assert.is_nil(effects.launch);assert.equals('capacity',effects.reason)
        pool,state,permissions=Read.transition(pool,state,{type='finish'})
        assert.is_true(permissions.deliver);assert.is_true(permissions.cancel)
        assert.equals(1,pool.used)
        pool,state,permissions=Read.transition(pool,state,{type='observation',physical_resolved=false})
        assert.is_nil(permissions.complete);assert.equals(1,pool.used)
        pool,state,permissions=Read.transition(pool,state,{type='observation',physical_resolved=true})
        assert.is_true(permissions.retire);assert.is_true(permissions.release_owner)
        assert.is_nil(permissions.complete);assert.equals(0,pool.used)
    end)
    it('accounts interleaved owners against the current shared pool',function()
        local pool,a,b=Read.pool(2),Read.new(),Read.new();local effects
        pool,a=Read.transition(pool,a,{type='admit',now=0})
        pool,b=Read.transition(pool,b,{type='admit',now=1})
        assert.equals(2,pool.used)
        pool,a=Read.transition(pool,a,{type='finish'})
        pool,b,effects=Read.transition(pool,b,{type='observation',physical_resolved=true})
        assert.is_true(effects.complete);assert.is_nil(effects.release_owner)
        assert.equals(1,pool.used)
        pool,b,effects=Read.transition(pool,b,{type='finish'})
        assert.is_true(effects.release_owner);assert.equals(1,pool.used)
        pool,a=Read.transition(pool,a,{type='observation',physical_resolved=true})
        assert.equals(0,pool.used)
    end)
    it('derives bounded polling and deadline logical completion without physical retirement',function()
        local pool,state=Read.pool(1),Read.new();local effects
        pool,state,effects=Read.transition(pool,state,{type='admit',now=0})
        assert.equals(10,effects.delay)
        pool,state,effects=Read.transition(pool,state,{type='tick',now=9})
        assert.is_nil(effects.probe)
        pool,state,effects=Read.transition(pool,state,{type='tick',now=10})
        assert.is_true(effects.probe);assert.equals(20,effects.delay)
        pool,state,effects=Read.transition(pool,state,{type='tick',now=5000})
        assert.is_true(effects.deadline);assert.is_true(effects.deliver);assert.is_true(effects.cancel)
        assert.is_nil(effects.retire);assert.equals(1,pool.used)
        pool,state,effects=Read.transition(pool,state,{type='tick',now=6000})
        assert.is_nil(effects.deadline);assert.is_nil(effects.delay)
    end)
    it('rejects launch after terminal and delivery duplicates',function()
        local pool,state=Read.pool(1),Read.new();local effects
        pool,state,effects=Read.transition(pool,state,{type='finish'})
        assert.is_true(effects.deliver);assert.is_true(effects.release_owner)
        pool,state,effects=Read.transition(pool,state,{type='admit',now=0})
        assert.is_nil(effects.launch)
        pool,state,effects=Read.transition(pool,state,{type='finish'})
        assert.is_nil(effects.deliver)
    end)
    it('retains immutable predecessors and sweeps cancellation completion permutations',function()
        local events={{type='finish'},{type='observation',physical_resolved=true},
            {type='observation',physical_resolved=false},{type='tick',now=6000}}
        local function run(sequence)
            local pool,state=Read.pool(1),Read.new();pool,state=Read.transition(pool,state,{type='admit',now=0})
            local delivered,retired=0,0
            for _,event in ipairs(sequence)do
                local previous_pool,previous_state=vim.deepcopy(pool),vim.deepcopy(state)
                local next_pool,next_state,effects=Read.transition(pool,state,event)
                assert.same(previous_pool,pool);assert.same(previous_state,state)
                pool,state=next_pool,next_state
                if effects.deliver then delivered=delivered+1 end
                if effects.retire then retired=retired+1 end
                assert.is_true(pool.used>=0 and pool.used<=1)
            end
            assert.equals(1,delivered);assert.equals(1,retired)
        end
        for a=1,4 do for b=1,4 do if b~=a then for c=1,4 do if c~=a and c~=b then
            for d=1,4 do if d~=a and d~=b and d~=c then
                run({events[a],events[b],events[c],events[d],events[a],events[b],events[c],events[d]})
            end end
        end end end end end
    end)
end)
