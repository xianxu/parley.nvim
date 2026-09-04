-- parley.skill_assembly — the PURE P2 (artifact-mode) context-assembler.
--
-- build_invocation turns a skill manifest + the already-sourced body + the
-- artifact document into the LLM-call inputs the thin M3 driver feeds to
-- dispatcher.prepare_payload. resolve_agent is the agent cascade salvaged from
-- skill_runner, made PURE by INJECTING its config + agent-registry deps (v1 read
-- the parley module directly). The driver supplies `body` (the source() result)
-- and the agent deps at the boundary.
--
-- One ambient read remains (#198): resolve_agent's tool-capable test calls
-- wire.resolve, which for cliproxyapi reaches providers.cliproxy_strategy and
-- thus module-global config for the web_search_strategy fallback. Outcome-
-- neutral today — cliproxyapi resolves to SOME wire either way — but it is a
-- real dependency, so this file is not the pure island the rest of it is.

local M = {}

--- Build the LLM-call inputs for invoking a skill on an artifact.
--- The skill body is conveyed AS the `role="system"` message (the provider
--- adapter extracts it into the top-level `system`, per parley convention) — so
--- there is NO separate `system_prompt` field (that would double-apply).
--- @param manifest table SkillManifest
--- @param opts table { body = string, document = string, manual = boolean? }
--- @return table { messages, tools, force_tool }
function M.build_invocation(manifest, opts)
    opts = opts or {}
    local body = opts.body or ""

    -- tools granted whenever invoked; elevated granted only on MANUAL invocation
    -- (the #129 hook — manual-only elevation).
    local tools = {}
    for _, t in ipairs(manifest.tools or {}) do
        table.insert(tools, t)
    end
    if opts.manual then
        for _, t in ipairs(manifest.elevated or {}) do
            table.insert(tools, t)
        end
    end

    -- Carry the tool NAME, not a wire shape (#198). Anthropic spells a forced
    -- choice `{type="tool", name=…}` and OpenAI `{type="function",
    -- function={name=…}}`; that is wire knowledge, and this module is pure and
    -- provider-agnostic. skill_invoke encodes it through the wire registry at
    -- payload time, once the agent — and therefore the wire — is known.
    return {
        messages = {
            { role = "system", content = body },
            { role = "user", content = opts.document or "" },
        },
        tools = tools,
        force_tool = manifest.force_tool,
    }
end

--- Resolve the agent for a skill via the salvaged cascade. PURE given `deps`:
---   deps.config        = { skills = {...}, review_agent = name?, skill_agent = name? }
---   deps.get_agent     = function(name) -> agent   (NEVER nil; see note below)
---   deps.agent_names   = ordered list of agent names (for the tool-capable scan)
---   deps.agents        = name -> agent table
---   deps.current_agent = the agent the BUFFER is using — the selection with the
---                        chat's provider:/model: header overrides applied. The
---                        IO shell computes it (skill_invoke); this stays pure.
---
--- Cascade: per-skill config → legacy review_agent → manifest default →
--- global skill_agent → CURRENT TRANSCRIPT AGENT → first tool-capable.
--- Tiers are numbered 1..6 here, in the atlas, and in the issue Spec — one scheme.
---
--- #215. Two things this function used to get wrong:
---
---  1. It treated `get_agent` as a lookup that returns nil on a miss. Production
---     (`init.lua:4405-4451`) never returns nil — an unknown name warns and
---     falls back to `M._state.agent`. So a stale `config.skill_agent` did not
---     "fall through"; it silently resolved to the selection and made the roster
---     scan below unreachable. Nilling those defaults (`config.lua`) is what
---     makes the transcript tier observable at all.
---  2. Only the roster scan tested tool capability. Every earlier tier returned
---     `get_agent`'s result unvetted, so an agent with no tool wire could reach
---     a skill whose entire purpose is its tool — surfacing as the maximally
---     unhelpful "model returned no tool call". One predicate now guards them all.
--- @param manifest table SkillManifest
--- @param deps table injected config + agent registry
--- @return table|nil agent
function M.resolve_agent(manifest, deps)
    local config = deps.config or {}
    local get_agent = deps.get_agent or function() return nil end
    local wire = require("parley.tools.wire")

    -- A skill cannot do its job through an agent that cannot call tools, so a
    -- wireless agent is not an answer at ANY tier — better to keep descending
    -- than to hand `define` an agent that can never emit `emit_definition`.
    local function capable(agent)
        if not agent then return nil end
        if wire.resolve(agent.provider, agent.model) == nil then return nil end
        return agent
    end

    -- 1: per-skill config override
    for _, cfg in ipairs(config.skills or {}) do
        if cfg.name == manifest.name and cfg.agent then
            local agent = capable(get_agent(cfg.agent))
            if agent then return agent end
        end
    end

    -- 2: legacy review_agent fallback (review skill only)
    if manifest.name == "review" and config.review_agent then
        local agent = capable(get_agent(config.review_agent))
        if agent then return agent end
    end

    -- 3: manifest default
    if manifest.agent then
        local agent = capable(get_agent(manifest.agent))
        if agent then return agent end
    end

    -- 4: global skill_agent config. Nil by default since #215 — when it IS set
    -- the user asked for it explicitly, so it still outranks the transcript.
    if config.skill_agent then
        local agent = capable(get_agent(config.skill_agent))
        if agent then return agent end
    end

    -- 5: the agent this buffer is actually talking to. Ambient context beats
    -- roster position: defining a term inside a chat pinned to one model should
    -- not silently answer from another.
    local current = capable(deps.current_agent)
    if current then return current end

    -- 6: first tool-capable agent. "Tool-capable" is now "has a tool wire"
    -- rather than a hardcoded provider pair (#198) — openai, copilot, azure
    -- and ollama qualify too. cliproxyapi resolves on either route, so the
    -- model matters only for picking WHICH wire, not whether one exists.
    for _, name in ipairs(deps.agent_names or {}) do
        local agent = capable((deps.agents or {})[name])
        if agent then return agent end
    end

    return nil
end

return M
