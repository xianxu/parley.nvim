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

    local function write_file(path, lines)
        vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
        local file = io.open(path, "w")
        assert.is_truthy(file)
        file:write(table.concat(lines or { "# test" }, "\n"))
        file:close()
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

        notes_dir = "/tmp/parley-test-notefinder-" .. string.format("%x", math.random(0, 0xFFFFFF))
        vim.fn.mkdir(notes_dir, "p")

        M.config.notes_dir = notes_dir
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
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        assert.is_function(captured.on_query_change)

        captured.on_query_change("{K} evergreen")
        assert.equals("{K}", M._note_finder.sticky_query)

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
        end

        M.cmd.NoteFinder()

        assert.is_truthy(captured)
        captured.on_query_change("{} dated")
        assert.equals("{}", M._note_finder.sticky_query)

        M.cmd.NoteFinder()
        assert.equals("{} ", captured.initial_query)
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
