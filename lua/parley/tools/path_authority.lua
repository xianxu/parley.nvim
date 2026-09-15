-- Path capabilities retain identities, never ambient pathname authority. Native
-- workers resolve each component relative to a pinned directory descriptor.
local M={}
local tokens=setmetatable({},{__mode='k'})
local function encode(value)
    if type(value)=='string'then return string.format('%q',value)end
    if type(value)~='table'then return tostring(value)end
    local out={'{'};for k,v in pairs(value)do out[#out+1]='['..encode(k)..']='..encode(v)..','end
    out[#out+1]='}';return table.concat(out)
end
function M.capture(paths,claims,parent)
    local uv=vim.uv or vim.loop
    if not jit or (jit.os~='OSX' and jit.os~='Linux') or not uv.new_work then
        return nil,'descriptor-relative tool filesystem unavailable'
    end
    if parent then
        local previous=tokens[parent];if not previous then return nil,'invalid parent authority'end
        for path,expected in pairs(previous.evidence)do
            local stat=uv.fs_lstat(path)
            if not stat or stat.dev~=expected.dev or stat.ino~=expected.ino or stat.type~=expected.type then
                return nil,'captured root authority changed'
            end
        end
    end
    local evidence={};local count=0
    for _,path in ipairs(paths)do
        if type(path)~='string' or path:sub(1,1)~='/' or #path>4096 then return nil,'invalid authority path'end
        local current=''
        for part in path:gmatch('[^/]+')do
            if part=='.' or part=='..'then return nil,'invalid authority component'end
            current=current..'/'..part
            if not evidence[current]then
                count=count+1;if count>4096 then return nil,'path authority capacity'end
                local stat,err=uv.fs_lstat(current)
                if stat then
                    if stat.type=='link'then return nil,'path authority symlink'end
                    if stat.type~='file' and stat.type~='directory'then return nil,'unsupported tool resource type'end
                    evidence[current]={dev=stat.dev,ino=stat.ino,type=stat.type}
                elseif not tostring(err):find('ENOENT',1,true)then return nil,err end
            end
        end
    end
    local permissions={}
    for _,p in ipairs(paths)do permissions[#permissions+1]={path=p,scope='file'}end
    for _,claim in ipairs(claims or {})do
        if claim.path then permissions[#permissions+1]={path=claim.path,scope=claim.scope}end
    end
    local value={evidence=evidence,permissions=permissions}
    if #encode(value)>65536 then return nil,'path authority capacity'end
    local token={};tokens[token]=value;return token
end
function M.export(token)return vim.deepcopy(assert(tokens[token],'invalid path authority'))end
function M.import(value)
    if type(value)~='table' or type(value.evidence)~='table' or type(value.permissions)~='table'then return nil,'invalid authority'end
    local seen,nodes,bytes={},0,0
    local function bounded(v,depth)
        nodes=nodes+1;if nodes>8192 or depth>8 then return false end
        if type(v)=='string'then bytes=bytes+#v;return bytes<=65536 end
        if type(v)=='number'then return v==v and v>=0 and v<math.huge and v%1==0 end
        if type(v)~='table' or getmetatable(v) or seen[v]then return false end
        seen[v]=true
        for k,x in pairs(v)do if not bounded(k,depth+1) or not bounded(x,depth+1)then return false end end
        return true
    end
    if not bounded(value,0) or #encode(value)>65536 then return nil,'authority capacity'end
    for path,stat in pairs(value.evidence)do
        if type(path)~='string' or path:sub(1,1)~='/' or type(stat)~='table'
            or type(stat.dev)~='number' or type(stat.ino)~='number'
            or (stat.type~='file' and stat.type~='directory')then return nil,'invalid authority'end
    end
    for _,p in ipairs(value.permissions)do
        if type(p)~='table' or type(p.path)~='string' or p.path:sub(1,1)~='/'
            or (p.scope~='file' and p.scope~='subtree')then return nil,'invalid authority'end
    end
    local token={};tokens[token]=vim.deepcopy(value);return token
end
local function worker(encoded)
    local uv=require('luv');local ffi=require('ffi')
    ffi.cdef([[int openat(int, const char *, int, ...); int mkdirat(int,const char *,unsigned int);
        int unlinkat(int,const char *,int); int linkat(int,const char *,int,const char *,int);]])
    local spec=assert(loadstring('return '..encoded))()
    local nofollow=ffi.os=='OSX' and 256 or 131072
    local directory=ffi.os=='OSX' and 1048576 or 65536
    local cloexec=ffi.os=='OSX' and 16777216 or 524288
    local nonblock=ffi.os=='OSX' and 4 or 2048
    local owned={}
    local bindings={}
    local created={}
    local function close(fd)
        local ok=uv.fs_close(fd);if ok then owned[fd]=nil end;return ok
    end
    local function clean()for fd,state in pairs(owned)do if state~=false then close(fd)end end end
    local function error_code()return uv.translate_sys_error(ffi.errno())end
    local function pin(path)
        local parts={};for part in path:gmatch('[^/]+')do parts[#parts+1]=part end
        if #parts>128 then return nil,'E2BIG'end
        local fd,err=uv.fs_open('/',0,0);if not fd then return nil,err end;owned[fd]=true
        local current=''
        for i=1,#parts-1 do
            current=current..'/'..parts[i]
            local nextfd=ffi.C.openat(fd,parts[i],nofollow+directory+cloexec)
            if nextfd<0 then return nil,error_code()end
            nextfd=tonumber(nextfd);owned[nextfd]=true
            local stat=uv.fs_fstat(nextfd);local expected=spec.evidence[current]
            if not stat or expected and (stat.dev~=expected.dev or stat.ino~=expected.ino or stat.type~=expected.type)then
                return nil,'ESTALE: path authority changed'
            end
            if not close(fd)then owned[fd]=false;return nil,'EIO: directory close unresolved'end;fd=nextfd
        end
        return fd,parts[#parts] or '.'
    end
    local function execute()
        if spec.name=='ftruncate'then
            local guard=spec.preimage
            if not guard then return nil,'EACCES: checked pre-image required'end
            local parent,leaf=pin(guard.path);if not parent then return nil,leaf end
            local fd=ffi.C.openat(parent,leaf,nofollow+cloexec+nonblock)
            if fd<0 then return nil,error_code()end;fd=tonumber(fd);owned[fd]=true
            local stat=uv.fs_fstat(fd);local expected=guard.revision
            if not stat or stat.dev~=expected.dev or stat.ino~=expected.ino or stat.type~=expected.type
                or stat.size~=expected.size or stat.mode~=expected.mode
                or stat.mtime.sec~=expected.mtime.sec or stat.mtime.nsec~=expected.mtime.nsec
                or stat.ctime.sec~=expected.ctime.sec or stat.ctime.nsec~=expected.ctime.nsec then
                return nil,'ESTALE: durable pre-image changed before truncate'
            end
            return uv.fs_ftruncate(spec.args[1],spec.args[2])
        end
        local parent,leaf=pin(spec.args[1]);if not parent then return nil,leaf end
        local name=spec.name
        if name=='open' or name=='lstat'then
            local flags=0
            if name=='open'then
                local kind=spec.args[2]
                if kind=='r+'then flags=2
                elseif kind=='wx'then flags=1+(ffi.os=='OSX' and 512+2048 or 64+128)
                elseif kind~='r' then return nil,'EINVAL: unsupported protected open'end
            end
            local fd=ffi.C.openat(parent,leaf,flags+nofollow+cloexec+nonblock,ffi.cast('unsigned int',spec.args[3] or 0))
            if fd<0 then return nil,error_code()end;fd=tonumber(fd);owned[fd]=true
            if name=='open' and spec.args[2]=='wx'then created[spec.args[1]]=true end
            local stat,err=uv.fs_fstat(fd);if not stat then return nil,err end
            if stat.type~='file' and stat.type~='directory'then return nil,'EACCES: unsupported resource type'end
            local expected=spec.evidence[spec.args[1]]
            if expected and (stat.dev~=expected.dev or stat.ino~=expected.ino or stat.type~=expected.type)then
                return nil,'ESTALE: resource identity changed'
            end
            if name=='open'then
                if spec.args[2]=='wx'then
                    bindings[spec.args[1]]={dev=stat.dev,ino=stat.ino,type=stat.type};created[spec.args[1]]=nil
                end
                owned[fd]=nil;return fd
            end
            return stat
        elseif name=='mkdir'then
            if ffi.C.mkdirat(parent,leaf,spec.args[2])~=0 then return nil,error_code()end
            created[spec.args[1]]=true
            local fd=ffi.C.openat(parent,leaf,nofollow+directory+cloexec)
            if fd<0 then return nil,error_code()end;fd=tonumber(fd);owned[fd]=true
            local stat=uv.fs_fstat(fd);if not stat then return nil,'EIO: created directory identity unavailable'end
            bindings[spec.args[1]]={dev=stat.dev,ino=stat.ino,type=stat.type};created[spec.args[1]]=nil;return true
        elseif name=='unlink'then
            local expected=spec.evidence[spec.args[1]]
            if not expected then return nil,'ESTALE: unlink requires owned leaf identity'end
            local fd=ffi.C.openat(parent,leaf,nofollow+cloexec+nonblock)
            if fd<0 then return nil,error_code()end;fd=tonumber(fd);owned[fd]=true
            local stat=uv.fs_fstat(fd)
            if not stat or stat.dev~=expected.dev or stat.ino~=expected.ino or stat.type~=expected.type then
                return nil,'ESTALE: cleanup leaf replaced'
            end
            if ffi.C.unlinkat(parent,leaf,0)~=0 then return nil,error_code()end;return true
        elseif name=='link'then
            local expected=spec.evidence[spec.args[1]]
            if not expected then return nil,'ESTALE: publication requires owned leaf identity'end
            local fd=ffi.C.openat(parent,leaf,nofollow+cloexec+nonblock)
            if fd<0 then return nil,error_code()end;fd=tonumber(fd);owned[fd]=true
            local source=uv.fs_fstat(fd)
            if not source or source.dev~=expected.dev or source.ino~=expected.ino or source.type~='file'then
                return nil,'ESTALE: pre-image leaf replaced'
            end
            local other,target=pin(spec.args[2]);if not other then return nil,target end
            if ffi.C.linkat(parent,leaf,other,target,0)~=0 then return nil,error_code()end
            created[spec.args[2]]=true
            local published=ffi.C.openat(other,target,nofollow+cloexec+nonblock)
            if published<0 then return nil,error_code()end;published=tonumber(published);owned[published]=true
            local stat=uv.fs_fstat(published)
            if not stat or stat.dev~=source.dev or stat.ino~=source.ino or stat.type~='file'then
                return nil,'ESTALE: published pre-image identity changed'
            end
            bindings[spec.args[2]]={dev=stat.dev,ino=stat.ino,type=stat.type};created[spec.args[2]]=nil;return true
        end
        return nil,'EINVAL'
    end
    local ok,value,err=pcall(execute);clean()
    local unresolved={}
    for fd in pairs(owned)do unresolved[#unresolved+1]={fd=fd,identity=uv.fs_fstat(fd)}end
    local function serialize(v)
        if type(v)=='string'then return string.format('%q',v)end
        if type(v)~='table'then return tostring(v)end
        local out={'{'};for k,x in pairs(v)do out[#out+1]='['..serialize(k)..']='..serialize(x)..','end
        out[#out+1]='}';return table.concat(out)
    end
    if not ok then return serialize({error=tostring(value),unresolved=unresolved,bindings=bindings,created=created})end
    return serialize({value=value,error=err,unresolved=unresolved,bindings=bindings,created=created})
end
function M.runtime(token)
    local authority=tokens[token];assert(authority,'invalid path authority')
    local evidence=vim.deepcopy(authority.evidence)
    local additions=0
    local preimage
    local uv=vim.uv or vim.loop;local runtime=setmetatable({},{__index=uv})
    local unresolved={}
    local uncertain_created={}
    function runtime.unresolved()return next(unresolved)~=nil end
    function runtime.uncertain_artifacts()return vim.deepcopy(uncertain_created)end
    function runtime.uncertain()return next(uncertain_created)~=nil end
    function runtime.reconcile()
        for fd,identity in pairs(unresolved)do
            local stat,err=uv.fs_fstat(fd)
            if tostring(err):find('EBADF',1,true) or stat and identity and
                (stat.dev~=identity.dev or stat.ino~=identity.ino)then unresolved[fd]=nil end
        end
    end
    local function permitted(path)
        if type(path)~='string' or #path>4096 or path:find('%z') or path:find('//',1,true)then return false end
        for part in path:gmatch('[^/]+')do if part=='.' or part=='..'then return false end end
        for _,p in ipairs(authority.permissions)do
            if path==p.path or p.scope=='subtree' and (p.path=='/' or path:sub(1,#p.path+1)==p.path..'/')then return true end
        end
        return false
    end
    function runtime.require_preimage(path,revision)
        assert(permitted(path),'pre-image outside captured authority')
        preimage={path=path,revision=vim.deepcopy(revision)}
    end
    for _,name in ipairs({'open','lstat','mkdir','link','unlink','ftruncate'})do
        runtime['fs_'..name]=function(...)
            local args={...};local callback=table.remove(args)
            if name~='ftruncate' and (not permitted(args[1]) or name=='link' and not permitted(args[2]))then
                vim.schedule(function()callback('EACCES: outside captured resources')end);return {}
            end
            local work
            work=uv.new_work(worker,function(encoded)
                local result=assert(loadstring('return '..encoded))()
                for _,item in ipairs(result.unresolved or {})do unresolved[item.fd]=item.identity or false end
                for path in pairs(result.created or {})do uncertain_created[path]=true end
                for path,identity in pairs(result.bindings or {})do
                    if not evidence[path]then additions=additions+1 end
                    evidence[path]=identity
                end
                callback(result.error,result.value);work=nil
            end)
            local creates=name=='mkdir' or name=='link' or name=='open' and args[2]=='wx'
            local newpath=name=='link' and args[2] or args[1]
            if creates and (additions>=256 or #encode(evidence)+#newpath+128>65536)then
                vim.schedule(function()callback('E2BIG: created resource identity capacity')end);return {}
            end
            work:queue(encode({name=name,args=args,evidence=evidence,preimage=preimage}));return work
        end
    end
    function runtime.fs_unlink_checked(path,expected,callback)
        local bound=evidence[path]
        if not bound or not expected or bound.dev~=expected.dev or bound.ino~=expected.ino or bound.type~=expected.type then
            vim.schedule(function()callback('ESTALE: cleanup identity unavailable')end);return {}
        end
        return runtime.fs_unlink(path,callback)
    end
    return runtime
end
return M
