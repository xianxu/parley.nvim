-- Live cliproxy agent registration + persistence (issue #205).
--
-- The load-bearing case is the RESTART one, and it is driven through the real
-- `refresh_state`: `_state.agent` holds a NAME, and refresh_state resets it to
-- the first configured agent when that name is not in M.agents. A live pick
-- therefore only survives if the restore runs BEFORE that guard.
--
-- An earlier version of this file stubbed refresh_state, so deleting the restore
-- block entirely left the suite green. These call the production path.

local parley = require("parley")

-- A real setup: refresh_state drives the interview timer and the note-root
-- machinery, so a stubbed-out plugin table cannot exercise it. state_dir points
-- at a temp dir so the spec never touches the operator's persisted state.
local SPEC_STATE_DIR = vim.fn.tempname()
vim.fn.mkdir(SPEC_STATE_DIR, "p")
parley.setup({ state_dir = SPEC_STATE_DIR })

-- refresh_state reloads _state FROM DISK, which is exactly what a restart does —
-- so the persisted file is where a restart scenario has to start. Module scope
-- because more than one describe needs a restart.
local function persist(state)
    state.updated = os.time()
    local fd = assert(io.open(SPEC_STATE_DIR .. "/state.json", "w"))
    fd:write(vim.json.encode(state))
    fd:close()
    parley._state = {}
end

describe("live agent state", function()
    local saved = {}

    before_each(function()
        saved.agents = parley.agents
        saved.list = parley._agents
        saved.state = parley._state
        saved.config = parley.config
        parley.agents = {
            alpha = { provider = "openai", model = { model = "gpt-4" }, system_prompt = "x" },
        }
        parley._agents = { "alpha" }
        parley._state = {}
    end)

    after_each(function()
        parley.agents = saved.agents
        parley._agents = saved.list
        parley._state = saved.state
        parley.config = saved.config
        os.remove(SPEC_STATE_DIR .. "/state.json")
    end)

    it("rebuilds the persisted live agent and keeps it selected", function()
        persist({ agent = "claude-opus-5*",
                  live_agent = { id = "claude-opus-5", owner = "anthropic" } })

        parley.refresh_state() -- the real one: restore, then the fallback guard

        assert.equals("claude-opus-5*", parley._state.agent,
            "the live pick was reset to the first configured agent")
        assert.is_not_nil(parley.agents["claude-opus-5*"])
        assert.equals("cliproxyapi", parley.agents["claude-opus-5*"].provider)
        assert.is_true(vim.tbl_contains(parley._agents, "claude-opus-5*"))
    end)

    it("rebuilds it with the strategy its owner implies, not a default", function()
        -- `owner` is why the ROW is persisted rather than the name: an
        -- antigravity-served model resolves differently from the same id
        -- elsewhere, and a name alone could not reproduce it.
        persist({ agent = "gemini-3-flash*",
                  live_agent = { id = "gemini-3-flash", owner = "antigravity" } })

        parley.refresh_state()

        assert.equals("none", parley.agents["gemini-3-flash*"].model.web_search_strategy)
    end)

    it("still falls back when there is no live agent to restore", function()
        persist({ agent = "long-gone*" })
        parley.refresh_state()
        assert.equals("alpha", parley._state.agent)
    end)

    it("survives a corrupt persisted row instead of aborting setup", function()
        persist({ agent = "alpha", live_agent = { owner = "anthropic" } }) -- no id
        assert.has_no.errors(function() parley.refresh_state() end)
        assert.equals("alpha", parley._state.agent)
    end)
end)

describe("register_live_agent", function()
    local saved = {}

    before_each(function()
        saved.agents, saved.list, saved.state, saved.config =
            parley.agents, parley._agents, parley._state, parley.config
        parley.agents = { alpha = { provider = "openai", model = { model = "gpt-4" },
                                    system_prompt = "x" } }
        parley._agents = { "alpha" }
        parley._state = { agent = "alpha" }
    end)

    after_each(function()
        parley.agents, parley._agents, parley._state, parley.config =
            saved.agents, saved.list, saved.state, saved.config
        os.remove(SPEC_STATE_DIR .. "/state.json")
    end)

    it("registers the model, selects it, and persists the row", function()
        parley.register_live_agent({ id = "claude-opus-5", owner = "anthropic",
                                     display = "Claude Opus 5" })
        assert.equals("claude-opus-5*", parley._state.agent)
        assert.is_true(vim.tbl_contains(parley._agents, "claude-opus-5*"))
        -- the ROW, not just the name — build_agent needs `owner`
        assert.equals("anthropic", parley._state.live_agent.owner)
    end)

    it("refuses a row with no usable id instead of raising", function()
        assert.has_no.errors(function()
            parley.register_live_agent({ owner = "anthropic" })
        end)
        assert.equals("alpha", parley._state.agent)
    end)

    it("a live PICK overwrites a same-named agent", function()
        -- BR-109: the two adoption sites had different collision semantics and
        -- collapsing them onto one left nothing able to tell. This pins the
        -- selection half — the user naming a model right now wins.
        parley.agents["claude-opus-5*"] = { provider = "openai", model = { model = "stale" },
                                            system_prompt = "x" }
        parley._agents = { "alpha", "claude-opus-5*" }
        parley.register_live_agent({ id = "claude-opus-5", owner = "anthropic",
                                     display = "Claude Opus 5" })
        assert.equals("cliproxyapi", parley.agents["claude-opus-5*"].provider,
            "selecting a live row must replace a same-named entry, not defer to it")
    end)
end)

describe("restoring a persisted live pick", function()
    local saved = {}

    before_each(function()
        saved.agents, saved.list, saved.state =
            parley.agents, parley._agents, parley._state
    end)

    after_each(function()
        parley.agents, parley._agents, parley._state =
            saved.agents, saved.list, saved.state
        os.remove(SPEC_STATE_DIR .. "/state.json")
    end)

    it("does NOT clobber a configured agent of the same name", function()
        -- The other half of BR-109, and the one that actually bites: setup()
        -- builds M.agents from config and only THEN calls refresh_state, so
        -- overwriting here lets a stale session pick beat the config on every
        -- launch. Config is authoritative.
        parley.agents = { alpha = { provider = "openai", model = { model = "gpt-4" },
                                    system_prompt = "x" },
                          ["claude-opus-5*"] = { provider = "anthropic",
                                                 model = { model = "configured" },
                                                 system_prompt = "x" } }
        parley._agents = { "alpha", "claude-opus-5*" }
        persist({ agent = "alpha", live_agent = { id = "claude-opus-5", owner = "anthropic" } })
        parley.refresh_state()
        assert.equals("anthropic", parley.agents["claude-opus-5*"].provider,
            "a persisted live pick must not overwrite a configured agent")
        assert.equals("configured", parley.agents["claude-opus-5*"].model.model)
    end)
end)

describe("agent_picker._select", function()
    local ap = require("parley.agent_picker")

    local function fake_plugin()
        local calls = { refresh = {}, registered = {}, info = {} }
        return {
            config = { cmd_prefix = "Parley" },
            logger = { info = function(m) table.insert(calls.info, m) end },
            refresh_state = function(u) table.insert(calls.refresh, u) end,
            register_live_agent = function(m) table.insert(calls.registered, m) end,
        }, calls
    end

    it("selects a configured agent by name", function()
        local plugin, calls = fake_plugin()
        ap._select(plugin, { kind = "agent", name = "ToolOpus*" })
        assert.same({ { agent = "ToolOpus*" } }, calls.refresh)
        assert.same({}, calls.registered)
    end)

    it("registers the catalog row behind a live item", function()
        local plugin, calls = fake_plugin()
        local row = { id = "claude-opus-5", owner = "anthropic" }
        ap._select(plugin, { kind = "live", name = "claude-opus-5*", model = row })
        assert.same({ row }, calls.registered)
        assert.same({}, calls.refresh, "a live pick must not also set the agent by name")
    end)

    it("does nothing at all for the separator", function()
        local plugin, calls = fake_plugin()
        ap._select(plugin, { kind = "separator", name = "__live_separator__" })
        assert.same({}, calls.refresh)
        assert.same({}, calls.registered)
    end)

    it("starts a login for a logged-out provider", function()
        local plugin, calls = fake_plugin()
        local ran = {}
        local real_cmd = vim.cmd
        vim.cmd = function(c) table.insert(ran, c) end
        ap._select(plugin, { kind = "login", provider = "antigravity" })
        vim.wait(200, function() return #ran > 0 end)
        vim.cmd = real_cmd
        assert.same({ "ParleyProxy login antigravity" }, ran)
        assert.same({}, calls.refresh)
    end)
end)

describe("keybinding_registry.key_for", function()
    local kr = require("parley.keybinding_registry")

    it("returns the registered default for the picker's expand key", function()
        assert.equals("<C-a>", kr.key_for("ap_expand_catalog", {}))
    end)

    it("honors a config override", function()
        assert.equals("<C-x>", kr.key_for("ap_expand_catalog",
            { agent_picker_mappings = { expand_catalog = { shortcut = "<C-x>" } } }))
    end)

    it("returns nil for an id nothing registers", function()
        assert.is_nil(kr.key_for("no_such_binding_id", {}))
    end)
end)
