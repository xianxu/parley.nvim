-- parley.timezone_diagnostics — local-time diagnostics for UTC timestamps.

local M = {}

local UTC_TOKEN_PATTERN = "%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ"
local DIAG_NS = "parley_timezone"

local diag_ns_id

local function ensure_namespace()
    if not diag_ns_id then
        diag_ns_id = vim.api.nvim_create_namespace(DIAG_NS)
        vim.diagnostic.config({
            virtual_lines = { current_line = true },
            virtual_text = false,
        }, diag_ns_id)
    end
end

local function days_from_civil(year, month, day)
    year = year - (month <= 2 and 1 or 0)
    local era = math.floor((year >= 0 and year or year - 399) / 400)
    local yoe = year - era * 400
    local month_prime = month + (month > 2 and -3 or 9)
    local doy = math.floor((153 * month_prime + 2) / 5) + day - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

local function civil_from_days(days)
    days = days + 719468
    local era = math.floor((days >= 0 and days or days - 146096) / 146097)
    local doe = days - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local year = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local month_prime = math.floor((5 * doy + 2) / 153)
    local day = doy - math.floor((153 * month_prime + 2) / 5) + 1
    local month = month_prime + (month_prime < 10 and 3 or -9)
    year = year + (month <= 2 and 1 or 0)
    return year, month, day
end

local function parse_utc_token(token)
    local year, month, day, hour, min, sec = token:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)Z$")
    if not year then
        return nil
    end

    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour)
    min = tonumber(min)
    sec = tonumber(sec)

    if month < 1 or month > 12 or day < 1 or hour > 23 or min > 59 or sec > 59 then
        return nil
    end

    local days = days_from_civil(year, month, day)
    local round_year, round_month, round_day = civil_from_days(days)
    if round_year ~= year or round_month ~= month or round_day ~= day then
        return nil
    end

    return days * 86400 + hour * 3600 + min * 60 + sec
end

local function format_local_time(local_time)
    return string.format(
        "%04d-%02d-%02d %02d:%02d:%02d",
        local_time.year,
        local_time.month,
        local_time.day,
        local_time.hour,
        local_time.min,
        local_time.sec
    )
end

--- Build pure diagnostic records for strict UTC timestamp tokens.
--- @param lines string[]
--- @param opts table  { to_local = function(epoch) -> osdate table }
--- @return table[]
function M.build_diagnostics(lines, opts)
    opts = opts or {}
    local to_local = opts.to_local
    if type(to_local) ~= "function" then
        error("timezone_diagnostics.build_diagnostics requires opts.to_local")
    end

    local diagnostics = {}
    for line_index, line in ipairs(lines or {}) do
        local search_start = 1
        while search_start <= #line do
            local start_col, end_col = line:find(UTC_TOKEN_PATTERN, search_start)
            if not start_col then
                break
            end

            local token = line:sub(start_col, end_col)
            local epoch = parse_utc_token(token)
            if epoch then
                local local_time = format_local_time(to_local(epoch))
                table.insert(diagnostics, {
                    lnum = line_index - 1,
                    col = start_col - 1,
                    end_col = end_col,
                    utc = token,
                    epoch = epoch,
                    local_time = local_time,
                    message = string.format("local time: %s", local_time),
                })
            end

            search_start = end_col + 1
        end
    end

    return diagnostics
end

--- The namespace for Parley timezone diagnostics.
--- @return integer
function M.diag_namespace()
    ensure_namespace()
    return diag_ns_id
end

local function real_local_time(epoch)
    return os.date("*t", epoch)
end

--- Refresh timezone diagnostics for a buffer.
--- @param buf integer
--- @param opts table|nil  optional { to_local = function(epoch) -> osdate table }
function M.refresh_buffer(buf, opts)
    ensure_namespace()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    opts = opts or {}
    local reader = opts.reader or require("parley.line_reader").for_buffer(buf)
    local lines = reader:lines(0, -1, false)
    local diagnostics = M.build_diagnostics(lines, {
        to_local = opts.to_local or real_local_time,
    })

    local nvim_diagnostics = {}
    for _, diagnostic in ipairs(diagnostics) do
        table.insert(nvim_diagnostics, {
            lnum = diagnostic.lnum,
            col = diagnostic.col,
            end_lnum = diagnostic.lnum,
            end_col = diagnostic.end_col,
            message = diagnostic.message,
            severity = vim.diagnostic.severity.INFO,
            source = "parley-timezone",
            user_data = {
                utc = diagnostic.utc,
                local_time = diagnostic.local_time,
                epoch = diagnostic.epoch,
            },
        })
    end

    vim.diagnostic.set(diag_ns_id, buf, nvim_diagnostics)
end

--- Clear timezone diagnostics for a buffer.
--- @param buf integer
function M.clear(buf)
    ensure_namespace()
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.diagnostic.reset(diag_ns_id, buf)
end

return M
