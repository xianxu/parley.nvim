local Processes = require("tests.helpers.test_processes")
local Identity = require("tests.helpers.process_identity")
local uv = vim.uv or vim.loop

-- Stateful native seam: signals and observation races change the same world.
local function world()
    local w = { live = {}, probes = 0, signals = {}, clock = 0 }
    w.deps = {
        observe = function(pid)
            w.probes = w.probes + 1
            if w.on_probe then w.on_probe(pid) end
            local value = w.live[pid]
            if value == false then return { kind = "unknown", reason = "permission denied" } end
            return value and { kind = "live", start = value } or { kind = "absent" }
        end,
        signal = function(pid, name)
            w.signals[#w.signals + 1] = { pid, name }
            if w.denied then return nil, "EPERM" end
            if name == "sigkill" then w.live[pid] = nil end
            return true
        end,
        now = function() return w.clock end,
        wait = function(ms) w.clock = w.clock + ms end,
        grace_ms = 40, join_ms = 40,
    }
    return w
end

describe("retained birth registry", function()
    local dir, cap
    before_each(function()
        dir, cap = vim.fn.tempname(), Processes.MAX_RECORDS
        vim.fn.mkdir(dir, "p", 448)
    end)
    after_each(function()
        Processes.MAX_RECORDS = cap
        vim.fn.delete(dir, "rf")
    end)
    local function born(pid, start)
        local ticket = assert(Processes.prepare(dir))
        assert(Processes.complete(ticket, pid, function() return { kind = "live", start = start } end))
        return ticket
    end

    it("persists unknown before any spawn and leaves interrupted publication intact", function()
        local ticket = assert(Processes.prepare(dir))
        local w = world()
        local before = vim.fn.readfile(ticket)
        local result = Processes.reconcile(dir, w.deps)
        assert.is_false(result.ok)
        assert.is_true(result.unknown)
        assert.equals(0, w.probes)
        assert.same({}, w.signals)
        assert.same(before, vim.fn.readfile(ticket))
        assert.is_nil(Processes.complete(ticket, 7, function() return { kind = "unknown" } end))
        assert.equals("pending", Processes.read(dir)[1].record.state)
    end)

    it("preserves future nested fields through atomic pending to born publication", function()
        local ticket = assert(Processes.prepare(dir))
        vim.fn.writefile({ '{"version":1,"state":"pending","future":{"nested":[true,{"x":2}]}}' }, ticket)
        assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10.000001" } end))
        assert.same({ nested = { true, { x = 2 } } }, Processes.read(dir)[1].record.future)
    end)

    it("preserves future JSON null members through publication", function()
        local ticket = assert(Processes.prepare(dir))
        vim.fn.writefile({ '{"version":1,"state":"pending","future":{"value":null,"items":[null]}}' }, ticket)
        assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10" } end))
        local body = table.concat(vim.fn.readfile(ticket), "\n")
        local value = vim.json.decode(body)
        assert.equals(vim.NIL, value.future.value)
        assert.equals(vim.NIL, value.future.items[1])
    end)

    it("round trips generated future JSON structures and preserves empty container kinds", function()
        for seed = 1, 32 do
            local ticket = assert(Processes.prepare(dir))
            local future = { ['key' .. seed] = { '[]{}:"\\\n' .. seed, vim.NIL, { seed, seed % 2 == 0 } } }
            vim.fn.writefile({ vim.json.encode({ version = 1, state = "pending", future = future }) }, ticket)
            assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10" } end))
            assert.same(future, Processes.read(dir)[1].record.future)
            assert(Processes.abort(ticket))
        end
        local ticket = assert(Processes.prepare(dir))
        vim.fn.writefile({ '{"version":1,"state":"pending","future":{"object":{},"array":[]}}' }, ticket)
        assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10" } end))
        local body = table.concat(vim.fn.readfile(ticket), "\n")
        assert.is_truthy(body:find('"object":{}', 1, true), body)
        assert.is_truthy(body:find('"array":[]', 1, true), body)
    end)

    it("preserves unknown JSON numeric tokens without a lossy decoder oracle", function()
        for _, future in ipairs({
            '9007199254740993', '-9007199254740993', '0.123456789012345678901234567890',
            '{"nested":[9007199254740993,1.234567890123456789e+27,-0,1E-99]}',
        }) do
            local ticket = assert(Processes.prepare(dir))
            local member = '"future" : ' .. future
            vim.fn.writefile({ '{"version":1,"state":"pending",' .. member .. '}' }, ticket)
            assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10" } end))
            local body = table.concat(vim.fn.readfile(ticket), "\n")
            assert.is_truthy(body:find(member, 1, true), body)
            assert.equals("born", Processes.read(dir)[1].record.state)
            assert(Processes.abort(ticket))
        end
    end)

    it("refuses malformed, duplicated or unresolved storage without effects", function()
        for _, body in ipairs({ '{}', '{"version":1,"version":1,"state":"pending"}',
            '{"version":1,"state":"pending","future":{"x":1,"x":2}}',
            '{"version":1,"state":"pending","future":{"x":1,"\\u0078":2}}',
            '{"version":1,"state":"born","pid":7,"start":null}', 'partial', string.rep(" ", 257) }) do
            vim.fn.writefile({ body }, dir .. "/1.json")
            local w = world()
            local result = Processes.reconcile(dir, w.deps)
            assert.is_false(result.ok, body)
            assert.is_true(result.unknown, body)
            assert.same({}, w.signals)
            assert.equals(1, vim.fn.filereadable(dir .. "/1.json"))
        end
        vim.fn.delete(dir .. "/1.json")
        vim.fn.writefile({ "torn publication" }, dir .. "/1.json.new")
        assert.is_false(Processes.reconcile(dir, world().deps).ok)
    end)

    it("refuses persisted identifiers outside native pid_t before observation", function()
        vim.fn.writefile({ '{"version":1,"state":"born","pid":4294967303,"start":"10"}' }, dir .. "/1.json")
        local w = world()
        local result = Processes.reconcile(dir, w.deps)
        assert.is_true(result.unknown)
        assert.equals(0, w.probes)
        assert.equals(1, vim.fn.filereadable(dir .. "/1.json"))
    end)

    it("bounds writers before creating the child and never drops old records", function()
        Processes.MAX_RECORDS = 2
        assert(Processes.prepare(dir)); assert(Processes.prepare(dir))
        local ticket, err = Processes.prepare(dir)
        assert.is_nil(ticket)
        assert.matches("limit", err)
        assert.equals(2, #Processes.read(dir))
    end)

    it("observes joined death after TERM resistance instead of trusting signal delivery", function()
        local ticket = born(7, "10.000001")
        local w = world(); w.live[7] = "10.000001"
        local result = Processes.reconcile(dir, w.deps)
        assert.is_true(result.ok)
        assert.is_true(result.leaked)
        assert.same({ { 7, "sigterm" }, { 7, "sigkill" } }, w.signals)
        assert.is_nil(w.live[7])
        assert.equals(0, vim.fn.filereadable(ticket))
    end)

    it("retains evidence after denied cleanup and allows a proven later retirement", function()
        local ticket = born(7, "10")
        local w = world(); w.live[7], w.denied = "10", true
        local result = Processes.reconcile(dir, w.deps)
        assert.is_false(result.ok)
        assert.equals(1, vim.fn.filereadable(ticket))
        w.live[7] = nil
        assert.is_true(Processes.reconcile(dir, w.deps).ok)
        assert.equals(0, vim.fn.filereadable(ticket))
    end)

    it("rechecks immediately before signals and never signals a reused pid", function()
        born(7, "10")
        local w = world(); w.live[7] = "10"
        w.on_probe = function() if w.probes == 2 then w.live[7] = "11" end end
        assert.is_true(Processes.reconcile(dir, w.deps).ok)
        assert.same({}, w.signals)
        assert.equals("11", w.live[7])
    end)

    it("does not treat unreadable native identity as an absent process", function()
        local ticket = born(7, "10")
        local w = world(); w.live[7] = false
        assert.is_false(Processes.reconcile(dir, w.deps).ok)
        assert.same({}, w.signals)
        assert.equals(1, vim.fn.filereadable(ticket))
    end)

    it("keeps a legacy shared ledger until every original incarnation is gone", function()
        vim.fn.writefile({ "7 10", "8 11" }, dir .. "/jobs")
        local w = world(); w.live[8], w.denied = "11", true
        assert.is_false(Processes.reconcile(dir, w.deps).ok)
        assert.same({ "7 10", "8 11" }, vim.fn.readfile(dir .. "/jobs"))
        w.live[8] = nil
        assert.is_true(Processes.reconcile(dir, w.deps).ok)
        assert.equals(0, vim.fn.filereadable(dir .. "/jobs"))
        vim.fn.writefile({ "" }, dir .. "/jobs")
        assert.is_true(Processes.reconcile(dir, w.deps).unknown)
    end)

    it("scales native observation count linearly at N and 2N", function()
        local counts = {}
        for _, n in ipairs({ 16, 32 }) do
            local w = world()
            for i = 1, n do born(i, "10"); w.live[i] = "10" end
            assert.is_true(Processes.reconcile(dir, w.deps).ok)
            counts[#counts + 1] = w.probes
        end
        assert.equals(counts[1] * 2, counts[2])
    end)

    it("rejects symlink ledgers without reading or removing the external file", function()
        local outside = dir .. "-outside"
        vim.fn.writefile({ '{"version":1,"state":"pending"}' }, outside)
        assert(uv.fs_symlink(outside, dir .. "/1.json"))
        local result = Processes.reconcile(dir, world().deps)
        local present = vim.fn.filereadable(outside)
        vim.fn.delete(outside)
        assert.is_true(result.unknown)
        assert.equals(1, present)
    end)

    it("keeps evidence replaced during observation instead of unlinking a newer birth", function()
        local ticket = born(7, "10")
        local w = world()
        w.on_probe = function()
            vim.fn.writefile({ '{"version":1,"state":"pending"}' }, ticket)
        end
        local result = Processes.reconcile(dir, w.deps)
        assert.is_false(result.ok)
        assert.is_true(result.unknown)
        assert.equals(1, vim.fn.filereadable(ticket))
    end)

    it("refuses a registry writable by another principal", function()
        local ticket = born(7, "10")
        assert(uv.fs_chmod(dir, 511))
        local result = Processes.reconcile(dir, world().deps)
        assert.is_true(result.unknown)
        assert.equals(1, vim.fn.filereadable(ticket))
    end)

    it("uses explicit native absence and refuses values outside pid_t", function()
        assert.equals("live", Identity.observe(vim.fn.getpid()).kind)
        assert.equals("absent", Identity.observe(2 ^ 30).kind)
        assert.equals("unknown", Identity.observe(2 ^ 32 + vim.fn.getpid()).kind)
    end)

    it("rescans new scopes created during cleanup before allowing a clean census", function()
        local run = dir .. "/run"
        local scope = run .. "/first"
        vim.fn.mkdir(scope, "p", 448)
        local ticket = assert(Processes.prepare(scope))
        assert(Processes.complete(ticket, 7, function() return { kind = "live", start = "10" } end))
        local w = world(); w.live[7] = "10"
        local signal = w.deps.signal
        w.deps.signal = function(pid, name)
            if name == "sigkill" then
                local late = run .. "/late"
                vim.fn.mkdir(late, "p", 448)
                assert(Processes.prepare(late))
            end
            return signal(pid, name)
        end
        local result = Processes.census(dir, run, w.deps)
        assert.is_false(result.ok)
        assert.is_true(result.unknown)
        assert.equals("pending", Processes.read(run .. "/late")[1].record.state)
    end)
end)
