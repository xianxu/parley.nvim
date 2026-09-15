local dispatcher = require("parley.dispatcher")
local tasker = require("parley.tasker")
local vault = require("parley.vault")
local fake_process = require("tests.helpers.fake_process")
local providers = require("parley.providers")

local function status(process, code)
    for index, argument in ipairs(process.args) do
        if argument == "--write-out" then
            local sentinel = process.args[index + 1]:match("%%{stderr}(.-)%%{http_code}")
            process:emit("stderr", sentinel .. code .. "\n")
            return
        end
    end
    error("fixture request has no HTTP status trailer")
end

describe("dispatcher transport ownership", function()
    local old_secret, old_with_secret, old_provider_get, runtime, processes
    before_each(function()
        tasker._reset()
        runtime, processes = fake_process.new()
        tasker._uv = runtime
        old_secret, old_with_secret = vault.get_secret, vault.run_with_secret
        old_provider_get = providers.get
        vault.get_secret = function() return "fixture-secret" end
        vault.run_with_secret = function(_, fn) fn() end
        dispatcher.providers.openai = { endpoint = "http://127.0.0.1:9/fixture" }
        dispatcher.query_dir = vim.fn.tempname() .. "-queries"
        vim.fn.mkdir(dispatcher.query_dir, "p")
    end)
    after_each(function()
        providers.get = old_provider_get
        for _, process in pairs(processes.processes) do
            process:emit("stdout", 'data: {"choices":[{"delta":{"content":"done"},"finish_reason":"stop"}]}\n\n')
            status(process, "200")
            process:finish()
        end
        vim.wait(100, function() return #tasker._handles == 0 end, 5)
        vault.get_secret, vault.run_with_secret = old_secret, old_with_secret
        tasker._reset()
        tasker._uv = nil
    end)

    it("routes same-buffer requests to distinct cancellable owners", function()
        local output = {}
        local function start(owner)
            dispatcher.query(71, "openai", { model = "fixture", messages = {} },
                function(_, chunk) output[owner] = (output[owner] or "") .. chunk end,
                nil, nil, nil, nil, nil, nil,
                { generation_id = owner, admission_key = owner })
        end
        start("first")
        start("second")
        assert.equals(2, processes.spawn_calls)
        tasker.stop_owner("first")
        assert.same({ { pid = 4242, signal = 15 } }, processes.signals)
        processes.processes[4243]:emit("stdout", 'data: {"choices":[{"delta":{"content":"survivor"}}]}\n\n')
        assert.equals("survivor", output.second)
        assert.is_true(tasker.is_busy(71), "signal does not retire either attempt")
    end)

    it("retires query preparation when authorization fails before transport launch", function()
        vault.get_secret = function() return nil end
        local aborted = false
        dispatcher.query(72, "openai", { model = "fixture", messages = {} }, function() end,
            nil, nil, nil, function() aborted = true end)
        assert.is_true(aborted)
        assert.equals(0, processes.spawn_calls)
        assert.is_nil(tasker.get_active_query_by_buf(72), "rejected preparation must not remain active")
    end)

    it("retains the captured owner through provider recovery retries", function()
        providers.get = function(name)
            local adapter = vim.tbl_extend("force", {}, old_provider_get(name))
            adapter.recover_query = function(_, retry) retry(); return true end
            return adapter
        end
        local function start(owner)
            dispatcher.query(73, "openai", { model = "fixture", messages = {} }, function() end,
                nil, nil, nil, nil, nil, nil,
                { generation_id = owner, admission_key = owner })
        end
        start("retry-owner")
        start("unrelated-owner")
        status(processes.processes[4242], "503")
        processes.processes[4242]:finish()
        assert.is_true(vim.wait(300, function() return processes.spawn_calls == 3 end, 5))
        assert.equals(1, tasker.stop_owner("retry-owner"))
        assert.same({ { pid = 4244, signal = 15 } }, processes.signals)
        assert.equals(2, #tasker._handles, "retry and unrelated work retain independent admission")
    end)
end)
