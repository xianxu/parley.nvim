-- parley.skill_assembly — the PURE P2 (artifact-mode) context-assembler.
--
-- build_invocation turns a skill manifest + the already-sourced body + the
-- artifact document into the LLM-call inputs the thin M3 driver feeds to
-- dispatcher.prepare_payload. resolve_agent is the agent cascade salvaged from
-- skill_runner, made PURE by INJECTING its config + agent-registry deps (v1 read
-- the parley module directly). No IO, no require("parley") here — the driver
-- supplies `body` (the source() result) and the agent deps at the boundary.

local M = {}

--- Build the LLM-call inputs for invoking a skill on an artifact.
--- The skill body is conveyed AS the `role="system"` message (the provider
--- adapter extracts it into the top-level `system`, per parley convention) — so
--- there is NO separate `system_prompt` field (that would double-apply).
--- @param manifest table SkillManifest
--- @param opts table { body = string, document = string, manual = boolean? }
--- @return table { messages, tools, tool_choice }
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

    local tool_choice = nil
    if manifest.force_tool then
        tool_choice = { type = "tool", name = manifest.force_tool }
    end

    return {
        messages = {
            { role = "system", content = body },
            { role = "user", content = opts.document or "" },
        },
        tools = tools,
        tool_choice = tool_choice,
    }
end

--- Resolve the agent for a skill via the salvaged cascade. PURE given `deps`:
---   deps.config       = { skills = {...}, review_agent = name?, skill_agent = name? }
---   deps.get_agent    = function(name) -> agent|nil
---   deps.agent_names  = ordered list of agent names (for the tool-capable scan)
---   deps.agents       = name -> agent table
--- Cascade: per-skill config → legacy review_agent → manifest default →
--- global skill_agent → first tool-capable (anthropic|cliproxyapi).
--- @param manifest table SkillManifest
--- @param deps table injected config + agent registry
--- @return table|nil agent
function M.resolve_agent(manifest, deps)
    local config = deps.config or {}
    local get_agent = deps.get_agent or function() return nil end

    -- 1: per-skill config override
    for _, cfg in ipairs(config.skills or {}) do
        if cfg.name == manifest.name and cfg.agent then
            local agent = get_agent(cfg.agent)
            if agent then return agent end
        end
    end

    -- 1b: legacy review_agent fallback (review skill only)
    if manifest.name == "review" and config.review_agent then
        local agent = get_agent(config.review_agent)
        if agent then return agent end
    end

    -- 2: manifest default
    if manifest.agent then
        local agent = get_agent(manifest.agent)
        if agent then return agent end
    end

    -- 3: global skill_agent config
    if config.skill_agent then
        local agent = get_agent(config.skill_agent)
        if agent then return agent end
    end

    -- 4: first tool-capable agent
    for _, name in ipairs(deps.agent_names or {}) do
        local agent = (deps.agents or {})[name]
        if agent and (agent.provider == "anthropic" or agent.provider == "cliproxyapi") then
            return agent
        end
    end

    return nil
end

return M
