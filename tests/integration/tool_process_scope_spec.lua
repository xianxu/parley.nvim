local A=require('parley.tools.path_authority')
local Scope=require('parley.tools.process_scope')
local Bootstrap=require('parley.tools.process_bootstrap')
local uv=vim.uv or vim.loop

describe('native captured subprocess authority',function()
    local root
    before_each(function()root=vim.fn.resolve(vim.fn.tempname());vim.fn.mkdir(root..'/inside','p');vim.fn.mkdir(root..'/outside','p')end)
    after_each(function()vim.fn.delete(root,'rf')end)
    local function run(command,authority)
        local plan=assert(Scope.plan(command))[1]
        local argv=assert(Bootstrap.command(plan,authority));local executable=table.remove(argv,1)
        local value=vim.system(vim.list_extend({executable},argv),{text=true}):wait(10000)
        return value,Scope.restore(value.stdout or '',plan.path,plan.command[1])
    end
    it('executes a normal pinned directory traversal',function()
        vim.fn.writefile({'safe'},root..'/inside/INSIDE')
        local value,text=run({'ls',root..'/inside'},assert(A.capture({root..'/inside'})))
        assert.equals(0,value.code,value.stderr);assert.matches('INSIDE',text)
    end)
    it('refuses a queued ancestor symlink replacement without reading outside',function()
        vim.fn.writefile({'OUTSIDE_SECRET'},root..'/outside/secret')
        local authority=assert(A.capture({root..'/inside'}))
        assert(uv.fs_rename(root..'/inside',root..'/moved'));assert(uv.fs_symlink(root..'/outside',root..'/inside'))
        local value=run({'grep','-r','-H','--','SECRET',root..'/inside'},authority)
        assert.is_not.equals(0,value.code);assert.is_nil((value.stdout or ''):find('OUTSIDE_SECRET',1,true))
    end)
    it('passes a pinned regular file through an inherited descriptor',function()
        vim.fn.writefile({'MATCH'},root..'/inside/file')
        local value,text=run({'grep','-H','--','MATCH',root..'/inside/file'},assert(A.capture({root..'/inside/file'})))
        assert.equals(0,value.code,value.stderr);assert.matches(root..'/inside/file:MATCH',text,1,true)
    end)
    it('preserves regular-file find type and detailed ls metadata',function()
        local path=root..'/inside/file';vim.fn.writefile({'content'},path)
        local authority=assert(A.capture({path}))
        local found,text=run({'find',path,'-type','f'},authority)
        assert.equals(0,found.code,found.stderr);assert.equals(path,text:gsub('%s+$',''))
        local listed,listing=run({'ls','-l',path},authority)
        assert.equals(0,listed.code,listed.stderr);assert.equals('-',listing:sub(1,1))
        assert.is_nil(listing:find('/dev/fd/',1,true));assert.matches(path,listing,1,true)
    end)

    local function produce(name,input,options,before_spawn)
        require('parley.tools').register_builtins()
        options=options or {};options.allowed_tools={name};options.root_policy={write_root=root,read_roots={}}
        options.buf=981
        local producer=assert(require('parley.tools.producer').new(options))
        local Tasker=require('parley.tasker');local native=Tasker.run
        local intercepted=false
        if before_spawn then Tasker.run=function(...)
            Tasker.run=native;intercepted=true;before_spawn();return native(...)
        end end
        local result,done
        producer.start({id='scope',name=name,input=input},{epoch=1,generation=1,attempt=1,round=1},
            {outcome=function(_,v)result=v end,resolved=function()done=true end})
        local finished=vim.wait(10000,function()return done end,1)
        Tasker.run=native
        producer.close();assert.is_true(finished,'production subprocess did not settle')
        if before_spawn then assert.is_true(intercepted,'controlled replacement must run before native spawn')end
        return result
    end
    for _,name in ipairs({'ls','find','grep'})do
        it('refuses production '..name..' after captured ancestor redirection',function()
            vim.fn.writefile({'OUTSIDE_SECRET'},root..'/outside/OUTSIDE_SECRET')
            local result=produce(name,{path=root..'/inside',pattern=name=='grep' and 'SECRET' or nil},nil,function()
                assert(uv.fs_rename(root..'/inside',root..'/moved'))
                assert(uv.fs_symlink(root..'/outside',root..'/inside'))
            end)
            assert.is_true(result.is_error);assert.is_nil(result.content:find('OUTSIDE_SECRET',1,true))
        end)
    end
    it('preserves multiple production search targets and their restored filenames',function()
        vim.fn.writefile({'MATCH_INSIDE'},root..'/inside/one')
        vim.fn.writefile({'MATCH_OUTSIDE'},root..'/outside/two')
        local result=produce('grep',{pattern='MATCH',paths={root..'/inside',root..'/outside'}})
        assert.is_false(result.is_error)
        assert.truthy(result.content:find(root..'/inside/one',1,true))
        assert.truthy(result.content:find(root..'/outside/two',1,true))
        assert.is_nil(result.content:find('/dev/fd/',1,true))
    end)
    for _,name in ipairs({'ls','find','grep'})do
        it('does not follow child symlinks in production '..name,function()
            vim.fn.writefile({'OUTSIDE_SECRET'},root..'/outside/OUTSIDE_SECRET')
            assert(uv.fs_symlink(root..'/outside',root..'/inside/link'))
            local result=produce(name,{path=root..'/inside',pattern=name=='grep' and 'SECRET' or nil,
                flags=name=='ls' and {'-R'} or nil,type=name=='find' and 'f' or nil})
            assert.is_false(result.is_error)
            assert.is_nil(result.content:find('OUTSIDE_SECRET',1,true))
        end)
    end
    for _,name in ipairs({'grep','find','ls'})do
        it('keeps private recovery storage excluded in production '..name,function()
            local state=root..'/inside/state';local private=state..'/answer-recovery'
            vim.fn.mkdir(private,'p');vim.fn.writefile({'SECRET'},private..'/PRIVATE_SECRET')
            vim.fn.writefile({'SECRET'},root..'/inside/PUBLIC_SECRET')
            local result=produce(name,{path=root..'/inside',pattern=name=='grep' and 'SECRET' or nil,
                flags=name=='ls' and {'-R'} or nil},{state_dir=state})
            assert.is_nil(result.content:find('PRIVATE_SECRET',1,true))
            if name=='ls'then assert.is_true(result.is_error)
            else assert.is_false(result.is_error);assert.truthy(result.content:find('PUBLIC_SECRET',1,true))end
        end)
    end
    it('cancels the production bootstrap child and waits for physical Tasker drain',function()
        require('parley.tools').register_builtins()
        local Tasker=require('parley.tasker');local baseline=Tasker.stats().active
        local producer=assert(require('parley.tools.producer').new({allowed_tools={'find'},
            root_policy={write_root=root,read_roots={}},buf=982}))
        local delivered=0
        local handle=producer.start({id='cancel',name='find',input={path=root..'/inside'}},
            {epoch=1,generation=1,attempt=1,round=1},{outcome=function()delivered=delivered+1 end})
        assert.is_true(vim.wait(5000,function()return Tasker.stats().active>baseline end,1),
            'cancellation must exercise a launched child')
        producer.cancel(handle);producer.close()
        assert.is_true(vim.wait(10000,function()return Tasker.stats().active==baseline end,1))
        assert.equals(0,delivered)
    end)

end)
