-- cliproxy_release.lua — pure release/version logic for the managed
-- cliproxyapi (#237).
--
-- No IO: every function takes values the caller already gathered (a curl
-- result table, `ps` rows, config), so the whole decision surface is
-- unit-tested without mocks (ARCH-PURE). cliproxy.lua owns the IO around it.
--
-- A version is "X.Y.Z" with no leading v, digits kept exactly as published —
-- they become the release tag in a download URL. Anything else (a prerelease
-- suffix, two components, stray text) is not a version: parsers return nil and
-- callers report "unknown" rather than guess (ARCH-SECURE).

local M = {}

--- Normalize a release version: "7.2.158" / "v7.2.158" -> "7.2.158"; else nil.
---@param s any
---@return string|nil
function M.parse_version(s)
    if type(s) ~= "string" then
        return nil
    end
    local a, b, c = vim.trim(s):match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not a then
        return nil
    end
    return a .. "." .. b .. "." .. c
end

--- -1, 0 or 1, comparing two parsed versions numerically.
---@param a string
---@param b string
---@return integer
function M.compare_versions(a, b)
    local pa = { (a or ""):match("^(%d+)%.(%d+)%.(%d+)$") }
    local pb = { (b or ""):match("^(%d+)%.(%d+)%.(%d+)$") }
    assert(#pa == 3 and #pb == 3, "compare_versions: not a parsed version")
    for i = 1, 3 do
        local x, y = tonumber(pa[i]), tonumber(pb[i])
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

-- Split curl's `-w "…\n%{http_code}"` tail off its stdout.
local function split_code(stdout)
    local head, code = (stdout or ""):match("^(.*)\n(%d+)%s*$")
    return head, code
end

--- The release GitHub's `releases/latest` redirect names. `obj` is the
--- vim.system result of `curl -o /dev/null -w "%{redirect_url}\n%{http_code}"`.
---@param obj table # { code, stdout, stderr }
---@return string|nil version, string|nil err
function M.parse_latest_response(obj)
    if obj.code ~= 0 then
        return nil, "unreachable: " .. vim.trim(obj.stderr or "")
    end
    local url, code = split_code(obj.stdout)
    local tag = vim.trim(url or ""):match("/releases/tag/([^/?#%s]+)$")
    local version = M.parse_version(tag)
    if not version then
        return nil, ("no release in the redirect (HTTP %s)"):format(tostring(code))
    end
    return version
end

--- The version a running proxy reports: X-Cpa-Version, which every
--- /v0/management/* response carries (captured live, 7.1.71). `obj` is the
--- vim.system result of `curl -D - -o /dev/null -w "\n%{http_code}"`.
---@param obj table # { code, stdout }
---@return string|nil version, string|nil reason # "down" | "no_header"
function M.parse_version_probe(obj)
    if obj.code ~= 0 then
        return nil, "down"
    end
    local headers = split_code(obj.stdout) or ""
    for line in headers:gmatch("[^\r\n]+") do
        local name, value = line:match("^([%w%-]+):%s*(.-)%s*$")
        if name and name:lower() == "x-cpa-version" then
            local v = M.parse_version(value)
            if v then
                return v
            end
            break
        end
    end
    return nil, "no_header"
end

--- Who holds the managed port (#237). A listener is ours when its command line
--- carries `-config <config_path>` as a whole token — launched by parley with
--- its rendered config, in this nvim session or an earlier one. Only the
--- listener's row is read, so a shell that merely mentions the path can never
--- match (the #197 lesson). A find, not the first token, so a data dir with a
--- space in it still matches.
---@param rows table[] # cliproxy_auth.parse_ps rows: { pid, command, exe }
---@param port_pids number[] # pids listening on the managed port
---@param config_path string|nil # parley's rendered config.yaml
---@return table|nil # { ours: boolean, exe: string|nil } — nil when nothing listens
function M.running_identity(rows, port_pids, config_path)
    if not port_pids or #port_pids == 0 then
        return nil
    end
    local on_port = {}
    for _, pid in ipairs(port_pids) do
        on_port[pid] = true
    end
    local needle = config_path and ("-config " .. config_path) or nil
    local exe
    for _, r in ipairs(rows or {}) do
        if on_port[r.pid] then
            exe = exe or r.exe
            if needle then
                -- Two locals from ONE call: `needle and cmd:find(...)` would
                -- truncate find's results to one value and lose `e`.
                local cmd = r.command or ""
                local s, e = cmd:find(needle, 1, true)
                if s and (e == #cmd or cmd:sub(e + 1, e + 1) == " ") then
                    return { ours = true, exe = r.exe }
                end
            end
        end
    end
    return { ours = false, exe = exe }
end

--- Why parley will not update the managed binary, or nil when it may. Checked
--- before any network call.
---@param s table # { managed: boolean, binary_path: string|nil }
---@return string|nil
function M.update_refusal(s)
    if not s.managed then
        return "cliproxy.manage is off — parley does not run the proxy, so update your cliproxyapi yourself"
    end
    if type(s.binary_path) == "string" and s.binary_path ~= "" then
        return ("cliproxy.binary_path is set, so parley runs %s — update that binary, or unset "
            .. "binary_path to use parley's download"):format(s.binary_path)
    end
    return nil
end

--- The update decision table (#237, ARCH-ORDER): what to install, whether to
--- restart, and what to tell the user, from facts the IO layer gathered.
---@param s table
---   target      string|nil  version to install (download_version, else latest)
---   target_err  string|nil  why target is nil
---   pinned      boolean     target came from cliproxy.download_version
---   installed   string|nil  version recorded for the managed binary
---   running     table|nil   { version?, ours, exe?, port } — nil when nothing answers
---@return table # { ok, install?, restart?: "managed"|"manual", target?, message }
function M.plan_update(s)
    local target = s.target
    if not target then
        if s.pinned then
            return { ok = false, message = tostring(s.target_err) }
        end
        return { ok = false, message = ("could not find the latest cliproxyapi release (%s) — set "
            .. "cliproxy.download_version to install a specific one"):format(tostring(s.target_err)) }
    end
    local install = s.installed ~= target and target or nil
    local r, restart = s.running, nil
    if r and (install or (r.version and r.version ~= target)) then
        restart = r.ours and "managed" or "manual"
    end
    local msg
    if install then
        msg = s.installed and ("updated %s → %s"):format(s.installed, target) or ("installed %s"):format(target)
    else
        msg = ("already at %s"):format(target)
    end
    if s.pinned then
        msg = msg .. " (pinned by cliproxy.download_version)"
    end
    if restart == "managed" then
        msg = msg .. " — restarting the proxy"
    elseif restart == "manual" then
        msg = msg .. (" — the proxy on port %s (%s) was not started by parley and still runs %s; stop it "
            .. "(e.g. `brew services stop cliproxyapi`) so parley can start %s, or upgrade it"):format(
            tostring(r.port), r.exe or "another process", r.version or "an older version", target)
    end
    return { ok = true, install = install, restart = restart, target = target, message = msg }
end

return M
