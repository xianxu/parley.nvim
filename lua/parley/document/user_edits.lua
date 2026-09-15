-- Captured user intent owns text provenance, never an output grant.
local S=require('parley.document.structure')
local M={}
local tokens=setmetatable({},{__mode='k'})
local LIMIT=65536
local function integer(n) return type(n)=='number' and n>=0 and n<math.huge and n%1==0 end
local function position(editor,p)
    if type(p)~='table' or not integer(p.row) or not integer(p.col) then return nil end
    local rows=editor.driver.line_count(editor.buf)
    local row,col=p.row,p.col
    if row==rows and col==0 then row=rows-1;col=editor.driver.offset(editor.buf,rows)-editor.driver.offset(editor.buf,row)-1 end
    if row>=rows then return nil end
    local offset=editor.driver.offset(editor.buf,row)
    if col>editor.driver.offset(editor.buf,row+1)-offset-1 then return nil end
    return {row=row,col=col,byte=offset+col}
end
-- Fixed slots contain weak references. Tokens retain their guards; neither
-- registry values nor guard owners retain the opaque token or editor key.
local registries=setmetatable({},{__mode='k'})
local CAPACITY=64
local function registry(editor)
    local r=registries[editor]
    if not r then r={slots=setmetatable({},{__mode='v'}),last_visits=0,total_visits=0};registries[editor]=r end
    return r
end
local function live(guard) return guard and guard.valid and next(guard.owners)~=nil end
local function copy_pos(p)return {row=p.row,col=p.col,byte=p.byte}end
local function relocate(p,event)
    local old,new=event.old_end,event.new_end
    return {byte=p.byte+event.new_bytes-(event.last-event.first),
        row=p.row+new.row-old.row,col=p.row==old.row and new.col+p.col-old.col or p.col}
end
function M.observe(editor,event)
    local r=registries[editor];if not r then return 0 end
    local visits=CAPACITY
    for i=1,CAPACITY do
        local guard=r.slots[i]
        if live(guard) then
            -- Closed boundary contact is deliberately conservative: joining a
            -- selected edge must not substitute adjacent identical text.
            if event.last<guard.first.byte then
                guard.first=relocate(guard.first,event);guard.last=relocate(guard.last,event)
                guard.source_first=relocate(guard.source_first,event);guard.source_last=relocate(guard.source_last,event)
            elseif event.first<=guard.last.byte then guard.valid=false;r.slots[i]=nil end
        elseif guard then r.slots[i]=nil end
    end
    r.last_visits=visits;r.total_visits=r.total_visits+visits
    return visits
end
function M.clear(editor)
    local r=registries[editor];if not r then return end
    for i=1,CAPACITY do local g=r.slots[i];if g then g.valid=false;r.slots[i]=nil end end
end
function M.stats(editor)
    local r=registry(editor);local count=0
    for i=1,CAPACITY do if live(r.slots[i]) then count=count+1 end end
    return {live=count,capacity=CAPACITY,last_visits=r.last_visits,total_visits=r.total_visits}
end
local function binding(structure,editor,epoch,token)
    local t=tokens[token]
    if not t or t.consumed or t.structure~=structure or t.editor~=editor or t.epoch~=epoch
        or editor.dead or editor.epoch~=epoch then return nil,'stale' end
    return t
end
function M.resolve(structure,editor,epoch,token)
    local t,reason=binding(structure,editor,epoch,token);if not t then return nil,reason end
    local result={regions={},anchors={}}
    for _,g in ipairs(t.regions) do
        if not g.valid then return nil,'stale' end
        result.regions[#result.regions+1]={first=copy_pos(g.source_first),last=copy_pos(g.source_last)}
    end
    for _,g in ipairs(t.anchors) do
        if not g.valid then return nil,'stale' end
        result.anchors[#result.anchors+1]=copy_pos(g.source_first)
    end
    return result
end
local function make_guard(editor,a,b,exact_point)
    local first,last=a,b
    if a.byte==b.byte and not exact_point then
        first=position(editor,{row=a.row,col=0})
        last=position(editor,{row=a.row,col=editor.driver.offset(editor.buf,a.row+1)-editor.driver.offset(editor.buf,a.row)-1})
    end
    return {first=first,last=last,source_first=a,source_last=b,valid=true,owners=setmetatable({},{__mode='k'})}
end
local function capture(structure,editor,epoch,intent,old,exact_point)
    if type(intent)~='table' or intent.grant or intent.generation or editor.dead or editor.in_callback or editor.operation then return nil,'refused' end
    local op=old and old.operation or intent.operation
    if not (type(op)=='string' and #op>0 and #op<=256 or integer(op)) then return nil,'operation' end
    if #(intent.regions or {})+#(intent.anchors or {})>CAPACITY then return nil,'capacity' end
    local regions,anchors={},{}
    for _,r in ipairs(intent.regions or {}) do
        local a,b=position(editor,r.first),position(editor,r.last)
        if not a or not b or a.byte>b.byte then return nil,'range' end
        regions[#regions+1]=make_guard(editor,a,b,exact_point)
    end
    for _,a in ipairs(intent.anchors or {}) do
        if a.edge~='start' and a.edge~='end' then return nil,'anchor' end
        local span=S.lookup(structure,a.handle);if not span then return nil,'anchor' end
        local p=position(editor,{row=a.edge=='end' and span.end_row or span.start_row,col=0})
        if not p then return nil,'anchor' end
        anchors[#anchors+1]=make_guard(editor,p,p)
    end
    local r=registry(editor);local slots={}
    for i=1,CAPACITY do if not live(r.slots[i]) then slots[#slots+1]=i end end
    if #slots<#regions+#anchors then return nil,'capacity' end
    local token={};local t={structure=structure,editor=editor,epoch=epoch,operation=op,regions={},anchors={}}
    local slot=0
    for _,pair in ipairs({{regions,t.regions},{anchors,t.anchors}}) do
        for _,guard in ipairs(pair[1]) do
            slot=slot+1;r.slots[slots[slot]]=guard;pair[2][#pair[2]+1]=guard
        end
    end
    if old then
        local combined={};for _,g in ipairs(old.regions) do combined[#combined+1]=g end
        for _,g in ipairs(t.regions) do combined[#combined+1]=g end;t.regions=combined
        local combined_anchors={};for _,g in ipairs(old.anchors) do combined_anchors[#combined_anchors+1]=g end
        for _,g in ipairs(t.anchors) do combined_anchors[#combined_anchors+1]=g end;t.anchors=combined_anchors
    end
    for _,list in ipairs({t.regions,t.anchors}) do for _,g in ipairs(list) do g.owners[token]=true end end
    tokens[token]=t;return token
end
function M.capture(structure,editor,epoch,intent)return capture(structure,editor,epoch,intent)end
-- Private replacement seam: callers must possess the finite successor witness.
-- No option supplied to ordinary capture/extend can select point semantics.
function M.capture_successor(structure,editor,epoch,intent,authority,witness)
    local current=require('parley.document.state').successor_current(authority,witness)
    if not current or editor.epoch~=epoch or type(intent)~='table'
        or #(intent.regions or {})~=1 or #(intent.anchors or {})~=0 then return nil,'successor' end
    local r=intent.regions[1]
    local a,b=position(editor,r.first),position(editor,r.last)
    if not a or not b or a.byte~=b.byte or a.byte<current.first or a.byte>current.last then return nil,'successor' end
    return capture(structure,editor,epoch,intent,nil,true)
end
function M.extend(structure,editor,epoch,token,intent)
    local old,reason=binding(structure,editor,epoch,token)
    if not old or not M.resolve(structure,editor,epoch,token) then return nil,reason or 'stale' end
    return capture(structure,editor,epoch,intent,old)
end
function M.cancel(structure,editor,epoch,token)
    local t=binding(structure,editor,epoch,token);if not t then return false end
    t.consumed=true
    for _,list in ipairs({t.regions,t.anchors}) do for _,g in ipairs(list) do g.owners[token]=nil end end
    t.regions={};t.anchors={};return true
end
local function point(start,text,offset)
    local row,col=start.row,start.col
    local from=1
    while true do
        local newline=text:find('\n',from,true)
        if not newline or newline>offset then col=col+offset-from+1;break end
        row=row+1;col=0;from=newline+1
    end
    return {row=row,col=col,byte=start.byte+offset}
end
local function boundary(text,offset)
    while offset>0 and offset<#text and text:byte(offset+1)>=128 and text:byte(offset+1)<192 do offset=offset-1 end
    return offset
end
local function compile(editor,regions,requests)
    local edits={}
    for _,request in ipairs(requests or {}) do
        local r=regions[request.region]
        if not r or type(request.text)~='string' then return nil,'patch' end
        edits[#edits+1]={first=r.first,last=r.last,text=request.text}
    end
    table.sort(edits,function(a,b)return a.first.byte>b.first.byte end)
    local patches={};local lower=math.huge
    for _,e in ipairs(edits) do
        if e.last.byte>lower or e.first.byte==lower then return nil,'overlapping patches' end
        lower=e.first.byte
        local old=table.concat(editor.reader:text(e.first.row,e.first.col,e.last.row,e.last.col,{}),'\n')
        if #old<=LIMIT and #e.text<=LIMIT then
            patches[#patches+1]={start=e.first,finish=e.last,expected_old=old,text=e.text}
        else
            local remaining=#old
            while remaining>0 do
                local first=boundary(old,math.max(0,remaining-LIMIT))
                -- Retreating a UTF-8 boundary can exceed the byte cap; advance
                -- to the next complete codepoint instead.
                if remaining-first>LIMIT then first=first+1;while old:byte(first+1)>=128 and old:byte(first+1)<192 do first=first+1 end end
                patches[#patches+1]={start=point(e.first,old,first),finish=point(e.first,old,remaining),expected_old=old:sub(first+1,remaining),text=''}
                remaining=first
            end
            remaining=#e.text
            while remaining>0 do
                local first=math.max(0,remaining-LIMIT)
                while first>0 and e.text:byte(first+1)>=128 and e.text:byte(first+1)<192 do first=first+1 end
                patches[#patches+1]={start=e.first,finish=e.first,expected_old='',text=e.text:sub(first+1,remaining)}
                remaining=first
            end
        end
    end
    return patches
end
function M.apply(structure,editor,epoch,token,request)
    local t,reason=binding(structure,editor,epoch,token)
    local resolved=t and M.resolve(structure,editor,epoch,token)
    if not resolved then return {status='stale',reason=reason,receipts={}} end
    local patches,err=compile(editor,resolved.regions,request.patches)
    if not patches then return {status='refused',reason=err,receipts={}} end
    if not M.resolve(structure,editor,epoch,token) then return {status='stale',receipts={}} end
    M.cancel(structure,editor,epoch,token)
    return editor:apply_user({epoch=epoch,operation=t.operation,patches=patches},function(_,_,phase,event)
        return editor.epoch==epoch and not editor.dead and (phase~='after' or event.role=='user')
    end)
end
return M
