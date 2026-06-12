--------------------------------------------------------------------------------
-- IO lifecycle shell for the managed cliproxyapi instance (issue #131).
--
-- Thin IO seam (ARCH-PURE): binary discovery, detached spawn, identity-checked
-- health probe, reuse-if-healthy, the :ParleyProxy commands. All pure config
-- transforms live in parley/cliproxy_config.lua and are injected here.
--
-- Reached from the dispatcher via the cliproxyapi adapter's pre_query hook
-- (ARCH-DRY: the same seam copilot uses to prep before a query).
--------------------------------------------------------------------------------

local uv = vim.uv or vim.loop
local cc = require("parley.cliproxy_config")
local logger = require("parley.logger")

local M = {}

-- pid -> uv process handle for proxies PARLEY spawned (so stop() is scoped to
-- our own daemon and never touches a reused/foreign one).
local _spawned = {}

--------------------------------------------------------------------------------
-- Config access
--------------------------------------------------------------------------------

-- The merged user config lives on the `parley` module (init.lua merges
-- top-level setup{} keys into M.config), NOT on this module's M.
local function cfg()
    local ok, parley = pcall(require, "parley")
    if ok and parley and type(parley.config) == "table" then
        return parley.config.cliproxy
    end
    return nil
end

local function endpoint()
    local ok, parley = pcall(require, "parley")
    if ok and parley and parley.dispatcher and parley.dispatcher.providers
        and parley.dispatcher.providers.cliproxyapi then
        return parley.dispatcher.providers.cliproxyapi.endpoint
    end
    return nil
end

--- Is the managed-proxy feature opted into?
---@return boolean
function M.is_managed()
    local c = cfg()
    return c ~= nil and c.manage == true
end

--------------------------------------------------------------------------------
-- Binary discovery
--------------------------------------------------------------------------------

--- Locate the cliproxy binary: explicit binary_path → PATH (brew name
--- `cliproxyapi`, then release-tarball name `cli-proxy-api`). M2 inserts the
--- managed download dir between binary_path and PATH.
---@return string|nil
function M.discover_binary()
    local c = cfg() or {}
    if type(c.binary_path) == "string" and c.binary_path ~= "" then
        if vim.fn.executable(c.binary_path) == 1 then
            return c.binary_path
        end
    end
    for _, name in ipairs({ "cliproxyapi", "cli-proxy-api" }) do
        local p = vim.fn.exepath(name)
        if p ~= nil and p ~= "" then
            return p
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Health probe (identity-checked)
--------------------------------------------------------------------------------

-- Classify a curl result against cliproxy's /v1/models contract (route + body
-- shapes confirmed in issue #131 Task 2.0):
--   down                 connection refused / timeout (no usable response)
--   client_key_mismatch  401 (rendered api-keys != the bearer we sent)
--   healthy              200, {object:"list", data:[non-empty]}
--   needs_login          200, {object:"list", data:[]}  (up, no upstream login)
--   foreign              200 but not the list shape (someone else holds the port)
local function classify(code, stdout)
    if code ~= 0 then
        return "down"
    end
    local out = stdout or ""
    local body, http = out:match("^(.*)\n(%d+)%s*$")
    http = tonumber(http)
    if http == 401 then
        return "client_key_mismatch"
    end
    if http ~= 200 then
        return "foreign"
    end
    local ok, decoded = pcall(vim.json.decode, body or "")
    if ok and type(decoded) == "table" and decoded.object == "list" then
        if type(decoded.data) == "table" and #decoded.data > 0 then
            return "healthy"
        end
        return "needs_login"
    end
    return "foreign"
end

M._classify = classify -- exposed for unit testing

--- Probe http://host:port/v1/models with the client bearer and classify.
--- Async; calls cb(state) on the main loop.
---@param host string
---@param port number
---@param secret string|nil
---@param cb fun(state: string)
function M.health_probe(host, port, secret, cb)
    local url = ("http://%s:%s/v1/models"):format(host, port)
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", "2" }
    if type(secret) == "string" and secret ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. secret)
    end
    table.insert(args, url)
    vim.system(args, { text = true }, function(obj)
        local state = classify(obj.code, obj.stdout)
        vim.schedule(function()
            cb(state)
        end)
    end)
end

return M
