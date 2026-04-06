-- Vision finder module for Parley
-- Float picker UI for browsing initiatives across vision YAML files

local vision_mod = require("parley.vision")

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

    local dir = vision_mod.get_vision_dir()
    if not dir then
        _parley.logger.warning("vision_dir is not configured")
        _parley._vision_finder.opened = false
        return
    end

    local initiatives = vision_mod.load_vision_dir(dir)

    -- Build picker items (projects only — skip persons and settings)
    local items = {}
    for _, item in ipairs(initiatives) do
        if not item.project or item.project == "" then goto continue end
        local size_str = item.size and ("[" .. item.size .. "]") or ""
        local type_str = item.type or ""
        local need_by_str = type(item.need_by) == "string" and item.need_by or ""
        local ns = item._namespace or ""
        local clean_name = vision_mod.parse_priority(item.project or "?")
        local display = string.format("%s  %s  %s  %s  %s",
            ns, clean_name, size_str, type_str, need_by_str)

        local deps = item.depends_on or {}
        if type(deps) == "table" then deps = table.concat(deps, " ") end

        table.insert(items, {
            display = display,
            search_text = string.format("%s %s %s %s %s %s",
                ns, clean_name, item.type or "", item.size or "",
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
        anchor = "bottom",
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
