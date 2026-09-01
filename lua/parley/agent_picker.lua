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
        local found = false
        for _, m in ipairs(models or {}) do
            if m.owner == owner then
                found = true
                break
            end
        end
        if not found and provider ~= "" then
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
        local name = m.id .. "*"
        local is_current = name == plugin._state.agent
        items[#items + 1] = {
            name = name,
            kind = "live",
            model = m,
            display = (is_current and "✓ " or "  ")
                .. m.display .. " - " .. m.id .. " (" .. tostring(m.owner) .. ")",
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
    local providers = (cfg or {}).providers or {}
    local cat = require("parley.cliproxy_catalog")

    -- Picking a live model registers it as `<id>*`, and the restart restore does
    -- the same. Without this it renders TWICE on the next open — once from the
    -- configured loop, once from the catalog — both checkmarked, both keyed the
    -- same for `recall_id_fn`.
    local function unregistered(rows)
        local out = {}
        for _, m in ipairs(rows) do
            if not agents[m.id .. "*"] then
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
    local title = "🤖 Parley Agents"
    local handle
    handle = float_picker.open({
        title = title,
        items = M._build_items(plugin, view_for(expanded)),
        anchor = "top",
        recall_key = "parley.agent_picker",
        recall_id_fn = function(item) return item.name end,
        on_select = function(item)
            if item.kind == "separator" then
                return
            end
            if item.kind == "login" then
                -- The picker doubles as the login surface: a provider you are
                -- not logged into is exactly where you notice it.
                local prefix = plugin.config.cmd_prefix or "Parley"
                vim.schedule(function()
                    vim.cmd(prefix .. "Proxy login " .. item.provider)
                end)
                return
            end
            if item.kind == "live" then
                plugin.register_live_agent(item.model)
                return
            end
            plugin.refresh_state({ agent = item.name })
            plugin.logger.info("Agent set to: " .. item.name)
            vim.cmd("doautocmd User ParleyAgentChanged")
        end,
        mappings = {
            {
                key = keybindings_key,
                fn = function(_, _)
                    vim.schedule(function()
                        plugin.cmd.KeyBindings()
                    end)
                end,
            },
            {
                -- Expand to the whole catalog. Curation decides the DEFAULT view,
                -- never what is reachable. The key comes from the registry so it
                -- is discoverable in <C-g>? and rebindable like every other one.
                key = require("parley.keybinding_registry")
                    .key_for("ap_expand_catalog", plugin.config) or "<C-a>",
                fn = function()
                    expanded = not expanded
                    handle.update(M._build_items(plugin, view_for(expanded)))
                    handle.set_title(expanded and (title .. " — all models") or title)
                end,
            },
        },
    })

    -- Refresh in the background when the cache is cold or stale, and repaint if
    -- the picker is still open. fetch_catalog never spawns the proxy, so opening
    -- a picker cannot start a daemon (#131).
    if ok_proxy and cliproxy.is_managed() and cliproxy.catalog_stale() then
        cliproxy.fetch_catalog(function(models)
            -- Repaint whenever the fetch RESOLVED, not only when it returned
            -- rows: a proxy answering 200 with an empty registry is exactly the
            -- case the login rows report, and gating on `#models > 0` would
            -- leave the picker showing a stale list instead.
            if models and handle and not handle.is_closed() then
                handle.update(M._build_items(plugin, view_for(expanded)))
            end
        end)
    end
end

return M
