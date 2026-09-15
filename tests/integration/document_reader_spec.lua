local Reader = require("parley.line_reader")

describe("bounded document text reader", function()
    local buf
    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        if buf then Reader.clear_buffer(buf) end
    end)

    it("reads huge rows in exact bounded byte chunks without fetching whole lines", function()
        buf = vim.api.nvim_create_buf(false, true)
        local line = "💬: " .. string.rep("é", 50000)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "before", line, "" })
        local events = {}
        Reader.set_observer(buf, function(event) events[#events + 1] = event end)
        local reader = Reader.for_buffer(buf)
        assert.equals("function", type(reader.chunk))
        local pieces, col = {}, 0
        repeat
            local input = reader:chunk({ request_id = 254, row = 1, col = col, max_bytes = 101 })
            assert.equals(254, input.request_id)
            assert.equals(7, input.start_byte)
            assert.is_true(#input.bytes <= 101)
            pieces[#pieces + 1] = input.bytes
            col = col + #input.bytes
            if input.eol then break end
        until false
        assert.equals(line, table.concat(pieces))
        for _, event in ipairs(events) do
            assert.equals("text", event.operation)
            assert.is_false(event.full_buffer)
            assert.is_true(event.bytes_read <= 101)
        end
    end)

    it("normalizes the editor's final empty row without reading another row", function()
        buf = vim.api.nvim_create_buf(false, true)
        local reader = Reader.for_buffer(buf)
        assert.equals("function", type(reader.chunk))
        local result = reader:chunk({ request_id = 1, row = 0, col = 0, max_bytes = 64 })
        assert.equals("", result.bytes)
        assert.is_true(result.eol)
        assert.equals(0, result.start_byte)
        assert.equals(1, result.separator_bytes)
    end)

    it("rejects unbounded read requests before fetching payload", function()
        buf = vim.api.nvim_create_buf(false, true)
        local reader = Reader.for_buffer(buf)
        assert.equals("function", type(reader.chunk))
        for _, size in ipairs({ math.huge, -1, 0, 65537, 1.5 }) do
            assert.has_error(function()
                reader:chunk({ request_id = 1, row = 0, col = 0, max_bytes = size })
            end)
        end
    end)
end)
