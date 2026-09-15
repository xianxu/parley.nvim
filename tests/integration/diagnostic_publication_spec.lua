local D=require('parley.document')
local Refresh=require('parley.diagnostic_refresh')

describe('revision-bound diagnostic publication callbacks',function()
    local buf,doc
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'term[^term]','','[^term]: definition'})
        doc=D.attach(buf,{schedule=false})
        assert.equals('idle',D.drain(doc,10000).status)
    end)
    after_each(function()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end
    end)
    it('runs once after the exact source diagnostics are visible',function()
        local calls,visible=0,0
        Refresh.refresh(buf,{schedule=false,on_publish=function()
            calls=calls+1
            visible=#vim.diagnostic.get(buf)
        end})
        assert.equals(0,calls)
        assert.equals('idle',Refresh.drain(buf,10000).status)
        assert.equals(1,calls)
        assert.is_true(visible>0)
        Refresh.drain(buf,10000)
        assert.equals(1,calls)
    end)
    for _,kind in ipairs({'edit','identical replacement','undo','detach'}) do
        it('cancels the old snapshot on '..kind,function()
            local published,cancelled=0,0
            vim.cmd('let &undolevels = &undolevels')
            vim.api.nvim_buf_set_text(buf,0,0,0,0,{'new '})
            D.drain(doc,10000)
            Refresh.refresh(buf,{schedule=false,on_publish=function() published=published+1 end,
                on_cancel=function() cancelled=cancelled+1 end})
            if kind=='detach' then D.detach(doc)
            elseif kind=='undo' then vim.cmd('silent undo')
            elseif kind=='identical replacement' then
                vim.api.nvim_buf_set_lines(buf,0,1,false,{'new term[^term]'})
            else vim.api.nvim_buf_set_text(buf,0,0,0,0,{'human '}) end
            assert.equals(1,cancelled)
            if kind~='detach' then Refresh.drain(buf,10000) end
            assert.equals(0,published)
            assert.equals(1,cancelled)
        end)
    end
end)
