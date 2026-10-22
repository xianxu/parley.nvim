-- Stateful backend for remote_process.observe: kernel records and ps snapshots
-- deliberately evolve separately, exposing death/reuse during an in-flight read.
local M = {}
function M.new(records)
    local self = { records = vim.deepcopy(records or {}), reads = {}, probes = {}, pending = {}, hold = false }
    function self.probe(pid)
        self.probes[pid] = (self.probes[pid] or 0) + 1
        local record = self.records[pid]
        return vim.deepcopy(record and { kind = record.kind or 'alive', reason = record.reason }
            or { kind = 'dead' })
    end
    function self.set(pid, record) self.records[pid] = vim.deepcopy(record) end
    function self.release(index, override)
        local request = self.pending[index or 1]
        if not request then return end
        request.callback(override or request.result)
        request.delivered = true
    end
    function self.read(pids, callback, options)
        self.reads[#self.reads + 1] = { pids = vim.deepcopy(pids), options = vim.deepcopy(options) }
        local lines = {}
        for _, pid in ipairs(pids) do
            local record = self.records[pid]
            if record and (record.kind or 'alive') == 'alive' then
                lines[#lines + 1] = tostring(pid) .. ' ' .. (record.started or 'Thu Oct 22 10:11:12 2026')
            end
        end
        local request = { callback = callback, result = { code = 0, stdout = table.concat(lines, '\n') }, canceled = false }
        self.pending[#self.pending + 1] = request
        local index = #self.pending
        if not self.hold then vim.schedule(function() if not request.canceled then self.release(index) end end) end
        return { cancel = function(on_joined)
            request.canceled = true
            if on_joined then on_joined() end
        end }
    end
    return self
end
return M
