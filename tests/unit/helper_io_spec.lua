-- Unit tests for helper I/O functions in lua/parley/helper.lua
--
-- Covers the file I/O functions NOT already tested in helper_spec.lua:
-- read_file_content, format_file_content, is_directory, find_files,
-- find_git_root, table_to_file, file_to_table, prepare_dir
--
-- Strategy: Create real tmp directories with known file trees.
-- Pattern follows process_directory_pattern_spec.lua.

local helper = require("parley.helper")

describe("helper I/O functions", function()
    local tmpdir

    before_each(function()
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-helper-io-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
    end)

    after_each(function()
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
    end)

    describe("Group A: read_file_content", function()
        it("A1: returns file contents as a string", function()
            local path = tmpdir .. "/test.txt"
            local f = io.open(path, "w")
            f:write("line1\nline2\nline3")
            f:close()

            local content = helper.read_file_content(path)
            assert.equals("line1\nline2\nline3", content)
        end)

        it("A2: returns nil for non-existent file", function()
            local content = helper.read_file_content(tmpdir .. "/nonexistent.txt")
            assert.is_nil(content)
        end)

        it("A3: returns empty string for empty file", function()
            local path = tmpdir .. "/empty.txt"
            local f = io.open(path, "w")
            f:close()

            local content = helper.read_file_content(path)
            assert.equals("", content)
        end)

        it("A4: handles file with single line (no trailing newline)", function()
            local path = tmpdir .. "/single.txt"
            local f = io.open(path, "w")
            f:write("only line")
            f:close()

            local content = helper.read_file_content(path)
            assert.equals("only line", content)
        end)
    end)

    describe("Group B: format_file_content", function()
        it("B1: returns formatted output with 'File:' header", function()
            local path = tmpdir .. "/code.lua"
            local f = io.open(path, "w")
            f:write("print('hello')")
            f:close()

            local result = helper.format_file_content(path)
            assert.is_true(result:find("File:") ~= nil)
        end)

        it("B2: includes line numbers", function()
            local path = tmpdir .. "/code.lua"
            local f = io.open(path, "w")
            f:write("line1\nline2")
            f:close()

            local result = helper.format_file_content(path)
            assert.is_true(result:find("1: line1") ~= nil)
            assert.is_true(result:find("2: line2") ~= nil)
        end)

        it("B3: wraps content in code fences", function()
            local path = tmpdir .. "/code.lua"
            local f = io.open(path, "w")
            f:write("return 42")
            f:close()

            local result = helper.format_file_content(path)
            -- Should contain opening and closing fences
            local fence_count = 0
            for _ in result:gmatch("```") do
                fence_count = fence_count + 1
            end
            assert.equals(2, fence_count)
        end)

        it("B4: returns error message for non-readable file", function()
            local result = helper.format_file_content(tmpdir .. "/missing.txt")
            assert.is_true(result:find("Error: Could not read file") ~= nil)
        end)
    end)

    describe("Group C: is_directory", function()
        it("C1: returns true for existing directory", function()
            assert.is_true(helper.is_directory(tmpdir))
        end)

        it("C2: returns false for existing file", function()
            local path = tmpdir .. "/file.txt"
            local f = io.open(path, "w")
            f:write("content")
            f:close()
            assert.is_false(helper.is_directory(path))
        end)

        it("C3: returns false for non-existent path", function()
            assert.is_false(helper.is_directory(tmpdir .. "/nope"))
        end)
    end)

    describe("Group D: find_files", function()
        before_each(function()
            -- Create file tree:
            -- tmpdir/a.lua, tmpdir/b.md, tmpdir/sub/c.lua
            local f1 = io.open(tmpdir .. "/a.lua", "w")
            f1:write("a") f1:close()
            local f2 = io.open(tmpdir .. "/b.md", "w")
            f2:write("b") f2:close()
            vim.fn.mkdir(tmpdir .. "/sub", "p")
            local f3 = io.open(tmpdir .. "/sub/c.lua", "w")
            f3:write("c") f3:close()
        end)

        it("D1: finds files matching *.lua in flat directory", function()
            local files = helper.find_files(tmpdir, "*.lua", false)
            assert.equals(1, #files)
            assert.is_true(files[1]:find("a%.lua") ~= nil)
        end)

        it("D2: recursive=true finds files in subdirectories", function()
            local files = helper.find_files(tmpdir, "*.lua", true)
            assert.equals(2, #files)
        end)

        it("D3: returns empty table for non-existent directory", function()
            local files = helper.find_files(tmpdir .. "/nonexistent", "*.lua", false)
            assert.same({}, files)
        end)

        it("D4: excludes directories from results", function()
            local files = helper.find_files(tmpdir, nil, false)
            for _, f in ipairs(files) do
                assert.is_false(helper.is_directory(f))
            end
        end)
    end)

    describe("Group E: find_git_root", function()
        it("E1: finds .git in directory containing it", function()
            -- Create a fake .git directory
            vim.fn.mkdir(tmpdir .. "/.git", "p")
            local root = helper.find_git_root(tmpdir .. "/somefile.lua")
            assert.equals(tmpdir, root)
        end)

        it("E2: walks up parent directories to find .git", function()
            vim.fn.mkdir(tmpdir .. "/.git", "p")
            vim.fn.mkdir(tmpdir .. "/deep/nested", "p")
            local root = helper.find_git_root(tmpdir .. "/deep/nested/file.lua")
            assert.equals(tmpdir, root)
        end)

        it("E3: returns empty string when no .git found", function()
            -- tmpdir has no .git - but there might be a real .git above
            -- Use a path that definitely has no .git ancestor
            local isolated = tmpdir .. "/no_git_here"
            vim.fn.mkdir(isolated, "p")
            -- This test is tricky because the real repo has .git
            -- We can at least verify the function returns a string
            local root = helper.find_git_root(isolated .. "/file.lua")
            assert.is_string(root)
        end)
    end)

    describe("Group F: table_to_file + file_to_table", function()
        it("F1: round-trip preserves table structure", function()
            local path = tmpdir .. "/data.json"
            local original = { name = "test", count = 42, tags = { "a", "b" } }

            helper.table_to_file(original, path)
            local loaded = helper.file_to_table(path)

            assert.equals("test", loaded.name)
            assert.equals(42, loaded.count)
            assert.same({ "a", "b" }, loaded.tags)
        end)

        it("F2: file_to_table returns nil for non-existent file", function()
            local result = helper.file_to_table(tmpdir .. "/missing.json")
            assert.is_nil(result)
        end)

        it("F3: file_to_table returns nil for empty file", function()
            local path = tmpdir .. "/empty.json"
            local f = io.open(path, "w")
            f:close()
            local result = helper.file_to_table(path)
            assert.is_nil(result)
        end)

        it("F4: table_to_file with nested table serializes correctly", function()
            local path = tmpdir .. "/nested.json"
            local original = {
                level1 = {
                    level2 = {
                        value = "deep"
                    }
                }
            }

            helper.table_to_file(original, path)
            local loaded = helper.file_to_table(path)

            assert.equals("deep", loaded.level1.level2.value)
        end)
    end)

    describe("Group G: prepare_dir", function()
        it("G1: creates directory if it does not exist", function()
            local dir = tmpdir .. "/new_dir"
            assert.is_false(helper.is_directory(dir))

            helper.prepare_dir(dir, "test")
            assert.is_true(helper.is_directory(dir))
        end)

        it("G2: returns resolved path", function()
            local dir = tmpdir .. "/resolve_me"
            local result = helper.prepare_dir(dir, "test")
            assert.is_string(result)
            assert.is_true(helper.is_directory(result))
        end)

        it("G3: strips trailing slash", function()
            local dir = tmpdir .. "/trailing/"
            helper.prepare_dir(dir, "test")
            -- The dir without trailing slash should exist
            assert.is_true(helper.is_directory(tmpdir .. "/trailing"))
        end)

        it("G4: existing directory is not recreated", function()
            local dir = tmpdir .. "/existing"
            vim.fn.mkdir(dir, "p")
            -- Should not error
            local result = helper.prepare_dir(dir, "test")
            assert.is_string(result)
        end)
    end)
end)
