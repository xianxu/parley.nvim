-- Floating full-colorscheme picker with non-persistent live preview.
local M = {}

local theme = require("parley.theme")

local function item_index(items, id)
    for index, item in ipairs(items) do
        if item.value == id then return index end
    end
    return 1
end

local function apply(parley, id)
    local ok, result = theme.apply(id, {
        on_applied = function()
            parley.setup_highlight()
        end,
    })
    if not ok then
        vim.notify("Parley theme could not load: " .. tostring(result), vim.log.levels.WARN)
    end
    return ok
end

function M.open(parley)
    local saved_id = theme.load(parley.config.state_dir)
    local opening = theme.snapshot()
    local opening_scheme = opening.colorscheme
    local opening_onedark = opening.onedark_config
    local specs = theme.items()
    local items = {}
    for _, spec in ipairs(specs) do
        items[#items + 1] = {
            display = spec.label,
            search_text = spec.label .. " " .. spec.id,
            value = spec.id,
        }
    end

    local initial_id = saved_id or "startup"
    for _, spec in ipairs(specs) do
        if spec.colorscheme == opening_scheme
            and (not spec.variant or spec.variant == (opening_onedark or {}).style) then
            initial_id = spec.id
            break
        end
    end

    local function restore()
        local ok = theme.restore(opening)
        if ok then parley.setup_highlight() end
    end

    return parley.float_picker.open({
        title = "Parley Themes",
        items = items,
        initial_index = item_index(items, initial_id),
        recall_key = "parley.theme_picker",
        on_selection_change = function(item)
            apply(parley, item.value)
        end,
        on_select = function(item)
            if apply(parley, item.value) then
                local saved, err = theme.save(parley.config.state_dir, item.value, parley.helpers)
                if not saved then
                    restore()
                    vim.notify("Parley theme preference was not saved: " .. tostring(err), vim.log.levels.WARN)
                end
            else
                restore()
            end
        end,
        on_cancel = restore,
    })
end

return M
