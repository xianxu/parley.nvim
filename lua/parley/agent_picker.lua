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
        -- Combined [🔧🌎]-style indicator group for tool-enabled agents and
        -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers
        -- so picker, buffer-top extmark, and lualine agree on the badge
        -- string. The `require` itself is NOT pcall-wrapped: a real load
        -- failure in parley.highlighter should surface loudly, not silently
        -- hide the badge. The pcall only guards the `agent_web_search_badge`
        -- state read (_parley._state) which may be nil in isolated unit tests.
        local highlighter = require("parley.highlighter")
        local tool_part = highlighter.agent_tool_badge(agent) or ""
        local ok_ws, web_part = pcall(highlighter.agent_web_search_badge, agent)
        if not ok_ws then web_part = "" end
        local indicators = tool_part .. (web_part or "")
        local indicator_group = (indicators ~= "") and (" [" .. indicators .. "]") or ""
        local is_current = agent_name == plugin._state.agent
        local display = (is_current and "✓ " or "  ") .. agent_name .. indicator_group .. " - " .. description

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
