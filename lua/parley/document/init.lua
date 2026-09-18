-- Buffer coordination only: text stays in the editor, indexed facts in
-- Structure, and write authority in State. Every callback observes State first.
local Editor=require('parley.document.editor')
local State=require('parley.document.state')
local Structure=require('parley.document.structure')
local Grammar=require('parley.document.grammar')
local Lexical=require('parley.document.lexical')
local Reader=require('parley.line_reader')
local User=require('parley.document.user_edits')
local Append=require('parley.document.append')
local Replacement=require('parley.document.replacement')
local M={}
local buffers={}
local documents=setmetatable({},{__mode='k'})
local next_epoch=0
local function epoch() next_epoch=next_epoch+1; return next_epoch end
local function state(doc) local s=documents[doc]; assert(s,'invalid document'); return s end
local function opaque(rows,bytes) return rows>0 and {{rows=rows,bytes=bytes,opaque=true}} or {} end
local function notify(s,event)
    for _,callback in pairs(s.subscribers) do callback(event) end
end
local function effects(s,result)
    if s.on_effect then for _,effect in ipairs(result.effects or {}) do s.on_effect(effect) end end
    return result
end
local function proof(s,grant)
    local result=Structure.authority_range(s.structure,grant.entity,grant.first,grant.last)
    if result.status=='stale' or result.status=='refused' then return nil end
    return {entity=grant.entity,marker_revision=1,revision=grant.revision,
        first=grant.first,last=grant.last,confirmed=result.status=='ready'}
end
local function reconcile(s,only_suspended)
    local proofs={}
    for gid,grant in pairs(State.snapshot(s.authority).grants) do
        if grant.status~='revoked' and not Replacement.owns(s,gid) and (not only_suspended or grant.status=='suspended') then
            proofs[gid]=proof(s,grant) or {entity=false}
        end
    end
    effects(s,State.transition(s.authority,{kind='reconcile',proofs=proofs}))
end
local function record(s,work)
    Reader.record_work(s.buf,{
        structure_rows_processed=work.rows_processed or 0,
        structure_entries_copied=work.entries_copied or 0,
        index_nodes_visited=work.nodes_visited or 0,
        index_entries_visited=work.entries_visited or 0,
        dependency_nodes_visited=work.dependency_nodes_visited or 0,
        metadata_values_copied=work.metadata_values_copied or 0,
        summary_values_copied=(work.summary_values_copied or 0)+(work.channel_values_copied or 0),
    })
end
local function measured_query(s,fn,...)
    local before=Structure.stats(s.structure)
    local a,b=fn(s.structure,...)
    local work=Structure.stats(s.structure)
    for key,value in pairs(work) do work[key]=value-(before[key] or 0) end
    record(s,work)
    return a,b
end
local function cancel_schedule(s)
    if s.work then s.work:cancel() end
end
local function schedule(doc)
    local s=state(doc)
    if s.dead or not s.scheduling then return end
    if not s.work then
        s.work=require('parley.deferred_work').new(function()
            if s.dead then return false end
            local start=(vim.uv or vim.loop).hrtime()
            repeat
                local result=M.repair_step(doc)
                if result.status=='idle' or result.status=='detached' or result.status=='mutation' then return false end
            until (vim.uv or vim.loop).hrtime()-start>=2000000
            return true
        end)
    end
    s.work:request()
end
local function preserve(s,old,token,event)
    if not old or old.opaque or not old.metadata or not old.metadata.token then return false end
    local prior=old.metadata.token
    if not Grammar.same_token(prior,token) then return false end
    if prior.kind=='text' or prior.kind=='blank' then return true end
    local prefix=s.patterns[prior.kind..'_prefix']
    -- Surviving literal marker bytes, not equivalent replacement text, preserve
    -- marker identity. Insertion at the prefix boundary remains conservative.
    return prefix~=nil and event.start.row==old.start_row and event.start.col>#prefix
end
local function accumulate_repair(work,result)
    for _,key in ipairs({'dependency_nodes_visited','rows_processed'}) do
        work[key]=work[key]+(result and result.work and result.work[key] or 0)
    end
    return result
end
local function observe_edit(doc,s,event)
    local successor,final_receipt=Replacement.observe(s,event)
    Reader.record_work(s.buf,{operation='source_guard_edit',source_guards_visited=User.observe(s.editor,event)})
    local before=Structure.stats(s.structure)
    local classified_rows,classified_bytes=0,0
    local repair_work={dependency_nodes_visited=0,rows_processed=0}
    if s.deferred then
        accumulate_repair(repair_work,Structure.cancel_deferred_fragment(s.structure));s.deferred=nil
    end
    effects(s,State.transition(s.authority,{kind='observed_edit',epoch=event.epoch,
        first=event.first,last=event.last,new_bytes=event.new_bytes,
        owner_grant=event.owner and event.owner.grant,successor=successor}))
    Replacement.prune(s)
    Append.prune(s.append,State.snapshot(s.authority).grants)
    local appended=Append.observe(s.append,s.structure,event)
    local first=math.min(event.start.row,event.old_rows)
    -- Prepared append spans include the surviving source tail row, even when
    -- a newline appended to an empty row looks like a whole-row insertion.
    local whole_rows=not appended and event.start.col==0 and event.old_end.col==0 and event.new_end.col==0
    local last=math.min(event.old_rows,event.old_end.row+(whole_rows and 0 or 1))
    local a=first<event.old_rows and Structure.at(s.structure,first) or nil
    if a and a.opaque then last=math.max(last,a.end_row) end
    local z=last>first and Structure.at(s.structure,last-1) or nil
    if a then first=a.start_row end
    if z then last=z.end_row end
    local first_byte=a and a.start_byte or event.old_total
    local last_byte=z and z.end_byte or first_byte
    local added=last-first+event.new_rows-event.old_rows
    local bytes=last_byte-first_byte+event.new_bytes-(event.last-event.first)
    local newlast=first+added
    local reused=false
    local diagnostic_changed=true
    -- Only the private cursor's final exact receipt may publish known small
    -- rows. Earlier/large slices stay opaque to avoid rereading a growing row.
    local classify_successor=successor and final_receipt and bytes<=4096
    local unchanged_eol=event.source_frame==true and event.owner and a and not a.opaque and last==first+1
        and event.first==event.last and event.first==a.end_byte-1
        and event.start.row==a.start_row and event.start.col==a.bytes-1
        and event.new_end.row>event.start.row
    if unchanged_eol then
        -- A zero-width insertion cannot alter the prefix. Native row offsets
        -- prove its first inserted byte is a newline without rereading a long
        -- question row. Only an exact owned callback reaches this check.
        unchanged_eol=s.editor.driver.offset(s.buf,first+1)-s.editor.driver.offset(s.buf,first)==a.bytes
    end
    if unchanged_eol and not appended and (successor and not classify_successor or bytes>65536 or added>256) then
        accumulate_repair(repair_work,Structure.splice(s.structure,first+1,last,opaque(added-1,bytes-a.bytes)))
    elseif (not successor or classify_successor) and event.source_frame==true and (appended or (added<=256 and last-first<=256 and bytes<=65536
        and not (a and a.opaque) and not (z and z.opaque))) then
        local lines=not appended and s.editor.reader:lines(first,newlast,false) or {}
        local spans=appended and appended.spans or {}; local actual=0
        if appended then for _,span in ipairs(spans) do actual=actual+span.bytes end end
        for i,line in ipairs(lines) do
            local _,token=Grammar.lex_step(Grammar.lex_start(s.patterns),line,true,{bytes=65536})
            spans[i]={rows=1,bytes=#line+1,metadata={token=token}}; actual=actual+#line+1
        end
        classified_rows,classified_bytes=#spans,appended and 0 or actual
        if actual==bytes and #spans==1 and last-first==1 and a and a.metadata then
            local old,new=a.metadata.token,spans[1].metadata.token
            diagnostic_changed=not old or old.footnote or old.diagnostic_utc_candidate
                or old.diagnostic_reference_candidate or new.footnote or new.diagnostic_utc_candidate
                or new.diagnostic_reference_candidate or false
        end
        -- Native undo can expose final text during an intermediate callback.
        -- Keep that callback's exact arithmetic extent opaque until delivery ends.
        if actual~=bytes or #spans~=added then
            local delayed
            if added==1 then
                delayed=accumulate_repair(repair_work,Structure.begin_deferred_fragment(s.structure,
                    first,last,added,bytes,{rows=256,bytes=65536,nodes=65536,entries=65536}))
            else delayed=accumulate_repair(repair_work,Structure.splice(s.structure,first,last,opaque(added,bytes))) end
            if delayed.status=='deferred' then s.deferred={first=first,last=newlast,bytes=bytes} end
        elseif last>first and spans[1] and a and preserve(s,a,spans[1].metadata.token,event) then
            -- Exact owned insertion of a newline at EOL leaves this original
            -- row's bytes untouched. Keep its text stamp as well as identity.
            -- External/ambiguous callbacks always advance the ordinary stamp.
            if not unchanged_eol then
                accumulate_repair(repair_work,Structure.replace_row(s.structure,first,spans[1].metadata.token,spans[1].bytes))
            end
            if last-first==1 and #spans==1 then reused=true
            else
                local tail={}; for i=2,#spans do tail[#tail+1]=spans[i] end
                reused=accumulate_repair(repair_work,Structure.replace_fragment(s.structure,first+1,last,tail,
                    {rows=256,bytes=65536,nodes=65536,entries=65536})).reused_suffix
            end
        else
            reused=accumulate_repair(repair_work,Structure.replace_fragment(s.structure,first,last,spans,
                {rows=256,bytes=65536,nodes=65536,entries=65536})).reused_suffix
        end
    elseif not successor and added==1 and last-first<=256 and bytes<=65536 and not (a and a.opaque) and not (z and z.opaque) then
        -- Capture only old indexed evidence here. No callback text is read;
        -- the settled repair turn may prove a bounded join against its suffix.
        local delayed=accumulate_repair(repair_work,Structure.begin_deferred_fragment(s.structure,
            first,last,added,bytes,{rows=256,bytes=65536,nodes=65536,entries=65536}))
        if delayed.status=='deferred' then s.deferred={first=first,last=newlast,bytes=bytes} end
    else accumulate_repair(repair_work,Structure.splice(s.structure,first,last,opaque(added,bytes))) end
    if successor then
        effects(s,State.transition(s.authority,{kind='uncertain',first=event.first,last=event.first+event.new_bytes}))
    end
    if appended then Append.commit(s.append,s.structure,appended,newlast-1) end
    if not reused then s.idle=false end
    Replacement.after_observe(s,event,reused)
    reconcile(s)
    local work=Structure.stats(s.structure)
    for key,value in pairs(work) do work[key]=value-(before[key] or 0) end
    work.rows_processed,work.bytes_scanned=classified_rows+repair_work.rows_processed,classified_bytes
    work.dependency_nodes_visited=repair_work.dependency_nodes_visited
    if not s.append_busy then record(s,work) end
    -- Local proof repair gets the first scheduled turn. Presentation consumers
    -- still fail closed if their slice runs before that proof converges.
    schedule(doc)
    notify(s,{kind='edit',first_row=first,last_row=newlast,old_last_row=last,
        reused_suffix=reused,semantic_changed=not reused,diagnostic_changed=diagnostic_changed,
        deferred_fragment=s.deferred~=nil})
end
local function observe(doc,event)
    local s=state(doc)
    if s.dead or event.epoch~=s.epoch then return end
    if event.kind=='edit' then observe_edit(doc,s,event)
    elseif event.kind=='reload' then
        Replacement.clear(s)
        User.clear(s.editor)
        cancel_schedule(s)
        Append.clear(s.append)
        s.epoch=epoch(); s.deferred=nil; s.idle=false
        effects(s,State.transition(s.authority,{kind='reload',next_epoch=s.epoch}))
        s.editor:set_epoch(s.epoch)
        Structure.reload(s.structure,opaque(event.rows,event.total))
        notify(s,{kind='reload'}); schedule(doc)
    elseif event.kind=='detach' then
        Replacement.clear(s)
        User.clear(s.editor)
        cancel_schedule(s)
        Append.clear(s.append)
        s.dead=true; s.deferred=nil; buffers[s.buf]=nil
        if s.work then s.work:close() end
        effects(s,State.transition(s.authority,{kind='detach'}))
        notify(s,{kind='detach'}); s.subscribers={}; s.structure=nil; s.on_effect=nil; s.work=nil
    end
end

function M.attach(buf,opts)
    if buffers[buf] then return buffers[buf] end
    opts=opts or {}; local doc={}; local ep=epoch()
    local s={buf=buf,epoch=ep,authority=State.new({epoch=ep}),subscribers={},
        patterns=opts.patterns or Lexical.patterns({}),scheduling=opts.schedule~=false,on_effect=opts.on_effect}
    documents[doc]=s
    s.editor=Editor.new(buf,{epoch=ep,driver=opts.driver,on_event=function(event) observe(doc,event) end})
    s.structure=Structure.new(opaque(s.editor.rows,s.editor.total),s.patterns)
    if not s.editor:attach() then documents[doc]=nil; return nil end
    buffers[buf]=doc; schedule(doc); return doc
end
function M.get(buf) return buffers[buf] end
function M.size(doc)
    local s=state(doc); return s.dead and {rows=0,bytes=0} or Structure.size(s.structure)
end
function M.query(doc,first,last,opts)
    local s=state(doc); return s.dead and {} or measured_query(s,Structure.query,first,last,opts)
end
function M.snapshot(doc) return State.snapshot(state(doc).authority) end
--- Current write-turn holder, without the cost of a full snapshot copy.
function M.turn(doc) return State.turn(state(doc).authority) end
function M.stats(doc,reset)
    local s=state(doc); return s.dead and {} or Structure.stats(s.structure,reset)
end
function M.lookup(doc,handle,opts)
    local s=state(doc); if not s.dead then return measured_query(s,Structure.lookup,handle,opts) end
end
function M.exchange(doc,row,opts)
    local s=state(doc); return s.dead and {status='detached'} or measured_query(s,Structure.exchange,row,opts)
end
function M.capture_revision(doc,entity,kind,opts)
    local s=state(doc)
    return s.dead and {status='obsolete'} or measured_query(s,Structure.capture_revision,entity,kind,opts)
end
function M.validate_revision(doc,token,opts)
    local s=state(doc)
    return s.dead and {status='obsolete'} or measured_query(s,Structure.validate_revision,token,opts)
end
-- Display-only byte coordinates; no native reads or write authority.
function M.byte_position(doc,offset)
    local s=state(doc)
    if s.dead or type(offset)~='number' or offset<0 or offset>=math.huge or offset%1~=0 then return nil end
    local row=measured_query(s,Structure.at_byte,offset)
    if not row or row.opaque or row.end_row-row.start_row~=1 then return nil end
    return {row=row.start_row,col=offset-row.start_byte}
end
function M.next_exchange(doc,first,last,opts)
    local s=state(doc); return s.dead and {status='detached'} or measured_query(s,Structure.next_exchange,first,last,opts)
end
function M.completion(doc,entity,tip_row,opts)
    local s=state(doc)
    return s.dead and {status='detached'} or measured_query(s,Structure.completion,entity,tip_row,opts)
end
function M.folds(doc,first,last,opts)
    local s=state(doc); return s.dead and {status='detached'} or measured_query(s,Structure.folds,first,last,opts)
end
function M.outline(doc,first,last,opts)
    local s=state(doc); return s.dead and {status='detached'} or measured_query(s,Structure.outline,first,last,opts)
end
function M.diagnostic_candidates(doc,first,last,opts)
    local s=state(doc)
    return s.dead and {status='detached'} or measured_query(s,Structure.diagnostic_candidates,first,last,opts)
end
function M.uncertain_range(doc)
    local s=state(doc)
    return not s.dead and Structure.uncertain_range(s.structure) or nil
end
function M.validate_projection(doc,certificate)
    local s=state(doc); if s.dead then return false,'detached' end
    return measured_query(s,Structure.validate_projection,certificate)
end
function M.subscribe(doc,callback)
    local s=state(doc); assert(type(callback)=='function','subscriber must be callable')
    local key={}; s.subscribers[key]=callback
    return function() s.subscribers[key]=nil end
end
function M.transition(doc,event)
    local s=state(doc)
    if s.dead or type(event)~='table' then return effects(s,State.transition(s.authority,event)) end
    if event.kind~='register_generation' and event.kind~='acquire' and event.kind~='revoke'
        and event.kind~='finish_generation' and event.kind~='request_turn' and event.kind~='release_turn' then return {ok=false,reason='coordinator-owned event',effects={}} end
    if event.kind=='acquire' then
        if type(event.regions)~='table' or #event.regions>16 then return {ok=false,reason='grant limit',effects={}} end
        for _,region in ipairs(event.regions or {}) do
            if type(region)~='table' or type(region.first)~='number' or type(region.last)~='number' then
                return {ok=false,reason='invalid region',effects={}}
            end
            local current=proof(s,region)
            if not current or not current.confirmed or region.marker_revision~=1 or region.last>M.size(doc).bytes then
                return {ok=false,reason='unconfirmed entity',effects={}}
            end
        end
    end
    local before=State.turn(s.authority)
    local result=effects(s,State.transition(s.authority,event))
    if Replacement.prune(s) then schedule(doc) end
    Append.prune(s.append,State.snapshot(s.authority).grants)
    -- Compare the value rather than listing event kinds. finish_generation moves
    -- the turn as often as an explicit release does, and a per-event list drops it
    -- — leaving a generation parked on a 'waiting' step asleep for good.
    local after=State.turn(s.authority)
    if after~=before then notify(s,{kind='turn',turn=after}) end
    return result
end
function M.repair_step(doc,budget)
    local s=state(doc); if s.dead then return {status='detached'} end
    local before=Structure.stats(s.structure)
    local limits={bytes=4096,rows=1,nodes=32768,entries=32768}
    for key,value in pairs(budget or {}) do
        assert(type(value)=='number' and value>=0 and value<math.huge and value%1==0,'invalid repair budget')
        limits[key]=value
    end
    if s.deferred then
        local pending=s.deferred
        local result
        if not pending.spans then
            if limits.bytes<1 or limits.rows<1 then
                result={status='budget',required={bytes=1,rows=1},work={}}
            else
                pending.lex=pending.lex or Grammar.lex_start(s.patterns)
                local col=pending.col or 0
                local chunk=s.editor.reader:chunk({row=pending.first,col=col,max_bytes=math.min(65536,limits.bytes,math.max(1,pending.bytes-1-col))})
                local progress,token=Grammar.lex_step(pending.lex,chunk.bytes,chunk.eol,{bytes=limits.bytes})
                pending.lex=progress;pending.col=col+#chunk.bytes
                if token then pending.spans={{rows=1,bytes=pending.col+1,metadata={token=token}}} end
                result={status='more',work={bytes_scanned=#chunk.bytes,rows_processed=token and 1 or 0}}
                if pending.col>pending.bytes-1 or not chunk.eol and pending.col>=pending.bytes-1 then
                    pending.spans={}
                end
            end
        else
            local required=Structure.deferred_requirements(s.structure)
            if limits.nodes<required.nodes or limits.entries<required.entries or limits.rows<required.rows then
                result={status='budget',required=required,work={}}
            else
                s.deferred=nil
                result=Structure.finish_deferred_fragment(s.structure,pending.spans)
                if result.status=='idle' then s.idle=true end
                reconcile(s,true)
            end
        end
        result.work=result.work or {}
        for key,value in pairs(Structure.stats(s.structure)) do result.work[key]=value-(before[key] or 0) end
        record(s,result.work);notify(s,{kind='repair',result=result})
        return result
    end
    -- Refresh unread intents from the lexer's live provenance immediately
    -- before IO so disjoint edits cannot starve
    -- delivery or redirect it to a different row.
    local refreshed=Structure.refresh_read_request(s.structure,limits)
    local result
    if refreshed.status=='read' and Replacement.blocks(s,refreshed.request.row) then
        return {status='mutation',work=refreshed.work}
    elseif refreshed.status=='read' then
        limits.nodes=limits.nodes-(refreshed.work.nodes_visited or 0)
        limits.entries=limits.entries-(refreshed.work.entries_visited or 0)
        result=Structure.repair_step(s.structure,s.editor:chunk(refreshed.request),limits)
    elseif refreshed.status=='idle' then
        result=Structure.repair_step(s.structure,nil,limits)
    else result=refreshed end
    if result.status=='idle' then s.idle=true end
    reconcile(s,true)
    for key,value in pairs(Structure.stats(s.structure)) do result.work[key]=value-(before[key] or 0) end
    record(s,result.work or {})
    notify(s,{kind='repair',result=result})
    return result
end
function M.drain(doc,limit,budget)
    local result
    for _=1,limit or 10000 do
        result=M.repair_step(doc,budget)
        if result.status=='idle' or result.status=='detached' then return result end
    end
    return result
end
function M.capture_user(doc,intent)
    local s=state(doc)
    if s.dead then return nil,'detached' end
    return measured_query(s,function() return User.capture(s.structure,s.editor,s.epoch,intent) end)
end
function M.resolve_user(doc,token)
    local s=state(doc)
    if s.dead then return nil,'detached' end
    return measured_query(s,function() return User.resolve(s.structure,s.editor,s.epoch,token) end)
end
function M.extend_user(doc,token,intent)
    local s=state(doc)
    if s.dead then return nil,'detached' end
    return measured_query(s,function() return User.extend(s.structure,s.editor,s.epoch,token,intent) end)
end
function M.cancel_user(doc,token)
    local s=state(doc);return User.cancel(s.structure,s.editor,s.epoch,token)
end
function M.user_guard_stats(doc)return User.stats(state(doc).editor)end
function M.apply_user(doc,token,request)
    local s=state(doc)
    return User.apply(s.structure,s.editor,s.epoch,token,request)
end
-- Fresh confirmation may restore only the current parent endpoint after all
-- delegated writers have retired. This never uses finite successor authority.
function M.reclaim_tail(doc,intent)
    local s=state(doc)
    if s.dead or type(intent)~='table' then return {ok=false,reason='detached',effects={}} end
    local grant=State.snapshot(s.authority).grants[intent.grant]
    if not grant or Replacement.owns(s,intent.grant) then return {ok=false,reason='ownership',effects={}} end
    return effects(s,State.transition(s.authority,{kind='reclaim_tail',epoch=intent.epoch,
        generation=intent.generation,grant=intent.grant,entity=intent.entity,revision=intent.revision,current=proof(s,grant)}))
end
function M.replace_new(doc,intent)
    local s=state(doc)
    if s.dead or type(intent)~='table' then return nil,'detached' end
    if State.waits_for_turn(s.authority,intent.generation,intent.grant) then return nil,'waiting' end
    local grant=State.snapshot(s.authority).grants[intent.grant]
    if not grant then return nil,'grant' end
    local entity=Structure.lookup(s.structure,grant.entity)
    local offset=intent.first_offset or 0
    if type(offset)~='number' or offset<0 or offset%1~=0 or offset>grant.last-grant.first
        or not entity or grant.first+offset<entity.end_byte then return nil,'entity row overlap' end
    return Replacement.new(s,intent,proof(s,grant))
end
-- Insert a bounded suffix and relinquish it using finite replacement's private
-- receipt. Existing trailing authority may shrink; native bytes are never cut.
function M.insert_released_new(doc,intent)
    local s=state(doc)
    if s.dead or type(intent)~='table' or type(intent.bytes)~='string' or #intent.bytes>4096
        or type(intent.point)~='number' or intent.point%1~=0 then return nil,'invalid released insertion' end
    if State.waits_for_turn(s.authority,intent.generation,intent.grant) then return nil,'waiting' end
    local _,newlines=intent.bytes:gsub('\n','')
    if newlines>255 then return nil,'row slice limit'end
    local grant=State.snapshot(s.authority).grants[intent.grant]
    if not grant or intent.point<grant.first or intent.point>grant.last then return nil,'outside grant'end
    local row=Structure.at_byte(s.structure,intent.point)
    local entity=Structure.lookup(s.structure,grant.entity)
    if not row or row.opaque or intent.point~=row.end_byte-1 or not entity
        or intent.point<entity.end_byte then return nil,'unconfirmed line end'end
    local witness,reason=State.successor_new(s.authority,intent,proof(s,grant))
    if not witness then return nil,reason end
    if not State.successor_finish(s.authority,witness,intent.point)then
        State.successor_cancel(s.authority,witness);return nil,'cannot narrow grant'
    end
    grant=State.snapshot(s.authority).grants[intent.grant]
    local request={epoch=intent.epoch,generation=intent.generation,entity=intent.entity,grant=intent.grant,
        revision=grant.revision,operation=intent.operation,bytes=intent.bytes,
        first_offset=grant.last-grant.first,retain_prefix=0}
    return Replacement.new(s,request,proof(s,grant))
end
function M.replace_step(doc,cursor)
    local s=state(doc)
    local result=Replacement.step(s,cursor,function(grant)return proof(s,grant)end)
    if result.status~='more' then schedule(doc) end
    return result
end
function M.replace_cancel(doc,cursor)
    local s=state(doc);Replacement.cancel(s,cursor);schedule(doc)
end
function M.apply(doc,plan)
    local s=state(doc)
    if State.waits_for_turn(s.authority,plan.generation,plan.grant) then
        return {status='waiting',reason='write turn held elsewhere'}
    end
    local expected=plan.revision
    return s.editor:apply(plan,function(_,patch,phase,event)
        local grant=State.snapshot(s.authority).grants[plan.grant]
        if not grant then return false end
        local current=proof(s,grant)
        if not current then return false end
        if phase=='after' then
            if not event.owner or event.owner.grant~=plan.grant then return false end
            expected=type(expected)=='number' and expected+1 or nil
        end
        return effects(s,State.resolve(s.authority,{epoch=plan.epoch,generation=plan.generation,
            grant=plan.grant,entity=plan.entity,revision=expected,
            first=phase=='before' and patch.start.byte or event.first,
            last=phase=='before' and patch.finish.byte or event.first+event.new_bytes},current))
    end)
end
-- Resolve an owned leaf tail at call time. The caller supplies bytes, never
-- coordinates or lexical evidence. Exact receipts distinguish applied output
-- from permission to continue after structural repair.
local function append(doc,intent)
    local s=state(doc)
    local function reject(status,reason)return {status=status,reason=reason,accepted_bytes=0,work={}}end
    if s.dead then return reject('stale','detached') end
    if s.append_busy then return reject('busy','append in flight') end
    local operation=type(intent)=='table' and intent.operation
    local valid_operation=type(operation)=='string' and #operation>0 and #operation<=256
        or type(operation)=='number' and operation>=0 and operation<math.huge and operation%1==0
    if type(intent)~='table' or type(intent.bytes)~='string' or #intent.bytes>4096 or not valid_operation then
        return reject('refused','invalid append intent')
    end
    local _,newlines=intent.bytes:gsub('\n','')
    if newlines>255 then return reject('refused','row slice limit') end
    local snapshot=State.snapshot(s.authority)
    local grant=snapshot.grants[intent.grant]
    if not grant then return reject('stale','grant') end
    if State.waits_for_turn(s.authority,intent.generation,intent.grant) then return reject('waiting','write turn held elsewhere') end
    for _,other in pairs(snapshot.grants) do
        if other.parent==grant.id and other.status~='revoked' then return reject('refused','delegated parent') end
    end
    local current=proof(s,grant)
    if not current then return reject('stale','identity') end
    local resolved=effects(s,State.resolve(s.authority,{epoch=intent.epoch,generation=intent.generation,
        entity=intent.entity,grant=intent.grant,revision=intent.revision,first=grant.last,last=grant.last},current))
    if not resolved.ok then return reject((resolved.reason=='suspended' or resolved.reason=='uncertain')
        and 'suspended' or 'stale',resolved.reason) end
    if #intent.bytes==0 then return {status='applied',accepted_bytes=0,revision=grant.revision,work={}} end
    s.append=s.append or Append.new(s.patterns)
    Append.prune(s.append,snapshot.grants)
    local prepared=Append.prepare(s.append,s.structure,s.editor.reader,grant,intent)
    if prepared.status~='ready' then return prepared end
    s.append_busy=true
    local result=M.apply(doc,{epoch=intent.epoch,generation=intent.generation,operation=prepared.prepared.receipt_operation,
        grant=intent.grant,entity=intent.entity,revision=intent.revision,patches={prepared.patch}})
    s.append_busy=false
    local accepted=prepared.prepared.accepted and #intent.bytes or 0
    local after=State.snapshot(s.authority).grants[intent.grant]
    Append.finish(s.append,result.status=='interrupted' or result.status=='error' or accepted==0
        or not after or after.status=='revoked')
    local status=result.status
    if accepted>0 and after and after.status=='suspended' then status='suspended' end
    return {status=status,accepted_bytes=accepted,revision=after and after.revision,
        receipts=result.receipts,error=result.error,work=prepared.work}
end

function M.append(doc,intent)
    local s=state(doc)
    local before=not s.dead and Structure.stats(s.structure)
    local result=append(doc,intent)
    if before then
        local work=Structure.stats(s.structure)
        for key,value in pairs(work) do work[key]=value-(before[key] or 0) end
        for key,value in pairs(result.work or {}) do work[key]=value end
        work.lexer_retained_bytes,work.append_cursors=Append.retained(s.append)
        result.work=work
        record(s,work)
    end
    return result
end

function M.detach(doc) state(doc).editor:detach() end
return M
