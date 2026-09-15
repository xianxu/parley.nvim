-- Immutable answer snapshots. Publication is a prerequisite, never a best-effort
-- backup; the directory itself is the discovery index and physical quota ledger.
local M={}
local MAX_RECORD=16*1024*1024
local MAX_PROFILE=256*1024*1024
local states=setmetatable({},{__mode='k'})
local serial=0
local pending_owners={}
local pending_count=0
local native_runtime={}
local MAX_PENDING=32
local function native()
    local uv=vim.uv or vim.loop
    return {fstat=uv.fs_fstat,stat=uv.fs_stat,lstat=uv.fs_lstat,mkdir=uv.fs_mkdir,open=uv.fs_open,
        write=uv.fs_write,read=uv.fs_read,fsync=uv.fs_fsync,close=uv.fs_close,
        rename=uv.fs_rename,unlink=uv.fs_unlink,list=function(path)
            local scan,err=uv.fs_scandir(path);if not scan then return nil,err end
            local out={};while true do local name=uv.fs_scandir_next(scan);if not name then break end;out[#out+1]=name end
            return out
        end}
end
local function state(store)return assert(states[store],'invalid recovery store')end
local function fail(reason)return {ok=false,reason=tostring(reason)}end
local function copy(value)return vim.deepcopy(value)end
local function text(value,empty)return type(value)=='string' and #value<=4096 and (empty or #value>0)end
local function association(value)
    if type(value)~='table'then return false end
    for _,name in ipairs({'timestamp','path','root','question','predecessor'})do
        if not text(value[name],name=='predecessor')then return false end
    end
    return true
end
local function replacement(value)
    return type(value)=='table' and type(value.bytes)=='string' and #value.bytes<=MAX_RECORD
        and (value.revision==nil or text(value.revision) or type(value.revision)=='number'
            and value.revision>=0 and value.revision<math.huge and value.revision%1==0)
end
local function valid(record)
    return type(record)=='table' and text(record.id) and record.id:match('^[%w%-]+$')
        and text(record.key) and type(record.sequence)=='number' and record.sequence>=1
        and record.sequence%1==0 and type(record.bytes)=='string' and #record.bytes<=MAX_RECORD
        and association(record.association) and replacement(record.replacement)
        and (record.annotations==nil or type(record.annotations)=='table')
end
local function encode(record)
    local payload=vim.json.encode(record)
    return vim.json.encode({version=1,payload=payload,sha256=vim.fn.sha256(payload)})
end
local function decode(bytes)
    local ok,envelope=pcall(vim.json.decode,bytes)
    if not ok or type(envelope)~='table' or envelope.version~=1 or type(envelope.payload)~='string'
        or envelope.sha256~=vim.fn.sha256(envelope.payload)then return nil end
    local parsed,record=pcall(vim.json.decode,envelope.payload)
    return parsed and valid(record) and record or nil
end
local function close(s,fd)
    local ok,err=s.fs.close(fd)
    if not ok then
        if not s.pending[fd]then s.pending[fd]=true;pending_count=pending_count+1 end
        pending_owners[s]=s.store[1]
        return nil,err
    end
    return true
end
-- An ambiguous close loses ownership of the numeric descriptor. Keep its
-- owner alive and block new opens in that store until absence is proven.
local function open_handle(s,path,flags,mode)
    if next(s.pending)then return nil,'recovery close unresolved'end
    if pending_count>=MAX_PENDING then return nil,'recovery pending handle capacity exceeded'end
    return s.fs.open(path,flags,mode)
end
local function read(s,path,size)
    local fd,err=open_handle(s,path,'r',384);if not fd then return nil,err end
    local chunks,offset={},0
    while offset<size do
        local bytes,why=s.fs.read(fd,math.min(65536,size-offset),offset)
        if not bytes or #bytes==0 then close(s,fd);return nil,why or 'truncated recovery record' end
        chunks[#chunks+1]=bytes;offset=offset+#bytes
    end
    local done,why=close(s,fd);if not done then return nil,why end
    return table.concat(chunks)
end
local function scan(s)
    local names,err=s.fs.list(s.directory);if not names then return nil,err end
    local records,paths,keys={}, {},{}
    local total,unavailable=0,0
    local blocked={}
    for _,name in ipairs(names)do
        local path=s.directory..'/'..name
        local stat,why=s.fs.lstat(path);if not stat then return nil,why end
        if stat.type~='file' then return nil,'unexpected recovery artifact type' end
        total=total+stat.size
        local record
        if name:match('%.json$') and stat.size<=s.max_record and stat.mode%512==384 then
            local bytes,read_error=read(s,path,stat.size)
            if not bytes then return nil,read_error end
            record=decode(bytes)
            if record and name~=record.id..'.'..record.sequence..'.json' then record=nil end
        end
        if record then
            paths[record.id]=paths[record.id] or {};paths[record.id][#paths[record.id]+1]=path
            local previous=records[record.id]
            if previous and (previous.key~=record.key or previous.bytes~=record.bytes
                or not vim.deep_equal(previous.association,record.association))then
                return nil,'conflicting recovery revisions'
            end
            if not previous or record.sequence>previous.sequence then records[record.id]=record end
        else
            unavailable=unavailable+1
            local committed=name:match('^([%w%-]+)%.%d+%.json$') or name:match('^([%w%-]+)%.%d+%.json%.quarantine$')
            if committed then blocked[committed]=true end
            -- Quarantine is unavailable even if renaming fails. It remains in
            -- the physical quota ledger and is never silently age-deleted.
            if name:match('%.json$')then s.fs.rename(path,path..'.quarantine')end
        end
    end
    local blocked_keys={}
    for id in pairs(blocked)do
        if records[id]then blocked_keys[records[id].key]=true end
        records[id]=nil
    end
    s.blocked_keys=blocked_keys
    for id,record in pairs(records)do
        if keys[record.key] and keys[record.key]~=id then return nil,'ambiguous recovery key' end
        keys[record.key]=id
    end
    s.records,s.paths,s.keys=records,paths,keys;s.bytes=total;s.unavailable=unavailable
    return true
end
local function sync_directory(s)
    local fd,err=open_handle(s,s.directory,'r',448);if not fd then return nil,err end
    local synced,why=s.fs.fsync(fd)
    local closed,failure=close(s,fd)
    return synced and closed,why or failure
end
local function publish_record(s,record)
    if next(s.pending)then return fail('recovery close unresolved')end
    local scanned,why=scan(s);if not scanned then return fail(why)end
    local ok,bytes=pcall(encode,record);if not ok then return fail('invalid recovery metadata')end
    if #bytes>s.max_record then return fail('recovery snapshot exceeds record limit')end
    if s.bytes+#bytes>s.max_bytes then return fail('recovery profile capacity exceeded')end
    local target=s.directory..'/'..record.id..'.'..record.sequence..'.json'
    if s.fs.lstat(target)then return fail('recovery publication already exists')end
    local temporary=target..'.tmp'
    local fd,err=open_handle(s,temporary,'wx',384);if not fd then return fail(err)end
    local offset=0
    while offset<#bytes do
        local count,failure=s.fs.write(fd,bytes:sub(offset+1,offset+65536),offset)
        if not count or count<=0 or count>math.min(65536,#bytes-offset) then err=failure or 'invalid recovery write';break end
        offset=offset+count
    end
    if not err then local synced,failure=s.fs.fsync(fd);if not synced then err=failure end end
    local closed,failure=close(s,fd);if not closed then err=err or failure end
    if not err then local renamed,rename_error=s.fs.rename(temporary,target);if not renamed then err=rename_error end end
    if err then
        if closed then s.fs.unlink(temporary)end
        scan(s);return fail(err)
    end
    -- A successful rename is the authority boundary. Directory synchronization
    -- confirms it survives a crash before replacement is allowed to proceed.
    local synced,sync_error=sync_directory(s)
    local refreshed,scan_error=scan(s)
    if not synced or not refreshed then return fail(sync_error or scan_error)end
    if not s.records[record.id] or s.records[record.id].sequence~=record.sequence then
        return fail('published recovery record unavailable')
    end
    return {ok=true,id=record.id}
end
function M.open(opts)
    if type(opts)~='table' or not text(opts.directory)then return nil,'recovery directory required'end
    local s={directory=opts.directory,fs=opts.fs or native(),runtime=opts.fs or native_runtime,pending={},
        max_record=opts.max_record_bytes or MAX_RECORD,max_bytes=opts.max_bytes or MAX_PROFILE}
    for _,limit in ipairs({{s.max_record,MAX_RECORD},{s.max_bytes,MAX_PROFILE}})do
        if type(limit[1])~='number' or limit[1]<1 or limit[1]%1~=0 or limit[1]>limit[2]then return nil,'invalid recovery capacity'end
    end
    for owner in pairs(pending_owners)do
        if owner.directory==s.directory and owner.runtime==s.runtime then
            if owner.max_record~=s.max_record or owner.max_bytes~=s.max_bytes then
                return nil,'unresolved recovery owner has different capacities'
            end
            return owner.store[1]
        end
    end
    local store={};s.store=setmetatable({store},{__mode='v'});states[store]=s
    local stat,err=s.fs.lstat(s.directory)
    if not stat then
        if not tostring(err):find('ENOENT',1,true)then return nil,err end
        local made,why=s.fs.mkdir(s.directory,448);if not made then return nil,why end
        stat,err=s.fs.lstat(s.directory);if not stat then return nil,err end
    end
    if stat.type~='directory' or stat.mode%512~=448 then return nil,'recovery directory must be private (0700)'end
    local ok,why=scan(s);if not ok then return nil,why end
    return store
end
function M.publish(store,spec)
    local s=state(store)
    if type(spec)~='table' or not text(spec.key) or type(spec.bytes)~='string'
        or not association(spec.association) or not replacement(spec.replacement)then return fail('invalid recovery snapshot')end
    local ok,err=scan(s);if not ok then return fail(err)end
    if s.blocked_keys[spec.key]then return fail('original recovery snapshot unavailable')end
    local existing=s.keys[spec.key]
    if existing then
        if not vim.deep_equal(s.records[existing].association,spec.association)then return fail('recovery key association changed')end
        if next(s.pending)then return fail('recovery close unresolved')end
        local synced,why=sync_directory(s);if not synced then return fail(why)end
        return {ok=true,id=existing,retained=true}
    end
    serial=serial+1
    local record=copy(spec);record.id=vim.fn.sha256(tostring((vim.uv or vim.loop).hrtime())..':'..serial):sub(1,32);record.sequence=1
    if not valid(record)then return fail('invalid recovery snapshot')end
    return publish_record(s,record)
end
function M.inspect(store,id)
    local s=state(store);local ok,err=scan(s);if not ok then return nil,err end
    local record=s.records[id];return record and copy(record) or nil,'snapshot unavailable'
end
function M.update(store,id,evidence)
    local s=state(store);local record,err=M.inspect(store,id)
    if not record then return fail(err)end
    if not replacement(evidence)then return fail('invalid replacement evidence')end
    local previous=copy(s.paths[id]);record.sequence=record.sequence+1;record.replacement=copy(evidence)
    local result=publish_record(s,record);if not result.ok then return result end
    local cleanup_error
    for _,path in ipairs(previous)do local ok,why=s.fs.unlink(path);if not ok then cleanup_error=why end end
    local scanned,scan_error=scan(s)
    result.cleanup_error=cleanup_error or (not scanned and scan_error or nil);return result
end
function M.resolve(store,id,candidates)
    local record,err=M.inspect(store,id);if not record then return fail(err)end
    local matches={}
    for _,candidate in ipairs(candidates or {})do
        local a,b=record.association,candidate.association
        if association(b) and a.timestamp==b.timestamp and a.root==b.root and a.question==b.question
            and a.predecessor==b.predecessor and replacement(candidate.replacement)
            and record.replacement.bytes==candidate.replacement.bytes then matches[#matches+1]=candidate end
    end
    if #matches~=1 then return fail(#matches==0 and 'no exact recovery target' or 'ambiguous recovery target')end
    return {ok=true,target=matches[1].target,record=record}
end
function M.restore(store,id,opts)
    local record,err=M.inspect(store,id);if not record then return fail(err)end
    if type(opts)~='table' or type(opts.validate)~='function' or type(opts.apply)~='function'then return fail('fresh restore validation required')end
    local ok,proof,why=pcall(opts.validate,copy(record))
    if not ok or not proof then return fail(why or proof or 'restore conflict')end
    local applied,result=pcall(opts.apply,proof,record.bytes,copy(record.annotations))
    if not applied then return fail(result)end
    if type(result)~='table' or result.ok~=true then return fail(type(result)=='table' and result.reason or 'restore not confirmed')end
    return result
end
function M.cleanup(store,id,evidence)
    local s=state(store);local record,err=M.inspect(store,id);if not record then return fail(err)end
    if type(evidence)~='table' then return fail('cleanup evidence required')end
    if evidence.kind=='saved' then
        if not vim.deep_equal(record.replacement,evidence.replacement)then return fail('saved replacement does not match')end
    elseif evidence.kind~='discard' and evidence.kind~='chat_deleted' then return fail('invalid cleanup reason')end
    local failure
    local paths=copy(s.paths[id])
    table.sort(paths,function(a,b)
        return tonumber(a:match('%.(%d+)%.json$'))<tonumber(b:match('%.(%d+)%.json$'))
    end)
    -- Keep the newest evidence if any earlier deletion fails; never resurrect
    -- an older replacement revision as the current snapshot after cleanup.
    for _,path in ipairs(paths)do local ok,why=s.fs.unlink(path);if not ok then failure=why;break end end
    local ok,why=scan(s);if not ok then return fail(why)end
    return failure and fail(failure) or {ok=true}
end
function M.reconcile(store)
    local s=state(store);local failure
    for fd in pairs(s.pending)do
        local called,stat,err,code=pcall(s.fs.fstat or function()return nil,'descriptor probe unavailable'end,fd)
        local absent=called and not stat and (code=='EBADF' or err=='EBADF'
            or type(err)=='string' and err:match('^EBADF:'))
        if absent then
            s.pending[fd]=nil;pending_count=pending_count-1
        else failure=called and (err or 'recovery close unresolved') or stat end
    end
    if not next(s.pending)then pending_owners[s]=nil end
    local ok,err=scan(s)
    return failure and fail(failure) or not ok and fail(err)
        or next(s.pending) and fail('recovery close unresolved') or {ok=true}
end
function M.list(store)
    local s=state(store);local ok,err=scan(s);if not ok then return nil,err end
    local records={}
    for id,record in pairs(s.records)do
        records[#records+1]={id=id,key=record.key,sequence=record.sequence,
            association=copy(record.association),replacement=copy(record.replacement)}
    end
    table.sort(records,function(a,b)return a.id<b.id end)
    return records
end
function M.stats(store)
    local s=state(store);local ok,err=scan(s);if not ok then return {error=err}end
    local count,pending=0,0;for _ in pairs(s.records)do count=count+1 end;for _ in pairs(s.pending)do pending=pending+1 end
    return {bytes=s.bytes,records=count,unavailable=s.unavailable,pending_closes=pending}
end
return M
