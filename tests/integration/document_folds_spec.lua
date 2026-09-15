local D=require('parley.document')
local F=require('parley.tool_folds')
describe('document indexed fold reconciliation',function()
    local buf,doc,win
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true);vim.api.nvim_set_current_buf(buf)
        win=vim.api.nvim_get_current_win()
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{
            '💬: q','🤖: a','🧠: thought','body','🧠:[END]','plain','💬: next','draft'})
        doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc).status)
        F.setup(buf)
        F.flush(buf)
    end)
    after_each(function() if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end end)
    it('folds confirmed sections without full buffer materialization',function()
        assert.equals(3,vim.fn.foldclosed(3));assert.equals(5,vim.fn.foldclosedend(3))
        assert.equals(-1,vim.fn.foldclosed(7))
    end)
    it('does no native fold work while typing the next question',function()
        vim.cmd('3foldopen')
        local events={};F._observer=function(e) events[#events+1]=e end
        vim.api.nvim_buf_set_text(buf,7,5,7,5,{' more'})
        F.flush(buf)
        F._observer=nil
        assert.equals(0,#events)
        assert.equals(-1,vim.fn.foldclosed(3));assert.equals(1,vim.fn.foldlevel(3))
    end)
    it('removes stale folds after marker deletion without folding questions',function()
        vim.api.nvim_buf_set_lines(buf,2,3,false,{})
        D.drain(doc);F.flush(buf)
        assert.equals(0,vim.fn.foldlevel(3))
        assert.equals(0,vim.fn.foldlevel(6))
    end)
    it('keeps an existing fold open through structural repair',function()
        vim.cmd('3foldopen')
        vim.api.nvim_buf_set_lines(buf,5,6,false,{'📝: summary'})
        D.drain(doc);F.flush(buf)
        assert.equals(1,vim.fn.foldlevel(3));assert.equals(-1,vim.fn.foldclosed(3))
        assert.equals(6,vim.fn.foldclosed(6))
    end)
    it('clears affected folds while the structure is uncertain',function()
        vim.api.nvim_buf_set_lines(buf,2,3,false,{'plain marker replacement'})
        F.flush(buf)
        assert.equals(0,vim.fn.foldlevel(3))
        D.drain(doc);F.flush(buf)
        assert.equals(0,vim.fn.foldlevel(3))
    end)    it('preserves a proven prefix and restores open suffix folds after uncertainty',function()
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{
            '💬: first','🤖: a','🧠: one','body','🧠:[END]',
            '💬: second','🤖: b','body','📝: summary','summary body',
            '💬: third','🤖: c','🧠: three','body','🧠:[END]',
        })
        D.drain(doc);F.flush(buf)
        vim.cmd('3foldopen');vim.cmd('13foldopen')
        vim.api.nvim_buf_set_lines(buf,7,8,false,{'📝: added'})
        for _=1,100 do
            if (D.uncertain_range(doc) or {first=15}).first>=5 then break end
            D.repair_step(doc)
        end
        assert.is_true(D.uncertain_range(doc).first>=5)
        F.flush(buf)
        assert.equals(1,vim.fn.foldlevel(3));assert.equals(-1,vim.fn.foldclosed(3))
        assert.equals(0,vim.fn.foldlevel(9));assert.equals(0,vim.fn.foldlevel(13))
        D.drain(doc);F.flush(buf)
        assert.equals(1,vim.fn.foldlevel(13));assert.equals(-1,vim.fn.foldclosed(13))
    end)
    it('prunes retired open hints in bounded slices across repeated invalidations',function()
        local lines={'💬: q','🤖: a'}
        for i=1,100 do
            lines[#lines+1]='🧠: '..i;lines[#lines+1]='body';lines[#lines+1]='🧠:[END]'
        end
        local lookup=D.lookup
        local per_step=0
        D.lookup=function(...) per_step=per_step+1;return lookup(...) end
        local ok,err=pcall(function()
            for _=1,4 do
                vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
                assert.equals('idle',D.drain(doc,100000).status);assert.equals('idle',F.flush(buf))
                vim.api.nvim_buf_set_text(buf,0,0,0,#'💬: q',{'plain'})
                for _=1,100 do
                    per_step=0
                    local status=F.step(buf)
                    assert.is_true(per_step<=64)
                    if status~='more' then break end
                end
                -- Delete every captured marker identity before the next cycle.
                vim.api.nvim_buf_set_lines(buf,0,-1,false,{'plain'})
                local total=0
                for _=1,100 do
                    per_step=0
                    local status=F.step(buf);total=total+per_step
                    assert.is_true(per_step<=64)
                    if status~='more' then break end
                end
                assert.is_true(total<=100)
                D.drain(doc,100000);F.flush(buf)
            end
        end)
        D.lookup=lookup
        assert.is_true(ok,tostring(err))
    end)

end)
