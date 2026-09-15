local D=require('parley.document')
local F=require('parley.tool_folds')
local Reader=require('parley.line_reader')
local function fixture(groups,rows)
    local lines={'💬: question','🤖: answer'}
    for i=1,groups do
        for _,line in ipairs({'🧠: thought '..i,'body','🧠:[END]','plain'}) do lines[#lines+1]=line end
    end
    while #lines<(rows or 0) do lines[#lines+1]='plain' end
    local buf=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_set_current_buf(buf);vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    local doc=D.attach(buf,{schedule=false})
    assert.equals('idle',D.drain(doc,200000,{rows=256,bytes=65536,nodes=65536,entries=65536}).status)
    return buf,doc
end

describe('bounded native fold batches',function()
    local buf
    after_each(function() if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end end)
    it('limits fold creation per step and keeps actual native folds correct',function()
        buf=fixture(150)
        F.setup(buf)
        local operations=0
        local observer=Reader.set_observer(buf,function(e) operations=operations+(e.native_fold_ops or 0) end)
        local status,steps
        for i=1,100 do
            operations=0;status=F.step(buf);steps=i
            assert.is_true(operations<=129,'one fold step performed '..operations..' native operations')
            if status=='idle' then break end
        end
        Reader.clear_observer(buf,observer)
        assert.equals('idle',status);assert.is_true(steps>=3)
        for i=1,150 do assert.equals(3+(i-1)*4,vim.fn.foldclosed(3+(i-1)*4)) end
    end)
    it('yields scheduled recreation to a native timer',function()
        buf=fixture(150)
        local seen=false
        F.setup(buf)
        vim.defer_fn(function()
            seen=true
            assert.equals(0,vim.fn.foldlevel(3+149*4))
        end,1)
        assert.is_true(vim.wait(1000,function() return seen end,1))
        assert.equals('idle',F.flush(buf))
        assert.equals(3+149*4,vim.fn.foldclosed(3+149*4))
    end)
    it('rederives coordinates after an edit between batches and preserves window views',function()
        local doc
        buf,doc=fixture(150)
        local first=vim.api.nvim_get_current_win()
        vim.cmd('vsplit')
        local second=vim.api.nvim_get_current_win()
        F.setup(buf)
        for _=1,100 do
            F.step(buf)
            if vim.fn.foldlevel(3)>0 then break end
        end
        vim.cmd('3foldopen')
        vim.api.nvim_win_set_cursor(first,{20,0});vim.api.nvim_win_set_cursor(second,{30,0})
        vim.api.nvim_buf_set_lines(buf,0,0,false,{'header'})
        D.drain(doc,10000,{rows=256,bytes=65536,nodes=65536,entries=65536})
        local views={}
        for _,win in ipairs({first,second}) do
            views[win]=vim.api.nvim_win_call(win,vim.fn.winsaveview)
        end
        assert.equals('idle',F.flush(buf))
        for _,win in ipairs({first,second}) do
            vim.api.nvim_win_call(win,function()
                assert.same(views[win],vim.fn.winsaveview())
                assert.equals(1,vim.fn.foldlevel(4))
                assert.equals(4+149*4,vim.fn.foldclosed(4+149*4))
            end)
        end
        vim.api.nvim_win_close(second,true)
    end)
    it('cancels a partially recreated native plan on file reload',function()
        local doc
        buf,doc=fixture(150)
        local path=vim.fn.tempname()..'.md'
        vim.bo[buf].buftype=''
        vim.api.nvim_buf_set_name(buf,path)
        vim.cmd('silent write!')
        F.setup(buf)
        for _=1,100 do F.step(buf);if vim.fn.foldlevel(3)>0 then break end end
        vim.fn.writefile({'💬: reloaded','new question'},path)
        vim.cmd('silent edit!')
        buf=vim.api.nvim_get_current_buf()
        doc=D.get(buf) or D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,10000).status)
        F.setup(buf)
        assert.equals('idle',F.flush(buf))
        assert.equals(0,vim.fn.foldlevel(1))
        assert.equals(0,vim.fn.foldlevel(2))
        vim.fn.delete(path)
    end)
    it('suspends broad cleanup above fifty thousand rows and restores preferences on abort',function()
        local doc
        buf,doc=fixture(150,50010)
        vim.wo.foldmethod='manual';vim.wo.foldenable=true
        for i=1,150 do vim.cmd(string.format('%d,%dfold',3+(i-1)*4,5+(i-1)*4)) end
        vim.cmd('3foldopen')
        F.setup(buf)
        for _=1,100 do F.step(buf);if not vim.wo.foldenable then break end end
        assert.is_false(vim.wo.foldenable)
        local work={ops=0,groups=0,reads=0}
        local token=Reader.set_observer(buf,function(e)
            work.ops=work.ops+(e.native_fold_ops or 0)
            work.groups=work.groups+(e.fold_groups_visited or 0)
            work.reads=work.reads+(e.lines_requested or 0)
        end)
        assert.equals('more',F.step(buf))
        Reader.clear_observer(buf,token)
        assert.is_true(work.groups<=64)
        assert.is_true(work.ops<=128)
        assert.equals(0,work.reads)
        assert.is_false(vim.wo.foldenable)
        assert.equals('idle',F.flush(buf))
        assert.is_true(vim.wo.foldenable)
        assert.equals(1,vim.fn.foldlevel(3));assert.equals(-1,vim.fn.foldclosed(3))
        assert.equals(3+149*4,vim.fn.foldclosed(3+149*4))
        vim.wo.foldenable=false
        F.apply_folds(buf)
        assert.equals('idle',F.flush(buf))
        assert.is_false(vim.wo.foldenable)
        vim.wo.foldenable=true
        F.apply_folds(buf)
        for _=1,100 do F.step(buf);if not vim.wo.foldenable then break end end
        assert.is_false(vim.wo.foldenable)
        -- Explicit logical detach cancels the batch immediately, before any
        -- scheduled callback can recreate folds against a retired document.
        D.detach(doc)
        assert.is_true(vim.wo.foldenable)
        assert.equals('idle',F.step(buf))
    end)

end)
