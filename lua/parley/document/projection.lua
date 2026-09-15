-- Derived semantic summaries live in the sequence, never in a consumer cache.
local M = {}
local S = require('parley.document.sequence')
local policy = require('parley.fold_projection')
local cursors = setmetatable({}, {__mode='k'})
local PROJECTION = {kind='projection'}
function M.empty() return {} end
function M.combine(a,b)
    local out={}
    for key,value in pairs(a) do if value then out[key]=true end end
    for key,value in pairs(b) do if value then out[key]=true end end
    return out
end
function M.summary(metadata)
    if not metadata or not metadata.confirmed or not metadata.semantic then return {unknown=true} end
    local sem,token=metadata.semantic,metadata.token or {}
    local before,after=metadata.section_before or {},metadata.section_after or {}
    local kind=sem.section_kind
    local start=sem.section_start or (kind and before.section~=kind)
    local finish=kind and (after.section~=kind or kind=='summary')
    -- Outline uses the legacy tilde/backtick toggle dialect, whose state is
    -- already published by grammar. Rendering has a different fence dialect.
    local outside=not (metadata.after or {}).memo_code
    local outline_chat=outside and (token.kind=='user' or token.kind=='branch' or token.preface_tag) or false
    return {
        exchange=sem.exchange_start or false,answer=sem.answer_start or false,
        answer_end=sem.answer_start or sem.exchange_start or sem.preface or sem.footer or sem.content_ended or false,
        section_start=start or false,section_end_after=finish or false,
        boundary=start or finish or sem.exchange_start or sem.answer_start or sem.preface
            or sem.footer or sem.content_ended or false,
        fold_start=kind and policy.is_foldable(kind) and start or false,
        nonblank=not token.blank,
        outline_chat=outline_chat,
        outline=outline_chat or outside and token.heading_level~=nil or false,
        diagnostic_definition=token.footnote or false,
        diagnostic_content=token.diagnostic_utc_candidate or token.diagnostic_reference_candidate or false,
    }
end
function M.find(seq,first,last,kind,opts)
    opts=opts or {}
    local saved=opts.cursor and cursors[opts.cursor]
    if opts.cursor and (not saved or saved.kind~='find' or saved.seq~=seq or saved.selector~=kind
        or saved.reverse~=(opts.reverse==true)) then return {status='stale',work={nodes_visited=0,entries_visited=0}} end
    local result=S.find(seq,first,last,{projection=true,reverse=opts.reverse,cursor=saved and saved.query,
        max_nodes=opts.budget_nodes or 2048,max_entries=opts.budget_entries or 4096,
        may_match=function(summary)return summary.unknown or summary[kind] end,
        matches=function(metadata)local summary=M.summary(metadata);return summary.unknown or summary[kind] end})
    if result.cursor then
        local token={}
        cursors[token]={kind='find',seq=seq,selector=kind,reverse=opts.reverse==true,query=result.cursor}
        result.cursor=token
    end
    if result.status=='found' and M.summary(result.span.metadata).unknown then result.status='opaque' end
    return result
end
local function work(seq,initial)
    local out=S.stats(seq)
    for key,value in pairs(out) do out[key]=value-(initial[key] or 0) end
    return out
end
local function output(ctx,result)
    result.work=work(ctx.seq,ctx.initial)
    return result
end
local function pause(ctx)
    local token={};cursors[token]=ctx.state
    return output(ctx,{status='budget',cursor=token,ranges=ctx.ranges,certificate=ctx.state.proof})
end
local function begin(seq,kind,first,last,opts)
    local ctx={seq=seq,initial=S.stats(seq),opts=opts or {},ranges={}}
    local reserve=S.navigation_budget(seq)
    if (ctx.opts.budget_nodes or 4096)<=reserve.nodes*2
        or (ctx.opts.budget_entries or 8192)<=reserve.entries*2 then
        return nil,{status='budget',cursor=ctx.opts.cursor,work=work(seq,ctx.initial),
            required={budget_nodes=reserve.nodes*2+1,budget_entries=reserve.entries*2+1}}
    end
    local state=ctx.opts.cursor and cursors[ctx.opts.cursor]
    if ctx.opts.cursor and (not state or state.seq~=seq or state.kind~=kind or state.first~=first or state.last~=last) then
        return nil,{status='stale',work=work(seq,ctx.initial)}
    end
    if state then
        if state.proof and not S.validate_certificate(seq,state.proof,PROJECTION) then
            return nil,{status='stale',work=work(seq,ctx.initial)}
        end
        local clone={};for k,v in pairs(state) do clone[k]=v end;state=clone
    else state={seq=seq,kind=kind,first=first,last=last,phase=kind=='exchange' and 'previous' or 'start'} end
    ctx.state=state
    return ctx
end
local function search(ctx,first,last,kind,reverse)
    local used=work(ctx.seq,ctx.initial)
    local reserve=S.navigation_budget(ctx.seq)
    local nodes=(ctx.opts.budget_nodes or 4096)-used.nodes_visited-reserve.nodes
    local entries=(ctx.opts.budget_entries or 8192)-used.entries_visited-reserve.entries
    if nodes<=reserve.nodes or entries<=reserve.entries then return {status='budget'} end
    local result=M.find(ctx.seq,first,last,kind,{reverse=reverse,cursor=ctx.state.query,
        budget_nodes=nodes,budget_entries=entries})
    ctx.state.query=result.status=='budget' and result.cursor or nil
    return result
end
local function ensure_proof(ctx)
    if ctx.state.proof then return true end
    local reserve=S.navigation_budget(ctx.seq)
    if (ctx.opts.budget_nodes or 4096)<=reserve.nodes*2
        or (ctx.opts.budget_entries or 8192)<=reserve.entries*2 then return false end
    ctx.state.proof=S.range_certificate(ctx.seq,ctx.state.first,ctx.state.last,PROJECTION)
    return ctx.state.proof~=nil
end
-- The exchange owning row; last is exclusive and includes its gap before the
-- next question. Identity is a stable semantic origin, never a numeric index.
function M.exchange(seq,row,opts)
    local total=S.size(seq).rows
    local ctx,err=begin(seq,'exchange',0,total,opts)
    if not ctx then return err end
    local state=ctx.state
    if state.row and state.row~=row then return output(ctx,{status='stale'}) end
    state.row=row
    while true do
        local previous=state.phase=='previous'
        local found=search(ctx,previous and 0 or state.origin_row+1,previous and math.min(row+1,total) or total,'exchange',previous)
        if found.status=='budget' then return pause(ctx) end
        if found.status=='opaque' or found.status=='stale' then return output(ctx,found) end
        if previous then
            if found.status=='not_found' then return output(ctx,{status='not_found'}) end
            state.origin,state.origin_row=found.span.handle,found.span.start_row;state.phase='next'
            state.proof=S.range_certificate(seq,state.origin_row,math.min(row+1,total),PROJECTION)
        else
            local last=found.span and found.span.start_row or total
            local proof=S.range_certificate(seq,state.origin_row,found.span and last+1 or total,PROJECTION)
            return output(ctx,{status='ready',identity=state.origin,first=state.origin_row,
                last=last,certificate=proof})
        end
    end
end
-- Each page contains at most eight copied ranges. Consumers must validate the
-- projection certificate before applying a page; unknown never authorizes clear.
function M.folds(seq,first,last,opts)
    local ctx,err=begin(seq,'folds',first,last,opts)
    if not ctx then return err end
    local state=ctx.state
    if not ensure_proof(ctx) then return pause(ctx) end
    state.next=state.next or first
    while #ctx.ranges<8 do
        local phase=state.phase
        local a,b,kind,reverse
        if phase=='start' then a,b,kind=state.next,last,'fold_start'
        elseif phase=='end' then a,b,kind=state.scan,last,'boundary'
        else a,b,kind,reverse=state.start,state.finish,'nonblank',true end
        local found=search(ctx,a,b,kind,reverse)
        if found.status=='budget' then return pause(ctx) end
        if found.status=='opaque' or found.status=='stale' then return output(ctx,found) end
        if phase=='start' then
            if found.status=='not_found' then return output(ctx,{status='ready',ranges=ctx.ranges,certificate=state.proof}) end
            state.start=found.span.start_row;state.fold_kind=found.span.metadata.semantic.section_kind
            local flags=M.summary(found.span.metadata)
            state.phase='end'
            -- The opener is itself a start boundary; only one-row/closing
            -- sections terminate there. All other searches begin after it.
            state.start_end=flags.section_end_after
            state.start_handle=found.span.handle
            if state.start_end then state.finish=state.start+1;state.phase='trim' else state.scan=state.start+1 end
        elseif phase=='end' then
            local flags=found.span and M.summary(found.span.metadata) or {}
            state.finish=found.span and (found.span.start_row+(flags.section_end_after and not flags.section_start and 1 or 0)) or last
            state.phase='trim'
        else
            if found.span then ctx.ranges[#ctx.ranges+1]={kind=state.fold_kind,start_0=state.start,end_0=found.span.start_row,identity=state.start_handle} end
            state.next=state.finish;state.phase='start'
        end
    end
    local result=pause(ctx);result.certificate=state.proof;return result
end
function M.validate(seq,certificate)return S.validate_certificate(seq,certificate,PROJECTION)end
return M
