local M = {}

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, item in pairs(value) do
        result[copy(key)] = copy(item)
    end
    return result
end

local function require_exact_fields(value, path, fields)
    if type(value) ~= "table" then
        error(path .. " must be a table", 3)
    end
    local allowed = {}
    for _, field in ipairs(fields) do
        allowed[field] = true
    end
    for field in pairs(value) do
        if not allowed[field] then
            error(path .. " has unexpected field: " .. tostring(field), 3)
        end
    end
end

local function require_type(value, expected, path)
    if type(value) ~= expected then
        error(path .. " must be a " .. expected, 3)
    end
end

function M.summarize(samples)
    require_type(samples, "table", "samples")
    if #samples == 0 then
        error("samples must not be empty", 2)
    end
    local sorted = copy(samples)
    table.sort(sorted)
    local count = #sorted
    local middle = math.floor(count / 2)
    local median
    if count % 2 == 0 then
        median = (sorted[middle] + sorted[middle + 1]) / 2
    else
        median = sorted[middle + 1]
    end
    return {
        median = median,
        p95 = sorted[math.ceil(count * 0.95)],
    }
end

function M.measure(fn, iterations, now)
    now = now or vim.uv.hrtime
    local samples = {}
    for index = 1, iterations do
        local started = now()
        fn()
        samples[index] = (now() - started) / 1000000
    end
    return samples
end

function M.new_report(environment)
    return {
        schema_version = 1,
        generated_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        timing_unit = "milliseconds",
        environment = copy(environment),
        scenarios = {},
    }
end

function M.add_scenario(report, scenario)
    require_exact_fields(scenario, "scenario", {
        "name", "phase", "attribution", "line_count", "iteration_count", "elapsed_ms", "work",
    })
    require_type(scenario.name, "string", "scenario.name")
    require_type(scenario.phase, "string", "scenario.phase")
    if scenario.attribution ~= "inclusive" and scenario.attribution ~= "isolated" then
        error("scenario.attribution must be inclusive or isolated", 2)
    end
    require_type(scenario.line_count, "number", "scenario.line_count")
    require_type(scenario.iteration_count, "number", "scenario.iteration_count")
    require_exact_fields(scenario.elapsed_ms, "scenario.elapsed_ms", { "samples", "median", "p95" })
    require_type(scenario.elapsed_ms.samples, "table", "scenario.elapsed_ms.samples")
    require_type(scenario.elapsed_ms.median, "number", "scenario.elapsed_ms.median")
    require_type(scenario.elapsed_ms.p95, "number", "scenario.elapsed_ms.p95")
    for index, sample in ipairs(scenario.elapsed_ms.samples) do
        require_type(sample, "number", "scenario.elapsed_ms.samples[" .. index .. "]")
    end
    require_exact_fields(scenario.work, "scenario.work", {
        "line_read_calls", "lines_requested", "full_buffer_reads", "structure_rows_processed",
    })
    for _, field in ipairs({
        "line_read_calls", "lines_requested", "full_buffer_reads", "structure_rows_processed",
    }) do
        require_type(scenario.work[field], "number", "scenario.work." .. field)
    end
    table.insert(report.scenarios, copy(scenario))
end

function M.encode(report)
    return vim.json.encode(report)
end

function M.render_table(report)
    local scenarios = copy(report.scenarios)
    table.sort(scenarios, function(left, right)
        if left.phase ~= right.phase then
            return left.phase < right.phase
        end
        if left.attribution ~= right.attribution then
            return left.attribution < right.attribution
        end
        return left.line_count < right.line_count
    end)

    local baselines = {}
    for _, item in ipairs(scenarios) do
        local group = item.phase .. "\0" .. item.attribution
        if item.line_count == 100 then
            baselines[group] = item.elapsed_ms.median
        end
    end

    local lines = {
        "phase | attribution | lines | median ms | p95 ms | median ratio",
        "--- | --- | ---: | ---: | ---: | ---:",
    }
    for _, item in ipairs(scenarios) do
        local baseline = baselines[item.phase .. "\0" .. item.attribution]
        local ratio = "n/a"
        if baseline and baseline ~= 0 then
            ratio = string.format("%.2fx", item.elapsed_ms.median / baseline)
        end
        table.insert(lines, string.format("%s | %s | %d | %.2f | %.2f | %s", item.phase, item.attribution,
            item.line_count, item.elapsed_ms.median, item.elapsed_ms.p95, ratio))
    end
    return table.concat(lines, "\n")
end

return M
