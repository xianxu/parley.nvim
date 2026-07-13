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

local function is_finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function require_nonnegative_number(value, path)
    if not is_finite(value) or value < 0 then
        error(path .. " must be a finite nonnegative number", 3)
    end
end

local function require_integer(value, minimum, path)
    if not is_finite(value) or value % 1 ~= 0 or value < minimum then
        error(path .. " must be an integer >= " .. minimum, 3)
    end
end

local function require_dense_array(value, path)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
            error(path .. " must be a dense array", 3)
        end
        count = count + 1
    end
    if count ~= #value then
        error(path .. " must be a dense array", 3)
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
    require_integer(scenario.line_count, 1, "scenario.line_count")
    require_integer(scenario.iteration_count, 1, "scenario.iteration_count")
    require_exact_fields(scenario.elapsed_ms, "scenario.elapsed_ms", { "samples", "median", "p95" })
    require_type(scenario.elapsed_ms.samples, "table", "scenario.elapsed_ms.samples")
    require_dense_array(scenario.elapsed_ms.samples, "scenario.elapsed_ms.samples")
    if #scenario.elapsed_ms.samples ~= scenario.iteration_count then
        error("scenario.elapsed_ms.samples length must equal scenario.iteration_count", 2)
    end
    for index, sample in ipairs(scenario.elapsed_ms.samples) do
        require_nonnegative_number(sample, "scenario.elapsed_ms.samples[" .. index .. "]")
    end
    require_nonnegative_number(scenario.elapsed_ms.median, "scenario.elapsed_ms.median")
    require_nonnegative_number(scenario.elapsed_ms.p95, "scenario.elapsed_ms.p95")
    local summary = M.summarize(scenario.elapsed_ms.samples)
    if scenario.elapsed_ms.median ~= summary.median then
        error("scenario.elapsed_ms.median must match the sample median", 2)
    end
    if scenario.elapsed_ms.p95 ~= summary.p95 then
        error("scenario.elapsed_ms.p95 must match the sample p95", 2)
    end
    require_exact_fields(scenario.work, "scenario.work", {
        "line_read_calls", "lines_requested", "full_buffer_reads", "structure_rows_processed",
    })
    for _, field in ipairs({
        "line_read_calls", "lines_requested", "full_buffer_reads", "structure_rows_processed",
    }) do
        require_integer(scenario.work[field], 0, "scenario.work." .. field)
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
