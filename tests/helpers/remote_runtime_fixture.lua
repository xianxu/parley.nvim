-- Test bootstrap only: no editor in the harness may allocate in the native
-- shared runtime. Capture that prefix before a spec replaces the getter.
local uv=vim.uv or vim.loop
local M={}
local installed=setmetatable({},{__mode='k'})
local canonical=require('parley.tools.dispatcher').canonical_path
local remove_tree=require('tests.helpers.fixture_files').remove_tree

-- Both the child and its joined parent use this exact captured-root proof.
function M.cleanup(parent,identity)
    local stat,err,code=uv.fs_lstat(parent)
    if not stat then return code=='ENOENT',err end
    if stat.type~='directory' or stat.uid~=identity.uid or stat.mode~=16832
        or stat.dev~=identity.dev or stat.ino~=identity.ino then
        return nil,'test runtime fixture replaced: '..parent
    end
    return remove_tree(parent)
end

function M.install(options)
    options=options or {}
    local runtime=options.runtime or require('parley.remote_runtime')
    if installed[runtime] then return installed[runtime] end
    local native_getter=runtime.default_parent
    local native=assert(native_getter(),'native runtime parent unavailable')
    local native_physical=assert(canonical(native),'native runtime identity unavailable')
    local base=uv.fs_stat('/Volumes/TestScratch') and uv.fs_realpath('/Volumes/TestScratch') or uv.fs_realpath('/tmp')
    local parent=assert(uv.fs_mkdtemp(assert(base)..'/pr-XXXXXX'))
    local identity=assert(uv.fs_lstat(parent))
    local fixture={parent=parent,native_default_parent=native_getter}
    function fixture.witness()
        return {type=identity.type,uid=identity.uid,mode=identity.mode,dev=identity.dev,ino=identity.ino}
    end
    function fixture.cleanup()
        return M.cleanup(parent,identity)
    end
    local acquire=runtime.acquire
    runtime.default_parent=function() return parent end
    runtime.acquire=function(value,callback)
        local selected=value and value.parent or runtime.default_parent()
        local normalized=type(selected)=='string' and vim.fs.normalize(selected) or ''
        local physical=canonical(selected)
        local function inside(path,prefix)
            return path==prefix or path:sub(1,#prefix+1)==prefix..'/'
        end
        if not physical or inside(normalized,native) or inside(physical,native_physical) then
            callback({kind='unavailable',error='test runtime refuses native shared parent'})
            return {cancel=function() end}
        end
        local copied=vim.tbl_extend('force',{},value or {},{parent=selected})
        return acquire(copied,callback)
    end
    installed[runtime]=fixture
    -- Product exit stops exact owned listeners in VimLeavePre. Only afterwards
    -- may the harness remove its disposable files; os.exit uses cleanup below.
    vim.api.nvim_create_autocmd('VimLeave',{callback=function()
        local ok,err=fixture.cleanup()
        if not ok then io.stderr:write('test runtime cleanup failed: '..tostring(err)..'\n') end
    end})
    return fixture
end

return M
