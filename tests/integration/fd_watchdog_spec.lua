-- The watchdog's shell (#399): the real timer, descriptor count and capture
-- path, with stand-in lsof and ps scripts so no spec depends on either tool.
local watchdog = require("parley.fd_watchdog")

describe("fd_watchdog capture (#399)", function()
    local root

    local function script(name, body)
        local path = root .. "/" .. name
        vim.fn.writefile({ "#!/bin/sh", body }, path)
        assert((vim.uv or vim.loop).fs_chmod(path, 493))
        return path
    end

    -- Each setup gets its own collector, so a late callback cannot land in
    -- another spec's warnings.
    local function collector()
        local warnings = {}
        return warnings, function(message, level) warnings[#warnings + 1] = { message = message, level = level } end
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        watchdog._rearm()
    end)

    after_each(function()
        watchdog._rearm()
        vim.fn.delete(root, "rf")
    end)

    it("captures lsof and the live children past the threshold, warns once naming the file, keeps five", function()
        local dir = root .. "/captures"
        vim.fn.mkdir(dir, "p")
        for i = 1, 6 do vim.fn.writefile({ "old" }, ("%s/fd-20000101-00000%d-1.txt"):format(dir, i)) end
        local pid = vim.fn.getpid()
        local warnings, notify = collector()
        -- A child's arguments can carry secrets: the stand-in answers `comm=`
        -- with the executable, and anything else with a whole command line.
        local ps = script("ps", ([[case "$*" in *comm=*) echo '%d %d /usr/local/bin/curl'; echo '1 0 launchd';;
*) echo '%d %d curl -H Authorization: Bearer SECRET-TOKEN';; esac]]):format(pid + 1, pid, pid + 1, pid))
        watchdog.setup({ threshold = watchdog.count() - 3, interval_ms = 20, dir = dir, notify = notify,
            lsof = script("lsof", "echo LSOF-MARK $@"), ps = ps })
        assert.is_true(vim.wait(5000, function() return #warnings > 0 end))
        vim.wait(200, function() return false end)
        assert.equals(1, #warnings, "one warning, not one per tick")
        assert.equals(vim.log.levels.WARN, warnings[1].level)
        local path = warnings[1].message:match("Captured lsof and its children to (%S+)$")
        assert.truthy(path, warnings[1].message)
        local text = table.concat(vim.fn.readfile(path), "\n")
        assert.truthy(text:find("## children\n" .. (pid + 1) .. " /usr/local/bin/curl", 1, true), text)
        assert.is_nil(text:find("SECRET-TOKEN", 1, true))
        assert.is_nil(text:find("launchd", 1, true))
        assert.truthy(text:find("LSOF-MARK -p " .. pid, 1, true))
        local kept = {}
        for name in vim.fs.dir(dir) do kept[#kept + 1] = name end
        assert.equals(5, #kept)
        assert.truthy(vim.tbl_contains(kept, vim.fs.basename(path)))
        -- Once per process: setting it up again does not re-arm it.
        watchdog.setup({ threshold = watchdog.count() - 3, interval_ms = 20, dir = dir, notify = notify })
        vim.wait(200, function() return false end)
        assert.equals(1, #warnings)
    end)

    it("stays quiet at or below the threshold, and off at 0", function()
        local warnings, notify = collector()
        watchdog.setup({ threshold = watchdog.count() + 50, interval_ms = 20, dir = root .. "/c", notify = notify })
        vim.wait(150, function() return false end)
        watchdog.setup({ threshold = 0, interval_ms = 20, dir = root .. "/c", notify = notify })
        vim.wait(150, function() return false end)
        assert.same({}, warnings)
        assert.equals(0, vim.fn.isdirectory(root .. "/c"))
    end)
end)
