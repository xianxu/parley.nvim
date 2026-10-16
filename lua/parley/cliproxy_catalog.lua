--------------------------------------------------------------------------------
-- Pure catalog core for cliproxyapi's advertised models (issue #205).
--
-- cliproxyapi already knows which models it serves, and that set moves on its
-- own — a login registers new models with no restart. This module turns the
-- proxy's two model routes into rows parley can offer directly, so no model
-- name has to be written into config.lua and go stale there.
--
-- No IO: every function here is deterministic and unit-tested against fixtures
-- captured from a real proxy, without mocks (ARCH-PURE). The fetch/cache shell
-- lives in parley/cliproxy.lua.
--------------------------------------------------------------------------------

local M = {}

--- The model LINE an id belongs to: the id with version numerals removed, so
--- claude-opus-5 and claude-opus-4-8 collapse to one series and the newest of
--- the line can be picked. Sol/Luna/Terra stay distinct because their
--- distinguishing token is a word, not a number.
---
--- Derived from the id alone, deliberately. An earlier draft also specified a
--- displayName-derived stem for opaque-id providers; it was dropped because the
--- id rule already produces the correct curation for every verified case,
--- antigravity included — "Gemini 3.1 Pro (Low)" and "(High)" are genuinely
--- different offerings and SHOULD stay separate series.
---@param id string
---@return string
function M.series(id)
    if type(id) ~= "string" then
        return ""
    end
    local s = id:gsub("%-?%d[%d%.%-]*", "-"):gsub("%-+", "-")
    s = s:gsub("^%-", ""):gsub("%-$", "")
    -- An all-numeral id strips to "", which would collapse every such model into
    -- one series and let curate drop all but one. Ids are vendor-controlled, so
    -- fall back to the id itself rather than emit a colliding empty key.
    if s == "" then
        return id
    end
    return s
end

--- Join cliproxy's two model routes into one row list.
---
--- Both are needed and neither is sufficient: /v1/models carries `created` (the
--- recency signal) and /v1beta/models carries `displayName` + `description` (the
--- only human-readable naming — and for antigravity the only TRUTHFUL naming,
--- since its ids are opaque handles: `gemini-pro-agent` is "Gemini 3.1 Pro
--- (High)").
---@param v1_json string   # body of GET /v1/models
---@param beta_json string # body of GET /v1beta/models
---@return table[] # { { id, owner, created?, display, description, series }, … }
function M.parse(v1_json, beta_json)
    local ok, v1 = pcall(vim.json.decode, v1_json or "")
    if not ok or type(v1) ~= "table" or type(v1.data) ~= "table" then
        return {}
    end
    local beta_by_id = {}
    local beta_ok, beta = pcall(vim.json.decode, beta_json or "")
    if beta_ok and type(beta) == "table" and type(beta.models) == "table" then
        for _, m in ipairs(beta.models) do
            if type(m) == "table" and type(m.name) == "string" then
                beta_by_id[(m.name:gsub("^models/", ""))] = m
            end
        end
    end
    local out = {}
    for _, m in ipairs(v1.data) do
        -- An empty id is not a model: it would collide with every other empty id
        -- in `series` and let curate drop real rows. Rejected here, at the
        -- boundary, rather than defended against in every consumer.
        if type(m) == "table" and type(m.id) == "string" and m.id ~= "" then
            local b = beta_by_id[m.id] or {}
            out[#out + 1] = {
                id = m.id,
                owner = m.owned_by,
                created = tonumber(m.created),
                display = type(b.displayName) == "string" and b.displayName or m.id,
                description = type(b.description) == "string" and b.description or "",
                series = M.series(m.id),
            }
        end
    end
    return out
end

--- Recency for ordering. Two disjoint bands, never mixed: a dated row ranks in
--- epoch seconds; a row with no `created` — every antigravity model, measured
--- 2026-08-31 — ranks by the version parsed from its displayName, always BELOW
--- any dated row.
---
--- -1e9, not -1000: the bands must not overlap for ANY input, and a parsed
--- display version only has to reach 1000 to outrank a small epoch value.
---@param m table # a parsed Model
---@return number
function M.rank_key(m)
    if type(m.created) == "number" and m.created > 0 then
        return m.created
    end
    -- A numeral scraped from a free-text display name is a VERSION only when it
    -- is delimited — not glued to a letter. "120B", "20B", "70B", "32K" are
    -- magnitudes with unit suffixes, and reading one as a version floats that
    -- row above every real release. A magnitude threshold would only have
    -- excluded the sizes that happen to be large.
    local version = 0
    for n, next_char in tostring(m.display or ""):gmatch("(%d+%.?%d*)(.?)") do
        if not next_char:match("%a") then
            version = tonumber(n) or 0
            break
        end
    end
    return -1e9 + version
end

--- Parse one `live_models.providers` entry:
--- "<provider>[!N]" or "<provider>:<term>[!N][,<term>[!N]…]".
--- `!N` caps the search it is attached to: a term, or a bare provider (which
--- is the search with the empty term). No `!` means no limit (#230). A count
--- that is not a positive integer is an error, never read as "no limit".
---@param spec string
---@return table|nil # { provider = string, cap = integer|nil, terms = { {text=string, cap=integer|nil} } }
---@return string|nil # why the spec is malformed, naming it
function M.parse_provider_spec(spec)
    spec = tostring(spec or "")
    local function bad(why) return nil, ("live_models.providers %q: %s"):format(spec, why) end
    local function capped(text)
        local base, count = text:match("^(.-)!(.*)$")
        if not base then return text, nil end
        if not count:match("^%d+$") or tonumber(count) < 1 then
            return nil, nil, ("%q needs a positive count after !"):format(text)
        end
        return base, tonumber(count)
    end
    -- Greedy up to the FIRST colon. A lazy `[^:]-` here matches the empty
    -- string and hands the whole spec to the filter half.
    local provider_part, filter = spec:match("^([^:]*):?(.*)$")
    local provider, cap, err = capped(vim.trim(provider_part))
    if err then return bad(err) end
    local terms = {}
    for term in filter:gmatch("[^,]+") do
        term = vim.trim(term)
        if term ~= "" then
            local text, term_cap, term_err = capped(term)
            if term_err then return bad(term_err) end
            text = vim.trim(text)
            if text == "" then return bad(("%q has no search term"):format(term)) end
            terms[#terms + 1] = { text = text:lower(), cap = term_cap }
        end
    end
    if cap and #terms > 0 then return bad("!N on the provider applies only to a bare provider; cap each term") end
    return { provider = vim.trim(provider), cap = cap, terms = terms }
end

-- Terms match the id AND the display name. Matching displayName is required,
-- not a nicety: antigravity's ids are opaque handles, so an id-only match would
-- make that provider unfilterable.
local function matches(m, term)
    return tostring(m.id):lower():find(term, 1, true) ~= nil
        or tostring(m.display):lower():find(term, 1, true) ~= nil
end

-- Compare GPT's dotted numeric version only after the primary recency tie.
-- Same-date vendor rows need a numeric tie-break: alphabetical order places
-- GPT-6 after GPT-5.6. Other families and equal-version variants stay lexical.
local function tied_id_less(a, b)
    local va, vb = a:match("^gpt%-(%d[%d%.]*)"), b:match("^gpt%-(%d[%d%.]*)")
    if va and vb then
        local aa, bb = vim.split(va, ".", { plain = true }), vim.split(vb, ".", { plain = true })
        for i = 1, math.max(#aa, #bb) do
            local na, nb = tonumber(aa[i]) or 0, tonumber(bb[i]) or 0
            if na ~= nb then
                return na > nb
            end
        end
    end
    return a < b
end

--- The picker's default view: for each configured provider, the models matching
--- each of its searches, one per series (the newest). A search shows every
--- matching series unless it carries `!N` (#230): a hidden cap is how a later
--- term once vanished. Series are deduplicated across a provider's searches,
--- so an earlier search can claim a shared series but never another's budget.
--- A malformed spec contributes nothing; `diagnose` names it.
---
--- Term order is display order, so the config expresses preference.
---@param models table[] # from parse()
---@param opts table # { providers = {"claude:opus,sonnet", "codex:gpt-5!3"}, owned_by = fn }
---@return table[]
function M.curate(models, opts)
    opts = opts or {}
    local owned_by = opts.owned_by or require("parley.cliproxy_config").provider_owned_by
    local out = {}
    for _, spec in ipairs(opts.providers or {}) do
        local parsed = M.parse_provider_spec(spec)
        for _, m in ipairs(parsed and M._select(models, parsed, owned_by) or {}) do
            -- Copy before tagging: these rows are the disk cache's own tables,
            -- re-curated on every <C-a> toggle and background repaint, and this
            -- module promises to be side-effect-free (ARCH-PURE).
            local row = vim.tbl_extend("force", {}, m)
            row.provider = parsed.provider
            out[#out + 1] = row
        end
    end
    return out
end

-- The provider's rows, newest first. A provider name we don't know (a typo
-- like "claud") yields owner=nil, and `m.owner == owner` would then match every
-- row whose owned_by is ABSENT — silently offering unrelated models under that
-- heading. An unknown provider contributes nothing instead.
local function pool_for(models, provider, owned_by)
    local owner = owned_by(provider)
    local pool = {}
    for _, m in ipairs(owner and models or {}) do
        if m.owner == owner then
            pool[#pool + 1] = m
        end
    end
    table.sort(pool, function(a, b)
        local ra, rb = M.rank_key(a), M.rank_key(b)
        if ra ~= rb then
            return ra > rb
        end
        return tied_id_less(tostring(a.id), tostring(b.id))
    end)
    return pool
end

local function searches(parsed)
    return #parsed.terms > 0 and parsed.terms or { { text = "", cap = parsed.cap } }
end

--- One parsed spec's rows in display order (exposed for diagnose and tests).
function M._select(models, parsed, owned_by)
    local pool = pool_for(models, parsed.provider, owned_by)
    local taken, seen = {}, {}
    for _, search in ipairs(searches(parsed)) do
        local count = 0
        for _, m in ipairs(pool) do
            if search.cap and count >= search.cap then
                break
            end
            if not seen[m.series] and (search.text == "" or matches(m, search.text)) then
                seen[m.series] = true
                taken[#taken + 1] = m
                count = count + 1
            end
        end
    end
    return taken
end

--- What a caller should tell the operator about its provider specs: each
--- malformed spec, and each search that matches no model of a provider that
--- has models (a provider with none is the logged-out case, reported apart).
--- Pure: the caller logs it once per catalog refresh, never per repaint.
---@return string[]
function M.diagnose(models, providers, owned_by)
    owned_by = owned_by or require("parley.cliproxy_config").provider_owned_by
    local out = {}
    for _, spec in ipairs(providers or {}) do
        local parsed, err = M.parse_provider_spec(spec)
        if not parsed then
            out[#out + 1] = err
        else
            local pool = pool_for(models, parsed.provider, owned_by)
            if #pool > 0 then
                for _, search in ipairs(parsed.terms) do
                    local hit = false
                    for _, m in ipairs(pool) do
                        if matches(m, search.text) then hit = true; break end
                    end
                    if not hit then
                        out[#out + 1] = ("live_models.providers %q: %q matches no %s model"):format(
                            spec, search.text, parsed.provider)
                    end
                end
            end
        end
    end
    return out
end

--- The agent name a catalog model registers under. Single source (ARCH-DRY):
--- the picker's de-duplication, `_build_items` and `build_agent` all have to
--- agree on it, and three copies of `id .. "*"` is three chances to drift — a
--- mismatch would silently render the model twice again.
---@param id string
---@return string
function M.agent_name(id)
    return tostring(id) .. "*"
end

--- Turn a catalog row into a session agent. Tools and web search are ON: an
--- ad-hoc pick is meant to be a working agent, not a stripped one.
---
--- The wire follows the MODEL FAMILY, never `owner`: owner is a display
--- grouping that is not even stable (claude-sonnet-4-6 was reported under
--- `anthropic` on one proxy start and `antigravity` on the next), while a
--- claude model speaks the Anthropic wire whichever channel serves it —
--- measured through antigravity, 200 OK. `owner` is forwarded because it
--- decides the SEARCH TOOL for the families whose wire it cannot affect; the
--- whole decision is single-sourced in providers.lua.
---@param m table # a parsed Model
---@param opts table|nil # { system_prompt = string, tools = string[] }; nil tools defaults to @all
---@return table # a parley agent
function M.build_agent(m, opts)
    opts = opts or {}
    -- Returns nil rather than raising: the callers are a picker callback and a
    -- session restore, where an error would surface as a stack trace over the
    -- UI or abort setup. A row with no id cannot name an agent.
    if type(m) ~= "table" or type(m.id) ~= "string" or m.id == "" then
        return nil
    end
    return {
        provider = "cliproxyapi",
        name = M.agent_name(m.id),
        model = {
            model = m.id,
            web_search_strategy = require("parley.providers")
                .cliproxy_default_web_search_strategy(m.id, m.owner),
        },
        system_prompt = opts.system_prompt or require("parley.defaults").chat_system_prompt,
        synthetic_system_prompt = true,
        tools = vim.deepcopy(opts.tools or { "@all" }),
    }
end

return M
