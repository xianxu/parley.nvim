local function probe(n)
    local output = vim.fn.tempname() .. ".json"
    local lua = string.format("local ok,m=pcall(require,'tests.perf.ownership'); if not ok then print(m); vim.cmd('cquit 1') else m.run_probe(%d, %s) end", n, vim.fn.string(output))
    local result = vim.fn.system({ "nvim", "-n", "--headless", "--noplugin", "-u",
        "tests/minimal_init.vim", "-c", "lua " .. lua })
    assert.equals(0, vim.v.shell_error, result)
    local sample = vim.json.decode(table.concat(vim.fn.readfile(output), "\n"))
    vim.fn.delete(output)
    return sample
end

describe("ownership performance baselines", function()
    it("measures real fold maintenance across many exchange anchors", function()
        local small, large = probe(100), probe(1000)
        assert.is_true(small.fold_work.fold_groups_visited > 0)
        assert.is_true(small.fold_work.native_fold_ops > 0)
        assert.is_true(large.fold_work.anchors_resolved > small.fold_work.anchors_resolved)
        assert.is_true(small.fold_preserved)
        assert.is_true(large.fold_preserved)
    end)

    it("includes measured ownership phases at every report size", function()
        local output = vim.fn.tempname() .. ".json"
        local lua = string.format("require('tests.perf.chat_typing').start({warmups=0,iterations=1,output=%s})",
            vim.fn.string(output))
        local raw = vim.fn.system({ "nvim", "-n", "--headless", "--noplugin", "-u",
            "tests/minimal_init.vim", "-c", "lua " .. lua })
        assert.equals(0, vim.v.shell_error, raw)
        local report = vim.json.decode(table.concat(vim.fn.readfile(output), "\n"))
        vim.fn.delete(output)
        for _, n in ipairs({ 100, 1000, 5000 }) do
            for _, phase in ipairs({ "fold_maintenance", "stream_human_interleave" }) do
                local found
                for _, scenario in ipairs(report.scenarios) do
                    if scenario.phase == phase and scenario.line_count == n then found = scenario end
                end
                assert.is_table(found, phase .. " missing at " .. n)
                assert.equals(1, found.iteration_count)
                assert.is_true(found.work.native_fold_ops > 0)
            end
        end
    end)

    it("interleaves the production stream handler with real typed-ahead input", function()
        local sample = probe(100)
        assert.is_true(sample.human_preserved)
        assert.is_true(sample.stream_before_human)
        assert.is_true(sample.insert_mode)
        assert.is_true(sample.text_changed_i > 0)
        assert.equals(2, sample.deliveries)
        assert.is_true(sample.stream_work.structure_rows_processed > 0)
        assert.is_true(sample.stream_work.native_fold_ops > 0)
    end)
end)
