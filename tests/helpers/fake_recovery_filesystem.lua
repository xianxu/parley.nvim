local M={}
function M.new()
    local fs={files={},handles={},faults={},calls={},next_fd=0,short_write=nil}
    local function fault(name)
        fs.calls[#fs.calls+1]=name
        local queue=fs.faults[name]
        if queue and #queue>0 then local value=table.remove(queue,1);if value then return tostring(value) end end
    end
    function fs.fail(name,...)fs.faults[name]={...}end
    function fs.stat(path)
        local err=fault('stat');if err then return nil,err end
        local f=fs.files[path];if not f then return nil,'ENOENT' end
        return {type=f.type or 'file',size=#(f.bytes or ''),mode=f.mode or 384}
    end
    fs.lstat=fs.stat
    function fs.mkdir(path,mode)
        local err=fault('mkdir');if err then return nil,err end
        if fs.files[path]then return nil,'EEXIST'end
        fs.files[path]={type='directory',mode=mode};return true
    end
    function fs.open(path,flags,mode)
        local err=fault('open');if err then return nil,err end
        if flags=='wx' then
            if fs.files[path]then return nil,'EEXIST'end
            fs.files[path]={bytes='',mode=mode}
        elseif not fs.files[path]then return nil,'ENOENT'end
        fs.next_fd=fs.next_fd+1;fs.handles[fs.next_fd]={path=path};return fs.next_fd
    end
    function fs.write(fd,bytes,offset)
        local err=fault('write');if err then return nil,err end
        local f=fs.files[assert(fs.handles[fd]).path]
        local count=math.min(#bytes,fs.short_write or #bytes)
        f.bytes=f.bytes:sub(1,offset)..bytes:sub(1,count)..f.bytes:sub(offset+count+1)
        return count
    end
    function fs.read(fd,size,offset)
        local err=fault('read');if err then return nil,err end
        return fs.files[assert(fs.handles[fd]).path].bytes:sub(offset+1,offset+size)
    end
    function fs.fsync(_)local err=fault('fsync');if err then return nil,err end;return true end
    function fs.close(fd)
        local err=fault('close');if err then return nil,err end
        fs.handles[fd]=nil;return true
    end
    function fs.rename(old,new)
        local err=fault('rename');if err then return nil,err end
        fs.files[new]=fs.files[old];fs.files[old]=nil;return true
    end
    function fs.unlink(path)
        local err=fault('unlink');if err then return nil,err end
        fs.files[path]=nil;return true
    end
    function fs.list(path)
        local err=fault('list');if err then return nil,err end
        local names={}
        for name in pairs(fs.files)do
            local suffix=name:sub(#path+2)
            if name:sub(1,#path+1)==path..'/' and not suffix:find('/')then names[#names+1]=suffix end
        end
        table.sort(names);return names
    end
    return fs
end
return M
