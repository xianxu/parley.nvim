-- Owns only private Parley runtime directories and listeners. Native lifetime
-- ends with serverstop; shared count/create/reclaim is serialized by the
-- existing permanent document lease, never by another lock protocol.
local M = {}
local uv = vim.uv or vim.loop
local codec = require('parley.remote_runtime_record')
local processes = require('parley.remote_process')
local lease = require('parley.document_lease')
local uid, pid = uv.os_get_passwd().uid, uv.os_getpid()
local function now() return uv.hrtime() / 1000000 end
local function same(a,b) return a and b and a.dev==b.dev and a.ino==b.ino and a.type==b.type end
local function private(stat) return stat and stat.type=='directory' and stat.uid==uid and stat.mode==16832 end
local function need(value,err) if not value then error(tostring(err or 'runtime unavailable'),0) end; return value end
local finalize_owned_write

-- A transaction has one outstanding fs request or joined process observation.
-- Cancellation drains it before descriptors and the kernel guard are released.
local function transaction(timeout, callback, body, deadline)
    local ctx = {deadline=deadline or now()+timeout, descriptors={}}
    local co, timer, finished, final_result
    local resume
    local function check()
        if ctx.finalizing then return end
        if ctx.stopped then error(ctx.stopped,0) end
        if now()>=ctx.deadline then error('runtime deadline',0) end
    end
    ctx.check=check
    local function complete(result)
        if finished then return end
        finished=true
        if timer and not timer:is_closing() then timer:stop();timer:close() end
        for fd in pairs(ctx.descriptors) do pcall(uv.fs_close,fd) end
        if ctx.finally then
            local ok,err=pcall(ctx.finally,result)
            if not ok then result={kind='unavailable',error=tostring(err)} end
        end
        if ctx.guard then ctx.guard.release();ctx.guard=nil end
        vim.schedule(function() callback(result) end)
    end
    local function finish(result)
        if result.kind~='unavailable' or (not ctx.owned_write and not ctx.created_directory) then complete(result);return end
        -- Admission is over. Only this finite, exact-owned cleanup can run
        -- beyond its deadline; it cannot start listeners or publish success.
        ctx.finalizing,final_result=true,result
        if timer and not timer:is_closing() then timer:stop();timer:close() end
        co=coroutine.create(function() finalize_owned_write(ctx) end)
        resume()
    end
    resume=function(...)
        if finished then return end
        local ok,result=coroutine.resume(co,...)
        if not ok then
            if ctx.finalizing then
                final_result.error=final_result.error..'; owned cleanup retained: '..tostring(result)
                complete(final_result)
            else finish({kind='unavailable',error=tostring(result)}) end
        elseif coroutine.status(co)=='dead' then
            if ctx.finalizing then complete(final_result)
            else finish(result or {kind='unavailable',error='runtime unavailable'}) end
        end
    end
    function ctx.fs(name,...)
        check()
        local args={...}
        local count=select('#',...)
        args[count+1]=function(err,result)
            ctx.request=nil
            if name=='fs_open' and result then ctx.descriptors[result]=true end
            if name=='fs_close' and not err then ctx.descriptors[args[1]]=nil end
            if name=='fs_mkdtemp' and not err and result then
                -- Capture this random directory before a canceled body can
                -- lose its ownership. No yield separates path and identity.
                ctx.created_directory={path=result,stat=uv.fs_lstat(result)}
            end
            local owned=ctx.owned_write
            if owned and not err then
                -- Capture native creation before the canceled body resumes.
                if name=='fs_open' and args[1]==owned.temporary and args[2]=='wx' then owned.fd=result end
                if name=='fs_fstat' and args[1]==owned.fd and not owned.stat then owned.stat=result end
            end
            vim.schedule(function() resume(result,err) end)
        end
        ctx.request=uv[name](unpack(args,1,count+1))
        local result,err=coroutine.yield()
        check()
        return result,err
    end
    function ctx.observe(pids,source)
        check()
        ctx.observation=processes.observe(pids,function(rows,status)
            ctx.observation=nil
            resume(rows,status)
        end,{source=source,deadline_ms=math.min(1000,ctx.deadline-now())})
        local rows,status=coroutine.yield()
        check()
        return rows,status
    end
    function ctx.lock(parent)
        check()
        local guard,err=lease.acquire('remote-session-runtime','allocation',{root=parent})
        ctx.guard=need(guard,err and (err.message or err.kind))
    end
    local operation={}
    function operation.cancel(reason)
        if finished or ctx.stopped or ctx.finalizing then return end
        ctx.stopped=reason or 'runtime canceled'
        if ctx.observation then ctx.observation.cancel()
        elseif ctx.request then pcall(uv.cancel,ctx.request) end
    end
    timer=uv.new_timer()
    -- The deadline is hrtime; refresh the loop clock so synchronous work before
    -- acquire cannot make the timer fire at once (#382, #421).
    require('parley.helper').start_deadline(timer,math.max(1,math.ceil(ctx.deadline-now())),
        vim.schedule_wrap(function() operation.cancel('runtime deadline') end))
    co=coroutine.create(function() check();return body(ctx) end)
    vim.schedule(function() resume() end)
    return operation
end

local function entries(ctx,path,limit)
    local scan=ctx.fs('fs_scandir',path)
    if not scan then return nil end
    local names={}
    while true do
        local name=uv.fs_scandir_next(scan)
        if not name then break end
        names[#names+1]=name
        if limit and #names>limit then return nil end
    end
    return names
end
local function read_marker(ctx,directory)
    local path=directory..'/owner.json'
    local stat=ctx.fs('fs_lstat',path)
    if not stat or stat.type~='file' or stat.uid~=uid or stat.mode%512~=384 or stat.size>32768 then return nil end
    local fd=ctx.fs('fs_open',path,'r',0)
    if not fd then return nil end
    local opened=ctx.fs('fs_fstat',fd)
    local bytes=ctx.fs('fs_read',fd,32769,0)
    ctx.fs('fs_close',fd)
    local after=ctx.fs('fs_lstat',path)
    if not same(stat,opened) or not same(stat,after) or not bytes or #bytes>32768
        or opened.size~=#bytes or after.size~=#bytes or stat.size~=#bytes then return nil end
    local record=codec.decode(bytes)
    if not record then return nil end
    return record,{stat=after,bytes=bytes}
end
local function witness_matches(ctx,directory,witness)
    local record,current=read_marker(ctx,directory)
    return record and current and same(current.stat,witness.stat) and current.bytes==witness.bytes
end
local function finalize_marker_write(ctx)
    local owned=ctx.owned_write
    local resource=owned.resource
    local function owned_directory()
        local stat=ctx.fs('fs_lstat',resource.directory)
        return private(stat) and same(stat,resource.stat)
    end
    if not owned_directory() then return end
    if not owned.stat and owned.fd and ctx.descriptors[owned.fd] then
        owned.stat=ctx.fs('fs_fstat',owned.fd)
    end
    if not owned.stat or owned.stat.type~='file' or owned.stat.uid~=uid then return end
    local temporary=ctx.fs('fs_lstat',owned.temporary)
    if same(temporary,owned.stat) and temporary.uid==uid and temporary.mode%512==384 and owned_directory() then
        need(ctx.fs('fs_unlink',owned.temporary))
    end
    local record,witness=read_marker(ctx,resource.directory)
    if record and same(witness.stat,owned.stat) and witness.bytes==owned.bytes and owned_directory() then
        -- The rename committed before cancellation was observed. This witness
        -- permits later exact cleanup, never activation or successful publish.
        resource.record,resource.witness=owned.record,witness
    end
end
finalize_owned_write=function(ctx)
    if ctx.owned_write then finalize_marker_write(ctx) end
    local created=ctx.created_directory
    if not created then return end
    local function owned_directory()
        local stat=ctx.fs('fs_lstat',created.path)
        return private(stat) and same(stat,created.stat)
    end
    if not owned_directory() then return end
    local names=entries(ctx,created.path,1)
    if not names then return end
    if #names==1 then
        local resource=created.resource
        if names[1]~='owner.json' or not resource or not resource.witness
            or not witness_matches(ctx,created.path,resource.witness) or not owned_directory() then return end
        need(ctx.fs('fs_unlink',created.path..'/owner.json'))
    end
    if owned_directory() then ctx.fs('fs_rmdir',created.path) end
end
local function write_marker(ctx,resource,record)
    need(same(ctx.fs('fs_lstat',resource.directory),resource.stat),'runtime directory changed')
    if resource.witness then need(witness_matches(ctx,resource.directory,resource.witness),'ownership marker changed') end
    local bytes=need(codec.encode(record),'invalid ownership marker')
    local temporary=resource.directory..'/.owner.tmp'
    local owned={resource=resource,temporary=temporary,bytes=bytes,record=record}
    ctx.owned_write=owned
    local fd=need(ctx.fs('fs_open',temporary,'wx',384))
    owned.stat=need(ctx.fs('fs_fstat',fd))
    local offset=0
    while offset<#bytes do
        local size=need(ctx.fs('fs_write',fd,bytes:sub(offset+1),offset))
        need(size>0,'marker write made no progress');offset=offset+size
    end
    need(ctx.fs('fs_fsync',fd));need(ctx.fs('fs_close',fd))
    if resource.witness then need(witness_matches(ctx,resource.directory,resource.witness),'ownership marker changed') end
    need(same(ctx.fs('fs_lstat',resource.directory),resource.stat),'runtime directory changed')
    need(ctx.fs('fs_rename',temporary,resource.directory..'/owner.json'))
    local directory_fd=need(ctx.fs('fs_open',resource.directory,'r',0))
    need(ctx.fs('fs_fsync',directory_fd));need(ctx.fs('fs_close',directory_fd))
    local stat=need(ctx.fs('fs_lstat',resource.directory..'/owner.json'))
    resource.record,resource.witness=record,{stat=stat,bytes=bytes}
    ctx.owned_write=nil
end
local function facts(ctx,directory,record)
    local stat=ctx.fs('fs_lstat',directory)
    local names=entries(ctx,directory,257)
    if not names then return nil end
    local sockets={}
    for _,socket in ipairs(record.Sockets) do
        local item=ctx.fs('fs_lstat',directory..'/'..socket.Name)
        if item then sockets[socket.Name]=item end
    end
    return {uid=uid,directory=stat,entries=names,sockets=sockets}
end
local function dead(source,owner_pid)
    if source then
        local ok,value=pcall(source.probe,owner_pid)
        return ok and type(value)=='table' and value.kind=='dead'
    end
    local ok,value,err=pcall(uv.kill,owner_pid,0)
    return ok and not value and type(err)=='string' and err:match('^ESRCH')~=nil
end
local function exact_directory(ctx,entry)
    local stat=ctx.fs('fs_lstat',entry.directory)
    return private(stat) and same(stat,entry.facts.directory)
end
local function remove_entry(ctx,entry,plan,confirm_dead)
    local confirmed=false
    local function confirm()
        if confirmed or not confirm_dead then return true end
        confirmed=confirm_dead()
        return confirmed
    end
    if not exact_directory(ctx,entry) or not witness_matches(ctx,entry.directory,entry.witness) then return false end
    for _,name in ipairs(plan.sockets) do
        local path=entry.directory..'/'..name
        local current=ctx.fs('fs_lstat',path)
        if not same(current,entry.facts.sockets[name]) or current.uid~=uid then return false end
        if not confirm() then return false end
        need(ctx.fs('fs_unlink',path))
    end
    if not exact_directory(ctx,entry) or not witness_matches(ctx,entry.directory,entry.witness) then return false end
    if not confirm() then return false end
    need(ctx.fs('fs_unlink',entry.directory..'/owner.json'))
    if not exact_directory(ctx,entry) then return false end
    return ctx.fs('fs_rmdir',entry.directory) and true or false
end

-- Neovim serverstop unlinks its configured pathname even after replacement.
-- Do not yield between this exact-inode preflight and ending kernel lifetime.
-- A foreign replacement is retained; the private listener then dies at exit.
local function stop_owned(resource,path)
    local expected=resource.listeners[path]
    if not expected then return true end
    local directory=uv.fs_lstat(resource.directory)
    local current=uv.fs_lstat(path)
    if not private(directory) or not same(directory,resource.stat)
        or (current and (current.uid~=uid or not same(current,expected))) then
        return nil,'listener pathname replaced'
    end
    local ok,result=pcall(vim.fn.serverstop,path)
    if not ok or result==0 then return nil,'cannot stop owned listener' end
    resource.listeners[path]=nil
    return true
end

local function resource_methods(resource)
    resource.listeners={}
    function resource.listen(name,callback)
        local started
        return transaction(2000,callback,function(ctx)
            need(not resource.closed,'runtime closed')
            need(type(name)=='string' and name:match('^s[1-9]%d*$') and tonumber(name:sub(2))<=256,'invalid socket name')
            local path=resource.directory..'/'..name
            need(#path<=103,'Unix socket path is too long')
            ctx.lock(resource.parent)
            need(private(ctx.fs('fs_lstat',resource.parent)),'unsafe runtime parent')
            need(same(ctx.fs('fs_lstat',resource.directory),resource.stat),'runtime directory changed')
            need(witness_matches(ctx,resource.directory,resource.witness),'ownership marker changed')
            local record=vim.deepcopy(resource.record)
            for _,socket in ipairs(record.Sockets) do need(socket.Name~=name,'duplicate socket name') end
            need(#record.Sockets<256,'socket capacity 256')
            need(not ctx.fs('fs_lstat',path),'socket path already exists')
            record.Sockets[#record.Sockets+1]={Name=name,State='reserved'}
            write_marker(ctx,resource,record)
            ctx.check()
            local ok,value=pcall(vim.fn.serverstart,path)
            need(ok and value==path,'cannot start private listener')
            resource.listeners[path]={};started=path
            ctx.finally=function(result)
                if result.kind~='listening' and started then stop_owned(resource,started) end
            end
            local stat=need(uv.fs_lstat(path),'listener socket missing')
            need(stat.type=='socket' and stat.uid==uid,'unproven listener socket')
            resource.listeners[path]=stat
            ctx.check()
            record=vim.deepcopy(resource.record)
            local socket=record.Sockets[#record.Sockets]
            socket.State,socket.Device,socket.Inode='listening',stat.dev,stat.ino
            write_marker(ctx,resource,record)
            ctx.check()
            -- Acquisition and first durable listener share one startup budget.
            -- Only a completed publication admits later per-operation budgets.
            resource.startup_deadline=nil
            return {kind='listening',path=path}
        end,resource.startup_deadline)
    end
    function resource.stop(name,callback)
        callback=callback or function() end
        local path=type(name)=='string' and resource.directory..'/'..name
        local stopped,stop_error=true,nil
        if path and resource.listeners[path] then stopped,stop_error=stop_owned(resource,path) end
        return transaction(2000,callback,function(ctx)
            need(type(name)=='string' and name:match('^s[1-9]%d*$') and tonumber(name:sub(2))<=256,'invalid socket name')
            need(stopped,stop_error)
            if resource.removed then return {kind='closed'} end
            ctx.lock(resource.parent)
            need(private(ctx.fs('fs_lstat',resource.parent)),'unsafe runtime parent')
            need(same(ctx.fs('fs_lstat',resource.directory),resource.stat),'runtime directory changed')
            need(witness_matches(ctx,resource.directory,resource.witness),'ownership marker changed')
            local record=vim.deepcopy(resource.record)
            local found
            for index,socket in ipairs(record.Sockets) do if socket.Name==name then found=index;break end end
            if not found then return {kind='closed'} end
            need(not ctx.fs('fs_lstat',path),'listener pathname replaced or retained')
            table.remove(record.Sockets,found)
            write_marker(ctx,resource,record)
            return {kind='closed'}
        end)
    end
    -- Kernel-only retirement for exit. Marker/directory cleanup remains with
    -- close's guarded transaction; this method creates no asynchronous work.
    function resource.stop_listeners()
        -- Only listeners returned by our own serverstart belong to us. Ending
        -- their kernel lifetime is safe even if another editor holds admission.
        local stop_error
        for path in pairs(resource.listeners) do local ok,err=stop_owned(resource,path);if not ok then stop_error=err end end
        resource.closed=true
        if stop_error then return nil,stop_error end
        return true
    end
    function resource.close(callback)
        callback=callback or function() end
        local stopped,stop_error=resource.stop_listeners()
        return transaction(2000,callback,function(ctx)
            need(stopped,stop_error)
            if resource.removed then return {kind='closed'} end
            ctx.lock(resource.parent)
            need(private(ctx.fs('fs_lstat',resource.parent)),'unsafe runtime parent')
            local record,witness=read_marker(ctx,resource.directory)
            if not record then
                if not ctx.fs('fs_lstat',resource.directory) then resource.removed=true;return {kind='closed'} end
                error('ownership marker unavailable',0)
            end
            need(witness.bytes==resource.witness.bytes and same(witness.stat,resource.witness.stat),'ownership marker changed')
            local observed=facts(ctx,resource.directory,record)
            need(observed and private(observed.directory) and same(observed.directory,resource.stat),'runtime directory changed')
            local names={}
            for _,socket in ipairs(record.Sockets) do names[socket.Name]=true end
            for _,name in ipairs(observed.entries) do need(name=='owner.json' or names[name],'unlisted runtime entry') end
            local present={}
            for name,stat in pairs(observed.sockets) do
                -- serverstop normally removes its own pathname. Any remaining
                -- declared socket must still match its recorded inode.
                local declared
                for _,socket in ipairs(record.Sockets) do if socket.Name==name then declared=socket end end
                need(stat.type=='socket' and stat.uid==uid and declared.State=='listening'
                    and stat.dev==declared.Device and stat.ino==declared.Inode,'replaced listener socket')
                present[#present+1]=name
            end
            need(remove_entry(ctx,{directory=resource.directory,facts=observed,witness=witness},{sockets=present}),'runtime cleanup retained')
            resource.removed=true
            return {kind='closed'}
        end)
    end
end

--- Physical system temporary parent, short enough for native Unix sockets.
--- One physical private parent, short even when TMPDIR cannot fit Unix sockets.
--- Test bootstrap replaces this IO selection without changing product policy.
function M.default_parent()
    local base=uv.fs_realpath('/tmp')
    return base and base..'/parley-rpc-'..uid
end

--- Acquire a unique private runtime under one bounded allocation transaction.
--- Callback receives ready/runtime or unavailable/error. Unknown residue counts
--- toward 256; explicit native death alone permits exact marked reclamation.
--- Inspection reserves one of its 256 distinct PID slots for this editor;
--- additional marker owners stay unknown, counted and retained.
function M.acquire(options,callback)
    options=options or {}
    local incarnation,source=options.incarnation,options.source
    local timeout=tonumber(options.timeout_ms) or 2000
    local parent=options.parent
    if not parent then parent=M.default_parent() end
    return transaction(timeout,callback,function(ctx)
        need(type(incarnation)=='string' and #incarnation==32 and incarnation:match('^[0-9a-f]+$'),'invalid editor incarnation')
        need(type(parent)=='string' and parent:sub(1,1)=='/' and not parent:find('\0',1,true),'invalid runtime parent')
        parent=vim.fs.normalize(parent)
        local stat=ctx.fs('fs_lstat',parent)
        if not stat then need(ctx.fs('fs_mkdir',parent,448));stat=ctx.fs('fs_lstat',parent) end
        need(private(stat),'unsafe runtime parent')
        need(ctx.fs('fs_realpath',parent)==parent,'runtime parent is not physical')
        ctx.lock(parent)
        need(same(stat,ctx.fs('fs_lstat',parent)),'runtime parent changed')
        local names=need(entries(ctx,parent,257),'runtime census exceeds bounded capacity 256')
        table.sort(names)
        local count,candidates,pids=0,{}, {pid}
        local selected={[pid]=true}
        for _,name in ipairs(names) do
            if name:match('^e%-') then
                count=count+1
                local directory=parent..'/'..name
                local directory_stat=ctx.fs('fs_lstat',directory)
                if private(directory_stat) then
                    local record,witness=read_marker(ctx,directory)
                    if record and record.Directory.Name==name then
                        local observed=facts(ctx,directory,record)
                        if observed then
                            candidates[#candidates+1]={directory=directory,record=record,witness=witness,facts=observed}
                            -- Own identity shares the 256-PID inspection cap.
                            -- Excess unique owners remain unknown and retained.
                            if not selected[record.PID] and #pids<256 then
                                pids[#pids+1]=record.PID;selected[record.PID]=true
                            end
                        end
                    end
                end
            end
        end
        need(count<=256,'runtime capacity 256 exceeded')
        local rows,status=ctx.observe(pids,source)
        need(status.kind=='complete','native process inspection unavailable')
        local own=rows[pid]
        need(own and own.kind=='alive','own process identity unavailable')
        for _,entry in ipairs(candidates) do
            entry.facts.process=rows[entry.record.PID]
            local plan=codec.cleanup(entry.record,entry.facts)
            if plan.kind=='reclaim' and exact_directory(ctx,entry)
                and witness_matches(ctx,entry.directory,entry.witness) then
                -- Observe already confirms ESRCH twice. This third check follows
                -- asynchronous facts/witness reads immediately before effects.
                if remove_entry(ctx,entry,plan,function() return dead(source,entry.record.PID) end) then count=count-1 end
            end
        end
        need(count<256,'runtime capacity 256 reached')
        ctx.check()
        local directory=need(ctx.fs('fs_mkdtemp',parent..'/e-XXXXXX'))
        local directory_stat=need(ctx.fs('fs_lstat',directory))
        need(private(directory_stat) and same(directory_stat,ctx.created_directory.stat),'unsafe new runtime directory')
        local resource={directory=directory,parent=parent,stat=directory_stat,startup_deadline=ctx.deadline}
        ctx.created_directory.resource=resource
        local record={Version=1,EditorIncarnation=incarnation,PID=pid,Started=own.started,
            Directory={Name=vim.fn.fnamemodify(directory,':t'),Device=directory_stat.dev,Inode=directory_stat.ino},Sockets={}}
        write_marker(ctx,resource,record)
        resource_methods(resource)
        return {kind='ready',runtime=resource}
    end)
end
return M
