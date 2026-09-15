local function child(code)
    local script=vim.fn.tempname()..'.lua'
    local output=vim.fn.tempname()..'.json'
    vim.fn.writefile(vim.split("local output="..string.format('%q',output).."\n"..code,'\n',{plain=true}),script)
    local raw=vim.fn.system({'nvim','-n','--headless','--noplugin','-u','tests/minimal_init.vim','-c','luafile '..script})
    local status=vim.v.shell_error
    local result=vim.fn.filereadable(output)==1 and table.concat(vim.fn.readfile(output),'\n') or raw
    vim.fn.delete(script);vim.fn.delete(output)
    assert.equals(0,status,result)
    return vim.json.decode(result)
end

describe('native join fold preservation',function()
    it('does zero native fold work after Enter and Backspace fully converge',function()
        local result=child([[
local T=require('tests.perf.chat_typing')
local D=require('parley.document')
local F=require('parley.tool_folds')
local scenario=T.open_fixture(100,function(n)
    local lines,target=T.build_fixture(n)
    lines[78]='🧠: reasoning';lines[82]='🧠:[END]'
    return lines,target
end)
F.setup(scenario.buf);assert(F.flush(scenario.buf)=='idle');vim.cmd('78foldopen')
local reconciles=0
F._observer=function() reconciles=reconciles+1 end
T.measure_edit_sample(scenario,{enter_join=true,timeout_ms=10000},function(sample,err)
    if not sample then vim.fn.writefile({tostring(err)},output);vim.cmd('cquit 1');return end
    assert(D.drain(scenario.document,10000).status=='idle');assert(F.flush(scenario.buf)=='idle')
    vim.fn.writefile({vim.json.encode({ops=sample.work.native_fold_ops,reconciles=reconciles,
        level=vim.fn.foldlevel(78),closed=vim.fn.foldclosed(78)})},output)
    vim.cmd('qa!')
end)
]])
        assert.equals(0,result.ops)
        assert.equals(0,result.reconciles)
        assert.equals(1,result.level);assert.equals(-1,result.closed)
    end)
    it('rebuilds folds when a native join creates a structural marker',function()
        local result=child([[
local D=require('parley.document')
local F=require('parley.tool_folds')
local buf=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: answer','🧠',': thought','body','🧠:[END]'})
local doc=D.attach(buf,{schedule=false});assert(D.drain(doc,10000).status=='idle')
F.setup(buf);assert(F.flush(buf)=='idle')
vim.api.nvim_win_set_cursor(0,{4,0})
local deadline=vim.uv.hrtime()+5000000000
local function poll(predicate,callback)
    if predicate() then return callback() end
    if vim.uv.hrtime()>deadline then error('native join timeout') end
    vim.defer_fn(function() poll(predicate,callback) end,1)
end
vim.schedule(function()
    vim.api.nvim_input('i')
    poll(function() return vim.api.nvim_get_mode().mode=='i' end,function()
        local tick=vim.api.nvim_buf_get_changedtick(buf)
        vim.api.nvim_input('<BS>')
        poll(function() return vim.api.nvim_buf_get_changedtick(buf)>tick end,function()
            assert(D.drain(doc,10000).status=='idle');assert(F.flush(buf)=='idle')
            vim.fn.writefile({vim.json.encode({first=vim.fn.foldclosed(3),last=vim.fn.foldclosedend(3),
                text=vim.api.nvim_buf_get_lines(buf,2,3,false)[1]})},output)
            vim.cmd('qa!')
        end)
    end)
end)
]])
        assert.equals('🧠: thought',result.text)
        assert.equals(3,result.first);assert.equals(5,result.last)
    end)
    it('resumes a dirty fold batch that waited for a successful deferred join',function()
        local result=child([[
local D=require('parley.document')
local F=require('parley.tool_folds')
local buf=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: answer','🧠: thought','body','tail','🧠:[END]','suffix'})
local doc=D.attach(buf,{schedule=false});assert(D.drain(doc,10000).status=='idle')
F.setup(buf);assert(F.flush(buf)=='idle');vim.cmd('3foldopen')
local reconciles=0
F._observer=function() reconciles=reconciles+1 end
vim.api.nvim_win_set_cursor(0,{5,0})
local deadline=vim.uv.hrtime()+5000000000
local function poll(predicate,callback)
    if predicate() then return callback() end
    if vim.uv.hrtime()>deadline then
        vim.fn.writefile({'dirty fold batch did not resume'},output);vim.cmd('cquit 1');return
    end
    vim.defer_fn(function() poll(predicate,callback) end,1)
end
vim.schedule(function()
    vim.api.nvim_input('i')
    poll(function() return vim.api.nvim_get_mode().mode=='i' end,function()
        local tick=vim.api.nvim_buf_get_changedtick(buf)
        F.apply_folds(buf)
        vim.api.nvim_input('<BS>')
        poll(function() return vim.api.nvim_buf_get_changedtick(buf)>tick end,function()
            assert(F.flush(buf)=='pending')
            assert(vim.fn.foldlevel(3)==0)
            -- Let the queued fold task actually stop on uncertainty. Its only
            -- wake-up after this point is the successful document repair event.
            vim.defer_fn(function()
                assert(reconciles==0)
                assert(D.drain(doc,10000).status=='idle')
                poll(function() return reconciles>0 end,function()
                    vim.fn.writefile({vim.json.encode({reconciles=reconciles,
                        level=vim.fn.foldlevel(3),closed=vim.fn.foldclosed(3),
                        text=vim.api.nvim_buf_get_lines(buf,3,4,false)[1]})},output)
                    vim.cmd('qa!')
                end)
            end,20)
        end)
    end)
end)
]])
        assert.equals(1,result.reconciles)
        assert.equals('bodytail',result.text)
        assert.equals(1,result.level);assert.equals(-1,result.closed)
    end)

end)
