-- Parley - A Neovim LLM Chat Plugin
-- https://github.com/xianxu/parley.nvim/
-- Lualine integration

local M = {}

-- Notes folder detection and formatting
M.format_directory = function(parley_instance)
  local cwd = vim.fn.getcwd()
  local home = vim.env.HOME
  local notes_path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/notes"
  
  -- Try to get parley instance from multiple sources
  local parley = parley_instance or _parley
  if not parley then
    local ok, parley_module = pcall(require, "parley")
    if ok then
      parley = parley_module
    end
  end
  
  -- Priority 1: If interview mode is active, always show INTERVIEW with timer
  if parley and parley._state and parley._state.interview_mode and parley._state.interview_start_time then
    local elapsed = os.time() - parley._state.interview_start_time
    local minutes = math.floor(elapsed / 60)
    local timer_text = string.format(":%02dMIN", minutes)
    return " INTERVIEW " .. timer_text
  end
  
  -- Priority 2: If in notes folder, show NOTE
  if cwd:sub(1, #notes_path) == notes_path then
    return " NOTE"
  end
  
  -- Priority 3: Default behavior - show current directory
  if cwd:sub(1, #home) == home then
    cwd = "~" .. cwd:sub(#home + 1)
  end
  return " " .. cwd
end

-- Directory color function
M.get_directory_color = function(parley_instance)
  local cwd = vim.fn.getcwd()
  local home = vim.env.HOME
  local notes_path = home .. "/Library/Mobile Documents/com~apple~CloudDocs/notes"
  
  -- Try to get parley instance from multiple sources
  local parley = parley_instance or _parley
  if not parley then
    local ok, parley_module = pcall(require, "parley")
    if ok then
      parley = parley_module
    end
  end
  
  -- Priority 1: Interview mode gets red color regardless of location
  if parley and parley._state and parley._state.interview_mode then
    return { fg = '#ff6b6b', gui = 'bold' }  -- Red color for interview mode
  end
  
  -- Priority 2: Notes folder gets cyan color
  if cwd:sub(1, #notes_path) == notes_path then
    return { fg = '#61dafb', gui = 'bold' }  -- Cyan color for note mode
  end
  
  -- Priority 3: Default color for other folders
  return nil
end

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
    if not has_lualine then
      return
    end
    
    -- Create the parley component if lualine integration is enabled
    local parley_component = nil
    if config.lualine and config.lualine.enable then
      parley_component = M.create_component(parley)
    end

    pcall(function()
      -- Get existing lualine config
      local has_config, existing_config = pcall(function() return lualine.get_config() end)
      
      if not has_config or not existing_config then
        -- Lualine hasn't been set up yet, just add parley component if enabled
        if parley_component then
          local section = config.lualine.section or "lualine_z"
          local lualine_config = {
            sections = {
              [section] = { parley_component }
            }
          }
          lualine.setup(lualine_config)
        end
        return
      end
      
      -- Make sure we have a valid config object
      existing_config = existing_config or {}
      existing_config.sections = existing_config.sections or {}
      
      -- Enhance existing directory components with notes detection
      for section_name, section_components in pairs(existing_config.sections) do
        if type(section_components) == "table" then
          for i, component in ipairs(section_components) do
            -- Look for directory display functions
            if type(component) == "table" and type(component[1]) == "function" then
              local func = component[1]
              local func_str = string.dump(func)
              
              -- Check if this looks like a directory display function
              if func_str:find("getcwd") and func_str:find("HOME") then
                -- Replace with our enhanced version, pass parley instance
                existing_config.sections[section_name][i] = {
                  function()
                    return M.format_directory(parley)
                  end,
                  color = function()
                    return M.get_directory_color(parley)
                  end
                }
              end
            end
          end
        end
      end
      
      -- Add parley component if enabled
      if parley_component then
        local section = config.lualine.section or "lualine_z"
        -- Create section if it doesn't exist
        if not existing_config.sections[section] then
          existing_config.sections[section] = {}
        end
        table.insert(existing_config.sections[section], parley_component)
      end
      
      -- Refresh lualine with the updated config
      lualine.setup(existing_config)
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
