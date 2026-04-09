-- Agent picker module for Parley.nvim
-- Provides a floating window UI for selecting LLM agents

local M = {}

local float_picker = require("parley.float_picker")

-- Build the sorted item list from a plugin state. Exposed for testing.
function M._build_items(plugin)
    local items = {}
    for _, agent_name in ipairs(plugin._agents) do
        local agent = plugin.agents[agent_name]
        local provider = agent.provider or "openai"
        local model_name = type(agent.model) == "table" and agent.model.model or agent.model

        local description = model_name .. " (" .. provider .. ")"
        -- [🔧] badge for agents opting into client-side tool use (M1 Task 1.7
        -- of issue #81). Non-empty agent.tools = agentic agent.
        local tool_badge = (type(agent.tools) == "table" and #agent.tools > 0) and " [🔧]" or ""
        local is_current = agent_name == plugin._state.agent
        local display = (is_current and "✓ " or "  ") .. agent_name .. tool_badge .. " - " .. description

        table.insert(items, {
            name = agent_name,
            display = display,
            is_current = is_current,
        })
    end

    -- Current agent first, then alphabetical
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

-- Create a floating picker to select an LLM agent
function M.agent_picker(plugin)
    local items = M._build_items(plugin)
    local keybindings_key = (plugin.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }).shortcut
    float_picker.open({
        title = "🤖 Parley Agents",
        items = items,
        anchor = "top",
        on_select = function(item)
            plugin.refresh_state({ agent = item.name })
            plugin.logger.info("Agent set to: " .. item.name)
            vim.cmd("doautocmd User ParleyAgentChanged")
        end,
        mappings = {
            {
                key = keybindings_key,
                fn = function(_, _)
                    vim.schedule(function()
                        plugin.cmd.KeyBindings()
                    end)
                end,
            },
        },
    })
end

return M
