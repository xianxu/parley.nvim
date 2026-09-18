local D=require('parley.document')
local Runner=require('parley.generation_runner')
local Target=require('parley.response_target')
local Fake=require('tests.helpers.fake_generation_runner')
local buffers={}
local function document(lines)
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    return buf,D.attach(buf,{schedule=false})
end
describe('native generation input provenance',function()
    after_each(function()
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('keeps question input fixed through an owned answer separator but stales human boundary insertion',function()
        for _,human in ipairs({false,true})do
            local buf,doc=document({'💬: question'})
            assert.equals('idle',D.drain(doc,1000).status)
            local marker=D.query(doc,0,1)[1];local seam=marker.end_byte-1
            local gen=D.transition(doc,{kind='register_generation',dependencies={{first=0,last=seam}}}).generation
            local grant=D.transition(doc,{kind='acquire',generation=gen,regions={{entity=marker.handle,
                first=seam,last=seam,marker_revision=1,revision=1,confirmed=true}}}).grants[1]
            if human then vim.api.nvim_buf_set_text(buf,0,seam,0,seam,{' human'})
            else
                local result
                for _=1,10 do
                    result=D.append(doc,{epoch=D.snapshot(doc).epoch,generation=gen,operation='separator',grant=grant,
                        entity=marker.handle,revision=1,bytes='\n\n🤖: answer'})
                    if (result.accepted_bytes or 0)>0 then break end
                end
                assert.equals(#'\n\n🤖: answer',result.accepted_bytes,vim.inspect(result))
            end
            local generation=D.snapshot(doc).generations[gen]
            assert.equals(human,generation.stale)
            if not human then assert.same({{first=0,last=seam}},generation.dependencies)end
        end
    end)
    for _,consumed in ipairs({false,true})do
        it('carries '..(consumed and 'consumed-prefix staleness' or 'excluded-suffix freshness')..' into preparation before IO',function()
            local buf,doc=document({'context','💬: question','body','🤖: answer','text'})
            local fake=Fake.new();local runner
            local target=assert(Target.start(doc,{operation='response',schedule=false,input_ref='frozen',input_prefix=true,
                question={first={row=1,col=0},last={row=2,col=4}},
                output={first={row=2,col=4},last={row=4,col=4}}},{ready=function(value)
                    assert.equals(consumed,value.input_stale)
                    runner=assert(Runner.start(doc,{entity=value.entity,first=value.first,last=value.last,
                        input={message='frozen'},dependencies=value.dependencies,input_stale=value.input_stale,
                        capabilities={},schedule=false},fake.adapters))
                end}))
            if consumed then vim.api.nvim_buf_set_text(buf,0,0,0,1,{'C'})
            else vim.api.nvim_buf_set_lines(buf,5,5,false,{'💬: other'})end
            for _=1,1000 do if Target.step(target).status~='waiting'then break end end
            assert.equals('ready',Target.snapshot(target).status)
            assert.equals(consumed,Runner.snapshot(runner).stale_input)
            assert.equals(0,#fake.preparations)
            -- #266 M1: `start` now emits request_turn before the prepare
            -- operation, so preparation begins one effect later.
            for _=1,10 do if #fake.preparations>0 then break end; Runner.step(runner) end
            assert.equals(1,#fake.preparations,'preparation never started')
            assert.equals(consumed,fake.preparations[1].ctx.stale_input)
            assert.equals('frozen',fake.preparations[1].ctx.input.message)
            Runner.cancel(runner)
            fake.preparations[1].callbacks.resolved()
            Runner.drain(runner,100)
            assert.equals('terminal',Runner.snapshot(runner).phase)
        end)
    end
end)
