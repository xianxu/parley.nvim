-- Integration tests for ExportHTML and ExportMarkdown
--
-- These commands export chat transcripts to HTML and Markdown formats.
-- Tests verify end-to-end functionality: file creation, content transformation, and validation.

local M = require("parley")

describe("Export commands", function()
    local tmpdir
    local export_html_dir
    local export_markdown_dir
    local original_config
    
    before_each(function()
        -- Save original config
        original_config = vim.deepcopy(M.config)
        
        -- Create temp directories
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-export-" .. random_suffix
        export_html_dir = tmpdir .. "/html"
        export_markdown_dir = tmpdir .. "/markdown"
        
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(export_html_dir, "p")
        vim.fn.mkdir(export_markdown_dir, "p")
        
        -- Configure export directories
        M.config.chat_dir = tmpdir
        M.config.export_html_dir = export_html_dir
        M.config.export_markdown_dir = export_markdown_dir
    end)
    
    after_each(function()
        -- Clean up temp directory
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
        
        -- Restore original config
        M.config = original_config
    end)
    
    local function create_chat_file(filename, content)
        local filepath = tmpdir .. "/" .. filename
        local f = io.open(filepath, "w")
        f:write(content)
        f:close()
        return filepath
    end
    
    describe("Group A: ExportHTML", function()
        it("A1: creates HTML file from valid chat", function()
            -- Create a simple chat file
            local chat_content = [[# topic: Test Chat
- file: test.md
---
💬: Hello, how are you?

🤖: I'm doing well, thank you!
]]
            local chat_file = create_chat_file("2024-03-15-14-30-45-test.md", chat_content)
            
            -- Open the chat file in a buffer
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            assert.is_true(vim.api.nvim_buf_is_valid(buf))
            
            -- Export to HTML
            M.cmd.ExportHTML()
            
            -- Check that HTML file was created
            -- Note: filename is derived from full title "topic: Test Chat" -> "topic_test_chat"
            local html_file = export_html_dir .. "/topic_test_chat.html"
            local exists = vim.fn.filereadable(html_file) == 1
            
            assert.is_true(exists, "HTML file should be created at " .. html_file)
            
            -- Verify content contains expected elements
            if exists then
                local content = table.concat(vim.fn.readfile(html_file), "\n")
                assert.is_true(content:find("<!DOCTYPE html>") ~= nil, "Should have DOCTYPE")
                assert.is_true(content:find("<title>topic: Test Chat</title>") ~= nil, "Should have title")
                assert.is_true(content:find("Question") ~= nil, "Should transform 💬: to Question")
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("A2: handles chat with code blocks", function()
            local chat_content = [[# topic: Code Example
- file: code.md
---
💬: Show me a Python function

🤖: Here's an example:

```python
def hello():
    print("Hello, World!")
```
]]
            local chat_file = create_chat_file("2024-03-15-14-30-46-code.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportHTML()
            
            local html_file = export_html_dir .. "/topic_code_example.html"
            assert.is_true(vim.fn.filereadable(html_file) == 1)
            
            local content = table.concat(vim.fn.readfile(html_file), "\n")
            -- Check for code block styling
            assert.is_true(content:find("python") ~= nil or content:find("code") ~= nil)
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("A3: rejects non-chat files", function()
            -- Create a non-chat file (outside chat_dir)
            local non_chat = "/tmp/non-chat-" .. math.random(999999) .. ".md"
            local f = io.open(non_chat, "w")
            f:write("# Not a chat\n\nJust some text.")
            f:close()
            
            vim.cmd("edit " .. non_chat)
            local buf = vim.api.nvim_get_current_buf()
            
            -- Try to export (should fail validation)
            M.cmd.ExportHTML()
            
            -- Verify no file was created (filename would be based on title)
            local html_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
            assert.equals(0, #html_files, "Should not create HTML for non-chat file")
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
            os.remove(non_chat)
        end)
        
        it("A4: handles empty buffer", function()
            -- Create empty file in chat_dir
            local empty_file = create_chat_file("2024-03-15-14-30-47-empty.md", "")
            
            vim.cmd("edit " .. empty_file)
            local buf = vim.api.nvim_get_current_buf()
            
            -- Try to export (should fail)
            M.cmd.ExportHTML()
            
            -- Verify no HTML was created
            local html_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
            assert.equals(0, #html_files, "Should not create HTML for empty buffer")
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("A5: uses custom export directory from params", function()
            local custom_dir = tmpdir .. "/custom_html"
            vim.fn.mkdir(custom_dir, "p")
            
            local chat_content = [[# topic: Custom Dir Test
- file: custom.md
---
💬: Test question here

🤖: Test response here
]]
            local chat_file = create_chat_file("2024-03-15-14-30-48-custom.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            
            -- Export with custom directory
            M.cmd.ExportHTML({ args = custom_dir })
            
            -- Check file was created in custom directory
            local html_file = custom_dir .. "/topic_custom_dir_test.html"
            assert.is_true(vim.fn.filereadable(html_file) == 1, 
                "Should create HTML in custom directory")
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
    end)
    
    describe("Group B: ExportMarkdown", function()
        it("B1: creates Markdown file with Jekyll front matter", function()
            local chat_content = [[# topic: Jekyll Test
- file: 2024-01-15-jekyll.md
- tags: test, jekyll
---
💬: Hello Jekyll

🤖: Response here
]]
            local chat_file = create_chat_file("2024-03-15-14-30-49-jekyll.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            -- Check that markdown file was created with date prefix
            local md_file = export_markdown_dir .. "/2024-01-15-jekyll_test.markdown"
            local exists = vim.fn.filereadable(md_file) == 1
            
            assert.is_true(exists, "Markdown file should be created at " .. md_file)
            
            if exists then
                local content = table.concat(vim.fn.readfile(md_file), "\n")
                -- Verify Jekyll front matter
                assert.is_true(content:find("^%-%-%-\n") ~= nil, "Should start with ---")
                assert.is_true(content:find("layout: post") ~= nil, "Should have layout")
                assert.is_true(content:find("title:  \"Jekyll Test\"") ~= nil, "Should have title")
                assert.is_true(content:find("date:   2024%-01%-15") ~= nil, "Should have date from file header")
                assert.is_true(content:find("tags: test, jekyll") ~= nil, "Should have tags")
                -- Verify watermark
                assert.is_true(content:find("parley%.nvim") ~= nil, "Should have parley.nvim watermark")
                -- Verify header removal
                assert.is_true(content:find("^# topic:") == nil, "Should remove Parley header")
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("B2: transforms 💬: to #### 💬:", function()
            local chat_content = [[# topic: Transform Test
- file: transform.md
---
💬: Question 1

🤖: Answer 1

💬: Question 2

🤖: Answer 2
]]
            local chat_file = create_chat_file("2024-03-15-14-30-50-transform.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            local md_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
            assert.is_true(#md_files > 0, "Should create markdown file")
            
            if #md_files > 0 then
                local content = table.concat(vim.fn.readfile(md_files[1]), "\n")
                -- Verify transformation
                assert.is_true(content:find("#### 💬:") ~= nil, 
                    "Should transform 💬: to #### 💬:")
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("B3: extracts date from filename when not in header", function()
            local chat_content = [[# topic: Date Extraction
- file: nodate.md
---
💬: Test question

🤖: Test answer
]]
            local chat_file = create_chat_file("2024-05-20-14-30-51-datetest.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            -- File should use date from chat filename
            local md_file = export_markdown_dir .. "/2024-05-20-date_extraction.markdown"
            assert.is_true(vim.fn.filereadable(md_file) == 1,
                "Should use date from chat filename")
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("B4: handles missing tags gracefully", function()
            local chat_content = [[# topic: No Tags
- file: notags.md
---
💬: Test without tags

🤖: Response here
]]
            local chat_file = create_chat_file("2024-03-15-14-30-52-notags.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            local md_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
            assert.is_true(#md_files > 0)
            
            if #md_files > 0 then
                local content = table.concat(vim.fn.readfile(md_files[1]), "\n")
                -- Should have default tags
                assert.is_true(content:find("tags: unclassified") ~= nil,
                    "Should use default 'unclassified' tag")
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("B5: uses custom export directory from params", function()
            local custom_dir = tmpdir .. "/custom_md"
            vim.fn.mkdir(custom_dir, "p")
            
            local chat_content = [[# topic: Custom Markdown
- file: custom.md
---
💬: Test question

🤖: Test response
]]
            local chat_file = create_chat_file("2024-03-15-14-30-53-custommd.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown({ args = custom_dir })
            
            -- Check file was created in custom directory
            local md_files = vim.fn.glob(custom_dir .. "/*.markdown", false, true)
            assert.is_true(#md_files > 0, "Should create markdown in custom directory")
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("B6: rejects non-chat files", function()
            -- Create a non-chat file (outside chat_dir)
            local non_chat = "/tmp/non-chat-md-" .. math.random(999999) .. ".md"
            local f = io.open(non_chat, "w")
            f:write("# Not a chat\n\nJust some text.")
            f:close()
            
            vim.cmd("edit " .. non_chat)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            -- Verify no file was created
            local md_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
            assert.equals(0, #md_files, "Should not create markdown for non-chat file")
            
            -- Delete buffer if it still exists
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
            os.remove(non_chat)
        end)
    end)
    
    describe("Group C: Filename generation", function()
        it("C1: HTML filename is sanitized and lowercased", function()
            local chat_content = [[# topic: Test With Special!@#$%^&* Characters
- file: special.md
- tags: test
---
💬: Test question here
]]
            local chat_file = create_chat_file("2024-03-15-14-30-54-special.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportHTML()
            
            -- Filename should be sanitized
            local html_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
            assert.is_true(#html_files > 0, "Should create HTML file")
            
            if #html_files > 0 then
                local filename = vim.fn.fnamemodify(html_files[1], ":t")
                -- Should only contain safe characters
                assert.is_true(filename:match("^[%w_]+%.html$") ~= nil,
                    "Filename should be sanitized: " .. filename)
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("C2: Markdown filename is sanitized and lowercased", function()
            local chat_content = [[# topic: Jekyll Post: Amazing!
- file: amazing.md
- tags: test
---
💬: Test question here
]]
            local chat_file = create_chat_file("2024-03-15-14-30-55-amazing.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportMarkdown()
            
            local md_files = vim.fn.glob(export_markdown_dir .. "/*.markdown", false, true)
            assert.is_true(#md_files > 0, "Should create markdown file")
            
            if #md_files > 0 then
                local filename = vim.fn.fnamemodify(md_files[1], ":t")
                -- Should match Jekyll pattern: YYYY-MM-DD-sanitized.markdown
                assert.is_true(filename:match("^%d%d%d%d%-%d%d%-%d%d%-[%w_]+%.markdown$") ~= nil,
                    "Filename should follow Jekyll pattern: " .. filename)
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
        
        it("C3: limits filename length to 50 characters", function()
            local long_title = string.rep("Very Long Title ", 10) -- 160+ chars
            local chat_content = "# topic: " .. long_title .. "\n- file: long.md\n- tags: test\n---\n💬: Test question"
            local chat_file = create_chat_file("2024-03-15-14-30-56-long.md", chat_content)
            
            vim.cmd("edit " .. chat_file)
            local buf = vim.api.nvim_get_current_buf()
            M.cmd.ExportHTML()
            
            local html_files = vim.fn.glob(export_html_dir .. "/*.html", false, true)
            if #html_files > 0 then
                local filename = vim.fn.fnamemodify(html_files[1], ":t:r") -- without .html
                -- Should be truncated to 50 chars
                assert.is_true(#filename <= 50, 
                    "Filename length should be <= 50, got " .. #filename)
            end
            
            -- Close buffer if valid
            if vim.api.nvim_buf_is_valid(buf) then
                vim.cmd("bdelete! " .. buf)
            end
        end)
    end)
end)
