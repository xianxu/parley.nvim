local LineReader = require("parley.line_reader")

local function fake_delegate(lines)
    return {
        lines = function(_, start0, end0)
            if start0 < 0 or (end0 ~= -1 and end0 < start0) then error("invalid range") end
            local stop = end0 == -1 and #lines or math.min(end0, #lines)
            local out = {}
            for i = start0 + 1, stop do out[#out + 1] = lines[i] end
            return out
        end,
        text = function(_, sr, sc, er, ec)
            if sr < 0 or er < sr then error("invalid text range") end
            local out = {}
            for row = sr, er do
                local line = lines[row + 1] or ""
                local first = row == sr and sc + 1 or 1
                local last = row == er and ec or #line
                out[#out + 1] = first <= last and line:sub(first, last) or ""
            end
            return out
        end,
        line = function(_, row0)
            if row0 < 0 or not lines[row0 + 1] then error("invalid row") end
            return lines[row0 + 1]
        end,
    }
end

describe("parley.line_reader", function()
    before_each(function()
        LineReader.clear_buffer(11)
        LineReader.clear_buffer(12)
    end)

    it("preserves reads and reports requested versus returned line work", function()
        local events = {}
        LineReader.set_observer(11, function(event) events[#events + 1] = event end)
        local reader = LineReader.for_buffer(11, { delegate = fake_delegate({ "a", "b", "c" }) })

        assert.same({ "b", "c" }, reader:lines(1, 9, false))
        assert.equals("b", reader:line(1))
        assert.same({ "a", "b", "c" }, reader:lines(0, -1, false))

        assert.same({ start_row = 1, end_row = 9, strict = false }, events[1].requested)
        assert.equals(8, events[1].lines_requested)
        assert.equals(2, events[1].returned_lines)
        assert.is_false(events[1].full_buffer)
        assert.equals("line", events[2].operation)
        assert.equals(1, events[2].lines_requested)
        assert.equals(1, events[2].returned_lines)
        assert.is_true(events[3].full_buffer)
        assert.equals(-1, events[3].requested.end_row)
    end)

    it("reports precise rows touched by text reads", function()
        local events = {}
        LineReader.set_observer(11, function(event) events[#events + 1] = event end)
        local reader = LineReader.for_buffer(11, { delegate = fake_delegate({ "abcd", "efgh", "ijkl" }) })

        assert.same({ "bcd", "efgh", "" }, reader:text(0, 1, 2, 0, {}))
        assert.equals(2, events[1].lines_requested)
        assert.equals(3, events[1].returned_lines)
        assert.same({ start_row = 0, start_col = 1, end_row = 2, end_col = 0, opts = {} }, events[1].requested)
    end)

    it("matches native half-open text results at an end-row column zero", function()
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "abcd", "efgh", "ijkl" })
        local event
        LineReader.set_observer(buf, function(e) event = e end)
        local result = LineReader.for_buffer(buf):text(0, 1, 2, 0, {})
        assert.same({ "bcd", "efgh", "" }, result)
        assert.equals(2, event.lines_requested)
        assert.equals(3, event.returned_lines)
        LineReader.clear_buffer(buf)
        vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it("observes invalid attempts while preserving the delegate error", function()
        local events = {}
        LineReader.set_observer(11, function(event) events[#events + 1] = event end)
        local reader = LineReader.for_buffer(11, { delegate = fake_delegate({ "a" }) })
        local ok, err = pcall(function() reader:lines(-1, 0, true) end)
        assert.is_false(ok)
        assert.matches("invalid range", err)
        assert.equals("lines", events[1].operation)
        assert.equals(0, events[1].returned_lines)
    end)

    it("isolates observers, checks tokens, and invalidates state on clear", function()
        local first, second = {}, {}
        local stale = LineReader.set_observer(11, function(e) first[#first + 1] = e end)
        LineReader.set_observer(12, function(e) second[#second + 1] = e end)
        assert.is_false(LineReader.clear_observer(11, {}))
        LineReader.for_buffer(12, { delegate = fake_delegate({ "x" }) }):line(0)
        assert.equals(0, #first)
        assert.equals(1, #second)
        LineReader.clear_buffer(11)
        assert.is_false(LineReader.clear_observer(11, stale))
    end)

    it("restores nested phases on success and error", function()
        local phases = {}
        LineReader.set_observer(11, function(e) phases[#phases + 1] = e.phase end)
        local reader = LineReader.for_buffer(11, { delegate = fake_delegate({ "x" }) })
        LineReader.with_phase(11, "outer", function()
            reader:line(0)
            local ok, err = pcall(function()
                LineReader.with_phase(11, "inner", function()
                    reader:line(0)
                    error("boom")
                end)
            end)
            assert.is_false(ok)
            assert.matches("boom", err)
            reader:line(0)
        end)
        reader:line(0)
        assert.same({ "outer", "inner", "outer", nil }, phases)
    end)

    it("records CPU-side structural work in the active phase", function()
        local event
        LineReader.set_observer(11, function(e) event = e end)
        LineReader.with_phase(11, "parse", function()
            LineReader.record_work(11, { operation = "footer_scan", structure_rows_processed = 17 })
        end)
        assert.equals(11, event.buf)
        assert.equals("parse", event.phase)
        assert.equals("footer_scan", event.operation)
        assert.equals(17, event.structure_rows_processed)
    end)
end)
