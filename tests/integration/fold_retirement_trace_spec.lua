local Embedded = require('tests.helpers.embedded_nvim')
local Trace = require('tests.helpers.fold_retirement_trace')

describe('fold retirement diagnostic evidence', function()
    local child, trace, saved
    before_each(function()
        saved = Embedded.REQUEST_MS
        trace = Trace.new()
        child = Embedded.start()
    end)
    after_each(function()
        Embedded.REQUEST_MS = saved
        if child then child:stop() end
        trace:close()
    end)

    it('returns the unchanged RPC value and records bounded work evidence', function()
        local result = trace:run(child, [[
            local trace = require('tests.helpers.fold_retirement_trace').start(...)
            for _ = 1, 8 do trace:count({native_fold_ops=1}) end
            trace:stage('retired')
            return {enabled=true, status='idle'}
        ]])
        assert.same({enabled=true, status='idle'}, result)
        local evidence = trace:read()
        assert.equals('retired', evidence.stage)
        assert.equals(8, evidence.work.native_fold_ops)
        assert.equals('string', type(evidence.runtime.nvim))
        assert.equals(3, #evidence.load)
        assert.is_true(evidence.wall_ms >= 0)
        assert.is_true(evidence.cpu_ms >= 0)
    end)

    it('reports the last stage after the bounded helper kills a stuck child', function()
        Embedded.REQUEST_MS = 500
        local ok, err = pcall(trace.run, trace, child, [[
            local trace = require('tests.helpers.fold_retirement_trace').start(...)
            trace:count({repair_steps=16, native_fold_ops=128})
            trace:stage('before-option-detach')
            while true do end
        ]])
        assert.is_false(ok)
        assert.is_truthy(tostring(err):find('within 500 ms', 1, true), err)
        assert.is_truthy(tostring(err):find('before-option-detach', 1, true), err)
        local evidence = trace:read()
        assert.equals('before-option-detach', evidence.stage)
        assert.equals(16, evidence.work.repair_steps)
        assert.equals(128, evidence.work.native_fold_ops)
        assert.is_not_nil(vim.uv.fs_stat(trace.root))
        trace:close()
        assert.is_nil(vim.uv.fs_stat(trace.root))
    end)

    for _, repairs in ipairs({4, 8}) do
        it('writes only logarithmic progress snapshots for '..repairs..' repairs', function()
            local result = trace:run(child, [[
                local path, repairs = ...
                local trace = require('tests.helpers.fold_retirement_trace').start(path)
                local callback
                trace:observe({subscribe=function(_, fn)
                    callback=fn; return function() callback=nil end
                end}, nil, vim.api.nvim_get_current_buf())
                local stage, writes = trace.stage, 0
                trace.stage = function(self, name) writes=writes+1; return stage(self, name) end
                for _ = 1, repairs do callback({kind='repair'}) end
                trace:finish()
                return {writes=writes, repairs=trace.work.repair_steps}
            ]], repairs)
            assert.equals(repairs, result.repairs)
            assert.equals(repairs == 4 and 4 or 5, result.writes)
        end)
    end
end)
