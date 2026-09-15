-- Stateful asynchronous filesystem: effects happen only when their queued IO
-- completion is stepped. Faults can occur before/after effects or lose callbacks.
local M={}
function M.new()
    local s={files={},fds={},queue={},calls={},faults={},serial=0,clock=0,short_write=nil,short_read=nil,lost={}}
    local runtime={}
    local function stamp(f)s.clock=s.clock+1;f.mtime={sec=s.clock,nsec=s.clock};f.ctime={sec=s.clock,nsec=s.clock}end
    function s.put(path,bytes,kind)
        s.serial=s.serial+1;local f={bytes=bytes or '',type=kind or 'file',dev=1,ino=s.serial,mode=384};stamp(f);s.files[path]=f
        return f
    end
    local function stat(f)
        return {type=f.type,mode=f.mode,dev=f.dev,ino=f.ino,size=#f.bytes,mtime=vim.deepcopy(f.mtime),ctime=vim.deepcopy(f.ctime)}
    end
    function s.fail(name,...)s.faults[name]={...}end
    local function enqueue(name,args,callback,effect)
        s.calls[#s.calls+1]={name=name,args=vim.deepcopy(args)}
        local faults=s.faults[name];local fault=faults and table.remove(faults,1)
        s.queue[#s.queue+1]=function()
            if type(fault)=='table' and fault.before then fault.before(s,args)end
            if type(fault)=='string'then callback(fault);return end
            local err,result=effect()
            if type(fault)=='table' and fault.after then fault.after(s,args)end
            if type(fault)=='table' and fault.drop then s.lost[#s.lost+1]=function()callback(err,result)end;return end
            callback(type(fault)=='table' and fault.error or err,result)
            if type(fault)=='table' and fault.duplicate then callback(err,result)end
        end
        if type(fault)=='table' and fault.throw then error('submission threw after queuing')end
        return {}
    end
    runtime.fs_lstat=function(path,cb)return enqueue('lstat',{path},cb,function()
        local f=s.files[path];if not f then return 'ENOENT' end;return nil,stat(f)
    end)end
    runtime.fs_fstat=function(fd,cb)return enqueue('fstat',{fd},cb,function()
        local f=s.fds[fd];if not f then return 'EBADF' end;return nil,stat(f)
    end)end
    runtime.fs_open=function(path,flags,mode,cb)return enqueue('open',{path,flags,mode},cb,function()
        local f=s.files[path]
        if flags=='wx'then if f then return 'EEXIST'end;f=s.put(path,'');f.mode=mode
        elseif not f then return 'ENOENT'end
        s.serial=s.serial+1;s.fds[s.serial]=f;return nil,s.serial
    end)end
    runtime.fs_read=function(fd,size,offset,cb)return enqueue('read',{fd,size,offset},cb,function()
        local f=s.fds[fd];if not f then return 'EBADF'end
        return nil,f.bytes:sub(offset+1,offset+math.min(size,s.short_read or size))
    end)end
    runtime.fs_write=function(fd,bytes,offset,cb)return enqueue('write',{fd,#bytes,offset},cb,function()
        local f=s.fds[fd];if not f then return 'EBADF'end
        local n=math.min(#bytes,s.short_write or #bytes)
        f.bytes=f.bytes:sub(1,offset)..bytes:sub(1,n)..f.bytes:sub(offset+n+1);stamp(f);return nil,n
    end)end
    runtime.fs_ftruncate=function(fd,size,cb)return enqueue('ftruncate',{fd,size},cb,function()
        local f=s.fds[fd];if not f then return 'EBADF'end;f.bytes=f.bytes:sub(1,size);stamp(f);return nil,true
    end)end
    runtime.fs_fsync=function(fd,cb)return enqueue('fsync',{fd},cb,function()
        if not s.fds[fd]then return 'EBADF'end;return nil,true
    end)end
    runtime.fs_close=function(fd,cb)return enqueue('close',{fd},cb,function()
        if not s.fds[fd]then return 'EBADF'end;s.fds[fd]=nil;return nil,true
    end)end
    runtime.fs_link=function(old,new,cb)return enqueue('link',{old,new},cb,function()
        if s.files[new]then return 'EEXIST'end
        if not s.files[old]then return 'ENOENT'end;s.files[new]=s.files[old];return nil,true
    end)end
    runtime.fs_unlink_checked=function(path,expected,cb)return enqueue('unlink',{path},cb,function()
        local f=s.files[path];if not f then return 'ENOENT'end
        if not expected or f.dev~=expected.dev or f.ino~=expected.ino or f.type~=expected.type then return 'ESTALE'end
        s.files[path]=nil;return nil,true
    end)end
    runtime.fs_unlink=function(path,cb)return enqueue('unlink',{path},cb,function()
        if not s.files[path]then return 'ENOENT'end;s.files[path]=nil;return nil,true
    end)end
    runtime.fs_mkdir=function(path,mode,cb)return enqueue('mkdir',{path,mode},cb,function()
        if s.files[path]then return 'EEXIST'end
        local parent=path:match('^(.*)/[^/]+$')
        if not s.files[parent] or s.files[parent].type~='directory'then return 'ENOENT'end
        local f=s.put(path,'','directory');f.mode=mode;return nil,true
    end)end
    function s.schedule(fn)s.queue[#s.queue+1]=fn end
    function s.step()local fn=table.remove(s.queue,1);if fn then fn();return true end;return false end
    function s.drain(limit)for _=1,limit or 10000 do if not s.step()then return end end;error('fake filesystem did not settle')end
    function s.count(name)local n=0;for _,c in ipairs(s.calls)do if c.name==name then n=n+1 end end;return n end
    return runtime,s
end
return M
