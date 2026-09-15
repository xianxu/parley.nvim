local Producer=require('parley.tools.producer')
local Scheduler=require('parley.tools.scheduler')
require('parley.tools').register_builtins()
local Serialize=require('parley.tools.serialize')
local Wire=require('parley.tools.wire_openai')
local NOTICE='[Tool result incomplete]'
local function visible(result)
    assert.is_true(result.truncated)
    assert.truthy(result.content:find(NOTICE,1,true))
    assert.truthy(Serialize.render_result(result):find(NOTICE,1,true))
    local messages={{role='user',content={{type='tool_result',tool_use_id=result.id or 'a',
        content=result.content,is_error=result.is_error}}}}
    local translated=Wire.translate_messages(messages)
    assert.truthy(translated[1].content:find(NOTICE,1,true))
end
describe('truthful bounded tool result publication',function()
    it('publishes a native 600000-byte read as incomplete through transcript and provider text',function()
        local root=vim.fn.tempname();vim.fn.mkdir(root,'p')
        local path=root..'/large.txt';vim.fn.writefile({string.rep('x',600000)},path,'b')
        local producer=assert(Producer.new({allowed_tools={'read_file'},
            root_policy={write_root=root,read_roots={root}},buf=777,max_result_bytes=524288}))
        local result,done
        producer.start({id='large',name='read_file',input={path=path}},
            {epoch=1,generation=1,round=1,attempt=1},
            {outcome=function(kind,value)assert.equals('known',kind);result=value end,resolved=function()done=true end})
        local settled=vim.wait(5000,function()return done end,1)
        producer.close();vim.fn.delete(root,'rf')
        assert.is_true(settled);assert.is_false(result.is_error)
        visible(result);assert.is_true(#result.content<=524288)
    end)
    it('publishes an omission notice even when the aggregate body capacity is exhausted',function()
        local queue={};local service=Scheduler.new({limits={max_result_bytes=4,max_total_result_bytes=4},
            schedule=function(fn)queue[#queue+1]=fn end})
        local gen=assert(service:generation({document='d',logical_generation='g',capabilities={fixture={
            execute_async=function(_,_,done)
                done({certainty='known',effect='not_applied',physical_resolved=true,result={content='abcd'}})
                return {cancel=function()end}
            end}}}))
        local results={}
        for _,id in ipairs({'a','b'})do
            assert(service:execute(gen,{attempt='1',round='1',call_id=id,name='fixture',input={},claims={}},
                {outcome=function(_,value)results[id]=value end}))
        end
        while #queue>0 do table.remove(queue,1)()end
        assert.equals('abcd',results.a.content)
        visible(results.b)
        assert.equals(4,service:stats().result_bytes)
        service:close_generation(gen)
    end)    it('retains incompleteness when a custom normalizer returns shorter text without flags',function()
        local queue={};local service=Scheduler.new({limits={max_result_bytes=32,max_total_result_bytes=32},
            schedule=function(fn)queue[#queue+1]=fn end,normalize=function()return {content='ok'}end})
        local gen=assert(service:generation({document='d',logical_generation='g',capabilities={fixture={
            execute_async=function(_,_,done)
                done({certainty='known',effect='not_applied',physical_resolved=true,result={content=string.rep('x',100)},evidence={reconciliation_required=true}})
                return {cancel=function()end}
            end}}}))
        local result
        service:execute(gen,{attempt='1',round='1',call_id='a',name='fixture',input={},claims={}},
            {outcome=function(_,value)result=value end})
        while #queue>0 do table.remove(queue,1)()end
        service:close_generation(gen)
        visible(result)
        assert.truthy(result.content:find('[Disk updated; buffer reconciliation required]',1,true))
    end)
    it('marks a clipped capability refusal instead of returning an unexplained character',function()
        local producer=assert(Producer.new({allowed_tools={},max_result_bytes=1}))
        local result
        producer.start({id='a',name='missing',input={}},{},{outcome=function(_,value)result=value end})
        producer.close()
        assert.is_true(result.is_error);visible(result)
    end)

end)
