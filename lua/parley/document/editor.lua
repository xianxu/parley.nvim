-- One buffer callback owner. Authority belongs to the document coordinator.
local M = {}
local Editor = {}
Editor.__index = Editor
local LIMIT = 65536
local owners = {}
local function native()
    return {
        line_count=vim.api.nvim_buf_line_count, offset=vim.api.nvim_buf_get_offset,
        text=vim.api.nvim_buf_get_text, lines=vim.api.nvim_buf_get_lines,
        set_text=vim.api.nvim_buf_set_text, attach=vim.api.nvim_buf_attach,
        detach=vim.api.nvim_buf_detach,
        undo_state=function(buf)
            return {sequence=vim.api.nvim_buf_call(buf,vim.fn.changenr),tick=vim.api.nvim_buf_get_changedtick(buf)}
        end,
        undo_break=function(buf)
            vim.api.nvim_buf_call(buf,function() vim.cmd('let &l:undolevels = &l:undolevels') end)
        end,
        undo_join=function(buf)
            vim.api.nvim_buf_call(buf,function() vim.cmd('undojoin') end)
        end,
    }
end
local function endpoint(sr,sc,rows,col,byte)
    return {row=sr+rows,col=rows==0 and sc+col or col,byte=byte}
end
local function equal_pos(a,b)
    return a.row==b.row and a.col==b.col and a.byte==b.byte
end
local function split(text)
    return vim.split(text,'\n',{plain=true})
end
local function authorized(validate,plan,patch,phase,event)
    local result=validate(plan,patch,phase,event)
    return result==true or type(result)=='table' and result.ok==true
end
function M.new(buf,opts)
    opts=opts or {}
    local driver=opts.driver or native()
    local rows=driver.line_count(buf)
    local self=setmetatable({buf=buf,epoch=assert(opts.epoch),driver=driver,
        on_event=assert(opts.on_event),rows=rows,total=driver.offset(buf,rows)},Editor)
    self.reader=require('parley.line_reader').for_buffer(buf,{delegate=driver})
    return self
end
function Editor:chunk(request) return self.reader:chunk(request) end
function Editor:observe(tick,sr,sc,sb,orows,oc,ob,nrows,nc,nb)
    self.undo_receipt=nil
    -- Grouped undo exposes final native text while emitting intermediate edits.
    -- Keep the callback coordinate frame by applying its row delta as well.
    local rows=math.max(1,self.rows-orows+nrows)
    local total=self.total-ob+nb
    if total==0 then total=1 end
    -- Deleting all lines reports zero new bytes, but Neovim keeps one empty row.
    local inserted=total-self.total+ob
    local new_end=endpoint(sr,sc,nrows,nc,sb+inserted)
    if inserted~=nb then new_end={row=rows,col=0,byte=total} end
    local event={kind='edit',epoch=self.epoch,tick=tick,first=sb,last=sb+ob,new_bytes=inserted,
        start={row=sr,col=sc,byte=sb},old_end=endpoint(sr,sc,orows,oc,sb+ob),new_end=new_end,
        old_rows=self.rows,new_rows=rows,old_total=self.total,new_total=total}
    self.rows,self.total=rows,total
    local pending=self.pending
    if pending and not pending.seen and equal_pos(event.start,pending.patch.start)
        and equal_pos(event.old_end,pending.patch.finish) and equal_pos(new_end,pending.new_end)
        and inserted==#pending.patch.text then
        local actual=table.concat(self.reader:text(sr,sc,new_end.row,new_end.col,{}),'\n')
        if actual==pending.patch.text then
            pending.seen=true
            event.owner=pending.owner
        end
    end
    if self.operation then
        self.operation.receipts[#self.operation.receipts+1]=event
        if not event.owner then self.operation.unexpected=true end
    end
    self.in_callback=true
    local ok,err=pcall(function()
        self.on_event(event)
        if self.operation and not authorized(self.operation.validate,self.operation.plan,
            self.operation.patch,'after',event) then self.operation.revoked=true end
    end)
    self.in_callback=false
    if not ok then
        if self.operation then self.operation.unexpected=true end
        error(err)
    end
    return event
end
function Editor:attach()
    assert(not self.attached and not owners[self.buf],'document editor already attached')
    owners[self.buf]=self
    local function lifecycle(kind,tick)
        self.undo_receipt=nil
        if self.operation then self.operation.unexpected=true end
        if kind=='reload' then
            self.rows=self.driver.line_count(self.buf)
            self.total=self.driver.offset(self.buf,self.rows)
        elseif kind=='detach' then self.dead=true; owners[self.buf]=nil end
        self.in_callback=true
        local delivered,err=pcall(self.on_event,{kind=kind,epoch=self.epoch,tick=tick,rows=self.rows,total=self.total})
        self.in_callback=false
        if not delivered then error(err) end
    end
    local ok=self.driver.attach(self.buf,false,{
        on_bytes=function(_,_,tick,...) if not self.dead then self:observe(tick,...) end end,
        on_reload=function() lifecycle('reload') end,
        on_detach=function() lifecycle('detach') end,
        on_changedtick=function(_,_,tick) lifecycle('tick',tick) end,
    })
    if not ok then owners[self.buf]=nil; return false end
    self.attached=true
    return true
end
function Editor:set_epoch(epoch)
    self.undo_receipt=nil
    self.epoch=assert(epoch)
    self.pending=nil
    if self.operation then self.operation.unexpected=true end
end
function Editor:detach()
    if self.attached and not self.dead then self.driver.detach(self.buf) end
end
-- A sequence number alone is insufficient: undo/redo may revisit it. Every
-- observed edit/lifecycle transition clears this private receipt first.
function Editor:can_join_undo(plan)
    local receipt=self.undo_receipt
    if self.dead or not receipt or not self.driver.undo_state or type(plan)~='table'
        or plan.epoch~=self.epoch or plan.epoch~=receipt.epoch
        or plan.generation==nil or plan.grant==nil
        or plan.generation~=receipt.generation or plan.grant~=receipt.grant then return false end
    local native_state=self.driver.undo_state(self.buf)
    return native_state.sequence>0 and native_state.sequence==receipt.sequence and native_state.tick==receipt.tick
end

function Editor:apply(plan,validate)
    if self.in_callback or self.operation then return {status='busy',receipts={}} end
    if self.dead or not self.attached or plan.epoch~=self.epoch then return {status='stale',receipts={}} end
    assert(type(validate)=='function','authority validator required')
    for _,patch in ipairs(plan.patches) do
        if #patch.text>LIMIT or #patch.expected_old>LIMIT then return {status='chunkneeded',receipts={}} end
    end
    local operation={receipts={},validate=validate,plan=plan}
    self.operation=operation
    local status='applied'
    local ok,err=pcall(function()
        for i,patch in ipairs(plan.patches) do
            operation.patch=patch
            if not authorized(validate,plan,patch,'before') then status='stale'; break end
            local a,b=patch.start,patch.finish
            if self.driver.offset(self.buf,a.row)+a.col~=a.byte
                or self.driver.offset(self.buf,b.row)+b.col~=b.byte
                or b.byte-a.byte~=#patch.expected_old then status='stale'; break end
            local old=table.concat(self.reader:text(a.row,a.col,b.row,b.col,{}),'\n')
            if old~=patch.expected_old then status='stale'; break end
            local lines=split(patch.text)
            if self.driver.undo_break and self.driver.undo_join then
                if self:can_join_undo(plan) then self.driver.undo_join(self.buf)
                else self.driver.undo_break(self.buf) end
                if operation.unexpected or operation.revoked then status='interrupted'; break end
            end
            self.pending={patch=patch,new_end=endpoint(a.row,a.col,#lines-1,#lines[#lines],a.byte+#patch.text),
                owner={epoch=plan.epoch,generation=plan.generation,operation=plan.operation,grant=plan.grant,entity=plan.entity,patch=i}}
            self.driver.set_text(self.buf,a.row,a.col,b.row,b.col,lines)
            local seen=self.pending and self.pending.seen
            self.pending=nil
            if operation.unexpected or not seen then status='interrupted'; break end
            if operation.revoked then status='stale'; break end
            if self.driver.undo_break then self.driver.undo_break(self.buf) end
            if operation.unexpected or operation.revoked then status='interrupted'; break end
            if self.driver.undo_state then
                local undo=self.driver.undo_state(self.buf)
                self.undo_receipt={epoch=plan.epoch,generation=plan.generation,grant=plan.grant,
                    sequence=undo.sequence,tick=undo.tick}
            end
        end
    end)
    -- Close even a partial or mutate-then-error write so the next caller cannot
    -- accidentally inherit its native undo block.
    if self.driver.undo_break then
        local closed,close_error=pcall(self.driver.undo_break,self.buf)
        if not closed and ok then ok,err=false,close_error end
    end
    if not ok or status~='applied' or operation.unexpected or operation.revoked then self.undo_receipt=nil end
    self.pending,self.operation=nil,nil
    return {status=ok and status or 'error',receipts=operation.receipts,error=not ok and tostring(err) or nil}
end
return M
