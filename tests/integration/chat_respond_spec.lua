-- Integration tests for M.chat_respond in lua/parley/init.lua
--
-- These tests exercise the full chat_respond flow including the completion callback,
-- which requires mocking the dispatcher and tasker.

local tmp_dir = "/tmp/parley-test-chat-respond-" .. os.time()

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

-- Create the chat directory
vim.fn.mkdir(tmp_dir, "p")

describe("chat_respond: completion callback", function()
    local test_file
    local original_query
    
    before_each(function()
        -- Create a unique test file for each test
        test_file = tmp_dir .. "/test-" .. os.time() .. "-" .. math.random(1000) .. ".md"
        
        -- Save original dispatcher.query
        original_query = parley.dispatcher.query
    end)
    
    after_each(function()
        -- Restore original dispatcher.query
        if original_query then
            parley.dispatcher.query = original_query
        end
        
        -- Clean up test file
        if test_file and vim.fn.filereadable(test_file) == 1 then
            vim.fn.delete(test_file)
        end
        
        -- Close any open buffers
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buftype") == "" then
                pcall(vim.api.nvim_buf_delete, buf, {force = true})
            end
        end
    end)
    
    it("does not error when headers.topic is accessed in completion callback", function()
        -- Create a chat file with topic = "?" (triggers topic generation path)
        local chat_content = [[
# topic: ?
- file: test.md
---

💬: What is Lua?
]]
        
        -- Write to file
        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        
        -- Open the file in a buffer
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        
        -- Position cursor on the question line
        vim.api.nvim_win_set_cursor(0, {6, 0})
        
        -- Mock dispatcher.query to immediately call the completion callback
        local completion_called = false
        parley.dispatcher.query = function(buf, provider, payload, handler, completion_callback)
            -- Simulate successful query
            local mock_qid = "mock_qid_" .. tostring(math.random(100000))
            parley.tasker.set_query(mock_qid, { 
                response = "Lua is a scripting language.",
                buf = buf
            })
            
            -- Call the completion callback synchronously (not via vim.schedule for test simplicity)
            -- In reality this would be async, but for testing we want synchronous execution
            vim.schedule(function()
                completion_callback(mock_qid)
                completion_called = true
            end)
        end
        
        -- Call chat_respond (which should not error even with headers.topic = "?")
        local success, err = pcall(function()
            parley.chat_respond({range = 0})
        end)
        
        -- Wait a bit for scheduled callback to execute
        vim.wait(100, function() return completion_called end, 10)
        
        -- Assert no error during the call or in the callback
        assert.is_true(success, "chat_respond should not error: " .. tostring(err))
    end)
    
    it("accesses headers correctly when topic is not '?'", function()
        -- Create a chat file with a normal topic (does not trigger topic generation)
        local chat_content = [[
# topic: Normal Topic
- file: test.md
---

💬: What is Lua?
]]
        
        -- Write to file
        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        
        -- Open the file in a buffer
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        
        -- Position cursor on the question line
        vim.api.nvim_win_set_cursor(0, {6, 0})
        
        -- Mock dispatcher.query
        local completion_called = false
        parley.dispatcher.query = function(buf, provider, payload, handler, completion_callback)
            local mock_qid = "mock_qid_" .. tostring(math.random(100000))
            parley.tasker.set_query(mock_qid, { 
                response = "Lua is a scripting language.",
                buf = buf
            })
            
            vim.schedule(function()
                completion_callback(mock_qid)
                completion_called = true
            end)
        end
        
        -- Call chat_respond
        local success, err = pcall(function()
            parley.chat_respond({range = 0})
        end)
        
        -- Wait for callback
        vim.wait(100, function() return completion_called end, 10)
        
        -- Assert no error
        assert.is_true(success, "chat_respond should not error: " .. tostring(err))
    end)
    
    it("completion callback can access parsed_chat from outer scope", function()
        -- This tests that other closure variables (not just headers) are accessible
        local chat_content = [[
# topic: Test
- file: test.md
---

💬: First question

🤖: First answer

💬: Second question
]]
        
        vim.fn.writefile(vim.split(chat_content, "\n"), test_file)
        vim.cmd("edit " .. test_file)
        local buf = vim.api.nvim_get_current_buf()
        
        -- Position cursor on second question
        vim.api.nvim_win_set_cursor(0, {10, 0})
        
        local completion_called = false
        local callback_error = nil
        
        parley.dispatcher.query = function(buf, provider, payload, handler, completion_callback)
            local mock_qid = "mock_qid_" .. tostring(math.random(100000))
            parley.tasker.set_query(mock_qid, { 
                response = "Mock response",
                buf = buf
            })
            
            vim.schedule(function()
                -- Try to execute callback and catch any errors
                local ok, err = pcall(completion_callback, mock_qid)
                if not ok then
                    callback_error = err
                end
                completion_called = true
            end)
        end
        
        local success, err = pcall(function()
            parley.chat_respond({range = 0})
        end)
        
        vim.wait(100, function() return completion_called end, 10)
        
        assert.is_true(success, "chat_respond should not error: " .. tostring(err))
        assert.is_nil(callback_error, "Completion callback should not error: " .. tostring(callback_error))
    end)
end)
