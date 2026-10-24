local arrival = require('tests.helpers.arrival')
local fake = require('tests.helpers.fake_process_source')
local fixture_process = require('tests.helpers.fixture_process')
local uv = vim.uv or vim.loop
local stamp = 'Thu Oct 22 10:11:12 2026'

describe('bounded remote process evidence', function()
    local process, scratch, operations, mark
    local function wait_for(predicate) assert(vim.wait(arrival.MS, predicate, 10)) end
    local function observe(pids, options)
        local receipt = { count = 0 }
        local op = process.observe(pids, function(rows, status)
            receipt.rows, receipt.status, receipt.count = rows, status, receipt.count + 1
        end, options)
        operations[#operations + 1] = op
        receipt.operation = op
        return receipt
    end
    local function complete(receipt) wait_for(function() return receipt.status ~= nil end); return receipt end
    local function seed(value) vim.fn.writefile({ vim.json.encode(value) }, scratch .. '/snapshot.json') end
    local function native_options(extra)
        return vim.tbl_extend('force', { ps_binary = vim.fn.fnamemodify('tests/fixtures/fake_ps.py', ':p'),
            env = { PARLEY_FAKE_PS_STATE = scratch } }, extra or {})
    end
    local function requests()
        local result = {}
        if vim.fn.filereadable(scratch .. '/requests.jsonl') == 1 then
            for _, line in ipairs(vim.fn.readfile(scratch .. '/requests.jsonl')) do result[#result + 1] = vim.json.decode(line) end
        end
        return result
    end
    before_each(function()
        -- The first RED is an explicit missing-API assertion, not a loader error.
        local ok, module = pcall(require, 'parley.remote_process')
        process = ok and module or {}
        operations = {}
        mark = fixture_process.mark()
        scratch = vim.fn.tempname() .. '-remote-process'
        vim.fn.mkdir(scratch, 'p')
    end)
    after_each(function()
        for _, op in ipairs(operations) do op.cancel() end
        fixture_process.reap({ since = mark })
        vim.fn.delete(scratch, 'rf')
    end)
    it('exposes an asynchronous observation operation', function()
        assert.equals('function', type(process.observe))
        local source = fake.new({ [12] = { started = stamp } })
        local receipt = observe({12}, {source = source})
        assert.is_nil(receipt.status)
        complete(receipt)
        assert.same({ kind = 'alive', started = stamp }, receipt.rows[12])
        assert.equals('complete', receipt.status.kind)
    end)
    for _, count in ipairs({8, 16}) do
        it('batches and deduplicates ' .. count .. ' process identities', function()
            local records, pids = {}, {}
            for pid = 1, count do records[pid] = {started = stamp}; pids[#pids + 1] = pid; pids[#pids + 1] = pid end
            local source = fake.new(records)
            local receipt = complete(observe(pids, {source = source}))
            assert.equals(1, #source.reads)
            assert.equals(count, #source.reads[1].pids)
            for pid = 1, count do assert.equals('alive', receipt.rows[pid].kind); assert.equals(1, source.probes[pid]) end
        end)
    end
    it('rechecks explicit death and keeps contradictory live evidence unknown', function()
        local source = fake.new()
        source.hold = true
        local receipt = observe({12,13}, {source = source})
        source.set(13, {started = stamp})
        source.release()
        complete(receipt)
        assert.equals('dead', receipt.rows[12].kind)
        assert.equals('unknown', receipt.rows[13].kind)
    end)
    it('reports a reused pid with its current start stamp and never death', function()
        local source = fake.new({[12]={started=stamp}})
        source.set(12,{started='Fri Oct 23 10:11:12 2026'})
        local receipt = complete(observe({12},{source=source}))
        assert.same({kind='alive',started='Fri Oct 23 10:11:12 2026'},receipt.rows[12])
    end)
    it('never turns denied or missing ps evidence into death', function()
        local source = fake.new({ [12] = {kind='unknown',reason='EPERM'}, [13] = {started=stamp} })
        source.hold = true
        local receipt = observe({12,13}, {source=source})
        source.release(1, {code=0, stdout=''})
        complete(receipt)
        assert.equals('unknown', receipt.rows[12].kind)
        assert.equals('unknown', receipt.rows[13].kind)
    end)
    for _, response in ipairs({ {code=1,stdout='12 '..stamp}, {code=0,stdout='12 nonsense'},
        {code=0,stdout='12 '..stamp..'\n12 '..stamp}, {code=0,stdout='unexpected'} }) do
        it('refuses failed or malformed native evidence ' .. vim.inspect(response), function()
            local source = fake.new({ [12]={started=stamp} }); source.hold=true
            local receipt = observe({12}, {source=source})
            source.release(1,response); complete(receipt)
            assert.equals('unknown', receipt.rows[12].kind)
        end)
    end
    it('cancels once and ignores stale held completion', function()
        local source = fake.new({ [12]={started=stamp} }); source.hold=true
        local receipt = observe({12}, {source=source})
        receipt.operation.cancel(); receipt.operation.cancel(); complete(receipt)
        assert.equals('canceled', receipt.status.kind)
        assert.equals('unknown', receipt.rows[12].kind)
        assert.is_true(source.pending[1].canceled)
        source.release(); vim.wait(20, function() return false end) -- absence: duplicate completion must not deliver
        assert.equals(1, receipt.count)
    end)
    it('expires held observations and cancels their read', function()
        local source = fake.new({ [12]={started=stamp} }); source.hold=true
        local receipt = complete(observe({12}, {source=source,deadline_ms=20}))
        assert.equals('unknown', receipt.status.kind)
        assert.equals('unknown', receipt.rows[12].kind)
        assert.is_true(source.pending[1].canceled)
        source.release(); assert.equals(1, receipt.count)
    end)
    it('measures its deadline from now even after the loop was blocked (#421)', function()
        local source = fake.new({ [12]={started=stamp} }); source.hold=true
        -- Synchronous work leaves libuv's cached clock 1.2 s behind; a timer
        -- armed from that stale clock would expire this 1 s deadline at once.
        local stop = uv.hrtime() + 1200 * 1e6
        while uv.hrtime() < stop do end
        local receipt = observe({12}, {source=source,deadline_ms=1000})
        vim.wait(100, function() return false end) -- absence: a stale-clock deadline fires in the first loop turns
        assert.is_nil(receipt.status, vim.inspect(receipt.status))
        source.release(); complete(receipt)
        assert.equals('complete', receipt.status.kind, vim.inspect(receipt.status))
        assert.equals('alive', receipt.rows[12].kind)
    end)
    it('copies caller pid and environment inputs', function()
        local source = fake.new({ [12]={started=stamp} }); source.hold=true
        local pids, env = {12}, {KEY='original'}
        local receipt = observe(pids, {source=source,env=env})
        pids[1], env.KEY = 13, 'changed'
        source.release(); complete(receipt)
        assert.equals('alive', receipt.rows[12].kind)
        assert.equals('original', source.reads[1].options.env.KEY)
    end)
    it('rejects invalid pid values and oversized batches without inspection', function()
        for _, pids in ipairs({ {0}, {-1}, {'12'}, {1.5}, {math.huge}, vim.fn.range(1,257) }) do
            local source = fake.new()
            local receipt = complete(observe(pids,{source=source}))
            assert.equals('unknown',receipt.status.kind)
            assert.equals(0,#source.reads)
        end
    end)
    it('uses targeted argv and the C locale through the executable seam', function()
        local pid = vim.fn.getpid()
        seed({rows={ [tostring(pid)]=stamp }})
        local receipt = complete(observe({pid,pid},native_options()))
        assert.same({kind='alive',started=stamp},receipt.rows[pid])
        assert.same({'-p',tostring(pid),'-o','pid=','-o','lstart='},requests()[1].argv)
        assert.equals('C', requests()[1].locale)
    end)
    it('reports unavailable ps as unknown', function()
        local receipt = complete(observe({vim.fn.getpid()}, {ps_binary=scratch..'/absent'}))
        assert.equals('unknown', receipt.rows[vim.fn.getpid()].kind)
    end)
    it('joins a timed out executable child before delivering its result', function()
        seed({rows={},delay_ms=10000})
        local receipt = observe({vim.fn.getpid()}, native_options())
        wait_for(function() return #requests()==1 end)
        local child = requests()[1].pid
        complete(receipt)
        assert.equals('unknown', receipt.status.kind)
        local alive, err = uv.kill(child,0)
        assert.is_nil(alive); assert.matches('ESRCH',err)
    end)
    it('joins an explicitly canceled executable child before reporting canceled', function()
        seed({rows={},delay_ms=10000})
        local receipt = observe({vim.fn.getpid()}, native_options({deadline_ms=5000}))
        wait_for(function() return #requests()==1 end)
        local child = requests()[1].pid
        receipt.operation.cancel(); complete(receipt)
        assert.equals('canceled',receipt.status.kind)
        local alive, err = uv.kill(child,0)
        assert.is_nil(alive); assert.matches('ESRCH',err)
    end)
    it('agrees with native liveness for a real live then reaped child', function()
        local handle, exited, err, pid = fixture_process.spawn('/bin/sleep', {'30'})
        assert.is_not_nil(handle,err)
        local live = complete(observe({pid}))
        assert.equals('alive',live.rows[pid].kind)
        assert.is_true(#live.rows[pid].started > 0)
        handle:kill('sigkill'); wait_for(exited)
        local dead = complete(observe({pid}))
        assert.equals('dead',dead.rows[pid].kind)
    end)
end)
