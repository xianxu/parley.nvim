-- Pure bounded semantic repair. Call before_splice/after_splice around TEXT
-- edits; lexical materialization and semantic projection are not text edits.
local S=require('parley.document.sequence')
local G=require('parley.document.grammar')
local F=require('parley.document.facts')
local D=require('parley.document.dependencies')
local M={}
local workers=setmetatable({},{__mode='k'})
local evidence_store=setmetatable({},{__mode='k'})
local fragment_store=setmetatable({},{__mode='k'})

local function state(worker) return assert(workers[worker],'invalid semantic worker') end
local function copy(value) local out={}; for k,v in pairs(value or {}) do out[k]=v end; return out end
local function finite_budget(value,name)
    assert(type(value)=='number' and value>=0 and value<math.huge and value%1==0,
        name..' must be a finite nonnegative integer')
    return value
end
local function dependencies(seq)
    return D.new({rank=function(handle,budget)
        local p,reason=S.rank(seq,handle,budget)
        return p and p.row,reason
    end})
end
local function position(w,job)
    local p=job.next and S.rank(w.seq,job.next)
    return p and p.row or job.row
end
local function seek(w,job,row)
    local span=S.at(w.seq,row)
    job.next=span and span.handle or S.eof(w.seq)
    job.row=row
    job.facts,job.fact_cursor,job.fact_need={},nil,nil
end
function M.new(seq)
    local worker={}
    local w={seq=seq,deps=dependencies(seq),queue={},serial=0}
    w.global={checkpoint=G.initial(),facts={},row=0}
    workers[worker]=w
    return worker
end

local function queue_answer(w,last)
    if not w.answer then return end
    local header=S.rank(w.seq,w.answer)
    local finish=S.rank(w.seq,last)
    if header and finish and header.row+1<finish.row then
        local job={checkpoint=G.initial_sections({['end']=last}),finish=last,header=w.answer,facts={}}
        job.scope_proof=S.range_certificate(w.seq,header.row,math.min(S.size(w.seq).rows,finish.row+1))
        seek(w,job,header.row+1)
        w.queue[#w.queue+1]=job
    end
    w.answer=nil
end

function M.step(worker,opts)
    local w=state(worker)
    opts=opts or {}
    local row_limit=math.min(finite_budget(opts.rows or 256,'rows'),256)
    local node_limit=finite_budget(opts.nodes or opts.budget_nodes or 32768,'nodes')
    local entry_limit=finite_budget(opts.entries or opts.budget_entries or 65536,'entries')
    local initial=S.stats(w.seq)
    local rows,dep_visits,deltas=0,0,{}
    local reserve=S.navigation_budget(w.seq)
    local function work()
        local out=S.stats(w.seq)
        for k,v in pairs(out) do out[k]=v-(initial[k] or 0) end
        out.rows_processed=rows; out.dependency_nodes_visited=dep_visits
        return out
    end
    local function finish(status,extra)
        local result=extra or {}; result.status=status; result.work=work(); result.deltas=deltas
        return result
    end
    local function budget()
        return finish('budget',{required={nodes=reserve.nodes*8+1,entries=reserve.entries*8+1}})
    end
    while rows<row_limit do
        local used=work()
        if node_limit-used.nodes_visited<=reserve.nodes*8
            or entry_limit-used.entries_visited<=reserve.entries*8 then return budget() end
        local job=w.queue[1] or w.global
        local sections=job~=w.global
        if not sections and w.global_done then return finish('idle') end
        local row=position(w,job)
        local last=sections and S.rank(w.seq,job.finish) or nil
        if sections and not last then
            table.remove(w.queue,1)
        elseif row>=(sections and last.row or S.size(w.seq).rows) then
            if sections then table.remove(w.queue,1)
            else
                queue_answer(w,S.eof(w.seq)); w.global_done=true
                if #w.queue==0 then return finish('idle') end
            end
        else
            local span=S.at(w.seq,row)
            if not span or span.opaque or not span.metadata or not span.metadata.token then
                job.next=nil; job.row=row
                return finish('opaque',{row=row})
            end
            local token=copy(span.metadata.token)
            token.provenance=span.handle
            -- Certificates remain private. Previously acquired facts can span
            -- calls; validate their exact inputs before reusing them.
            local stale=false
            for _,fact in pairs(job.facts) do
                if not F.validate(w.seq,fact.certificate) then stale=true; break end
            end
            if stale then job.facts={}; job.fact_cursor=nil; job.fact_need=nil end
            local result=(sections and G.advance_sections or G.advance)(job.checkpoint,token,job.facts)
            if result.need then
                local now=work()
                local answer=F.resolve(w.seq,span.handle,result.need,{
                    cursor=job.fact_need==result.need.kind and job.fact_cursor or nil,
                    budget_nodes=node_limit-now.nodes_visited-reserve.nodes*4,
                    budget_entries=entry_limit-now.entries_visited-reserve.entries*4,
                })
                if answer.status=='ready' then
                    job.facts[result.need.kind]=answer.fact
                    job.fact_cursor,job.fact_need=nil,nil
                elseif answer.status=='opaque' then return finish('opaque',{row=answer.row})
                elseif answer.status=='stale' then
                    job.facts,job.fact_cursor,job.fact_need={},nil,nil
                    return finish('more')
                else
                    job.fact_cursor,job.fact_need=answer.cursor,result.need.kind
                    return finish('budget',{required=answer.required})
                end
            else
                -- Reserve rank work for every dependency node the operation
                -- may visit. Exhaustion keeps a conservative extra dependency,
                -- never publishes a row lacking its required certificate.
                for _,certificate in ipairs(result.dependencies) do
                    for _,part in ipairs(F.dependencies(certificate)) do
                        local dep_budget=512-dep_visits
                        if dep_budget<1 then return budget() end
                        local added=w.deps:add(part.origin,part.last,{first=part.first,channels=part.channels,
                            budget=dep_budget,before_rank=function()
                                local current=work()
                                -- Reserve the remaining row publication work,
                                -- then admit each uncached adapter rank using
                                -- actual navigation already consumed this slice.
                                local nodes=node_limit-current.nodes_visited-reserve.nodes*4
                                local entries=entry_limit-current.entries_visited-reserve.entries*4
                                if nodes<=0 or entries<=0 then return false end
                                return {nodes=nodes,entries=entries}
                            end})
                        dep_visits=dep_visits+added.work.dependency_nodes_visited
                        if added.status~='ok' then return budget() end
                    end
                end
                local metadata=span.metadata
                if sections then
                    metadata.section_before=job.checkpoint
                    metadata.section_after=result.checkpoint
                    metadata.semantic.section_kind=result.section.kind
                    metadata.semantic.section_start=result.section.start or false
                    metadata.confirmed=true
                else
                    local sem=result.semantic
                    if sem.exchange_start or sem.answer_start or sem.footer or sem.content_ended then
                        queue_answer(w,sem.preface_origin or span.handle)
                    end
                    if sem.answer_start then w.answer=span.handle end
                    metadata.before,metadata.after=job.checkpoint,result.checkpoint
                    metadata.semantic,metadata.render_before=sem,result.render_before
                    metadata.answer_header=w.answer
                    metadata.section_before,metadata.section_after=nil,nil
                    metadata.confirmed=sem.role~='answer' or sem.answer_start or sem.preface or sem.header
                        or sem.footer or sem.content_ended or false
                end
                assert(S.project_many(w.seq,{{handle=span.handle,metadata=metadata}}))
                job.checkpoint=result.checkpoint
                rows=rows+1
                deltas[#deltas+1]={handle=span.handle,kind=sections and 'section' or 'global',events=result.events}
                seek(w,job,row+1)
                -- A newly bounded answer is repaired before reading another
                -- global row, so the pending scope queue never grows with N.
            end
        end
    end
    return finish('more')
end

-- Live snapshots below this frontier can use their copied confirmed flag.
-- Section repair changes that flag without moving the global frontier.
function M.confirmed_frontier(worker)
    local w=state(worker)
    return w.global_done and S.size(w.seq).rows or position(w,w.global)
end

function M.is_confirmed(worker,handle)
    local w=state(worker)
    local p=S.rank(w.seq,handle)
    if not p or p.rows==0 then return false end
    if p.row+p.rows>M.confirmed_frontier(worker) then return false end
    local row=S.at(w.seq,p.row)
    return row and row.metadata and row.metadata.confirmed==true or false
end
M.confirmed=M.is_confirmed

-- Query while old endpoint handles are live. If this cheap safety check runs
-- out of budget, discard the dependency root after the edit and repair from0.
-- This path never delays or rejects a human text edit.
function M.before_splice(worker,first,last,opts)
    local w=state(worker)
    opts=opts or {}
    local initial=S.stats(w.seq)
    local nodes,entries=opts.nodes or 32768,opts.entries or 65536
    local reserve=S.navigation_budget(w.seq)
    local dep_visits=0
    local function evidence(restart,checkpoint,exhausted)
        local token={status=exhausted and 'budget' or 'ready',restart_row=restart,budget_exhausted=exhausted or false}
        evidence_store[token]={worker=worker,restart=restart,checkpoint=checkpoint,serial=w.serial,fallback=exhausted,
            active_scope=not exhausted and w.queue[1] or nil}
        local work=S.stats(w.seq)
        for k,v in pairs(work) do work[k]=v-(initial[k] or 0) end
        work.dependency_nodes_visited=dep_visits
        token.work=work
        return token
    end
    if nodes<=reserve.nodes*8 or entries<=reserve.entries*8 then return evidence(0,G.initial(),true) end
    local dep_budget=math.min(128,math.floor((nodes-reserve.nodes*8)/(reserve.nodes*6)))
    if dep_budget<1 then return evidence(0,G.initial(),true) end
    local query=w.deps:restart_origin(first,last,{budget=dep_budget})
    dep_visits=dep_visits+query.work.dependency_nodes_visited
    if query.status~='ok' then return evidence(0,G.initial(),true) end
    local affected=query.origin and S.rank(w.seq,query.origin)
    local restart=math.min(first,affected and affected.row or first,position(w,w.global))
    local preceding=restart>0 and S.at(w.seq,restart-1) or nil
    if preceding and preceding.metadata and preceding.metadata.answer_header then
        local header=S.rank(w.seq,preceding.metadata.answer_header)
        if header then restart=math.min(restart,header.row) end
    end
    preceding=restart>0 and S.at(w.seq,restart-1) or nil
    local checkpoint=preceding and preceding.metadata and preceding.metadata.after or G.initial()
    if restart>0 and not (preceding and preceding.metadata and preceding.metadata.after) then restart=0; checkpoint=G.initial() end
    local origin=S.at(w.seq,restart)
    local removed=w.deps:remove_from(origin and origin.handle or S.eof(w.seq),{budget=dep_budget})
    dep_visits=dep_visits+removed.work.dependency_nodes_visited
    if removed.status~='ok' then return evidence(0,G.initial(),true) end
    return evidence(restart,checkpoint,false)
end

function M.after_splice(worker,token,first,newlast)
    local w=state(worker)
    local evidence=evidence_store[token]
    assert(evidence and evidence.worker==worker and evidence.serial==w.serial,'invalid splice evidence')
    evidence_store[token]=nil
    w.serial=w.serial+1
    if evidence.fallback then w.deps=dependencies(w.seq) end
    -- Preserve a disjoint in-flight scope, not global certainty. It can finish
    -- while the global frontier remains unresolved; the later global pass
    -- rebuilds dependency ownership before its section output becomes final.
    local active=evidence.active_scope
    w.queue=active and active.scope_proof and S.validate_certificate(w.seq,active.scope_proof) and {active} or {}
    w.answer=nil; w.global_done=false
    w.global={checkpoint=evidence.checkpoint,facts={},row=evidence.restart}
    seek(w,w.global,math.min(evidence.restart,S.size(w.seq).rows))
    return {status='more',restart_row=evidence.restart,first_row=first,last_row=newlast}
end

local PLAIN_FIELDS={kind=true,token=true,bytes=true,blank=true,divider=true,preface_tag=true,
    footnote=true,draft_open=true,draft_end=true,provenance=true,row=true,
    diagnostic_utc_candidate=true,diagnostic_reference_candidate=true}
local function plain_token(token)
    if type(token)~='table' or (token.kind~='text' and token.kind~='blank') then return false end
    if token.token~=(token.kind=='blank' and '_' or 't') or token.blank~=(token.kind=='blank') then return false end
    if token.divider or token.preface_tag or token.footnote or token.draft_open or token.draft_end then return false end
    for key,value in pairs(token) do
        if not PLAIN_FIELDS[key] or type(value)=='table' or type(value)=='function' then return false end
    end
    return true
end
local function references_removed(value,removed)
    if type(value)~='table' then return removed[value]==true end
    for _,item in pairs(value) do if references_removed(item,removed) then return true end end
    return false
end
local function fragment_work(seq,initial,rows,dependencies_visited)
    local out=S.stats(seq)
    for key,value in pairs(out) do out[key]=value-(initial[key] or 0) end
    out.rows_processed=rows or 0
    out.dependency_nodes_visited=dependencies_visited or 0
    return out
end

-- Preparation never changes the dependency index for a candidate local
-- transfer. A failed post-splice checkpoint comparison has an O(1) conservative
-- fallback already captured here; it does not need deleted endpoint handles.
function M.before_fragment(worker,first,last,new_spans,opts)
    local w=state(worker)
    opts=opts or {}
    local rows=math.min(finite_budget(opts.rows or 256,'rows'),256)
    local bytes=math.min(finite_budget(opts.bytes or 65536,'bytes'),65536)
    local nodes=finite_budget(opts.nodes or 65536,'nodes')
    local entries=finite_budget(opts.entries or 65536,'entries')
    local initial=S.stats(w.seq)
    local visits=0
    local function fallback()
        local used=fragment_work(w.seq,initial)
        local normal=M.before_splice(worker,first,last,{nodes=math.max(0,nodes-used.nodes_visited),
            entries=math.max(0,entries-used.entries_visited)})
        local token={status='fallback'}
        fragment_store[token]={worker=worker,normal=normal}
        token.work=fragment_work(w.seq,initial,0,visits+(normal.work.dependency_nodes_visited or 0))
        return token
    end
    local reserve=S.navigation_budget(w.seq)
    if nodes<=reserve.nodes*(#new_spans+8) or entries<=reserve.entries*8
        or last-first>rows or #new_spans>rows then return fallback() end
    local new_tokens,total_bytes={},0
    local changed={row=true}
    for i,span in ipairs(new_spans) do
        if span.rows~=1 or span.opaque or not span.metadata or not plain_token(span.metadata.token)
            or type(span.bytes)~='number' or span.bytes<0 or span.bytes%1~=0 then return fallback() end
        total_bytes=total_bytes+span.bytes
        if total_bytes>bytes then return fallback() end
        new_tokens[i]={token=copy(span.metadata.token),bytes=span.bytes}
        for channel in pairs(G.channels(span.metadata.token)) do changed[channel]=true end
    end
    local frontier=w.global_done and S.size(w.seq).rows or position(w,w.global)
    if last>frontier then return fallback() end
    local old=S.query(w.seq,first,last,{limit=257})
    local removed={}
    for _,span in ipairs(old) do
        if span.rows~=1 or span.opaque or not span.metadata or not span.metadata.confirmed
            or not plain_token(span.metadata.token) then return fallback() end
        removed[span.handle]=true
        for channel in pairs(G.channels(span.metadata.token)) do changed[channel]=true end
    end
    local left=first>0 and S.at(w.seq,first-1) or nil
    local right=S.at(w.seq,last)
    local incoming=old[1] and old[1].metadata or (right and right.metadata)
    local outgoing=old[#old] and old[#old].metadata
    local before=incoming and incoming.before or (left and left.metadata and left.metadata.after)
    local after=outgoing and outgoing.after or before
    if not before or not after or (before.role~='question' and before.role~='answer') then return fallback() end
    local section_before,section_after,header
    if before.role=='answer' then
        section_before=incoming and incoming.section_before or (left and left.metadata and left.metadata.section_after)
        section_after=outgoing and outgoing.section_after or section_before
        header=incoming and incoming.answer_header or (left and left.metadata and left.metadata.answer_header)
        if not section_before and first==last and left and left.metadata and left.metadata.semantic
            and left.metadata.semantic.answer_start then
            header=left.handle
            section_before=G.initial_sections({['end']=right and right.handle or S.eof(w.seq)})
            section_after=section_before
        end
        if not section_before or not section_after or not header or not S.rank(w.seq,header)
            or not section_before.scope_end or not S.rank(w.seq,section_before.scope_end) then return fallback() end
    end
    if references_removed(before,removed) or references_removed(after,removed)
        or references_removed(section_before,removed) or references_removed(section_after,removed) then return fallback() end
    local used=fragment_work(w.seq,initial)
    local dep_budget=math.min(256,math.floor((nodes-used.nodes_visited-reserve.nodes*4)/(reserve.nodes*3)))
    if dep_budget<1 then return fallback() end
    local affected=w.deps:restart_origin(first,last,{channels=changed,budget=dep_budget})
    visits=visits+affected.work.dependency_nodes_visited
    if affected.status~='ok' or affected.origin then return fallback() end
    local normal={status='budget',restart_row=0,budget_exhausted=true}
    evidence_store[normal]={worker=worker,restart=0,checkpoint=G.initial(),serial=w.serial,fallback=true}
    local active=w.queue[1]
    local active_valid=active and active.scope_proof and S.validate_certificate(w.seq,active.scope_proof)
    local token={status='local'}
    fragment_store[token]={worker=worker,serial=w.serial,normal=normal,first=first,last=last,new_tokens=new_tokens,
        before=before,after=after,section_before=section_before,section_after=section_after,header=header,
        left=left and left.handle,right=right and right.handle or S.eof(w.seq),removed=removed,
        global=w.global,global_checkpoint=w.global.checkpoint,global_next=w.global.next,
        active=active_valid and active or nil,nodes=nodes,entries=entries}
    token.work=fragment_work(w.seq,initial,0,visits)
    return token
end

function M.after_fragment(worker,token,first,newlast)
    local w=state(worker)
    local captured=fragment_store[token]
    assert(captured and captured.worker==worker,'invalid fragment evidence')
    fragment_store[token]=nil
    local initial=S.stats(w.seq)
    local function fallback()
        local result=M.after_splice(worker,captured.normal,first,newlast)
        result.work=fragment_work(w.seq,initial)
        return result
    end
    if token.status=='fallback' then return fallback() end
    if captured.serial~=w.serial or captured.first~=first or newlast-first~=#captured.new_tokens
        or captured.global~=w.global or captured.global_checkpoint~=w.global.checkpoint
        or captured.global_next~=w.global.next then return fallback() end
    local right=S.rank(w.seq,captured.right)
    local left=captured.left and S.rank(w.seq,captured.left)
    if not right or right.row~=newlast or (captured.left and (not left or left.row+left.rows~=first)) then return fallback() end
    local actual=S.query(w.seq,first,newlast,{limit=257})
    if #actual~=#captured.new_tokens then return fallback() end
    local checkpoint,section=captured.before,captured.section_before
    local updates,deltas={},{}
    for i,span in ipairs(actual) do
        local expected=captured.new_tokens[i]
        if span.rows~=1 or span.opaque or captured.removed[span.handle] or span.bytes~=expected.bytes
            or not span.metadata or not span.metadata.token or not G.same_token(span.metadata.token,expected.token) then return fallback() end
        local lexical=copy(span.metadata.token); lexical.provenance=span.handle
        local global=G.advance(checkpoint,lexical,{})
        if global.need or #global.dependencies>0 then return fallback() end
        local projected=section and G.advance_sections(section,lexical,{}) or nil
        if projected and (projected.need or #projected.dependencies>0) then return fallback() end
        local metadata=span.metadata
        metadata.before,metadata.after=checkpoint,global.checkpoint
        metadata.semantic,metadata.render_before=global.semantic,global.render_before
        metadata.answer_header=captured.header
        metadata.section_before=section
        metadata.section_after=projected and projected.checkpoint or nil
        if projected then
            metadata.semantic.section_kind=projected.section.kind
            metadata.semantic.section_start=projected.section.start or false
        end
        metadata.confirmed=true
        updates[#updates+1]={handle=span.handle,metadata=metadata}
        deltas[#deltas+1]={kind='fragment',handle=span.handle,events=global.events}
        checkpoint=global.checkpoint
        section=projected and projected.checkpoint or nil
    end
    if not G.same_checkpoint(checkpoint,captured.after)
        or (section and not G.same_checkpoint(section,captured.section_after)) then return fallback() end
    assert(S.project_many(w.seq,updates))
    if captured.active then
        local header=S.rank(w.seq,captured.active.header)
        local finish=S.rank(w.seq,captured.active.finish)
        if header and finish then
            captured.active.scope_proof=S.range_certificate(w.seq,header.row,math.min(S.size(w.seq).rows,finish.row+1))
        end
    end
    evidence_store[captured.normal]=nil
    w.serial=w.serial+1
    return {status='reused',deltas=deltas,work=fragment_work(w.seq,initial,#updates)}
end

return M
