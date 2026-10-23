local Embedded=require('tests.helpers.embedded_nvim')
local Trace=require('tests.helpers.fold_retirement_trace')
describe('native suspended fold retirement',function()
    local child, trace
    local function exec(code)return trace:run(child,code)end
    before_each(function()
        trace=Trace.new()
        child=Embedded.start({ui={80,24}})
    end)
    after_each(function()if child then child:stop() end;if trace then trace:close() end end)
    it('restores the operator preference and view when detach interrupts suspended apply',function()
        local result=exec([[
            local trace=require('tests.helpers.fold_retirement_trace').start(...)
            local D=require('parley.document');local F=require('parley.tool_folds')
            trace:stage('modules-loaded')
            -- Cross the suspension threshold with a small fixture (#401): a
            -- 50k-row drain costs 15-25 s and says nothing more here.
            F.INTERACTIVE_ROWS=500
            local buf=vim.api.nvim_get_current_buf()
            local lines={'💬: q','🤖: a'}
            for i=1,150 do for _,line in ipairs({'🧠: thought','body','🧠:[END]','plain'}) do lines[#lines+1]=line end end
            lines[#lines+1]='💬: next question'
            while #lines<1210 do lines[#lines+1]='plain' end
            vim.api.nvim_buf_set_lines(buf,0,-1,false,lines)
            trace:stage('buffer-ready')
            local doc=D.attach(buf,{schedule=false})
            trace:observe(D,doc,buf);trace:stage('before-drain')
            assert(D.drain(doc,200000,{rows=256,bytes=65536,nodes=65536,entries=65536}).status=='idle');trace:stage('drained')
            vim.wo.foldenable=true;F.setup(buf);trace:stage('fold-setup')
            for i=1,100 do
                trace:stage('before-suspend-step-'..i);F.step(buf)
                trace:stage('after-suspend-step-'..i)
                if not vim.wo.foldenable then break end
            end
            assert(not vim.wo.foldenable,'did not suspend')
            -- Keep the saved viewport outside folds: enabling a fold necessarily
            -- canonicalizes a topline that was inside its collapsed body.
            vim.api.nvim_win_set_cursor(0,{1000,2});local before=vim.fn.winsaveview()
            local detached=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                if not detached then
                    trace:stage('detach-enter');detached=true;D.detach(doc);trace:stage('detach-exit')
                end
            end})
            trace:stage('before-retire');F.step(buf);trace:stage('retired')
            local result={detached=detached,enabled=vim.wo.foldenable,status=F.flush(buf),before=before,view=vim.fn.winsaveview()}
            trace:finish()
            return result
        ]])
        assert.is_true(result.detached);assert.equals('idle',result.status);assert.is_true(result.enabled);assert.same(result.before,result.view)
    end)
end)
