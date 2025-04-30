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
  -- Cache the busy state and only check it when events fire
  local cached_busy_state = false
  local last_check_time = 0
  local check_interval = 1  -- seconds
  
  -- Function to check busy state with caching
  local function check_is_busy(buf)
    local current_time = os.time()
    
    -- Only check actual busy state periodically or when forced by events
    if (current_time - last_check_time) >= check_interval then
      -- Pass skip_warning=true to avoid log spam from UI components
      cached_busy_state = parley.tasker.is_busy(buf, true)
      last_check_time = current_time
    end
    
    return cached_busy_state
  end
  
  -- Create an augroup for our events
  local augroup = vim.api.nvim_create_augroup("ParleyLualineComponent", { clear = true })
  
  -- Force refresh when specific events occur - using direct API call to avoid buffer issues
  vim.api.nvim_create_autocmd({"User"}, {
    pattern = {"ParleyQueryStarted", "ParleyQueryFinished", "ParleyDone"},
    group = augroup,
    callback = function()
      -- Reset cache immediately on these events
      last_check_time = 0
    end
  })
  
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
      
      -- Check if a response is being generated (using cached state)
      local is_busy = check_is_busy(buf)
      
      -- Get provider info and check if it's Anthropic/Claude
      local agent_info = nil
      if parley.get_agent_info then
        -- Get agent info with empty headers since we don't have any here
        agent_info = parley.get_agent_info({}, parley.get_agent(agent_name))
      end
      
      local is_anthropic = agent_info and 
                           (agent_info.provider == "anthropic" or agent_info.provider == "claude")
      
      -- Show agent name with icon (spinner if busy)
      if is_busy then
        return "🔄 " .. agent_name
      else
        -- Display cache metrics for any provider that has them
        local cache_metrics = parley.tasker.get_cache_metrics()
        
        -- Format each metric - use "-" for nil/undefined values or zeros
        local input_display = (cache_metrics.input and cache_metrics.input > 0) and cache_metrics.input or "-"
        local creation_display = (cache_metrics.creation and cache_metrics.creation > 0) and cache_metrics.creation or "-" 
        local read_display = (cache_metrics.read and cache_metrics.read > 0) and cache_metrics.read or "-"
        
        -- Provider-specific formatting
        local agent_info = parley.get_agent_info and parley.get_agent_info({}, parley.get_agent(agent_name))
        if agent_info then
          -- For OpenAI/Copilot, always show creation as "-" (not applicable)
          if agent_info.provider == "openai" or agent_info.provider == "copilot" then
            creation_display = "-"
          end
          
          -- For Google AI/Gemini, always show read and creation as "-" (not applicable)
          if agent_info.provider == "googleai" then
            read_display = "-"
            creation_display = "-"
          end
        end
        
        return "🤖 " .. agent_name .. " [" .. input_display .. "/" .. creation_display .. "/" .. read_display .. "]"
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
      -- Use the same cached busy state for color
      local is_busy = check_is_busy(buf)
      
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
  -- Immediately assign the parley reference
  _parley = parley
  
  -- Defer the lualine setup to ensure Neovim is fully initialized
  vim.defer_fn(function()
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
        
        -- Use a simple approach - just add our component at the start
        table.insert(existing_config.sections[section], parley_component)
        
        -- Refresh lualine with the updated config
        lualine.setup(existing_config)
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
          pcall(function()
            require("lualine").refresh()
          end)
        end
      })
    end)
  end, 100) -- Delay 100ms to ensure all initialization is complete
end

return M
