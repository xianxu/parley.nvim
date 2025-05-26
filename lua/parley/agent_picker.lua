-- Agent picker module for Parley.nvim
-- Provides a Telescope UI for selecting LLM agents

local M = {}

-- Create a Telescope picker to select an LLM agent
function M.agent_picker(plugin)
  -- Check if telescope is available
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope is required for this feature", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  -- Format the agents for display
  local agents = {}
  for _, agent_name in ipairs(plugin._agents) do
    local agent = plugin.agents[agent_name]
    local provider = agent.provider or "openai"
    local model_name = type(agent.model) == "table" and agent.model.model or agent.model
    
    -- Create a description that includes the model and provider
    local description = model_name .. " (" .. provider .. ")"
    
    -- Check if this is the current agent
    local is_current = agent_name == plugin._state.agent
    local display = (is_current and "✓ " or "  ") .. agent_name .. " - " .. description
    
    table.insert(agents, {
      name = agent_name,
      display = display,
      provider = provider,
      model = model_name,
      is_current = is_current
    })
  end
  
  -- Sort the agents alphabetically
  table.sort(agents, function(a, b)
    -- Current agent always goes first
    if a.is_current then return true end
    if b.is_current then return false end
    return a.name < b.name
  end)

  -- Create the picker
  pickers.new({}, {
    prompt_title = "🤖 Parley Agents",
    finder = finders.new_table {
      results = agents,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.name,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        -- Get the selected entry
        local selection = action_state.get_selected_entry()
        local agent_name = selection.value.name
        
        -- Close the picker
        actions.close(prompt_bufnr)
        
        -- Set the selected agent
        plugin.refresh_state({ agent = agent_name })
        plugin.logger.info("Agent set to: " .. agent_name)
        vim.cmd("doautocmd User ParleyAgentChanged")
      end)
      
      return true
    end,
  }):find()
end

return M