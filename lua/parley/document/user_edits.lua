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
local function binding(structure,editor,epoch,token)
    local t=tokens[token]
    if not t or t.consumed or t.structure~=structure or t.editor~=editor or t.epoch~=epoch
        or editor.dead or editor.epoch~=epoch then return nil,'stale' end
    return t
end
function M.resolve(structure,editor,epoch,token)
    local t,reason=binding(structure,editor,epoch,token);if not t then return nil,reason end
    local result={regions={},anchors={}}
    for _,r in ipairs(t.regions) do
        local ok,extent=S.validate_text(structure,r.proof);if not ok then return nil,'stale' end
        local first=position(editor,{row=extent.first_row,col=r.first_col})
        local last=position(editor,{row=extent.first_row+r.row_delta,col=r.last_col})
        if not first or not last then return nil,'stale' end
        result.regions[#result.regions+1]={first=first,last=last}
    end
    for _,a in ipairs(t.anchors) do
        local span=S.lookup(structure,a.handle)
        if not span then return nil,'stale' end
        result.anchors[#result.anchors+1]={row=a.edge=='end' and span.end_row or span.start_row,
            byte=a.edge=='end' and span.end_byte or span.start_byte}
    end
    return result
end
function M.capture(structure,editor,epoch,intent)
    if type(intent)~='table' or intent.grant or intent.generation or editor.dead or editor.in_callback or editor.operation then return nil,'refused' end
    local op=intent.operation
    if not (type(op)=='string' and #op>0 and #op<=256 or integer(op)) then return nil,'operation' end
    local regions={}
    for _,r in ipairs(intent.regions or {}) do
        local a,b=position(editor,r.first),position(editor,r.last)
        if not a or not b or a.byte>b.byte then return nil,'range' end
        regions[#regions+1]={first=a,last=b}
    end
    for _,r in ipairs(regions) do
        local first,last=r.first.row,r.last.row+1
        S.expose_text_range(structure,first,last,editor.driver.offset(editor.buf,first),editor.driver.offset(editor.buf,last))
    end
    local t={structure=structure,editor=editor,epoch=epoch,operation=op,regions={},anchors={}}
    for _,r in ipairs(regions) do
        local proof,err=S.capture_text(structure,r.first.row,r.last.row+1)
        if not proof then return nil,err end
        t.regions[#t.regions+1]={proof=proof,first_col=r.first.col,last_col=r.last.col,row_delta=r.last.row-r.first.row}
    end
    for _,a in ipairs(intent.anchors or {}) do
        if (a.edge~='start' and a.edge~='end') or not S.lookup(structure,a.handle) then return nil,'anchor' end
        t.anchors[#t.anchors+1]={handle=a.handle,edge=a.edge}
    end
    local token={};tokens[token]=t;return token
end
function M.extend(structure,editor,epoch,token,intent)
    local old,reason=binding(structure,editor,epoch,token)
    if not old or not M.resolve(structure,editor,epoch,token) then return nil,reason or 'stale' end
    local added,err=M.capture(structure,editor,epoch,{operation=old.operation,regions=intent.regions,anchors=intent.anchors})
    if not added then return nil,err end
    if not M.resolve(structure,editor,epoch,token) then return nil,'stale' end
    local next_token={};local t=tokens[added]
    local combined={};for _,r in ipairs(old.regions) do combined[#combined+1]=r end
    for _,r in ipairs(t.regions) do combined[#combined+1]=r end;t.regions=combined
    for _,a in ipairs(old.anchors) do t.anchors[#t.anchors+1]=a end
    tokens[next_token]=t;return next_token
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
        if e.last.byte>=lower then return nil,'overlapping patches' end
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
    t.consumed=true
    return editor:apply_user({epoch=epoch,operation=t.operation,patches=patches},function(_,_,phase,event)
        return editor.epoch==epoch and not editor.dead and (phase~='after' or event.role=='user')
    end)
end
return M
