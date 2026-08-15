-- Unit tests for lua/parley/skill_assembly.lua
--
-- The PURE P2 context-assembler. build_invocation turns a skill manifest + the
-- already-sourced body + the artifact document into the LLM-call inputs the M3
-- driver feeds to dispatcher.prepare_payload. resolve_agent is the salvaged
-- agent cascade, made pure by INJECTING its config/registry deps (vs v1 reading
-- the parley module). Both run with no IO and no require("parley").

local assembly = require("parley.skill_assembly")

local function manifest(over)
    return vim.tbl_extend("force", {
        name = "review",
        description = "d",
        scope = "global",
        activation = { manual = true },
        source = function() return "BODY" end,
        tools = { "read_file" },
        elevated = { "propose_edits" },
        force_tool = "propose_edits",
    }, over or {})
end

describe("skill_assembly.build_invocation", function()
    it("builds system+user messages from body + document (no redundant system_prompt field)", function()
        local inv = assembly.build_invocation(manifest(), { body = "BODY", document = "DOC", manual = true })
        -- the body is conveyed AS the role=system message; no separate field
        assert.is_nil(inv.system_prompt)
        assert.are.same({
            { role = "system", content = "BODY" },
            { role = "user", content = "DOC" },
        }, inv.messages)
    end)

    it("grants elevated tools only on a manual invocation", function()
        local m = manifest()
        local manual = assembly.build_invocation(m, { body = "B", document = "D", manual = true })
        assert.is_true(vim.tbl_contains(manual.tools, "read_file"))
        assert.is_true(vim.tbl_contains(manual.tools, "propose_edits")) -- elevated, manual

        local auto = assembly.build_invocation(m, { body = "B", document = "D", manual = false })
        assert.is_true(vim.tbl_contains(auto.tools, "read_file"))
        assert.is_false(vim.tbl_contains(auto.tools, "propose_edits")) -- elevated withheld
    end)

    -- #198: this used to emit Anthropic's {type="tool", name=…} directly.
    -- A forced choice is spelled differently per wire, so the pure assembler
    -- carries the NAME and skill_invoke shapes it once the agent is known.
    it("carries force_tool as a plain name, else nil", function()
        local forced = assembly.build_invocation(manifest(), { body = "B", document = "D", manual = true })
        assert.are.equal("propose_edits", forced.force_tool)
        -- and emphatically NOT a pre-shaped wire table
        assert.is_nil(forced.tool_choice)

        local m = manifest()
        m.force_tool = nil -- (tbl_extend can't drop a key via nil; clear it on the table)
        local none = assembly.build_invocation(m, { body = "B", document = "D", manual = true })
        assert.is_nil(none.force_tool)
    end)
end)

describe("skill_assembly.resolve_agent (pure, injected deps)", function()
    -- deps inject what v1 read from the parley module: config fields + the
    -- agent resolver/registry. No global reads → pure.
    local function deps(over)
        return vim.tbl_extend("force", {
            config = { skills = {}, review_agent = nil, skill_agent = nil },
            get_agent = function(name)
                local known = { A1 = { name = "A1" }, RA = { name = "RA" }, MA = { name = "MA" }, SA = { name = "SA" } }
                return known[name]
            end,
            agent_names = { "x", "y" },
            agents = { x = { provider = "openai" }, y = { provider = "anthropic" } },
        }, over or {})
    end

    it("tier 1: per-skill config override wins", function()
        local d = deps({ config = { skills = { { name = "review", agent = "A1" } } } })
        assert.are.equal("A1", assembly.resolve_agent(manifest(), d).name)
    end)

    it("tier 1b: legacy review_agent for the review skill", function()
        local d = deps({ config = { skills = {}, review_agent = "RA" } })
        assert.are.equal("RA", assembly.resolve_agent(manifest(), d).name)
    end)

    it("tier 2: manifest.agent default", function()
        assert.are.equal("MA", assembly.resolve_agent(manifest({ agent = "MA" }), deps()).name)
    end)

    it("tier 3: global skill_agent", function()
        local d = deps({ config = { skills = {}, skill_agent = "SA" } })
        assert.are.equal("SA", assembly.resolve_agent(manifest({ name = "other" }), d).name)
    end)

    -- #198 widened "tool-capable" from a hardcoded anthropic/cliproxyapi pair
    -- to "has a tool wire". This fixture lists openai FIRST precisely because
    -- it used to be skipped; now it is a legitimate answer.
    it("tier 4: first tool-capable agent, which now includes openai", function()
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), deps()).provider)
    end)

    it("tier 4: skips agents whose provider has no tool wire", function()
        local d = deps({
            agent_names = { "g", "y" },
            agents = {
                g = { provider = "googleai", model = { model = "gemini-3-pro-preview" } },
                y = { provider = "anthropic", model = { model = "claude-sonnet-5" } },
            },
        })
        assert.are.equal("anthropic", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
    end)

    it("tier 4: accepts cliproxyapi on either route", function()
        for _, model in ipairs({
            { model = "gpt-5.6-sol" },
            { model = "claude-opus-4-8", web_search_strategy = "anthropic_tools_route" },
        }) do
            local d = deps({
                agent_names = { "c" },
                agents = { c = { provider = "cliproxyapi", model = model } },
            })
            assert.are.equal("cliproxyapi",
                assembly.resolve_agent(manifest({ name = "other" }), d).provider)
        end
    end)

    it("returns nil when nothing resolves", function()
        local d = deps({ agent_names = {}, agents = {} })
        assert.is_nil(assembly.resolve_agent(manifest({ name = "other" }), d))
    end)

    it("returns nil when no listed agent has a tool wire", function()
        local d = deps({
            agent_names = { "g" },
            agents = { g = { provider = "googleai", model = { model = "gemini-3-pro-preview" } } },
        })
        assert.is_nil(assembly.resolve_agent(manifest({ name = "other" }), d))
    end)
end)
