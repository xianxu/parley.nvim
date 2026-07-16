local finder_scan = require("parley.finder_scan")
local file_enrichment = require("parley.async_file_enrichment")
local operation_queue = require("parley.async_operation_queue")

local M = {}
local FAILURE_KIND = finder_scan.FAILURE_KIND

local function join_path(left, right)
    return left:sub(-1) == "/" and left .. right or left .. "/" .. right
end

local function bounded_error(value)
    if type(value) ~= "string" then
        return "filesystem operation failed"
    end
    return finder_scan.sanitize_diagnostic(value)
end

local function root_failure(root_ordinal, error_value)
    return {
        root_ordinal = root_ordinal,
        status = "failed",
        failure = {
            kind = FAILURE_KIND.root_enumeration,
            diagnostic = bounded_error(error_value),
        },
    }
end

local function sort_by_relative(items)
    table.sort(items, function(left, right) return left.relative < right.relative end)
end

M.new = function(dependencies)
    dependencies = dependencies or {}
    local uv = dependencies.uv or vim.uv or vim.loop
    assert(uv, "libuv is required")

    local source = {}
    source.scan = function(_, options, on_root, on_complete)
        assert(type(options) == "table" and type(options.roots) == "table", "scan roots are required")
        assert(type(options.match) == "function", "scan match policy is required")
        assert(type(on_root) == "function" and type(on_complete) == "function", "scan callbacks are required")
        assert(not (options.read ~= nil and options.read_policy ~= nil), "read and read_policy are mutually exclusive")

        local cancelled = false
        local completed = false
        local pending_roots = #options.roots
        local queue = operation_queue.new(uv, options.concurrency or 16)
        local enrichment_handles = {}
        local handle = {
            cancel = function()
                if cancelled then
                    return
                end
                cancelled = true
                queue.cancel()
                for _, enrichment_handle in ipairs(enrichment_handles) do
                    enrichment_handle.cancel()
                end
            end,
            is_cancelled = function() return cancelled end,
        }

        local function complete_if_ready()
            if not cancelled and not completed and pending_roots == 0 then
                completed = true
                on_complete()
            end
        end

        local function emit_root(event)
            if not cancelled then
                on_root(event)
                pending_roots = pending_roots - 1
                complete_if_ready()
            end
        end

        local function enrich_root(root, root_ordinal, staged)
            sort_by_relative(staged)
            local paths = {}
            for _, candidate in ipairs(staged) do
                paths[#paths + 1] = candidate.relative
            end
            local enrichment_handle = file_enrichment.run({
                uv = uv,
                queue = queue,
                root = root,
                root_ordinal = root_ordinal,
                paths = paths,
                read = options.read,
                read_policy = options.read_policy,
                is_cancelled = function() return cancelled end,
            }, function(result)
                emit_root({
                    root_ordinal = root_ordinal,
                    status = "success",
                    candidates = result.candidates,
                    failures = result.failures,
                })
            end)
            enrichment_handles[#enrichment_handles + 1] = enrichment_handle
        end

        local function scan_root(root, root_ordinal)
            queue:call(function(done) return uv.fs_stat(root.path, done) end, function(preflight_error, stat)
                if cancelled then
                    return
                end
                if preflight_error or not stat then
                    if root.optional and type(preflight_error) == "string"
                        and preflight_error:find("ENOENT", 1, true) then
                        emit_root({ root_ordinal = root_ordinal, status = "skipped", reason = "absent_optional" })
                    else
                        emit_root(root_failure(root_ordinal, preflight_error))
                    end
                    return
                end
                if stat.type ~= "directory" then
                    emit_root(root_failure(root_ordinal, "configured root is not a directory"))
                    return
                end

                local failed = false
                local pending_directories = 0
                local staged = {}
                local function fail_enumeration(error_value)
                    if not failed and not cancelled then
                        failed = true
                        staged = {}
                        emit_root(root_failure(root_ordinal, error_value))
                    end
                end

                local scan_directory
                scan_directory = function(path, relative_parent, parent_depth)
                    if failed or cancelled then
                        return
                    end
                    pending_directories = pending_directories + 1
                    queue:call(function(done) return uv.fs_scandir(path, done) end, function(scandir_error, request)
                        if failed or cancelled then
                            return
                        end
                        if scandir_error or not request then
                            fail_enumeration(scandir_error)
                            return
                        end

                        local ok, drain_error = pcall(function()
                            while true do
                                local name, entry_type = uv.fs_scandir_next(request)
                                if not name then
                                    break
                                end
                                local relative = relative_parent == "" and name or relative_parent .. "/" .. name
                                local depth = parent_depth + 1
                                if entry_type == "directory" then
                                    if options.recurse and depth < options.max_depth then
                                        scan_directory(join_path(path, name), relative, depth)
                                    end
                                elseif entry_type == "file" or entry_type == "link" then
                                    if depth <= options.max_depth and options.match(relative, entry_type) then
                                        staged[#staged + 1] = { relative = relative, entry_type = entry_type }
                                    end
                                else
                                    error("unknown directory entry type")
                                end
                            end
                        end)
                        if not ok then
                            fail_enumeration(drain_error)
                            return
                        end

                        pending_directories = pending_directories - 1
                        if pending_directories == 0 and not failed then
                            enrich_root(root, root_ordinal, staged)
                        end
                    end)
                end
                scan_directory(root.path, "", 0)
            end)
        end

        if pending_roots == 0 then
            complete_if_ready()
        else
            for root_ordinal, root in ipairs(options.roots) do
                scan_root(root, root_ordinal)
            end
        end
        return handle
    end

    source.read_paths = function(_, options, on_complete)
        assert(type(options) == "table" and type(options.paths) == "table", "read paths are required")
        assert(type(options.root) == "table" and type(options.root.path) == "string", "read root is required")
        assert(type(on_complete) == "function", "read completion callback is required")
        assert(not (options.read ~= nil and options.read_policy ~= nil), "read and read_policy are mutually exclusive")

        local cancelled = false
        local queue = operation_queue.new(uv, options.concurrency or 16)
        local enrichment_handle = file_enrichment.run({
            uv = uv,
            queue = queue,
            root = options.root,
            root_ordinal = options.root_ordinal,
            paths = options.paths,
            read = options.read,
            read_policy = options.read_policy,
            is_cancelled = function() return cancelled end,
        }, on_complete)
        return {
            cancel = function()
                if not cancelled then
                    cancelled = true
                    queue.cancel()
                    enrichment_handle.cancel()
                end
            end,
            is_cancelled = function() return cancelled end,
        }
    end
    return source
end

local default_source
M.scan = function(options, on_root, on_complete)
    default_source = default_source or M.new()
    return default_source:scan(options, on_root, on_complete)
end

M.read_paths = function(options, on_complete)
    default_source = default_source or M.new()
    return default_source:read_paths(options, on_complete)
end

return M
