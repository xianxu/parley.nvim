-- Builtin adapters share pure validation/formatting with legacy handlers. IO is
-- yielded to captured services; no global runner replacement or cwd mutation.
local M = {}
local file_tools = {read_file=true,write_file=true,edit_file=true,propose_edits=true}
local write_tools = {write_file=true,edit_file=true,propose_edits=true}
local source = debug.getinfo(1, 'S').source:sub(2)
local help_root = source:match('^(.*)/lua/parley/tools/async_builtin%.lua$')
help_root = help_root and (vim.uv or vim.loop).fs_realpath(help_root)
local function result(name,content,failed)return {name=name,content=content,is_error=failed or false}end
local function await(method,...)
    local value=coroutine.yield({method=method,args={...}})
    if value.error_code or value.cancelled then error({outcome=value},0)end
    return value
end

local function file_body(name,input,context,refresh)
    local path=input.file_path or input.path
    if type(path)~='string' or path:sub(1,1)~='/'then return result(name,'missing or invalid required field: file_path',true)end
    local maximum=context.max_file_bytes or 1048576
    local invalid=require('parley.tools.file_transform').validate(name,input,maximum)
    if invalid then return result(name,invalid,true)end
    local prior
    if name=='write_file'then
        prior=await('stat',path)
        if prior.revision.exists then prior=await('read',path)
        else
            await('ensure_dir',{path=path:match('^(.*)/[^/]+$'),
                root=context.root_policy and context.root_policy.write_root or context.cwd})
        end
    else prior=await('read',path)end
    local content=prior.data or ''
    if name=='read_file'then
        local text,err,metadata=require('parley.tools.file_transform').numbered_read(input,content)
        local value=result(name,text or err,text==nil)
        for key,item in pairs(metadata or {})do value[key]=item end
        return value
    end
    local changed,message=require('parley.tools.file_transform').transform(name,input,content,path,maximum)
    if not changed then return result(name,message,true)end
    local backup
    if prior.revision.exists then
        for number=1,1024 do
            local candidate=path..'.parley-backup.'..number
            if not await('stat',candidate).revision.exists then backup=candidate;break end
        end
        if not backup then return result(name,'backup capacity exhausted',true)end
    end
    local outcome=await('write_checked',{path=path,content=changed,expected=prior.revision,backup_path=backup})
    local completion=require('parley.tools.file_refresh').complete(refresh,changed)
    outcome.evidence=outcome.evidence or {}
    outcome.evidence.reconciliation_required=completion.reconciliation_required
    return result(name,message),outcome
end

local function help_body(input,context)
    for key in pairs(input)do
        if key~='topic' and key~='offset' and key~='limit'then
            return result('parley_help','Only a help topic is accepted, not a file path',true)
        end
    end
    local root=context.help_root or help_root
    local function read(relative)
        local expected=root..'/'..relative
        if (vim.uv or vim.loop).fs_realpath(expected)~=expected then
            error({message='Bundled documentation is missing or redirected'},0)
        end
        local data=await('read',expected).data
        if #data>131072 then error({message='Invalid documentation size'},0)end
        return data
    end
    local catalog,problem=context.help_catalog
    if not catalog then catalog,problem=require('parley.help_content').parse(read('README.md'),read('atlas/index.md'))end
    if not catalog then return result('parley_help',problem,true)end
    if input.topic==nil or input.topic==''then return result('parley_help',table.concat(catalog.topics,'\n'))end
    if type(input.topic)~='string' or not catalog.paths[input.topic]then
        return result('parley_help','Unknown help topic; call parley_help without a topic to list topics',true)
    end
    return result('parley_help','    '..read(catalog.paths[input.topic]):gsub('\n','\n    '))
end


local function execute(definition,input,context,done)
    input=vim.deepcopy(input or {})
    local captured={};for key,value in pairs(context or {})do
        captured[key]=type(value)=='table' and key~='filesystem' and key~='tasker' and key~='authority' and vim.deepcopy(value) or value
    end
    context=captured
    local fs=context.filesystem or require('parley.tools.filesystem').new({max_bytes=context.max_file_bytes or 1048576})
    if context.authority then fs=fs:authorized(context.authority)end
    local tasker=context.tasker or require('parley.tasker')
    local refresh=write_tools[definition.name] and type(input.file_path or input.path)=='string'
        and require('parley.tools.file_refresh').capture(input.file_path or input.path,context.deferred_refresh_buf) or nil
    local cancelled,finished=false,false
    local active,sequence=nil,0
    local process_bytes=0
    local process_formatted_bytes,process_truncated=0,false
    local had_effect=false
    local last={certainty='unknown',effect='not_applied',physical_resolved=false}
    local handle={}
    local function publish(value)
        if value.effect=='applied' or value.effect=='partial'then had_effect=true end
        if had_effect and value.effect=='not_applied'then value.effect='partial'end
        if refresh and value.effect~='not_applied' and require('parley.tools.file_refresh').pending(refresh)then
            value.evidence=value.evidence or {};value.evidence.reconciliation_required=true
        end
        if value.result and value.evidence and value.evidence.backup_confirmed and value.evidence.backup_path then
            value.result.content=value.result.content..'\npre-image: '..value.evidence.backup_path
        end
        last=value;if value.certainty=='known' and value.physical_resolved then
            finished=true;active=nil
            if refresh then require('parley.tools.file_refresh').release(refresh);refresh=nil end
        end
        pcall(done,vim.deepcopy(value))
    end
    local function failure(value)
        value=value or {};value.result=value.result or result(definition.name,
            value.error_code or (cancelled and 'tool cancelled' or 'tool execution failed'),true)
        publish(value)
    end
    local function terminal(value,evidence)
        if process_truncated then value.truncated=true end
        evidence=evidence or {}
        publish({certainty='known',effect=evidence.effect or (had_effect and (value.is_error and 'partial' or 'applied') or 'not_applied'),physical_resolved=true,
            result=value,evidence=evidence.evidence})
    end
    local execution={chat_roots=context.chat_roots or {},root_policy=context.root_policy}
    execution.run=function(command)
        if not context.authority then
            local observed=await('process',command)
            return observed.data,observed.code
        end
        local scope=require('parley.tools.process_scope')
        local plans,problem=scope.plan(command)
        if not plans then error({message=problem},0)end
        local outputs,code={},nil
        for _,plan in ipairs(plans)do
            -- The pinned target is the final search/ls operand; find keeps it
            -- as operand two.
            plan.target_position=plan.command[1]=='find' and 2 or #plan.command
            local observed=await('process',plan.command,plan)
            local remaining=math.max(0,(context.max_bytes or 1048576)-process_formatted_bytes)
            local separator=#outputs>0 and remaining>0 and '\n' or ''
            local rendered,truncated=scope.restore(observed.data or '',plan.path,plan.command[1],remaining-#separator)
            outputs[#outputs+1]=separator..rendered
            process_formatted_bytes=process_formatted_bytes+#separator+#rendered
            process_truncated=process_truncated or truncated
            code=scope.join_code(code,observed.code)
        end
        return table.concat(outputs),code
    end
    local thread=coroutine.create(function()
        if file_tools[definition.name]then return file_body(definition.name,input,context,refresh)end
        if definition.name=='parley_help'then return help_body(input,context)end
        return definition.handler(input,execution)
    end)
    local resume
    resume=function(value)
        if finished then return end
        if cancelled then terminal(result(definition.name,'tool cancelled',true),value);return end
        local ok,request,evidence=coroutine.resume(thread,value)
        if not ok then
            local outcome=type(request)=='table' and request.outcome
            if outcome then failure(outcome)
            else terminal(result(definition.name,type(request)=='table' and request.message or 'tool formatter failed',true),value)end
            return
        end
        if coroutine.status(thread)=='dead'then terminal(request,evidence);return end
        sequence=sequence+1;local ticket={};active=ticket
        local function observed(outcome)
            if active~=ticket or finished then return end
            if outcome.certainty~='known' or not outcome.physical_resolved then failure(outcome);return end
            if outcome.effect=='applied' or outcome.effect=='partial'then had_effect=true end
            active=nil;resume(outcome)
        end
        local ok_launch,child=pcall(function()
            if request.method=='process'then
                local command=request.args[1]
                local process_cwd=context.cwd
                if request.args[2]then
                    local wrapped,problem=require('parley.tools.process_bootstrap').command(request.args[2],context.authority)
                    if not wrapped then
                        observed({certainty='known',effect='not_applied',physical_resolved=true,error_code=problem})
                        return {}
                    end
                    command=wrapped;process_cwd='/'
                end
                local args={};for i=2,#command do args[#args+1]=command[i]end
                local remaining=(context.max_bytes or 1048576)-process_bytes
                if remaining<2 then
                    observed({certainty='known',effect='not_applied',physical_resolved=true,error_code='aggregate process output capacity'})
                    return {}
                end
                local stderr_limit=math.min(65536,math.max(1,math.floor(remaining/8)))
                local marker=request.args[2] and require('parley.tools.process_scope').exec_marker or ''
                local id=tostring(context.operation_id)..':process:'..sequence
                local launched=tasker.run(context.buf,command[1],args,function(code,signal,out,err,io_error)
                    if marker~=''then
                        -- io_error is tasker's diagnosis (a kill, a pipe error) and
                        -- is kept: a process killed before its bootstrap wrote the
                        -- marker was killed, not a failed bootstrap (#261 M3 review).
                        if err:sub(1,#marker)~=marker then
                            io_error=io_error or 'scoped process bootstrap failed'
                        else err=err:sub(#marker+1)end
                    end
                    process_bytes=process_bytes+#out+#err
                    observed({certainty='known',effect='applied',physical_resolved=true,data=out..err,
                        code=code,error_code=io_error or signal~=0 and 'process terminated' or nil})
                end,nil,nil,function()
                    observed({certainty='known',effect='not_applied',physical_resolved=true,error_code='process launch failed'})
                end,{cwd=process_cwd,kind='tool',attempt_id=id,admission_key=id,
                    generation_id=context.generation_id,logical_generation=context.logical_generation,
                    stdout_limit=remaining-stderr_limit,stderr_limit=stderr_limit+#marker,
                    on_unresolved=function()observed({certainty='unknown',effect='not_applied',physical_resolved=false,
                        error_code='process cleanup unresolved'})end})
                return {cancel=function()if launched then pcall(tasker.stop_attempt,launched)end end,
                    reconcile=function()tasker.reconcile_step()end}
            end
            return fs[request.method](fs,unpack(request.args),observed)
        end)
        if active==ticket then
            if ok_launch and child then
                ticket.handle=child
                if cancelled and child.cancel then pcall(child.cancel,child)end
            else failure({certainty='unknown',effect='unknown',physical_resolved=false,error_code='IO submission unresolved'})end
        end
    end
    function handle.cancel(_)
        if finished then return end;cancelled=true
        if active then if active.handle and active.handle.cancel then pcall(active.handle.cancel,active.handle)end
        else terminal(result(definition.name,'tool cancelled',true))end
    end
    function handle:reconcile()
        if active and active.handle and active.handle.reconcile then pcall(active.handle.reconcile,active.handle)end
        return self:snapshot()
    end
    function handle.snapshot(_)return vim.deepcopy(last)end
    vim.schedule(function()resume()end)
    return handle
end

function M.bind(definition)
    local frozen={name=definition.name,handler=definition.handler}
    definition.execute_async=function(input,context,done)return execute(frozen,input,context,done)end
    definition.resources=function(input,context)
        input=input or {};context=context or {}
        local name=frozen.name
        if name=='emit_definition'then return {}end
        if name=='parley_help'then return {{path=context.help_root or help_root,scope='subtree',mode='read'}}end
        local paths=name=='chat_history_search' and context.chat_roots or input.paths
        if not paths then paths={input.file_path or input.path or context.cwd}end
        local out={}
        for _,value in ipairs(paths or {})do
            local path=type(value)=='table' and value.dir or value
            if write_tools[name]then
                -- Numbered backup selection and target write share one exclusive
                -- parent claim, including candidates not yet present on disk.
                local ancestor=name=='write_file' and context.root_policy and context.root_policy.write_root
                    or path:match('^(.*)/[^/]+$') or '/'
                out[#out+1]={path=ancestor,scope='subtree',mode='write'}
            else out[#out+1]={path=path,scope=file_tools[name] and 'file' or 'subtree',mode='read'}end
        end
        return out
    end
    return definition
end
return M
