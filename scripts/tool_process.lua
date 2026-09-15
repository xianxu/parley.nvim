-- luacheck: globals vim
-- Private exec bootstrap. Only the parent-generated bounded payload is accepted.
-- No user configuration/plugins run; descriptor ownership ends at exec/exit.
local source=debug.getinfo(1,'S').source:sub(2)
local root=assert(source:match('^(.*)/scripts/tool_process%.lua$'))
package.path=root..'/lua/?.lua;'..root..'/lua/?/init.lua;'..package.path
local uv=vim.uv or vim.loop
local ffi=require('ffi')
ffi.cdef[[int fchdir(int); int close(int); int fcntl(int,int,...);
    int execvp(const char *, char *const []); void _exit(int);]]
local function fail()
    io.stderr:write('scoped process authority or execution failed\n')
    ffi.C._exit(126)
end
local ok,spec=pcall(function()
    assert(type(arg[1])=='string' and #arg[1]<=65536)
    local value=vim.json.decode(arg[1]);assert(type(value)=='table')
    assert(type(value.path)=='string' and value.path:sub(1,1)=='/')
    assert(type(value.command)=='table' and #value.command<=256)
    local allowed={ls=true,find=true,rg=true,grep=true,ack=true}
    assert(allowed[value.command[1]])
    for _,part in ipairs(value.command)do assert(type(part)=='string' and not part:find('\0',1,true))end
    assert(type(value.target_position)=='number' and value.command[value.target_position]=='.')
    return value
end)
if not ok then fail()end
local A=require('parley.tools.path_authority')
local token=A.import(spec.authority)
if not token then fail()end
local runtime=A.runtime(token)
runtime.fs_open(spec.path,'r',0,function(err,fd)
    if err or not fd then fail()end
    local stat=uv.fs_fstat(fd)
    if not stat then fail()end
    if stat.type=='directory'then
        if ffi.C.fchdir(fd)~=0 then fail()end
        if ffi.C.close(fd)~=0 then fail()end
    elseif stat.type=='file'then
        if spec.command[1]=='find'then
            table.insert(spec.command,2,'-H');spec.target_position=spec.target_position+1
        elseif spec.command[1]=='ls'then
            table.insert(spec.command,2,'-L');spec.target_position=spec.target_position+1
        end
        if ffi.C.fcntl(fd,2,ffi.cast('int',0))~=0 then fail()end -- F_SETFD: inherit final descriptor
        spec.command[spec.target_position]='/dev/fd/'..fd
    else fail()end
    local argv=ffi.new('char *[?]',#spec.command+1)
    for i,part in ipairs(spec.command)do argv[i-1]=ffi.cast('char *',part)end
    local marker=require('parley.tools.process_scope').exec_marker
    if not io.stderr:write(marker) or not io.stderr:flush()then fail()end
    ffi.C.execvp(argv[0],argv)
    fail()
end)
uv.run()
fail()
