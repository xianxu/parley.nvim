-- Probe the native behavior the incremental fold adapter relies on with a real UI.
describe('document native fold adjustment', function()
    local child
    local function exec(code, ...)
        return vim.rpcrequest(child, 'nvim_exec_lua', code, { ... })
    end
    before_each(function()
        child = vim.fn.jobstart({ vim.v.progpath, '--clean', '--embed', '--headless', '-i', 'NONE' }, { rpc = true })
        vim.rpcrequest(child, 'nvim_ui_attach', 100, 30, { rgb = true })
        exec([[
            vim.wo.foldmethod='manual'; vim.wo.foldminlines=0; vim.wo.scrolloff=0
            local lines={'💬: q','🤖: a','🧠: thought','body','🧠:[END]','plain','💬: next','draft'}
            for i=1,200 do lines[#lines+1]='tail '..i end
            vim.api.nvim_buf_set_lines(0,0,-1,false,lines)
            vim.cmd('3,5fold')
            vim.fn.winrestview({lnum=100,col=0,topline=90})
            vim.cmd('redraw')
        ]])
    end)
    after_each(function()
        vim.fn.jobstop(child)
        vim.fn.jobwait({ child }, 1000)
    end)
    it('moves an existing fold on interior insertion without recreating it', function()
        local result=exec([[
            vim.api.nvim_buf_set_text(0,3,2,3,2,{'dy','continued'})
            return {vim.fn.foldclosed(3),vim.fn.foldclosedend(3),vim.fn.foldlevel(7)}
        ]])
        assert.same({3,6,0},result)
    end)
    it('preserves open state and view when only the next draft changes', function()
        exec("vim.cmd('3foldopen'); vim.fn.winrestview({lnum=100,col=0,topline=90}); vim.cmd('redraw')")
        local before=exec('return vim.fn.winsaveview()')
        exec("vim.api.nvim_buf_set_text(0,7,5,7,5,{' more'}); vim.cmd('redraw')")
        assert.same(before,exec('return vim.fn.winsaveview()'))
        assert.equals(-1,exec('return vim.fn.foldclosed(3)'))
        assert.equals(1,exec('return vim.fn.foldlevel(3)'))
    end)
    it('requires structural repair after a fold marker is deleted', function()
        exec('vim.api.nvim_buf_set_lines(0,2,3,false,{})')
        assert.equals(1,exec('return vim.fn.foldlevel(3)'))
        -- Native movement alone is insufficient: the old fold survives on prose.
        exec("local view=vim.fn.winsaveview(); vim.api.nvim_win_set_cursor(0,{3,0}); vim.cmd('normal! zD'); vim.fn.winrestview(view)")
        assert.equals(0,exec('return vim.fn.foldlevel(3)'))
    end)
end)
