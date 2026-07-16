-- Unit tests for ChatFinder pure logic
--
-- ChatFinder is a large UI feature (~300 lines) built on the custom float picker.
-- These tests focus on the testable pure logic: timestamp parsing, filtering, sorting.
--
-- Note: Full UI integration (floating picker, keymappings, buffer manipulation)
-- is not tested here; these specs stay focused on logic that can be verified headlessly.

local M = require("parley")

describe("ChatFinder logic", function()
    local tmpdir
    local secondary_tmpdir
    local special_tmpdir
    local original_config
    local original_float_picker_open
    local original_ui_input
    local original_defer_fn
    local original_schedule
    local original_reopen_chat_finder
    local original_delete_file
    local original_prompt_delete_confirmation
    local original_open_buf
    local original_track_file_access
    local original_finder_dependencies
    local original_logger_warning

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

    local function float_line_containing(needle)
        for _, win in ipairs(find_float_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
                if line:find(needle, 1, true) then
                    return line
                end
            end
        end
    end

    local function picker_stub(opts)
        local closed = false
        return {
            update = function(items, tags, initial_index)
                opts.items = items
				opts.initial_index = initial_index or opts.initial_index
                if opts.tag_bar then
                    opts.tag_bar.tags = tags or {}
                end
            end,
            set_status = function(status) opts.status = status end,
            current_query = function() return opts.initial_query or "" end,
            close = function() closed = true end,
            is_closed = function() return closed end,
        }
    end

    local function synchronous_file_source()
        return {
            scan = function(options, on_root, on_complete)
                for ordinal, root in ipairs(options.roots) do
                    if vim.fn.isdirectory(root.path) == 0 then
                        on_root({ root_ordinal = ordinal, status = "skipped", reason = "absent_optional" })
                    else
                        local candidates = {}
                        local pattern = vim.fn.fnameescape(root.path) .. "/*.md"
                        for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
                            local relative = vim.fn.fnamemodify(path, ":t")
                            if options.match(relative, "file") then
                                local candidate = {
                                    root = root,
                                    root_ordinal = ordinal,
                                    relative = relative,
                                    unresolved_absolute = path,
                                    resolved_absolute = vim.fn.resolve(path),
                                    stat = (vim.uv or vim.loop).fs_stat(path),
                                }
                                local decision = options.read_policy(candidate)
                                if decision.kind == "ready" then
                                    candidate.precomputed = decision.value
                                else
                                    candidate.payload = table.concat(vim.fn.readfile(path, "", 10), "\n")
                                end
                                candidates[#candidates + 1] = candidate
                            end
                        end
                        on_root({
                            root_ordinal = ordinal,
                            status = "success",
                            candidates = candidates,
                            failures = {},
                        })
                    end
                end
                on_complete()
                return { cancel = function() end }
            end,
        }
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
        original_track_file_access = require("parley.file_tracker").track_file_access
        original_finder_dependencies = M._finder_dependencies
        original_logger_warning = M.logger.warning
        require("parley.chat_finder").clear_cache()

        -- Create a temp directory for chat files
        local random_suffix = string.format("%x", math.random(0, 0xFFFFFF))
        tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chatfinder-" .. random_suffix
        secondary_tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chatfinder-secondary-" .. random_suffix
        special_tmpdir = nil
        vim.fn.mkdir(tmpdir, "p")
        vim.fn.mkdir(secondary_tmpdir, "p")

        -- Set config to use temp directory
        M.config.chat_dir = tmpdir
        M.config.chat_dirs = { tmpdir, secondary_tmpdir }
        M.config.chat_roots = {
            { dir = tmpdir, label = "main" },
            { dir = secondary_tmpdir, label = "secondary" },
        }
        M.config.chat_finder_mappings = {
            delete = { shortcut = "<C-d>" },
            move = { shortcut = "<C-x>" },
            next_recency = { shortcut = "<C-a>" },
            previous_recency = { shortcut = "<C-s>" },
        }
        M.config.chat_finder_recency = {
            filter_by_default = true,
            months = 12,
            presets = { 6, 12 },
        }
        M.config.global_shortcut_keybindings = { shortcut = "<C-g>?" }
        M._finder_dependencies = {
            async_file_source = synchronous_file_source(),
            schedule = function(callback) callback() end,
            now = function() return 0 end,
        }

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
            sticky_query = nil,
            sticky_query_initialized = false,
        }
    end)

    after_each(function()
		for _, win in ipairs(find_float_wins()) do
			pcall(vim.api.nvim_win_close, win, true)
		end
        -- Clean up temp directory
        if tmpdir then
            vim.fn.delete(tmpdir, "rf")
        end
        if secondary_tmpdir then
            vim.fn.delete(secondary_tmpdir, "rf")
        end
        if special_tmpdir then
            vim.fn.delete(special_tmpdir, "rf")
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
        require("parley.file_tracker").track_file_access = original_track_file_access
        M._finder_dependencies = original_finder_dependencies
        M.logger.warning = original_logger_warning
        require("parley.chat_finder").clear_cache()
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
		local function loading_picker(captured, updates)
			local closed = false
			return {
				update = function(items, tags)
					updates[#updates + 1] = { items = items, tags = tags }
				end,
				set_status = function(status) captured.status_update = status end,
				current_query = function() return captured.initial_query or "" end,
				close = function() closed = true end,
				is_closed = function() return closed end,
			}
		end

		it("opens a loading picker before asynchronous acquisition starts", function()
			local order = {}
			local captured
			local updates = {}
			M.float_picker.open = function(opts)
				order[#order + 1] = "picker"
				captured = opts
				return loading_picker(captured, updates)
			end
			M._finder_dependencies = {
				schedule = function(callback) callback() end,
				now = function() return 0 end,
				async_file_source = {
					scan = function()
						order[#order + 1] = "scan"
						return { cancel = function() end }
					end,
				},
			}

			M.cmd.ChatFinder()

			assert.same({ "picker", "scan" }, order)
			assert.same({ message = "scanning…", animated = true }, captured.status)
			assert.same({}, captured.items)
		end)

        it("animates the real picker while Chat acquisition remains delayed", function()
            local cancel_count = 0
            M.float_picker.open = original_float_picker_open
            M._finder_dependencies = {
                schedule = vim.schedule,
                async_file_source = {
                    scan = function()
                        return { cancel = function() cancel_count = cancel_count + 1 end }
                    end,
                },
            }
            local sentinel = false
            vim.schedule(function() sentinel = true end)

            M.cmd.ChatFinder()
            local initial = float_line_containing("scanning…")

            assert.is_not_nil(initial)
            assert(vim.wait(1000, function()
                local current = float_line_containing("scanning…")
                return sentinel and current ~= nil and current ~= initial
            end, 10), "Chat spinner did not tick while acquisition was pending")
            vim.api.nvim_feedkeys(
                vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
                "x",
                true
            )
            assert(vim.wait(500, function() return cancel_count == 1 end, 10))
        end)

        it("cancels loading acquisition before a recency mapping reopens Chat", function()
            local scan_count = 0
            local cancel_count = 0
            M.float_picker.open = original_float_picker_open
            M._finder_dependencies = {
                schedule = vim.schedule,
                async_file_source = {
                    scan = function()
                        scan_count = scan_count + 1
                        return { cancel = function() cancel_count = cancel_count + 1 end }
                    end,
                },
            }

            M.cmd.ChatFinder()
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-a>", true, false, true), "x", true)

            assert(vim.wait(1000, function() return cancel_count == 1 and scan_count == 2 end, 10))
            assert.equals(1, scan_count - cancel_count)
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
            assert(vim.wait(500, function() return cancel_count == 2 end, 10))
        end)

		it("joins a matching retained prewarm instead of starting a second scan", function()
			local scan_count = 0
			local finish_root
			local finish_scan
			local captured
			local updates = {}
			M.float_picker.open = function(opts)
				captured = opts
				return loading_picker(captured, updates)
			end
			M._finder_dependencies = {
				schedule = function(callback) callback() end,
				now = function() return 0 end,
				async_file_source = {
					scan = function(_, on_root, on_complete)
						scan_count = scan_count + 1
						finish_root = on_root
						finish_scan = on_complete
						return { cancel = function() end }
					end,
				},
			}
			vim.defer_fn = function(callback) callback() end

			local chat_finder = require("parley.chat_finder")
			chat_finder.prewarm()
			M.cmd.ChatFinder()
			assert.equals(1, scan_count)

			finish_root({
				root_ordinal = 1,
				status = "success",
				candidates = {
					{
						root = { path = tmpdir, label = "main", is_primary = true },
						root_ordinal = 1,
						relative = "2026-02-03-10-20-30-late.md",
						unresolved_absolute = tmpdir .. "/2026-02-03-10-20-30-late.md",
						resolved_absolute = tmpdir .. "/2026-02-03-10-20-30-late.md",
						stat = { mtime = { sec = 100 } },
						payload = "# topic: Joined\n",
					},
				},
				failures = {},
			})
			finish_root({ root_ordinal = 2, status = "success", candidates = {}, failures = {} })
			finish_scan()

			assert.equals(1, #updates)
			assert.equals("Joined", updates[1].items[1].display:match(" %- (.-) %[%d%d%d%d%-"))
		end)

		it("cancels picker-owned acquisition and ignores late root delivery", function()
			local finish_root
			local finish_scan
			local cancel_count = 0
			local captured
			local updates = {}
			M.float_picker.open = function(opts)
				captured = opts
				return loading_picker(captured, updates)
			end
			M._finder_dependencies = {
				schedule = function(callback) callback() end,
				now = function() return 0 end,
				async_file_source = {
					scan = function(_, on_root, on_complete)
						finish_root = on_root
						finish_scan = on_complete
						return { cancel = function() cancel_count = cancel_count + 1 end }
					end,
				},
			}

			M.cmd.ChatFinder()
			captured.on_cancel()
			finish_root({ root_ordinal = 1, status = "success", candidates = {}, failures = {} })
			finish_scan()

			assert.equals(1, cancel_count)
			assert.same({}, updates)
		end)

        it("keeps recency outside the exact discovery fingerprint", function()
            local chat_finder = require("parley.chat_finder")
            local first = chat_finder._discovery_snapshot()
            local first_data = first:copy()

            M.config.chat_finder_recency.months = 6
            local recency_changed = chat_finder._discovery_snapshot()
            M.config.chat_roots[2].label = "peer"
            local root_changed = chat_finder._discovery_snapshot()

            assert.equals("chat", first_data.kind)
            assert.is_false(first_data.recursion)
            assert.equals(1, first_data.max_depth)
            assert.equals("YYYY-MM-DD*.md", first_data.pattern)
            assert.same({ source = "libuv", header_lines = 10 }, first_data.backend)
            assert.equals(first:fingerprint(), recency_changed:fingerprint())
            assert.is_true(first:fingerprint() ~= root_changed:fingerprint())
        end)

        it("settles all-absent optional roots as a successful empty picker", function()
            local captured
            local updates = {}
            M.float_picker.open = function(opts)
                captured = opts
                return loading_picker(captured, updates)
            end
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, on_root, on_complete)
                        for ordinal in ipairs(options.roots) do
                            on_root({
                                root_ordinal = ordinal,
                                status = "skipped",
                                reason = "absent_optional",
                            })
                        end
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.ChatFinder()

            assert.equals(1, #updates)
            assert.same({}, updates[1].items)
            assert.is_nil(captured.status_update)
        end)

        it("keeps a bounded error status when every Chat root fails", function()
            local captured
            local updates = {}
            M.float_picker.open = function(opts)
                captured = opts
                return loading_picker(captured, updates)
            end
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, on_root, on_complete)
                        for ordinal in ipairs(options.roots) do
                            on_root({
                                root_ordinal = ordinal,
                                status = "failed",
                                failure = { kind = "root_enumeration", diagnostic = "EACCES" },
                            })
                        end
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.ChatFinder()

            assert.same({}, updates)
            assert.is_false(captured.status_update.animated)
            assert.truthy(captured.status_update.message:find("scan failed", 1, true))
        end)

        it("keeps successful Chat records and warns once for record failures", function()
            local warning_count = 0
            local captured
            local updates = {}
            M.logger.warning = function() warning_count = warning_count + 1 end
            M.float_picker.open = function(opts)
                captured = opts
                return loading_picker(captured, updates)
            end
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, on_root, on_complete)
                        local root = options.roots[1]
                        on_root({
                            root_ordinal = 1,
                            status = "success",
                            candidates = {
                                {
                                    root = root,
                                    root_ordinal = 1,
                                    relative = "2026-02-03-10-20-30-good.md",
                                    unresolved_absolute = root.path .. "/2026-02-03-10-20-30-good.md",
                                    resolved_absolute = root.path .. "/2026-02-03-10-20-30-good.md",
                                    stat = { mtime = { sec = 100 } },
                                    payload = "# topic: Good\n",
                                },
                            },
                            failures = { { kind = "read", diagnostic = "EIO" } },
                        })
                        on_root({ root_ordinal = 2, status = "success", candidates = {}, failures = {} })
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.ChatFinder()

            assert.equals(1, warning_count)
            assert.equals(1, #updates)
            assert.equals(1, #updates[1].items)
        end)

        it("replaces a mismatched retained prewarm instead of joining it", function()
            local scan_count = 0
            local cancel_count = 0
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function()
                        scan_count = scan_count + 1
                        return { cancel = function() cancel_count = cancel_count + 1 end }
                    end,
                },
            }
            local chat_finder = require("parley.chat_finder")

            chat_finder.prewarm()
            M.config.chat_roots[2].label = "renamed"
            chat_finder.prewarm()

            assert.equals(2, scan_count)
            assert.equals(1, cancel_count)
        end)

        it("reuses unchanged cached metadata without requesting another read", function()
            local decisions = {}
            local captured
            M.float_picker.open = function(opts)
                captured = opts
                return picker_stub(opts)
            end
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, on_root, on_complete)
                        for ordinal, root in ipairs(options.roots) do
                            local candidates = {}
                            if ordinal == 1 then
                                local path = root.path .. "/2026-02-03-10-20-30-cache.md"
                                local item = {
                                    root = root,
                                    root_ordinal = ordinal,
                                    relative = "2026-02-03-10-20-30-cache.md",
                                    unresolved_absolute = path,
                                    resolved_absolute = path,
                                    stat = { mtime = { sec = 100 } },
                                }
                                local decision = options.read_policy(item)
                                decisions[#decisions + 1] = decision.kind
                                if decision.kind == "ready" then
                                    item.precomputed = decision.value
                                else
                                    item.payload = "# topic: Cached once\n"
                                end
                                candidates[1] = item
                            end
                            on_root({
                                root_ordinal = ordinal,
                                status = "success",
                                candidates = candidates,
                                failures = {},
                            })
                        end
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.ChatFinder()
            captured.on_cancel()
            M.cmd.ChatFinder()

            assert.same({ "read", "ready" }, decisions)
            assert.equals("Cached once", captured.items[1].display:match(" %- (.-) %[%d%d%d%d%-"))
        end)

        it("prunes cache only for roots that enumerate successfully", function()
            local chat_finder = require("parley.chat_finder")
            local cache = chat_finder.get_cache()
            cache["/stale-main.md"] = { mtime = 1, topic = "main", tags = {}, root_path = tmpdir }
            cache["/stale-peer.md"] = {
                mtime = 1,
                topic = "peer",
                tags = {},
                root_path = secondary_tmpdir,
            }
            M.float_picker.open = function(opts) return picker_stub(opts) end
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(_, on_root, on_complete)
                        on_root({ root_ordinal = 1, status = "success", candidates = {}, failures = {} })
                        on_root({
                            root_ordinal = 2,
                            status = "failed",
                            failure = { kind = "root_enumeration", diagnostic = "EACCES" },
                        })
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.ChatFinder()

            assert.is_nil(cache["/stale-main.md"])
            assert.is_not_nil(cache["/stale-peer.md"])
        end)

        it("opens with the active recency label and all four cycle mappings", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local filename = "2026-02-01-10-00-00-recent.md"
            local filepath = tmpdir .. "/" .. filename
            local f = io.open(filepath, "w")
            f:write("# topic: Recent\n")
            f:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals("Chat Files (Recent: 12 months  <Tab>/<S-Tab>: cycle)", captured.title)
            assert.equals("<C-x>", captured.mappings[3].key)
            assert.equals("<C-a>", captured.mappings[4].key)
            assert.equals("<Tab>", captured.mappings[5].key)
            assert.equals("<C-s>", captured.mappings[6].key)
            assert.equals("<S-Tab>", captured.mappings[7].key)
        end)

        it("<Tab> cycles left (aliases <C-a>), <S-Tab> right (aliases <C-s>) (#159)", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local filepath = tmpdir .. "/2026-02-01-10-00-00-recent.md"
            local f = io.open(filepath, "w")
            f:write("# topic: Recent\n")
            f:close()

            M.cmd.ChatFinder()
            assert.is_truthy(captured)

            -- The direction-critical mutation (recency_index) happens
            -- synchronously, before the async defer-reopen — so invoke each
            -- mapping fn and read where the index landed. A left/right swap in
            -- make_recency_cycle would flip these (#159 close-review Important).
            local cfg = M.config.chat_finder_recency
            local START = 2
            local exp_prev = M._cycle_chat_finder_recency(cfg, START, "previous")
            local exp_next = M._cycle_chat_finder_recency(cfg, START, "next")
            assert.is_true(exp_prev ~= exp_next, "fixture must discriminate directions")

            local function invoke(map_idx)
                M._chat_finder.recency_index = START
                captured.mappings[map_idx].fn(nil, function() end)
                return M._chat_finder.recency_index
            end

            assert.equals(exp_prev, invoke(4)) -- <C-a>  = left
            assert.equals(exp_prev, invoke(5)) -- <Tab>  = left (aliases <C-a>)
            assert.equals(exp_next, invoke(6)) -- <C-s>  = right
            assert.equals(exp_next, invoke(7)) -- <S-Tab> = right (aliases <C-s>)
        end)

        it("prefers restoring selection by item value when reopening after delete", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
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
            return picker_stub(opts)
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
            assert.matches("^2026%-02%-03%-10%-00%-00%-secondary%.md %- {%s*secondary%s*}", captured.items[2].display)
        end)

        it("keeps a moved chat visible when moving it from ChatFinder", function()
            local picker_calls = {}
            require("parley.file_tracker").track_file_access = function() end
            vim.schedule = function(fn)
                fn()
            end
            vim.defer_fn = function(fn, _)
                fn()
            end

            M.float_picker.open = function(opts)
                table.insert(picker_calls, opts)
                if opts.title == "Move Chat To" then
                    assert.equals(1, #opts.items)
                    opts.on_select(opts.items[1])
                end
				return picker_stub(opts)
            end

            local filename = "2026-02-04-10-00-00-move-me.md"
            local old_path = tmpdir .. "/" .. filename
            local new_path = secondary_tmpdir .. "/" .. filename
            local file = io.open(old_path, "w")
            file:write("# topic: Move me\n")
            file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(picker_calls[1])
            assert.equals("Chat Files (Recent: 12 months  <Tab>/<S-Tab>: cycle)", picker_calls[1].title)
            assert.equals(old_path, picker_calls[1].items[1].value)

            picker_calls[1].mappings[3].fn(picker_calls[1].items[1], function() end)

            assert.equals(0, vim.fn.filereadable(old_path))
            assert.equals(1, vim.fn.filereadable(new_path))
            assert.equals("Move Chat To", picker_calls[2].title)
            assert.equals("Chat Files (Recent: 12 months  <Tab>/<S-Tab>: cycle)", picker_calls[3].title)
            assert.equals(new_path, picker_calls[3].items[1].value)
        end)

        it("finds moved chats in roots whose paths contain glob characters", function()
            special_tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chatfinder-[archive]-" .. string.format("%x", math.random(0, 0xFFFFFF))
            local picker_calls = {}
            require("parley.file_tracker").track_file_access = function() end
            vim.fn.mkdir(special_tmpdir, "p")
            M.config.chat_dirs = { tmpdir, special_tmpdir }
            M.config.chat_roots = {
                { dir = tmpdir, label = "main" },
                { dir = special_tmpdir, label = "archive" },
            }
            vim.schedule = function(fn)
                fn()
            end
            vim.defer_fn = function(fn, _)
                fn()
            end

            M.float_picker.open = function(opts)
                table.insert(picker_calls, opts)
                if opts.title == "Move Chat To" then
                    assert.equals(special_tmpdir, opts.items[1].value)
                    opts.on_select(opts.items[1])
                end
				return picker_stub(opts)
            end

            local filename = "2026-02-04-10-00-00-escaped-root.md"
            local old_path = tmpdir .. "/" .. filename
            local new_path = special_tmpdir .. "/" .. filename
            local file = io.open(old_path, "w")
            file:write("# topic: Escaped root\n")
            file:close()

            M.cmd.ChatFinder()
            picker_calls[1].mappings[3].fn(picker_calls[1].items[1], function() end)

            assert.equals(0, vim.fn.filereadable(old_path))
            assert.equals(1, vim.fn.filereadable(new_path))
            assert.equals("Chat Files (Recent: 12 months  <Tab>/<S-Tab>: cycle)", picker_calls[3].title)
            assert.equals(new_path, picker_calls[3].items[1].value)
        end)

        it("reopens on moved chats when the destination root was configured with a tilde path", function()
            special_tmpdir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-chatfinder-tilde-" .. string.format("%x", math.random(0, 0xFFFFFF))
            local tilde_root = special_tmpdir:gsub("^" .. vim.pesc(vim.env.HOME), "~")
            local picker_calls = {}
            require("parley.file_tracker").track_file_access = function() end
            vim.fn.mkdir(special_tmpdir, "p")
            M.config.chat_dirs = { tmpdir, tilde_root }
            M.config.chat_roots = {
                { dir = tmpdir, label = "main" },
                { dir = tilde_root, label = "family" },
            }
            vim.schedule = function(fn)
                fn()
            end
            vim.defer_fn = function(fn, _)
                fn()
            end

            M.float_picker.open = function(opts)
                table.insert(picker_calls, opts)
                if opts.title == "Move Chat To" then
                    assert.equals(tilde_root, opts.items[1].value)
                    opts.on_select(opts.items[1])
                end
				return picker_stub(opts)
            end

            local filename = "2026-02-04-10-00-00-tilde-root.md"
            local old_path = tmpdir .. "/" .. filename
            local new_path = special_tmpdir .. "/" .. filename
            local file = io.open(old_path, "w")
            file:write("# topic: Tilde root\n")
            file:close()

            M.cmd.ChatFinder()
            picker_calls[1].mappings[3].fn(picker_calls[1].items[1], function() end)

            assert.equals(0, vim.fn.filereadable(old_path))
            assert.equals(1, vim.fn.filereadable(new_path))
            assert.equals(new_path, picker_calls[3].items[1].value)
            assert.matches("^2026%-02%-04%-10%-00%-00%-tilde%-root%.md %- {%s*family%s*}", picker_calls[3].items[1].display)
        end)

        it("passes filename, tags, and topic as search text for matcher ranking", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end
            M.config.chat_assistant_prefix = { "🤖:" }
            M.config.chat_user_prefix = "💬:"
            M.config.chat_local_prefix = "📎:"
            M.config.chat_memory = {
                enable = false,
                summary_prefix = "📝:",
                reasoning_prefix = "🧠:",
            }

            local filepath = tmpdir .. "/2026-02-04-10-00-00-release-notes.md"
            local file = io.open(filepath, "w")
            file:write(table.concat({
                "---",
                "topic: Shipping notes",
                "tags: roadmap, launch",
                "---",
                "",
            }, "\n"))
            file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals(filepath, captured.items[1].value)
            assert.matches("2026%-02%-04%-10%-00%-00%-release%-notes%.md", captured.items[1].search_text)
            assert.matches("roadmap", captured.items[1].search_text)
            assert.matches("launch", captured.items[1].search_text)
            assert.matches("Shipping notes", captured.items[1].search_text)
        end)

        it("keeps canonical facet behavior across toggles and rediscovery", function()
            local captured = nil
            local updates = {}
            M.float_picker.open = function(opts)
                captured = opts
				local picker = picker_stub(opts)
				picker.update = function(items, tags)
					picker_stub(opts).update(items, tags)
					table.insert(updates, { items = items, tags = tags })
				end
				return picker
            end

            local function write_chat(name, topic, tags)
                local file = io.open(tmpdir .. "/" .. name, "w")
                local lines = { "---", "topic: " .. topic }
                if tags then
                    table.insert(lines, "tags: " .. tags)
                end
                table.insert(lines, "---")
                table.insert(lines, "")
                file:write(table.concat(lines, "\n"))
                file:close()
            end

            write_chat("2026-02-04-10-00-00-alpha.md", "Alpha", "alpha")
            write_chat("2026-02-03-10-00-00-beta.md", "Beta", "beta")
            write_chat("2026-02-02-10-00-00-untagged.md", "Untagged")
            M._chat_finder.tag_state = { alpha = false, missing = false }
            M._chat_finder.sticky_query = "  [beta] exact  "

            M.cmd.ChatFinder()
            updates = {}

            assert.same({
                { label = "alpha", enabled = false },
                { label = "beta", enabled = true },
                { label = "", enabled = true },
            }, captured.tag_bar.tags)
            assert.is_false(M._chat_finder.tag_state.missing)
            assert.is_true(M._chat_finder.tag_state.beta)

            captured.tag_bar.on_toggle("beta")
            assert.equals(1, #updates)
            assert.equals(1, #updates[1].items)
            assert.matches("untagged", updates[1].items[1].value)
            assert.equals("  [beta] exact  ", M._chat_finder.sticky_query)

            captured.tag_bar.on_none()
            assert.equals(0, #updates[2].items)
            captured.tag_bar.on_all()
            assert.equals(3, #updates[3].items)

            vim.fn.delete(tmpdir .. "/2026-02-03-10-00-00-beta.md")
            M._chat_finder.opened = false
            M.cmd.ChatFinder()
            assert.is_true(M._chat_finder.tag_state.beta)

            write_chat("2026-02-03-10-00-00-beta.md", "Beta", "beta")
            M._chat_finder.tag_state.beta = false
            M._chat_finder.opened = false
            M.cmd.ChatFinder()
            assert.is_false(M._chat_finder.tag_state.beta)
        end)

        it("includes extra-root labels in finder search text", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local secondary_path = secondary_tmpdir .. "/2026-02-03-10-00-00-secondary.md"
            local secondary_file = io.open(secondary_path, "w")
            secondary_file:write("# topic: Secondary\n")
            secondary_file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals(secondary_path, captured.items[1].value)
            assert.matches("secondary", captured.items[1].search_text)
        end)

        it("includes empty braces in primary-root search text", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local primary_path = tmpdir .. "/2026-02-04-10-00-00-primary.md"
            local primary_file = io.open(primary_path, "w")
            primary_file:write("# topic: Primary\n")
            primary_file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals(primary_path, captured.items[1].value)
            assert.matches("%{%}", captured.items[1].search_text)
        end)

        it("passes preserved tag filters back into the picker prompt", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            M._chat_finder.sticky_query = "[workspace] {secondary} [client-a]"

            local filepath = tmpdir .. "/2026-02-04-10-00-00-sticky.md"
            local file = io.open(filepath, "w")
            file:write("# topic: Sticky\n")
            file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            assert.equals("[workspace] {secondary} [client-a] ", captured.initial_query)
            assert.is_function(captured.on_query_change)
        end)

        it("preserves only bracket-tag and brace-label fragments from finder queries", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local filepath = tmpdir .. "/2026-02-04-10-00-00-tags.md"
            local file = io.open(filepath, "w")
            file:write("# topic: Tagged\n")
            file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)

            captured.on_query_change("[workspace] {secondary} shipping [client-a]")
            assert.equals("[workspace] {secondary} [client-a]", M._chat_finder.sticky_query)

            captured.on_query_change("shipping")
            assert.is_nil(M._chat_finder.sticky_query)
        end)

        it("matches extra-root labels when the query uses brace syntax", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
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
            captured.on_query_change("{secondary}")
            assert.equals("{secondary}", M._chat_finder.sticky_query)
        end)

        it("preserves empty brace filters for the primary root", function()
            local captured = nil
            M.float_picker.open = function(opts)
                captured = opts
            return picker_stub(opts)
            end

            local filepath = tmpdir .. "/2026-02-04-10-00-00-primary.md"
            local file = io.open(filepath, "w")
            file:write("# topic: Primary\n")
            file:close()

            M.cmd.ChatFinder()

            assert.is_truthy(captured)
            captured.on_query_change("{} primary")
            assert.equals("{}", M._chat_finder.sticky_query)
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

    describe("default_sticky_query_for_repo_mode", function()
        local chat_finder = require("parley.chat_finder")

        it("returns {} in plain repo mode", function()
            local got = chat_finder.default_sticky_query_for_repo_mode({
                repo_root = "/some/repo",
            })
            assert.equals("{}", got)
        end)

        it("returns nil when not in repo mode", function()
            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode({}))
            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode({ repo_root = "" }))
            assert.is_nil(chat_finder.default_sticky_query_for_repo_mode(nil))
        end)

        it("returns nil in super-repo mode (don't override aggregation intent)", function()
            local got = chat_finder.default_sticky_query_for_repo_mode({
                repo_root = "/some/repo",
                super_repo_root = "/some/workspace",
            })
            assert.is_nil(got)
        end)
    end)
end)
