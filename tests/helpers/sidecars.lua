-- The one list of sidecars under the profile state directory (#261, target
-- transcript-is-the-whole-truth). Each entry names the module that reads it,
-- the file, bodies whose fields hold the wrong type (every field its reader
-- takes, and the first nested level the reader indexes), and how to make that
-- reader read it.
--
-- tests/arch/sidecar_authority_spec.lua checks the readers against the tree;
-- tests/integration/sidecar_degrade_spec.lua writes every body, runs the
-- reader, and submits a chat. A new reader of the state directory belongs here.
return {
    {
        reader = "lua/parley/init.lua",
        file = "state.json",
        wrong_shapes = {
            { updated = "x", agent = 3, system_prompt = 3, web_search = "x", claude_web_search = "x",
              follow_cursor = "x", last_chat = 3, live_agent = 3, note_dirs = 3, note_roots = 3,
              chat_dirs = 3, chat_roots = 3, repo_modes = 3, interview_mode = "x", interview_start_time = "x" },
            { note_roots = { 3 }, note_dirs = { 3 }, live_agent = { id = 3 } },
        },
        exercise = function(parley) parley.refresh_state() end,
    },
    {
        reader = "lua/parley/vault.lua",
        file = "vault_state.json",
        wrong_shapes = {
            { copilot_bearer = 3 },
            { copilot_bearer = { token = 3, expires_at = "x" } },
        },
        exercise = function()
            local vault, tasker = require("parley.vault"), require("parley.tasker")
            local run = tasker.run
            -- The bearer refresh would spawn curl; a refused fetch is enough to
            -- reach every read of the state file.
            tasker.run = function(_, _, _, callback) if callback then callback(1, 0, "", "") end end
            vault._state.copilot_bearer = nil
            vault.add_secret("copilot", "fixture-token")
            local ok, err = pcall(vault.refresh_copilot_bearer, function() end)
            tasker.run = run
            assert(ok, err)
        end,
    },
    {
        reader = "lua/parley/custom_prompts.lua",
        file = "custom_system_prompts.json",
        wrong_shapes = {
            { fixture = 3 },
            { fixture = { system_prompt = 3 } },
        },
        exercise = function()
            local prompts = require("parley.custom_prompts")
            for name, prompt in pairs(prompts.load()) do
                assert(type(prompt) == "table" and type(prompt.system_prompt) == "string",
                    "custom prompt " .. tostring(name) .. " reached a caller malformed")
            end
            prompts.source("fixture", {})
        end,
    },
    {
        reader = "lua/parley/chat_respond.lua",
        file = "remote_reference_cache.json",
        wrong_shapes = {
            { chats = 3 },
            { chats = { fixture = 3 } },
            { chats = { fixture = { ["https://example.com/doc"] = 3 } } },
        },
        exercise = function(parley)
            parley._remote_reference_cache = nil
            local cache = require("parley.chat_respond").get_chat_remote_reference_cache("fixture")
            for url, content in pairs(cache) do
                assert(type(content) == "string", "cached reference " .. tostring(url) .. " is not text")
            end
        end,
    },
}
