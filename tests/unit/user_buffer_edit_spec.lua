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

-- #265: the one refusal policy every chat command edits through.
describe('edit_user_lines',function()
    local buf,warnings,debugs,saved
    local Capacity=require('tests.helpers.user_edit_capacity')
    before_each(function()
        buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'one','two','three'})
        D.attach(buf,{schedule=false})
        local logger=require('parley.logger')
        saved={warning=logger.warning,debug=logger.debug}
        warnings,debugs={},{}
        logger.warning=function(m)warnings[#warnings+1]=m end
        logger.debug=function(m)debugs[#debugs+1]=m end
    end)
    after_each(function()
        local logger=require('parley.logger')
        logger.warning,logger.debug=saved.warning,saved.debug
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
    end)
    it('applies and says nothing when the edit is allowed',function()
        assert.is_true(Edit.edit_user_lines('Test',buf,1,2,{'TWO'}))
        assert.same({'one','TWO','three'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same({},warnings)
    end)
    it('refuses without raising: buffer unchanged, one warning naming the command',function()
        local held=Capacity.hold(buf)
        local ok,why=Edit.edit_user_lines('NewQuestion',buf,1,2,{'TWO'})
        held.release()
        assert.is_false(ok)
        assert.equals('capacity',why)
        assert.same({'one','two','three'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same({'NewQuestion — Edit not made: too many edits are pending in this chat; try again in a moment'},warnings)
    end)
    it('logs a quiet refusal at debug only',function()
        local held=Capacity.hold(buf)
        local ok=Edit.edit_user_lines('ReadRepair',buf,1,2,{'TWO'},{quiet=true})
        held.release()
        assert.is_false(ok)
        assert.same({},warnings)
        assert.equals(1,#debugs)
        assert.is_truthy(debugs[1]:find('ReadRepair — Edit not made',1,true))
    end)
    -- #265 close BR-1: an apply that ERRORED (status 'error', the editor's
    -- own failure) reaches the user with the editor's text as the detail,
    -- not as "unexpected (error)" with nothing in the log.
    it('keeps the editor error as the warning detail',function()
        local real=Edit._replace_user_lines
        Edit._replace_user_lines=function()return nil,'error','nvim_buf_set_text: buffer is not modifiable'end
        local ok,why=Edit.edit_user_lines('ExchangePaste',buf,1,2,{'TWO'})
        Edit._replace_user_lines=real
        assert.is_false(ok);assert.equals('error',why)
        assert.equals(1,#warnings)
        assert.equals('ExchangePaste — Edit not made: the edit failed while it was being applied; edit the chat back if it changed, then try again'
            ..' — nvim_buf_set_text: buffer is not modifiable',warnings[1])
    end)
    it('applies again once the hold is released',function()
        local held=Capacity.hold(buf);held.release()
        assert.is_true(Edit.edit_user_lines('Test',buf,0,1,{'ONE'}))
    end)
end)

