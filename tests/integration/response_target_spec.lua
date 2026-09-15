local D=require('parley.document')
local Target=require('parley.response_target')
local Runner=require('parley.generation_runner')
local buffers={}
local function fixture()
    local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
    vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: question','body','🤖: answer','text'})
    return buf,D.attach(buf,{schedule=false})
end
local function spec()
    return {operation='response',question={first={row=0,col=0},last={row=1,col=4}},
        output={first={row=1,col=4},last={row=3,col=4}},input_ref='input'}
end
describe('asynchronous native response target resolution',function()
    after_each(function()
        for _,buf in ipairs(buffers)do if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end end
        buffers={}
    end)
    it('acquires runner authority in the ready callback before provider preparation can run',function()
        local _,doc=fixture();local calls=0;local runner
        local adapters={prepare=function()calls=calls+1 end,request=function()calls=calls+1 end,finalize=function()end}
        local target=assert(Target.start(doc,spec(),{ready=function(value)
            assert.equals(0,calls)
            runner=assert(Runner.start(doc,{entity=value.entity,first=value.first,last=value.last,
                dependencies=value.dependencies,input_seed={},capabilities={},schedule=false},adapters))
            assert.is_table(D.snapshot(doc).grants[Runner.snapshot(runner).grant])
        end}))
        assert.equals('waiting',Target.snapshot(target).status);assert.equals(0,calls)
        assert.is_true(vim.wait(2000,function()return Target.snapshot(target).status~='waiting'end,1))
        assert.equals('ready',Target.snapshot(target).status);assert.is_table(runner);assert.equals(0,calls)
        Runner.cancel(runner);Runner.drain(runner,100)
    end)
    it('cancels pending native targets on deletion and releases their document callbacks',function()
        local weak=setmetatable({},{__mode='v'});local calls=0
        local function populate()
            for i=1,20 do
                local buf,doc=fixture()
                local target=assert(Target.start(doc,spec(),{ready=function()calls=calls+1 end}))
                weak[i]=target;weak[i+20]=doc
                vim.api.nvim_buf_delete(buf,{force=true})
                assert.equals('cancelled',Target.snapshot(target).status)
            end
        end
        populate();vim.wait(20,function()return false end,1)
        collectgarbage('collect');collectgarbage('collect');collectgarbage('collect')
        local retained=0;for _ in pairs(weak)do retained=retained+1 end
        assert.equals(0,retained);assert.equals(0,calls)
    end)
    it('retains consumed prefix edit evidence through native undo before admission',function()
        local buf=vim.api.nvim_create_buf(false,true);buffers[#buffers+1]=buf
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'prefix','💬: question','body','🤖: answer','text'})
        local doc=D.attach(buf,{schedule=false})
        local ready
        local target=assert(Target.start(doc,{operation='undo-prefix',schedule=false,input_prefix=true,
            question={first={row=1,col=0},last={row=2,col=4}},
            output={first={row=2,col=4},last={row=4,col=4}}},{ready=function(value)ready=value end}))
        vim.api.nvim_win_set_cursor(0,{1,0})
        local function keys(value)vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value,true,false,true),'nx',false)end
        vim.cmd('let &l:undolevels = &l:undolevels')
        keys('iX<Esc>');keys('u')
        assert.equals('prefix',vim.api.nvim_buf_get_lines(buf,0,1,false)[1])
        assert.is_true(Target.snapshot(target).input_stale)
        for _=1,100 do if Target.step(target).status~='waiting'then break end end
        assert.equals('ready',Target.snapshot(target).status);assert.is_true(ready.input_stale)
    end)

end)
