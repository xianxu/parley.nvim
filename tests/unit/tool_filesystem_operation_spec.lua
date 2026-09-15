local F=require('parley.tools.filesystem_operation')
local _
describe('pure filesystem operation lifecycle authority',function()
    it('admits one identified request and rejects stale or duplicate completions',function()
        local s=F.new(3);local d
        s,d=F.transition(s,{type='request'});assert.is_true(d.execute);local id=d.id
        local same,rejected=F.transition(s,{type='request'});assert.equals(s,same);assert.is_false(rejected.execute)
        same,rejected=F.transition(s,{type='completed',id=id+1});assert.equals(s,same);assert.is_false(rejected.consume)
        s,d=F.transition(s,{type='completed',id=id});assert.is_true(d.consume)
        _,d=F.transition(s,{type='completed',id=id});assert.is_false(d.consume)
    end)
    it('cancellation retains pending mutation and permits only its completion and cleanup',function()
        local s=F.new(2);local d
        s,d=F.transition(s,{type='request',mutation=true});local id=d.id
        s=F.transition(s,{type='cancel'})
        assert.equals('unknown',F.view(s,{}).certainty)
        _,d=F.transition(s,{type='request'});assert.is_false(d.execute)
        s=F.transition(s,{type='completed',id=id})
        s,d=F.transition(s,{type='proceed'});assert.is_false(d.proceed);assert.is_true(d.cleanup)
        s,d=F.transition(s,{type='request',cleanup=true});assert.is_true(d.execute)
    end)
    it('joins known effect and physical cleanup in either order before terminal publication',function()
        for _,first in ipairs({'effect','cleanup'})do
            local s=F.new(4);local d
            if first=='effect'then
                s=F.transition(s,{type='effect',applied=true,uncertain=false})
                s,d=F.transition(s,{type='publish',facts={handles=true}})
            else
                s=F.transition(s,{type='effect',uncertain=true})
                s,d=F.transition(s,{type='publish',facts={}})
                s=F.transition(s,{type='effect',applied=true,uncertain=false})
            end
            assert.equals('unknown',d.outcome.certainty);assert.is_false(s.terminal)
            s,d=F.transition(s,{type='publish',facts={}})
            assert.is_true(d.publish);assert.is_true(s.terminal);assert.equals('applied',d.outcome.effect)
            _,d=F.transition(s,{type='request',cleanup=true});assert.is_false(d.execute)
            _,d=F.transition(s,{type='publish',facts={}});assert.is_false(d.publish)
        end
    end)
    it('owns work admission while reserving cleanup after exhaustion',function()
        local s=F.new(1);local d
        s,d=F.transition(s,{type='request'});s=F.transition(s,{type='completed',id=d.id})
        _,d=F.transition(s,{type='request'});assert.equals('capacity',d.reason)
        s,d=F.transition(s,{type='request',cleanup=true});assert.is_true(d.execute)
    end)
    it('selects cleanup only after pending evidence and never disguises a mutation as cleanup',function()
        local s=F.new(4);local d
        s,d=F.transition(s,{type='request'});local id=d.id
        _,d=F.transition(s,{type='cleanup',remaining=1,facts={handles=true}});assert.is_nil(d.action)
        _,d=F.transition(s,{type='reconcile'});assert.is_false(d.reconcile)
        s=F.transition(s,{type='completed',id=id})
        _,d=F.transition(s,{type='cleanup',remaining=1,facts={handles=true}});assert.equals('close',d.action)
        _,d=F.transition(s,{type='cleanup',remaining=0,facts={temporary=true}});assert.equals('remove_temporary',d.action)
        _,d=F.transition(s,{type='cleanup',remaining=0,facts={}});assert.equals('publish',d.action)
        s=F.transition(s,{type='cancel'})
        _,d=F.transition(s,{type='request',cleanup=true,mutation=true});assert.is_false(d.execute)
    end)
end)
