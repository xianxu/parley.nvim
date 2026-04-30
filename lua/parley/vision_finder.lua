-- Vision finder module for Parley
-- Float picker UI for browsing initiatives across vision YAML files

local vision_mod = require("parley.vision")
local finder_sticky = require("parley.finder_sticky")

local M = {}
local _parley

M.setup = function(parley)
    _parley = parley
end

M.open = function()
    if _parley._vision_finder.opened then
        _parley.logger.warning("Vision finder is already open")
        return
    end
    _parley._vision_finder.opened = true

    -- Compute vision roots: in super-repo mode, one per member; else just the single repo.
    local sr_vision = _parley.super_repo and _parley.super_repo.expand_roots(_parley.config.vision_dir) or nil
    local roots = sr_vision or { { dir = vision_mod.get_vision_dir(), repo_name = nil } }
    if #roots == 0 or not roots[1].dir then
        _parley.logger.warning("vision_dir is not configured")
        _parley._vision_finder.opened = false
        return
    end

    -- Aggregate initiatives across roots, tagging each with its repo_name.
    local initiatives = {}
    for _, root in ipairs(roots) do
        if root.dir and vim.fn.isdirectory(root.dir) == 1 then
            local got = vision_mod.load_vision_dir(root.dir)
            for _, item in ipairs(got) do
                item._repo_name = root.repo_name
                table.insert(initiatives, item)
            end
        end
    end

    -- Build picker items (projects only — skip persons and settings)
    local items = {}
    for _, item in ipairs(initiatives) do
        if not item.project or item.project == "" then goto continue end
        local size_str = item.size and ("[" .. item.size .. "]") or ""
        local type_str = item.type or ""
        local need_by_str = type(item.need_by) == "string" and item.need_by or ""
        local ns = item._namespace or ""
        local clean_name = vision_mod.parse_priority(item.project or "?")
        local repo_prefix = item._repo_name and ("{" .. item._repo_name .. "} ") or ""
        local display = string.format("%s%s  %s  %s  %s  %s",
            repo_prefix, ns, clean_name, size_str, type_str, need_by_str)

        local deps = item.depends_on or {}
        if type(deps) == "table" then deps = table.concat(deps, " ") end

        table.insert(items, {
            display = display,
            search_text = string.format("%s%s %s %s %s %s %s",
                repo_prefix, ns, clean_name, item.type or "", item.size or "",
                type(item.need_by) == "string" and item.need_by or "", deps),
            value = item._file,
            line = item._line,
        })
        ::continue::
    end

    local source_win = vim.api.nvim_get_current_win()

    local chat_finder_mod = require("parley.chat_finder")

    _parley.float_picker.open({
        title = string.format("Vision (%d initiatives)", #items),
        items = items,
        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._vision_finder, items, "VisionFinder"),
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
    })
end

return M
