local async_file_source = require("parley.async_file_source")
local file_enrichment = require("parley.async_file_enrichment")
local failure_kind = require("parley.finder_scan").FAILURE_KIND

local function fake_uv(options)
    options = options or {}
    local directories = options.directories or {}
    local stats = options.stats or {}
    local scandir_errors = options.scandir_errors or {}

    return {
        fs_stat = function(path, callback)
            local value = stats[path]
            if type(value) == "table" and value.error then
                callback(value.error)
            elseif value then
                callback(nil, value)
            elseif directories[path] then
                callback(nil, { type = "directory", mtime = { sec = 1 } })
            else
                callback("ENOENT: no such file")
            end
        end,
        fs_scandir = function(path, callback)
            if scandir_errors[path] then
                callback(scandir_errors[path])
                return
            end
            callback(nil, { entries = directories[path] or {}, index = 0 })
        end,
        fs_scandir_next = function(request)
            request.index = request.index + 1
            local entry = request.entries[request.index]
            if entry then
                return entry[1], entry[2]
            end
        end,
        fs_realpath = function(path, callback)
            callback(nil, "/real" .. path)
        end,
    }
end

local function run_scan(uv, options)
    local roots = {}
    local complete_count = 0
    local source = async_file_source.new({ uv = uv })
    local handle = source:scan(options, function(event)
        roots[#roots + 1] = event
    end, function()
        complete_count = complete_count + 1
    end)
    return roots, complete_count, handle, function() return complete_count end
end

local function deferred_uv(root_paths)
    local pending = {}
    local active = 0
    local max_active = 0
    local cancel_count = 0
    local roots = {}
    for _, path in ipairs(root_paths) do
        roots[path] = true
    end

    local function defer(callback, ...)
        active = active + 1
        max_active = math.max(max_active, active)
        local request = { callback = callback, values = { ... }, cancelled = false }
        pending[#pending + 1] = request
        return request
    end

    local uv = {
        fs_stat = function(path, callback)
            if roots[path] then
                return defer(callback, nil, { type = "directory" })
            end
            return defer(callback, "ENOENT")
        end,
        fs_scandir = function(_, callback)
            return defer(callback, nil, { entries = {}, index = 0 })
        end,
        fs_scandir_next = function(request)
            request.index = request.index + 1
        end,
        fs_realpath = function(path, callback)
            return defer(callback, nil, path)
        end,
        cancel = function(request)
            if not request.cancelled then
                request.cancelled = true
                cancel_count = cancel_count + 1
            end
            return true
        end,
    }

    local control = {}
    control.drain_one = function()
        local request = table.remove(pending, 1)
        if not request then
            return false
        end
        active = active - 1
        if request.cancelled then
            request.callback("ECANCELED")
        else
            request.callback(unpack(request.values))
        end
        return true
    end
    control.drain_all = function()
        while control.drain_one() do end
    end
    control.max_active = function() return max_active end
    control.cancel_count = function() return cancel_count end
    control.pending_count = function() return #pending end
    return uv, control
end

local function file_uv(files)
    local opens = 0
    local reads = 0
    local closes = 0
    local uv = {
        fs_stat = function(path, callback)
            local file = files[path]
            if not file or file.stat_error then
                callback(file and file.stat_error or "ENOENT")
                return
            end
            callback(nil, file.stat or { type = "file", mtime = { sec = 1 } })
        end,
        fs_realpath = function(path, callback)
            local file = files[path]
            callback(file and file.realpath_error, file and file.realpath or path)
        end,
        fs_open = function(path, _, _, callback)
            opens = opens + 1
            local file = files[path]
            if file.open_error then
                callback(file.open_error)
            else
                callback(nil, { path = path })
            end
        end,
        fs_read = function(fd, size, offset, callback)
            reads = reads + 1
            local file = files[fd.path]
            if file.read_error then
                callback(file.read_error)
                return
            end
            callback(nil, file.content:sub(offset + 1, offset + size))
        end,
        fs_close = function(_, callback)
            closes = closes + 1
            callback(nil)
        end,
    }
    return uv, {
        opens = function() return opens end,
        reads = function() return reads end,
        closes = function() return closes end,
    }
end

describe("asynchronous file source", function()
    describe("transactional traversal", function()
        it("skips absent optional roots and enriches a successful recursive root", function()
            local uv = fake_uv({
                directories = {
                    ["/repo"] = {
                        { "root.md", "file" },
                        { "docs", "directory" },
                        { "linked", "link" },
                    },
                    ["/repo/docs"] = { { "nested.md", "file" } },
                },
                stats = {
                    ["/repo/root.md"] = { type = "file", mtime = { sec = 2 } },
                    ["/repo/docs/nested.md"] = { type = "file", mtime = { sec = 3 } },
                    ["/repo/linked"] = { type = "directory", mtime = { sec = 4 } },
                },
            })

            local events, complete_count, handle = run_scan(uv, {
                roots = {
                    { path = "/missing", optional = true },
                    { path = "/repo", optional = false },
                },
                recurse = true,
                max_depth = 4,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "none",
                concurrency = 16,
            })

            assert.equals(2, #events)
            assert.same({ root_ordinal = 1, status = "skipped", reason = "absent_optional" }, events[1])
            assert.equals("success", events[2].status)
            assert.equals(2, events[2].root_ordinal)
            assert.same({ "docs/nested.md", "root.md" }, vim.tbl_map(function(item)
                return item.relative
            end, events[2].candidates))
            assert.same({}, events[2].failures)
            assert.equals(1, complete_count)
            assert.is_false(handle:is_cancelled())
        end)

        it("discards staged candidates when nested enumeration fails", function()
            local uv = fake_uv({
                directories = {
                    ["/repo"] = { { "kept.md", "file" }, { "broken", "directory" } },
                },
                stats = {
                    ["/repo/kept.md"] = { type = "file", mtime = { sec = 2 } },
                },
                scandir_errors = { ["/repo/broken"] = "EACCES: denied" },
            })

            local events, _, _, complete_count = run_scan(uv, {
                roots = { { path = "/repo", optional = false } },
                recurse = true,
                max_depth = 4,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "none",
                concurrency = 16,
            })

            assert.equals(1, #events)
            assert.equals("failed", events[1].status)
            assert.equals(failure_kind.root_enumeration, events[1].failure.kind)
            assert.is_nil(events[1].candidates)
            assert.equals(1, complete_count())
        end)

        it("fails safely on an unknown entry type needed for traversal", function()
            local uv = fake_uv({
                directories = { ["/repo"] = { { "mystery", "unknown" } } },
            })

            local events = run_scan(uv, {
                roots = { { path = "/repo", optional = false } },
                recurse = true,
                max_depth = 4,
                match = function() return true end,
                read = "none",
                concurrency = 16,
            })

            assert.equals("failed", events[1].status)
            assert.equals(failure_kind.root_enumeration, events[1].failure.kind)
        end)

        it("counts depth by relative path components", function()
            local uv = fake_uv({
                directories = {
                    ["/repo"] = { { "one", "directory" }, { "root.md", "file" } },
                    ["/repo/one"] = { { "two", "directory" }, { "depth2.md", "file" } },
                    ["/repo/one/two"] = { { "depth3.md", "file" } },
                },
                stats = {
                    ["/repo/root.md"] = { type = "file" },
                    ["/repo/one/depth2.md"] = { type = "file" },
                },
            })

            local events = run_scan(uv, {
                roots = { { path = "/repo", optional = false } },
                recurse = true,
                max_depth = 2,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read = "none",
                concurrency = 16,
            })

            assert.equals("success", events[1].status)
            assert.same({ "one/depth2.md", "root.md" }, vim.tbl_map(function(item)
                return item.relative
            end, events[1].candidates))
        end)
    end)


    describe("concurrency and cancellation", function()
        it("caps filesystem operations across roots", function()
            local paths = {}
            local roots = {}
            for index = 1, 20 do
                local path = "/repo-" .. index
                paths[#paths + 1] = path
                roots[#roots + 1] = { path = path, optional = false }
            end
            local uv, control = deferred_uv(paths)
            local events, _, _, complete_count = run_scan(uv, {
                roots = roots,
                recurse = true,
                max_depth = 2,
                match = function() return true end,
                read = "none",
                concurrency = 16,
            })

            control.drain_all()

            assert.is_true(control.max_active() <= 16)
            assert.equals(20, #events)
            assert.equals(1, complete_count())
        end)

        it("cancels active work once and suppresses queued and late callbacks", function()
            local paths = {}
            local roots = {}
            for index = 1, 20 do
                local path = "/repo-" .. index
                paths[#paths + 1] = path
                roots[#roots + 1] = { path = path, optional = false }
            end
            local uv, control = deferred_uv(paths)
            local events, _, handle, complete_count = run_scan(uv, {
                roots = roots,
                recurse = true,
                max_depth = 2,
                match = function() return true end,
                read = "none",
                concurrency = 16,
            })

            handle:cancel()
            handle:cancel()
            control.drain_all()

            assert.is_true(handle:is_cancelled())
            assert.equals(16, control.cancel_count())
            assert.equals(0, control.pending_count())
            assert.same({}, events)
            assert.equals(0, complete_count())
        end)
    end)

    describe("conditional path reads", function()
		it("rejects directory targets while preserving regular-file candidates", function()
			local uv = file_uv({
				["/repo/directory.md"] = { stat = { type = "directory", mtime = { sec = 1 } } },
				["/repo/file.md"] = { stat = { type = "file", mtime = { sec = 2 } } },
			})
			local source = async_file_source.new({ uv = uv })
			local completion

			source:read_paths({
				root = { path = "/repo" },
				root_ordinal = 1,
				paths = { "directory.md", "file.md" },
				read = "none",
				concurrency = 16,
			}, function(result) completion = result end)

			assert.same({ "file.md" }, vim.tbl_map(function(candidate) return candidate.relative end,
				completion.candidates))
			assert.equals(1, #completion.failures)
			assert.equals("directory.md", completion.failures[1].relative)
			assert.equals(failure_kind.invalid_path, completion.failures[1].kind)
		end)

        it("applies the same post-stat read policy during traversal", function()
            local uv = fake_uv({
                directories = { ["/repo"] = { { "chat.md", "file" } } },
                stats = { ["/repo/chat.md"] = { type = "file", mtime = { sec = 2 } } },
            })
            local open_count = 0
            uv.fs_open = function(path, _, _, callback)
                open_count = open_count + 1
                callback(nil, { path = path })
            end
            uv.fs_read = function(_, _, offset, callback)
                callback(nil, offset == 0 and "topic\nbody\n" or "")
            end
            uv.fs_close = function(_, callback) callback(nil) end

            local events = run_scan(uv, {
                roots = { { path = "/repo", optional = false } },
                recurse = true,
                max_depth = 2,
                match = function(relative) return relative:match("%.md$") ~= nil end,
                read_policy = function()
                    return { kind = "read", mode = { head_lines = 1 } }
                end,
                concurrency = 16,
            })

            assert.equals("topic\n", events[1].candidates[1].payload)
            assert.equals(1, open_count)
        end)

        it("uses cached values without opening and reads only changed headers", function()
            local uv, calls = file_uv({
                ["/repo/cached.md"] = { content = "cached body", realpath = "/real/cached.md" },
                ["/repo/changed.md"] = { content = "one\ntwo\nthree\n", realpath = "/real/changed.md" },
                ["/repo/stat-only.md"] = { content = "unused" },
            })
            local source = async_file_source.new({ uv = uv })
            local completion
            local complete_count = 0

            source:read_paths({
                root = { path = "/repo", label = "repo" },
                root_ordinal = 1,
                paths = { "cached.md", "changed.md", "stat-only.md" },
                read_policy = function(stat_record)
                    if stat_record.relative == "cached.md" then
                        return { kind = "ready", value = { topic = "cached" } }
                    elseif stat_record.relative == "changed.md" then
                        return { kind = "read", mode = { head_lines = 2 } }
                    end
                    return { kind = "none" }
                end,
                concurrency = 16,
            }, function(result)
                completion = result
                complete_count = complete_count + 1
            end)

            assert.equals(1, complete_count)
            assert.same({}, completion.failures)
            assert.equals(3, #completion.candidates)
            assert.same({ topic = "cached" }, completion.candidates[1].precomputed)
            assert.is_nil(completion.candidates[1].payload)
            assert.equals("one\ntwo\n", completion.candidates[2].payload)
            assert.is_nil(completion.candidates[2].precomputed)
            assert.is_nil(completion.candidates[3].payload)
            assert.equals(1, calls.opens())
            assert.is_true(calls.reads() >= 1)
            assert.equals(1, calls.closes())
        end)

        it("contains invalid and throwing read policies as static record failures", function()
            local uv, calls = file_uv({
                ["/repo/invalid.md"] = { content = "secret" },
                ["/repo/throws.md"] = { content = "secret" },
            })
            local source = async_file_source.new({ uv = uv })
            local completion

            source:read_paths({
                root = { path = "/repo" },
                root_ordinal = 1,
                paths = { "invalid.md", "throws.md" },
                read_policy = function(stat_record)
                    if stat_record.relative == "invalid.md" then
                        return { kind = "raw", value = "secret" }
                    end
                    error({ secret = string.rep("x", 1000) })
                end,
                concurrency = 16,
            }, function(result)
                completion = result
            end)

            assert.same({ failure_kind.invalid_read_policy, failure_kind.read_policy_exception },
                vim.tbl_map(function(item) return item.kind end, completion.failures))
            assert.same({}, completion.candidates)
            assert.equals(0, calls.opens())
            assert.is_nil(completion.failures[1].diagnostic)
            assert.is_nil(completion.failures[2].diagnostic)
        end)

        it("closes descriptors when a read fails", function()
            local uv, calls = file_uv({
                ["/repo/broken.md"] = { content = "", read_error = "EIO" },
            })
            local source = async_file_source.new({ uv = uv })
            local completion

            source:read_paths({
                root = { path = "/repo" },
                root_ordinal = 1,
                paths = { "broken.md" },
                read = "all",
                concurrency = 16,
            }, function(result)
                completion = result
            end)

            assert.same({}, completion.candidates)
            assert.equals(failure_kind.read, completion.failures[1].kind)
            assert.equals(1, calls.opens())
            assert.equals(1, calls.closes())
        end)

        it("rechecks cancellation after policy evaluation before opening", function()
            local uv, calls = file_uv({
                ["/repo/cancel.md"] = { content = "must not read" },
            })
            local finish_realpath
            uv.fs_realpath = function(path, callback)
                finish_realpath = function() callback(nil, path) end
            end
            local source = async_file_source.new({ uv = uv })
            local handle
            local complete_count = 0

            handle = source:read_paths({
                root = { path = "/repo" },
                root_ordinal = 1,
                paths = { "cancel.md" },
                read_policy = function()
                    handle:cancel()
                    return { kind = "read", mode = "all" }
                end,
                concurrency = 16,
            }, function()
                complete_count = complete_count + 1
            end)
            finish_realpath()

            assert.is_true(handle:is_cancelled())
            assert.equals(0, calls.opens())
            assert.equals(0, complete_count)
        end)

        it("closes a descriptor returned after cancellation cannot stop fs_open", function()
            local finish_open
            local fd = { path = "/repo/late.md" }
            local close_count = 0
            local completion_count = 0
            local uv = {
                fs_stat = function(_, callback)
                    callback(nil, { type = "file", mtime = { sec = 1 } })
                end,
                fs_realpath = function(path, callback) callback(nil, path) end,
                fs_open = function(_, _, _, callback)
                    finish_open = callback
                    return { kind = "open-request" }
                end,
                fs_close = function(closed_fd, callback)
                    assert.equals(fd, closed_fd)
                    close_count = close_count + 1
                    callback(nil)
                end,
                cancel = function() return nil, "EBUSY" end,
            }
            local source = async_file_source.new({ uv = uv })
            local handle = source:read_paths({
                root = { path = "/repo" },
                root_ordinal = 1,
                paths = { "late.md" },
                read = "all",
                concurrency = 16,
            }, function()
                completion_count = completion_count + 1
            end)

            handle:cancel()
            finish_open(nil, fd)

            assert.equals(1, close_count)
            assert.equals(0, completion_count)
        end)

        it("retains descriptor ownership while close is queued", function()
            local pending = {}
            local queue = {
                call = function(_, start, callback)
                    pending[#pending + 1] = { start = start, callback = callback }
                end,
            }
            local function drive()
                local job = table.remove(pending, 1)
                assert.is_not_nil(job)
                job.start(function(...) job.callback(...) end)
            end

            local fd = { path = "/repo/queued-close.md" }
            local close_count = 0
            local uv = {
                fs_stat = function(_, callback)
                    callback(nil, { type = "file", mtime = { sec = 1 } })
                end,
                fs_realpath = function(path, callback) callback(nil, path) end,
                fs_open = function(_, _, _, callback) callback(nil, fd) end,
                fs_read = function(_, _, _, callback) callback(nil, "") end,
                fs_close = function(closed_fd, callback)
                    assert.equals(fd, closed_fd)
                    close_count = close_count + 1
                    callback(nil)
                end,
            }
            local handle = file_enrichment.run({
                uv = uv,
                queue = queue,
                root = { path = "/repo" },
                root_ordinal = 1,
                paths = { "queued-close.md" },
                read = "all",
                is_cancelled = function() return false end,
            }, function() error("cancelled enrichment must not complete") end)

            drive() -- stat
            drive() -- realpath
            drive() -- open
            drive() -- read; close remains queued behind saturated work
            assert.equals(1, #pending)

            handle.cancel()
            assert.equals(1, close_count)
        end)
    end)
end)
