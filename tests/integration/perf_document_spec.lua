local loaded, benchmark = pcall(require, "tests.perf.document")

describe("document core performance report", function()
    it("provides the direct core benchmark", function() assert.is_true(loaded) end)
    if not loaded then return end

    it("measures semantic Enter and join with retained suffix identity", function()
        local elapsed, work = benchmark.measure(100, "fragment_enter_join")
        assert.is_number(elapsed)
        assert.equals(3, work.structure_rows_processed)
        assert.is_true(work.dependency_nodes_visited > 0)
        assert.is_true(work.index_nodes_visited > 0)
        assert.equals(0, work.bytes_read)
    end)

    it("records leaf-entry inspection and metadata copies during real updates", function()
        local _, work = benchmark.measure(100, "typed_row")
        assert.is_number(work.index_entries_visited)
        assert.is_true(work.index_entries_visited > 0)
        assert.is_true(work.metadata_values_copied > 0)
        assert.is_true(work.summary_values_copied > 0)
    end)

    it("reports every core workload at all four structural scales", function()
        local report = benchmark.run({ iterations = 1, warmups = 0 })
        assert.equals(4, report.schema_version)
        assert.equals(28, #report.scenarios)
        local found = {}
        for _, scenario in ipairs(report.scenarios) do
            found[scenario.phase .. ":" .. scenario.line_count] = scenario
            assert.equals(1, scenario.iteration_count)
            assert.equals(0, scenario.work.full_buffer_reads)
            for _, field in ipairs(require("tests.perf.harness").WORK_FIELDS) do
                assert.is_number(scenario.work[field])
            end
        end
        for _, n in ipairs({ 100, 1000, 10000, 50000 }) do
            for _, phase in ipairs({ "typed_row", "sequence_splice", "bulk_paste_delete", "dependency_eof",
                "fact_footer", "long_line", "fragment_enter_join" }) do assert.is_table(found[phase .. ":" .. n]) end
            assert.is_true(found["typed_row:" .. n].work.structure_entries_copied <= 256)
            assert.is_true(found["typed_row:" .. n].work.index_nodes_visited <= 512)
            assert.equals(0, found["typed_row:" .. n].work.bytes_read)
            local fragment = found["fragment_enter_join:" .. n].work
            assert.equals(3, fragment.structure_rows_processed)
            assert.is_true(fragment.index_nodes_visited < 1024)
            assert.is_true(fragment.structure_entries_copied < 2048)
            assert.is_true(fragment.index_entries_visited < 4096)
            assert.equals(0, fragment.bytes_read)
            assert.is_true(found["sequence_splice:" .. n].work.structure_entries_copied <= 2048)
            assert.is_true(found["bulk_paste_delete:" .. n].work.structure_entries_copied <= 2048)
            assert.is_true(found["dependency_eof:" .. n].work.dependency_nodes_visited <= 128)
            assert.is_true(found["dependency_eof:" .. n].work.index_nodes_visited <= 4096)
            assert.is_true(found["fact_footer:" .. n].work.index_nodes_visited <= 4096)
            assert.equals(n * 16, found["long_line:" .. n].work.bytes_read)
            assert.equals(1, found["long_line:" .. n].work.structure_rows_processed)
        end
    end)

    it("writes a schema-valid standalone report", function()
        local path = vim.fn.tempname() .. ".json"
        local report = benchmark.run({ sizes = { 100 }, iterations = 1, warmups = 0, output = path })
        local decoded = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
        assert.equals(#report.scenarios, #decoded.scenarios)
        assert.equals("parley_document_core", decoded.scenarios[1].name)
        vim.fn.delete(path)
    end)
end)
