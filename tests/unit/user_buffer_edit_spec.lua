local Edit=require('parley.buffer_edit')
local D=require('parley.document')
describe('user line hunk transactions',function()
    local buf
    after_each(function() if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf,{force=true}) end end)
    local function change(before,after)
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,before)
        D.attach(buf,{schedule=false})
        local capture=assert(Edit.capture_user(buf,'explicit-transform',{
            {first={row=0,col=0},last={row=#before-1,col=#before[#before]}},
        }))
        assert.equals('applied',Edit.apply_user_line_hunks(capture,before,after).status)
        assert.same(after,vim.api.nvim_buf_get_lines(buf,0,-1,false))
    end
    it('deletes the final row without inventing a trailing blank row',function()
        change({'first','tail'},{'first'})
    end)
    it('appends UTF8 rows at EOF exactly once',function()
        change({'first'},{'first','λ','end'})
    end)
    it('replaces multiple separated local ranges in one undo transaction',function()
        local before={'one','middle','three'}
        change(before,{'ONE','middle','THREE'})
        vim.cmd('silent undo')
        assert.same(before,vim.api.nvim_buf_get_lines(buf,0,-1,false))
    end)
end)
