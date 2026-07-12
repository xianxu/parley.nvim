local harness = require("tests.perf.harness")

local function scenario(line_count, phase, attribution, median, p95)
    return {
        name = phase .. "-" .. attribution .. "-" .. line_count,
        phase = phase,
        attribution = attribution,
        line_count = line_count,
        iteration_count = 3,
        elapsed_ms = { samples = { median, p95, median }, median = median, p95 = p95 },
        work = {
            line_read_calls = 1,
            lines_requested = line_count,
            full_buffer_reads = 0,
            structure_rows_processed = line_count,
        },
    }
end

describe("performance harness", function()
    it("summarizes odd and even samples without mutating input", function()
        local odd = { 9, 1, 5 }
        local even = { 8, 2, 6, 4 }

        assert.same({ median = 5, p95 = 9 }, harness.summarize(odd))
        assert.same({ 9, 1, 5 }, odd)
        assert.same({ median = 5, p95 = 8 }, harness.summarize(even))
        assert.same({ 8, 2, 6, 4 }, even)
    end)

    it("uses nearest-rank p95 and rejects empty samples", function()
        local samples = {}
        for i = 1, 20 do
            samples[i] = i
        end
        assert.equals(19, harness.summarize(samples).p95)
        assert.has_error(function()
            harness.summarize({})
        end, "samples must not be empty")
    end)

    it("measures elapsed milliseconds with an injected clock", function()
        local ticks = { 1000000, 3500000, 4000000, 9000000 }
        local index = 0
        local calls = 0
        local measured = harness.measure(function()
            calls = calls + 1
        end, 2, function()
            index = index + 1
            return ticks[index]
        end)

        assert.same({ 2.5, 5 }, measured)
        assert.equals(2, calls)
    end)

    it("creates and encodes the exact report envelope", function()
        local environment = { neovim = "0.11", machine = "test" }
        local report = harness.new_report(environment)
        environment.machine = "changed"

        local keys = vim.tbl_keys(report)
        table.sort(keys)
        assert.same({ "environment", "generated_at", "scenarios", "schema_version", "timing_unit" }, keys)
        assert.equals(1, report.schema_version)
        assert.equals("milliseconds", report.timing_unit)
        assert.equals("test", report.environment.machine)
        assert.is_string(report.generated_at)
        assert.same({}, report.scenarios)
        local decoded = vim.json.decode(harness.encode(report))
        assert.equals(1, decoded.schema_version)
        assert.equals("milliseconds", decoded.timing_unit)
    end)

    it("validates scenarios and does not retain caller-owned tables", function()
        local report = harness.new_report({})
        local valid = scenario(100, "render", "inclusive", 1, 2)
        harness.add_scenario(report, valid)
        valid.elapsed_ms.samples[1] = 99
        assert.equals(1, report.scenarios[1].elapsed_ms.samples[1])

        local invalid = scenario(100, "render", "combined", 1, 2)
        assert.has_error(function()
            harness.add_scenario(report, invalid)
        end, "scenario.attribution must be inclusive or isolated")
        invalid = scenario(100, "render", "isolated", 1, 2)
        invalid.extra = true
        assert.has_error(function()
            harness.add_scenario(report, invalid)
        end, "scenario has unexpected field: extra")
        invalid = scenario(100, "render", "isolated", 1, 2)
        invalid.work.lines_requested = nil
        assert.has_error(function()
            harness.add_scenario(report, invalid)
        end, "scenario.work.lines_requested must be a number")
    end)

    it("renders grouped ratios in deterministic size order and two-decimal precision", function()
        local report = harness.new_report({})
        harness.add_scenario(report, scenario(5000, "render", "inclusive", 25, 30))
        harness.add_scenario(report, scenario(100, "render", "isolated", 0, 1))
        harness.add_scenario(report, scenario(1000, "render", "inclusive", 5, 6))
        harness.add_scenario(report, scenario(100, "render", "inclusive", 2, 3))
        harness.add_scenario(report, scenario(1000, "render", "isolated", 5, 6))

        local table_text = harness.render_table(report)
        assert.matches("phase | attribution | lines | median ms | p95 ms | median ratio", table_text, 1, true)
        local first = assert(table_text:find("render | inclusive | 100 | 2.00 | 3.00 | 1.00x", 1, true))
        local second = assert(table_text:find("render | inclusive | 1000 | 5.00 | 6.00 | 2.50x", 1, true))
        local third = assert(table_text:find("render | inclusive | 5000 | 25.00 | 30.00 | 12.50x", 1, true))
        assert.is_true(first < second and second < third)
        assert.matches("render | isolated | 100 | 0.00 | 1.00 | n/a", table_text, 1, true)
        assert.matches("render | isolated | 1000 | 5.00 | 6.00 | n/a", table_text, 1, true)
    end)
end)
