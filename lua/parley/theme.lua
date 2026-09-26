-- Theme metadata and preference validation for the packaged Parley profile.
-- Applying a colorscheme and writing state stay at the UI boundary; this
-- module's registry is deliberately deterministic so every consumer derives
-- the same picker rows and validation set.
local M = {}

local DEFAULT = {
    id = "startup",
    label = "Restore startup theme",
    colorscheme = "moonfly",
    mode = "dark",
    style = "subdued",
    startup = true,
}

local CHOICES = {
    {
        id = "catppuccin-mocha",
        label = "Catppuccin Mocha — dark · colorful",
        colorscheme = "catppuccin-mocha",
        mode = "dark",
        style = "colorful",
    },
    {
        id = "tokyonight-storm",
        label = "Tokyo Night Storm — dark · subdued",
        colorscheme = "tokyonight-storm",
        mode = "dark",
        style = "subdued",
    },
    {
        id = "catppuccin-latte",
        label = "Catppuccin Latte — light · colorful",
        colorscheme = "catppuccin-latte",
        mode = "light",
        style = "colorful",
    },
    {
        id = "solarized-light",
        label = "Solarized Light — light · subdued",
        colorscheme = "solarized",
        mode = "light",
        style = "subdued",
    },
}

local function copy(spec)
    local result = {}
    for key, value in pairs(spec) do result[key] = value end
    return result
end

function M.default()
    return copy(DEFAULT)
end

function M.items()
    local result = {}
    for _, spec in ipairs(CHOICES) do result[#result + 1] = copy(spec) end
    result[#result + 1] = M.default()
    return result
end

function M.valid_id(id)
    if id == DEFAULT.id then return id end
    for _, spec in ipairs(CHOICES) do
        if id == spec.id then return id end
    end
    return DEFAULT.id
end

function M.find(id)
    local valid = M.valid_id(id)
    if valid == DEFAULT.id then return M.default() end
    for _, spec in ipairs(CHOICES) do
        if spec.id == valid then return copy(spec) end
    end
    return M.default()
end

function M.preference_path(state_dir)
    return state_dir .. "/theme.json"
end

--- Read the persisted choice. A missing file means the caller should preserve
--- its own startup scheme; malformed or unknown content resolves to startup.
function M.load(state_dir)
    local path = M.preference_path(state_dir)
    if vim.fn.filereadable(path) ~= 1 then return nil end
    local ok, value = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(value) ~= "table" then return DEFAULT.id end
    return M.valid_id(value.id)
end

function M.save(state_dir, id, helpers)
    if helpers and helpers.prepare_dir then
        helpers.prepare_dir(state_dir, "theme preference")
    else
        require("parley.fs").ensure_dir(state_dir)
    end
    local value = { id = M.valid_id(id) }
    if helpers and helpers.table_to_file_atomic then
        return helpers.table_to_file_atomic(value, M.preference_path(state_dir))
    end
    local ok, encoded = pcall(vim.json.encode, value)
    if not ok then return false, encoded end
    return vim.fn.writefile({ encoded }, M.preference_path(state_dir)) == 0
end

function M.apply(id, opts)
    opts = opts or {}
    local spec = M.find(id)
    local apply_colorscheme = opts.apply_colorscheme or vim.cmd.colorscheme
    local ok, err = pcall(apply_colorscheme, spec.colorscheme)
    if not ok then return false, err end
    if opts.on_applied then opts.on_applied(spec) end
    return true, spec
end

return M
