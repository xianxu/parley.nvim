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
    -- interleaving with the configured agents.
    extra = extra or {}
    for _, m in ipairs(extra.live or {}) do
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
    for _, p in ipairs(extra.logged_out or {}) do
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

-- Create a floating picker to select an LLM agent
function M.agent_picker(plugin)
    local cat = require("parley.cliproxy_catalog")
    local ok_proxy, cliproxy = pcall(require, "parley.cliproxy")

    -- Read the catalog off disk: synchronous, ~5 KB, no network on a UI path.
    local function catalog()
        if not ok_proxy then
            return {}
        end
        local models = cliproxy.catalog_cached()
        return models or {}
    end

    local function live_config()
        return ((plugin.config or {}).cliproxy or {}).live_models or {}
    end

    -- Two views the <C-a> toggle switches between: the curated default, and the
    -- entire catalog with filter AND curation bypassed, so narrowing the config
    -- never puts a model out of reach.
    local expanded = false
    local function view_for(all)
        local models = catalog()
        local cfg = live_config()
        if #models == 0 then
            return {}
        end
        if all then
            return { live = models, logged_out = {} }
        end
        return {
            live = cat.curate(models, {
                providers = cfg.providers or {},
                per_provider = cfg.per_provider,
            }),
            logged_out = M._providers_without_models(models, cfg.providers or {}),
        }
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
                -- never what is reachable.
                key = "<C-a>",
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
            if models and #models > 0 and handle and not handle.is_closed() then
                handle.update(M._build_items(plugin, view_for(expanded)))
            end
        end)
    end
end

return M
