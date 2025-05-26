-- Test module for agent_picker
-- This is a utility file to test the agent picker implementation

local plugin = require("parley")
local agent_picker = require("parley.agent_picker")

-- Make sure plugin is initialized
if not plugin._setup_called then
  -- A minimal setup to test with
  plugin.setup({})
end

-- Run the agent picker
agent_picker.agent_picker(plugin)

-- Return nothing since we run this file directly with :luafile
return nil