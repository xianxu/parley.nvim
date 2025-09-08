-- System prompt picker module for Parley.nvim
-- Provides a Telescope UI for selecting system prompts

local M = {}

-- Create a Telescope picker to select a system prompt
function M.system_prompt_picker(plugin)
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

  -- Format the system prompts for display
  local system_prompts = {}
  for _, prompt_name in ipairs(plugin._system_prompts) do
    local prompt = plugin.system_prompts[prompt_name]
    
    -- Create a truncated description of the system prompt
    local description = prompt.system_prompt:gsub("\n", " "):gsub("%s+", " ")
    if #description > 80 then
      description = description:sub(1, 80) .. "..."
    end
    
    -- Check if this is the current system prompt
    local is_current = prompt_name == plugin._state.system_prompt
    local display = (is_current and "✓ " or "  ") .. prompt_name .. " - " .. description
    
    table.insert(system_prompts, {
      name = prompt_name,
      display = display,
      system_prompt = prompt.system_prompt,
      is_current = is_current
    })
  end
  
  -- Sort the system prompts alphabetically
  table.sort(system_prompts, function(a, b)
    -- Current system prompt always goes first
    if a.is_current then return true end
    if b.is_current then return false end
    return a.name < b.name
  end)

  -- Create the picker
  pickers.new({}, {
    prompt_title = "💬 Parley System Prompts",
    finder = finders.new_table {
      results = system_prompts,
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
        local prompt_name = selection.value.name
        
        -- Close the picker
        actions.close(prompt_bufnr)
        
        -- Set the selected system prompt
        plugin.refresh_state({ system_prompt = prompt_name })
        plugin.logger.info("System prompt set to: " .. prompt_name)
        vim.cmd("doautocmd User ParleySystemPromptChanged")
      end)
      
      return true
    end,
  }):find()
end

return M