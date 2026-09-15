-- Private append cursors. The document validates grants; the editor proves
-- exact delivery before any prepared lexical descriptor is published.
local Lex=require('parley.document.lexical')
local Structure=require('parley.document.structure')
local M={}
local write_serial=0
local owners=setmetatable({},{__mode='k'})
local function state(owner)return assert(owners[owner],'invalid append owner')end
function M.new(patterns)
    local owner={};owners[owner]={patterns=patterns,slots={}};return owner
end
function M.clear(owner)if owner then local s=state(owner);s.slots={};s.pending=nil end end
function M.prune(owner,grants)
    if not owner then return end
    local s=state(owner)
    for id in pairs(s.slots) do
        if not grants[id] or grants[id].status=='revoked' then s.slots[id]=nil end
    end
end
function M.prepare(owner,document,reader,grant,intent)
    local s=state(owner);local slot=s.slots[grant.id]
    local span=slot and Structure.validate_entry(document,slot.proof)
    if slot and (not span or slot.operation~=intent.operation or slot.entity~=intent.entity) then
        s.slots[grant.id]=nil;slot=nil
    end
    if not slot then
        local count=0;for _ in pairs(s.slots) do count=count+1 end
        if count>=16 then return {status='refused',reason='append cursor limit',accepted_bytes=0,work={}} end
        span=Structure.at_byte(document,grant.last,{nodes=128,entries=128})
        if not span or span.opaque or span.rows~=1 or grant.last~=span.end_byte-1 then
            return {status='refused',reason='append requires a known line-end slot',accepted_bytes=0,work={}}
        end
        slot={proof=Structure.entry_checkpoint(document,span.handle),cursor=Lex.lex_start(s.patterns),
            col=0,operation=intent.operation,entity=intent.entity}
        s.slots[grant.id]=slot
    end
    if grant.last~=span.end_byte-1 then
        s.slots[grant.id]=nil
        return {status='stale',reason='append slot moved within source',accepted_bytes=0,work={}}
    end
    local length=span.bytes-1
    if slot.col<length then
        local chunk=reader:chunk({row=span.start_row,col=slot.col,max_bytes=math.min(4096,length-slot.col)})
        Lex.lex_step(slot.cursor,chunk.bytes,false,{bytes=4096})
        slot.col=slot.col+#chunk.bytes
        return {status='more',accepted_bytes=0,work={bytes_scanned=#chunk.bytes}}
    end
    local cursor={};for k,v in pairs(slot.cursor) do cursor[k]=v end
    local spans={};local at=1
    while true do
        local ending=intent.bytes:find('\n',at,true)
        local part=intent.bytes:sub(at,ending and ending-1 or -1)
        Lex.lex_step(cursor,part,false,{bytes=4096})
        local token=Lex.lex_token(cursor)
        spans[#spans+1]={rows=1,bytes=token.bytes+1,metadata={token=token}}
        if not ending then break end
        cursor=Lex.lex_start(s.patterns);at=ending+1
    end
    write_serial=write_serial+1
    local prepared={receipt_operation='append:'..write_serial,grant=grant.id,operation=intent.operation,entity=intent.entity,epoch=intent.epoch,
        generation=intent.generation,first=grant.last,bytes=#intent.bytes,spans=spans,cursor=cursor}
    s.pending=prepared
    return {status='ready',prepared=prepared,patch={start={row=span.start_row,col=length,byte=grant.last},
        finish={row=span.start_row,col=length,byte=grant.last},expected_old='',text=intent.bytes},
        work={bytes_scanned=#intent.bytes}}
end
function M.observe(owner,document,event)
    if not owner then return nil end
    local s=state(owner);local pending=s.pending;local o=event.owner
    local matching=pending and o and o.grant==pending.grant and o.operation==pending.receipt_operation
        and o.entity==pending.entity and o.epoch==pending.epoch and o.generation==pending.generation
        and event.first==pending.first and event.last==pending.first and event.new_bytes==pending.bytes
    for id,slot in pairs(s.slots) do
        local span=Structure.validate_entry(document,slot.proof)
        local touched=false
        if span then
            if event.first==event.last then
                local preceding_rows=event.first==span.start_byte and event.start.col==0
                    and event.new_end.col==0
                touched=event.first>=span.start_byte and event.first<=span.end_byte-1 and not preceding_rows
            else touched=event.first<span.end_byte and event.last>span.start_byte end
        end
        if not span or (not matching or id~=pending.grant) and touched then s.slots[id]=nil end
    end
    return matching and pending or nil
end
function M.commit(owner,document,prepared,last_row)
    local s=state(owner)
    if s.pending~=prepared then return end
    local span=Structure.at(document,last_row)
    s.slots[prepared.grant]={proof=Structure.entry_checkpoint(document,span.handle),cursor=prepared.cursor,
        col=prepared.cursor.bytes,operation=prepared.operation,entity=prepared.entity}
    prepared.accepted=true
end
function M.retained(owner)
    local bytes,count=0,0
    if owner then
        for _,slot in pairs(state(owner).slots) do bytes=bytes+Lex.lexer_retained_bytes(slot.cursor);count=count+1 end
    end
    return bytes,count
end
function M.finish(owner,discard)
    if owner then
        local s=state(owner)
        if discard and s.pending then s.slots[s.pending.grant]=nil end
        s.pending=nil
    end
end
return M
