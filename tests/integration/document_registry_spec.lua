local uv = vim.uv or vim.loop

describe("document registry process boundary", function()
    local root, saved, client
    local function request(op, args, options)
        local result
        client.request(op, args, { path = args[1], generation = 1 }, function(value) result = value end, options)
        assert.is_true(vim.wait(4000, function() return result ~= nil end, 10))
        return result
    end

    before_each(function()
        root = vim.fn.tempname()
        vim.fn.mkdir(root, "p")
        require("tests.helpers.fake_couch").write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, state = vim.env.FAKE_COUCH_REGISTRY, mode = vim.env.FAKE_COUCH_REGISTRY_MODE }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        package.loaded["parley.document_registry"] = nil
        client = require("parley.document_registry")
    end)

    after_each(function()
        if client then client.shutdown() end
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = saved.path, saved.state, saved.mode
        vim.fn.delete(root, "rf")
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
        assert.is_true(vim.wait(2000, function() return result ~= nil end, 10))
        handle.cancel()
        vim.wait(100, function() return false end, 10)
        assert.equals(1, count)
        assert.equals("unavailable", result.kind)
    end)
end)
