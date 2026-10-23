-- #420: evidence from inside one synchronous fixture RPC, readable even after
-- embedded_nvim kills that child. This never changes its request deadline.
local M = {}
local uv = vim.uv or vim.loop
local LIMIT = 16384
local FIELDS = {'repair_steps', 'native_fold_ops', 'fold_groups_visited',
    'index_nodes_visited', 'index_entries_visited', 'structure_rows_processed',
    'structure_entries_copied', 'bytes_read', 'returned_lines'}

local function read(path, tail)
    local file = io.open(path, 'rb')
    if not file then return nil end
    if tail then
        local size = file:seek('end')
        file:seek('set', math.max(0, size - LIMIT))
    end
    local text = file:read(LIMIT)
    file:close()
    return text
end

function M.new()
    local root = assert(uv.fs_mkdtemp((vim.env.TMPDIR or '/tmp') .. '/fold-retirement.XXXXXX'))
    local parent = {root=root, path=root .. '/stage.json'}
    function parent:read()
        local ok, result = pcall(vim.json.decode, read(self.path) or '')
        if not ok or type(result) ~= 'table' or type(result.stage) ~= 'string' then
            result = {stage='not captured'}
        end
        local profile = read(self.path .. '.jit', true)
        result.profile = profile and profile:match('([^\n]+)\n?$') or 'no sample yet'
        return result
    end
    function parent:run(child, code, ...)
        local started = uv.hrtime()
        local ok, result = pcall(child.exec, child, code, self.path, ...)
        local snapshot = self:read()
        snapshot.request_wall_ms = (uv.hrtime()-started)/1e6
        local evidence = vim.json.encode(snapshot)
        io.stdout:write('FOLD_RETIREMENT ' .. evidence .. '\n'); io.stdout:flush()
        if not ok then error(tostring(result) .. '\nFOLD_RETIREMENT ' .. evidence, 0) end
        return result
    end
    function parent:close() vim.fn.delete(self.root, 'rf') end
    return parent
end

function M.start(path)
    local started, cpu = uv.hrtime(), os.clock()
    local trace = {work={}, next_repair=1}
    local runtime = {nvim=tostring(vim.version()), jit=jit.version, arch=jit.arch, os=jit.os}
    -- Reuse the existing VM profiler: its callback still runs while synchronous
    -- Lua work prevents libuv timers from running. One line/second, bounded by
    -- the unchanged request deadline; all files die with the parent fixture.
    vim.env.PARLEY_TEST_JITSTAT_LOG = path .. '.jit'
    require('tests.helpers.jit_watch').install(1)
    function trace:count(event)
        for _, key in ipairs(FIELDS) do self.work[key] = (self.work[key] or 0) + (event[key] or 0) end
    end
    function trace:stage(stage)
        local evidence = {stage=stage, pid=uv.os_getpid(), runtime=runtime,
            wall_ms=(uv.hrtime()-started)/1e6, cpu_ms=(os.clock()-cpu)*1000,
            load={uv.loadavg()}, work=self.work}
        local file = assert(io.open(path .. '.pending', 'wb'))
        assert(file:write(vim.json.encode(evidence))); assert(file:close())
        assert(os.rename(path .. '.pending', path))
    end
    function trace:observe(document, doc, buf)
        local reader = require('parley.line_reader')
        local token = reader.set_observer(buf, function(event) self:count(event) end)
        local unsubscribe = document.subscribe(doc, function(event)
            if event.kind ~= 'repair' then return end
            self:count({repair_steps=1})
            -- Powers of two retain progress with at most 18 writes in the
            -- fixture's existing 200,000-step cap; no per-row disk writes.
            if self.work.repair_steps == self.next_repair then
                self.next_repair = self.next_repair * 2
                self:stage('repair-progress')
            end
        end)
        self.cleanup = function() reader.clear_observer(buf, token); unsubscribe() end
    end
    function trace:finish()
        if self.cleanup then self.cleanup(); self.cleanup=nil end
        self:stage('complete')
    end
    trace:stage('entered')
    return trace
end

return M
