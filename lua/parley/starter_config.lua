-- Portable starter policy; roots and client secret are supplied by the IO shell.
local M = {}

function M.options(roots, key)
    return {
        api_keys = { cliproxyapi = key },
        providers = {
            openai = {}, anthropic = {}, googleai = {}, ollama = {}, copilot = {},
            cliproxyapi = { endpoint = 'http://127.0.0.1:8318/v1/chat/completions' },
        },
        cliproxy = {
            manage = true, auto_download = true, auth_dir = roots.data .. '/auth',
            live_models = { providers = { 'claude', 'codex', 'gemini' }, per_provider = 3, tools = {} },
            config = { ['remote-management'] = { ['disable-control-panel'] = true } },
        },
        agents = {
            { name = 'ToolOpus*', disable = true },
            { name = 'Choose a model', provider = 'cliproxyapi', model = { model = 'choose-a-model' },
                system_prompt = 'You are a helpful assistant. Explain ideas clearly.', tools = {} },
        },
        -- The sole configured learner is the first-use fallback. Setting
        -- default_agent would override a restored live selection on every start.
        chat_dir = roots.data .. '/chats', chat_dirs = {}, chat_roots = {},
        notes_dir = roots.data .. '/notes', note_dirs = {}, note_roots = {},
        export_html_dir = roots.data .. '/exports/html',
        export_markdown_dir = roots.data .. '/exports/markdown',
        state_dir = roots.state .. '/persisted', log_file = roots.state .. '/parley.log',
        log_sensitive = false, tool_read_roots = {}, web_search = false,
        memory_prefs = { enable = false }, chat_confirm_delete = true,
        default_keymaps = false,
        chat_shortcut_respond = { modes = { 'n', 'i' }, shortcut = '<M-CR>' },
        chat_shortcut_paste_image = { modes = { 'n', 'i' }, shortcut = '<M-v>' },
        chat_shortcut_outline = { modes = { 'n', 'i' }, shortcut = '<M-t>' },
    }
end

return M
