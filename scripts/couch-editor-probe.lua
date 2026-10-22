-- luacheck: globals vim
-- Offline endpoint conformance. The Python driver owns all roots and selects
-- one candidate producer; embedded editors exercise the actual frontend.
vim.opt.runtimepath:prepend(assert(vim.env.PARLEY_CONFORMANCE_ROOT))
local config=vim.json.decode(table.concat(vim.fn.readfile(assert(vim.env.PARLEY_REGISTRY_PROBE)),'\n'))
local registry=require('parley.document_registry')
local embedded=require('tests.helpers.embedded_nvim')
local children={}
local client_options={binary=config.binary,env=config.env,timeout_ms=3000}
local function check(condition,message)
    if not condition then error('editor endpoint conformance: '..message,0) end
end
local function await(operation)
    local result
    operation(function(value) result=value end)
    check(vim.wait(10000,function() return result~=nil end,10),'client operation timed out')
    return result
end
local function editor(operation,payload)
    -- Producer-native work has its own lifetime: losing its CLI response can
    -- still mean published. Only confirmed authority or lookup-null is proof.
    return await(function(callback)
        registry.editor(operation,payload,{probe=true},callback,client_options)
    end)
end
local function confirmed(reply,where)
    check(reply.kind=='confirmed',where..': expected confirmed, got '..vim.inspect(reply))
    return reply.binding
end
local function query(context)
    return {Namespace=context.Namespace,DocumentID=context.DocumentID,
        EditorIncarnation=context.EditorIncarnation,AttachID=context.AttachID,Buffer=context.Buffer}
end
local function register_payload(context)
    local payload=vim.deepcopy(context)
    payload.File=nil;payload.Version=1
    return payload
end
local function unregister_payload(binding)
    return {Version=1,Namespace=binding.Namespace,PID=binding.PID,EditorIncarnation=binding.EditorIncarnation,
        Entries={{DocumentID=binding.DocumentID,AttachID=binding.AttachID,BindingGeneration=binding.BindingGeneration}}}
end
local function binding_matches(left,right)
    for _,field in ipairs({'Namespace','DocumentID','EditorIncarnation','AttachID','PID','Socket',
        'Buffer','Mode','File','ProcessIdentity','BindingGeneration'}) do
        if left[field]~=right[field] then return false end
    end
    return true
end
local function attach(identity)
    local child=embedded.start({rtp='prepend'})
    children[#children+1]=child
    child:exec([[local identity,options=...;vim.o.swapfile=false
        _G.probe_buffer=vim.fn.bufadd(identity.File);vim.fn.bufload(_G.probe_buffer)
        require('parley.remote_session').attach(_G.probe_buffer,identity,function(value) _G.probe_reply=value end,options)
    ]],identity,{runtime={parent=config.runtime_parent},client=client_options})
    check(child:exec([[return vim.wait(10000,function() return _G.probe_reply~=nil end,10)]]),'frontend attach timed out')
    local reply=child:exec('return _G.probe_reply')
    confirmed(reply,'native frontend attach')
    local state=child:exec('return require("parley.remote_session").snapshot(_G.probe_buffer)')
    check(state.phase=='active','confirmed frontend did not activate')
    check(child:exec('return not vim.bo[_G.probe_buffer].modified and vim.bo[_G.probe_buffer].modifiable'),
        'endpoint publication altered local editing')
    return child,state
end
local function endpoint(child,context,published_socket)
    if not published_socket then
        return child:exec('return require("parley.remote_session").endpoint(...)',query(context))
    end
    local channel=vim.fn.sockconnect('pipe',published_socket,{rpc=true})
    check(channel>0,'published private socket refused connection')
    -- Reuse the helper's bounded request implementation on this actual socket;
    -- channel closure is separate from the editor's control-channel lifetime.
    local connected=setmetatable({channel=channel,pid=child.pid},getmetatable(child))
    local ok,result=pcall(connected.exec,connected,'return require("parley.remote_session").endpoint(...)',query(context))
    pcall(vim.fn.chanclose,channel)
    check(ok,'published native handshake failed: '..tostring(result))
    return result
end
local function absent_endpoint(value) return value==nil or value==vim.NIL end
local function close_child(child)
    child:exec([[require('parley.remote_session').close(function() _G.probe_closed=true end)]])
    check(child:exec([[return vim.wait(10000,function() return _G.probe_closed==true end,10)]]),'frontend close timed out')
end
local function main()
    local path=config.root..'/endpoint.md'
    vim.fn.writefile({'# Disposable endpoint conformance'},path)
    local registered=await(function(callback)
        registry.request('register',{path,'pair:5'},{probe=true},callback,client_options)
    end)
    check(registered.kind=='registered','document registration failed: '..vim.inspect(registered))
    local identity=registered.registration
    check(type(identity.Namespace)=='string' and identity.Namespace:sub(1,1)=='/','registration omitted canonical Namespace')
    check(identity.File==path,'registered document path changed')
    local lookup={Namespace=identity.Namespace,DocumentID=identity.ID}
    local first,old=attach(identity)
    local old_binding=confirmed(editor('lookup',lookup),'first authority lookup')
    check(binding_matches(old_binding,old.binding),'first binding differs from frontend snapshot')
    local handshake=endpoint(first,old.context,old_binding.Socket)
    check(type(handshake)=='table' and handshake.PID==first.pid and handshake.File==path
        and handshake.Socket==old_binding.Socket,'actual private socket handshake mismatch')
    local retry=confirmed(editor('register',register_payload(old.context)),'same-attach retry')
    check(binding_matches(retry,old_binding),'same-attach retry changed authority or generation')

    local second,current=attach(identity)
    local successor=confirmed(editor('lookup',lookup),'takeover authority lookup')
    check(binding_matches(successor,current.binding),'desktop takeover did not publish the second editor')
    check(successor.PID==second.pid and successor.EditorIncarnation~=old_binding.EditorIncarnation
        and successor.BindingGeneration~=old_binding.BindingGeneration,'takeover reused old ownership')
    local active=endpoint(second,current.context,successor.Socket)
    check(type(active)=='table' and active.PID==second.pid,'successor handshake mismatch')
    if not config.fake then
        check(first:exec([[return vim.wait(5000,function()
            local state=require('parley.remote_session').snapshot(_G.probe_buffer)
            return state and state.phase=='superseded'
        end,10)]]),'producer did not deliver the exact supersession notice')
        check(absent_endpoint(endpoint(first,old.context)),'superseded old attachment still answers its exact query')
    end
    local stale=editor('register',register_payload(old.context))
    check(stale.kind=='refused' and (stale.code=='superseded' or stale.code=='stale'),
        'old snapshot reclaimed authority: '..vim.inspect(stale))
    local cleanup=editor('unregister',unregister_payload(old_binding))
    confirmed(cleanup,'stale exact unregister')
    check(cleanup.results[1].Status=='stale','old unregister was not fenced as stale')
    check(binding_matches(confirmed(editor('lookup',lookup),'post-stale authority lookup'),successor),
        'old unregister erased its successor')

    first:exec('require("parley.remote_session").detach(_G.probe_buffer)')
    check(absent_endpoint(endpoint(first,old.context)),'detached old attachment still answers')
    close_child(first)
    check(binding_matches(confirmed(editor('lookup',lookup),'post-old-detach authority lookup'),successor),
        'old frontend detach erased its successor')
    second:exec('require("parley.remote_session").detach(_G.probe_buffer)')
    check(absent_endpoint(endpoint(second,current.context)),'detached current attachment still answers')
    close_child(second)
    check(editor('lookup',lookup).kind=='absent','owned detach did not retire the current binding')
    check(vim.deep_equal(vim.fn.readfile(path),{'# Disposable endpoint conformance'}),'endpoint flow changed document content')
    print('PASS: native frontend/private-socket/register/same-attach-retry/desktop-takeover/stale-register/stale-unregister/detach/lookup-retirement'
        ..(config.fake and ' (fake client/authority controls; producer native handshake and advisory notification unqualified)'
            or '/producer-native-handshake/exact-supersession-notice'))
end
local ok,err=pcall(main)
for _,child in ipairs(children) do
    pcall(close_child,child)
    child:stop()
end
registry.shutdown()
if not ok then
    io.stderr:write(tostring(err)..'\n')
    vim.cmd('cquit 1')
else vim.cmd('qa!') end
