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
    -- The get_agent double MUST mirror production (init.lua:4405-4451), which
    -- NEVER returns nil: an unknown name logs a warning and falls back to
    -- M._state.agent (the live <C-g>a selection); it only error()s on an empty
    -- roster. A strict-lookup double is the INVERSE of that, and every tier
    -- assertion below would pass green over behavior the real cascade does not
    -- have — tier 3 in particular can never fall through in production. #215.
    local SELECTION = { name = "SEL", provider = "cliproxyapi", model = { model = "claude-opus-5" } }
    local function deps(over)
        return vim.tbl_extend("force", {
            config = { skills = {}, review_agent = nil, skill_agent = nil },
            get_agent = function(name)
                -- Every fixture agent carries a provider+model, because every
                -- REAL agent does (init.lua:4405-4451 builds them from
                -- agent_rec). Bare {name=…} stubs passed only while capability
                -- was tested on the roster scan alone; #215 tests it at every
                -- tier, and a provider-less stub is not a shape production can
                -- produce.
                local function A(n)
                    return { name = n, provider = "anthropic", model = { model = "claude-opus-5" } }
                end
                local known = { A1 = A("A1"), RA = A("RA"), MA = A("MA"), SA = A("SA") }
                -- unknown name → the selection, exactly as production does
                return known[name] or SELECTION
            end,
            agent_names = { "x", "y" },
            agents = { x = { provider = "openai" }, y = { provider = "anthropic" } },
        }, over or {})
    end

    it("tier 1: per-skill config override wins", function()
        local d = deps({ config = { skills = { { name = "review", agent = "A1" } } } })
        assert.are.equal("A1", assembly.resolve_agent(manifest(), d).name)
    end)

    it("tier 2: legacy review_agent for the review skill", function()
        local d = deps({ config = { skills = {}, review_agent = "RA" } })
        assert.are.equal("RA", assembly.resolve_agent(manifest(), d).name)
    end)

    it("tier 3: manifest.agent default", function()
        assert.are.equal("MA", assembly.resolve_agent(manifest({ agent = "MA" }), deps()).name)
    end)

    it("tier 4: global skill_agent", function()
        local d = deps({ config = { skills = {}, skill_agent = "SA" } })
        assert.are.equal("SA", assembly.resolve_agent(manifest({ name = "other" }), d).name)
    end)

    -- #215: the transcript tier. Sits BELOW explicit config (a user who sets
    -- skill_agent still gets it) and ABOVE the roster scan, so the default path
    -- follows the conversation instead of roster position.
    local TRANSCRIPT = { name = "TR", provider = "anthropic", model = { model = "claude-opus-5" } }

    it("tier 5: the transcript agent, when no config tier claims the turn", function()
        local d = deps({ current_agent = TRANSCRIPT })
        assert.are.equal("TR", assembly.resolve_agent(manifest({ name = "other" }), d).name)
    end)

    it("tier 5: explicit skill_agent still OUTRANKS the transcript", function()
        local d = deps({ config = { skills = {}, skill_agent = "SA" }, current_agent = TRANSCRIPT })
        assert.are.equal("SA", assembly.resolve_agent(manifest({ name = "other" }), d).name)
    end)

    it("tier 5: a per-skill override still outranks the transcript", function()
        local d = deps({
            config = { skills = { { name = "other", agent = "A1" } } },
            current_agent = TRANSCRIPT,
        })
        assert.are.equal("A1", assembly.resolve_agent(manifest({ name = "other" }), d).name)
    end)

    -- The transcript is ambient, not asked-for: a chat pinned to a provider with
    -- no tool wire must not hand `define` an agent that can never call
    -- emit_definition. Descend to the roster instead.
    it("tier 5: a wireless transcript agent falls through to the roster scan", function()
        local d = deps({
            current_agent = { name = "TR", provider = "googleai", model = { model = "gemini-3-pro-preview" } },
        })
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
    end)

    -- #215: capability is now tested at EVERY tier, not only the roster scan.
    -- Before this, a configured-but-wireless agent was returned unvetted and
    -- surfaced as "model returned no tool call" at the far end of the request.
    it("capability is enforced on the configured tiers too, not just the scan", function()
        -- The override must honour the SAME never-nil contract the shared deps()
        -- helper encodes; hand-rolling `... or nil` here would reintroduce the
        -- very inversion this file corrected a few lines above. Unknown names
        -- fall back to the selection, exactly as production does.
        local wireless = { name = "SA", provider = "googleai", model = { model = "gemini-3-pro-preview" } }
        local d = deps({
            config = { skills = {}, skill_agent = "SA" },
            get_agent = function(name)
                if name == "SA" then return wireless end
                return SELECTION
            end,
        })
        -- falls past the wireless skill_agent, lands on the roster's openai
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
    end)

    -- #215 round 2: dropping a user-configured agent must not be silent.
    it("reports a dropped agent for a CONFIGURED tier", function()
        local wireless = { name = "SA", provider = "googleai", model = { model = "gemini-3-pro-preview" } }
        local seen = {}
        local d = deps({
            config = { skills = {}, skill_agent = "SA" },
            get_agent = function(name)
                if name == "SA" then return wireless end
                return SELECTION
            end,
            on_dropped = function(source, agent) table.insert(seen, source .. ":" .. agent.provider) end,
        })
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
        assert.are.same({ "skill_agent=SA:googleai" }, seen)
    end)

    -- Ambient tiers stay quiet: nobody asked for the transcript or the roster.
    it("stays silent when the dropped agent is the AMBIENT transcript", function()
        local seen = {}
        local d = deps({
            current_agent = { name = "TR", provider = "googleai", model = { model = "gemini-3-pro-preview" } },
            on_dropped = function(source, agent) table.insert(seen, source .. ":" .. agent.provider) end,
        })
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
        assert.are.same({}, seen)
    end)

    -- BR-3: the transcript tier costs a buffer read + header parse, so the shell
    -- passes a thunk. It must not be called when an earlier tier wins.
    it("does not evaluate the transcript thunk when an earlier tier wins", function()
        local calls = 0
        local d = deps({
            config = { skills = {}, skill_agent = "SA" },
            current_agent = function() calls = calls + 1; return nil end,
        })
        assert.are.equal("SA", assembly.resolve_agent(manifest({ name = "other" }), d).name)
        assert.are.equal(0, calls)
    end)

    it("evaluates the transcript thunk when it is the tier that answers", function()
        local calls = 0
        local d = deps({
            current_agent = function()
                calls = calls + 1
                return { name = "TR", provider = "anthropic", model = { model = "claude-opus-5" } }
            end,
        })
        assert.are.equal("TR", assembly.resolve_agent(manifest({ name = "other" }), d).name)
        assert.are.equal(1, calls)
    end)

    -- #198 widened "tool-capable" from a hardcoded anthropic/cliproxyapi pair
    -- to "has a tool wire". This fixture lists openai FIRST precisely because
    -- it used to be skipped; now it is a legitimate answer.
    it("tier 6: first tool-capable agent, which now includes openai", function()
        assert.are.equal("openai", assembly.resolve_agent(manifest({ name = "other" }), deps()).provider)
    end)

    it("tier 6: skips agents whose provider has no tool wire", function()
        local d = deps({
            agent_names = { "g", "y" },
            agents = {
                g = { provider = "googleai", model = { model = "gemini-3-pro-preview" } },
                y = { provider = "anthropic", model = { model = "claude-sonnet-5" } },
            },
        })
        assert.are.equal("anthropic", assembly.resolve_agent(manifest({ name = "other" }), d).provider)
    end)

    it("tier 6: accepts cliproxyapi on either route", function()
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
