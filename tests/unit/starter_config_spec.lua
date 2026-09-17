local starter

describe('starter profile options', function()
    before_each(function() starter = require('parley.starter_config') end)
    it('inherits common learner behavior instead of carrying a second policy', function()
        local defaults = require('parley.config')
        local opts = starter.options({data = '/profile/data', state = '/profile/state'})
        assert.is_nil(opts.agents)
        assert.is_nil(opts.cliproxy)
        assert.is_nil(opts.chat_memory)
        assert.is_nil(opts.web_search)
        assert.is_false(defaults.chat_memory.enable)
        assert.is_true(defaults.web_search)
        assert.is_true(defaults.agents[1].placeholder)
        assert.equals('Choose a model', defaults.agents[1].name)
        assert.matches('We collaboratively seek knowledge', defaults.agents[1].system_prompt)
        assert.is_truthy(defaults.agents[1].system_prompt:find('always generate summary', 1, true))
    end)
    it('retains product search terms for the app providers', function()
        local opts = starter.options({ data = '/profile/data', state = '/profile/state' })
        assert.same({'claude:opus,sonnet,fable', 'codex:gpt-6,gpt-5', 'gemini'},
            require('parley.config').cliproxy.live_models.providers)
    end)
    -- #262: the app filter keeps only <C-g>/<M-> families, because the app
    -- must not claim ordinary editing keys from users who are not Vim experts.
    -- A TEXT OBJECT is operator-pending/visual only -- it cannot fire as a bare
    -- key -- so that policy does not reach it, and dropping it would leave the
    -- app with the delete hotkeys but no dae/yae/cae.
    it('keeps operator-pending text objects, which cannot claim a bare key', function()
        local opts = starter.options({ data = '/profile/data', state = '/profile/state' })
        assert.same({ 'ae' }, opts.chat_shortcut_entity_object_outer.shortcut)
        assert.same({ 'ie' }, opts.chat_shortcut_entity_object_inner.shortcut)
        assert.same({ 'aE' }, opts.chat_shortcut_entity_object_to_end.shortcut)
        assert.same({ 'o', 'x' }, opts.chat_shortcut_entity_object_outer.modes)
        -- the hotkey twins ride the <C-g> family as usual
        assert.same({ '<C-g>k' }, opts.chat_shortcut_entity_delete.shortcut)
        assert.same({ '<C-g>K' }, opts.chat_shortcut_entity_delete_to_end.shortcut)
    end)

    it('still refuses a bare normal-mode key from a non <C-g>/<M-> family', function()
        local opts = starter.options({ data = '/profile/data', state = '/profile/state' })
        -- gf is a parley_buffer normal-mode binding on a bare key: the app must
        -- keep excluding it, or this fix has widened the policy rather than
        -- carved out the one case it does not cover.
        assert.is_nil(opts.chat_shortcut_resolve_ref_gf)
    end)

    it('keeps chat prefix and Alt chords without enabling other shortcut families', function()
        local opts = starter.options({ data = '/profile/data', state = '/profile/state' })
        assert.same({ '<C-g>f' }, opts.global_shortcut_finder.shortcut)
        assert.same({ '<C-g>?' }, opts.global_shortcut_keybindings.shortcut)
        assert.same({ '<C-g><C-g>', '<M-CR>' }, opts.chat_shortcut_respond.shortcut)
        assert.same({ '<M-o>', '<C-g>o' }, opts.chat_shortcut_open_file.shortcut)
        assert.same({ '<C-g>t', '<M-t>' }, opts.chat_shortcut_outline.shortcut)
        assert.same({ '<M-v>' }, opts.chat_shortcut_paste_image.shortcut)
        assert.is_nil(opts.global_shortcut_issue_finder)
        assert.is_nil(opts.global_shortcut_note_finder)
        assert.is_false(opts.default_keymaps)
    end)
    it('retains finder-local controls despite restricting global key families', function()
        local opts = starter.options({ data = '/profile/data', state = '/profile/state' })
        local defaults = require('parley.config')
        for _, field in ipairs({ 'chat_finder_mappings', 'note_finder_mappings', 'issue_finder_mappings' }) do
            for action, binding in pairs(defaults[field]) do
                local expected = type(binding.shortcut) == 'table' and binding.shortcut or { binding.shortcut }
                assert.is_truthy(opts[field] and opts[field][action], field .. '.' .. action)
                assert.same(expected, opts[field][action].shortcut, field .. '.' .. action)
            end
        end
        assert.is_nil(opts.global_shortcut_note_finder)
        assert.is_nil(opts.global_shortcut_issue_finder)
    end)
    it('overrides app locations and external provider availability only', function()
        local roots = { data = '/profile/data', state = '/profile/state' }
        local opts = starter.options(roots)
        assert.equals('/profile/data/chats', opts.chat_dir)
        assert.same({}, opts.chat_dirs)
        assert.equals('/profile/state/persisted', opts.state_dir)
        assert.same({}, opts.providers.openai)
        assert.same({}, opts.providers.anthropic)
        assert.same({}, opts.providers.googleai)
        assert.same({}, opts.providers.ollama)
        assert.same({cliproxyapi = require('parley.config').api_keys.cliproxyapi}, opts.api_keys)
        assert.same(require('parley.config').providers.cliproxyapi, opts.providers.cliproxyapi)
        local common = require('parley.config')
        assert.equals(vim.fn.expand('~/.cli-proxy-api'), common.cliproxy.auth_dir)
        assert.same({'@all'},
            common.cliproxy.live_models.tools)
        assert.same(common.cliproxy.live_models.tools, common.agents[1].tools)
        assert.is_true(common.cliproxy.manage)
        assert.is_true(common.cliproxy.auto_download)
        assert.is_false(common.memory_prefs.enable)
        assert.same({}, common.tool_read_roots)
        assert.is_true(common.chat_confirm_delete)
        assert.matches('/parley/chats$', common.chat_dir)
        assert.matches('/parley/notes$', common.notes_dir)
        assert.matches('/parley/exports/html$', common.export_html_dir)
    end)
end)
