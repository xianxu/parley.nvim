local uv=vim.uv or vim.loop
describe('descriptor-relative tool path authority',function()
    local root
    before_each(function()root=vim.fn.tempname();vim.fn.mkdir(root..'/allowed/child','p');vim.fn.mkdir(root..'/outside','p')
        root=assert(uv.fs_realpath(root));vim.fn.writefile({'INSIDE'},root..'/allowed/child/file')
        vim.fn.writefile({'OUTSIDE_SECRET'},root..'/outside/file')end)
    after_each(function()vim.fn.delete(root,'rf')end)
    local function redirect()
        assert(uv.fs_rename(root..'/allowed/child',root..'/allowed/old'))
        assert(uv.fs_symlink(root..'/outside',root..'/allowed/child'))
    end
    it('rejects a queued read whose captured ancestor was replaced',function()
        local A=require('parley.tools.path_authority')
        local authority=assert(A.capture({root..'/allowed/child/file'}))
        local fs=require('parley.tools.filesystem').new():authorized(authority)
        redirect()
        local result;fs:read(root..'/allowed/child/file',function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end))
        assert.is_nil(result.data);assert.equals('not_applied',result.effect)
        assert.is_true(result.physical_resolved)
    end)
    it('reads unchanged captured resources through the asynchronous seam',function()
        local A=require('parley.tools.path_authority')
        local fs=require('parley.tools.filesystem').new():authorized(assert(A.capture({root..'/allowed/child/file'})))
        local result;fs:read(root..'/allowed/child/file',function(v)result=v end)
        assert.is_nil(result);assert.is_true(vim.wait(5000,function()return result~=nil end))
        assert.equals('INSIDE\n',result.data);assert.is_true(result.physical_resolved)
    end)
    it('revalidates between asynchronous stat and open',function()
        local A=require('parley.tools.path_authority');local file=root..'/allowed/child/file'
        local runtime=A.runtime(assert(A.capture({file})));local open=runtime.fs_open
        runtime.fs_open=function(...)redirect();return open(...)end
        local result;require('parley.tools.filesystem').new({runtime=runtime}):read(file,function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end))
        assert.is_nil(result.data);assert.is_not_nil(result.error_code);assert.is_true(result.physical_resolved)
    end)
    it('rejects replacement by a different ordinary directory too',function()
        local A=require('parley.tools.path_authority');local file=root..'/allowed/child/file'
        local fs=require('parley.tools.filesystem').new():authorized(assert(A.capture({file})))
        assert(uv.fs_rename(root..'/allowed/child',root..'/allowed/old'))
        vim.fn.mkdir(root..'/allowed/child');vim.fn.writefile({'OTHER'},file)
        local result;fs:read(file,function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.is_nil(result.data)
    end)
    it('confines runtime calls to captured claims',function()
        local A=require('parley.tools.path_authority');local file=root..'/allowed/child/file'
        local runtime=A.runtime(assert(A.capture({file})))
        local result;runtime.fs_open(root..'/outside/file','r',0,function(err,fd)result={err=err,fd=fd}end)
        assert.is_true(vim.wait(5000,function()return result~=nil end))
        assert.is_nil(result.fd);assert.matches('EACCES',result.err)
    end)
    it('preserves checked backup and write semantics under captured subtree authority',function()
        local A=require('parley.tools.path_authority');local dir=root..'/allowed/child';local file=dir..'/file'
        local authority=assert(A.capture({dir,file},{{path=dir,scope='subtree'}}))
        local fs=require('parley.tools.filesystem').new():authorized(authority)
        local before;fs:read(file,function(v)before=v end);assert.is_true(vim.wait(5000,function()return before~=nil end))
        local result;fs:write_checked({path=file,content='changed',expected=before.revision,backup_path=file..'.backup'},function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.is_nil(result.error_code)
        assert.equals('applied',result.effect);assert.is_true(result.physical_resolved)
        assert.same({'INSIDE'},vim.fn.readfile(file..'.backup'));assert.same({'changed'},vim.fn.readfile(file))
    end)
    it('refuses new-file creation after ancestor redirection',function()
        local A=require('parley.tools.path_authority');local file=root..'/allowed/child/new'
        local fs=require('parley.tools.filesystem').new():authorized(assert(A.capture({file})))
        redirect();local result;fs:write_checked({path=file,content='bad',expected={exists=false}},function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.equals('not_applied',result.effect)
        assert.is_nil(uv.fs_stat(root..'/outside/new'));assert.is_true(result.physical_resolved)
    end)
    it('exports and imports identity evidence without reauthorizing changed paths',function()
        local A=require('parley.tools.path_authority');local file=root..'/allowed/child/file'
        local token=assert(A.import(A.export(assert(A.capture({file})))));redirect()
        local result;A.runtime(token).fs_open(file,'r',0,function(err,fd)result={err=err,fd=fd}end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.is_nil(result.fd)
    end)
    it('refuses production producer reads redirected after admission',function()
        require('parley.tools').register_builtins()
        local producer=assert(require('parley.tools.producer').new({allowed_tools={'read_file'},
            root_policy={write_root=root..'/allowed',read_roots={}},buf=912}))
        local result,resolved
        producer.start({id='read',name='read_file',input={path=root..'/allowed/child/file'}},
            {epoch=1,generation=1,round=1,attempt=1},
            {outcome=function(_,v)result=v end,resolved=function()resolved=true end})
        redirect();assert.is_true(vim.wait(5000,function()return resolved end));producer.close()
        assert.is_true(result.is_error);assert.is_nil(result.content:find('OUTSIDE_SECRET',1,true))
    end)
    it('refuses a root replaced after capability capture but before preparation',function()
        require('parley.tools').register_builtins()
        local producer=assert(require('parley.tools.producer').new({allowed_tools={'read_file'},
            root_policy={write_root=root..'/allowed/child',read_roots={}},buf=913}))
        redirect();local result,resolved
        producer.start({id='read',name='read_file',input={path=root..'/allowed/child/file'}},
            {epoch=1,generation=1,round=1,attempt=1},
            {outcome=function(_,v)result=v end,resolved=function()resolved=true end})
        assert.is_true(vim.wait(5000,function()return resolved end));producer.close()
        assert.is_true(result.is_error);assert.is_nil(result.content:find('OUTSIDE_SECRET',1,true))
    end)
    it('refuses redirected backup publication without touching the outside tree',function()
        local A=require('parley.tools.path_authority');local dir=root..'/allowed/child';local file=dir..'/file'
        local runtime=A.runtime(assert(A.capture({dir,file},{{path=dir,scope='subtree'}})))
        local fs=require('parley.tools.filesystem').new({runtime=runtime})
        local before;fs:read(file,function(v)before=v end);assert.is_true(vim.wait(5000,function()return before~=nil end))
        local link=runtime.fs_link;runtime.fs_link=function(...)redirect();return link(...)end
        local result;fs:write_checked({path=file,content='bad',expected=before.revision,backup_path=file..'.backup'},function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.equals('not_applied',result.effect)
        assert.is_nil(uv.fs_stat(root..'/outside/file.backup'));assert.same({'OUTSIDE_SECRET'},vim.fn.readfile(root..'/outside/file'))
    end)
    it('creates new descendants while preserving the captured existing ancestor',function()
        local A=require('parley.tools.path_authority');local dir=root..'/allowed/child'
        local fs=require('parley.tools.filesystem').new():authorized(assert(A.capture({dir},{{path=dir,scope='subtree'}})))
        local result;fs:ensure_dir({path=dir..'/new/nested',root=dir},function(v)result=v end)
        assert.is_true(vim.wait(5000,function()return result~=nil end));assert.is_nil(result.error_code)
        assert.equals('applied',result.effect);assert.is_true(result.physical_resolved)
    end)
end)
