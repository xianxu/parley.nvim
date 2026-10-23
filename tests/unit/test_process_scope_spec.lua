local Processes = require("tests.helpers.test_processes")
local uv = vim.uv or vim.loop

describe("retained process scope admission", function()
    local dir, scandir
    before_each(function()
        dir = vim.fn.tempname()
        assert(uv.fs_mkdir(dir, 448))
        scandir = uv.fs_scandir
    end)
    after_each(function()
        uv.fs_scandir = scandir
        vim.fn.delete(dir, "rf")
    end)

    local function names()
        local result, scan = {}, assert(scandir(dir))
        while true do
            local name = uv.fs_scandir_next(scan)
            if not name then return result end
            result[#result + 1] = name
        end
    end

    it("atomically admits one of two callers whose snapshots both have one free slot", function()
        for i = 1, Processes.MAX_SCOPES - 1 do assert(uv.fs_mkdir(dir .. "/spec-" .. i, 448)) end
        -- Both native scans finish before either caller can reserve. This exact
        -- old count/count/mkdtemp/mkdtemp interleaving deterministically made 65.
        uv.fs_scandir = function(path)
            local scan, err = scandir(path)
            if path == dir then coroutine.yield("snapshot complete") end
            return scan, err
        end
        local first = coroutine.create(function() return Processes.scope(dir) end)
        local second = coroutine.create(function() return Processes.scope(dir) end)
        for _, caller in ipairs({ first, second }) do
            local ok, barrier = coroutine.resume(caller)
            assert.is_true(ok, barrier)
            assert.equals("snapshot complete", barrier)
        end
        local ok_first, admitted, first_err = coroutine.resume(first)
        local ok_second, denied, reason = coroutine.resume(second)
        assert.is_true(ok_first, admitted)
        assert.is_true(ok_second, denied)
        assert.is_string(admitted, first_err)
        assert.is_nil(denied)
        assert.matches("limit", reason)
        assert.equals(Processes.MAX_SCOPES, #names())
    end)

    it("retains legacy random scopes and refuses further admission visibly", function()
        local legacy = assert(uv.fs_mkdtemp(dir .. "/spec-XXXXXX"))
        local ticket = assert(Processes.prepare(legacy))
        local body = vim.fn.readfile(ticket)
        local scope, err = Processes.scope(dir)
        assert.is_nil(scope)
        assert.matches("scope", err)
        assert.same(body, vim.fn.readfile(ticket))
        assert.equals(1, #names())
    end)

    it("uses a bounded slot set and allows reuse only after empty scope retirement", function()
        local scopes = {}
        for _ = 1, Processes.MAX_SCOPES do
            local scope = assert(Processes.scope(dir))
            assert.is_nil(scopes[scope], "scope returned twice")
            scopes[scope] = true
        end
        local scope, err = Processes.scope(dir)
        assert.is_nil(scope)
        assert.matches("limit", err)
        assert.equals(Processes.MAX_SCOPES, #names())
        local released = next(scopes)
        local ticket = assert(Processes.prepare(released))
        assert.is_nil(Processes.prune(released), "unresolved evidence must prevent retirement")
        assert.is_nil(Processes.scope(dir))
        assert(Processes.abort(ticket))
        assert(Processes.prune(released))
        assert.equals(released, Processes.scope(dir))
        assert.equals(Processes.MAX_SCOPES, #names())
    end)

    it("refuses malformed slot entries without following or deleting them", function()
        local outside = dir .. "-outside"
        assert(uv.fs_mkdir(outside, 448))
        assert(uv.fs_symlink(outside, dir .. "/spec-1"))
        local scope, err = Processes.scope(dir)
        local link = uv.fs_lstat(dir .. "/spec-1")
        assert(uv.fs_rmdir(outside))
        assert.is_nil(scope)
        assert.matches("scope", err)
        assert.equals("link", link.type)
    end)
end)
