-- Builtin adapters share pure validation/formatting with legacy handlers. IO is
-- yielded to captured services; no global runner replacement or cwd mutation.
local M = {}
local file_tools = {read_file=true,write_file=true,edit_file=true,propose_edits=true}
local write_tools = {write_file=true,edit_file=true,propose_edits=true}
local source = debug.getinfo(1, 'S').source:sub(2)
local help_root = source:match('^(.*)/lua/parley/tools/async_builtin%.lua$')
help_root = help_root and (vim.uv or vim.loop).fs_realpath(help_root)
local function result(name,content,failed)return {name=name,content=content,is_error=failed or false}end
local function integer(n)return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
local function inside(parent,path)return path==parent or path:sub(1,#parent+1)==parent..'/'end
local function await(method,...)
    local value=coroutine.yield({method=method,args={...}})
    if value.error_code or value.cancelled then error({outcome=value},0)end
    return value
end
local function lines(bytes)
    local out={};for line in (bytes..'\n'):gmatch('([^\n]*)\n')do out[#out+1]=line end
    if bytes:sub(-1)=='\n' then table.remove(out)end
    return out
end

local function transform(name,input,content,path,maximum)
    if name=='write_file' then
        if type(input.content)~='string' then return nil,'missing or invalid required field: content'end
        if #input.content>maximum then return nil,'file transformation exceeds size limit'end
        return input.content,'Written '..#input.content..' bytes to '..path
    end
    if name=='propose_edits'then
        if type(input.edits)~='table' or #input.edits==0 then return nil,'no edits provided'end
        if #input.edits>128 or #content*#input.edits>8388608 then return nil,'edit work capacity exceeded'end
        local bound=#content
        for _,edit in ipairs(input.edits)do
            if type(edit)~='table' or type(edit.new_string)~='string'then return nil,'invalid edit'end
            bound=bound+#edit.new_string
            if bound>maximum then return nil,'file transformation exceeds size limit'end
        end
        local changed=require('parley.skill_edits').compute_edits(content,input.edits)
        return changed.ok and changed.content or nil,changed.msg..(changed.ok and ' to '..path or '')
    end
    if input.insert_line~=nil and input.insert_text~=nil then
        if type(input.insert_line)~='number' or not integer(math.abs(input.insert_line)) or type(input.insert_text)~='string'then return nil,'invalid insert fields'end
        if #content+#input.insert_text+2>maximum then return nil,'file transformation exceeds size limit'end
        local old,added=lines(content),lines(input.insert_text)
        local at=math.max(0,math.min(input.insert_line,#old));local out={}
        for i=1,at do out[#out+1]=old[i]end
        for _,line in ipairs(added)do out[#out+1]=line end
        for i=at+1,#old do out[#out+1]=old[i]end
        return table.concat(out,'\n')..(content:sub(-1)=='\n' and '\n' or ''),
            'Inserted '..#added..' line(s) after line '..at..' in '..path
    end
    local old,new=input.old_string,input.new_string
    if type(old)~='string' or old=='' then return nil,'missing or invalid required field: old_string'end
    if type(new)~='string'then return nil,'missing or invalid required field: new_string'end
    local first=content:find(old,1,true)
    if not first then return nil,'old_string not found in '..path end
    if not input.replace_all and content:find(old,first+1,true)then
        return nil,'old_string is not unique in '..path..'. Use replace_all=true to replace all occurrences.'
    end
    local escaped=old:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])','%%%1')
    local count=1
    if input.replace_all then count=select(2,content:gsub(escaped,''))end
    if #content+count*(#new-#old)>maximum then return nil,'file transformation exceeds size limit'end
    local changed
    if input.replace_all then changed=content:gsub(escaped,(new:gsub('%%','%%%%')))
    else changed=content:sub(1,first-1)..new..content:sub(first+#old)end
    return changed,'Replaced '..count..' occurrence(s) in '..path
end

local function file_body(name,input,context)
    local path=input.file_path or input.path
    if type(path)~='string' or path:sub(1,1)~='/'then return result(name,'missing or invalid required field: file_path',true)end
    local maximum=context.max_file_bytes or 1048576
    local prior
    if name=='write_file'then
        if type(input.content)~='string' or #input.content>maximum then return result(name,'invalid or oversized content',true)end
        prior=await('stat',path)
        if prior.revision.exists then prior=await('read',path)
        else
            await('ensure_dir',{path=path:match('^(.*)/[^/]+$'),
                root=context.root_policy and context.root_policy.write_root or context.cwd,
                private_directory=context.private_directory})
        end
    else prior=await('read',path)end
    local content=prior.data or ''
    if (name=='read_file' or input.insert_line~=nil) and select(2,content:gsub('\n',''))>32768 then
        return result(name,'line transformation capacity exceeded',true)
    end
    if name=='read_file'then
        if content==''then return result(name,'')end
        local start=input.offset or input.line_start or 1
        local limit=input.limit or (input.line_end and input.line_end-start+1)
        if not integer(start) or start<1 or limit and not integer(limit)then return result(name,'invalid line range',true)end
        local out={};for index,line in ipairs(lines(content))do
            if index>=start and (not limit or #out<limit)then out[#out+1]=string.format('%5d  %s',index,line)end
        end
        return result(name,table.concat(out,'\n'))
    end
    local changed,message=transform(name,input,content,path,maximum)
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

-- Apply exclusions as argv before a traversal process can read private bytes.
-- rg/ack do not follow child symlinks. grep -r also leaves child symlinks alone.
local function private_argv(command,context)
    local private=context.private_directory
    if not private then return command end
    local out=vim.deepcopy(command);local program=out[1]
    if program=='rg'then
        local escaped=private:gsub('([%*%?%[%]{}!])', '\\%1')
        table.insert(out,2,'--glob');table.insert(out,3,'!**'..escaped..'/**')
    elseif program=='grep'then table.insert(out,2,'--exclude-dir='..private:match('[^/]+$'))
    elseif program=='ack'then table.insert(out,2,'--ignore-dir=is:'..private:match('[^/]+$'))
    elseif program=='find'then
        -- Existing builder starts with a single canonical root, followed by predicates.
        table.insert(out,3,'(');table.insert(out,4,'-path');table.insert(out,5,private)
        table.insert(out,6,'-prune');table.insert(out,7,')');table.insert(out,8,'-o')
        out[#out+1]='-print'
    elseif program=='ls'then
        for _,arg in ipairs(out)do
            if arg:sub(1,1)=='-' and arg:find('R',1,true) and inside(out[#out],private)then
                error({message='recursive listing overlaps private recovery storage'},0)
            end
        end
    end
    return out
end

local function execute(definition,input,context,done)
    input=vim.deepcopy(input or {})
    local captured={};for key,value in pairs(context or {})do
        captured[key]=type(value)=='table' and key~='filesystem' and key~='tasker' and vim.deepcopy(value) or value
    end
    context=captured
    local fs=context.filesystem or require('parley.tools.filesystem').new({max_bytes=context.max_file_bytes or 1048576})
    local tasker=context.tasker or require('parley.tasker')
    local cancelled,finished=false,false
    local active,sequence=nil,0
    local process_bytes=0
    local had_effect=false
    local last={certainty='unknown',effect='not_applied',physical_resolved=false}
    local handle={}
    local function publish(value)
        if value.effect=='applied' or value.effect=='partial'then had_effect=true end
        if had_effect and value.effect=='not_applied'then value.effect='partial'end
        if value.result and value.evidence and value.evidence.backup_confirmed and value.evidence.backup_path then
            value.result.content=value.result.content..'\npre-image: '..value.evidence.backup_path
        end
        last=value;if value.certainty=='known' and value.physical_resolved then finished=true;active=nil end
        pcall(done,vim.deepcopy(value))
    end
    local function failure(value)
        value=value or {};value.result=value.result or result(definition.name,
            value.error_code or (cancelled and 'tool cancelled' or 'tool execution failed'),true)
        publish(value)
    end
    local function terminal(value,evidence)
        evidence=evidence or {}
        publish({certainty='known',effect=evidence.effect or (had_effect and (value.is_error and 'partial' or 'applied') or 'not_applied'),physical_resolved=true,
            result=value,evidence=evidence.evidence})
    end
    local execution={chat_roots=context.chat_roots or {},root_policy=context.root_policy}
    execution.run=function(command)
        local observed=await('process',private_argv(command,context))
        return observed.data,observed.code
    end
    local thread=coroutine.create(function()
        if file_tools[definition.name]then return file_body(definition.name,input,context)end
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
                local command=request.args[1];local args={};for i=2,#command do args[#args+1]=command[i]end
                local remaining=(context.max_bytes or 1048576)-process_bytes
                if remaining<2 then
                    observed({certainty='known',effect='not_applied',physical_resolved=true,error_code='aggregate process output capacity'})
                    return {}
                end
                local stderr_limit=math.min(65536,math.max(1,math.floor(remaining/8)))
                local id=tostring(context.operation_id)..':process:'..sequence
                local launched=tasker.run(context.buf,command[1],args,function(code,signal,out,err,io_error)
                    process_bytes=process_bytes+#out+#err
                    observed({certainty='known',effect='applied',physical_resolved=true,data=out..err,
                        code=code,error_code=io_error or signal~=0 and 'process terminated' or nil})
                end,nil,nil,function()
                    observed({certainty='known',effect='not_applied',physical_resolved=true,error_code='process launch failed'})
                end,{cwd=context.cwd,kind='tool',attempt_id=id,admission_key=id,
                    generation_id=context.generation_id,logical_generation=context.logical_generation,
                    stdout_limit=remaining-stderr_limit,stderr_limit=stderr_limit,
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
