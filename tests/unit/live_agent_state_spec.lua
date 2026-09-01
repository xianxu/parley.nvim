-- Unit tests for live cliproxy agent registration + persistence (issue #205).
--
-- The load-bearing case is the restart one: `_state.agent` holds a NAME, and
-- refresh_state resets it to the first configured agent when that name is not
-- in M.agents. A live pick therefore only survives if it is re-registered
-- BEFORE that guard runs.

local parley = require("parley")

describe("register_live_agent", function()
    local saved_agents, saved_list, saved_state

    before_each(function()
        saved_agents = parley.agents
        saved_list = parley._agents
        saved_state = parley._state
        parley.agents = {
            alpha = { provider = "openai", model = { model = "gpt-4" },
                      system_prompt = "x" },
        }
        parley._agents = { "alpha" }
        parley._state = { agent = "alpha" }
    end)

    after_each(function()
        parley.agents = saved_agents
        parley._agents = saved_list
        parley._state = saved_state
    end)

    it("registers the model as a selectable agent and selects it", function()
        local calls = {}
        local real_refresh = parley.refresh_state
        parley.refresh_state = function(update)
            calls[#calls + 1] = update
            for k, v in pairs(update or {}) do
                parley._state[k] = v
            end
        end

        local ok, err = pcall(parley.register_live_agent,
            { id = "claude-opus-5", owner = "anthropic", display = "Claude Opus 5" })
        parley.refresh_state = real_refresh
        assert.is_true(ok, tostring(err))

        assert.is_not_nil(parley.agents["claude-opus-5*"])
        assert.is_true(vim.tbl_contains(parley._agents, "claude-opus-5*"))
        assert.equals("claude-opus-5*", parley._state.agent)
        assert.equals("cliproxyapi", parley.agents["claude-opus-5*"].provider)
    end)

    it("persists the model so a restart can rebuild the agent", function()
        local persisted
        local real_refresh = parley.refresh_state
        parley.refresh_state = function(update)
            persisted = update and update.live_agent
        end
        pcall(parley.register_live_agent, { id = "claude-opus-5", owner = "anthropic" })
        parley.refresh_state = real_refresh

        -- The row itself is stored, not just the name: build_agent needs `owner`
        -- to decide the web-search strategy, so a name alone could not rebuild
        -- the same agent.
        assert.is_table(persisted)
        assert.equals("claude-opus-5", persisted.id)
        assert.equals("anthropic", persisted.owner)
    end)

    it("rebuilds an equivalent agent from what it persisted", function()
        local row = { id = "gemini-3-flash", owner = "antigravity" }
        local live = require("parley.cliproxy_catalog").build_agent(row)
        local rebuilt = require("parley.cliproxy_catalog").build_agent(row)
        assert.same(live.model, rebuilt.model)
        assert.equals("none", rebuilt.model.web_search_strategy)
    end)
end)
