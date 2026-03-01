-- Unit tests for helper.process_directory_pattern in lua/parley/helper.lua
--
-- process_directory_pattern is a pure filesystem function that:
-- - Parses directory patterns with optional glob (*, **/*)
-- - Finds matching files (recursive if ** present)
-- - Returns formatted content with line numbers wrapped in code fences
--
-- Strategy: Create real temporary directories/files on disk, call the function,
-- assert on the returned string content. Clean up in after_each.

local helper = require("parley.helper")

describe("helper.process_directory_pattern", function()
    local tmpdir
    
    before_each(function()
        -- Create a unique temp directory
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-dirpattern-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
        
        -- Create a known file tree:
        -- tmpdir/
        --   file_a.lua     (content: "-- lua file A")
        --   file_b.md      (content: "# markdown B")
        --   sub/
        --     deep.lua     (content: "-- deep lua")
        
        -- Create file_a.lua
        local file_a = io.open(tmpdir .. "/file_a.lua", "w")
        file_a:write("-- lua file A\n")
        file_a:close()
        
        -- Create file_b.md
        local file_b = io.open(tmpdir .. "/file_b.md", "w")
        file_b:write("# markdown B\n")
        file_b:close()
        
        -- Create subdirectory and deep.lua
        vim.fn.mkdir(tmpdir .. "/sub", "p")
        local deep = io.open(tmpdir .. "/sub/deep.lua", "w")
        deep:write("-- deep lua\n")
        deep:close()
    end)
    
    after_each(function()
        -- Clean up temp directory
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
    end)
    
    describe("Group A: Non-recursive directory (no glob)", function()
        it("A1: returns header with file count", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Should contain "Directory listing for ... (2 files):"
            -- (2 files because sub/ is a directory, not counted)
            assert.is_true(result:find("Directory listing") ~= nil)
            assert.is_true(result:find("2 files") ~= nil)
        end)
        
        it("A2: returned string contains file path", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Should contain File: .../file_a.lua
            assert.is_true(result:find("File:.*file_a%.lua") ~= nil)
        end)
        
        it("A3: returned string contains file line content with line numbers", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Should contain "1: -- lua file A"
            assert.is_true(result:find("1: %-%-") ~= nil)
        end)
        
        it("A4: empty directory returns 'No files found'", function()
            local emptydir = tmpdir .. "/empty"
            vim.fn.mkdir(emptydir, "p")
            
            local result = helper.process_directory_pattern(emptydir)
            
            assert.is_true(result:find("No files found") ~= nil)
        end)
        
        it("A5: non-existent directory returns 'No files found'", function()
            local result = helper.process_directory_pattern(tmpdir .. "/nonexistent")
            
            assert.is_true(result:find("No files found") ~= nil)
        end)
    end)
    
    describe("Group B: Glob pattern (single *)", function()
        it("B1: *.lua includes only lua files, not md files", function()
            local result = helper.process_directory_pattern(tmpdir .. "/*.lua")
            
            -- Should include file_a.lua
            assert.is_true(result:find("file_a%.lua") ~= nil)
            
            -- Should NOT include file_b.md
            assert.is_true(result:find("file_b%.md") == nil)
        end)
        
        it("B2: *.md includes only md files, not lua files", function()
            local result = helper.process_directory_pattern(tmpdir .. "/*.md")
            
            -- Should include file_b.md
            assert.is_true(result:find("file_b%.md") ~= nil)
            
            -- Should NOT include file_a.lua
            assert.is_true(result:find("file_a%.lua") == nil)
        end)
    end)
    
    describe("Group C: Recursive pattern (**)", function()
        it("C1: **/*.lua finds lua files in subdirectories", function()
            local result = helper.process_directory_pattern(tmpdir .. "/**/*.lua")
            
            -- Should include both file_a.lua and sub/deep.lua
            assert.is_true(result:find("file_a%.lua") ~= nil)
            assert.is_true(result:find("deep%.lua") ~= nil)
        end)
        
        it("C2: **/* finds all files recursively", function()
            local result = helper.process_directory_pattern(tmpdir .. "/**/*")
            
            -- Should include all 3 files (file_a.lua, file_b.md, sub/deep.lua)
            assert.is_true(result:find("file_a%.lua") ~= nil)
            assert.is_true(result:find("file_b%.md") ~= nil)
            assert.is_true(result:find("deep%.lua") ~= nil)
        end)
    end)
    
    describe("Group D: Trailing slash", function()
        it("D1: trailing slash treats as non-recursive directory", function()
            local result = helper.process_directory_pattern(tmpdir .. "/")
            
            -- Should include files directly in tmpdir
            assert.is_true(result:find("file_a%.lua") ~= nil)
            assert.is_true(result:find("file_b%.md") ~= nil)
            
            -- Should count 2 files (not recursive into sub/)
            assert.is_true(result:find("2 files") ~= nil)
        end)
    end)
    
    describe("Group E: Content formatting", function()
        it("E1: each file section begins with 'File:' header", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Count occurrences of "File:"
            local count = 0
            for _ in result:gmatch("File:") do
                count = count + 1
            end
            
            -- Should be 2 (file_a.lua and file_b.md)
            assert.equals(2, count)
        end)
        
        it("E2: content wrapped in code fences", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Should contain opening fence with filetype
            assert.is_true(result:find("```lua") ~= nil or result:find("```markdown") ~= nil)
            
            -- Should contain closing fence
            local fence_count = 0
            for _ in result:gmatch("```") do
                fence_count = fence_count + 1
            end
            
            -- Each file has opening + closing fence (2 files × 2 fences = 4)
            assert.is_true(fence_count >= 4)
        end)
        
        it("E3: line numbers present (1: prefix)", function()
            local result = helper.process_directory_pattern(tmpdir)
            
            -- Should contain line number prefix "1:"
            assert.is_true(result:find("1:") ~= nil)
        end)
    end)
end)
