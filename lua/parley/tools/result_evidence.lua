-- Body limits must never hide evidence that bytes or editor reconciliation are
-- missing. Fixed notices are metadata: at most 72 bytes per published result
-- (9,216 across the 128-record ceiling), even when body capacity is zero.
local M={}
local incomplete='[Tool result incomplete]\n'
local reconciliation='[Disk updated; buffer reconciliation required]\n'
local function copy(value)
    local out={};for k,v in pairs(value or {})do out[k]=v end;return out
end
local function body(value)
    local content=value.content or ''
    if value.truncated and content:sub(1,#incomplete)==incomplete then content=content:sub(#incomplete+1)end
    if value.reconciliation_required and content:sub(1,#reconciliation)==reconciliation then
        content=content:sub(#reconciliation+1)
    end
    return content
end
function M.cap(value,budget)
    local out=copy(value);out.content=body(out)
    if budget and #out.content>budget then out.content=out.content:sub(1,budget);out.truncated=true end
    return out
end
function M.publish(value,budget)
    local out=M.cap(value,budget)
    local notice=(out.truncated and incomplete or '')..(out.reconciliation_required and reconciliation or '')
    if budget and #out.content+#notice>budget then
        out.truncated=true
        notice=incomplete..(out.reconciliation_required and reconciliation or '')
        out.content=out.content:sub(1,math.max(0,budget-#notice))
    end
    out.content=notice..out.content
    return out
end
M.notice_bytes=#incomplete+#reconciliation
return M
