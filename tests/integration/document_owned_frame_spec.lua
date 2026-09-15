local E=require('parley.document.editor')

describe('owned native callback frames',function()
    it('commits the first provider chunk after finite preparation in a 1000-row chat',function()
        local output=vim.fn.tempname()..'.json'
        local code="require('tests.perf.ownership').run_probe(1000,"..vim.fn.string(output)..")"
        local log=vim.fn.system({'nvim','-n','--headless','--noplugin','-u','tests/minimal_init.vim','-c','lua '..code})
        assert.equals(0,vim.v.shell_error,log)
        local sample=vim.json.decode(table.concat(vim.fn.readfile(output),'\n'))
        vim.fn.delete(output)
        assert.equals(2,sample.deliveries)
        assert.is_true(sample.human_preserved)
        assert.is_true(sample.stream_before_human)
    end)

    it('authenticates an owned append after saving advances tick without an edit callback',function()
        local buf=vim.api.nvim_create_buf(true,false)
        local path=vim.fn.tempname()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_name(buf,path)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'body'})
        local events={}
        local editor=E.new(buf,{epoch=1,on_event=function(event)events[#events+1]=event end})
        editor:attach()
        local before=vim.api.nvim_buf_get_changedtick(buf)
        vim.cmd('silent write')
        assert.is_true(vim.api.nvim_buf_get_changedtick(buf)>before)
        assert.equals(0,#events,'save has no editor callback')
        local result=editor:apply({epoch=1,generation=1,grant=1,entity='question',operation='stream',patches={
            {start={row=0,col=4,byte=4},finish={row=0,col=4,byte=4},expected_old='',text=' output'},
        }},function()return true end)
        vim.api.nvim_buf_delete(buf,{force=true});vim.fn.delete(path)
        assert.equals('applied',result.status)
        assert.is_true(result.receipts[1].source_frame)
        assert.equals('stream',result.receipts[1].owner.operation)
    end)

    it('does not authenticate a nested human edit as the pending owned patch',function()
        local buf=vim.api.nvim_create_buf(false,true)
        vim.api.nvim_buf_set_lines(buf,0,-1,false,{'body','tail'})
        local editor,events
        events={}
        editor=E.new(buf,{epoch=1,on_event=function(event)events[#events+1]=event end})
        editor:attach()
        local set_text=editor.driver.set_text
        editor.driver.set_text=function(...)
            vim.api.nvim_buf_set_text(buf,1,0,1,0,{'human '})
            set_text(...)
        end
        local result=editor:apply({epoch=1,generation=1,grant=1,entity='question',operation='stream',patches={
            {start={row=0,col=4,byte=4},finish={row=0,col=4,byte=4},expected_old='',text=' output'},
        }},function()return true end)
        vim.api.nvim_buf_delete(buf,{force=true})
        assert.equals('interrupted',result.status)
        assert.is_nil(events[1].owner)
    end)
end)
