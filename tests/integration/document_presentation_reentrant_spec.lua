describe('native presentation publication ownership',function()
    local child
    local function exec(code,...)return vim.rpcrequest(child,'nvim_exec_lua',code,{...})end
    before_each(function()
        child=vim.fn.jobstart({vim.v.progpath,'--clean','--embed','--headless','-i','NONE'},{rpc=true})
        vim.rpcrequest(child,'nvim_ui_attach',80,24,{rgb=true})
        exec("vim.opt.rtp:append(...)",vim.fn.getcwd())
    end)
    after_each(function()vim.fn.jobstop(child);vim.fn.jobwait({child},1000)end)
    it('does not clear newer fold work after an OptionSet callback edits and repairs',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]','plain'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf)
            local created,edited=false,false
            F._observer=function(e)if e.phase=='reconcile' then created=true end end
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                if created and not edited then
                    edited=true
                    vim.api.nvim_buf_set_lines(buf,2,3,false,{'plain'})
                    D.drain(doc,1000)
                end
            end})
            F.flush(buf);F.flush(buf)
            F._observer=nil
            return {edited=edited,level=vim.fn.foldlevel(3)}
        ]])
        assert.is_true(result.edited);assert.equals(0,result.level)
    end)
    it('does not clear a newer fold job created reentrantly without a text edit',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf)
            local calls,reentered=0,false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                calls=calls+1
                if calls==4 then reentered=true;F.apply_folds(buf);F.flush(buf) end
            end})
            F.flush(buf);F.flush(buf)
            return {reentered=reentered,level=vim.fn.foldlevel(3)}
        ]])
        assert.is_true(result.reentered);assert.equals(1,result.level)
    end)
    it('stops configuring a detached document after an option callback',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf);F.flush(buf)
            vim.wo.foldcolumn='3';vim.wo.foldminlines=5
            local detached=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldtext',callback=function()
                if not detached then detached=true;D.detach(doc) end
            end})
            F.apply_folds(buf);local ok=pcall(F.flush,buf)
            return {ok=ok,detached=detached,column=vim.wo.foldcolumn,minlines=vim.wo.foldminlines,
                generation=vim.b[buf].parley_fold_generation}
        ]])
        assert.is_true(result.ok);assert.is_true(result.detached)
        assert.equals('3',result.column);assert.equals(5,result.minlines);assert.is_nil(result.generation)
    end)
    it('keeps the renderer native boundary read-only under redraw textlock',function()
        local result=exec([[
            local buf=vim.api.nvim_get_current_buf();vim.api.nvim_buf_set_lines(buf,0,-1,false,{'visible'})
            local other=vim.api.nvim_open_win(buf,false,{relative='editor',row=1,col=1,width=20,height=3})
            local entered=0
            vim.api.nvim_create_autocmd({'WinEnter','BufEnter'},{callback=function()entered=entered+1 end})
            vim.api.nvim_win_call(other,vim.fn.winsaveview)
            local attempted,changed=false,false
            vim.api.nvim_set_decoration_provider(vim.api.nvim_create_namespace('read-only-probe'),{
                on_win=function(_,win,b)
                    if b==buf then
                        vim.api.nvim_win_call(win,vim.fn.winsaveview)
                        attempted=true;changed=pcall(vim.api.nvim_buf_set_lines,buf,0,1,false,{'changed'})
                    end
                end})
            vim.cmd('redraw!')
            return {entered=entered,attempted=attempted,changed=changed,line=vim.api.nvim_buf_get_lines(buf,0,1,false)[1]}
        ]])
        assert.equals(0,result.entered);assert.is_true(result.attempted)
        assert.is_false(result.changed);assert.equals('visible',result.line)
    end)
    it('restores disabled folds and the view after an inert edit supersedes a slice',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]','plain'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf)
            vim.wo.foldenable=false
            vim.api.nvim_win_set_cursor(0,{6,2});local view=vim.fn.winsaveview()
            local edited=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                if not edited then edited=true;vim.api.nvim_buf_set_text(buf,5,0,5,1,{'p'})end
            end})
            F.flush(buf);F.flush(buf)
            local result={edited=edited,enabled=vim.wo.foldenable,view=vim.fn.winsaveview(),before=view}
            vim.wo.foldenable=true;result.level=vim.fn.foldlevel(3);return result
        ]])
        assert.is_true(result.edited);assert.is_false(result.enabled)
        assert.same(result.before,result.view);assert.equals(1,result.level)
    end)
    it('retries window configuration after an inert callback edit instead of reporting an empty plan complete',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]','plain'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf)
            local edited=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldminlines',callback=function()
                if not edited then edited=true;vim.api.nvim_buf_set_text(buf,5,0,5,1,{'p'})end
            end})
            local first,second=F.flush(buf),F.flush(buf)
            return {edited=edited,first=first,second=second,level=vim.fn.foldlevel(3)}
        ]])
        assert.is_true(result.edited);assert.equals('idle',result.second);assert.equals(1,result.level)
    end)

    it('restores operator state when native uncertainty clearing is superseded',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]','plain'})
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000);F.setup(buf);F.flush(buf)
            vim.wo.foldenable=false;vim.api.nvim_win_set_cursor(0,{6,2});local before=vim.fn.winsaveview()
            vim.api.nvim_buf_set_text(buf,0,0,0,#'💬: q',{'🤖: q'})
            local edited=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldenable',callback=function()
                if not edited then edited=true;vim.api.nvim_buf_set_text(buf,5,0,5,1,{'p'})end
            end})
            F.flush(buf,10)
            return {edited=edited,enabled=vim.wo.foldenable,before=before,view=vim.fn.winsaveview()}
        ]])
        assert.is_true(result.edited);assert.is_false(result.enabled);assert.same(result.before,result.view)
    end)
    it('schedules surviving windows when setup loses one window during configuration',function()
        local result=exec([[
            local D=require('parley.document');local F=require('parley.tool_folds')
            local buf=vim.api.nvim_get_current_buf()
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'💬: q','🤖: a','🧠: think','body','🧠:[END]'})
            vim.cmd('vsplit')
            local first=vim.fn.win_findbuf(buf)[1]
            local other=vim.fn.win_findbuf(buf)[2]
            local scratch=vim.api.nvim_create_buf(false,true)
            local doc=D.attach(buf,{schedule=false});D.drain(doc,1000)
            local switched=false
            vim.api.nvim_create_autocmd('OptionSet',{pattern='foldminlines',callback=function()
                if not switched then switched=true;vim.api.nvim_win_set_buf(first,scratch)end
            end})
            F.setup(buf)
            local ready=vim.wait(1500,function()
                return vim.api.nvim_win_call(other,function()return vim.fn.foldlevel(3)==1 end)
            end,1)
            return {switched=switched,ready=ready}
        ]])
        assert.is_true(result.switched);assert.is_true(result.ready)
    end)

end)
