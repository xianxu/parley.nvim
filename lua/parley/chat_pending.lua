-- Presentation only. The generation runner owns bytes, grants and completion.
local M={}
local Presentation=require('parley.chat_presentation')
local spinner=require('parley.progress').SPINNER
local namespace=vim.api.nvim_create_namespace('parley_chat_pending')
local groups={}
local version=0
local verbs = {
    "Baking",
    "Brewing",
    "Caramelizing",
    "Chopping",
    "Concocting",
    "Cooking",
    "Crafting",
    "Cultivating",
    "Fermenting",
    "Garnishing",
    "Kneading",
    "Marinating",
    "Mulling",
    "Noodling",
    "Percolating",
    "Puttering",
    "Seasoning",
    "Simmering",
    "Sketching",
    "Sprouting",
    "Steeping",
    "Stewing",
    "Tinkering",
    "Toasting",
    "Unfurling",
    "Whisking",
    "Working",
    "Zesting",
}

local function now()return (vim.uv or vim.loop).hrtime()/1000000 end
local function timer(delay,repeat_ms,callback)
    local handle=(vim.uv or vim.loop).new_timer();local closed=false
    handle:start(delay,repeat_ms,callback)
    return function()
        if closed then return end;closed=true
        handle:stop();if not handle:is_closing()then handle:close()end
    end
end
local default_scheduler={enqueue=vim.schedule,
    after=function(delay,callback)return timer(delay,0,callback)end,
    every=function(delay,callback)return timer(delay,delay,callback)end}
local function scalar(v)return type(v)=='string' and #v>0 and #v<=256
    or type(v)=='number' and v>=0 and v<math.huge and v%1==0 end
local function bump(group)version=version+1;group.version=version end
local function close_group(group)
    if group.unsubscribe then group.unsubscribe();group.unsubscribe=nil end
    if group.augroup then pcall(vim.api.nvim_del_augroup_by_id,group.augroup);group.augroup=nil end
    if groups[group.buf]==group then groups[group.buf]=nil end
end
local function retire_group(group)
    local sessions={};for _,s in pairs(group.sessions)do sessions[#sessions+1]=s end
    for _,s in ipairs(sessions)do s:cancel()end
end
local function group_for(buf)
    local group=groups[buf];if group then return group end
    group={buf=buf,sessions={}};groups[buf]=group;bump(group)
    group.augroup=vim.api.nvim_create_augroup('ParleyChatPending'..buf,{clear=true})
    vim.api.nvim_create_autocmd({'BufUnload','BufWipeout'},{group=group.augroup,buffer=buf,
        callback=function()retire_group(group)end})
    local Document=require('parley.document');local doc=Document.get(buf)
    if doc then group.unsubscribe=Document.subscribe(doc,function(event)
        if event.kind=='detach' or event.kind=='reload' then retire_group(group)end
    end)end
    return group
end
function M.start(opts)
    assert(type(opts)=='table' and vim.api.nvim_buf_is_valid(opts.buf),'valid buffer required')
    assert(scalar(opts.generation) and scalar(opts.entity),'generation and entity identities required')
    assert(type(opts.agent)=='string' and #opts.agent>0 and #opts.agent<=256,'agent display name required')
    assert(type(opts.alive)=='function' and type(opts.resolve_tip)=='function','presentation resolvers required')
    local group=groups[opts.buf];local count=0
    if group then
        assert(not group.sessions[opts.generation],'generation presentation already active')
        for _ in pairs(group.sessions)do count=count+1 end
    end
    assert(count<4,'presentation session limit')
    local scheduler=opts.scheduler or default_scheduler
    local clock=opts.clock or {now_ms=now}
    local choose=opts.choose_verb_index or function(n)return math.random(n)end
    local s={buf=opts.buf,generation=opts.generation,entity=opts.entity,agent=opts.agent,
        alive=opts.alive,resolve_tip=opts.resolve_tip,timers={},frame_index=2,detail_state={},finished=false}
    s.state=Presentation.initial({now_ms=clock.now_ms(),verbs=verbs,verb_index=choose(#verbs)})
    group=group_for(s.buf);group.sessions[s.generation]=s;bump(group)
    local function cancel_timer(name)
        local cancel=s.timers[name];s.timers[name]=nil;if cancel then pcall(cancel)end
    end
    local function hide()
        if s.extmark_id then pcall(vim.api.nvim_buf_del_extmark,s.buf,namespace,s.extmark_id);s.extmark_id=nil end
        s.visible_text=nil;s.playful_verb=nil
    end
    local function finish()
        if s.finished then return end;s.finished=true
        s.state=Presentation.transition(s.state,{type='complete'})
        cancel_timer('reveal');cancel_timer('frame');cancel_timer('idle');hide()
        s.pending=nil;s.detail_state={};s.alive=nil;s.resolve_tip=nil
        group.sessions[s.generation]=nil;bump(group)
        if not next(group.sessions)then close_group(group)end
    end
    local function valid()
        if s.finished or not vim.api.nvim_buf_is_valid(s.buf)then return false end
        local ok,alive=pcall(s.alive);return ok and alive==true
    end
    local function render(text)
        local ok,tip=pcall(s.resolve_tip)
        if not ok or type(tip)~='table' or type(tip.row)~='number' then finish();return end
        local success,mark=pcall(vim.api.nvim_buf_set_extmark,s.buf,namespace,tip.row,tip.col or 0,
            {id=s.extmark_id,virt_lines={{{text or '', 'Comment'}}},invalidate=true})
        if not success then finish();return end
        s.extmark_id=mark;s.visible_text=text;s.anchor_line=tip.row
    end
    local dispatch,submit
    local function after(name,delay,event)
        cancel_timer(name)
        s.timers[name]=scheduler.after(math.max(1,delay),function()
            scheduler.enqueue(function()if not s.finished then dispatch(event)end end)
        end)
    end
    local function frames()
        if not s.timers.frame then s.timers.frame=scheduler.every(120,function()submit({type='frame'})end)end
    end
    dispatch=function(event)
        if not valid()then finish();return end
        event.now_ms=clock.now_ms();event.verb_index=choose(#verbs)
        if event.type=='frame' then
            if s.playful_verb then s.frame_index=s.frame_index%#spinner+1;render(spinner[s.frame_index]..' '..s.playful_verb)end
            return
        end
        local actions;s.state,actions=Presentation.transition(s.state,event)
        for _,action in ipairs(actions)do
            if action.type=='hide' then hide()
            elseif action.type=='show_playful' then s.playful_verb=action.verb;render(spinner[s.frame_index]..' '..action.verb);if not s.finished then frames()end
            elseif action.type=='render_status' then cancel_timer('frame');render(action.message)end
        end
        if s.finished then return end
        if s.state.phase=='released' then cancel_timer('reveal');cancel_timer('frame');cancel_timer('idle')
        elseif event.type=='reveal_due' and s.state.phase=='waiting' then after('reveal',s.state.reveal_at-event.now_ms,{type='reveal_due'})
        elseif event.type=='activity' or event.type=='idle' then after('idle',s.state.verb_due_at-event.now_ms,{type='idle'})end
    end
    -- Coalesce UI updates while the main loop is busy. No chunk or completion
    -- callback is ever admitted into this bounded display slot.
    submit=function(event)
        if s.finished then return end
        if not s.pending or event.type=='progress' or s.pending.type~='progress' and event.type~='frame' then s.pending=event end
        if s.enqueued then return end;s.enqueued=true
        scheduler.enqueue(function()
            s.enqueued=false;local pending=s.pending;s.pending=nil
            if not s.finished and pending then dispatch(pending)end
        end)
    end
    function s.activity(_self)submit({type='activity'})end
    function s:progress(event)
        if self.finished then return end
        if type(event)~='table'then event={message=tostring(event or '')}end
        local message;self.detail_state,message=Presentation.progress_message(self.detail_state,event)
        submit({type='progress',message=type(message)=='string' and Presentation.bounded_message(message) or ''})
    end
    function s:written(row,col)
        if self.finished then return end
        self.pending=nil;self.anchor_line=row;self.anchor_col=col or 0
        self.state=Presentation.transition(self.state,{type='written'});hide()
        cancel_timer('reveal');cancel_timer('frame');cancel_timer('idle')
    end
    function s.complete(_self)finish()end
    function s.cancel(_self)finish()end
    function s.retire_stale_now(_self)finish()end
    local ok,err=pcall(function()
        after('reveal',1000,{type='reveal_due'});after('idle',15000,{type='idle'})
    end)
    if not ok then finish();error(err,0)end
    return s
end
function M.is_active(buf,generation)
    local g=groups[buf];return g~=nil and (generation==nil or g.sessions[generation]~=nil)
end
-- Copied display values. Compare version for membership identity; table
-- identity is deliberately not an authorization or stability contract.
function M.identity(buf,generation)
    local g=groups[buf];if not g then return nil end
    if generation~=nil then
        local s=g.sessions[generation];if not s then return nil end
        return {agent=s.agent,generation=s.generation,entity=s.entity,version=g.version,count=1}
    end
    local identities={}
    for _,s in pairs(g.sessions)do identities[#identities+1]={agent=s.agent,generation=s.generation,entity=s.entity}end
    table.sort(identities,function(a,b)return type(a.generation)..tostring(a.generation)<type(b.generation)..tostring(b.generation)end)
    return {count=#identities,identities=identities,version=g.version,agent=#identities==1 and identities[1].agent or nil}
end
function M.retire_stale_now(buf,_reason,generation)
    local g=groups[buf];if not g then return false end
    if generation then local s=g.sessions[generation];if not s then return false end;s:cancel()
    else retire_group(g)end
    return true
end
function M.cancel_all()
    local list={};for _,g in pairs(groups)do list[#list+1]=g end
    for _,g in ipairs(list)do retire_group(g)end
end
return M
