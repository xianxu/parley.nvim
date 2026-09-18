-- Operator reconciliation records observed effect evidence. It cannot invent
-- process exit/descriptor cleanup or rerun an operation.
local M={}
function M.open()
    local producer=require('parley.tools.producer')
    local choices=producer.list()
    if #choices==0 then vim.notify('No retained tool operations');return end
    local admitted={};for _,value in ipairs(choices)do admitted[value]=true end
    vim.ui.select(choices,{prompt='Tool operations:',format_item=function(value)
        return tostring(value.name or 'tool')..' ['..tostring(value.id)..'] — '..tostring(value.certainty)..', cleanup '..
            (value.physical_resolved and 'confirmed' or 'unresolved')
    end},function(value)
        if not value or not admitted[value] then return end
        local actions={'Inspect','Record confirmed effect'}
        vim.ui.select(actions,{prompt='Operation '..tostring(value.id)},function(action)
            if action=='Inspect' then
                vim.notify(vim.inspect(value));return
            end
            if action~='Record confirmed effect' then return end
            local effects={'applied','not_applied','partial'}
            vim.ui.select(effects,{prompt='Effect independently verified (Esc changes nothing):'},function(effect)
                if not vim.tbl_contains(effects,effect)then return end
                vim.ui.input({prompt='Describe the evidence you inspected: '},function(evidence)
                    if type(evidence)~='string' or not evidence:match('%S')then return end
                    if #evidence>4096 then vim.notify('Evidence exceeds 4096 bytes',vim.log.levels.WARN);return end
                    local ok=producer.reconcile(value.id,{certainty='known',effect=effect,
                        evidence={operator=evidence},result={content='Operator confirmed '..effect..': '..evidence,
                            is_error=effect~='applied'}})
                    -- #266 M3: only a tool whose process still runs holds its resources.
                    vim.notify(ok and ('Effect recorded.'..(value.physical_resolved and ''
                        or ' Its resources stay held until its process ends.'))
                        or 'Operation changed or evidence was refused',ok and vim.log.levels.INFO or vim.log.levels.WARN)
                end)
            end)
        end)
    end)
end
return M
