local Embedded=require('tests.helpers.embedded_nvim')
describe('native suspended fold retirement',function()
    local child
    local function exec(code,...)return child:exec(code,...)end
    before_each(function()
        child=Embedded.start({ui={80,24}})
    end)
    after_each(function()child:stop()end)
    it('restores the operator preference and view when detach interrupts suspended uncertainty',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            -- Cross the suspension threshold with a small fixture (#401): a
            -- 50k-row drain costs 15-25 s and says nothing more here.
            F.INTERACTIVE_ROWS=500
            local buf=vim.api.nvim_get_current_buf()
            local lines={'💬: q','🤖: a'}
            for i=1,150 do for _,line in ipairs({'🧠: thought','body','🧠:[END]','plain'}) do lines[#lines+1]=line end end
            lines[#lines+1]='💬: next question'
            while #lines<1210 do lines[#lines+1]='plain' end
            vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
            local doc=D.attach(buf,{schedule=false})
            assert(D.drain(doc,200000,{rows=256,bytes=65536,nodes=65536,entries=65536}).status=='idle')
            vim.wo.foldmethod='manual';vim.wo.foldenable=true
            for i=1,150 do vim.cmd(string.format('%d,%dfold',3+(i-1)*4,5+(i-1)*4)) end
            F.setup(buf)
            vim.api.nvim_buf_set_text(buf,0,0,0,#'💬: q',{'```'})
            assert(D.uncertain_range(doc))
            for i=1,100 do F.step(buf);if not vim.wo.foldenable then break end end
            assert(not vim.wo.foldenable,'did not suspend')
            -- Keep the saved viewport outside folds: enabling a fold necessarily
            -- canonicalizes a topline that was inside its collapsed body.
            vim.api.nvim_win_set_cursor(0,{1000,2});local before=vim.fn.winsaveview()
            local detached=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                if not detached then detached=true;D.detach(doc) end
            end})
            F.step(buf)
            return {detached=detached,enabled=vim.wo.foldenable,status=F.flush(buf),before=before,view=vim.fn.winsaveview()}
        ]])
        assert.is_true(result.detached);assert.equals('idle',result.status);assert.is_true(result.enabled);assert.same(result.before,result.view)
    end)
end)
