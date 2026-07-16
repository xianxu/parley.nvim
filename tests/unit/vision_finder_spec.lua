local parley = require("parley")
local vision_finder = require("parley.vision_finder")

describe("VisionFinder asynchronous discovery", function()
    local fake
    local captured
    local updates
    local order
    local on_root
    local on_complete
    local scan_options
    local warnings
    local cancel_count
    local opened_path

    local function picker_stub(opts)
        local closed = false
        return {
            update = function(items, tags, initial_index)
                updates[#updates + 1] = { items = items, tags = tags, initial_index = initial_index }
            end,
            set_status = function(status) captured.status_update = status end,
            set_title = function(title) captured.settled_title = title end,
            current_query = function() return opts.initial_query or "" end,
            is_closed = function() return closed end,
            close = function() closed = true end,
        }
    end

    local function candidate(root_ordinal, path, payload)
        return {
            unresolved_absolute = path,
            resolved_absolute = path,
            relative = path:match("([^/]+)$"),
            root_ordinal = root_ordinal,
            root = scan_options.roots[root_ordinal],
            stat = { mtime = { sec = 100 }, type = "file" },
            payload = payload,
        }
    end

    local function float_line_containing(needle)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local ok, config = pcall(vim.api.nvim_win_get_config, win)
            if ok and config.relative ~= "" then
                local buffer = vim.api.nvim_win_get_buf(win)
                for _, line in ipairs(vim.api.nvim_buf_get_lines(buffer, 0, -1, false)) do
                    if line:find(needle, 1, true) then
                        return line
                    end
                end
            end
        end
    end

    before_each(function()
        captured = nil
        updates = {}
        order = {}
        warnings = {}
        cancel_count = 0
        opened_path = nil
        fake = {
            _vision_finder = { opened = false, sticky_query = "{repo}" },
            _finder_dependencies = {
                schedule = function(callback) callback() end,
                now = function() return 0 end,
                async_file_source = {
                    scan = function(options, root_callback, complete_callback)
                        order[#order + 1] = "scan"
                        scan_options = options
                        on_root = root_callback
                        on_complete = complete_callback
                        return { cancel = function()
                            cancel_count = cancel_count + 1
                            order[#order + 1] = "cancel"
                        end }
                    end,
                },
            },
            config = { vision_dir = "/repo/workshop/vision" },
            float_picker = {
                open = function(opts)
                    order[#order + 1] = "picker"
                    captured = opts
                    return picker_stub(opts)
                end,
            },
            logger = { warning = function(message) warnings[#warnings + 1] = message end },
            open_buf = function(path) opened_path = path end,
        }
        vision_finder.setup(fake)
    end)

    after_each(function()
        vision_finder.setup(parley)
    end)

    it("opens scanning before disk acquisition and settles project rows in source order", function()
        vision_finder.open()

        assert.same({ "picker", "scan" }, order)
        assert.same({ message = "scanning…", animated = true }, captured.status)
        assert.equals("{repo} ", captured.initial_query)
        assert.same({}, captured.items)

        on_root({
            root_ordinal = 1,
            status = "success",
            failures = {},
            candidates = { {
                unresolved_absolute = "/repo/workshop/vision/platform.yaml",
                resolved_absolute = "/repo/workshop/vision/platform.yaml",
                relative = "platform.yaml",
                root_ordinal = 1,
                root = { path = "/repo/workshop/vision", optional = true },
                stat = { mtime = { sec = 100 }, type = "file" },
                payload = table.concat({
                    "- project: First",
                    "  size: S",
                    "- person: Ada",
                    "- project: Second",
                }, "\n"),
            } },
        })
        on_complete()

        assert.equals(1, #updates)
        assert.same({ "First", "Second" },
            vim.tbl_map(function(item) return item.project end, updates[1].items))
        assert.same({ 1, 4 }, vim.tbl_map(function(item) return item.line end, updates[1].items))
        assert.equals("Vision (2 initiatives)", captured.settled_title)
    end)

    it("keeps query changes live while loading and jumps to the settled source line", function()
        local buffer = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {
            "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
        })
        vision_finder.open()
        captured.on_query_change("plain {next}")

        on_root({
            root_ordinal = 1,
            status = "success",
            failures = {},
            candidates = { candidate(
                1,
                "/repo/workshop/vision/platform.yaml",
                "- person: Ada\n- project: Selected\n  size: S"
            ) },
        })
        on_complete()

        assert.equals("{next}", fake._vision_finder.sticky_query)
        captured.on_select(updates[1].items[1])
        assert.equals("/repo/workshop/vision/platform.yaml", opened_path)
        assert.same({ 2, 0 }, vim.api.nvim_win_get_cursor(0))
    end)

    it("settles absent optional roots as an empty successful picker", function()
        vision_finder.open()
        on_root({ root_ordinal = 1, status = "skipped", reason = "absent_optional" })
        on_complete()

        assert.same({}, updates[1].items)
        assert.equals("Vision (0 initiatives)", captured.settled_title)
        assert.is_nil(captured.status_update)
        assert.same({}, warnings)
    end)

    it("aggregates out-of-order roots into stable file and parser order", function()
        fake.super_repo = {
            expand_roots = function()
                return {
                    { dir = "/zeta/vision", repo_name = "zeta" },
                    { dir = "/alpha/vision", repo_name = "alpha" },
                }
            end,
        }
        vision_finder.open()
        on_root({
            root_ordinal = 2,
            status = "success",
            failures = {},
            candidates = { candidate(2, "/alpha/vision/a.yaml", "- project: Alpha") },
        })
        on_root({
            root_ordinal = 1,
            status = "success",
            failures = {},
            candidates = { candidate(1, "/zeta/vision/z.yaml", "- project: Zeta") },
        })
        on_complete()

        assert.same({ "Alpha", "Zeta" },
            vim.tbl_map(function(item) return item.project end, updates[1].items))
        assert.truthy(updates[1].items[1].display:find("{alpha}", 1, true))
    end)

    it("keeps total failure visible and reports partial read or parser failures once", function()
        vision_finder.open()
        on_root({
            root_ordinal = 1,
            status = "failed",
            failure = { kind = "root_enumeration", diagnostic = "denied" },
        })
        on_complete()
        assert.is_false(captured.status_update.animated)
        assert.truthy(captured.status_update.message:find("scan failed", 1, true))

        captured.on_cancel()
        vision_finder.open()
        local malformed = candidate(1, "/repo/workshop/vision/bad.yaml", "- project: Bad")
        malformed.stat = nil
        on_root({
            root_ordinal = 1,
            status = "success",
            failures = { { kind = "read", diagnostic = "unreadable" } },
            candidates = { malformed, candidate(1, "/repo/workshop/vision/README.md", "# skip") },
        })
        on_complete()

        assert.equals(1, #warnings)
        assert.truthy(warnings[1]:find("0 roots, 2 files failed", 1, true))
        assert.same({}, updates[#updates].items)
    end)

    it("cancels picker-owned acquisition and ignores late delivery", function()
        vision_finder.open()
        captured.on_cancel()
        assert.equals(1, cancel_count)
        on_root({ root_ordinal = 1, status = "success", failures = {}, candidates = {} })
        on_complete()
        assert.equals(0, #updates)
    end)

    it("animates the real picker while Vision acquisition remains delayed", function()
        fake.float_picker.open = parley.float_picker.open
        fake._finder_dependencies.schedule = vim.schedule
        local sentinel = false
        vim.schedule(function() sentinel = true end)

        vision_finder.open()
        local initial = float_line_containing("scanning…")
        assert.is_not_nil(initial)
        assert(vim.wait(1000, function()
            local current = float_line_containing("scanning…")
            return sentinel and current ~= nil and current ~= initial
        end, 10), "Vision spinner did not tick while acquisition was pending")
        vim.api.nvim_feedkeys(
            vim.api.nvim_replace_termcodes("<Esc>", true, false, true),
            "x",
            true
        )
        assert(vim.wait(500, function() return cancel_count == 1 end, 10))
    end)

    it("reads YAML through the real asynchronous disk source", function()
        local root = vim.fn.tempname() .. "-vision-finder-real-source"
        vim.fn.mkdir(root, "p")
        local path = root .. "/disk.yaml"
        vim.fn.writefile({ "- project: Real disk", "  size: M" }, path)
        fake.config.vision_dir = root
        fake._finder_dependencies = { schedule = vim.schedule }

        vision_finder.open()

        assert(vim.wait(1000, function() return #updates == 1 end, 10))
        assert.equals(path, updates[1].items[1].value)
        assert.equals("Real disk", updates[1].items[1].project)
        vim.fn.delete(root, "rf")
    end)

    it("reuses an unchanged cached file bundle without another payload read", function()
        local read_count = 0
        fake.config.vision_dir = "/cache-test"
        fake._finder_dependencies.async_file_source.scan = function(options, root_callback, complete_callback)
            local item = {
                unresolved_absolute = "/cache-test/only.yaml",
                resolved_absolute = "/cache-test/only.yaml",
                relative = "only.yaml",
                root_ordinal = 1,
                root = options.roots[1],
                stat = { mtime = { sec = 4242 }, type = "file" },
            }
            local decision = options.read_policy(item)
            if decision.kind == "ready" then
                item.precomputed = decision.value
            else
                read_count = read_count + 1
                item.payload = "- project: Cached"
            end
            root_callback({
                root_ordinal = 1,
                status = "success",
                failures = {},
                candidates = { item },
            })
            complete_callback()
            return { cancel = function() end }
        end

        vision_finder.open()
        captured.on_cancel()
        vision_finder.open()

        assert.equals(1, read_count)
        assert.equals(2, #updates)
        assert.equals("Cached", updates[2].items[1].project)
    end)
end)
