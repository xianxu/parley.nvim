-- Integration tests for D.create_handler in lua/parley/dispatcher.lua
--
-- create_handler returns a closure that writes streaming chunks to a buffer.
-- These tests verify the incremental writing behavior.

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = "/tmp/parley-test-handler",
    state_dir = "/tmp/parley-test-handler/state",
    providers = {},
    api_keys = {},
})

describe("create_handler: streaming behavior", function()
    local buf
    local mock_qid
    
    before_each(function()
        -- Create a scratch buffer for each test
        buf = vim.api.nvim_create_buf(false, true)
        
        -- Write some initial lines with empty line at position 3 where handler will write
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            "Line 0",
            "Line 1",
            "Line 2",
            "", -- Line 3 (empty, handler will write here)
            "Line 4",
        })
        
        -- Register a fake query
        mock_qid = "test_qid_" .. math.random(100000)
        parley.tasker.set_query(mock_qid, {
            response = "",
            buf = buf
        })
    end)
    
    after_each(function()
        -- Clean up buffer
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, {force = true})
        end
    end)
    
    it("first chunk is written to the correct line", function()
        -- Create handler that will write at line 3 (0-indexed)
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false)
        
        -- Call handler with first chunk
        handler(mock_qid, "Hello ")
        
        -- Wait for vim.schedule_wrap to execute and buffer to be written
        vim.wait(100, function()
            local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
            return line == "Hello "
        end, 10)
        
        -- Check that line 3 now contains our text
        local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
        assert.equals("Hello ", line)
    end)
    
    it("second chunk is accumulated and merged correctly", function()
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false)
        
        handler(mock_qid, "Hello ")
        vim.wait(100, function()
            local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
            return line == "Hello "
        end, 10)
        
        handler(mock_qid, "world")
        vim.wait(100, function()
            local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
            return line == "Hello world"
        end, 10)
        
        -- Should have "Hello world" on a single line
        local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
        assert.equals("Hello world", line)
    end)
    
    it("multi-line response splits across lines correctly", function()
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false)
        
        handler(mock_qid, "Line A\nLine B")
        vim.wait(100, function()
            local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
            return lines[1] == "Line A" and lines[2] == "Line B"
        end, 10)
        
        -- Should have two lines starting at line 3
        local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
        assert.equals("Line A", lines[1])
        assert.equals("Line B", lines[2])
    end)
    
    it("prefix is prepended to each written line", function()
        -- Create handler with ">> " prefix
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, ">> ", false)
        
        handler(mock_qid, "text")
        vim.wait(100, function()
            local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
            return line == ">> text"
        end, 10)
        
        local line = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
        assert.equals(">> text", line)
    end)
    
    it("multi-line with prefix prepends to each line", function()
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, ">> ", false)
        
        handler(mock_qid, "Line 1\nLine 2")
        vim.wait(100, function()
            local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
            return lines[1] == ">> Line 1" and lines[2] == ">> Line 2"
        end, 10)
        
        local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
        assert.equals(">> Line 1", lines[1])
        assert.equals(">> Line 2", lines[2])
    end)
    
    it("invalid buffer returns early without error", function()
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false)
        
        -- Delete the buffer
        vim.api.nvim_buf_delete(buf, {force = true})
        
        -- Calling handler should not crash
        local success = pcall(function()
            handler(mock_qid, "text")
            vim.wait(50, function() return true end)
        end)
        
        assert.is_true(success, "Handler should not crash when buffer is invalid")
    end)
    
    it("incremental write only updates the last incomplete line", function()
        local handler = parley.dispatcher.create_handler(buf, nil, 3, true, "", false)
        
        -- First chunk with complete line + partial
        handler(mock_qid, "Complete\nPartial")
        vim.wait(100, function()
            local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
            return lines[1] == "Complete" and lines[2] == "Partial"
        end, 10)
        
        local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
        assert.equals("Complete", lines[1])
        assert.equals("Partial", lines[2])
        
        -- Second chunk continues the partial line
        handler(mock_qid, " continued")
        vim.wait(100, function()
            local lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
            return lines[1] == "Complete" and lines[2] == "Partial continued"
        end, 10)
        
        lines = vim.api.nvim_buf_get_lines(buf, 3, 5, false)
        assert.equals("Complete", lines[1])
        assert.equals("Partial continued", lines[2])
    end)
end)
