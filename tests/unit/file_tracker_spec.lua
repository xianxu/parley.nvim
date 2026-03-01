-- Unit tests for file_tracker module in lua/parley/file_tracker.lua
--
-- The file tracker manages file access statistics with JSON persistence:
-- - track_file_access: records access count and timestamp
-- - get_last_access_time: returns timestamp with fs_stat fallback
-- - get_access_count: returns count for tracked files
-- - load_data / save_data: JSON persistence
-- - cleanup: removes entries for deleted files
--
-- Strategy: Monkey-patch vim.fn.stdpath before requiring the module
-- so access_data_file points to a tmp directory.

describe("file_tracker", function()
    local file_tracker
    local tmpdir
    local original_stdpath

    before_each(function()
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-tracker-" .. random_suffix
        vim.fn.mkdir(tmpdir .. "/parley", "p")

        -- Monkey-patch stdpath to redirect data directory
        original_stdpath = vim.fn.stdpath
        vim.fn.stdpath = function(what)
            if what == "data" then
                return tmpdir
            end
            return original_stdpath(what)
        end

        -- Clear and re-require module
        package.loaded["parley.file_tracker"] = nil
        file_tracker = require("parley.file_tracker")
        -- Reset internal state
        file_tracker._file_access = {}
    end)

    after_each(function()
        vim.fn.stdpath = original_stdpath
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
    end)

    describe("Group A: track + get functions", function()
        it("A1: tracking a new file creates entry with access_count=1", function()
            local test_file = tmpdir .. "/test_file.txt"
            local f = io.open(test_file, "w")
            f:write("test") f:close()

            file_tracker.track_file_access(test_file)
            assert.equals(1, file_tracker.get_access_count(test_file))
        end)

        it("A2: tracking same file twice increments access_count to 2", function()
            local test_file = tmpdir .. "/test_file.txt"
            local f = io.open(test_file, "w")
            f:write("test") f:close()

            file_tracker.track_file_access(test_file)
            file_tracker.track_file_access(test_file)
            assert.equals(2, file_tracker.get_access_count(test_file))
        end)

        it("A3: get_last_access_time returns reasonable timestamp for tracked file", function()
            local test_file = tmpdir .. "/test_file.txt"
            local f = io.open(test_file, "w")
            f:write("test") f:close()

            local before = os.time()
            file_tracker.track_file_access(test_file)
            local after = os.time()

            local access_time = file_tracker.get_last_access_time(test_file)
            assert.is_true(access_time >= before)
            assert.is_true(access_time <= after)
        end)

        it("A4: get_last_access_time for untracked existing file falls back to fs_stat", function()
            local test_file = tmpdir .. "/untracked.txt"
            local f = io.open(test_file, "w")
            f:write("test") f:close()

            local access_time = file_tracker.get_last_access_time(test_file)
            -- Should return mtime from fs_stat, which is > 0
            assert.is_true(access_time > 0)
        end)

        it("A5: get_last_access_time for non-existent, untracked file returns 0", function()
            local access_time = file_tracker.get_last_access_time(tmpdir .. "/nonexistent.txt")
            assert.equals(0, access_time)
        end)

        it("A6: get_access_count for untracked file returns 0", function()
            assert.equals(0, file_tracker.get_access_count(tmpdir .. "/nonexistent.txt"))
        end)
    end)

    describe("Group B: load_data + save_data", function()
        it("B1: save_data writes JSON to file", function()
            file_tracker._file_access = {
                ["/tmp/test.txt"] = { last_accessed = 1000, access_count = 5 }
            }
            local result = file_tracker.save_data()
            assert.is_true(result)
        end)

        it("B2: load_data reads JSON from file and populates _file_access", function()
            -- First save some data
            file_tracker._file_access = {
                ["/tmp/test.txt"] = { last_accessed = 1000, access_count = 5 }
            }
            file_tracker.save_data()

            -- Clear and reload
            file_tracker._file_access = {}
            local result = file_tracker.load_data()
            assert.is_true(result)
            assert.equals(5, file_tracker._file_access["/tmp/test.txt"].access_count)
        end)

        it("B3: load_data with non-existent file returns false", function()
            local result = file_tracker.load_data()
            assert.is_false(result)
            assert.same({}, file_tracker._file_access)
        end)

        it("B4: load_data with malformed JSON returns false", function()
            -- Write invalid JSON to the data file
            local data_file = tmpdir .. "/parley/file_access.json"
            vim.fn.writefile({ "not valid json {{{" }, data_file)

            local result = file_tracker.load_data()
            assert.is_false(result)
            assert.same({}, file_tracker._file_access)
        end)

        it("B5: round-trip: track -> save -> clear -> load -> verify", function()
            local test_file = tmpdir .. "/roundtrip.txt"
            local f = io.open(test_file, "w")
            f:write("test") f:close()

            file_tracker.track_file_access(test_file)
            file_tracker.track_file_access(test_file)

            -- Clear and reload
            file_tracker._file_access = {}
            file_tracker.load_data()

            assert.equals(2, file_tracker._file_access[test_file].access_count)
        end)
    end)

    describe("Group C: cleanup", function()
        it("C1: removes entries for files that no longer exist", function()
            file_tracker._file_access = {
                [tmpdir .. "/gone.txt"] = { last_accessed = 1000, access_count = 1 }
            }

            local result = file_tracker.cleanup()
            assert.equals(1, result.removed)
            assert.equals(0, result.after)
        end)

        it("C2: keeps entries for files that still exist", function()
            local existing = tmpdir .. "/exists.txt"
            local f = io.open(existing, "w")
            f:write("test") f:close()

            file_tracker._file_access = {
                [existing] = { last_accessed = 1000, access_count = 1 }
            }

            local result = file_tracker.cleanup()
            assert.equals(0, result.removed)
            assert.equals(1, result.after)
        end)

        it("C3: returns correct before/after/removed counts", function()
            local existing = tmpdir .. "/exists.txt"
            local f = io.open(existing, "w")
            f:write("test") f:close()

            file_tracker._file_access = {
                [existing] = { last_accessed = 1000, access_count = 1 },
                [tmpdir .. "/gone1.txt"] = { last_accessed = 1000, access_count = 1 },
                [tmpdir .. "/gone2.txt"] = { last_accessed = 1000, access_count = 1 },
            }

            local result = file_tracker.cleanup()
            assert.equals(3, result.before)
            assert.equals(1, result.after)
            assert.equals(2, result.removed)
        end)
    end)

    describe("Group D: init", function()
        it("D1: init calls load_data and cleanup, returns M", function()
            local result = file_tracker.init()
            assert.equals(file_tracker, result)
        end)
    end)
end)
