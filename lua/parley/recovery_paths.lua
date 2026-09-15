-- Shared private-artifact boundary for store placement and provider attachments.
-- Compare canonical paths, including aliases to an existing parent of a missing
-- leaf. String-prefix siblings must not inherit the private directory's policy.
local M={}
function M.directory(state_dir)
    if type(state_dir)~='string' or state_dir==''then return nil end
    return state_dir:gsub('/+$','')..'/answer-recovery'
end
local function canonical(path)
    if type(path)~='string' or path==''then return nil end
    local uv=vim.uv or vim.loop
    local current=vim.fn.fnamemodify(path,':p'):gsub('/+$','')
    local suffix={}
    while current~=''do
        local resolved=uv.fs_realpath(current)
        if resolved then
            for index=#suffix,1,-1 do resolved=resolved..'/'..suffix[index]end
            return resolved:gsub('/+$','')
        end
        local parent=vim.fn.fnamemodify(current,':h')
        if parent==current then break end
        suffix[#suffix+1]=vim.fn.fnamemodify(current,':t');current=parent
    end
    return nil
end
function M.is_private(path,state_dir)
    local directory=M.directory(state_dir);if not directory then return false end
    local root,value=canonical(directory),canonical(path)
    return root~=nil and value~=nil and (value==root or value:sub(1,#root+1)==root..'/')
end
return M
