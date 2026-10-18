local arrival = require("tests.helpers.arrival")
local uv = vim.uv or vim.loop

describe("document registry process boundary", function()
    local root, saved, client
    local function request(op, args, options)
        local result
        client.request(op, args, { path = args[1], generation = 1 }, function(value) result = value end, options)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result
    end

    local function run(argv)
        local result
        require("parley.couch").run(argv, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        return result
    end
    local function status(path, trailing_flag)
        local argv = trailing_flag and { "couch", "--session-sync", "status", path, "--json" }
            or { "couch", "--session-sync", "status", "--json", path }
        local result = run(argv)
        assert.equals(0, result.code, result.stderr)
        return vim.json.decode(result.stdout, { luanil = { object = true, array = true } })
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, state = vim.env.FAKE_COUCH_REGISTRY, mode = vim.env.FAKE_COUCH_REGISTRY_MODE,
            status = vim.env.FAKE_COUCH_STATUS }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.env.FAKE_COUCH_STATUS = nil
        package.loaded["parley.document_registry"] = nil
        client = require("parley.document_registry")
    end)

    after_each(function()
        if client then client.shutdown() end
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = saved.path, saved.state, saved.mode
        vim.env.FAKE_COUCH_STATUS = saved.status
        vim.fn.delete(root, "rf")
    end)

    -- #382: a caller that names no deadline used to get a 2.5 s literal, which
    -- a loaded suite's couch spawn missed (spec setups failed as `deadline
    -- exceeded`) and which document_move's journaled renames ran on in
    -- production. It now gets the product's submit deadline, read from config.
    it("gives a request that names no deadline the configured submit deadline", function()
        local file = root .. "/slow.md"
        vim.fn.writefile({ "plain" }, file)
        local config = require("parley").config
        local configured = config.agentic_submit_timeout_ms
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_REGISTRY_DELAY = "delay", "3"
        local ok, err = pcall(function()
            -- 3 s is past the old 2.5 s default and inside the 15 s one
            assert.equals("absent", request("lookup", { file }).kind)
            config.agentic_submit_timeout_ms = 1000
            local late = request("lookup", { file })
            assert.equals("unavailable", late.kind)
            assert.matches("deadline exceeded", late.error)
        end)
        config.agentic_submit_timeout_ms = configured
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_REGISTRY_DELAY = nil, nil
        assert.is_true(ok, tostring(err))
    end)

    -- #382: one rule for every caller that names no deadline. A rename, native
    -- or document_move's journaled one, waits three submit deadlines (#359).
    it("derives every default deadline from the submit deadline, a rename's from three", function()
        local old, new = root .. "/before.md", root .. "/after.md"
        vim.fn.writefile({ "plain" }, old)
        assert.equals("registered", request("register", { old, "ops:0" }).kind)
        vim.fn.rename(old, new)
        local config = require("parley").config
        local configured = config.agentic_submit_timeout_ms
        local ok, err = pcall(function()
            config.agentic_submit_timeout_ms = 1000
            local got = {}
            for _, op in ipairs({ "lookup", "register", "forget", "rename" }) do got[op] = client.default_deadline_ms(op) end
            assert.same({ lookup = 1000, register = 1000, forget = 1000, rename = 3000 }, got)
            -- and request() uses it: a rename the fake holds 2 s, past one
            -- deadline and inside three, is still answered
            vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_REGISTRY_DELAY = "delay", "2"
            vim.env.FAKE_COUCH_REGISTRY_DELAY_OPS = "rename"
            assert.equals("registered", request("rename", { old, new }).kind)
        end)
        config.agentic_submit_timeout_ms = configured
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_REGISTRY_DELAY = nil, nil
        vim.env.FAKE_COUCH_REGISTRY_DELAY_OPS = nil
        assert.is_true(ok, tostring(err))
    end)

    it("preserves null-only absence and persisted identity across register and rename replay", function()
        local old, new = root .. "/a space;note.md", root .. "/new.md"
        vim.fn.writefile({ "plain" }, old)
        assert.equals("absent", request("lookup", { old }).kind)
        local first = request("register", { old, "ops:0" })
        assert.equals("registered", first.kind)
        assert.is_true(first.changed)
        local repeat_register = request("register", { old, "ops:0" })
        assert.equals(first.registration.ID, repeat_register.registration.ID)
        assert.is_false(repeat_register.changed)
        assert(uv.fs_rename(old, new))
        local moved = request("rename", { old, new })
        assert.equals(first.registration.ID, moved.registration.ID)
        assert.is_true(moved.changed)
        assert.is_false(request("rename", { old, new }).changed)
        assert.equals("absent", request("lookup", { old }).kind)
        assert.equals(uv.fs_realpath(new), request("lookup", { new }).registration.File)
        assert.same({ "plain" }, vim.fn.readfile(new))
    end)

    it("adopts a seeded legacy ledger and preserves Owed and LastWrite across registration and metadata rename", function()
        local old, new = root .. "/legacy.md", root .. "/moved.md"
        vim.fn.writefile({ "---", "type: session-sync", "owner: ops:0", "---", "legacy" }, old)
        local observed = { Owed = { { ID = "delivery-original", Kind = "delivery", At = "2026-10-14T12:00:00Z" } },
            LastWrite = "2026-10-14T11:00:00Z" }
        vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = observed })
        assert.same(observed, status(old).Status)
        vim.env.FAKE_COUCH_STATUS = nil
        assert.same(observed, status(old, true).Status)
        local registered = request("register", { old, "ops:0" })
        assert.equals("registered", registered.kind)
        assert.same(observed, status(old).Status)
        local replay = request("register", { old, "ops:0" })
        assert.is_false(replay.changed)
        assert.same(observed, status(old).Status)
        assert(uv.fs_rename(old, new))
        local renamed = request("rename", { old, new })
        assert.equals(registered.registration.ID, renamed.registration.ID)
        assert.same(observed, status(new).Status)
        assert.is_nil(status(old).Status)
        assert.equals("absent", request("lookup", { old }).kind)
        assert.is_false(request("rename", { old, new }).changed)
        assert.same(observed, status(new, true).Status)
    end)

    it("persists status seeded after registration and keeps explicit response overrides", function()
        local file = root .. "/registered.md"
        vim.fn.writefile({ "plain" }, file)
        assert.equals("registered", request("register", { file, "ops:0" }).kind)
        local empty = status(file)
        assert.equals("ok", empty.Code); assert.is_nil(empty.Status); assert.is_nil(empty.Changed)
        local observed = { Owed = { { ID = "event", At = "2026-10-14T13:00:00Z" } }, LastWrite = "2026-10-14T12:59:00Z" }
        vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = observed })
        assert.same(observed, status(file).Status)
        vim.env.FAKE_COUCH_STATUS = nil
        assert.same(observed, status(file).Status)
        vim.env.FAKE_COUCH_STATUS = "{explicit-malformed"
        local malformed = run({ "couch", "--session-sync", "status", "--json", file })
        assert.equals(0, malformed.code); assert.equals("{explicit-malformed", malformed.stdout:gsub("\n$", ""))
        vim.env.FAKE_COUCH_STATUS = '{"Code":"delivery-gap","Status":{"Owed":[]}}'
        assert.equals("delivery-gap", status(file).Code)
        vim.env.FAKE_COUCH_STATUS = nil
        assert.same(observed, status(file).Status)
        assert.is_nil(status(root .. "/unknown.md").Status)
        assert.is_not.equals(0, run({ "couch", "--session-sync", "unknown", file, "--json" }).code)
    end)

    it("adopts an explicit initial legacy status without reinitializing it on register replay", function()
        local file = root .. "/import.md"
        vim.fn.writefile({ "legacy" }, file)
        local observed = { Owed = { { ID = "existing", At = "2026-10-13T01:00:00Z" } }, LastWrite = "2026-10-13T00:00:00Z" }
        vim.env.FAKE_COUCH_STATUS = vim.json.encode({ Code = "ok", Status = observed })
        assert.equals("registered", request("register", { file, "ops:0" }).kind)
        vim.env.FAKE_COUCH_STATUS = nil
        assert.same(observed, status(file).Status)
        assert.is_false(request("register", { file, "ops:0" }).changed)
        assert.same(observed, status(file).Status)
    end)

    it("bounds active and queued lookups and consumes every timeout and cancellation once", function()
        local file = root .. "/queue.md"
        vim.fn.writefile({ "plain" }, file)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "delay"
        local count, full, seen, handles, results = 0, 0, {}, {}, {}
        for n = 1, 70 do
            handles[n] = client.request("lookup", { file }, {}, function(result)
                count = count + 1; seen[n] = (seen[n] or 0) + 1; results[n] = result
                if result.error == "registry request queue full" then full = full + 1 end
            end, { timeout_ms = 30 })
        end
        assert.is_true(vim.wait(arrival.MS, function() return count == 70 end, 10))
        assert.equals(2, full)
        for n = 1, 70 do
            assert.equals(1, seen[n]); assert.equals("unavailable", results[n].kind); handles[n].cancel()
        end
        local canceled, cancellation = 0, nil
        local pending = client.request("lookup", { file }, {}, function(result)
            canceled = canceled + 1; cancellation = result
        end, { timeout_ms = 2500 })
        client.shutdown()
        assert.is_true(vim.wait(arrival.MS, function() return cancellation ~= nil end, 10))
        assert.equals("unavailable", cancellation.kind); pending.cancel()
        assert.is_nil(uv.fs_stat(vim.env.FAKE_COUCH_REGISTRY))
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        assert.equals("absent", request("lookup", { file }).kind)
        assert.equals(70, count); assert.equals(1, canceled)
    end)

    it("treats unsupported, malformed, omitted and mismatched replies as unavailable", function()
        local file = root .. "/note.md"
        vim.fn.writefile({ "plain" }, file)
        for _, mode in ipairs({ "unsupported", "malformed", "missing", "wrong-path" }) do
            vim.env.FAKE_COUCH_REGISTRY_MODE = mode
            assert.equals("unavailable", request("lookup", { file }).kind, mode)
        end
    end)

    it("retains uncertain mutations and consumes canceled callbacks once", function()
        local file = root .. "/note.md"
        vim.fn.writefile({ "plain" }, file)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "uncertain"
        assert.equals("uncertain", request("register", { file, "ops:0" }).kind)
        vim.env.FAKE_COUCH_REGISTRY_MODE = "delay"
        local count, result = 0
        local handle = client.request("lookup", { file }, {}, function(value) count, result = count + 1, value end,
            { timeout_ms = 30 })
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
        handle.cancel()
        vim.wait(100, function() return false end, 10)
        assert.equals(1, count)
        assert.equals("unavailable", result.kind)
    end)
end)
