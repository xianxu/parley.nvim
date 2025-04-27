-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- Lualine integration

local M = {}

-- Store the parley reference for external component access
local _parley = nil

-- Create a component generator that can be used externally or internally
M.create_component = function(parley_instance)
  local parley = parley_instance or _parley
  
  -- If no parley instance is available, return a placeholder
  if not parley then
    return {
      function() return "Parley not initialized" end,
      cond = function() return false end
    }
  end
  
  local not_chat = parley.not_chat
  
  -- Define the parley component
  return {
    function()
      -- Check if current buffer is a chat
      local buf = vim.api.nvim_get_current_buf()
      local file_name = vim.api.nvim_buf_get_name(buf)
      
      if not_chat(buf, file_name) then
        return ""
      end

      -- Get current agent
      local agent_name = parley._state.agent or ""
      
      -- Check if a response is being generated
      local is_busy = parley.tasker.is_busy(buf)
      
      -- Show agent name with icon (spinner if busy)
      if is_busy then
        return "🔄 " .. agent_name
      else
        return "🤖 " .. agent_name
      end
    end,
    
    -- Component options
    cond = function()
      -- Only show in chat buffers
      local buf = vim.api.nvim_get_current_buf()
      local file_name = vim.api.nvim_buf_get_name(buf)
      return not_chat(buf, file_name) == nil
    end,
    
    -- Use the hint highlight group for consistency with the in-buffer display
    color = function()
      local buf = vim.api.nvim_get_current_buf()
      local is_busy = parley.tasker.is_busy(buf)
      
      -- Use highlight group names without explicitly specifying fg
      -- This lets lualine handle the color extraction properly
      if is_busy then
        return "DiagnosticInfo"
      else
        return "DiagnosticHint"
      end
    end
  }
end

function M.setup(parley)
  -- Store the parley reference for external component access
  _parley = parley
  
  local config = parley.config

  -- Check if lualine is available
  local has_lualine, lualine = pcall(require, "lualine")
  if not has_lualine or not config.lualine or not config.lualine.enable then
    return
  end
  
  -- Create the component
  local parley_component = M.create_component(parley)

  -- Register component with lualine
  -- Get the section from config or default to lualine_z
  local section = config.lualine.section or "lualine_z"
  
  pcall(function()
    -- Add component to the lualine config
    -- Check if lualine.get_config() exists and use it carefully
    local has_config, existing_config = pcall(function() return lualine.get_config() end)
    
    if not has_config or not existing_config then
      -- Lualine hasn't been set up yet, create a minimal config
      local lualine_config = {
        sections = {
          [section] = { parley_component }
        }
      }
      lualine.setup(lualine_config)
    else
      -- Make sure we have a valid config object
      existing_config = existing_config or {}
      existing_config.sections = existing_config.sections or {}
      
      -- Create section if it doesn't exist
      if not existing_config.sections[section] then
        existing_config.sections[section] = {}
      end
      
      -- Check if our component is already added (to avoid duplicates)
      local already_added = false
      for _, component in ipairs(existing_config.sections[section]) do
        if component == parley_component then
          already_added = true
          break
        end
      end
      
      -- Add our component if it's not already there
      if not already_added then
		table.insert(existing_config.sections[section], 1, parley_component)
        -- table.insert(existing_config.sections[section], parley_component)
      end
      
      -- Refresh lualine with the updated config
      pcall(function() lualine.setup(existing_config) end)
    end
  end)
  
  -- Set up autocommands to refresh lualine when agent changes or a query starts/stops
  pcall(function()
    local augroup = vim.api.nvim_create_augroup("ParleyLualine", { clear = true })
    
    -- Refresh lualine when the user switches agents
    vim.api.nvim_create_autocmd("User", {
      pattern = "ParleyAgentChanged",
      group = augroup,
      callback = function()
        -- Force lualine to redraw
        pcall(function()
          require("lualine").refresh()
        end)
      end
    })
    
    -- Refresh lualine when a query starts/finishes
    vim.api.nvim_create_autocmd({"User"}, {
      pattern = {"ParleyQueryStarted", "ParleyQueryFinished", "ParleyDone"},
      group = augroup,
      callback = function()
        -- Force lualine to redraw
        pcall(function()
          require("lualine").refresh()
        end)
      end
    })
  end)
end

return M
