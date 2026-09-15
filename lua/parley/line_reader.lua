-- Observable, buffer-scoped seam for performance-sensitive text reads.

local M = {}

local states = {}
local function pack(...) return { n = select("#", ...), ... } end

local function state_for(buf)
    local state = states[buf]
    if not state then
        state = { generation = 0, phases = {} }
        states[buf] = state
    end
    return state
end

local function observe(buf, event)
    local state = states[buf]
    if not state or not state.observer then return end
    event.buf = buf
    event.phase = state.phases[#state.phases]
    pcall(state.observer, event)
end

function M.set_observer(buf, fn)
    assert(type(fn) == "function", "line reader observer must be a function")
    local state = state_for(buf)
    state.generation = state.generation + 1
    local token = { generation = state.generation }
    state.token = token
    state.observer = fn
    return token
end

function M.clear_observer(buf, token)
    local state = states[buf]
    if not state or state.token ~= token then return false end
    state.observer = nil
    state.token = nil
    return true
end

function M.clear_buffer(buf)
    states[buf] = nil
end

function M.with_phase(buf, phase, fn)
    local state = state_for(buf)
    state.phases[#state.phases + 1] = phase
    local result = pack(pcall(fn))
    state.phases[#state.phases] = nil
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
end

function M.record_work(buf, event)
    local copy = {}
    for key, value in pairs(event or {}) do copy[key] = value end
    copy.operation = copy.operation or "work"
    copy.requested = copy.requested or {}
    copy.bytes_read = copy.bytes_read or 0
    copy.returned_lines = copy.returned_lines or 0
    copy.lines_requested = copy.lines_requested or 0
    copy.full_buffer = copy.full_buffer or false
    copy.structure_rows_processed = copy.structure_rows_processed or 0
    copy.structure_entries_copied = copy.structure_entries_copied or 0
    observe(buf, copy)
end

local function production_delegate()
    return {
        offset = function(buf, row) return vim.api.nvim_buf_get_offset(buf, row) end,
        lines = function(buf, start0, end0, strict)
            return vim.api.nvim_buf_get_lines(buf, start0, end0, strict)
        end,
        text = function(buf, sr, sc, er, ec, opts)
            return vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, opts)
        end,
        line = function(buf, row0)
            return vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1]
        end,
    }
end

local function invoke(buf, event, fn)
    local result = pack(pcall(fn))
    if result[1] then
        local value = result[2]
        -- Count payload bytes only: API arrays contain no newline separators.
        -- Only scan returned strings when observed; ordinary reads pay no scan.
        event.bytes_read = 0
        local state = states[buf]
        if state and state.observer then
            if type(value) == "table" then
                for _, line in ipairs(value) do event.bytes_read = event.bytes_read + #line end
            elseif type(value) == "string" then
                event.bytes_read = #value
            end
        end
        event.returned_lines = type(value) == "table" and #value or (value ~= nil and 1 or 0)
        if event.operation == "lines" and event.requested.end_row == -1 then
            event.lines_requested = event.returned_lines
        end
        observe(buf, event)
        return unpack(result, 2, result.n)
    end
    event.returned_lines = 0
    event.bytes_read = 0
    observe(buf, event)
    error(result[2], 0)
end

function M.for_buffer(buf, opts)
    opts = opts or {}
    local delegate = opts.delegate or production_delegate()
    local reader = {}

    function reader.lines(_, start0, end0, strict)
        local requested_count = end0 == -1 and -1 or math.max(0, end0 - start0)
        return invoke(buf, {
            operation = "lines",
            requested = { start_row = start0, end_row = end0, strict = strict },
            lines_requested = requested_count,
            full_buffer = start0 == 0 and end0 == -1,
            structure_rows_processed = 0,
            structure_entries_copied = 0,
        }, function() return delegate.lines(buf, start0, end0, strict) end)
    end

    function reader.text(_, sr, sc, er, ec, text_opts)
        local touched = math.max(0, er - sr + (ec > 0 and 1 or 0))
        return invoke(buf, {
            operation = "text",
            requested = { start_row = sr, start_col = sc, end_row = er, end_col = ec, opts = text_opts },
            lines_requested = touched,
            full_buffer = false,
            structure_rows_processed = 0,
            structure_entries_copied = 0,
        }, function() return delegate.text(buf, sr, sc, er, ec, text_opts) end)
    end

    function reader.line(_, row0)
        return invoke(buf, {
            operation = "line",
            requested = { row = row0 },
            lines_requested = 1,
            full_buffer = false,
            structure_rows_processed = 0,
            structure_entries_copied = 0,
        }, function() return delegate.line(buf, row0) end)
    end

    -- Byte offsets provide line length without materializing a long line.
    -- Neovim's serialized buffer offsets include one separator per row.
    function reader.chunk(_, request)
        local function integer(value)
            return type(value) == "number" and value >= 0 and value < math.huge and value % 1 == 0
        end
        assert(type(request) == "table" and integer(request.row) and integer(request.col), "invalid chunk position")
        assert(integer(request.max_bytes) and request.max_bytes >= 1 and request.max_bytes <= 65536,
            "chunk size must be between 1 and 65536 bytes")
        local first = delegate.offset(buf, request.row)
        local last = delegate.offset(buf, request.row + 1)
        assert(first >= 0 and last > first, "chunk row is outside the buffer")
        local length = last - first - 1
        assert(request.col <= length, "chunk column is outside the row")
        local stop = math.min(length, request.col + request.max_bytes)
        local bytes = reader:text(request.row, request.col, request.row, stop, {})[1] or ""
        return { request_id = request.request_id, bytes = bytes, eol = stop == length,
            start_byte = first, separator_bytes = 1 }
    end

    return reader
end

return M
