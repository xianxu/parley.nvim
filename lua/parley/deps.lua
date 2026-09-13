-- parley.deps — the pure registry of external dependency guidance.
--
-- This module deliberately has no Neovim, filesystem, process, or package
-- manager dependency.  Callers supply the observed host and executable state;
-- this module only answers applicability, display advice, and package
-- projections.

local M = {}

M.entries = {
    {
        id = "cliproxyapi",
        executables = { "cliproxyapi", "cli-proxy-api" },
        tier = "managed",
        feature = "model access",
        guidance = "use :ParleyProxy update, or set cliproxy.binary_path",
        packages = {},
        formula_default = false,
        required = false,
    },
    {
        id = "osascript",
        executables = { "osascript" },
        tier = "platform",
        hosts = { "Darwin" },
        feature = "clipboard image",
        guidance = "osascript ships with macOS",
        packages = {},
        formula_default = false,
        required = false,
    },
    {
        id = "sips",
        executables = { "sips" },
        tier = "platform",
        hosts = { "Darwin" },
        feature = "image shrinking",
        guidance = "sips ships with macOS",
        packages = {},
        formula_default = false,
        required = false,
    },
    {
        id = "ripgrep",
        executables = { "rg" },
        tier = "advisory",
        feature = "chat and issue search",
        packages = { brew = "ripgrep", apt = "ripgrep" },
        formula_default = true,
        required = false,
    },
    {
        id = "imagemagick",
        executables = { "magick", "convert" },
        tier = "advisory",
        feature = "optional image shrinking backend",
        packages = { brew = "imagemagick", apt = "imagemagick" },
        formula_default = false,
        required = false,
    },
    {
        id = "ffmpeg",
        executables = { "ffmpeg" },
        tier = "advisory",
        feature = "optional image shrinking backend",
        packages = { brew = "ffmpeg", apt = "ffmpeg" },
        formula_default = false,
        required = false,
    },
    {
        id = "libvips",
        executables = { "vipsthumbnail" },
        tier = "advisory",
        feature = "optional image shrinking backend",
        packages = { brew = "vips", apt = "libvips-tools" },
        formula_default = false,
        required = false,
    },
    {
        id = "wl-clipboard",
        executables = { "wl-paste" },
        tier = "advisory",
        hosts = { "Linux" },
        feature = "clipboard image",
        packages = { apt = "wl-clipboard" },
        formula_default = false,
        required = false,
    },
    {
        id = "xclip",
        executables = { "xclip" },
        tier = "advisory",
        hosts = { "Linux" },
        feature = "clipboard image",
        packages = { apt = "xclip" },
        formula_default = false,
        required = false,
    },
    {
        id = "pandoc",
        executables = { "pandoc" },
        tier = "advisory",
        feature = "HTML export",
        packages = { brew = "pandoc", apt = "pandoc" },
        formula_default = false,
        required = false,
    },
    {
        id = "curl",
        executables = { "curl" },
        tier = "platform",
        feature = "network requests",
        guidance = "curl is system-provided on macOS",
        packages = { brew = "curl", apt = "curl" },
        formula_default = false,
        required = true,
    },
}

local by_id = {}
for _, entry in ipairs(M.entries) do
    by_id[entry.id] = entry
end

function M.get(id)
    return by_id[id]
end

--- Whether a registry entry applies to the supplied host.
--- Unrestricted entries (including curl) apply to every host.  Restricted
--- entries require a matching sysname and do not guess for a missing host.
function M.applicable(entry, host)
    if type(entry) ~= "table" then
        return false
    end
    if entry.hosts == nil then
        return true
    end
    if type(host) ~= "table" then
        return false
    end
    for _, sysname in ipairs(entry.hosts) do
        if host.sysname == sysname then
            return true
        end
    end
    return false
end

local function manager_supported(entry, host)
    if type(host) ~= "table" then
        return false
    end
    local manager = host.manager
    if manager ~= "brew" and manager ~= "apt" then
        return false
    end
    if manager == "brew" and host.sysname ~= "Darwin" then
        return false
    end
    if manager == "apt" and host.sysname ~= "Linux" then
        return false
    end
    return type(entry.packages) == "table" and type(entry.packages[manager]) == "string"
        and entry.packages[manager] ~= ""
end

local function host_label(host)
    if type(host) ~= "table" then
        return "unknown host"
    end
    local sysname = host.sysname or "unknown host"
    local manager = host.manager
    if manager == nil then
        return tostring(sysname) .. " (no supported package manager detected)"
    end
    return tostring(sysname) .. " (manager " .. tostring(manager) .. ")"
end

local function platform_advice(entry, host)
    if entry.tier == "platform" and type(host) == "table" and host.sysname == "Darwin" then
        return entry.guidance
    end
    return nil
end

--- Return display-only guidance for one dependency on one host.
function M.advice(id, host)
    local entry = M.get(id)
    if not entry then
        return "unknown dependency: " .. tostring(id)
    end
    if not M.applicable(entry, host) then
        return entry.id .. " is not applicable on " .. host_label(host)
    end

    if entry.tier == "managed" then
        return entry.guidance
    end

    local platform = platform_advice(entry, host)
    if platform then
        return platform
    end

    if manager_supported(entry, host) then
        return host.manager .. " install " .. entry.packages[host.manager]
    end
    return "no tested install advice for " .. entry.id .. " on " .. host_label(host)
end

--- Return the package names represented by the registry for a host.
--- `default` is the approved formula subset; `all` includes every advisory
--- package that has a tested manager mapping for the host.
function M.packages(host, selection)
    local want_all = selection == "all"
    local names = {}
    for _, entry in ipairs(M.entries) do
        if entry.tier == "advisory"
            and M.applicable(entry, host)
            and (want_all or entry.formula_default)
            and manager_supported(entry, host) then
            local package = entry.packages[host.manager]
            names[package] = true
        end
    end

    local out = {}
    for package in pairs(names) do
        out[#out + 1] = package
    end
    table.sort(out)
    return out
end

return M
