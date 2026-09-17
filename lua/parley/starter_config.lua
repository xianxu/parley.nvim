-- Portable starter policy; profile roots are supplied by the IO shell.
local M = {}

function M.options(roots)
    local defaults = require('parley.config')
    local options = {
        api_keys = { cliproxyapi = defaults.api_keys.cliproxyapi },
        providers = {
            cliproxyapi = vim.deepcopy(defaults.providers.cliproxyapi),
            openai = {}, anthropic = {}, googleai = {}, ollama = {}, copilot = {},
        },
        -- The sole configured learner is the first-use fallback. Setting
        -- default_agent would override a restored live selection on every start.
        chat_dir = roots.data .. '/chats',
        chat_dirs = {}, chat_roots = {},
        notes_dir = roots.data .. '/notes', note_dirs = {}, note_roots = {},
        export_html_dir = roots.data .. '/exports/html',
        export_markdown_dir = roots.data .. '/exports/markdown',
        state_dir = roots.state .. '/persisted', log_file = roots.state .. '/parley.log',
        default_keymaps = false,
    }
    -- Keep editor/global shortcuts in the app key families. Finder controls
    -- live only in their picker buffers, so retain their complete default set.
    local registry = require('parley.keybinding_registry')
    -- A text object is operator-pending/visual only: it fires after an operator
    -- or inside a selection, never as a bare key, so it cannot take an ordinary
    -- editing key away from the user. The family filter below exists to stop
    -- exactly that, so it does not reach text objects -- without this carve-out
    -- the app ships <C-g>k but no dae/yae/cae (#262).
    local function object_only(modes)
        if not modes or #modes == 0 then return false end
        for _, mode in ipairs(modes) do
            if mode ~= 'o' and mode ~= 'x' then return false end
        end
        return true
    end
    for _, entry in ipairs(registry.entries) do
        if entry.config_key then
            local keys, modes = registry.resolve_keys(entry, defaults)
            local selected = {}
            for _, keybinding in ipairs(keys or {}) do
                if entry.scope:match('_finder$') or object_only(modes)
                    or keybinding:lower():match('^<c%-g>')
                    or keybinding:lower():match('^<m%-') then
                    selected[#selected + 1] = keybinding
                end
            end
            if entry.id == 'chat_respond' then selected[#selected + 1] = '<M-CR>' end
            if #selected > 0 then
                local parts = vim.split(entry.config_key, '.', { plain = true })
                local target = options
                for i = 1, #parts - 1 do
                    target[parts[i]] = target[parts[i]] or {}
                    target = target[parts[i]]
                end
                target[parts[#parts]] = { modes = vim.deepcopy(modes), shortcut = selected }
            end
        end
    end
    return options
end

return M
