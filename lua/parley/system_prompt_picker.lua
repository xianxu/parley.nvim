-- System prompt picker module for Parley.nvim
-- Provides a floating window UI for selecting system prompts

local M = {}

local float_picker = require("parley.float_picker")

-- Build the sorted item list from a plugin state. Exposed for testing.
function M._build_items(plugin)
    local items = {}
    for _, prompt_name in ipairs(plugin._system_prompts) do
        local prompt = plugin.system_prompts[prompt_name]

        local description = prompt.system_prompt:gsub("\n", " "):gsub("%s+", " ")
        if #description > 80 then
            description = description:sub(1, 80) .. "..."
        end

        local is_current = prompt_name == plugin._state.system_prompt
        local display = (is_current and "✓ " or "  ") .. prompt_name .. " - " .. description

        table.insert(items, {
            name = prompt_name,
            display = display,
            is_current = is_current,
        })
    end

    -- Current prompt first, then alphabetical
    table.sort(items, function(a, b)
        if a.is_current then
            return true
        end
        if b.is_current then
            return false
        end
        return a.name < b.name
    end)

    return items
end

-- Create a floating picker to select a system prompt
function M.system_prompt_picker(plugin)
    local items = M._build_items(plugin)
    float_picker.open({
        title = "💬 Parley System Prompts",
        items = items,
        anchor = "top",
        on_select = function(item)
            plugin.refresh_state({ system_prompt = item.name })
            plugin.logger.info("System prompt set to: " .. item.name)
            vim.cmd("doautocmd User ParleySystemPromptChanged")
        end,
    })
end

return M
