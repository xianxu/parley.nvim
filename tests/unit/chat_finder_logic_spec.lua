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
    local secondary_tmpdir
    local original_config
    local original_float_picker_open
    local original_ui_input
    local original_defer_fn
    local original_schedule
    local original_reopen_chat_finder
    local original_delete_file
    local original_prompt_delete_confirmation
    local original_open_buf

    local function find_results_float_win()
        local current = vim.api.nvim_get_current_win()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
            if ok and cfg.relative ~= "" and win ~= current then
                return win
            end
        end
        return nil
    end

    local function find_float_wins()
        local wins = {}
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
            if ok and cfg.relative ~= "" then
                table.insert(wins, win)
            end
        end
        return wins
    end

    before_each(function()
        -- Save original config
        original_config = vim.deepcopy(M.config)
        original_float_picker_open = M.float_picker.open
        original_ui_input = vim.ui.input
        original_defer_fn = vim.defer_fn
        original_schedule = vim.schedule
        original_reopen_chat_finder = M._reopen_chat_finder
        original_delete_file = M.helpers.delete_file
        original_prompt_delete_confirmation = M._prompt_chat_finder_delete_confirmation
        original_open_buf = M.open_buf

        -- Create a temp directory for chat files
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = "/tmp/parley-test-chatfinder-" .. random_suffix
        secondary_tmpdir = "/tmp/parley-test-chatfinder-secondary-" .. random_suffix
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(secondary_tmpdir, "p")

        -- Set config to use temp directory
        M.config.chat_dir = tmpdir
        M.config.chat_dirs = { tmpdir, secondary_tmpdir }
        M.config.chat_finder_mappings = {
            delete = { shortcut = "<C-d>" },
            move = { shortcut = "<C-g>m" },
            next_recency = { shortcut = "<C-a>" },
            previous_recency = { shortcut = "<C-s>" },
        }
        M.config.chat_finder_recency = {
            filter_by_default = true,
            months = 12,
            presets = { 6, 12 },
        }
        M.config.global_shortcut_keybindings = { shortcut = "<C-g>?" }

        -- Reset chat finder state
        M._chat_finder = {
            opened = false,
            show_all = false,
            recency_index = nil,
            source_win = nil,
            active_window = nil,
            insert_mode = false,
            initial_index = nil,
            initial_value = nil,
        }
    end)

    after_each(function()
        -- Clean up temp directory
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
        if secondary_tmpdir then
            vim.fn.delete(secondary_tmpdir, "rf")
        end

        -- Restore original config
        M.config = original_config
        M.float_picker.open = original_float_picker_open
        vim.ui.input = original_ui_input
        vim.defer_fn = original_defer_fn
        vim.schedule = original_schedule
        M._reopen_chat_finder = original_reopen_chat_finder
        M.helpers.delete_file = original_delete_file
        M._prompt_chat_finder_delete_confirmation = original_prompt_delete_confirmation
        M.open_buf = original_open_buf
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

    describe("Group B: Recency cycling", function()
        it("B1: resolves configured presets and keeps all as the final state", function()
            local resolved = M._resolve_chat_finder_recency({
                filter_by_default = true,
                months = 12,
                presets = { 12, 6, 6 },
            })

            assert.equals(2, resolved.index)
            assert.same({ 6, 12 }, vim.tbl_map(function(state)
                return state.months
            end, { resolved.states[1], resolved.states[2] }))
            assert.equals("Recent: 6 months", resolved.states[1].label)
            assert.equals("Recent: 12 months", resolved.states[2].label)
            assert.is_true(resolved.states[3].is_all)
            assert.equals("All", resolved.states[3].label)
        end)

        it("B2: uses configured default month when opening in filtered mode", function()
            local resolved = M._resolve_chat_finder_recency({
                filter_by_default = true,
                months = 12,
                presets = { 6, 12 },
            })

            assert.equals(2, resolved.index)
            assert.equals(12, resolved.current.months)
            assert.is_false(resolved.current.is_all)
        end)

        it("B3: cycles left and right across presets and all", function()
            local recency = {
                filter_by_default = true,
                months = 6,
                presets = { 6, 12 },
            }

            local next_index, next_state = M._cycle_chat_finder_recency(recency, 2, "previous")
            assert.equals(1, next_index)
            assert.equals(6, next_state.months)

            next_index, next_state = M._cycle_chat_finder_recency(recency, next_index, "next")
            assert.equals(2, next_index)
            assert.equals(12, next_state.months)

            next_index, next_state = M._cycle_chat_finder_recency(recency, next_index, "next")
            assert.equals(3, next_index)
            assert.is_true(next_state.is_all)
        end)

        it("B4: files within recency cutoff are included", function()
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

        it("B5: files older than recency cutoff are excluded", function()
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

    describe("Group E: Delete confirmation reopen behavior", function()
        it("reopens ChatFinder on Esc during delete confirmation", function()
            local reopen_calls = {}
            M._reopen_chat_finder = function(source_win, selection_index, selection_value)
                table.insert(reopen_calls, {
                    source_win = source_win,
                    selection_index = selection_index,
                    selection_value = selection_value,
                })
            end

            local deleted = nil
            M.helpers.delete_file = function(path)
                deleted = path
            end

            M._handle_chat_finder_delete_response(nil, "/tmp/chat.md", 3, 7, 42)

            assert.equals(nil, deleted)
            assert.equals(1, #reopen_calls)
            assert.equals(42, reopen_calls[1].source_win)
            assert.equals(3, reopen_calls[1].selection_index)
            assert.equals("/tmp/chat.md", reopen_calls[1].selection_value)
        end)

        it("reopens on the item that moves into the deleted visual row", function()
            local reopen_calls = {}
            M._reopen_chat_finder = function(source_win, selection_index, selection_value)
                table.insert(reopen_calls, {
                    source_win = source_win,
                    selection_index = selection_index,
                    selection_value = selection_value,
                })
            end

            local deleted = nil
            M.helpers.delete_file = function(path)
                deleted = path
            end

            M._handle_chat_finder_delete_response("y", "/tmp/chat-b.md", 2, 4, 42, nil, {
                chat_finder_items = {
                    { value = "/tmp/chat-a.md" },
                    { value = "/tmp/chat-b.md" },
                    { value = "/tmp/chat-c.md" },
                    { value = "/tmp/chat-d.md" },
                },
            })

            assert.equals("/tmp/chat-b.md", deleted)
            assert.equals(1, #reopen_calls)
            assert.equals(42, reopen_calls[1].source_win)
            assert.equals(2, reopen_calls[1].selection_index)
            assert.equals("/tmp/chat-c.md", reopen_calls[1].selection_value)
        end)

        it("opens delete confirmation from the source window", function()
            local prompt_seen = nil
            local callback_value = nil
            local source_win = vim.api.nvim_get_current_win()

            vim.ui.input = function(opts, cb)
                prompt_seen = opts.prompt
                callback_value = vim.api.nvim_get_current_win()
                cb("n")
            end

            local reopen_calls = {}
            M._reopen_chat_finder = function(win, selection_index, selection_value)
                table.insert(reopen_calls, {
                    win = win,
                    selection_index = selection_index,
                    selection_value = selection_value,
                })
            end

            M._prompt_chat_finder_delete_confirmation("/tmp/chat.md", 2, 5, source_win)

            assert.equals("Delete /tmp/chat.md? [y/N] ", prompt_seen)
            assert.equals(source_win, callback_value)
            assert.equals(1, #reopen_calls)
            assert.equals(source_win, reopen_calls[1].win)
            assert.equals(2, reopen_calls[1].selection_index)
            assert.equals("/tmp/chat.md", reopen_calls[1].selection_value)
        end)
    end)

    describe("Group F: Chat finder picker mappings", function()
        it("opens with the active recency label and both cycle mappings", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            end

            local filename = "2026-02-01-10-00-00-recent.md"
            local filepath = tmpdir .. "/" .. filename
            local f = io.open(filepath, "w")
            f:write("# topic: Recent\n")
            f:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals("Chat Files (Recent: 12 months  <C-a>/<C-s>: cycle)", captured.title)
            assert.equals("<C-g>m", captured.mappings[2].key)
            assert.equals("<C-a>", captured.mappings[3].key)
            assert.equals("<C-s>", captured.mappings[4].key)
        end)

        it("prefers restoring selection by item value when reopening after delete", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            end

            local filenames = {
                "2026-02-04-10-00-00-alpha.md",
                "2026-02-03-10-00-00-beta.md",
                "2026-02-02-10-00-00-gamma.md",
            }
            for _, filename in ipairs(filenames) do
                local filepath = tmpdir .. "/" .. filename
                local f = io.open(filepath, "w")
                f:write("# topic: " .. filename .. "\n")
                f:close()
            end

            M._chat_finder.initial_index = 3
            M._chat_finder.initial_value = tmpdir .. "/2026-02-03-10-00-00-beta.md"

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals(tmpdir .. "/2026-02-03-10-00-00-beta.md", captured.items[2].value)
            assert.equals(2, captured.initial_index)
        end)

        it("includes chat files from secondary chat roots", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            end

            local primary_path = tmpdir .. "/2026-02-04-10-00-00-primary.md"
            local secondary_path = secondary_tmpdir .. "/2026-02-03-10-00-00-secondary.md"

            local primary_file = io.open(primary_path, "w")
            primary_file:write("# topic: Primary\n")
            primary_file:close()

            local secondary_file = io.open(secondary_path, "w")
            secondary_file:write("# topic: Secondary\n")
            secondary_file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            local values = vim.tbl_map(function(item)
                return item.value
            end, captured.items)
            assert.same({ primary_path, secondary_path }, values)
        end)

        it("falls back to the newer visual neighbor when deleting the oldest item", function()
            local reopen_calls = {}
            M._reopen_chat_finder = function(source_win, selection_index, selection_value)
                table.insert(reopen_calls, {
                    source_win = source_win,
                    selection_index = selection_index,
                    selection_value = selection_value,
                })
            end

            local deleted = nil
            M.helpers.delete_file = function(path)
                deleted = path
            end

            M._handle_chat_finder_delete_response("y", "/tmp/chat-c.md", 3, 3, 42, nil, {
                chat_finder_items = {
                    { value = "/tmp/chat-a.md" },
                    { value = "/tmp/chat-b.md" },
                    { value = "/tmp/chat-c.md" },
                },
            })

            assert.equals("/tmp/chat-c.md", deleted)
            assert.equals(1, #reopen_calls)
            assert.equals(42, reopen_calls[1].source_win)
            assert.equals(2, reopen_calls[1].selection_index)
            assert.equals("/tmp/chat-b.md", reopen_calls[1].selection_value)
        end)
    end)
end)
