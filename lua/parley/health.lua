--------------------------------------------------------------------------------
-- :checkhealth parley
--------------------------------------------------------------------------------

local M = {}

function M.check()
	vim.health.start("Parley.nvim checks")

	local ok, parley = pcall(require, "parley")
	if not ok then
		vim.health.error("require('parley') failed")
	else
		vim.health.ok("require('parley') succeeded")

		if parley._setup_called then
			vim.health.ok("require('parley').setup() has been called")
		else
			vim.health.error("require('parley').setup() has not been called")
		end
	end

    vim.health.start("Parley external tools")
    local deps = require("parley.deps")
    local probe = require("parley.deps_probe")
    local host = probe.host()
    for _, entry in ipairs(deps.entries) do
        local observed = probe.observe(entry, host)
        local label = entry.id .. " [" .. entry.tier .. "] — " .. entry.feature
        if not observed.applicable then
            vim.health.info(label .. ": not applicable on " .. host.sysname)
        elseif observed.present then
            local detail = ": installed (source: " .. observed.source
            if entry.tier == "managed" then
                detail = detail .. "; version: " .. (observed.version or "unknown")
            end
            vim.health.ok(label .. detail .. ")")
        else
            local report = entry.required and vim.health.error or vim.health.warn
            report(label .. ": missing. " .. deps.advice(entry.id, host))
        end
    end

	-- Check for optional dependencies
	local has_lualine, _ = pcall(require, "lualine")
	if has_lualine then
		local parley_ok, parley_module = pcall(require, "parley")
		if parley_ok and parley_module.config and parley_module.config.lualine and parley_module.config.lualine.enable then
			vim.health.ok("lualine is installed and integration is enabled")
		else
			vim.health.info("lualine is installed but integration is disabled (enable in config)")
		end
	else
		vim.health.info("lualine is not installed (statusline integration unavailable)")
	end

end

return M
