local function wait(predicate)assert.is_true(vim.wait(5000,predicate,1),'file operation did not finish')end
describe('checked file tool editor completion',function()
    local root,path,buf
    before_each(function()
        root=vim.fn.tempname();vim.fn.mkdir(root,'p');path=root..'/file.txt'
        vim.fn.writefile({'old'},path)
        vim.cmd('edit '..vim.fn.fnameescape(path));buf=vim.api.nvim_get_current_buf();vim.bo[buf].autoread=true
    end)
    after_each(function()
        if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_delete(buf,{force=true})end
        vim.fn.delete(root,'rf')
    end)
    local function input(name)
        if name=='write_file'then return {file_path=path,content='changed\n'}end
        if name=='edit_file'then return {file_path=path,old_string='old',new_string='changed'}end
        return {file_path=path,edits={{old_string='old',new_string='changed',explain='test'}}}
    end
    for _,name in ipairs({'write_file','edit_file','propose_edits'})do
        it('refreshes an unmodified autoread buffer after '..name,function()
            local result
            require('parley.tools.builtin.'..name).execute_async(input(name),
                {cwd=root,root_policy={write_root=root},operation_id=name},function(v)result=v end)
            wait(function()return result and result.physical_resolved end)
            assert.equals('applied',result.effect)
            assert.same({'changed'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
            assert.is_false(vim.bo[buf].modified)
        end)
        for _,aba in ipairs({false,true})do
            it('preserves '..(aba and 'edit undo evidence' or 'human edits')..' during '..name,function()
                local result
                require('parley.tools.builtin.'..name).execute_async(input(name),
                    {cwd=root,root_policy={write_root=root},operation_id=name},function(v)result=v end)
                vim.api.nvim_buf_set_lines(buf,0,-1,false,{'human'})
                if aba then vim.api.nvim_buf_set_lines(buf,0,-1,false,{'old'});vim.bo[buf].modified=false end
                wait(function()return result and result.physical_resolved end)
                assert.equals('applied',result.effect)
                assert.same({aba and 'old' or 'human'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
                assert.is_true(result.evidence.reconciliation_required)
                assert.same({'changed'},vim.fn.readfile(path))
            end)
        end
    end
    it('refreshes an attached document through its user-edit boundary',function()
        local doc=require('parley.document').attach(buf,{schedule=false})
        require('parley.document').drain(doc,1000)
        local result
        require('parley.tools.builtin.write_file').execute_async(input('write_file'),
            {cwd=root,root_policy={write_root=root},operation_id='document'},function(v)result=v end)
        wait(function()return result and result.physical_resolved end)
        assert.same({'changed'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.is_false(vim.bo[buf].modified)
        assert.equals(0,require('parley.document').user_guard_stats(doc).live)
    end)
    for _,aba in ipairs({false,true})do
        it('keeps edits made inside refresh dirty '..tostring(aba),function()
            local Edit=require('parley.buffer_edit');local native=Edit.replace_all_lines
            Edit.replace_all_lines=function(b,lines)
                native(b,lines);native(b,{'human'})
                if aba then native(b,lines)end
            end
            local result
            require('parley.tools.builtin.write_file').execute_async(input('write_file'),
                {cwd=root,root_policy={write_root=root},operation_id='reentrant'},function(v)result=v end)
            local ok,err=pcall(wait,function()return result and result.physical_resolved end)
            Edit.replace_all_lines=native;assert.is_true(ok,tostring(err))
            assert.same({aba and 'changed' or 'human'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
            assert.is_true(vim.bo[buf].modified);assert.is_true(result.evidence.reconciliation_required)
        end)
    end
    it('sets line endings from committed bytes without reopening the file',function()
        local Refresh=require('parley.tools.file_refresh')
        local ticket=Refresh.capture(path)
        local outcome=Refresh.complete(ticket,'one\r\ntwo\r\n')
        assert.is_nil(outcome.reconciliation_required)
        assert.equals('dos',vim.bo[buf].fileformat);assert.is_true(vim.bo[buf].endofline)
        assert.same({'one','two'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same({'old'},vim.fn.readfile(path),'refresh uses committed bytes, not a pathname read')
        ticket=Refresh.capture(path);outcome=Refresh.complete(ticket,'\239\187\191bom\n')
        assert.is_nil(outcome.reconciliation_required);assert.is_true(vim.bo[buf].bomb)
        assert.same({'bom'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        ticket=Refresh.capture(path);outcome=Refresh.complete(ticket,'final')
        assert.is_nil(outcome.reconciliation_required)
        assert.equals('unix',vim.bo[buf].fileformat);assert.is_false(vim.bo[buf].endofline)
    end)
    for _,name in ipairs({'write_file','edit_file','propose_edits'})do
        it('uses the same refresh boundary for legacy '..name,function()
            local result=require('parley.tools.builtin.'..name).handler(input(name))
            assert.is_false(result.is_error)
            assert.same({'changed'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
            assert.is_false(vim.bo[buf].modified)
        end)
    end

end)
