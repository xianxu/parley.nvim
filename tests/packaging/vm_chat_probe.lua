local phase = assert(vim.env.PARLEY_VM_PHASE)
local ok, evidence = pcall(function()
    return dofile(vim.env.HOME .. '/.parley-acceptance/vm_chat.lua').run(phase)
end)
if not ok then evidence = {status = 'failed', phase = phase} end
vim.fn.writefile({vim.json.encode(evidence)}, vim.env.HOME .. '/.parley-acceptance/phase.json')
if not ok then vim.cmd('cquit 1') end
if evidence.status == 'auth_pending' then vim.cmd('cquit 75') end
vim.cmd('qa!')
