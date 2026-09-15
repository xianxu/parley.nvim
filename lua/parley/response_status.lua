-- Bounded display-only annotations. Extmarks move with native edits; no redraw
-- or edit callback scans source. Reload retires all runtime stale evidence.
local D=require('parley.document')
local M={}
local ns=vim.api.nvim_create_namespace('parley_response_status')
local groups={}
function M.update(buf,doc,value)
    if D.get(buf)~=doc or D.snapshot(doc).epoch~=value.epoch then return end
    if not value.stale_input then
        local group=groups[buf]
        if group and group.marks[value.exchange] and value.phase=='preparing' then
            pcall(vim.api.nvim_buf_del_extmark,buf,ns,group.marks[value.exchange])
            group.marks[value.exchange]=nil
            for i,id in ipairs(group.order)do if id==value.exchange then table.remove(group.order,i);break end end
        end
        return
    end
    local marker=D.lookup(doc,value.exchange)
    if not marker or marker.opaque then return end
    local group=groups[buf]
    if not group then
        group={marks={},order={}};groups[buf]=group
        group.off=D.subscribe(doc,function(event)
            if event.kind=='reload' or event.kind=='detach' then
                if vim.api.nvim_buf_is_valid(buf)then vim.api.nvim_buf_clear_namespace(buf,ns,0,-1)end
                groups[buf]=nil;group.off();group.off=nil
            end
        end)
    end
    local id=group.marks[value.exchange]
    if not id then
        if #group.order>=256 then
            local old=table.remove(group.order,1)
            pcall(vim.api.nvim_buf_del_extmark,buf,ns,group.marks[old]);group.marks[old]=nil
        end
        group.order[#group.order+1]=value.exchange
    end
    local text=value.phase=='paused' and ' [input changed; paused — :ParleyChatResumeResponse]'
        or ' [input changed; answer uses original input]'
    group.marks[value.exchange]=vim.api.nvim_buf_set_extmark(buf,ns,marker.start_row,0,
        {id=id,end_row=marker.start_row+1,end_col=0,invalidate=true,
            virt_text={{text,'DiagnosticWarn'}},virt_text_pos='eol',right_gravity=false})
end
return M
