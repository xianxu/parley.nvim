local Dispatch=require('parley.tools.dispatcher')
local uv=vim.uv or vim.loop
local function definition(name,kind)
    return {name=name or 'tool',kind=kind or 'read',description='fixture',input_schema={},
        handler=function()return {content='legacy'}end,
        execute_async=function()return 'captured'end}
end
local function call(input)return {id='call',name='tool',input=input or {}}end
describe('captured async tool dispatch',function()
    local root,outside
    before_each(function()
        root=vim.fn.tempname()..'-capture';outside=vim.fn.tempname()..'-outside'
        vim.fn.mkdir(root,'p');vim.fn.mkdir(outside,'p');vim.fn.writefile({'data'},root..'/file')
        root=uv.fs_realpath(root);outside=uv.fs_realpath(outside)
    end)
    after_each(function()vim.fn.delete(root,'rf');vim.fn.delete(outside,'rf')end)
    local function capture(def,extra)
        local opts={root_policy={write_root=root,read_roots={root}},max_bytes=1000}
        for k,v in pairs(extra or {})do opts[k]=v end
        return assert(Dispatch.capture({def},opts))
    end
    it('freezes allowed definitions and root configuration while copying model input',function()
        local def=definition();def.default_path='file'
        local policy={write_root=root,read_roots={root}}
        local profile=capture(def,{root_policy=policy});policy.write_root=outside
        def.execute_async=function()return 'mutated'end;def.default_path='../outside'
        local input={offset=2,limit=3};local request=call(input)
        local prepared=assert(Dispatch.prepare(profile,request))
        assert.same({offset=2,limit=3},input);assert.equals(root..'/file',prepared.input.path)
        assert.is_nil(prepared.input.offset);assert.is_nil(prepared.input.limit)
        assert.equals('captured',Dispatch.capabilities(profile).tool.execute_async())
        assert.is_nil(Dispatch.prepare(profile,{id='other',name='unlisted',input={}}))
        local context=Dispatch.context(profile);context.root_policy.write_root=outside
        assert.equals(root,Dispatch.context(profile).root_policy.write_root)
    end)
    it('normalizes native JSON empty objects before strict operation admission',function()
        local O=require('parley.tools.operation')
        for _,json in ipairs({'{}','{"nested":{},"array":[{}, {"deeper":{}}]}'})do
            local input=vim.json.decode(json);local before=vim.deepcopy(input)
            local prepared=assert(Dispatch.prepare(capture(definition()),call(input)))
            local function plain(value)
                if type(value)~='table'then return end
                assert.is_nil(getmetatable(value));for _,item in pairs(value)do plain(item)end
            end
            plain(prepared.input);assert.same(before,input)
            if json=='{}'then assert.equals(getmetatable(vim.empty_dict()),getmetatable(input))end
            local _,result=O.accept(O.new(),{generation='g',attempt='a',round='r',call_id='id',
                name='tool',input=prepared.input,capability_ref='captured'})
            assert.equals('accepted',result.status)
        end
    end)
    it('explicitly refuses JSON null without dropping values or changing the request',function()
        local profile=capture(definition())
        for _,json in ipairs({'{"value":null}','{"items":[{},null]}'})do
            local input=vim.json.decode(json);local before=vim.deepcopy(input)
            local prepared,reason=Dispatch.prepare(profile,call(input))
            assert.is_nil(prepared);assert.equals('unsupported JSON null in tool input',reason)
            assert.same(before,input)
        end
    end)
    it('refuses arbitrary metatables and cyclic input without invoking metadata',function()
        local invoked=false
        local profile=capture(definition())
        local hostile=setmetatable({},{__index=function()invoked=true;error('metadata')end})
        assert.is_nil(Dispatch.prepare(profile,call({nested=hostile})))
        assert.is_false(invoked)
        local forged=setmetatable({},vim.deepcopy(getmetatable(vim.empty_dict())))
        assert.is_nil(Dispatch.prepare(profile,call({nested=forged})))
        local cycle={};cycle.self=cycle
        assert.is_nil(Dispatch.prepare(profile,call(cycle)))
    end)
    it('refuses synchronous definitions in the captured runtime',function()
        local def=definition();def.execute_async=nil
        assert.is_nil(Dispatch.capture({def},{root_policy={write_root=root,read_roots={root}}}))
        assert.equals('legacy',Dispatch.execute_call(call(),{get=function()return def end}).content)
        def.execute_async=function()end;def.handler=nil
        assert.is_not_nil(Dispatch.capture({def},{root_policy={write_root=root,read_roots={root}}}))
    end)
    it('canonicalizes the nearest existing ancestor before reserving a new nested write',function()
        local def=definition('tool','write')
        def.resources=function(input)return {{scope='file',mode='write',path=input.path}}end
        local prepared=assert(Dispatch.prepare(capture(def),call({path='new/nested/file'})))
        assert.equals(root..'/new/nested/file',prepared.input.path)
        assert.same({{scope='file',mode='write',path=root..'/new/nested/file'}},prepared.claims)
        assert.is_nil(uv.fs_stat(root..'/new'))
    end)
    it('rejects symlink escapes and allows separately captured read roots only for reads',function()
        assert(uv.fs_symlink(outside,root..'/alias'))
        vim.fn.writefile({'outside'},outside..'/file')
        assert.is_nil(Dispatch.prepare(capture(definition('tool','write')),call({path='alias/new/deep/file'})))
        local policy={write_root=root,read_roots={root,outside}}
        assert.is_not_nil(Dispatch.prepare(capture(definition(),{root_policy=policy}),call({path='alias/file'})))
        assert.is_nil(Dispatch.prepare(capture(definition('tool','write'),{root_policy=policy}),call({path='alias/file'})))
    end)
    it('uses exclusive fallback claims and rejects claims that exceed captured authority',function()
        local prepared=assert(Dispatch.prepare(capture(definition()),call()))
        assert.same({{scope='global',mode='write'}},prepared.claims)
        local def=definition();def.resources=function()return {{scope='file',mode='write',path=outside..'/file'}}end
        assert.is_nil(Dispatch.prepare(capture(def),call()))
    end)
    it('uses the same frozen per-definition config for resource claims and scheduler capabilities',function()
        local def=definition();def.config={path=root..'/file'}
        def.resources=function(_,context)return {{scope='file',mode='read',path=context.config.path}}end
        local profile=capture(def);def.config.path=outside..'/secret'
        local cap=Dispatch.capabilities(profile);cap.tool.config.path=outside
        assert.equals(root..'/file',Dispatch.prepare(profile,call()).claims[1].path)
        assert.equals(root..'/file',Dispatch.capabilities(profile).tool.config.path)
    end)
    it('rejects sparse or malformed paths and claims before scheduler admission',function()
        assert.is_nil(Dispatch.prepare(capture(definition()),call({paths={[2]='file'}})))
        local def=definition();def.resources=function()return {[2]={scope='file',mode='read',path=root}}end
        assert.is_nil(Dispatch.prepare(capture(def),call()))
    end)
    it('keeps explicit legacy execution inputs immutable under the same preparation helpers',function()
        local def=definition();def.default_path='file'
        local observed;def.handler=function(input)observed=input;return {content='one\ntwo'}end
        local request=call({offset=2,limit=1})
        local result=Dispatch.execute_call(request,{get=function()return def end},{cwd=root})
        assert.equals(root..'/file',observed.path);assert.same({offset=2,limit=1},request.input)
        assert.truthy(result.content:find('two',1,true))
    end)
    it('normalizes once from private preparation evidence without mutating backend output',function()
        local prepared=assert(Dispatch.prepare(capture(definition()),call({offset=2,limit=1})))
        local result={content='one\ntwo\nthree'}
        local normalized=Dispatch.normalize(prepared.token,result)
        assert.equals('call',normalized.id);assert.equals('tool',normalized.name)
        assert.truthy(normalized.content:find('two',1,true));assert.is_nil(result.id)
        assert.equals('one\ntwo\nthree',result.content)
    end)
    it('preserves only positively confirmed pre-image evidence when capping writes',function()
        local prepared=assert(Dispatch.prepare(capture(definition('tool','write'),{max_bytes=256}),call()))
        local result={content=string.rep('write output ',100)}
        local normalized=Dispatch.normalize(prepared.token,result,{backup_confirmed=true,backup_path=root..'/backup'})
        assert.truthy(normalized.content:find('\npre-image: '..root..'/backup',1,true))
        assert.is_true(#normalized.content<=256)
        assert.is_nil(Dispatch.normalize(prepared.token,result,{backup_path=root..'/backup'}).content:find('pre-image:',1,true))
    end)    it('refuses an unrepresentable confirmed footer within the total result limit',function()
        local prepared=assert(Dispatch.prepare(capture(definition('tool','write'),{max_bytes=4}),call()))
        local result=Dispatch.normalize(prepared.token,{content='done'},{backup_confirmed=true,backup_path=root..'/backup'})
        assert.is_true(result.is_error);assert.is_true(result.truncated)
        assert.equals('[Tool result incomplete]\n',result.content)
    end)

end)
