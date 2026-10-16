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
    it('defers only the captured completion owner, preserving alias refresh',function()
        local alias=vim.api.nvim_create_buf(true,false)
        vim.api.nvim_buf_set_name(alias,root..'/alias.txt')
        assert(vim.uv.fs_symlink(path,root..'/alias.txt'))
        vim.api.nvim_buf_set_lines(alias,0,-1,false,{'old'})
        vim.bo[alias].modified=false;vim.bo[alias].autoread=true
        local Refresh=require('parley.tools.file_refresh')
        local ticket=Refresh.capture(path,buf)
        local result=Refresh.complete(ticket,'changed\n')
        assert.is_nil(result.reconciliation_required)
        assert.same({'old'},vim.api.nvim_buf_get_lines(buf,0,-1,false))
        assert.same({'changed'},vim.api.nvim_buf_get_lines(alias,0,-1,false))
        vim.api.nvim_buf_delete(alias,{force=true})
    end)
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

    -- #358: the refresh replaces the whole buffer, which keeps only line
    -- numbers; each window's cursor and top line follow their text instead.
    describe('keeps every window on its text (#358)',function()
        local function numbered(n,extra)
            local t={};for i=1,n do t[#t+1]='line '..i end
            for _,l in ipairs(extra or {})do t[#t+1]=l end
            return t
        end
        local function bytes(lines)return table.concat(lines,'\n')..'\n'end
        local wins
        before_each(function()
            vim.fn.writefile(numbered(60),path);vim.cmd('silent edit!')
            vim.o.lines=40
            vim.cmd('silent! only');vim.cmd('split')
            wins=vim.fn.win_findbuf(buf);table.sort(wins)
            vim.api.nvim_win_call(wins[1],function()vim.fn.winrestview({lnum=20,col=3,topline=15})end)
            vim.api.nvim_win_call(wins[2],function()vim.fn.winrestview({lnum=40,col=0,topline=35})end)
        end)
        after_each(function()vim.cmd('silent! only')end)
        local function view(win)return vim.api.nvim_win_call(win,vim.fn.winsaveview)end
        for _,document in ipairs({false,true})do
            local kind=document and 'an attached document' or 'a plain buffer'
            it('shifts both cursors with lines added above, in '..kind,function()
                if document then
                    local doc=require('parley.document').attach(buf,{schedule=false})
                    require('parley.document').drain(doc,1000)
                end
                local Refresh=require('parley.tools.file_refresh')
                local new={'new a','new b','new c'};vim.list_extend(new,numbered(60))
                local outcome=Refresh.complete(Refresh.capture(path),bytes(new))
                assert.is_nil(outcome.reconciliation_required)
                assert.same(new,vim.api.nvim_buf_get_lines(buf,0,-1,false))
                local a,b=view(wins[1]),view(wins[2])
                assert.same({23,3,18},{a.lnum,a.col,a.topline})
                assert.same({43,0,38},{b.lnum,b.col,b.topline})
            end)
            it('leaves cursor and top line exact when lines are appended below, in '..kind,function()
                if document then
                    local doc=require('parley.document').attach(buf,{schedule=false})
                    require('parley.document').drain(doc,1000)
                end
                local Refresh=require('parley.tools.file_refresh')
                local new=numbered(60,{'tail 1','tail 2'})
                local outcome=Refresh.complete(Refresh.capture(path),bytes(new))
                assert.is_nil(outcome.reconciliation_required)
                assert.same(new,vim.api.nvim_buf_get_lines(buf,0,-1,false))
                local a,b=view(wins[1]),view(wins[2])
                assert.same({20,3,15},{a.lnum,a.col,a.topline})
                assert.same({40,0,35},{b.lnum,b.col,b.topline})
            end)
        end
        it('leaves the views alone when the refresh is refused',function()
            local Refresh=require('parley.tools.file_refresh')
            local ticket=Refresh.capture(path)
            vim.api.nvim_buf_set_lines(buf,0,0,false,{'human'})
            local outcome=Refresh.complete(ticket,bytes(numbered(60)))
            assert.is_true(outcome.reconciliation_required)
            local a=view(wins[1])
            assert.same({21,16},{a.lnum,a.topline},'Neovim\'s own adjustment for the human edit, untouched')
        end)
    end)
end)
