-- Checked asynchronous IO. Path policy and resource admission are supplied by
-- the host; this boundary never changes cwd or infers authority from a filename.
local M={}
local serial=0
local function copy(t)
    if type(t)~='table'then return t end
    local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out
end
local function path(value)
    return type(value)=='string' and #value>0 and #value<=4096 and value:sub(1,1)=='/'
        and not value:find('%z') and not value:find('//',1,true)
        and not (value..'/'):find('/../',1,true) and not (value..'/'):find('/./',1,true)
end
local function number(n)return type(n)=='number' and n==n and n>-math.huge and n<math.huge and n%1==0 end
local function time(value)
    if type(value)~='table' or getmetatable(value)then return false end
    for key in pairs(value)do if key~='sec' and key~='nsec'then return false end end
    return number(value.sec) and number(value.nsec)
        and value.nsec>=0 and value.nsec<1000000000
end
local fields={exists=true,type=true,dev=true,ino=true,size=true,mode=true,mtime=true,ctime=true}
local function valid_revision(value)
    if type(value)~='table' or getmetatable(value) or type(value.exists)~='boolean'then return false end
    for key in pairs(value)do if not fields[key] or not value.exists and key~='exists'then return false end end
    if not value.exists then return true end
    if value.type~='file' and value.type~='directory'then return false end
    for _,key in ipairs({'dev','ino','size','mode'})do if not number(value[key]) or value[key]<0 then return false end end
    return time(value.mtime) and time(value.ctime)
end
local function revision(stat)
    if not stat then return {exists=false}end
    if type(stat)~='table' or not time(stat.mtime) or not time(stat.ctime)then return nil end
    local value={exists=true,type=stat.type,dev=stat.dev,ino=stat.ino,size=stat.size,mode=stat.mode,
        mtime={sec=stat.mtime.sec,nsec=stat.mtime.nsec},ctime={sec=stat.ctime.sec,nsec=stat.ctime.nsec}}
    if valid_revision(value)then return value end
end
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~='table'then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function same_identity(a,b)
    return a and b and a.dev==b.dev and a.ino==b.ino and a.type==b.type
end
local function absent(err)return type(err)=='string' and err:find('ENOENT',1,true)~=nil end
function M.new(opts)
    opts=opts or {};local runtime=opts.runtime or vim.uv or vim.loop
    local schedule=opts.schedule or vim.schedule
    local function configured(key,default)if opts[key]~=nil then return opts[key]end;return default end
    local max_bytes=configured('max_bytes',1048576)
    local chunk_bytes=configured('chunk_bytes',65536)
    local max_steps=configured('max_steps',32768)
    for _,n in ipairs({max_bytes,chunk_bytes,max_steps})do
        assert(type(n)=='number' and n>0 and n<math.huge and n%1==0,'invalid filesystem limit')
    end
    assert(chunk_bytes<=65536,'filesystem chunk limit exceeds 64KiB')
    local fs={}
    local function operation(done)
        assert(type(done)=='function','filesystem completion required')
        local c={fds={},identities={},steps=0,written=0,cancelled=false,done=false}
        local handle={}
        local cleanup,fail,rpc
        local function outcome()
            local uncertain=c.pending~=nil or next(c.fds)~=nil or c.temporary~=nil or c.target_uncertain
            local effect=c.applied and 'applied' or c.mutated and 'partial' or c.target_uncertain and 'unknown' or 'not_applied'
            return {certainty=uncertain and 'unknown' or 'known',effect=effect,cancelled=c.cancelled,
                physical_resolved=c.pending==nil and next(c.fds)==nil,
                error_code=c.error_code,cleanup_error=c.cleanup_error,data=c.data,revision=copy(c.revision),
                evidence={written=c.written,backup_path=c.backup_published and c.backup_path or nil,
                    backup_confirmed=c.backup_confirmed or false,temporary=c.temporary,steps=c.steps}}
        end
        local function publish()
            local result=outcome()
            if result.certainty=='known'then c.done=true end
            -- A failing formatter/consumer cannot alter checked effect evidence.
            pcall(done,result)
        end
        rpc=function(name,args,cb,closing,mutation)
            if not closing and c.steps>=max_steps then fail('capacity');return end
            c.steps=c.steps+1;local token={};c.pending=token
            if mutation then c.target_uncertain=true end
            local function observed(err,value)
                schedule(function()
                    if c.pending~=token or token.seen then return end
                    token.seen=true;c.pending=nil
                    local ok=pcall(cb,err,value)
                    if not ok then fail('callback')end
                end)
            end
            local params={};for i,v in ipairs(args)do params[i]=v end;params[#params+1]=observed
            local ok,request=pcall(runtime['fs_'..name],unpack(params))
            if not ok or request==nil then
                -- A backend can throw after accepting IO. Only its eventual
                -- callback can retire this request; no guessed cancellation.
                c.error_code=c.error_code or 'submission';publish()
            end
        end
        local function close(fd,cb)
            rpc('close',{fd},function(err)
                if err then c.error_code=c.error_code or 'close';cb(false)
                else c.fds[fd]=nil;cb(true)end
            end,true)
        end
        cleanup=function(probe_only)
            local pending={};if not probe_only then for fd in pairs(c.fds)do pending[#pending+1]=fd end end
            local index=0
            local function next_close()
                index=index+1;local fd=pending[index]
                if fd then close(fd,next_close);return end
                if c.temporary and not next(c.fds)then
                    local temporary=c.temporary
                    rpc('unlink',{temporary},function(err)
                        if not err or absent(err)then c.temporary=nil else c.cleanup_error='unlink'end
                        publish()
                    end,true)
                else publish()end
            end
            next_close()
        end
        fail=function(code)
            c.error_code=c.error_code or code;c.stopped=true
            if not c.pending then cleanup()end
        end
        local function proceed()
            if c.stopped then cleanup();return false end
            if c.cancelled then fail('cancelled');return false end
            return true
        end
        local function open(file,flags,mode,cb)
            if not proceed()then return end
            rpc('open',{file,flags,mode},function(err,fd)
                if err or type(fd)~='number'then
                    if flags=='wx' and file==c.path then c.target_uncertain=false end
                    fail('open');return
                end
                c.fds[fd]=true
                if flags=='wx' and file==c.path then c.mutated=true;c.target_uncertain=false end
                if file==c.temp_candidate then c.temporary=file end
                rpc('fstat',{fd},function(failure,metadata)
                    if failure then fail('stat');return end
                    c.identities[fd]=revision(metadata)
                    if not c.identities[fd]then fail('stat');return end
                    if proceed()then cb(fd)end
                end)
            end,false,flags=='wx' and file==c.path)
        end
        local function stat(file,cb)
            if not proceed()then return end
            rpc('lstat',{file},function(err,value)
                if err and not absent(err)then fail('stat');return end
                local observed=revision(value)
                if not observed then fail('stat');return end
                if proceed()then cb(observed)end
            end)
        end
        local function read_snapshot(file,expected,limit,cb)
            stat(file,function(before)
                if expected and not same(before,expected)then fail('conflict');return end
                if not before.exists or before.type~='file'then fail('not_file');return end
                if type(before.size)~='number' or before.size<0 or before.size>limit then fail('capacity');return end
                open(file,'r',384,function(fd)
                    rpc('fstat',{fd},function(err,value)
                        if err or not same(before,revision(value))then fail('conflict');return end
                        local chunks,offset={},0
                        local function next_read()
                            if not proceed()then return end
                            if offset==before.size then
                                rpc('fstat',{fd},function(failure,last)
                                    if failure or not same(before,revision(last))then fail('conflict');return end
                                    close(fd,function(closed)
                                        if not closed then publish();return end
                                        if proceed()then cb(table.concat(chunks),before)end
                                    end)
                                end)
                                return
                            end
                            local size=math.min(chunk_bytes,before.size-offset)
                            rpc('read',{fd,size,offset},function(failure,bytes)
                                if failure or type(bytes)~='string' or #bytes==0 or #bytes>size then fail('read');return end
                                offset=offset+#bytes;chunks[#chunks+1]=bytes;next_read()
                            end)
                        end
                        next_read()
                    end)
                end)
            end)
        end
        local function write_bytes(fd,bytes,target,cb)
            local offset=0
            local function next_write()
                if not proceed()then return end
                if offset==#bytes then
                    rpc('fsync',{fd},function(err)
                        if err then fail('fsync');return end
                        if target then c.synced=true end
                        close(fd,function(closed)
                            if not closed then publish();return end
                            if target then c.applied=true end
                            if proceed()then cb()end
                        end)
                    end)
                    return
                end
                local chunk=bytes:sub(offset+1,offset+chunk_bytes)
                rpc('write',{fd,chunk,offset},function(err,count)
                    if err or type(count)~='number' or count<=0 or count>#chunk or count%1~=0 then fail('write');return end
                    offset=offset+count
                    if target then c.target_uncertain=false;c.written=offset end
                    next_write()
                end,false,target)
            end
            next_write()
        end
        local function sync_parent(file,cb)
            local parent=file:match('^(.*)/[^/]+$');if parent==''then parent='/'end
            open(parent,'r',448,function(fd)
                rpc('fsync',{fd},function(err)
                    if err then fail('directory_sync');return end
                    close(fd,function(closed)if closed and proceed()then cb()elseif not closed then publish()end end)
                end)
            end)
        end
        function handle.cancel(_)
            if c.done then return false end
            c.cancelled=true
            return true
        end
        function handle.reconcile(_)
            if c.done or c.pending then return false end
            schedule(function()
                if c.done or c.pending then return end
                local pending={};for fd in pairs(c.fds)do pending[#pending+1]=fd end
                local index=0
                local function next_close()
                    index=index+1
                    if pending[index]then
                        local fd=pending[index]
                        rpc('fstat',{fd},function(err,metadata)
                            local observed=not err and revision(metadata)
                            if type(err)=='string' and err:find('EBADF',1,true) or observed and c.identities[fd]
                                and not same_identity(c.identities[fd],observed)then c.fds[fd]=nil end
                            next_close()
                        end,true)
                        return
                    end
                    if not next(c.fds) and c.synced and c.mutated and c.written==#(c.content or '')then c.applied=true end
                    cleanup(true)
                end
                next_close()
            end)
            return true
        end
        function handle.snapshot(_)return outcome()end
        c.stat=stat;c.open=open;c.read_snapshot=read_snapshot;c.write_bytes=write_bytes;c.sync_parent=sync_parent
        c.rpc=rpc;c.fail=fail;c.proceed=proceed;c.publish=publish;c.cleanup=cleanup
        return c,handle
    end
    function fs.stat(_,file,done)
        local c,handle=operation(done)
        schedule(function()
            if not path(file)then c.fail('invalid');return end
            c.stat(file,function(value)c.revision=value;c.publish()end)
        end)
        return handle
    end
    function fs.read(_,file,done)
        local c,handle=operation(done)
        schedule(function()
            if not path(file)then c.fail('invalid');return end
            c.read_snapshot(file,nil,max_bytes,function(bytes,value)c.data=bytes;c.revision=value;c.publish()end)
        end)
        return handle
    end
    -- Directory creation is explicit and confined to an already canonical root.
    -- Every traversed component is lstat-checked; links never become ancestors.
    function fs.ensure_dir(_,spec,done)
        local c,handle=operation(done)
        local valid=type(spec)=='table' and path(spec.path) and path(spec.root)
            and (spec.root=='/' or spec.path==spec.root or spec.path:sub(1,#spec.root+1)==spec.root..'/')
            and (spec.private_directory==nil or path(spec.private_directory))
        local target,root,private
        if valid then target,root,private=spec.path,spec.root,spec.private_directory end
        schedule(function()
            if not valid then c.fail('invalid');return end
            local suffix=target:sub(#root+1);local paths={root};local current=root=='/' and '' or root
            for part in suffix:gmatch('[^/]+')do
                current=current..'/'..part;paths[#paths+1]=current
                if #paths>128 then c.fail('capacity');return end
            end
            local index=0
            local function next_directory()
                if not c.proceed()then return end
                index=index+1;local directory=paths[index]
                if not directory then c.applied=c.mutated or false;c.publish();return end
                if private and (directory==private or directory:sub(1,#private+1)==private..'/')then
                    c.fail('private');return
                end
                c.stat(directory,function(observed)
                    if observed.exists then
                        if observed.type~='directory'then c.fail('not_directory');return end
                        next_directory();return
                    end
                    if index==1 then c.fail('missing_root');return end
                    c.rpc('mkdir',{directory,448},function(err)
                        if err then
                            if tostring(err):find('EEXIST',1,true)then
                                c.target_uncertain=false
                                c.stat(directory,function(now)
                                    if not now.exists or now.type~='directory'then c.fail('not_directory');return end
                                    next_directory()
                                end)
                            else c.fail('mkdir')end
                            return
                        end
                        c.target_uncertain=false;c.mutated=true
                        c.sync_parent(directory,next_directory)
                    end,false,true)
                end)
            end
            next_directory()
        end)
        return handle
    end
    function fs.write_checked(_,spec,done)
        local c,handle=operation(done)
        local valid=type(spec)=='table' and path(spec.path) and type(spec.content)=='string'
            and #spec.content<=max_bytes and valid_revision(spec.expected)
            and (not spec.expected.exists or path(spec.backup_path) and spec.backup_path~=spec.path)
        if valid then
            c.path=spec.path;c.content=spec.content;c.expected=copy(spec.expected);c.backup_path=spec.backup_path
        end
        local function target()
            c.stat(c.path,function(current)
                if not same(current,c.expected)then c.fail('conflict');return end
                local flags=current.exists and 'r+' or 'wx'
                c.open(c.path,flags,current.mode or 384,function(fd)
                    local function write()c.write_bytes(fd,c.content,true,c.publish)end
                    if not current.exists then write();return end
                    c.rpc('fstat',{fd},function(err,value)
                        if err or not same(revision(value),c.expected)then c.fail('conflict');return end
                        c.stat(c.path,function(last)
                            if not same(last,c.expected)then c.fail('conflict');return end
                            c.rpc('ftruncate',{fd,0},function(failure)
                                if failure then c.fail('truncate');return end
                                c.target_uncertain=false;c.mutated=true;write()
                            end,false,true)
                        end)
                    end)
                end)
            end)
        end
        schedule(function()
            if not valid then c.fail('invalid');return end
            if not c.proceed()then return end
            if not c.expected.exists then target();return end
            c.read_snapshot(c.path,c.expected,max_bytes-#c.content,function(prior)
                serial=serial+1;c.temp_candidate=c.backup_path..'.tmp.'..tostring(serial)
                c.open(c.temp_candidate,'wx',384,function(fd)
                    c.write_bytes(fd,prior,false,function()
                        c.rpc('link',{c.temporary,c.backup_path},function(err)
                            if err then c.fail('backup_publish');return end
                            c.backup_published=true
                            c.rpc('unlink',{c.temporary},function(failure)
                                if failure then c.fail('backup_cleanup');return end
                                c.temporary=nil
                                c.sync_parent(c.backup_path,function()c.backup_confirmed=true;target()end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
        return handle
    end
    return fs
end
return M
