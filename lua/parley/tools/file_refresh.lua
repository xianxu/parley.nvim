-- Refresh only captured buffers from positively committed bytes. No pathname is
-- reopened and no global checktime can overwrite a sibling's human edits.
local M={}
local states=setmetatable({},{__mode='k'})
local Edit=require('parley.buffer_edit')
local function canonical(path)return vim.fn.resolve(vim.fn.fnamemodify(path,':p'))end
function M.capture(path)
    local ticket={};local s={path=canonical(path),buffers={}}
    for _,buf in ipairs(vim.api.nvim_list_bufs())do
        if vim.api.nvim_buf_is_loaded(buf) and canonical(vim.api.nvim_buf_get_name(buf))==s.path then
            local old={buf=buf,name=vim.api.nvim_buf_get_name(buf),tick=vim.api.nvim_buf_get_changedtick(buf),
                modified=vim.bo[buf].modified,autoread=vim.bo[buf].autoread,fileformat=vim.bo[buf].fileformat,encoding=vim.bo[buf].fileencoding}
            if require('parley.document').get(buf)then
                local count=vim.api.nvim_buf_line_count(buf)
                local last=vim.api.nvim_buf_get_offset(buf,count)-vim.api.nvim_buf_get_offset(buf,count-1)-1
                old.proof=Edit.capture_user(buf,'file-tool-refresh',{{first={row=0,col=0},last={row=count-1,col=last}}})
                old.document=true
            end
            s.buffers[#s.buffers+1]=old
        end
    end
    states[ticket]=s;return ticket
end
local function decode(bytes,format)
    if bytes:find('\0',1,true)then return nil end
    local bomb=bytes:sub(1,3)=='\239\187\191'
    if bomb then bytes=bytes:sub(4)end
    local eol=bytes:sub(-1)=='\n'
    if bytes:find('\r\n',1,true) and not bytes:gsub('\r\n',''):find('\n',1,true)then
        bytes=bytes:gsub('\r\n','\n');format='dos'
    elseif format=='mac' and not bytes:find('\n',1,true)then
        eol=bytes:sub(-1)=='\r';bytes=bytes:gsub('\r','\n')
    else format='unix'end
    local lines={};for line in (bytes..'\n'):gmatch('([^\n]*)\n')do lines[#lines+1]=line end
    if eol then table.remove(lines)end
    if #lines==0 then lines[1]=''end
    return lines,format,eol,bomb
end
local function dispose(s)
    for _,old in ipairs(s.buffers)do if old.proof then Edit.cancel_user(old.proof);old.proof=nil end end
end
function M.complete(ticket,bytes)
    local s=states[ticket];states[ticket]=nil
    if not s then return {reconciliation_required=true}end
    local reconciliation=false
    for _,old in ipairs(s.buffers)do
        local buf=old.buf
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)then
            local lines,format,eol,bomb=decode(bytes,old.fileformat)
            local safe=lines and (old.encoding=='' or old.encoding=='utf-8') and vim.api.nvim_buf_get_name(buf)==old.name
                and vim.api.nvim_buf_get_changedtick(buf)==old.tick and not old.modified
                and not vim.bo[buf].modified and old.autoread and vim.bo[buf].autoread
                and (not old.document or old.proof and Edit.resolve_user(old.proof))
            if safe then
                local ok,receipt=pcall(function()
                    if old.document then return Edit.apply_user(old.proof,{{region=1,text=table.concat(lines,'\n')}})end
                    Edit.replace_all_lines(buf,lines);return {status='applied'}
                end)
                local function matches()
                    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)
                        and vim.api.nvim_buf_get_name(buf)==old.name
                        and vim.api.nvim_buf_get_changedtick(buf)==old.tick+1
                        and vim.deep_equal(vim.api.nvim_buf_get_lines(buf,0,-1,false),lines)
                end
                if ok and receipt.status=='applied' and matches()then
                    local metadata_ok=pcall(function()
                        vim.bo[buf].fileformat=format;vim.bo[buf].endofline=eol;vim.bo[buf].bomb=bomb
                        if matches()then vim.bo[buf].modified=false else reconciliation=true end
                    end)
                    if not metadata_ok then reconciliation=true end
                    if not matches()then
                        reconciliation=true
                        if vim.api.nvim_buf_is_valid(buf)then vim.bo[buf].modified=true end
                    end
                else reconciliation=true end
            else reconciliation=true end
        end
    end
    dispose(s)
    return {reconciliation_required=reconciliation or nil}
end
function M.pending(ticket)local s=states[ticket];return s and #s.buffers>0 or false end
function M.release(ticket)
    local s=states[ticket];states[ticket]=nil;if s then dispose(s)end
end
return M
