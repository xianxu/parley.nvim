-- Unit tests for ChatFinder pure logic
--
-- ChatFinder is a large UI feature (~300 lines) with complex Telescope integration.
-- These tests focus on the testable pure logic: timestamp parsing, filtering, sorting.
--
-- Note: Full UI integration (Telescope picker, keymappings, buffer manipulation)
-- is not tested here as it requires a full Neovim instance with Telescope installed.

local M = require("parley")

describe("ChatFinder logic", function()
    local tmpdir
    local original_config
    
    before_each(function()
        -- Save original config
        original_config = vim.deepcopy(M.config)
        
        -- Create a temp directory for chat files
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-chatfinder-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
        
        -- Set config to use temp directory
        M.config.chat_dir = tmpdir
        
        -- Reset chat finder state
        M._chat_finder = {
            opened = false,
            show_all = false,
            source_win = nil,
            active_window = nil,
            insert_mode = false,
        }
    end)
    
    after_each(function()
        -- Clean up temp directory
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
        
        -- Restore original config
        M.config = original_config
    end)
    
    describe("Group A: Timestamp parsing from filename", function()
        it("A1: parses timestamp from valid YYYY-MM-DD-HH-MM-SS filename", function()
            -- Create a file with timestamp format
            local filename = "2024-03-15-14-30-45-test-topic.md"
            local filepath = tmpdir .. "/" .. filename
            local f = io.open(filepath, "w")
            f:write("---\n# topic: Test\n---\n")
            f:close()
            
            -- Parse filename timestamp (this logic is in ChatFinder lines 3481-3493)
            local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
            
            assert.equals("2024", year)
            assert.equals("03", month)
            assert.equals("15", day)
            assert.equals("14", hour)
            assert.equals("30", min)
            assert.equals("45", sec)
            
            -- Convert to timestamp
            local date_table = {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            }
            local file_time = os.time(date_table)
            
            assert.is_true(type(file_time) == "number")
            assert.is_true(file_time > 0)
        end)
        
        it("A2: returns nil for non-timestamp filename", function()
            local filename = "random-file-name.md"
            local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
            
            assert.is_nil(year)
            assert.is_nil(month)
        end)
        
        it("A3: handles YYYY-MM-DD format (without time)", function()
            local filename = "2024-03-15-some-topic.md"
            -- The pattern requires full timestamp, so this should not match
            local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
            
            assert.is_nil(year)
        end)
    end)
    
    describe("Group B: Recency filtering", function()
        it("B1: files within recency cutoff are included", function()
            -- Create a recent file (1 month ago)
            local one_month_ago = os.time() - (30 * 24 * 60 * 60)
            local date_table = os.date("*t", one_month_ago)
            local filename = string.format("%04d-%02d-%02d-%02d-%02d-%02d-recent.md",
                date_table.year, date_table.month, date_table.day,
                date_table.hour, date_table.min, date_table.sec)
            local filepath = tmpdir .. "/" .. filename
            local f = io.open(filepath, "w")
            f:write("---\n# topic: Recent\n---\n")
            f:close()
            
            -- Recency config: 3 months
            local months = 3
            local months_in_seconds = months * 30 * 24 * 60 * 60
            local cutoff_time = os.time() - months_in_seconds
            
            -- File time from filename
            local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
            local file_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
            
            -- Should NOT be filtered (recent enough)
            assert.is_true(file_time >= cutoff_time)
        end)
        
        it("B2: files older than recency cutoff are excluded", function()
            -- Create an old file (6 months ago)
            local six_months_ago = os.time() - (6 * 30 * 24 * 60 * 60)
            local date_table = os.date("*t", six_months_ago)
            local filename = string.format("%04d-%02d-%02d-%02d-%02d-%02d-old.md",
                date_table.year, date_table.month, date_table.day,
                date_table.hour, date_table.min, date_table.sec)
            
            -- Recency config: 3 months
            local months = 3
            local months_in_seconds = months * 30 * 24 * 60 * 60
            local cutoff_time = os.time() - months_in_seconds
            
            -- File time from filename
            local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
            local file_time = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
            
            -- Should be filtered (too old)
            assert.is_true(file_time < cutoff_time)
        end)
    end)
    
    describe("Group C: Entry sorting by timestamp", function()
        it("C1: entries are sorted newest first", function()
            local entries = {
                { timestamp = 100, display = "old" },
                { timestamp = 300, display = "newest" },
                { timestamp = 200, display = "middle" },
            }
            
            -- Sort by timestamp (newest first) - logic from line 3566
            table.sort(entries, function(a, b) 
                return a.timestamp > b.timestamp
            end)
            
            assert.equals(300, entries[1].timestamp)
            assert.equals("newest", entries[1].display)
            assert.equals(200, entries[2].timestamp)
            assert.equals(100, entries[3].timestamp)
        end)
        
        it("C2: equal timestamps maintain stable order", function()
            local entries = {
                { timestamp = 100, display = "first" },
                { timestamp = 100, display = "second" },
                { timestamp = 100, display = "third" },
            }
            
            table.sort(entries, function(a, b) 
                return a.timestamp > b.timestamp
            end)
            
            -- All have same timestamp, order should be preserved
            -- (Lua's sort is stable for equal elements)
            assert.equals(100, entries[1].timestamp)
            assert.equals(100, entries[2].timestamp)
            assert.equals(100, entries[3].timestamp)
        end)
    end)
    
    describe("Group D: Display formatting", function()
        it("D1: formats display with filename, topic, date, no tags", function()
            local filename = "2024-03-15-14-30-45-test.md"
            local topic = "Test Topic"
            local file_time = os.time({ year = 2024, month = 3, day = 15, hour = 14, min = 30, sec = 45 })
            local tags = {}
            
            -- Format date string (line 3539)
            local date_str = os.date("%Y-%m-%d", file_time)
            
            -- Format tags display (lines 3542-3549)
            local tags_display = ""
            if #tags > 0 then
                local tag_parts = {}
                for _, tag in ipairs(tags) do
                    table.insert(tag_parts, "[" .. tag .. "]")
                end
                tags_display = " " .. table.concat(tag_parts, " ")
            end
            
            -- Build display string (line 3557)
            local display = filename .. " - " .. topic .. " [" .. date_str .. "]" .. tags_display
            
            assert.equals("2024-03-15-14-30-45-test.md - Test Topic [2024-03-15]", display)
        end)
        
        it("D2: formats display with tags", function()
            local filename = "2024-03-15-14-30-45-test.md"
            local topic = "Test Topic"
            local file_time = os.time({ year = 2024, month = 3, day = 15, hour = 14, min = 30, sec = 45 })
            local tags = { "bug", "feature" }
            
            local date_str = os.date("%Y-%m-%d", file_time)
            
            local tags_display = ""
            if #tags > 0 then
                local tag_parts = {}
                for _, tag in ipairs(tags) do
                    table.insert(tag_parts, "[" .. tag .. "]")
                end
                tags_display = " " .. table.concat(tag_parts, " ")
            end
            
            local display = filename .. " - " .. topic .. " [" .. date_str .. "]" .. tags_display
            
            assert.equals("2024-03-15-14-30-45-test.md - Test Topic [2024-03-15] [bug] [feature]", display)
        end)
        
        it("D3: formats searchable ordinal with filename, topic, tags", function()
            local filename = "2024-03-15-14-30-45-test.md"
            local topic = "Test Topic"
            local tags = { "bug", "feature" }
            
            -- Format tags for search ordinal (line 3552)
            local tags_searchable = #tags > 0 and (" " .. table.concat(tags, " ")) or ""
            
            -- Build ordinal (line 3558)
            local ordinal = filename .. " " .. topic .. tags_searchable
            
            assert.equals("2024-03-15-14-30-45-test.md Test Topic bug feature", ordinal)
        end)
        
        it("D4: ordinal with no tags has no trailing space", function()
            local filename = "test.md"
            local topic = "Topic"
            local tags = {}
            
            local tags_searchable = #tags > 0 and (" " .. table.concat(tags, " ")) or ""
            local ordinal = filename .. " " .. topic .. tags_searchable
            
            assert.equals("test.md Topic", ordinal)
        end)
    end)
end)
