local M = require("parley")

describe("NoteFinder logic", function()
    local notes_dir
    local original_config
    local original_float_picker_open
    local original_ui_input
    local original_defer_fn
    local original_schedule
    local original_reopen_note_finder
    local original_delete_file
    local original_open_buf
    local original_create_note_file
    local original_notify
    local original_finder_dependencies
    local original_logger_warning

    local function find_float_wins()
        local wins = {}
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
            if ok and cfg.relative ~= "" then
                wins[#wins + 1] = win
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
            update = function(items, _, initial_index)
                opts.items = items
                opts.initial_index = initial_index or opts.initial_index
            end,
            set_status = function(status) opts.status_update = status end,
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
                        local pattern = vim.fn.fnameescape(root.path) .. "/**/*.md"
                        for _, path in ipairs(vim.fn.glob(pattern, false, true)) do
                            local relative = path:sub(#root.path + 2)
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

    local function write_file(path, lines)
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        local file = io.open(path, "w")
        assert.is_truthy(file)
        file:write(table.concat(lines or { "# test" }, "\n"))
        file:close()
    end

    local function write_template(name)
        write_file(notes_dir .. "/templates/" .. name, { "# template" })
    end

    before_each(function()
        original_config = vim.deepcopy(M.config)
        original_float_picker_open = M.float_picker.open
        original_ui_input = vim.ui.input
        original_defer_fn = vim.defer_fn
        original_schedule = vim.schedule
        original_reopen_note_finder = M._reopen_note_finder
        original_delete_file = M.helpers.delete_file
        original_open_buf = M.open_buf
        original_create_note_file = M._create_note_file
        original_notify = vim.notify
        original_finder_dependencies = M._finder_dependencies
        original_logger_warning = M.logger.warning
        require("parley.note_finder").clear_cache()

        -- Use a guaranteed-unique temp dir: vim.fn.tempname() is process- and
        -- call-unique, so parallel/sequential spec processes never collide (the
        -- old math.random() was unseeded → same dir every process → stale files).
        notes_dir = vim.fn.tempname() .. "-parley-test-notefinder"
        vim.fn.delete(notes_dir, "rf")
        vim.fn.mkdir(notes_dir, "p")
        -- Resolve /tmp -> /private/tmp (macOS symlink) AFTER the dir exists, so the
        -- spec's expected paths agree with the resolved paths the finder returns
        -- (note_finder.lua resolves every scanned file via vim.fn.resolve).
        notes_dir = vim.fn.resolve(notes_dir)

        M.config.notes_dir = notes_dir
        M.config.note_dirs = { notes_dir }
        M.config.note_roots = { { dir = notes_dir, label = "main", is_primary = true } }
        M.config.note_finder_mappings = {
            delete = { shortcut = "<C-d>" },
            next_recency = { shortcut = "<C-a>" },
            previous_recency = { shortcut = "<C-s>" },
        }
        M.config.note_finder_recency = {
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

        M._note_finder = {
            opened = false,
            show_all = false,
            recency_index = nil,
            source_win = nil,
            initial_index = nil,
            initial_value = nil,
            sticky_query = nil,
        }
    end)

    after_each(function()
        for _, win in ipairs(find_float_wins()) do
            pcall(vim.api.nvim_win_close, win, true)
        end
        if notes_dir then
            vim.fn.delete(notes_dir, "rf")
        end

        M.config = original_config
        M.float_picker.open = original_float_picker_open
        vim.ui.input = original_ui_input
        vim.defer_fn = original_defer_fn
        vim.schedule = original_schedule
        M._reopen_note_finder = original_reopen_note_finder
        M.helpers.delete_file = original_delete_file
        M.open_buf = original_open_buf
        M._create_note_file = original_create_note_file
        vim.notify = original_notify
        M._finder_dependencies = original_finder_dependencies
        M.logger.warning = original_logger_warning
        require("parley.note_finder").clear_cache()
    end)

    it("resolves and cycles note recency presets", function()
        local resolved = M._resolve_note_finder_recency({
            filter_by_default = true,
            months = 12,
            presets = { 12, 6, 6 },
        })

        assert.equals(2, resolved.index)
        assert.equals(6, resolved.states[1].months)
        assert.equals(12, resolved.states[2].months)
        assert.equals("All", resolved.states[3].label)

        local next_index, next_state = M._cycle_note_finder_recency({
            filter_by_default = true,
            months = 6,
            presets = { 6, 12 },
        }, 2, "next")

        assert.equals(3, next_index)
        assert.is_true(next_state.is_all)
    end)

    it("searches notes recursively, excludes templates, and uses directory dates for recency", function()
        local now = os.date("*t")
        local current_month_note = string.format(
            "%s/%04d/%02d/W%02d/01-design.md",
            notes_dir,
            now.year,
            now.month,
            tonumber(os.date("%U")) + 1
        )
        local nested_project_note = notes_dir .. "/projects/client-a/brief.md"
        local old_note = string.format("%s/%04d/01/W01/03-archive.md", notes_dir, now.year - 3)
        local template_note = notes_dir .. "/templates/basic.md"

        write_file(current_month_note, { "# Design" })
        write_file(nested_project_note, { "# Brief" })
        write_file(old_note, { "# Archive" })
        write_file(template_note, { "# Template" })

        local stale = os.time() - (5 * 365 * 24 * 60 * 60)
        vim.loop.fs_utime(current_month_note, stale, stale)

        local captured = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.equals("Note Files (Recent: 12 months  <C-a>/<C-s>: cycle)", captured.title)
        assert.equals("<C-d>", captured.mappings[1].key)
        assert.equals("<C-a>", captured.mappings[2].key)
        assert.equals("<C-s>", captured.mappings[3].key)

        local values = vim.tbl_map(function(item)
            return item.value
        end, captured.items)
        assert.is_true(vim.tbl_contains(values, current_month_note))
        assert.is_true(vim.tbl_contains(values, nested_project_note))
        assert.is_false(vim.tbl_contains(values, old_note))
        assert.is_false(vim.tbl_contains(values, template_note))
        for _, item in ipairs(captured.items) do
            if item.value == current_month_note then
                assert.matches("%{%}", item.search_text)
            end
        end
    end)

    it("always includes special first-level folders and labels them in display/search text", function()
        local now = os.date("*t")
        local regular_old_note = string.format("%s/%04d/01/W01/03-archive.md", notes_dir, now.year - 3)
        local special_old_note = notes_dir .. "/K/evergreen-note.md"

        write_file(regular_old_note, { "# Archive" })
        write_file(special_old_note, { "# Evergreen" })

        local old_mtime = os.time() - (5 * 365 * 24 * 60 * 60)
        vim.loop.fs_utime(regular_old_note, old_mtime, old_mtime)
        vim.loop.fs_utime(special_old_note, old_mtime, old_mtime)

        local captured = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.equals(1, #captured.items)
        assert.equals(special_old_note, captured.items[1].value)
        assert.matches("^%{K%} evergreen%-note%.md", captured.items[1].display)
        assert.matches("%{K%}", captured.items[1].search_text)
        assert.matches("evergreen%-note%.md", captured.items[1].search_text)
    end)

    it("restores selection by note path and opens the selected note", function()
        local now = os.date("*t")
        local alpha = string.format("%s/%04d/%02d/W01/02-alpha.md", notes_dir, now.year, now.month)
        local beta = string.format("%s/%04d/%02d/W01/03-beta.md", notes_dir, now.year, now.month)
        write_file(alpha, { "# Alpha" })
        write_file(beta, { "# Beta" })

        local captured = nil
        local opened = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end
        M.open_buf = function(path, from_finder)
            opened = { path = path, from_finder = from_finder }
        end

        M._note_finder.initial_index = 2
        M._note_finder.initial_value = beta

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.equals(beta, captured.items[1].value)
        assert.equals(1, captured.initial_index)

        captured.on_select(captured.items[1])
        assert.same({ path = beta, from_finder = true }, opened)
    end)

    it("orders same-date notes by last modified time before path name", function()
        local now = os.date("*t")
        local newer_name = string.format("%s/%04d/%02d/W01/04-alpha.md", notes_dir, now.year, now.month)
        local older_name = string.format("%s/%04d/%02d/W01/04-zulu.md", notes_dir, now.year, now.month)
        write_file(newer_name, { "# Newer" })
        write_file(older_name, { "# Older" })

        local older_mtime = os.time() - 120
        local newer_mtime = os.time() - 10
        vim.loop.fs_utime(older_name, older_mtime, older_mtime)
        vim.loop.fs_utime(newer_name, newer_mtime, newer_mtime)

        local captured = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.equals(newer_name, captured.items[1].value)
        assert.equals(older_name, captured.items[2].value)
    end)

    it("preserves only brace folder filters across note finder invocations", function()
        local special_note = notes_dir .. "/K/evergreen-note.md"
        write_file(special_note, { "# Evergreen" })

        local captured = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.is_function(captured.on_query_change)

        captured.on_query_change("{K} evergreen")
        assert.equals("{K}", M._note_finder.sticky_query)

        captured.on_cancel()
        M.cmd.NoteFinder()
        assert.equals("{K} ", captured.initial_query)

        captured.on_query_change("evergreen")
        assert.is_nil(M._note_finder.sticky_query)
    end)

    it("preserves empty brace filters for dated note trees", function()
        local now = os.date("*t")
        local dated_note = string.format("%s/%04d/%02d/W01/05-dated.md", notes_dir, now.year, now.month)
        write_file(dated_note, { "# Dated" })

        local captured = nil
        M.float_picker.open = function(opts)
            captured = opts
            return picker_stub(opts)
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        captured.on_query_change("{} dated")
        assert.equals("{}", M._note_finder.sticky_query)

        captured.on_cancel()
        M.cmd.NoteFinder()
        assert.equals("{} ", captured.initial_query)
    end)

    describe("asynchronous Note discovery", function()
        local function loading_picker(captured, updates)
            local picker = picker_stub(captured)
            picker.update = function(items, _, initial_index)
                updates[#updates + 1] = { items = items, initial_index = initial_index }
            end
            return picker
        end

        it("opens a loading picker before recursive acquisition starts", function()
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

            M.cmd.NoteFinder()

            assert.same({ "picker", "scan" }, order)
            assert.same({ message = "scanning…", animated = true }, captured.status)
            assert.same({}, captured.items)
        end)

        it("animates the real picker while Note acquisition remains delayed", function()
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

            M.cmd.NoteFinder()
            local initial = float_line_containing("scanning…")

            assert.is_not_nil(initial)
            assert(vim.wait(1000, function()
                local current = float_line_containing("scanning…")
                return sentinel and current ~= nil and current ~= initial
            end, 10), "Note spinner did not tick while acquisition was pending")
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", true)
            assert(vim.wait(500, function() return cancel_count == 1 end, 10))
        end)

        it("joins matching retained prewarm and settles its subscriber once", function()
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
            local note_finder = require("parley.note_finder")

            note_finder.prewarm()
            M.cmd.NoteFinder()
            assert.equals(1, scan_count)

            local root = note_finder._discovery_snapshot():copy().roots[1]
            local path = root.path .. "/K/joined.md"
            finish_root({
                root_ordinal = 1,
                status = "success",
                candidates = { {
                    root = root,
                    root_ordinal = 1,
                    relative = "K/joined.md",
                    unresolved_absolute = path,
                    resolved_absolute = path,
                    stat = { mtime = { sec = 100 } },
                } },
                failures = {},
            })
            finish_scan()

            assert.equals(1, #updates)
            assert.equals(path, updates[1].items[1].value)
        end)

        it("cancels picker-owned acquisition and ignores late delivery", function()
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

            M.cmd.NoteFinder()
            captured.on_cancel()
            finish_root({ root_ordinal = 1, status = "success", candidates = {}, failures = {} })
            finish_scan()

            assert.equals(1, cancel_count)
            assert.same({}, updates)
        end)

        it("fingerprints recursive discovery but excludes opener recency", function()
            local note_finder = require("parley.note_finder")
            local first = note_finder._discovery_snapshot()
            local data = first:copy()

            M.config.note_finder_recency.months = 6
            local recency_changed = note_finder._discovery_snapshot()
            M.config.note_roots[1].label = "renamed"
            local root_changed = note_finder._discovery_snapshot()

            assert.equals("note", data.kind)
            assert.is_true(data.recursion)
            assert.equals("*.md", data.pattern)
            assert.same({ source = "libuv", body = "none" }, data.backend)
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
                            on_root({ root_ordinal = ordinal, status = "skipped", reason = "absent_optional" })
                        end
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.NoteFinder()

            assert.equals(1, #updates)
            assert.same({}, updates[1].items)
            assert.is_nil(captured.status_update)
        end)

        it("shows total failure and retries a later prewarm", function()
            local scan_count = 0
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
                        on_root({
                            root_ordinal = 1,
                            status = "failed",
                            failure = { kind = "root_enumeration", diagnostic = "EACCES" },
                        })
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }
            local note_finder = require("parley.note_finder")

            M.cmd.NoteFinder()
            captured.on_cancel()
            note_finder.prewarm()

            assert.same({}, updates)
            assert.is_false(captured.status_update.animated)
            assert.truthy(captured.status_update.message:find("scan failed", 1, true))
            assert.equals(2, scan_count)
        end)

        it("keeps successful records and warns once for stat failures", function()
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
                        local path = root.path .. "/K/good.md"
                        on_root({
                            root_ordinal = 1,
                            status = "success",
                            candidates = { {
                                root = root,
                                root_ordinal = 1,
                                relative = "K/good.md",
                                unresolved_absolute = path,
                                resolved_absolute = path,
                                stat = { mtime = { sec = 100 } },
                            } },
                            failures = { { kind = "stat", diagnostic = "EIO" } },
                        })
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.NoteFinder()

            assert.equals(1, warning_count)
            assert.equals(1, #updates)
            assert.equals(1, #updates[1].items)
        end)

        it("prunes cache only for roots that enumerate successfully", function()
            local note_finder = require("parley.note_finder")
            local cache = note_finder.get_cache()
            local extra = vim.fn.tempname() .. "-parley-note-extra"
            vim.fn.mkdir(extra, "p")
            M.config.note_roots = {
                { dir = notes_dir, label = "main", is_primary = true },
                { dir = extra, label = "peer", is_primary = false },
            }
            cache["/stale-main.md"] = { mtime = 1, root_path = notes_dir }
            cache["/stale-peer.md"] = { mtime = 1, root_path = extra }
            M.logger.warning = function() end
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

            M.cmd.NoteFinder()
            assert.is_nil(cache["/stale-main.md"])
            assert.is_not_nil(cache["/stale-peer.md"])
            vim.fn.delete(extra, "rf")
        end)

        it("replaces a mismatched retained prewarm", function()
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
            local note_finder = require("parley.note_finder")

            note_finder.prewarm()
            M.config.note_roots[1].label = "renamed"
            note_finder.prewarm()

            assert.equals(2, scan_count)
            assert.equals(1, cancel_count)
        end)

        it("retires ownerless prewarm settlement after populating the cache", function()
            local finish_root
            local finish_scan
            M._finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, on_root, on_complete)
                        finish_root = function()
                            local root = options.roots[1]
                            local path = root.path .. "/K/prewarmed.md"
                            on_root({
                                root_ordinal = 1,
                                status = "success",
                                candidates = { {
                                    root = root,
                                    root_ordinal = 1,
                                    relative = "K/prewarmed.md",
                                    unresolved_absolute = path,
                                    resolved_absolute = path,
                                    stat = { mtime = { sec = 100 } },
                                } },
                                failures = {},
                            })
                        end
                        finish_scan = on_complete
                        return { cancel = function() end }
                    end,
                },
            }
            local note_finder = require("parley.note_finder")

            note_finder.prewarm()
            finish_root()
            finish_scan()

            assert.is_false(note_finder.is_prewarming())
            assert.is_not_nil(note_finder.get_cache()[notes_dir .. "/K/prewarmed.md"])
        end)

        it("reuses unchanged cached classification without reading a body", function()
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
                        local root = options.roots[1]
                        local path = root.path .. "/K/cached.md"
                        local item = {
                            root = root,
                            root_ordinal = 1,
                            relative = "K/cached.md",
                            unresolved_absolute = path,
                            resolved_absolute = path,
                            stat = { mtime = { sec = 100 } },
                        }
                        local decision = options.read_policy(item)
                        decisions[#decisions + 1] = decision.kind
                        if decision.kind == "ready" then
                            item.precomputed = decision.value
                        end
                        on_root({ root_ordinal = 1, status = "success", candidates = { item }, failures = {} })
                        on_complete()
                        return { cancel = function() end }
                    end,
                },
            }

            M.cmd.NoteFinder()
            captured.on_cancel()
            M.cmd.NoteFinder()

            assert.same({ "none", "ready" }, decisions)
            assert.equals(notes_dir .. "/K/cached.md", captured.items[1].value)
        end)

        it("reopens with the next recency state after records settle", function()
            local picker_calls = {}
            local deferred
            write_file(notes_dir .. "/K/settled.md")
            M.float_picker.open = function(opts)
                picker_calls[#picker_calls + 1] = opts
                return picker_stub(opts)
            end

            M.cmd.NoteFinder()
            vim.defer_fn = function(callback) deferred = callback end
            local closed = false
            local start_index = M._note_finder.recency_index
            picker_calls[1].mappings[2].fn(nil, function() closed = true end)

            assert.is_true(closed)
            assert.is_true(M._note_finder.recency_index ~= start_index)
            deferred()
            assert.equals(2, #picker_calls)
            assert.truthy(picker_calls[2].title:find("Recent: 6 months", 1, true))
        end)
    end)

    it("creates braced top-level notes directly under notes_dir", function()
        local current_date = os.date("*t")
        local captured = nil

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 42
        end

        local buf = M.new_note("{K} some document title")

        assert.equals(42, buf)
        assert.equals(notes_dir .. "/K/some-document-title.md", captured.filename)
        assert.equals("some document title", captured.title)
        assert.is_nil(captured.template_content)
        assert.same({
            { "Date", string.format("%04d-%02d-%02d", current_date.year, current_date.month, current_date.day) },
        }, captured.metadata)
        assert.equals(1, vim.fn.isdirectory(notes_dir .. "/K"))
    end)

    it("treats plain folder-looking prefixes as normal dated note titles", function()
        local current_date = os.date("*t")
        local year = current_date.year
        local month = string.format("%02d", current_date.month)
        local day = string.format("%02d", current_date.day)
        local week_number = M.helpers.get_week_number_sunday_based(string.format("%04d-%s-%s", year, month, day))
        local week_folder = "W" .. string.format("%02d", week_number)
        local captured = nil

        vim.fn.mkdir(notes_dir .. "/K", "p")

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 55
        end

        local buf = M.new_note("K something this")

        assert.equals(55, buf)
        assert.equals(
            string.format("%s/%04d/%s/%s/%s-K-something-this.md", notes_dir, year, month, week_folder, day),
            captured.filename
        )
        assert.equals("K something this", captured.title)
        assert.is_nil(captured.template_content)
        assert.same({
            { "Date", string.format("%04d-%s-%s", year, month, day) },
            { "Week", week_folder },
        }, captured.metadata)
    end)

    it("rejects bare brace filters during direct note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note("{} test")

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Bare %{%} is reserved for Note Finder filters", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("rejects exact bare braces during direct note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note("{}")

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Bare %{%} is reserved for Note Finder filters", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("rejects repeated leading braced segments during direct note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note("{K} {another} love")

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Only a single leading %{%w+%} segment is supported", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("creates braced top-level notes from templates directly under notes_dir", function()
        local current_date = os.date("*t")
        local captured = nil
        local template = { "# {{title}}", "", "Date: {{date}}" }

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 77
        end

        local buf = M.new_note_from_template("{K} template note", template)

        assert.equals(77, buf)
        assert.equals(notes_dir .. "/K/template-note.md", captured.filename)
        assert.equals("template note", captured.title)
        assert.same(template, captured.template_content)
        assert.same({
            { "Date", string.format("%04d-%02d-%02d", current_date.year, current_date.month, current_date.day) },
        }, captured.metadata)
        assert.equals(1, vim.fn.isdirectory(notes_dir .. "/K"))
    end)

    it("appends a normalized template slug for top-level template notes", function()
        local current_date = os.date("*t")
        local captured = nil
        local template = { "# {{title}}", "", "Date: {{date}}" }

        write_template("hiring-ai-affinity.md")
        write_template("hiring-ai-engineers.md")
        write_template("hiring-ref-check.md")
        write_template("hiring-HMS-Hiring-Manager-Phone-Screen.md")

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 88
        end

        local buf = M.new_note_from_template(
            "{K} xian xu",
            template,
            "hiring-HMS-Hiring-Manager-Phone-Screen.md"
        )

        assert.equals(88, buf)
        assert.equals(notes_dir .. "/K/xian-xu-hms-manager-phone-screen.md", captured.filename)
        assert.equals("xian xu", captured.title)
        assert.same(template, captured.template_content)
        assert.same({
            { "Date", string.format("%04d-%02d-%02d", current_date.year, current_date.month, current_date.day) },
        }, captured.metadata)
    end)

    it("appends a normalized template slug for dated template notes", function()
        local current_date = os.date("*t")
        local year = current_date.year
        local month = string.format("%02d", current_date.month)
        local day = string.format("%02d", current_date.day)
        local week_number = M.helpers.get_week_number_sunday_based(string.format("%04d-%s-%s", year, month, day))
        local week_folder = "W" .. string.format("%02d", week_number)
        local captured = nil
        local template = { "# {{title}}", "", "Date: {{date}}" }

        write_template("hiring-ai-affinity.md")
        write_template("hiring-ai-engineers.md")
        write_template("hiring-ref-check.md")
        write_template("hiring-HMS-Hiring-Manager-Phone-Screen.md")

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 89
        end

        local buf = M.new_note_from_template(
            "Xian Xu",
            template,
            "hiring-HMS-Hiring-Manager-Phone-Screen.md"
        )

        assert.equals(89, buf)
        assert.equals(
            string.format(
                "%s/%04d/%s/%s/%s-xian-xu-hms-manager-phone-screen.md",
                notes_dir,
                year,
                month,
                week_folder,
                day
            ),
            captured.filename
        )
        assert.equals("Xian Xu", captured.title)
        assert.same(template, captured.template_content)
        assert.same({
            { "Date", string.format("%04d-%s-%s", year, month, day) },
            { "Week", week_folder },
        }, captured.metadata)
    end)

    it("keeps uncommon template slugs in template note filenames", function()
        local current_date = os.date("*t")
        local year = current_date.year
        local month = string.format("%02d", current_date.month)
        local day = string.format("%02d", current_date.day)
        local week_number = M.helpers.get_week_number_sunday_based(string.format("%04d-%s-%s", year, month, day))
        local week_folder = "W" .. string.format("%02d", week_number)
        local captured = nil
        local template = { "# {{title}}", "", "Date: {{date}}" }

        write_template("brief-phone-screen.md")
        write_template("candidate-summary.md")
        write_template("hms-manager-phone-screen.md")

        M._create_note_file = function(filename, title, metadata, template_content)
            captured = {
                filename = filename,
                title = title,
                metadata = metadata,
                template_content = template_content,
            }
            return 90
        end

        local buf = M.new_note_from_template("Xian Xu", template, "hms-manager-phone-screen.md")

        assert.equals(90, buf)
        assert.equals(
            string.format(
                "%s/%04d/%s/%s/%s-xian-xu-hms-manager-phone-screen.md",
                notes_dir,
                year,
                month,
                week_folder,
                day
            ),
            captured.filename
        )
        assert.equals("Xian Xu", captured.title)
        assert.same(template, captured.template_content)
    end)

    it("rejects bare brace filters during template note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note_from_template("{} test", { "# {{title}}" })

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Bare %{%} is reserved for Note Finder filters", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("rejects exact bare braces during template note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note_from_template("{}", { "# {{title}}" })

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Bare %{%} is reserved for Note Finder filters", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("rejects repeated leading braced segments during template note creation", function()
        local created = false
        local notify_calls = {}

        M._create_note_file = function()
            created = true
        end
        vim.notify = function(msg, level)
            table.insert(notify_calls, { msg = msg, level = level })
        end

        local buf = M.new_note_from_template("{K} {another} love", { "# {{title}}" })

        assert.is_nil(buf)
        assert.is_false(created)
        assert.equals(1, #notify_calls)
        assert.matches("Only a single leading %{%w+%} segment is supported", notify_calls[1].msg)
        assert.equals(vim.log.levels.WARN, notify_calls[1].level)
    end)

    it("reopens note finder on cancelled delete and keeps the moved visual row on confirm", function()
        local reopen_calls = {}
        M._reopen_note_finder = function(source_win, selection_index, selection_value)
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

        M._handle_note_finder_delete_response(nil, "/tmp/note-a.md", 2, 4, 99)
        assert.equals(nil, deleted)
        assert.equals("/tmp/note-a.md", reopen_calls[1].selection_value)

        M._handle_note_finder_delete_response("y", "/tmp/note-b.md", 2, 4, 99, nil, {
            note_finder_items = {
                { value = "/tmp/note-a.md" },
                { value = "/tmp/note-b.md" },
                { value = "/tmp/note-c.md" },
                { value = "/tmp/note-d.md" },
            },
        })

        assert.equals("/tmp/note-b.md", deleted)
        assert.equals("/tmp/note-c.md", reopen_calls[2].selection_value)
    end)

    it("opens note delete confirmation from the source window", function()
        local source_win = vim.api.nvim_get_current_win()
        local prompt_seen = nil
        local prompt_win = nil
        local reopen_calls = {}

        vim.ui.input = function(opts, cb)
            prompt_seen = opts.prompt
            prompt_win = vim.api.nvim_get_current_win()
            cb("n")
        end
        M._reopen_note_finder = function(win, selection_index, selection_value)
            table.insert(reopen_calls, {
                win = win,
                selection_index = selection_index,
                selection_value = selection_value,
            })
        end

        M._prompt_note_finder_delete_confirmation("/tmp/note.md", 3, 5, source_win)

        assert.equals("Delete /tmp/note.md? [y/N] ", prompt_seen)
        assert.equals(source_win, prompt_win)
        assert.equals(1, #reopen_calls)
        assert.equals("/tmp/note.md", reopen_calls[1].selection_value)
    end)
end)
