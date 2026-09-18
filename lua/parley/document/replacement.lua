-- Finite replacement owns only an immutable payload and bounded authority.
-- Text remains native; exact receipts, never equivalent text, advance the cursor.
local State=require('parley.document.state')
local User=require('parley.document.user_edits')
local M={}
local cursors=setmetatable({},{__mode='k'})
local serial=0
local function point(editor,byte)
    local lo,hi=0,editor.driver.line_count(editor.buf)-1
    while lo<hi do
        local mid=math.floor((lo+hi+1)/2)
        if editor.driver.offset(editor.buf,mid)<=byte then lo=mid else hi=mid-1 end
    end
    return {row=lo,col=byte-editor.driver.offset(editor.buf,lo),byte=byte}
end
local function capture(c,first,last)
    if c.guard then User.cancel(c.s.structure,c.s.editor,c.s.epoch,c.guard) end
    local intent={operation=c.operation,
        regions={{first=point(c.s.editor,first),last=point(c.s.editor,last)}}}
    if first==last then
        c.guard=User.capture_successor(c.s.structure,c.s.editor,c.s.epoch,intent,c.s.authority,c.witness)
    else c.guard=User.capture(c.s.structure,c.s.editor,c.s.epoch,intent) end
    return c.guard~=nil
end
local function boundary(editor,byte)
    local p=point(editor,byte)
    local ending=editor.driver.offset(editor.buf,p.row+1)-1
    if byte==ending then return true end
    if byte>ending then return false end
    local x=editor.reader:text(p.row,p.col,p.row,p.col+1,{})[1]:byte(1)
    return not x or x<128 or x>=192
end
local function stop(c,status)
    if not c.s then return end
    c.status=status;c.active=false;c.payload=nil
    if c.s.replacements then c.s.replacements[c.token]=nil end
    State.successor_cancel(c.s.authority,c.witness)
    if c.guard then User.cancel(c.s.structure,c.s.editor,c.s.epoch,c.guard);c.guard=nil end
    c.s=nil;c.armed=nil;c.external_event=nil
end
function M.new(s,intent,current)
    if type(intent)~='table' or type(intent.bytes)~='string' or #intent.bytes>1048576 then return nil,'payload limit' end
    local op=intent.operation
    if not (type(op)=='string' and #op>0 and #op<=256 or type(op)=='number' and op>=0 and op<math.huge and op%1==0) then return nil,'operation' end
    local retain=intent.retain_prefix
    if retain~=nil and (type(retain)~='number' or retain<0 or retain%1~=0 or retain>#intent.bytes
        or retain<#intent.bytes and intent.bytes:byte(retain+1)>=128 and intent.bytes:byte(retain+1)<192) then
        return nil,'retained prefix'
    end
    local grant=State.snapshot(s.authority).grants[intent.grant]
    if not grant then return nil,'grant' end
    if not boundary(s.editor,grant.first+(intent.first_offset or 0)) or not boundary(s.editor,grant.last) then return nil,'UTF-8 boundary' end
    for token in pairs(s.replacements or {}) do
        local old=cursors[token]
        if old and old.status=='more' and old.grant==intent.grant then return nil,'busy' end
    end
    local witness,reason=State.successor_new(s.authority,intent,current)
    if not witness then return nil,reason end
    serial=serial+1
    local token={};local c={token=token,s=s,binding=setmetatable({s},{__mode='v'}),epoch=s.epoch,grant=grant.id,generation=grant.generation,entity=grant.entity,
        operation='finite-replacement-'..serial,witness=witness,payload=intent.bytes,retain=retain,
        removed=0,accepted=0,offset=intent.first_offset or 0,
        remaining=grant.last-grant.first-(intent.first_offset or 0),status='more',active=true}
    if not capture(c,grant.first+c.offset,grant.last) then State.successor_cancel(s.authority,witness);return nil,'source' end
    cursors[token]=c;s.replacements=s.replacements or {};s.replacements[token]=true
    return token
end
function M.cancel(s,token)
    local c=cursors[token];if c and c.s==s then stop(c,'cancelled') end
end
function M.clear(s)
    for token in pairs(s.replacements or {}) do local c=cursors[token];if c then stop(c,'stale') end end
end
-- Called before State observes an edit. Only the editor's exact matched owner
-- can name the operation currently armed by this private cursor.
function M.observe(s,event)
    local matched,final_receipt
    for token in pairs(s.replacements or {}) do
        local c=cursors[token]
        if c and c.status=='more' then
            local p=c.armed
            if p and event.source_frame==true and event.owner and event.owner.operation==c.operation
                and event.owner.grant==c.grant and event.first==p.first and event.last==p.last
                and event.new_bytes==p.new_bytes then
                c.received=true;matched=c.witness
                final_receipt=c.remaining==event.last-event.first
                    and c.accepted+event.new_bytes==#c.payload
            else c.external_event=event;c.was_active=c.active;c.active=false;c.paused=true end
        end
    end
    return matched,final_receipt
end
function M.after_observe(s,event,reused)
    for token in pairs(s.replacements or {}) do
        local c=cursors[token]
        if c and c.external_event==event then
            if reused and c.was_active and User.resolve(s.structure,s.editor,s.epoch,c.guard)
                and State.successor_relocate(s.authority,c.witness) then
                c.active=true;c.paused=false
            end
            c.external_event=nil;c.was_active=nil
        end
    end
end
function M.prune(s)
    local grants=State.snapshot(s.authority).grants;local changed=false
    for token in pairs(s.replacements or {}) do
        local c=cursors[token];local g=c and grants[c.grant]
        if c and (not g or g.status=='revoked' or s.epoch~=c.epoch) then stop(c,'stale');changed=true end
    end
    return changed
end
function M.owns(s,grant)
    for token in pairs(s.replacements or {}) do
        local c=cursors[token]
        if c and c.active and c.status=='more' and c.grant==grant then return true end
    end
    return false
end
function M.blocks(s,row)
    for token in pairs(s.replacements or {}) do
        local c=cursors[token]
        if c and c.active and c.status=='more' then
            local g=State.snapshot(s.authority).grants[c.grant]
            if g and row>=point(s.editor,g.first+c.offset).row and row<=point(s.editor,g.last).row then return true end
        end
    end
    return false
end
function M.step(s,token,proof)
    local c=cursors[token]
    local function result(status,removed,accepted,err)
        return {status=status,removed_bytes=removed or 0,accepted_bytes=accepted or 0,
            total_removed_bytes=c and c.removed or 0,total_accepted_bytes=c and c.accepted or 0,error=err}
    end
    if not c or (c.s or c.binding[1])~=s then return result('stale') end
    if c.status~='more' then return result(c.status) end
    if s.dead or s.epoch~=c.epoch then stop(c,'stale');return result('stale') end
    local source=User.resolve(s.structure,s.editor,s.epoch,c.guard)
    if not source then stop(c,'stale');return result('stale') end
    local g=State.snapshot(s.authority).grants[c.grant]
    if not g or g.status=='revoked' then stop(c,'stale');return result('stale') end
    -- #266 M1: a continuation must still hold the turn. Park without stop() — the
    -- cursor is resumable, and stopping it here would be permanent.
    if State.waits_for_turn(s.authority,c.generation,c.grant) then return result('waiting') end
    if c.paused then
        local current=proof(g)
        if not current or not current.confirmed then return result('suspended') end
        State.successor_cancel(s.authority,c.witness)
        c.witness=State.successor_new(s.authority,{epoch=c.epoch,generation=c.generation,
            entity=c.entity,grant=c.grant,revision=g.revision},current)
        if not c.witness then stop(c,'stale');return result('stale') end
        c.paused=false;c.active=true
    end
    local first,last=g.first+c.offset,g.last
    local a,b,text,old
    if c.remaining>0 then
        b=point(s.editor,last);a=point(s.editor,math.max(first,last-4096))
        old=table.concat(s.editor.reader:text(a.row,a.col,b.row,b.col,{}),'\n')
        -- A slice may begin in a UTF-8 codepoint; leave that codepoint for the
        -- next slice. Initial grant boundaries are checked by the coordinator.
        local skip=0
        while skip<#old and old:byte(skip+1)>=128 and old:byte(skip+1)<192 do skip=skip+1 end
        if skip>0 then old=old:sub(skip+1);a=point(s.editor,a.byte+skip) end
        text=''
    else
        a=point(s.editor,last);b=a;old=''
        text=c.payload:sub(c.accepted+1,c.accepted+4096)
        local cut=#text
        if c.accepted+cut<#c.payload then
            while cut>0 and c.payload:byte(c.accepted+cut+1)>=128 and c.payload:byte(c.accepted+cut+1)<192 do cut=cut-1 end
        end
        local count=0
        for i=1,cut do if text:byte(i)==10 then count=count+1;if count==256 then cut=i-1;break end end end
        text=text:sub(1,cut)
    end
    if #old==0 and #text==0 then
        State.successor_finish(s.authority,c.witness,g.first+c.offset+(c.retain or c.accepted))
        stop(c,'applied');return result('applied')
    end
    c.armed={first=a.byte,last=b.byte,new_bytes=#text};c.received=false
    if not State.successor_arm(s.authority,c.witness,c.armed) then stop(c,'stale');return result('stale') end
    local response=s.editor:apply({epoch=c.epoch,generation=c.generation,grant=c.grant,entity=c.entity,
        operation=c.operation,patches={{start=a,finish=b,text=text,expected_old=old}}},function(_,_,phase)
        if phase=='after' then return c.received and not c.paused end
        return State.successor_current(s.authority,c.witness)~=nil
    end)
    c.armed=nil
    local removed,accepted=0,0
    if c.received then
        removed=#old;accepted=#text;c.removed=c.removed+removed;c.remaining=c.remaining-removed;c.accepted=c.accepted+accepted
    end
    -- A native edit subscriber may cancel/reload during the final receipt.
    -- Count that proven mutation once, then respect its retired lifetime before
    -- touching released guards or payload state.
    if c.status~='more' then return result(c.status,removed,accepted) end
    g=State.snapshot(s.authority).grants[c.grant]
    if response.status~='applied' or c.paused or not g or g.status=='revoked' then
        stop(c,response.status=='error' and 'error' or 'stale')
        return result(c.status,removed,accepted,response.error)
    end
    if not capture(c,g.first+c.offset,g.last) then stop(c,'stale');return result('stale',removed,accepted) end
    if c.remaining==0 and c.accepted==#c.payload then
        State.successor_finish(s.authority,c.witness,g.first+c.offset+(c.retain or c.accepted))
        stop(c,'applied')
    end
    return result(c.status,removed,accepted)
end
return M
