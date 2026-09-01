-- Agent picker module for Parley.nvim
-- Provides a floating window UI for selecting LLM agents

local M = {}

local float_picker = require("parley.float_picker")

--- Which configured providers advertise no models at all.
---
--- The catalog IS the signal: cliproxy registers a channel's models only once
--- that channel has a credential, so a provider contributing nothing is one you
--- are not logged into. Measured — antigravity's 13 models appeared the moment
--- its auth file landed, with no restart. That keeps the check synchronous on a
--- UI path; a credential that is loaded but DEAD still lists models, and the
--- dispatch-failure path (#197) is what diagnoses that case.
---@param models table[] # the full cached catalog
---@param providers string[] # configured `live_models.providers` entries
---@return table[] # { { provider = "antigravity" }, … }
function M._providers_without_models(models, providers)
    local cat = require("parley.cliproxy_catalog")
    local cc = require("parley.cliproxy_config")
    local out = {}
    for _, spec in ipairs(providers or {}) do
        local provider = cat.parse_provider_spec(spec).provider
        local owner = cc.provider_owned_by(provider)
        -- Only a name parley can actually log into earns a login row. A typo
        -- ("claud") or an OWNER name ("anthropic") resolves to no channel, and
        -- offering `:ParleyProxy login claud` is an actionable-looking dead end.
        local loggable = owner ~= nil and vim.tbl_contains(cc.providers(), provider)
        local found = false
        for _, m in ipairs(models or {}) do
            if m.owner == owner then
                found = true
                break
            end
        end
        if not found and loggable then
            out[#out + 1] = { provider = provider }
        end
    end
    return out
end

-- Build the sorted item list from a plugin state. Exposed for testing.
--
-- `extra` (optional) carries the live cliproxy catalog section (#205):
--   { live = <curated catalog rows>, logged_out = { { provider = … } } }
-- Configured agents keep their existing order; the live rows follow, so a
-- catalog that moves never reshuffles the list the operator knows.
function M._build_items(plugin, extra)
    local items = {}
    for _, agent_name in ipairs(plugin._agents) do
        local agent = plugin.agents[agent_name]
        local provider = agent.provider or "openai"
        local model_name = type(agent.model) == "table" and agent.model.model or agent.model

        local description = model_name .. " (" .. provider .. ")"
        -- Combined [🔧🌎]-style indicator group for tool-enabled agents and
        -- web search (M1 Task 1.7 of #81). Reuse the highlighter helpers
        -- so picker, buffer-top extmark, and lualine agree on the badge
        -- string. The `require` itself is NOT pcall-wrapped: a real load
        -- failure in parley.highlighter should surface loudly, not silently
        -- hide the badge. The pcall only guards the `agent_web_search_badge`
        -- state read (_parley._state) which may be nil in isolated unit tests.
        local highlighter = require("parley.highlighter")
        local tool_part = highlighter.agent_tool_badge(agent) or ""
        local ok_ws, web_part = pcall(highlighter.agent_web_search_badge, agent)
        if not ok_ws then web_part = "" end
        local indicators = tool_part .. (web_part or "")
        local indicator_group = (indicators ~= "") and (" [" .. indicators .. "]") or ""
        local is_current = agent_name == plugin._state.agent
        local display = (is_current and "✓ " or "  ") .. agent_name .. indicator_group .. " - " .. description

        table.insert(items, {
            name = agent_name,
            kind = "agent",
            display = display,
            is_current = is_current,
        })
    end

    -- Current agent first, then alphabetical
    table.sort(items, function(a, b)
        if a.is_current then
            return true
        end
        if b.is_current then
            return false
        end
        return a.name < b.name
    end)

    -- Live section, appended AFTER the sort so it stays a section rather than
    -- interleaving with the configured agents. A separator carries that
    -- distinction visually; it is inert (`on_select` ignores it) because
    -- float_picker has no notion of a non-selectable row.
    extra = extra or {}
    local live = extra.live or {}
    local logged_out = extra.logged_out or {}
    if #live > 0 or #logged_out > 0 then
        items[#items + 1] = {
            name = "__live_separator__",
            kind = "separator",
            display = "── live · cliproxy ──",
            is_current = false,
        }
    end
    for _, m in ipairs(live) do
        local name = require("parley.cliproxy_catalog").agent_name(m.id)
        local is_current = name == plugin._state.agent
        items[#items + 1] = {
            name = name,
            kind = "live",
            model = m,
            -- `owner` is absent on a hand-edited or older-parley cache row;
            -- rendering it raw prints a literal "(nil)" into the picker.
            display = (is_current and "✓ " or "  ")
                .. m.display .. " - " .. m.id
                .. (m.owner and (" (" .. m.owner .. ")") or ""),
            is_current = is_current,
        }
    end
    for _, p in ipairs(logged_out) do
        items[#items + 1] = {
            name = p.provider,
            kind = "login",
            provider = p.provider,
            display = "  " .. p.provider .. " - (logged out)",
            is_current = false,
        }
    end

    return items
end

--- Build the picker's live section from a catalog. PURE — takes the catalog,
--- the `live_models` config and the registered agents, returns what
--- `_build_items` consumes.
---
--- Extracted so a test can drive the PRODUCTION path. The first version of the
--- de-duplication below was tested by re-implementing it in the spec body and
--- handing `_build_items` an already-filtered list, which meant reverting the
--- fix left the suite green — the test could not fail.
---@param models table[] # the full cached catalog
---@param cfg table # cliproxy.live_models
---@param opts table|nil # { all = boolean, agents = <plugin.agents> }
---@return table # { live = …, logged_out = … }
function M._view_for(models, cfg, opts)
    opts = opts or {}
    local agents = opts.agents or {}
    -- `providers = nil` means every provider parley knows how to log into —
    -- that is what config.lua documents, and returning {} instead made the whole
    -- live section vanish for anyone who omitted the key.
    local providers = (cfg or {}).providers
        or require("parley.cliproxy_config").providers()
    local cat = require("parley.cliproxy_catalog")

    -- Picking a live model registers it as `<id>*`, and the restart restore does
    -- the same. Without this it renders TWICE on the next open — once from the
    -- configured loop, once from the catalog — both checkmarked, both keyed the
    -- same for `recall_id_fn`.
    local function unregistered(rows)
        local out, seen = {}, {}
        for _, m in ipairs(rows) do
            -- Also dedupe BY ID: `providers = { "claude", "claude:opus" }` runs
            -- curate twice over the same pool (its per-series memo resets per
            -- entry), so the same model arrives twice — identical display, both
            -- marked current, one shared recall key. Same symptom as the
            -- registered-agent overlap, reached by a second route.
            if not seen[m.id] and not agents[cat.agent_name(m.id)] then
                seen[m.id] = true
                out[#out + 1] = m
            end
        end
        return out
    end

    -- `all` scopes exactly one thing: the curation bypass. It is not a reason to
    -- hide the logged-out rows, and an empty catalog is not either — an empty
    -- catalog is precisely when every configured provider is logged out, which
    -- is the case those rows exist to report.
    local live = opts.all and models
        or cat.curate(models, { providers = providers, per_provider = (cfg or {}).per_provider })

    return {
        live = unregistered(live),
        logged_out = M._providers_without_models(models, providers),
    }
end

--- What a picker selection DOES, by row kind. Split out of the closure so each
--- branch is reachable from a test — the branches are the whole behaviour of the
--- live section, and inside `agent_picker` none of them could be driven.
---@param plugin table
---@param item table # a row from _build_items
function M._select(plugin, item)
    if type(item) ~= "table" or item.kind == "separator" then
        return -- the separator is inert; float_picker has no non-selectable row
    end
    if item.kind == "login" then
        -- The picker doubles as the login surface: a provider you are not
        -- logged into is exactly where you notice it.
        local prefix = (plugin.config or {}).cmd_prefix or "Parley"
        return vim.schedule(function()
            vim.cmd(prefix .. "Proxy login " .. item.provider)
        end)
    end
    if item.kind == "live" then
        return plugin.register_live_agent(item.model)
    end
    plugin.refresh_state({ agent = item.name })
    plugin.logger.info("Agent set to: " .. item.name)
    vim.cmd("doautocmd User ParleyAgentChanged")
end

-- Create a floating picker to select an LLM agent
function M.agent_picker(plugin)
    local ok_proxy, cliproxy = pcall(require, "parley.cliproxy")

    -- Read the catalog off disk: synchronous, ~5 KB, no network on a UI path.
    local function catalog()
        if not ok_proxy then
            return {}
        end
        return cliproxy.catalog_cached() or {}
    end

    local expanded = false
    local function view_for(all)
        return M._view_for(catalog(), ((plugin.config or {}).cliproxy or {}).live_models or {},
            { all = all, agents = plugin.agents })
    end

    local keybindings_key = (plugin.config.global_shortcut_keybindings or { shortcut = "<C-g>?" }).shortcut
    local expand_key = require("parley.keybinding_registry")
        .key_for("ap_expand_catalog", plugin.config)
    local title = "🤖 Parley Agents"
    -- The registry owns the expand key. No literal fallback here: a hardcoded
    -- default would be a second copy of the registry's, invisible to the arch
    -- guard and free to drift. If the id ever stops resolving, the mapping is
    -- omitted rather than silently rebound to something else.
    local mappings = {
        {
            key = keybindings_key,
            fn = function(_, _)
                vim.schedule(function()
                    plugin.cmd.KeyBindings()
                end)
            end,
        },
    }

    local handle
    if expand_key then
        table.insert(mappings, {
            -- Expand to the whole catalog. Curation decides the DEFAULT view,
            -- never what is reachable.
            key = expand_key,
            fn = function()
                expanded = not expanded
                handle.update(M._build_items(plugin, view_for(expanded)))
                handle.set_title(expanded and (title .. " — all models") or title)
            end,
        })
    end

    handle = float_picker.open({
        title = title,
        items = M._build_items(plugin, view_for(expanded)),
        anchor = "top",
        recall_key = "parley.agent_picker",
        recall_id_fn = function(item) return item.name end,
        on_select = function(item)
            M._select(plugin, item)
        end,
        mappings = mappings,
    })

    -- Refresh in the background when the cache is cold or stale, and repaint if
    -- the picker is still open. fetch_catalog never spawns the proxy, so opening
    -- a picker cannot start a daemon (#131).
    -- NOT gated on is_managed(): `manage = false` means parley does not START
    -- the proxy, not that there is no proxy — a bring-your-own instance answers
    -- the same GET. Gating here left those operators with an empty catalog and a
    -- picker claiming every provider was logged out. fetch_catalog never spawns
    -- anything, so the dormancy contract is unaffected either way.
    if ok_proxy and cliproxy.catalog_stale() then
        cliproxy.fetch_catalog(function(models)
            -- Repaint whenever the fetch RESOLVED, not only when it returned
            -- rows: a proxy answering 200 with an empty registry is exactly the
            -- case the login rows report, and gating on `#models > 0` would
            -- leave the picker showing a stale list instead.
            if models and handle and not handle.is_closed() then
                -- Restore the selection by NAME, not by index: this lands while
                -- the operator may already be pointing at a row, and the refresh
                -- can insert or remove rows above it. Keeping the index would
                -- silently move the cursor onto a different agent.
                local was = handle.selected and handle.selected()
                local items = M._build_items(plugin, view_for(expanded))
                local index
                if was and was.name then
                    for i, item in ipairs(items) do
                        if item.name == was.name then
                            index = i
                            break
                        end
                    end
                end
                handle.update(items, nil, index)
            end
        end)
    end
end

return M
