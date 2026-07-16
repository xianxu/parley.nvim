-- Vision finder module for Parley
-- Float picker UI for browsing initiatives across vision YAML files

local vision_mod = require("parley.vision")
local finder_sticky = require("parley.finder_sticky")
local finder_scan = require("parley.finder_scan")
local finder_loader = require("parley.finder_loader")
local finder_producer = require("parley.finder_producer")
local async_file_source = require("parley.async_file_source")
local vision_records = require("parley.vision_finder_records")

local M = {}
local _parley
local _file_cache = {}

M.setup = function(parley)
    _parley = parley
end

local function discovery_dependencies()
    local injected = _parley._finder_dependencies or {}
    return {
        async_file_source = injected.async_file_source or async_file_source,
        schedule = injected.schedule or vim.schedule,
        now = injected.now or function()
            return (vim.uv or vim.loop).hrtime() / 1000000
        end,
    }
end

local function discovery_roots()
    local expanded = _parley.super_repo
        and _parley.super_repo.expand_roots(_parley.config.vision_dir) or nil
    local roots = {}
    if expanded then
        for _, root in ipairs(expanded) do
            if type(root.dir) == "string" and root.dir ~= "" then
                roots[#roots + 1] = {
                    path = vim.fn.fnamemodify(vim.fn.expand(root.dir), ":p"):gsub("/+$", ""),
                    repo_name = root.repo_name,
                    optional = true,
                }
            end
        end
    else
        local path
        if type(_parley.config.vision_dir) == "string"
            and _parley.config.vision_dir:sub(1, 1) == "/" then
            path = vim.fn.fnamemodify(vim.fn.expand(_parley.config.vision_dir), ":p"):gsub("/+$", "")
        else
            path = vision_mod.get_vision_dir()
        end
        if path then
            roots[1] = { path = path, optional = true }
        end
    end
    return roots
end

local function discovery_snapshot()
    return finder_scan.snapshot({
        kind = "vision",
        roots = discovery_roots(),
        recursion = false,
        max_depth = 1,
        pattern = "*.yaml",
        backend = { source = "libuv", read = "all" },
    })
end

local function identity_for(candidate)
    return finder_scan.path_identity({
        unresolved_absolute = candidate.unresolved_absolute,
        resolved_absolute = candidate.resolved_absolute,
        root_ordinal = candidate.root_ordinal,
    })
end

local function split_lines(payload)
    local lines = {}
    for line in ((payload or "") .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

local function read_decision(candidate)
    local identity = identity_for(candidate)
    local mtime = candidate.stat and candidate.stat.mtime and candidate.stat.mtime.sec
    local cached = _file_cache[identity.key]
    if type(cached) == "table" and cached.mtime == mtime and type(cached.bundle) == "table" then
        return { kind = "ready", value = cached.bundle }
    end
    return { kind = "read", mode = "all" }
end

local function cached_bundle(candidate, identity)
    local bundle = vim.deepcopy(candidate.precomputed)
    bundle.identity = identity
    bundle._mtime = candidate.stat.mtime.sec
    bundle.source.path = candidate.unresolved_absolute
    bundle.source.repo_name = candidate.root.repo_name
    for _, initiative in ipairs(bundle.initiatives) do
        initiative._file = candidate.unresolved_absolute
        initiative._repo_name = candidate.root.repo_name
    end
    return { kind = "record", value = bundle }
end

local function new_session(snapshot)
    local dependencies = discovery_dependencies()
    return finder_loader.new_session({
        snapshot = snapshot,
        ownership = "picker",
        schedule = dependencies.schedule,
        producer_factory = function(settle)
            local data = snapshot:copy()
            return finder_producer.run({
                roots = data.roots,
                acquire = function(on_root, on_complete)
                    return dependencies.async_file_source.scan({
                        roots = data.roots,
                        recurse = false,
                        max_depth = 1,
                        match = function(relative)
                            return relative:match("%.yaml$") ~= nil
                        end,
                        read_policy = read_decision,
                        concurrency = 16,
                    }, on_root, on_complete)
                end,
                adapter = function(candidate)
                    local identity = candidate.identity or identity_for(candidate)
                    if candidate.precomputed ~= nil then
                        return cached_bundle(candidate, identity)
                    end
                    local result = vision_records.adapt({
                        path = candidate.unresolved_absolute,
                        name = candidate.relative:match("([^/]+)$") or candidate.relative,
                        lines = split_lines(candidate.payload),
                        repo_name = candidate.root.repo_name,
                        identity = identity,
                    })
                    if result.kind == "record" then
                        result.value._mtime = candidate.stat.mtime.sec
                    end
                    return result
                end,
                finalize = function(records)
                    return finder_scan.deduplicate(records)
                end,
                batch = {
                    item_budget = 25,
                    time_budget_ms = 5,
                    now = dependencies.now,
                    schedule = dependencies.schedule,
                },
                on_record = function(bundle)
                    local root_path = data.roots[bundle.identity.source.root_ordinal].path
                    _file_cache[bundle.identity.key] = {
                        mtime = bundle._mtime,
                        root_path = root_path,
                        bundle = vim.deepcopy(bundle),
                    }
                end,
                on_root_success = function(root_ordinal, seen_keys)
                    local seen = {}
                    for _, key in ipairs(seen_keys) do
                        seen[key] = true
                    end
                    local root_path = data.roots[root_ordinal].path
                    for key, cached in pairs(_file_cache) do
                        if cached.root_path == root_path and not seen[key] then
                            _file_cache[key] = nil
                        end
                    end
                end,
            }, settle)
        end,
    })
end

M.open = function()
    if _parley._vision_finder.opened then
        _parley.logger.warning("Vision finder is already open")
        return
    end
    _parley._vision_finder.opened = true

    local snapshot = discovery_snapshot()
    if #snapshot:copy().roots == 0 then
        _parley.logger.warning("vision_dir is not configured")
        _parley._vision_finder.opened = false
        return
    end
    local session = new_session(snapshot)
    local items = {}
    local source_win = vim.api.nvim_get_current_win()
    local chat_finder_mod = require("parley.chat_finder")

    finder_loader.open_picker({
        session = session,
        picker_open = _parley.float_picker.open,
        finder_name = "Vision finder",
        warning = function(failed_roots, failed_records)
            _parley.logger.warning(string.format(
                "Vision finder: partial scan (%d roots, %d files failed)",
                failed_roots,
                failed_records
            ))
        end,
        materialize = function(outcome)
            items = vision_records.materialize_records(outcome.records)
            return {
                items = items,
                title = string.format("Vision (%d initiatives)", #items),
                initial_index = chat_finder_mod.resolve_finder_initial_index(
                    _parley._vision_finder,
                    items,
                    "VisionFinder"
                ),
            }
        end,
        picker_options = {
            title = "Vision",
            recall_key = "parley.vision_finder",
            initial_index = chat_finder_mod.resolve_finder_initial_index(
                _parley._vision_finder,
                items,
                "VisionFinder"
            ),
            initial_query = finder_sticky.format_initial_query(_parley._vision_finder.sticky_query),
            anchor = "bottom",
            on_query_change = function(query)
                _parley._vision_finder.sticky_query = finder_sticky.extract(query, { "root" })
            end,
            on_select = function(item)
                _parley._vision_finder.opened = false
                if source_win and vim.api.nvim_win_is_valid(source_win) then
                    vim.api.nvim_set_current_win(source_win)
                end
                _parley.open_buf(item.value, true)
                if item.line then
                    vim.api.nvim_win_set_cursor(0, { item.line, 0 })
                end
            end,
            on_cancel = function()
                _parley._vision_finder.opened = false
                _parley._vision_finder.initial_index = nil
                _parley._vision_finder.initial_value = nil
            end,
        },
    })
    session:start()
end

return M
