local uv=vim.uv or vim.loop
local arrival=require('tests.helpers.arrival')

describe('isolated editor runtime fixture',function()
    local fixtures,children
    before_each(function() fixtures,children={},{} end)
    after_each(function()
        for _,child in ipairs(children) do child:stop() end
        for _,fixture in ipairs(fixtures) do fixture.cleanup() end
    end)
    local function helper()
        local ok,value=pcall(require,'tests.helpers.remote_runtime_fixture')
        assert.is_true(ok,tostring(value))
        return value
    end
    local function fake_runtime()
        local calls={}
        local native=assert(uv.fs_realpath('/tmp'))..'/parley-rpc-'..uv.os_get_passwd().uid
        return {default_parent=function() return native end,acquire=function(options,callback)
            calls[#calls+1]=options.parent
            callback({kind='fake'})
        end},calls,native
    end
    it('guards the captured native parent and descendants before any acquire effect',function()
        local runtime,calls,native=fake_runtime()
        local fixture=helper().install({runtime=runtime});fixtures[#fixtures+1]=fixture
        assert.equals(native,fixture.native_default_parent())
        for _,parent in ipairs({native,native..'/e-owned',native..'/../'..vim.fs.basename(native)}) do
            local result
            runtime.acquire({parent=parent},function(value) result=value end)
            assert.equals('unavailable',result.kind)
        end
        runtime.default_parent=function() return native end
        local result
        runtime.acquire({},function(value) result=value end)
        assert.equals('unavailable',result.kind)
        assert.equals(0,#calls)
    end)
    it('passes a copied options table with one private default to the original acquire',function()
        local runtime,calls=fake_runtime()
        local fixture=helper().install({runtime=runtime});fixtures[#fixtures+1]=fixture
        assert.equals(fixture,helper().install({runtime=runtime}))
        local options={incarnation=string.rep('a',32)}
        runtime.acquire(options,function() end)
        assert.is_nil(options.parent)
        assert.same({fixture.parent},calls)
        assert.equals(fixture.parent,runtime.default_parent())
        assert.equals(16832,uv.fs_lstat(fixture.parent).mode)
        assert.equals(uv.os_get_passwd().uid,uv.fs_lstat(fixture.parent).uid)
    end)
    it('guards system and private symlink aliases before any acquire effect',function()
        local runtime,calls,native=fake_runtime()
        local fixture=helper().install({runtime=runtime});fixtures[#fixtures+1]=fixture
        local alias=fixture.parent..'/system-root'
        assert(uv.fs_symlink(vim.fs.dirname(native),alias))
        for _,parent in ipairs({'/tmp/'..vim.fs.basename(native),alias..'/'..vim.fs.basename(native),
            alias..'/'..vim.fs.basename(native)..'/e-new'}) do
            local result
            runtime.acquire({parent=parent},function(value) result=value end)
            assert.equals('unavailable',result.kind)
        end
        assert.equals(0,#calls)
    end)
    it('allocates a real socket privately while leaving the native parent unchanged',function()
        local fixture=helper().install()
        local runtime=require('parley.remote_runtime')
        local native=fixture.native_default_parent()
        local function identity(stat)
            return stat and {type=stat.type,dev=stat.dev,ino=stat.ino,uid=stat.uid,mode=stat.mode}
        end
        local before=identity(uv.fs_lstat(native))
        local source=require('tests.helpers.fake_process_source').new({[uv.os_getpid()]={started='Thu Oct 22 05:00:00 2026'}})
        local result
        runtime.acquire({incarnation=string.rep('a',32),source=source},function(value) result=value end)
        assert.is_true(vim.wait(arrival.MS,function() return result~=nil end,10))
        assert.equals('ready',result.kind,vim.inspect(result))
        assert.equals(fixture.parent,result.runtime.parent)
        local listening
        result.runtime.listen('s256',function(value) listening=value end)
        assert.is_true(vim.wait(arrival.MS,function() return listening~=nil end,10))
        assert.equals('listening',listening.kind,vim.inspect(listening))
        assert.is_true(#listening.path<=103)
        local closed
        result.runtime.close(function() closed=true end)
        assert.is_true(vim.wait(arrival.MS,function() return closed end,10))
        assert.same(before,identity(uv.fs_lstat(native)))
    end)
    it('cleans its exact disposable tree idempotently without following foreign symlinks',function()
        local runtime=fake_runtime()
        local fixture=helper().install({runtime=runtime});fixtures[#fixtures+1]=fixture
        local outside=assert(uv.fs_mkdtemp(vim.fs.dirname(fixture.parent)..'/outside-XXXXXX'))
        vim.fn.writefile({'keep'},outside..'/sentinel')
        assert(uv.fs_symlink(outside,fixture.parent..'/link'))
        assert.is_true(fixture.cleanup())
        assert.is_true(fixture.cleanup())
        assert.is_nil(uv.fs_lstat(fixture.parent))
        assert.same({'keep'},vim.fn.readfile(outside..'/sentinel'))
        vim.fn.delete(outside,'rf')
    end)
    it('installs isolation in clean embedded editors and removes it after normal exit',function()
        helper()
        local child=require('tests.helpers.embedded_nvim').start({rtp='prepend'})
        children[#children+1]=child
        local parent,native=unpack(child:exec([[local selected=require('parley.remote_runtime').default_parent()
            local f=require('tests.helpers.remote_runtime_fixture').install()
            return {selected,f.native_default_parent()}]]))
        assert.is_not.equals(native,parent)
        assert.equals(16832,uv.fs_lstat(parent).mode)
        child:exec([[vim.schedule(function() vim.cmd('qa!') end)]])
        assert.is_true(vim.wait(arrival.MS,function() return uv.fs_lstat(parent)==nil end,10))
    end)
    it('retains a replaced root when another owner uses its copied cleanup witness',function()
        local runtime=fake_runtime()
        local fixture=helper().install({runtime=runtime});fixtures[#fixtures+1]=fixture
        assert.equals('function',type(fixture.witness))
        local witness=fixture.witness()
        local original=fixture.parent..'-original'
        assert(uv.fs_rename(fixture.parent,original))
        assert(uv.fs_mkdir(fixture.parent,448))
        vim.fn.writefile({'replacement'},fixture.parent..'/sentinel')
        local ok,err=helper().cleanup(fixture.parent,witness)
        assert.is_nil(ok)
        assert.matches('replaced',err)
        assert.same({'replacement'},vim.fn.readfile(fixture.parent..'/sentinel'))
        assert.is_true(helper().cleanup(original,witness))
        vim.fn.delete(fixture.parent,'rf')
    end)
end)
