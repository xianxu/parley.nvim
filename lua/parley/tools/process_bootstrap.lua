-- Start a builtin inside a child pinned to its admitted filesystem identity.
-- The child owns all descriptors; Tasker owns its exit and output-drain lifetime.
local M={}
local source=vim.fn.fnamemodify(debug.getinfo(1,'S').source:sub(2),':p')
local root=assert(source:match('^(.*)/lua/parley/tools/process_bootstrap%.lua$'))
function M.command(plan,authority)
    local evidence,err=require('parley.tools.path_authority').export(authority)
    if not evidence then return nil,err end
    local payload=vim.json.encode({authority=evidence,path=plan.path,command=plan.command,
        target_position=plan.target_position})
    if #payload>65536 then return nil,'scoped process authority capacity'end
    return {vim.v.progpath,'-u','NONE','--noplugin','-i','NONE','-n','--headless',
        '-l',root..'/scripts/tool_process.lua',payload}
end
return M
