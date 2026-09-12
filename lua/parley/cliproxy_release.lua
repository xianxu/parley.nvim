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
---@return table|nil identity # { ours: boolean, exe: string|nil }
---@return string|nil why_unknown # set when identity is nil: parley cannot tell
---   who holds the port, and says so rather than guessing (#237 BR-8)
function M.running_identity(rows, port_pids, config_path)
    if not port_pids or #port_pids == 0 then
        return nil, "no process found listening on the port"
    end
    local on_port = {}
    for _, pid in ipairs(port_pids) do
        on_port[pid] = true
    end
    local needle = config_path and ("-config " .. config_path) or nil
    local exe, seen
    for _, r in ipairs(rows or {}) do
        if on_port[r.pid] then
            seen = true
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
    if not seen then
        return nil, "the listener is not in the process table"
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
---   running     table|nil   { version?, ours?, identity_err?, exe?, port } — nil when
---               nothing answers; ours is nil when parley could not tell who started it
---@return table # { ok, install?, restart?: "managed"|"manual"|"unknown", warn?, target?, message }
---   warn is true when the operator must still act: the listener is not
---   parley's, or parley could not tell, so the new version is not yet what
---   serves requests.
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
        if r.ours == true then
            restart = "managed"
        elseif r.ours == false then
            restart = "manual"
        else
            restart = "unknown" -- never restart what parley could not identify
        end
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
    elseif restart == "manual" and r.version then
        msg = msg .. (" — the proxy on port %s (%s) was not started by parley and still runs %s; stop it "
            .. "(e.g. `brew services stop cliproxyapi`) so parley can start %s, or upgrade it"):format(
            tostring(r.port), r.exe or "another process", r.version, target)
    elseif restart == "manual" then
        -- No X-Cpa-Version: a cliproxyapi without remote management, or not a
        -- cliproxyapi at all. Say only what is known.
        msg = msg .. (" — port %s is held by a process parley did not start%s, and it reports no "
            .. "cliproxyapi version; stop it so parley can start %s"):format(
            tostring(r.port), r.exe and (" (%s)"):format(r.exe) or "", target)
    elseif restart == "unknown" then
        msg = msg .. (" — could not tell whether parley started the proxy on port %s (%s), so it was left "
            .. "running (%s); if parley started it, :ParleyProxy restart replaces it"):format(
            tostring(r.port), tostring(r.identity_err or "identity unreadable"),
            r.version and ("it still runs " .. r.version) or "it reports no cliproxyapi version")
    end
    return { ok = true, install = install, restart = restart,
        warn = (restart == "manual" or restart == "unknown") or nil, target = target, message = msg }
end

--- What update tells the operator once its restart has answered (#237 BR-8).
--- Every claim comes from an observation: the version probed on the port after
--- the restart, the restart's own error, or its silence. Where nothing could be
--- observed, the message says so and names what to check.
---@param message string # plan_update's message for a managed restart
---@param target string # the version just installed
---@param o table # { timeout = true } | { err = string } | { version?: string, reason?: string }
---@return table # { ok: boolean, warn?: true, message: string }
function M.restart_outcome(message, target, o)
    if o.timeout then
        return { ok = false, message = message .. "; the restart did not answer — check :ParleyProxy status" }
    end
    if o.err then
        -- The error's own "cliproxy:" prefix would repeat the one :ParleyProxy adds.
        local err = tostring(o.err):gsub("^cliproxy: ", "")
        return { ok = false, message = message .. "; the restart failed — " .. err }
    end
    if o.version == target then
        return { ok = true, message = message .. "; now serving " .. target }
    end
    if o.version then
        return { ok = true, warn = true, message = ("%s; the proxy still reports %s, so the old process has "
            .. "not exited — run :ParleyProxy restart"):format(message, o.version) }
    end
    local why = ({ down = "nothing answers on the port", no_header = "it sent no version header" })[o.reason]
    return { ok = true, warn = true, message = ("%s; could not confirm what it now serves (%s) — check "
        .. ":ParleyProxy status"):format(message, why or tostring(o.reason or "no answer")) }
end

--- The `version:` value :ParleyProxy status prints (#237).
---@param v table # { running?, running_err?, installed?, latest?, latest_err?, pinned? }
---@param update_cmd string # e.g. ":ParleyProxy update"
---@return string
function M.version_summary(v, update_cmd)
    local latest = v.latest and ("latest " .. v.latest)
        or ("latest unknown: " .. tostring(v.latest_err or "not checked"))
    if not v.running then
        if v.running_err == "no_header" then
            return ("unknown — the proxy sent no version header (%s)"):format(latest)
        end
        if v.running_err ~= "down" then
            -- Only "down" was observed as not running; anything else is a read
            -- that did not happen, so say which (#237 BR-8).
            return ("unknown — %s (%s)"):format(tostring(v.running_err or "not read"), latest)
        end
        local parts = {}
        if v.installed then
            parts[#parts + 1] = "installed " .. v.installed
        end
        parts[#parts + 1] = latest
        return ("not running (%s)"):format(table.concat(parts, "; "))
    end
    local run = v.running
    if v.pinned then
        local pin = run == v.pinned and ("pinned to " .. v.pinned)
            or ("pinned to %s — run %s"):format(v.pinned, update_cmd)
        return ("%s (%s; %s)"):format(run, pin, latest)
    end
    if v.latest and M.compare_versions(run, v.latest) < 0 then
        return ("%s (latest %s — run %s)"):format(run, v.latest, update_cmd)
    end
    if v.latest and run == v.latest then
        return run .. " (latest)"
    end
    return ("%s (%s)"):format(run, latest)
end

return M
