local records
local function copy(value) return vim.deepcopy(value) end
local function record()
    return { Version = 1, EditorIncarnation = string.rep('a', 32), PID = 123,
        Started = 'Thu Oct 22 05:00:00 2026',
        Directory = { Name = 'e-ABC123', Device = 1, Inode = 7 },
        Sockets = { { Name = 's1', State = 'listening', Device = 1, Inode = 8 } } }
end
local function facts()
    return { uid = 501, directory = { type = 'directory', uid = 501, mode = 16832, dev = 1, ino = 7 },
        process = { kind = 'dead' }, entries = { 'owner.json', 's1' },
        sockets = { s1 = { type = 'socket', uid = 501, dev = 1, ino = 8 } } }
end

describe('private RPC runtime ownership records', function()
    before_each(function()
        local ok, module = pcall(require, 'parley.remote_runtime_record')
        records = ok and module or setmetatable({}, { __index = function()
            return function() assert.is_true(false, 'runtime ownership record module is missing') end
        end })
    end)

    it('retains unknown root and nested fields through decode and encode', function()
        local value = record()
        value.Future = { enabled = true }
        value.Directory.Future = 'nested'
        value.Sockets[1].Future = { 1, 2 }
        local parsed = assert(records.decode(vim.json.encode(value)))
        assert.same(value, parsed)
        assert.same(value, assert(records.decode(assert(records.encode(parsed)))))
        parsed.Future.enabled = false
        assert.is_true(value.Future.enabled)
    end)

    it('rejects malformed, truncated and duplicate JSON members', function()
        local good = vim.json.encode(record())
        for _, bytes in ipairs({ '', '{', good:sub(1, -2), good:gsub('"PID":123', '"PID":123,"PID":456'),
            good:gsub('"Name":"s1"', '"Name":"s1","Name":"s2"'),
            good:gsub('"PID":123', '"PID":123,"\\u0050ID":456') }) do
            assert.is_nil(records.decode(bytes), bytes)
        end
    end)

    it('rejects invalid marker identities and known field types', function()
        for _, field in ipairs({ 'Version', 'EditorIncarnation', 'PID', 'Started', 'Directory', 'Sockets' }) do
            local value = record(); value[field] = false
            assert.is_nil(records.decode(vim.json.encode(value)), field)
        end
        for _, bad in ipairs({ 0, -1, 1.5, '123' }) do
            local value = record(); value.PID = bad
            assert.is_nil(records.decode(vim.json.encode(value)))
        end
    end)

    it('refuses unsafe directory and socket names', function()
        for _, name in ipairs({ '', '..', '../s1', '/s1', 's1/child', 's1\0x' }) do
            local value = record(); value.Sockets[1].Name = name
            assert.is_nil(records.decode(vim.json.encode(value)), name)
        end
        local value = record(); value.Directory.Name = '../e-ABC123'
        assert.is_nil(records.decode(vim.json.encode(value)))
    end)

    it('bounds marker bytes and socket declarations', function()
        local value = record(); value.Future = string.rep('x', 32768)
        assert.is_nil(records.decode(vim.json.encode(value)))
        value = record(); value.Sockets = {}
        for i = 1, 257 do value.Sockets[i] = { Name = 's' .. i, State = 'reserved' } end
        assert.is_nil(records.decode(vim.json.encode(value)))
    end)

    it('requires dense unique socket declarations', function()
        local value = record(); value.Sockets[2] = copy(value.Sockets[1])
        assert.is_nil(records.decode(vim.json.encode(value)))
        value = record(); value.Sockets = { strange = value.Sockets[1] }
        assert.is_nil(records.decode(vim.json.encode(value)))
    end)

    it('validates all ownership numbers and declaration states in encode as well as decode', function()
        for _, change in ipairs({
            function(v) v.EditorIncarnation = string.rep('A', 32) end,
            function(v) v.Started = '' end,
            function(v) v.Directory.Device = 0 end,
            function(v) v.Directory.Inode = '7' end,
            function(v) v.Sockets[1].Device = nil end,
            function(v) v.Sockets[1].Inode = -1 end,
            function(v) v.Sockets[1].State = 'unknown' end,
            function(v) v.Sockets[1].Name = 's01' end,
            function(v) v.Sockets[1].Name = 's0' end,
            function(v) v.Sockets[1].Name = 's1.0' end,
            function(v) v.Sockets[1] = { Name = 's1', State = 'reserved', Device = false } end,
        }) do
            local value = record(); change(value)
            assert.is_nil(records.decode(vim.json.encode(value)))
            local bytes, err = records.encode(value)
            assert.is_nil(bytes)
            assert.is_string(err)
        end
        local value = record(); value.PID = math.huge
        assert.is_nil(records.encode(value))
        value = record(); value.PID = 0 / 0
        assert.is_nil(records.encode(value))
    end)

    it('rejects escaped duplicate fields at every object depth', function()
        local good = vim.json.encode(record())
        local candidates = {
            good:gsub('"Device":1', '"Device":1,"\\u0044evice":2', 1),
            good:gsub('"State":"listening"', '"State":"listening","\\u0053tate":"reserved"'),
            good:gsub('"Version":1', '"Future":1,"Future":2,"Version":1'),
            '[' .. good .. ']',
            good .. ' trailing',
            good:gsub('"Version":1', '"Future":NaN,"Version":1'),
            good:gsub('"Version":1', '"Future":Infinity,"Version":1'),
        }
        for _, bytes in ipairs(candidates) do assert.is_nil(records.decode(bytes), bytes) end
    end)

    it('preserves escaped strings and nested nulls without confusing members', function()
        local value = record()
        value.Future = { text = '"PID":123, { [ ] } \\ unicode: é', missing = vim.NIL }
        assert.same(value, assert(records.decode(assert(records.encode(value)))))
    end)

    it('plans only exact declared dead-owner artifacts', function()
        local value, observed = record(), facts()
        local plan = records.cleanup(value, observed)
        assert.equals('reclaim', plan.kind)
        assert.same({ 's1' }, plan.sockets)
        assert.equals('owner.json', plan.marker)
        assert.is_true(plan.rmdir_empty)
        assert.same(record(), value)
    end)

    it('retains live, reused and uncertain process owners', function()
        for _, process in ipairs({ { kind = 'alive', started = record().Started },
            { kind = 'alive', started = 'new process' }, { kind = 'unknown', reason = 'denied' }, {} }) do
            local observed = facts(); observed.process = process
            local plan = records.cleanup(record(), observed)
            assert.equals('retain', plan.kind)
            assert.is_nil(plan.sockets)
        end
    end)

    it('requires the exact physical private directory identity', function()
        for _, change in ipairs({ { type = 'link' }, { uid = 502 }, { mode = 16877 }, { dev = 2 }, { ino = 9 } }) do
            local observed = facts()
            for key, value in pairs(change) do observed.directory[key] = value end
            assert.equals('retain', records.cleanup(record(), observed).kind)
        end
    end)

    it('retains foreign or replaced declared socket entries', function()
        for _, change in ipairs({ { type = 'file' }, { type = 'link' }, { uid = 502 }, { dev = 2 }, { ino = 99 } }) do
            local observed = facts()
            for key, value in pairs(change) do observed.sockets.s1[key] = value end
            assert.equals('retain', records.cleanup(record(), observed).kind)
        end
    end)

    it('leaves unlisted entries untouched', function()
        local observed = facts(); observed.entries[3] = 'foreign.sock'
        assert.equals('retain', records.cleanup(record(), observed).kind)
    end)

    it('retains missing or inconsistent observations without guessing absence', function()
        for _, change in ipairs({
            function(v) v.directory = nil end,
            function(v) v.uid = nil end,
            function(v) v.process = nil end,
            function(v) v.entries = nil end,
            function(v) v.sockets = nil end,
            function(v) v.sockets.s1 = nil end,
            function(v) v.entries = { 'owner.json', 's1', 's1' } end,
            function(v) v.entries = { 'owner.json', '../s1' } end,
            function(v) v.sockets.foreign = v.sockets.s1 end,
        }) do
            local observed = facts(); change(observed)
            assert.equals('retain', records.cleanup(record(), observed).kind)
        end
        assert.equals('retain', records.cleanup({}, facts()).kind)
    end)

    it('returns independent cleanup plans and never mutates facts', function()
        local value, observed = record(), facts()
        local before = copy(observed)
        local plan = records.cleanup(value, observed)
        plan.sockets[1] = 'foreign'
        assert.same({ 's1' }, records.cleanup(value, observed).sockets)
        assert.same(before, observed)
    end)

    it('allows absent declared sockets and reserved pre-effect socket names', function()
        local value, observed = record(), facts()
        observed.sockets.s1 = nil; observed.entries = { 'owner.json' }
        assert.equals('reclaim', records.cleanup(value, observed).kind)
        value.Sockets[1] = { Name = 's1', State = 'reserved' }
        observed = facts()
        assert.equals('reclaim', records.cleanup(value, observed).kind)
    end)
end)
