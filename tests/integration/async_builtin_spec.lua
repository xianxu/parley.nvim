local A=require('parley.tools.async_builtin')
local T=require('parley.tasker')
local Fake=require('tests.helpers.fake_process')
local function wait(fn)assert.is_true(vim.wait(2000,fn,1))end

describe('asynchronous builtins',function()
    local processes
    before_each(function()T._reset();T._uv,processes=Fake.new()end)
    after_each(function()
        for _,p in pairs(processes.processes)do p:finish()end
        vim.wait(100,function()return T.stats().active==0 end,1);T._reset();T._uv=nil
    end)
    it('registers all eleven executable builtins with asynchronous capability',function()
        for _,name in ipairs({'read_file','write_file','edit_file','propose_edits','grep','ack','find','ls',
            'chat_history_search','parley_help','emit_definition'})do
            local definition=require('parley.tools.builtin.'..name)
            assert.equals('function',type(definition.execute_async),name)
            assert.equals('function',type(definition.resources),name)
        end
    end)
    it('preserves command formatting and captured cwd without synchronous execution',function()
        local result;local def=require('parley.tools.builtin.ls')
        def.execute_async({path='/captured'}, {tasker=T,cwd='/captured',buf=1,logical_generation='g',operation_id='ls'},
            function(value)result=value end)
        wait(function()return processes.spawn_calls==1 end)
        assert.equals('/captured',processes.processes[4242].cwd)
        processes.processes[4242]:emit('stdout','hello\n');processes.processes[4242]:finish()
        wait(function()return result~=nil end)
        assert.equals('hello',result.result.content);assert.is_true(result.physical_resolved)
    end)
    it('retains cancellation ownership until exit and both EOFs',function()
        local result;local def=require('parley.tools.builtin.ls')
        local handle=def.execute_async({path='/tmp'}, {tasker=T,cwd='/tmp',logical_generation='g',operation_id='cancel'},function(v)result=v end)
        wait(function()return processes.spawn_calls==1 end);handle:cancel()
        assert.is_false(handle:snapshot().physical_resolved)
        assert.is_nil(result)
        processes.processes[4242]:finish();wait(function()return result~=nil end)
        assert.is_true(result.physical_resolved);assert.is_true(result.result.is_error)
    end)
    it('reads numbered lines through the checked filesystem seam',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root/file','one\ntwo\nthree\n')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.read_file').execute_async({file_path='/root/file',offset=2,limit=1},
            {filesystem=fs,cwd='/root',operation_id='read'},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.equals('    2  two',result.result.content);assert.is_false(result.result.is_error)
    end)
    it('backs up the original before replacement and preserves numbered backups',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.put('/root/file','old');state.put('/root/file.parley-backup.1','older')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.write_file').execute_async({file_path='/root/file',content='new'},
            {filesystem=fs,cwd='/root',operation_id='write'},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.equals('new',state.files['/root/file'].bytes)
        assert.equals('older',state.files['/root/file.parley-backup.1'].bytes)
        assert.equals('old',state.files['/root/file.parley-backup.2'].bytes)
        assert.equals('applied',result.effect);assert.is_true(result.evidence.backup_confirmed)
    end)
    it('refuses a growing edit before any backup or target mutation',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root/file','aaaa')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.edit_file').execute_async(
            {file_path='/root/file',old_string='a',new_string='123456789',replace_all=true},
            {filesystem=fs,cwd='/root',operation_id='edit',max_file_bytes=8},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.equals('aaaa',state.files['/root/file'].bytes);assert.is_true(result.result.is_error)
        assert.equals('not_applied',result.effect)
        for _,call in ipairs(state.calls)do assert.is_not.equals('write',call.name)end
    end)
    it('retains unknown submitted IO across cancellation and resolves only from callback evidence',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root/file','old');state.fail('lstat',{throw=true})
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local results={}
        local handle=require('parley.tools.builtin.read_file').execute_async({file_path='/root/file'},
            {filesystem=fs,cwd='/root',operation_id='unknown'},function(v)results[#results+1]=v end)
        wait(function()if #state.queue>0 then state.step()end;return #results>0 end)
        assert.is_false(results[1].physical_resolved);handle:cancel()
        state.drain();wait(function()return results[#results].physical_resolved end)
        assert.is_true(results[#results].result.is_error)
    end)
    it('reports checked partial writes without replaying the operation',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.put('/root/file','old')
        state.fail('write',{},'EIO')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.edit_file').execute_async({file_path='/root/file',old_string='old',new_string='new'},
            {filesystem=fs,cwd='/root',operation_id='partial'},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.equals('partial',result.effect);assert.is_true(result.physical_resolved)
        assert.is_true(result.result.is_error);assert.equals('old',state.files['/root/file.parley-backup.1'].bytes)
    end)

    it('traverses with native grep and find',function()
        T._uv=nil
        local dir=vim.fn.tempname();vim.fn.mkdir(dir..'/nested','p')
        vim.fn.writefile({'PUBLIC_NEEDLE'},dir..'/public.txt')
        vim.fn.writefile({'NESTED_NEEDLE'},dir..'/nested/public.txt')
        local results={}
        local context={tasker=T,cwd=dir,logical_generation='g',operation_id='native-grep'}
        require('parley.tools.builtin.grep').execute_async({pattern='NEEDLE',path=dir},context,
            function(value)results.grep=value end)
        context.operation_id='native-find'
        require('parley.tools.builtin.find').execute_async({path=dir},context,function(value)results.find=value end)
        wait(function()return results.grep and results.find end)
        assert.is_false(results.grep.result.is_error)
        assert.is_not_nil(results.grep.result.content:find('PUBLIC_NEEDLE',1,true))
        assert.is_not_nil(results.grep.result.content:find('NESTED_NEEDLE',1,true))
        assert.is_not_nil(results.find.result.content:find('public.txt',1,true))
        vim.fn.delete(dir,'rf')
    end)

    it('reads help asynchronously and refuses unknown topics',function()
        local results={}
        local help=require('parley.tools.builtin.parley_help')
        help.execute_async({topic='README'},{operation_id='help'},function(v)results.read=v end)
        help.execute_async({topic='../../secret'},{operation_id='bad-help'},function(v)results.bad=v end)
        wait(function()return results.read and results.bad end)
        assert.is_false(results.read.result.is_error)
        assert.equals('    ',results.read.result.content:sub(1,4))
        assert.is_true(results.bad.result.is_error)
    end)
    it('applies proposed edits through the same checked backup path',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.put('/root/file','before')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.propose_edits').execute_async({file_path='/root/file',
            edits={{old_string='before',new_string='after',explain='change'}}},
            {filesystem=fs,operation_id='propose'},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.is_false(result.result.is_error);assert.equals('after',state.files['/root/file'].bytes)
        assert.equals('before',state.files['/root/file.parley-backup.1'].bytes)
    end)
    it('captures history roots and stops before a second root after cancellation',function()
        local result
        local context={tasker=T,cwd='/root',logical_generation='g',operation_id='history',chat_roots={{dir='/root/one'},{dir='/root/two'}}}
        local handle=require('parley.tools.builtin.chat_history_search').execute_async({pattern='hello'},context,
            function(v)result=v end)
        context.chat_roots[1].dir='/changed'
        wait(function()return processes.spawn_calls==1 end)
        assert.equals('/root/one',processes.processes[4242].args[#processes.processes[4242].args])
        handle:cancel();processes.processes[4242]:finish()
        wait(function()return result~=nil end);assert.equals(1,processes.spawn_calls)
    end)

    it('creates missing parent directories asynchronously before a new file',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.write_file').execute_async({file_path='/root/a/b/file',content='new'},
            {filesystem=fs,operation_id='mkdir',root_policy={write_root='/root'}},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.is_false(result.result.is_error)
        assert.equals('directory',state.files['/root/a'].type)
        assert.equals('directory',state.files['/root/a/b'].type)
        assert.equals('new',state.files['/root/a/b/file'].bytes)
    end)

    it('retains created-directory effects when cancellation follows a throwing mkdir submission',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.fail('mkdir',{throw=true})
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local results={}
        local handle=require('parley.tools.builtin.write_file').execute_async({file_path='/root/new/file',content='new'},
            {filesystem=fs,operation_id='mkdir-unknown',root_policy={write_root='/root'}},
            function(v)results[#results+1]=v end)
        wait(function()if #state.queue>0 then state.step()end;return #results>0 end)
        assert.equals('unknown',results[1].certainty);assert.is_false(results[1].physical_resolved)
        handle:cancel();state.drain()
        wait(function()return results[#results].physical_resolved end)
        assert.equals('partial',results[#results].effect)
        assert.equals('directory',state.files['/root/new'].type);assert.is_nil(state.files['/root/new/file'])
    end)
    it('rejects existing symlink ancestors before directory or file effects',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.put('/root/link','/outside','link')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=state.schedule})
        local result
        require('parley.tools.builtin.write_file').execute_async({file_path='/root/link/new/file',content='new'},
            {filesystem=fs,operation_id='mkdir-link',root_policy={write_root='/root'}},function(v)result=v end)
        wait(function()state.drain();return result~=nil end)
        assert.is_true(result.result.is_error);assert.equals('not_applied',result.effect)
        assert.equals(0,state.count('mkdir'));assert.equals(0,state.count('write'))
    end)
    it('creates native nested files and confirms their checked write completion',function()
        local dir=vim.fn.tempname();vim.fn.mkdir(dir,'p');dir=(vim.uv or vim.loop).fs_realpath(dir)
        local result
        require('parley.tools.builtin.write_file').execute_async({file_path=dir..'/a/b/file',content='new'},
            {operation_id='native-write',root_policy={write_root=dir}},function(v)result=v end)
        wait(function()return result~=nil end)
        assert.is_false(result.result.is_error);assert.equals('applied',result.effect)
        assert.same({'new'},vim.fn.readfile(dir..'/a/b/file'));vim.fn.delete(dir,'rf')
    end)

    it('propagates reentrant cancellation to a handle returned after unknown publication',function()
        local runtime,state=require('tests.helpers.fake_tool_filesystem').new()
        state.put('/root','','directory');state.put('/root/file','old')
        local fs=require('parley.tools.filesystem').new({runtime=runtime,schedule=function(fn)fn()end})
        local write=fs.write_checked
        fs.write_checked=function(self,spec,done)
            state.fail('lstat',{throw=true});return write(self,spec,done)
        end
        local result,handle
        handle=require('parley.tools.builtin.write_file').execute_async({file_path='/root/file',content='new'},
            {filesystem=fs,operation_id='reentrant',root_policy={write_root='/root'}},function(v)
                result=v;if v.certainty=='unknown'then handle:cancel()end
            end)
        wait(function()state.drain();return result and result.physical_resolved end)
        assert.equals('not_applied',result.effect);assert.equals('old',state.files['/root/file'].bytes)
        assert.is_nil(state.files['/root/file.parley-backup.1'])
    end)

    it('records completed command evidence even when result formatting fails',function()
        local definition=A.bind({name='ls',handler=function(_,context)
            context.run({'ls','/tmp'});error('formatter private data')
        end})
        local result
        definition.execute_async({}, {tasker=T,cwd='/tmp',logical_generation='g',operation_id='format'},function(v)result=v end)
        wait(function()return processes.spawn_calls==1 end);processes.processes[4242]:finish()
        wait(function()return result~=nil end)
        assert.equals('known',result.certainty);assert.equals('applied',result.effect)
        assert.is_true(result.physical_resolved);assert.equals('tool formatter failed',result.result.content)
    end)

end)
