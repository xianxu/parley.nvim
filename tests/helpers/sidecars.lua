-- The one list of sidecars under the profile state directory (#261, target
-- transcript-is-the-whole-truth). Each entry names the module that reads it,
-- the file, bodies whose fields hold the wrong type (every field its reader
-- takes, and the nested levels the reader indexes), how to make that reader
-- read it, and what its writes do with fields the read drops:
--
--   writes = "rewrite"   the file is app-owned state or a cache: a dropped
--                        field is re-derived or refetched, so rewriting the
--                        typed value is the recovery (`why` says which).
--   writes = "preserve"  the user wrote the file: the read filters a VIEW and
--                        the writes keep every entry. `preserve` proves it and
--                        sidecar_degrade_spec runs it (#261 M1 review BR-5).
--
-- tests/arch/sidecar_authority_spec.lua checks the readers against the tree and
-- that every entry declares `writes`; tests/integration/sidecar_degrade_spec.lua
-- writes every body, runs the reader, and submits a chat.
local FakeProcess = require("tests.helpers.fake_process")

return {
    {
        reader = "lua/parley/init.lua",
        file = "state.json",
        writes = "rewrite", why = "app-owned settings; refresh_state persists the typed state",
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
        writes = "rewrite", why = "a cache of a fetched copilot bearer; a dropped token is fetched again",
        wrong_shapes = {
            { copilot_bearer = 3 },
            { copilot_bearer = { token = 3, expires_at = "x" } },
        },
        exercise = function(parley)
            -- A fresh vault instance, so the secret added here does not leak into
            -- the module other specs share; the bearer refresh spawns into the
            -- stateful process fake behind tasker's runtime seam.
            local tasker = require("parley.tasker")
            local shared, runtime = package.loaded["parley.vault"], tasker._uv
            package.loaded["parley.vault"] = nil
            local vault = require("parley.vault")
            tasker._uv = FakeProcess.new()
            local ok, err = pcall(function()
                vault.setup({ state_dir = parley.config.state_dir })
                vault.add_secret("copilot", "fixture-token")
                vault.refresh_copilot_bearer(function() end)
            end)
            tasker._uv = runtime
            package.loaded["parley.vault"] = shared
            assert(ok, err)
        end,
    },
    {
        reader = "lua/parley/custom_prompts.lua",
        file = "custom_system_prompts.json",
        writes = "preserve",
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
        -- A write through the module keeps the entry the view filtered out.
        preserve = function(_, path)
            local before = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
            assert(require("parley.custom_prompts").set("added", { system_prompt = "added" }), "set refused")
            local after = vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
            assert(vim.deep_equal(before.fixture, after.fixture), "a write dropped the user's malformed entry")
        end,
    },
    {
        reader = "lua/parley/chat_respond.lua",
        file = "remote_reference_cache.json",
        writes = "rewrite", why = "a cache of fetched references; a dropped entry is fetched again",
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
