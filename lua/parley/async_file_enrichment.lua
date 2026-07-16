local finder_scan = require("parley.finder_scan")

local M = {}
local FAILURE_KIND = finder_scan.FAILURE_KIND

local function sort_by_relative(items)
    table.sort(items, function(left, right) return left.relative < right.relative end)
end

local function head_prefix(payload, line_count)
    local cursor = 1
    for _ = 1, line_count do
        local newline = payload:find("\n", cursor, true)
        if not newline then
            return payload, false
        end
        cursor = newline + 1
    end
    return payload:sub(1, cursor - 1), true
end

M.run = function(options, on_complete)
    local uv = options.uv
    local queue = options.queue
    local cancelled = false
    local completed = false
    local candidates = {}
    local failures = {}
    local pending = #options.paths
    local descriptors = {}

    local function is_cancelled()
        return cancelled or options.is_cancelled()
    end

    local function close_direct(fd)
        if descriptors[fd] then
            descriptors[fd] = nil
            pcall(uv.fs_close, fd, function() end)
        end
    end

    local handle = {}
    handle.cancel = function()
        if cancelled then
            return
        end
        cancelled = true
        local open = {}
        for fd in pairs(descriptors) do
            open[#open + 1] = fd
        end
        for _, fd in ipairs(open) do
            close_direct(fd)
        end
    end

    local function finish_if_ready()
        if not is_cancelled() and not completed and pending == 0 then
            completed = true
            sort_by_relative(candidates)
            sort_by_relative(failures)
            on_complete({ candidates = candidates, failures = failures })
        end
    end

    local function path_done()
        pending = pending - 1
        finish_if_ready()
    end

    local function fail_path(relative, absolute, kind, error_value)
        local failure = { relative = relative, unresolved_absolute = absolute, kind = kind }
        if error_value ~= nil then
            failure.diagnostic = finder_scan.bounded_io_error(error_value)
        end
        failures[#failures + 1] = failure
        path_done()
    end

    local function read_payload(relative, absolute, candidate, mode)
        queue:call(function(done)
            return uv.fs_open(absolute, "r", 438, done)
        end, function(open_error, fd)
            if open_error or fd == nil then
                fail_path(relative, absolute, FAILURE_KIND.open, open_error)
                return
            end
            descriptors[fd] = true
            local chunks = {}
            local offset = 0

            local function close_then(callback)
                if not descriptors[fd] then
                    return
                end
                descriptors[fd] = nil
                queue:call(function(done) return uv.fs_close(fd, done) end, callback)
            end

            local read_next
            read_next = function()
                queue:call(function(done) return uv.fs_read(fd, 4096, offset, done) end, function(read_error, data)
                    if read_error then
                        close_then(function() fail_path(relative, absolute, FAILURE_KIND.read, read_error) end)
                        return
                    end

                    data = data or ""
                    chunks[#chunks + 1] = data
                    offset = offset + #data
                    local payload = table.concat(chunks)
                    local enough = false
                    if type(mode) == "table" then
                        payload, enough = head_prefix(payload, mode.head_lines)
                    end
                    if data == "" or enough then
                        close_then(function(close_error)
                            if close_error then
                                fail_path(relative, absolute, FAILURE_KIND.read, close_error)
                            else
                                candidate.payload = payload
                                candidates[#candidates + 1] = candidate
                                path_done()
                            end
                        end)
                    else
                        read_next()
                    end
                end)
            end
            read_next()
        end)
    end

    local function apply_decision(relative, absolute, candidate)
        local decision
        if options.read_policy then
            local ok, result = pcall(options.read_policy, candidate)
            if not ok then
                fail_path(relative, absolute, FAILURE_KIND.read_policy_exception)
                return
            end
            decision = result
        elseif options.read == nil or options.read == "none" then
            decision = { kind = "none" }
        else
            decision = { kind = "read", mode = options.read }
        end

        if is_cancelled() then
            return
        end
        if type(decision) ~= "table" then
            fail_path(relative, absolute, FAILURE_KIND.invalid_read_policy)
        elseif decision.kind == "ready" then
            candidate.precomputed = decision.value
            candidates[#candidates + 1] = candidate
            path_done()
        elseif decision.kind == "none" then
            candidates[#candidates + 1] = candidate
            path_done()
        elseif decision.kind == "read"
            and (decision.mode == "all"
                or (type(decision.mode) == "table"
                    and type(decision.mode.head_lines) == "number"
                    and decision.mode.head_lines >= 1)) then
            read_payload(relative, absolute, candidate, decision.mode)
        else
            fail_path(relative, absolute, FAILURE_KIND.invalid_read_policy)
        end
    end

    for _, relative in ipairs(options.paths) do
        local absolute = finder_scan.join_path(options.root.path, relative)
        queue:call(function(done) return uv.fs_stat(absolute, done) end, function(stat_error, stat)
            if stat_error or not stat then
                fail_path(relative, absolute, FAILURE_KIND.stat, stat_error)
                return
            end
            if stat.type ~= "file" then
                fail_path(relative, absolute, FAILURE_KIND.invalid_path)
                return
            end
            queue:call(function(done) return uv.fs_realpath(absolute, done) end, function(_, resolved)
                apply_decision(relative, absolute, {
                    root = options.root,
                    root_ordinal = options.root_ordinal,
                    relative = relative,
                    unresolved_absolute = absolute,
                    resolved_absolute = resolved,
                    stat = stat,
                })
            end)
        end)
    end

    finish_if_ready()
    return handle
end

return M
