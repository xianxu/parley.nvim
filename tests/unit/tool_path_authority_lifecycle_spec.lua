local FS=require('parley.tools.filesystem')
local Fake=require('tests.helpers.fake_tool_filesystem')
describe('path worker descriptor quarantine joins filesystem settlement',function()
    it('retains physical ownership until the runtime positively resolves its intermediate descriptor',function()
        local runtime,f=Fake.new();f.put('/','', 'directory');f.put('/file','inside')
        local unresolved=true;local probes=0
        runtime.unresolved=function()return unresolved end
        runtime.reconcile=function()probes=probes+1 end
        local fs=FS.new({runtime=runtime,schedule=f.schedule});local result
        local handle=fs:read('/file',function(v)result=v end);f.drain()
        assert.equals('inside',result.data);assert.equals('unknown',result.certainty)
        assert.is_false(result.physical_resolved)
        local closes=f.count('close');handle:reconcile();f.drain()
        assert.equals(1,probes);assert.is_false(result.physical_resolved)
        assert.equals(closes,f.count('close'),'ambiguous worker handles must not receive guessed closes')
        unresolved=false;handle:reconcile();f.drain()
        assert.equals('known',result.certainty);assert.is_true(result.physical_resolved)
    end)
end)
