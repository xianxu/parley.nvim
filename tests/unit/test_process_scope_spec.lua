local Processes = require("tests.helpers.test_processes")
local uv = vim.uv or vim.loop

describe("retained process scope admission", function()
    local dir, scandir, lstat
    before_each(function()
        dir = vim.fn.tempname()
        assert(uv.fs_mkdir(dir, 448))
        scandir = uv.fs_scandir
        lstat = uv.fs_lstat
    end)
    after_each(function()
        uv.fs_scandir = scandir
        uv.fs_lstat = lstat
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

    it("admits after a sibling retires an empty scope from its completed snapshot", function()
        local retired = dir .. "/spec-1"
        assert(uv.fs_mkdir(retired, 448))
        uv.fs_scandir = function(path)
            local scan, err = scandir(path)
            if path == dir then coroutine.yield("snapshot complete") end
            return scan, err
        end
        local caller = coroutine.create(function() return Processes.scope(dir) end)
        local ok, barrier = coroutine.resume(caller)
        assert.is_true(ok, barrier)
        assert.equals("snapshot complete", barrier)
        assert(Processes.prune(retired))
        local resumed, admitted, err = coroutine.resume(caller)
        assert.is_true(resumed, admitted)
        assert.equals(retired, admitted, err)
        assert.equals(1, #names())
    end)

    it("admits only one stale caller into the slot retired after both full snapshots", function()
        for i = 1, Processes.MAX_SCOPES do assert(uv.fs_mkdir(dir .. "/spec-" .. i, 448)) end
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
        local retired = dir .. "/spec-1"
        assert(Processes.prune(retired))
        local ok_first, admitted, first_err = coroutine.resume(first)
        local ok_second, denied, reason = coroutine.resume(second)
        assert.is_true(ok_first, admitted)
        assert.is_true(ok_second, denied)
        assert.equals(retired, admitted, first_err)
        assert.is_nil(denied)
        assert.matches("limit", reason)
        assert.equals(Processes.MAX_SCOPES, #names())
    end)

    it("never returns a slot reused after its old directory identity was validated", function()
        local reused = dir .. "/spec-1"
        assert(uv.fs_mkdir(reused, 448))
        local paused = false
        uv.fs_lstat = function(path)
            local info, err, code = lstat(path)
            if path == reused and not paused then
                paused = true
                coroutine.yield("identity observed")
            end
            return info, err, code
        end
        local caller = coroutine.create(function() return Processes.scope(dir) end)
        local ok, barrier = coroutine.resume(caller)
        assert.is_true(ok, barrier)
        assert.equals("identity observed", barrier)
        assert(Processes.prune(reused))
        assert.equals(reused, Processes.scope(dir))
        local resumed, admitted, err = coroutine.resume(caller)
        assert.is_true(resumed, admitted)
        assert.equals(dir .. "/spec-2", admitted, err)
        assert.equals(2, #names())
    end)

    it("refuses unreadable or unknown metadata rather than treating every nil as absence", function()
        local existing = dir .. "/spec-1"
        assert(uv.fs_mkdir(existing, 448))
        local ticket = assert(Processes.prepare(existing))
        local body = vim.fn.readfile(ticket)
        for _, failure in ipairs({ { "EACCES: permission denied", "EACCES" },
            { "EIO: metadata unavailable", "EIO" }, { "unclassified lookup failure" } }) do
            uv.fs_lstat = function(path)
                if path == existing then return nil, failure[1], failure[2] end
                return lstat(path)
            end
            local admitted, err = Processes.scope(dir)
            assert.is_nil(admitted)
            assert.is_string(err)
            assert.same(body, vim.fn.readfile(ticket))
            assert.equals(1, #names())
        end
    end)

    it("refuses invalid present evidence even though atomic reservation has spare slots", function()
        for _, name in ipairs({ "spec-0", "spec-01", "spec-65", "unexpected" }) do
            local existing = dir .. "/" .. name
            assert(uv.fs_mkdir(existing, 448))
            local ticket = assert(Processes.prepare(existing))
            local body = vim.fn.readfile(ticket)
            local admitted, err = Processes.scope(dir)
            assert.is_nil(admitted)
            assert.matches("scope", err)
            assert.same(body, vim.fn.readfile(ticket))
            assert.equals(1, #names())
            vim.fn.delete(existing, "rf")
        end
        local insecure = dir .. "/spec-1"
        assert(uv.fs_mkdir(insecure, 511))
        assert(uv.fs_chmod(insecure, 511))
        local admitted, err = Processes.scope(dir)
        assert.is_nil(admitted)
        assert.matches("scope", err)
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
