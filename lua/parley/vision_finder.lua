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

    -- Build picker items
    local items = {}
    for _, item in ipairs(initiatives) do
        local size_str = item.size and ("[" .. item.size .. "]") or ""
        local type_str = item.type or ""
        local quarter_str = item.quarter or ""
        local ns = item._namespace or ""
        local display = string.format("%s  %s  %s  %s  %s",
            ns, item.name or "?", size_str, type_str, quarter_str)

        local deps = item.depends_on or {}
        if type(deps) == "table" then deps = table.concat(deps, " ") end

        table.insert(items, {
            display = display,
            search_text = string.format("%s %s %s %s %s %s",
                ns, item.name or "", item.type or "", item.size or "",
                item.quarter or "", deps),
            value = item._file,
            line = item._line,
        })
    end

    local source_win = vim.api.nvim_get_current_win()

    local chat_finder_mod = require("parley.chat_finder")

    _parley.float_picker.open({
        title = string.format("Vision (%d initiatives)", #items),
        items = items,
        initial_index = chat_finder_mod.resolve_finder_initial_index(_parley._vision_finder, items, "VisionFinder"),
        anchor = "bottom",
        on_select = function(item)
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
