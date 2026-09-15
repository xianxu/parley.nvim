-- Pure bounded semantic repair. Call before_splice/after_splice around TEXT
-- edits; lexical materialization and semantic projection are not text edits.
local S=require('parley.document.sequence')
local G=require('parley.document.grammar')
local F=require('parley.document.facts')
local D=require('parley.document.dependencies')
local M={}
local workers=setmetatable({},{__mode='k'})
local evidence_store=setmetatable({},{__mode='k'})

local function state(worker) return assert(workers[worker],'invalid semantic worker') end
local function copy(value) local out={}; for k,v in pairs(value or {}) do out[k]=v end; return out end
local function finite_budget(value,name)
    assert(type(value)=='number' and value>=0 and value<math.huge and value%1==0,
        name..' must be a finite nonnegative integer')
    return value
end
local function dependencies(seq)
    return D.new({rank=function(handle) local p=S.rank(seq,handle); return p and p.row end})
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
                if not S.validate_certificate(w.seq,fact.certificate.range,{kind='syntax'}) then stale=true; break end
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
                    local now=work()
                    local dep_budget=math.min(128,math.floor((node_limit-now.nodes_visited-reserve.nodes*4)/(reserve.nodes*3)))
                    if dep_budget<1 then return budget() end
                    local added=w.deps:add(certificate.origin,certificate.last,{budget=dep_budget})
                    dep_visits=dep_visits+added.work.dependency_nodes_visited
                    if added.status~='ok' then return budget() end
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

function M.is_confirmed(worker,handle)
    local w=state(worker)
    local p=S.rank(w.seq,handle)
    if not p or p.rows==0 then return false end
    if not w.global_done and p.row>=position(w,w.global) then return false end
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

return M
