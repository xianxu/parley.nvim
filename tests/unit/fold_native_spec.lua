local Native=require('parley.fold_native')

describe('fold_native inventory',function()
    local buf,win
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf);win=vim.api.nvim_get_current_win()
        vim.wo.foldmethod='manual';vim.wo.foldenable=true
        local lines={};for i=1,30 do lines[i]='row '..i end
        vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
    end)
    after_each(function() vim.api.nvim_buf_delete(buf,{force=true}) end)
    local function states()
        local out={};for row=1,30 do out[row]={vim.fn.foldlevel(row),vim.fn.foldclosed(row)} end;return out
    end
    it('reports exact outer extents, open state and nesting without changing folds',function()
        vim.cmd('3,5fold');vim.cmd('3foldopen')          -- open, flat
        vim.cmd('8,10fold')                               -- closed, flat
        vim.cmd('14,20fold');vim.cmd('14foldopen')         -- outer open ...
        vim.cmd('14,16fold')                              -- ... inner closed on the outer's first row
        vim.cmd('24,26fold');vim.cmd('24foldopen');vim.cmd('25,26fold') -- inner starts later, outer open
        local before=states()
        local folds,_,done=Native.walk(buf,win,0,29,nil,nil,nil,nil,'inventory')
        assert.is_true(done)
        assert.same({
            {start_0=2,end_0=4,open=true,nested=false},
            {start_0=7,end_0=9,open=false,nested=false},
            {start_0=13,end_0=19,open=true,nested=true},
            {start_0=23,end_0=25,open=true,nested=true},
        },folds)
        local after=states()
        -- Outer open/closed state of every group is unchanged; flat groups are unchanged exactly.
        for _,row in ipairs({3,4,5,8,9,10}) do assert.same(before[row],after[row],'row '..row) end
        assert.equals(-1,vim.fn.foldclosed(20),'outer of nested group 1 stays open')
        assert.equals(-1,vim.fn.foldclosed(24),'outer of nested group 2 stays open')
    end)
    it('handles a fold that ends on the last row',function()
        vim.cmd('28,30fold')
        local folds,_,done=Native.walk(buf,win,0,29,nil,nil,nil,nil,'inventory')
        assert.is_true(done)
        assert.same({{start_0=27,end_0=29,open=false,nested=false}},folds)
        assert.equals(28,vim.fn.foldclosed(29))
    end)
    it('pages a large span across calls without mutating',function()
        for r=1,28,3 do vim.cmd(r..','..(r+1)..'fold') end
        local all,row,done={},0,false
        for _=1,20 do
            local folds,next_row
            folds,next_row,done=Native.walk(buf,win,row,29,8,nil,nil,nil,'inventory')
            vim.list_extend(all,folds);row=next_row
            if done then break end
        end
        assert.is_true(done)
        assert.equals(10,#all)
        for i,f in ipairs(all) do assert.equals((i-1)*3,f.start_0) end
    end)
end)
